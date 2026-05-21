#!/usr/bin/env python3
"""
Generate a daily AppMetrica report as a PNG image and send it to Telegram.

Required env:
  APPMETRICA_APP_ID
  APPMETRICA_OAUTH_TOKEN
  TELEGRAM_BOT_TOKEN
  TELEGRAM_CHAT_ID

Useful:
  REPORT_DATE=yesterday|today|YYYY-MM-DD
  REPORT_TIMEZONE=Asia/Almaty
  REPORT_OUTPUT=build/appmetrica_report.png
"""

from __future__ import annotations

import argparse
import os
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import requests
from PIL import Image, ImageDraw, ImageFont
from zoneinfo import ZoneInfo


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "build" / "appmetrica_report.png"
API_BASE = "https://api.appmetrica.yandex.com/logs/v1/export"


@dataclass
class ReportData:
    report_date: str
    generated_at: str
    installs: int
    clicks: int
    sessions: int
    users: int
    app_start: int
    cart_add: int
    cart_share_tap: int
    top_trackers: list[tuple[str, int, int]]
    top_events: list[tuple[str, int]]
    warnings: list[str]


def load_dotenv(path: Path) -> None:
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


def required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required env: {name}")
    return value


def resolve_report_date(value: str, tz: ZoneInfo) -> datetime:
    now = datetime.now(tz)
    if value == "today":
        return now.replace(hour=0, minute=0, second=0, microsecond=0)
    if value == "yesterday":
        return (now - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    try:
        parsed = datetime.strptime(value, "%Y-%m-%d")
    except ValueError as exc:
        raise SystemExit("REPORT_DATE must be yesterday, today, or YYYY-MM-DD") from exc
    return parsed.replace(tzinfo=tz)


class AppMetricaClient:
    def __init__(self, app_id: str, token: str, limit: int) -> None:
        self.app_id = app_id
        self.token = token
        self.limit = limit

    def logs(self, endpoint: str, fields: list[str], date_since: str, date_until: str) -> list[dict[str, Any]]:
        url = f"{API_BASE}/{endpoint}.json"
        response = requests.get(
            url,
            headers={"Authorization": f"OAuth {self.token}"},
            params={
                "application_id": self.app_id,
                "date_since": date_since,
                "date_until": date_until,
                "fields": ",".join(fields),
                "limit": str(self.limit),
                "skip_unavailable_shards": "true",
            },
            timeout=45,
        )
        if response.status_code >= 400:
            raise RuntimeError(f"AppMetrica {endpoint} failed: {response.status_code} {response.text[:500]}")
        payload = response.json()
        data = payload.get("data", [])
        return data if isinstance(data, list) else []


def tracker_name(row: dict[str, Any]) -> str:
    tracker = str(row.get("tracker_name") or "").strip()
    publisher = str(row.get("publisher_name") or "").strip()
    return tracker or publisher or "Organic"


def fetch_report(report_day: datetime) -> ReportData:
    app_id = required_env("APPMETRICA_APP_ID")
    token = required_env("APPMETRICA_OAUTH_TOKEN")
    limit = int(os.getenv("APPMETRICA_LOG_LIMIT", "10000"))
    client = AppMetricaClient(app_id=app_id, token=token, limit=limit)

    date_since = report_day.strftime("%Y-%m-%d 00:00:00")
    date_until = report_day.strftime("%Y-%m-%d 23:59:59")
    warnings: list[str] = []

    clicks = client.logs(
        "clicks",
        ["click_datetime", "tracker_name", "publisher_name", "tracking_id"],
        date_since,
        date_until,
    )
    installs = client.logs(
        "installations",
        ["install_datetime", "installation_id", "tracker_name", "publisher_name", "tracking_id", "appmetrica_device_id"],
        date_since,
        date_until,
    )
    sessions = client.logs(
        "sessions_starts",
        ["session_start_datetime", "session_id", "appmetrica_device_id"],
        date_since,
        date_until,
    )
    events = client.logs(
        "events",
        ["event_datetime", "event_name", "session_id", "appmetrica_device_id"],
        date_since,
        date_until,
    )

    for name, rows in [
        ("clicks", clicks),
        ("installations", installs),
        ("sessions", sessions),
        ("events", events),
    ]:
        if len(rows) >= limit:
            warnings.append(f"{name}: reached limit {limit}, increase APPMETRICA_LOG_LIMIT")

    click_by_tracker = Counter(tracker_name(row) for row in clicks)
    install_by_tracker = Counter(tracker_name(row) for row in installs)
    all_trackers = sorted(set(click_by_tracker) | set(install_by_tracker))
    tracker_rows = sorted(
        [(name, click_by_tracker[name], install_by_tracker[name]) for name in all_trackers],
        key=lambda item: (item[1] + item[2], item[2], item[1]),
        reverse=True,
    )[:6]

    event_counts = Counter(str(row.get("event_name") or "unknown") for row in events)
    users = len({str(row.get("appmetrica_device_id")) for row in sessions if row.get("appmetrica_device_id")})

    return ReportData(
        report_date=report_day.strftime("%d.%m.%Y"),
        generated_at=datetime.now(report_day.tzinfo).strftime("%d.%m.%Y %H:%M"),
        installs=len(installs),
        clicks=len(clicks),
        sessions=len(sessions),
        users=users,
        app_start=event_counts.get("app_start", 0),
        cart_add=event_counts.get("cart_add", 0),
        cart_share_tap=event_counts.get("cart_share_tap", 0),
        top_trackers=tracker_rows,
        top_events=event_counts.most_common(6),
        warnings=warnings,
    )


def demo_report(tz: ZoneInfo) -> ReportData:
    yesterday = datetime.now(tz) - timedelta(days=1)
    return ReportData(
        report_date=yesterday.strftime("%d.%m.%Y"),
        generated_at=datetime.now(tz).strftime("%d.%m.%Y %H:%M"),
        installs=7,
        clicks=18,
        sessions=41,
        users=23,
        app_start=29,
        cart_add=6,
        cart_share_tap=2,
        top_trackers=[("Organic", 0, 7), ("Threads link", 18, 0)],
        top_events=[("app_start", 29), ("cart_add", 6), ("favorite_add", 4), ("cart_share_tap", 2)],
        warnings=[],
    )


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    names = {
        "regular": "JetBrainsMono-Regular.ttf",
        "medium": "JetBrainsMono-Medium.ttf",
        "semibold": "JetBrainsMono-SemiBold.ttf",
        "bold": "JetBrainsMono-Bold.ttf",
    }
    path = ROOT / "MinPrice" / "Resources" / "Fonts" / names.get(weight, names["regular"])
    try:
        return ImageFont.truetype(str(path), size=size)
    except OSError:
        return ImageFont.load_default()


def rounded(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int, fill: str, outline: str | None = None, width: int = 1) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def draw_metric_card(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, h: int, title: str, value: str, accent: str) -> None:
    rounded(draw, (x, y, x + w, y + h), 26, "#ffffff", "#d8eef2", 2)
    draw.rounded_rectangle((x + 22, y + 22, x + 68, y + 68), radius=16, fill=accent)
    draw.text((x + 86, y + 22), title, fill="#758294", font=font(24, "medium"))
    draw.text((x + 86, y + 58), value, fill="#162233", font=font(46, "bold"))


def draw_compact_metric(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, title: str, value: str, accent: str) -> None:
    rounded(draw, (x, y, x + w, y + 104), 22, "#fbfdff", "#d8eef2", 2)
    draw.rounded_rectangle((x + 22, y + 26, x + 70, y + 74), radius=15, fill=accent)
    draw.text((x + 88, y + 25), title, fill="#758294", font=font(22, "medium"))
    draw.text((x + 88, y + 58), value, fill="#162233", font=font(34, "bold"))


def draw_bar(draw: ImageDraw.ImageDraw, x: int, y: int, w: int, label: str, value: int, max_value: int, color: str) -> None:
    draw.text((x, y), label[:30], fill="#253044", font=font(22, "medium"))
    draw.text((x + w - 92, y), str(value), fill="#253044", font=font(22, "bold"))
    bar_y = y + 36
    rounded(draw, (x, bar_y, x + w, bar_y + 14), 7, "#edf7f9")
    if max_value > 0 and value > 0:
        filled = max(12, int(w * value / max_value))
        rounded(draw, (x, bar_y, x + filled, bar_y + 14), 7, color)


def render_report(data: ReportData, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGB", (1200, 1500), "#eef9fb")
    draw = ImageDraw.Draw(img)

    # Background accents
    for box, fill in [
        ((-160, -160, 430, 430), "#d8fbf2"),
        ((840, -120, 1320, 360), "#dff3ff"),
        ((760, 1120, 1360, 1680), "#e5fff3"),
    ]:
        draw.ellipse(box, fill=fill)

    rounded(draw, (60, 60, 1140, 1440), 42, "#f8fdff", "#aee3e5", 3)

    logo_path = ROOT / "MinPrice" / "Resources" / "Assets.xcassets" / "AppLogo.imageset" / "logo.png"
    if logo_path.exists():
        logo = Image.open(logo_path).convert("RGBA").resize((76, 76))
        img.paste(logo, (92, 88), logo)
    else:
        draw.rounded_rectangle((92, 88, 168, 164), radius=20, fill="#32c5dc")

    draw.text((188, 88), "minprice.kz", fill="#2aaec5", font=font(38, "bold"))
    draw.text((188, 136), "Daily AppMetrica report", fill="#6e7e91", font=font(24, "medium"))
    draw.text((835, 98), data.report_date, fill="#162233", font=font(36, "bold"))
    draw.text((835, 142), f"generated {data.generated_at}", fill="#7a8796", font=font(18, "regular"))

    draw_metric_card(draw, 92, 220, 490, 150, "Installs", str(data.installs), "#33c68c")
    draw_metric_card(draw, 618, 220, 490, 150, "Clicks", str(data.clicks), "#ef4c61")
    draw_metric_card(draw, 92, 400, 490, 150, "Sessions", str(data.sessions), "#34bad2")
    draw_metric_card(draw, 618, 400, 490, 150, "Users", str(data.users), "#f39a4a")

    rounded(draw, (92, 600, 1108, 790), 26, "#ffffff", "#d8eef2", 2)
    draw.text((126, 630), "Key events", fill="#162233", font=font(30, "bold"))
    draw_compact_metric(draw, 126, 672, 286, "app_start", str(data.app_start), "#34bad2")
    draw_compact_metric(draw, 456, 672, 286, "cart_add", str(data.cart_add), "#33c68c")
    draw_compact_metric(draw, 786, 672, 286, "share", str(data.cart_share_tap), "#ef4c61")

    rounded(draw, (92, 830, 1108, 1118), 26, "#ffffff", "#d8eef2", 2)
    draw.text((126, 860), "Traffic sources", fill="#162233", font=font(30, "bold"))
    draw.text((824, 866), "clicks", fill="#7a8796", font=font(20, "medium"))
    draw.text((962, 866), "installs", fill="#7a8796", font=font(20, "medium"))
    y = 918
    max_tracker = max([max(c, i) for _, c, i in data.top_trackers] + [1])
    for name, clicks, installs in data.top_trackers[:4]:
        draw.text((126, y), name[:28], fill="#253044", font=font(24, "medium"))
        draw.text((842, y), str(clicks), fill="#253044", font=font(24, "bold"))
        draw.text((1005, y), str(installs), fill="#253044", font=font(24, "bold"))
        bar_y = y + 42
        rounded(draw, (126, bar_y, 886, bar_y + 14), 7, "#edf7f9")
        value = max(clicks, installs)
        if max_tracker > 0 and value > 0:
            rounded(draw, (126, bar_y, 126 + max(12, int(760 * value / max_tracker)), bar_y + 14), 7, "#34bad2")
        y += 62

    rounded(draw, (92, 1158, 1108, 1386), 26, "#ffffff", "#d8eef2", 2)
    draw.text((126, 1188), "Top events", fill="#162233", font=font(30, "bold"))
    max_event = max([v for _, v in data.top_events] + [1])
    y = 1242
    for name, value in data.top_events[:3]:
        draw_bar(draw, 126, y, 920, name, value, max_event, "#33c68c")
        y += 56

    if data.warnings:
        warning = " / ".join(data.warnings)[:95]
        draw.text((92, 1408), f"Warning: {warning}", fill="#ef4c61", font=font(18, "medium"))
    else:
        draw.text((92, 1408), "Source: AppMetrica Logs API", fill="#7a8796", font=font(18, "medium"))

    img.save(output, "PNG", optimize=True)


def send_telegram(photo_path: Path, caption: str) -> None:
    bot_token = required_env("TELEGRAM_BOT_TOKEN")
    chat_id = required_env("TELEGRAM_CHAT_ID")
    url = f"https://api.telegram.org/bot{bot_token}/sendPhoto"
    with photo_path.open("rb") as photo:
        response = requests.post(
            url,
            data={"chat_id": chat_id, "caption": caption},
            files={"photo": (photo_path.name, photo, "image/png")},
            timeout=45,
        )
    if response.status_code >= 400:
        raise RuntimeError(f"Telegram sendPhoto failed: {response.status_code} {response.text[:500]}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--env", default=str(ROOT / ".env.appmetrica-report"), help="Path to env file")
    parser.add_argument("--output", default=os.getenv("REPORT_OUTPUT", str(DEFAULT_OUTPUT)))
    parser.add_argument("--demo", action="store_true", help="Render a demo report without API/Telegram")
    parser.add_argument("--no-send", action="store_true", help="Generate PNG but do not send to Telegram")
    args = parser.parse_args()

    load_dotenv(Path(args.env))
    tz = ZoneInfo(os.getenv("REPORT_TIMEZONE", "Asia/Almaty"))
    report_day = resolve_report_date(os.getenv("REPORT_DATE", "yesterday"), tz)
    data = demo_report(tz) if args.demo else fetch_report(report_day)
    output = Path(args.output)
    render_report(data, output)

    if args.demo or args.no_send:
        print(f"Report image written to {output}")
        return

    send_telegram(output, f"minprice.kz AppMetrica report — {data.report_date}")
    print(f"Report image sent to Telegram: {output}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
