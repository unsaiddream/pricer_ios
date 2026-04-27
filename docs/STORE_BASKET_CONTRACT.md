# Store Basket Endpoint Contract

Готовый агрегат для главного графика-корзины (Home → StoreBasketChart).
Этот endpoint заменяет 3-12 разных запросов с клиента и тяжёлый precompute
на устройстве, разгружая мобильную сеть и батарею.

## Endpoint

```
GET /api/home/basket/?city_id=<int>&category_id=<int?>&period=<str>
```

| Параметр | Обязателен | Значения | Дефолт |
|---|---|---|---|
| `city_id` | да | int | — |
| `category_id` | нет | int (id категории) или отсутствует | бэк сам выбирает по rotation |
| `period` | нет | `now` \| `month` \| `quarter` | `now` |

Если `category_id` не передан, бэк должен сам выбрать категорию для дня
(rotation по `dayOfYear`). Это избавляет клиент от знания списка категорий
для daily-pick.

## Response

```json
{
  "category": { "id": 42, "name": "Хлеб и выпечка", "emoji": "🍞" },
  "period": "now",
  "coverage_count": 87,
  "columns": [
    {
      "slug": "mgo",
      "name": "MagnumGO",
      "logo_url": "/media/chain_logos/magnum.png",
      "color_hex": "#F24D4D",
      "average": 612.34,
      "basket_total": 53273.4,
      "wins": 31,
      "win_share": 35.6,
      "honesty_score": 78.2,
      "overpay_percent": 4.1,
      "covered_count": 87,
      "has_data": true
    },
    { "slug": "arbuz",       "...": "..." },
    { "slug": "airbafresh",  "...": "..." },
    { "slug": "small",       "...": "..." },
    { "slug": "galmart",     "...": "..." },
    { "slug": "toimart",     "...": "..." }
  ],
  "line_points": [
    { "slug": "mgo",   "date": "2026-04-27T12:00:00Z", "price": 615.0 },
    { "slug": "mgo",   "date": "2026-03-28T12:00:00Z", "price": 642.0 },
    { "slug": "arbuz", "date": "2026-04-27T12:00:00Z", "price": 590.0 }
  ],
  "aggregator_version": 1
}
```

## Логика расчёта

### Шаг 1. Выборка товаров

Берём все активные товары из `category_id` (или из ротации дня), у которых
есть цены хотя бы в **двух** магазинах из 6 поддерживаемых сетей. Это даёт
"корзину сравнимых товаров" — основу для всех дальнейших метрик.

```sql
WITH covered_products AS (
  SELECT p.id, p.uuid
  FROM products p
  JOIN store_products sp ON sp.product_id = p.id
  JOIN stores s          ON s.id = sp.store_id
  JOIN chains c          ON c.id = s.chain_id
  WHERE p.is_active
    AND s.city_id = :city_id
    AND p.category_id = :category_id
    AND sp.price > 0
    AND c.slug IN ('mgo','arbuz','airbafresh','small','galmart','toimart')
  GROUP BY p.id, p.uuid
  HAVING COUNT(DISTINCT c.slug) >= 2
)
```

### Шаг 2. Цена по периоду

Для каждой пары (product, chain) выбираем цену:
- `period = now`     → текущая `sp.price`
- `period = month`   → среднее между `sp.price` и `sp.previous_price`
- `period = quarter` → `sp.previous_price` если есть, иначе `sp.price`

Если у одной сети несколько магазинов в городе — берём минимальную цену.

```sql
prices AS (
  SELECT
    cp.id AS product_id,
    c.slug AS chain_slug,
    MIN(
      CASE :period
        WHEN 'now'     THEN sp.price
        WHEN 'month'   THEN (sp.price + COALESCE(sp.previous_price, sp.price)) / 2.0
        WHEN 'quarter' THEN COALESCE(sp.previous_price, sp.price)
      END
    ) AS price
  FROM covered_products cp
  JOIN store_products sp ON sp.product_id = cp.id
  JOIN stores s          ON s.id = sp.store_id AND s.city_id = :city_id
  JOIN chains c          ON c.id = s.chain_id AND c.slug IN ('mgo','arbuz','airbafresh','small','galmart','toimart')
  WHERE sp.price > 0
  GROUP BY cp.id, c.slug
)
```

### Шаг 3. Per-product min/max и нормализация

```sql
ranges AS (
  SELECT product_id, MIN(price) AS p_min, MAX(price) AS p_max
  FROM prices
  GROUP BY product_id
)
```

Линейная нормализация для каждой (product, chain):

```
score = (p_max - price) / NULLIF(p_max - p_min, 0) * 100
```

