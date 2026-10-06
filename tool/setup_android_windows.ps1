$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Temp = Join-Path $env:TEMP "intention_mobile_platform_template"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw "Flutter PATH да топилмади. Аввал Flutter 3.47+ ни ўрнатинг."
}

if (Test-Path $Temp) { Remove-Item $Temp -Recurse -Force }
flutter create --platforms=android --org uz.intention --project-name intention_mobile $Temp
if (Test-Path (Join-Path $Root "android")) { Remove-Item (Join-Path $Root "android") -Recurse -Force }
Copy-Item (Join-Path $Temp "android") (Join-Path $Root "android") -Recurse
Remove-Item $Temp -Recurse -Force

$GradleKts = Join-Path $Root "android\app\build.gradle.kts"
if (Test-Path $GradleKts) {
  $Text = Get-Content $GradleKts -Raw
  $Text = $Text -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23'
  Set-Content $GradleKts $Text -Encoding UTF8
}
$Gradle = Join-Path $Root "android\app\build.gradle"
if (Test-Path $Gradle) {
  $Text = Get-Content $Gradle -Raw
  $Text = $Text -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 23'
  Set-Content $Gradle $Text -Encoding UTF8
}

Push-Location $Root
flutter pub get
Pop-Location
Write-Host "Android platform тайёр. Кейин: flutter build apk --release" -ForegroundColor Green
