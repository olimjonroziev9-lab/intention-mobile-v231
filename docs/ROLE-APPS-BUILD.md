# Role-specific Android apps

The same Flutter source can build six separate role-locked applications. The server still verifies the real role; the app also refuses a login whose role does not match `APP_ROLE`.

After generating Android platform files (`flutter create .` if needed), build with:

```bash
flutter build apk --release --dart-define=APP_ROLE=admin --dart-define="APP_NAME=Intention Admin"
flutter build apk --release --dart-define=APP_ROLE=teacher --dart-define="APP_NAME=Intention Teacher"
flutter build apk --release --dart-define=APP_ROLE=assistant --dart-define="APP_NAME=Intention Assistant"
flutter build apk --release --dart-define=APP_ROLE=student --dart-define="APP_NAME=Intention Student"
flutter build apk --release --dart-define=APP_ROLE=parent --dart-define="APP_NAME=Intention Parent"
flutter build apk --release --dart-define=APP_ROLE=methodologist --dart-define="APP_NAME=Intention Methodologist"
```

For simultaneous installation of all six APKs on one phone, create Android product flavors with distinct `applicationIdSuffix` values after generating the Android project. The role lock above is already implemented in Dart and remains the same for every flavor.
