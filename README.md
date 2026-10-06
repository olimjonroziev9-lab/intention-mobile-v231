# V2.3.1 Internet permission fix

Release APK учун `android.permission.INTERNET` автоматик қўшилади. Бу `SocketException: Failed host lookup` хатосини тузатади.

# Intention School Mobile — MVP 0.1

Android ва iPhone учун Flutter мобил клиент. Сервер сифатида мавжуд PHP/MySQL сайтнинг Mobile API V1 қисми ишлатилади.

## Сервер

API base:

`https://www.intentiontest.helioho.st/api/v1/mobile/`

Мобил иловага MySQL пароли, Telegram Bot Token ёки relay secret киритилмайди. Фақат HTTPS API билан ишлайди.

## Тайёр функциялар

### Ўқувчи
- сайтдаги логин/парол билан кириш;
- тестлар рўйхати;
- тест маълумоти;
- тестни бошлаш ва давом эттириш;
- сервер deadline асосида таймер;
- choice ва short-answer жавоблари;
- тестни якунлаш;
- балл, фоиз ва баҳони кўриш;
- натижалар тарихи;
- Telegram аккаунтини ботга боғлаш/узиш.

### Ассистент
- ўзига бириктирилган синфлар;
- кунлик статистика;
- Келди / Келмади / Кечикди;
- ҳар ўқувчига изоҳ;
- бутун синф давоматини битта сўровда сақлаш;
- Telegram канал ёки Telegram ID га вертикал ҳисобот юбориш.

### Ўқитувчи
- бириктирилган синф + фанлар;
- сана ва дарс рақами бўйича журнал;
- Ассистент давоматини алоҳида кўриш;
- Устоз давоматини мустақил белгилаш;
- 2–5 баҳо;
- изоҳ ва дарс мавзуси;
- давомат фарқи кўрсаткичи;
- журнал тарихи ва ўртача баҳо.

### Админ / Методист
Биринчи MVP да профил ишлайди, тўлиқ бошқарув ҳозирча веб-сайтда қолади.

## Талаб қилинади

- Flutter stable 3.47+ (2026-08 stable линияси)
- Dart 3.8+
- Android 6.0 / API 23+
- iOS 12+

Ишлатилади:
- `http ^1.6.0`
- `flutter_secure_storage ^11.2.0`
- `url_launcher ^6.3.2`

## 1. Серверни тайёрлаш

Аввал веб-сайтга `intentiontest_mobile_api_v1_patch.zip` ўрнатилган ва `mobile-api-v1-upgrade.sql` импорт қилинган бўлиши керак.

Браузерда текширинг:

`https://www.intentiontest.helioho.st/api/v1/mobile/health`

`ok: true` қайтиши керак.

## 2. Windows — Android платформани яратиш

PowerShell:

```powershell
cd intention_mobile
Set-ExecutionPolicy -Scope Process Bypass
.\tool\setup_android_windows.ps1
flutter run
```

Release APK:

```powershell
flutter build apk --release
```

Натижа одатда:

`build\app\outputs\flutter-apk\app-release.apk`

Google Play учун:

```powershell
flutter build appbundle --release
```

## 3. macOS — Android + iPhone

```bash
cd intention_mobile
./tool/setup_platforms_unix.sh
flutter run
```

### iOS Secure Storage

`flutter_secure_storage` учун Xcode да Runner target → Signing & Capabilities → `+ Capability` → **Keychain Sharing** қўшинг.

Сўнг:

```bash
flutter build ipa --release
```

Apple signing / Developer account алоҳида керак бўлади.

## 4. Хавфсизлик

- API token secure storage да сақланади.
- Token серверда фақат SHA-256 hash кўринишида сақланади.
- Token 30 кун амал қилади.
- Logout token'ни серверда revoke қилади.
- Correct answers active test вақтида API дан берилмайди.
- Мобил илова database'га тўғридан-тўғри уланмайди.

## 5. Кейинги босқич

MVP синовдан ўтгач қўшиш мумкин:
- push notification (Firebase/APNs);
- Admin мобил панели;
- biometric/PIN app lock;
- офлайн давомат queue;
- логотип ва branded launcher icon;
- Play Store / App Store release signing.
