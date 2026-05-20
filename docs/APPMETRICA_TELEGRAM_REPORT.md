# AppMetrica Telegram Report

Скрипт `scripts/appmetrica_daily_report.py` строит PNG-отчет из AppMetrica Logs API и отправляет его в Telegram через `sendPhoto`.

## Установка

```bash
cd /Users/33karaulov/Documents/pricer_mobile/pricer_ios
python3 -m venv .venv-report
. .venv-report/bin/activate
pip install -r scripts/requirements-appmetrica-report.txt
cp scripts/.env.appmetrica-report.example .env.appmetrica-report
```

Заполни `.env.appmetrica-report`:

- `APPMETRICA_OAUTH_TOKEN` — OAuth token Яндекса с доступом к AppMetrica.
- `TELEGRAM_BOT_TOKEN` — токен бота из `@BotFather`.
- `TELEGRAM_CHAT_ID` — id личного чата, группы или канала.

## Проверка картинки без отправки

```bash
python3 scripts/appmetrica_daily_report.py --demo
```

Файл появится в `build/appmetrica_report.png`.

## Отправка отчета

```bash
python3 scripts/appmetrica_daily_report.py
```

По умолчанию отправляется отчет за вчерашний день. Для ручной даты:

```bash
REPORT_DATE=2026-05-09 python3 scripts/appmetrica_daily_report.py
```

## Cron каждый день

Пример запуска каждый день в 09:00 по времени машины:

```cron
0 9 * * * cd /Users/33karaulov/Documents/pricer_mobile/pricer_ios && . .venv-report/bin/activate && python3 scripts/appmetrica_daily_report.py >> logs/appmetrica_report.log 2>&1
```

Перед добавлением cron создай папку `logs`.