Когда все цены равны (`p_max == p_min`) — `score = 50` (нейтрально).

### Шаг 4. Per-chain агрегация

```sql
per_chain AS (
  SELECT
    pr.chain_slug,
    AVG(pr.price)                       AS average,
    SUM(pr.price)                       AS basket_total,
    COUNT(*)                            AS covered_count,
    SUM(CASE WHEN pr.price = r.p_min THEN 1 ELSE 0 END) AS wins,
    AVG(
      CASE WHEN r.p_max > r.p_min
        THEN (r.p_max - pr.price) / (r.p_max - r.p_min) * 100
        ELSE 50
      END
    ) AS raw_score,
    AVG((pr.price - r.p_min) / NULLIF(r.p_min, 0) * 100) AS overpay_percent
  FROM prices pr
  JOIN ranges r ON r.product_id = pr.product_id
  GROUP BY pr.chain_slug
)
```

### Шаг 5. Bayesian smoothing (Python)

SQL не делает smoothing — добиваем в Python чтобы магазин с 3 товарами и
100 баллами не обогнал магазин с 50 товарами и 80:

```python
SMOOTHING = 5
NEUTRAL_SCORE = 50

for col in columns:
    n = col["covered_count"]
    raw = col["raw_score"]
    if n == 0:
        col["honesty_score"] = 0
    else:
        col["honesty_score"] = (raw * n + NEUTRAL_SCORE * SMOOTHING) / (n + SMOOTHING)
    col["win_share"] = (col["wins"] / n * 100) if n > 0 else 0
    col["has_data"]  = n > 0
```

### Шаг 6. Дополнить мета-данные сетей

К каждой колонке добавить из таблицы `chains`:

```python
for col in columns:
    chain = chains_by_slug[col["slug"]]
    col["name"]      = chain.name
    col["logo_url"]  = chain.logo_url
    col["color_hex"] = chain.color_hex   # если в БД есть; иначе null
```

Все 6 сетей возвращаем всегда — даже если в категории `has_data = false`.
Это даёт стабильный layout на клиенте (всегда 6 колонок одинаковой ширины,
пустые показываются полупрозрачно).

### Шаг 7. Line points (3 точки на сеть)

Для line-chart нужно 3 точки на каждую сеть:
- `now` — текущая средняя цена корзины (можно усреднить по covered_products)
- `mid` — половина периода назад
- `anchor` — начало периода (текущий `previous_price` если есть)

```python
def line_points_for(period: str, chain_slug: str, prices: list[Decimal]) -> list[dict]:
    now = datetime.utcnow()
    if period == "now":      anchor_days = 1
    elif period == "month":  anchor_days = 30
    else:                    anchor_days = 90

    cur = mean(prices.current)
    prev = mean(prices.previous) if prices.previous else cur
    mid = (cur + prev) / 2

    return [
        {"slug": chain_slug, "date": now - timedelta(days=anchor_days),     "price": prev},
        {"slug": chain_slug, "date": now - timedelta(days=anchor_days/2),   "price": mid},
        {"slug": chain_slug, "date": now,                                   "price": cur},
    ]
```

## Кэширование

Ответ должен кэшироваться в Redis с ключом
`basket:v1:{city_id}:{category_id_or_rotation_seed}:{period}` на **5 минут**.
Это покрывает ~95% случаев на главной (одни и те же категории/города).

Cache-busting:
- При обновлении цен (cron) — `DEL basket:v1:*`
- При смене ротации (раз в день) — естественно сменяется `category_id` если
  оно вычисляется из `dayOfYear`

## Производительность

Целевые метрики (бэк):
- p95 latency: < 150ms (с холодным Redis)
- p95 latency: < 30ms (с тёплым Redis)
- payload size: ~3-6 KB (gzip)

Для сравнения, текущая клиентская агрегация:
- 3-12 HTTP-запросов
- ~150-400 KB сетевого трафика (товары с полными `stores[]`)
- 200-800ms на iPhone средней мощности

## Forward compatibility

- Если бэк добавит новую сеть — она появится в `columns[]` автоматически.
  Клиент рисует все колонки, неизвестные slug-и красит дефолтным цветом
  (или берёт `color_hex` если бэк его прислал).
- Если бэк добавит новые поля в Column — клиент их игнорирует.
- Если бэк изменит методику расчёта — увеличить `aggregator_version`,
  клиент логирует это в analytics.

## Fallback

Клиент держит legacy-путь (3-12 запросов + клиентский precompute) на случай
если эндпоинт ещё не задеплоен или возвращает 5xx. После релиза эндпоинта
fallback можно убрать в следующем релизе приложения.
