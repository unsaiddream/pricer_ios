# iOS Release Checklist

Чек-лист перед уплоадом в App Store Connect / TestFlight.

## 1. Sentry DSN

Crash-reporting подключён через Sentry SDK. DSN читается из Info.plist
по ключу `SENTRY_DSN`, который подставляется из Build Setting `SENTRY_DSN`.

### Локально (Xcode)

1. Зарегистрироваться на https://sentry.io (или поднять self-hosted).
2. Создать проект `minprice-ios` (платформа: iOS).
3. Скопировать DSN вида `https://abc...@o000000.ingest.sentry.io/0000000`.
4. В Xcode:
   - Открыть `MinPrice.xcodeproj`
   - Target `MinPrice` → Build Settings → Search `SENTRY_DSN`
   - Заменить пустую строку на свой DSN
5. Пересобрать. В консоли при первом запуске будет `Log.debug("Sentry: ..."`)
   если что-то не так. Иначе SDK молчит.

Проверить работу: где-то в коде временно вызвать
```swift
CrashReporter.captureMessage("Hello from MinPrice", level: .info)
```
В Sentry-проекте появится событие через ~30 сек.

### CI / TestFlight

Лучше не коммитить DSN в репо. Прокидывать через ENV в xcodebuild:

```bash
xcodebuild ... SENTRY_DSN="https://...@sentry.io/..."
```

Или через xcconfig-файл, который не в git'е:

```ini
# Secrets.xcconfig (gitignored)
SENTRY_DSN = https:/$()/abc@o000.ingest.sentry.io/0000
```

Без подстановки `/$()/` Xcode съедает `//` в URL — известная проблема.

## 2. App Store Connect

После создания app listing'а:

1. **Bundle ID**: `kz.minprice.app` (уже в project.yml)
2. **App Privacy** анкета — данные взять из `MinPrice/Resources/PrivacyInfo.xcprivacy`:
   - Tracking: No
   - Crash data, performance data — collected, not linked, not used for tracking
3. **App Store URL** после публикации: добавить в env бэкенда
   `MINPRICE_IOS_APP_STORE_URL=https://apps.apple.com/...` и сделать
   `redis-cli DEL "app_config:v1:ios"` чтобы изменения подъехали в течение секунд.
4. **Privacy Policy URL** — обязательно
5. **Support URL** — обязательно

## 3. Версии

- `MARKETING_VERSION` (CFBundleShortVersionString) — поднимать на каждый
  пользовательский релиз: 1.0.0 → 1.0.1 → 1.1.0
- `CURRENT_PROJECT_VERSION` (CFBundleVersion) — поднимать на каждый билд
  для TestFlight: 1 → 2 → 3 → ...
- На бэкенде (env): после релиза с breaking-change-API
  `MINPRICE_IOS_MIN_VERSION=1.x.0` блокирует старые версии force-update'ом.

## 4. Pre-flight smoke test

Перед каждым TestFlight upload:

```
✅ xcodebuild -scheme MinPrice -configuration Release build  → BUILD SUCCEEDED
✅ Просканировать штрихкод → permission alert на русском
✅ Поделиться графиком корзины → permission alert на русском
✅ Выключить Wi-Fi → "Нет соединения" банер сверху, не падает
✅ Холодный запуск → onboarding на первом запуске, дашборд на втором
✅ Force-update тест: в env поднять `MINPRICE_IOS_MIN_VERSION=99.0.0` →
   при следующем запуске показывается ForceUpdateView. Откатить.
```
