#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/intention_mobile_platform_template"
command -v flutter >/dev/null 2>&1 || { echo "Flutter топилмади. Flutter 3.47+ ни ўрнатинг."; exit 1; }
rm -rf "$TMP"
if [[ "$(uname -s)" == "Darwin" ]]; then
  flutter create --platforms=android,ios --org uz.intention --project-name intention_mobile "$TMP"
else
  flutter create --platforms=android --org uz.intention --project-name intention_mobile "$TMP"
fi
rm -rf "$ROOT/android" "$ROOT/ios"
cp -R "$TMP/android" "$ROOT/android"
if [[ -d "$TMP/ios" ]]; then cp -R "$TMP/ios" "$ROOT/ios"; fi
rm -rf "$TMP"
MANIFEST="$ROOT/android/app/src/main/AndroidManifest.xml"
if [[ -f "$MANIFEST" ]] && ! grep -q 'android.permission.INTERNET' "$MANIFEST"; then
  sed -i.bak 's#<manifest xmlns:android="http://schemas.android.com/apk/res/android">#<manifest xmlns:android="http://schemas.android.com/apk/res/android">\
    <uses-permission android:name="android.permission.INTERNET" />#' "$MANIFEST"
  rm -f "$MANIFEST.bak"
fi
if [[ -f "$ROOT/android/app/build.gradle.kts" ]]; then
  sed -i.bak 's/minSdk = flutter.minSdkVersion/minSdk = 23/' "$ROOT/android/app/build.gradle.kts" || true
  rm -f "$ROOT/android/app/build.gradle.kts.bak"
fi
if [[ -f "$ROOT/android/app/build.gradle" ]]; then
  sed -i.bak 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 23/' "$ROOT/android/app/build.gradle" || true
  rm -f "$ROOT/android/app/build.gradle.bak"
fi
cd "$ROOT"
flutter pub get
echo "Platform тайёр. Android: flutter build apk --release"
if [[ "$(uname -s)" == "Darwin" ]]; then echo "iOS учун README даги Keychain Sharing қадамини бажаринг."; fi
