# App Config Contract

iOS-приложение запрашивает серверный конфиг при старте, чтобы менять поведение
без релиза в App Store. Этот документ — контракт между бэкендом и клиентом.

## Endpoint

```
GET /api/app-config/?platform=ios&version=<short-version>
```

С каждым запросом приложение шлёт заголовки:

```
X-Guest-UUID:    <uuid>            (если есть гость-сессия)
X-App-Version:   1.0.0             (CFBundleShortVersionString)
X-App-Build:     1                 (CFBundleVersion)
X-Platform:      ios
X-OS-Version:    17.4
X-Device-Model:  iPhone
```

Бэкенд может использовать эти заголовки чтобы выдавать разные конфиги для
разных версий клиента (например, скрывать новую фичу для старых билдов).

## Response shape

Все поля — **опциональные**. Клиент держит fallback на случай отсутствия конфига
или поля. Бэкенду достаточно вернуть только то, что нужно изменить.

```json
{
  "min_supported_version": "1.0.0",
  "recommended_version": "1.1.0",
  "app_store_url": "https://apps.apple.com/app/idXXXXXXXXX",

  "maintenance": {
    "enabled": false,
    "message": "Скоро вернёмся, чиним обновление цен.",
    "ends_at": "2026-05-01T12:00:00Z"
  },

  "chain_colors": {
    "galmart": "#33C68C",
    "toimart": "#FF6BA7",
    "small":   "#B373FF",
    "mgo":     "#F24D4D"
  },

  "popular_brands": [
    { "name": "Coca-Cola",     "emoji": "🥤", "logo_url": null },
    { "name": "Rakhat",        "emoji": "🍫", "logo_url": null },
    { "name": "Простоквашино", "emoji": "🥛", "logo_url": "https://backend.minprice.kz/media/brands/prostokvashino.png" }
  ],

  "home_banners": [
    {
      "slug": "fresh-week",
      "title": "Неделя овощей",
      "subtitle": "До -30% в Galmart и Arbuz",
      "action_url": "minprice://category/vegetables",
      "image_url": "https://backend.minprice.kz/media/banners/fresh-week.jpg",
      "background_color": "#33C68C"
    }
  ],

  "features": {
    "store_basket_chart":   true,
    "price_history_chart":  true,
    "discounts_tab":        true,
    "widget_sync":          true,
    "barcode_scanner":      true,
    "price_alerts":         true,
    "cart_transfer":        true
  },

  "copy": {
    "onboarding_title":    "Сравнивайте цены — экономьте на каждой покупке",
    "onboarding_subtitle": "Каталог из MagnumGO, Arbuz, Airba Fresh, Small, Galmart, Toimart",
    "empty_cart_message":  "Добавляйте товары из поиска или каталога"
  },

  "config_version": 1
}
```

## Семантика полей

### Версионирование

| Поле | Эффект |
|---|---|
| `min_supported_version` | Если `currentVersion < min` — показываем блокирующий экран "Обновите приложение" со ссылкой `app_store_url`. Пользователь не может пользоваться приложением. |
| `recommended_version` | Если `currentVersion < recommended` — показываем мягкий баннер "Доступно обновление". Пользователь может закрыть. |
| `app_store_url` | Прямая ссылка на страницу в App Store. |

Используем при критических багах, секьюрити-патчах, или когда новая версия имеет
несовместимый API-контракт со старой.

### Maintenance

При `maintenance.enabled = true` всё приложение блокируется экраном
"Технические работы" с сообщением. Используем для краткосрочных bx-окон
(апгрейд БД, миграции). `ends_at` пока показывается пользователю — клиент
не парсит автоматически.

### `chain_colors`

Цвет сети по `chain_slug` в формате `#RRGGBB` или `#RRGGBBAA`. Перебивает
хардкод `BrandPalette.storeColor`. Используем когда добавляем новую сеть и
хотим, чтобы её цвет появился у всех пользователей сразу — без релиза.

### `popular_brands`

Полностью заменяет встроенный список популярных брендов на экране Каталога.
Если backend вернул пустой массив или поле отсутствует — используется
fallback из приложения (8 захардкоженных). Если хочется временно скрыть
эту секцию — отдать пустой объект бренда не получится; нужен флаг
`features.popular_brands_strip = false` (можно добавить позже).

### `home_banners`

Промо-блоки на главной (пока не реализовано в UI — поле зарезервировано).
`action_url` — deeplink (`minprice://product/UUID`, `minprice://category/<slug>`)
или https-ссылка.

### `features`

Булевые feature-флаги. Ключи — `AppConfig.FeatureFlag`. Если ключ отсутствует
— дефолт `true` (фича включена).

| Флаг | Что отключает |
|---|---|
| `store_basket_chart` | Большой график-корзина на главной |
| `price_history_chart` | График истории цен на странице товара |
| `discounts_tab` | Вкладка "Скидки" в нижнем таб-баре |
| `widget_sync` | Синхронизация виджетов через App Group |
| `barcode_scanner` | Кнопка сканера штрихкодов |
| `price_alerts` | Уведомления при снижении цен в избранном |
| `cart_transfer` | Кнопка "открыть корзину в магазине" (Wolt deeplink) |

### `copy`

Тексты с заведомо известными ключами, которые могут понадобиться обновлять
быстро (онбординг, EmptyState, тексты ошибок). Клиент использует
`config.text(key, default:)`.

### `config_version`

Просто счётчик. Полезен для логов на стороне клиента (можно понять, что
конфиг обновился) и для диагностики.

## Кэширование

Клиент:
1. При старте сразу читает кэш из `UserDefaults` (`app_config_cache_v1`).
2. Параллельно делает сетевой запрос. На успех — обновляет кэш.
3. Если сеть недоступна — продолжает работать с кэшем или встроенным fallback.

TTL не используется — клиент всегда стартует с кэша и сразу же делает
запрос на бэк. Это даёт мгновенный UI без блокирующего лоадера в большинстве
случаев. Чтобы изменения "приехали" пользователю, ему нужно перезапустить
приложение (или мы можем добавить refresh при `scenePhase == .active`).

## Минимальный безопасный ответ

Если бэкенду нечего сообщить, можно вернуть пустой объект:

```json
{}
```

Все поля опциональны, клиент применит значения по умолчанию (все фичи
включены, никаких баннеров, версионных ограничений нет).
