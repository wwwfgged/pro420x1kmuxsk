# update.ps1 — автоматичне встановлення оновлення pro420x1kmuxsk
#
# Що робить:
#   1. Знаходить найновіший muzik420_lib_update*.zip у Downloads
#   2. Розпаковує його
#   3. Копіює lib/* в обидва проєкти (Android + Windows)
#   4. Копіює pubspec.yaml ТІЛЬКИ в Android-проєкт (Windows має інший)
#   5. Якщо в архіві є manifest_new.xml / native_splash/* — підказує,
#      що їх треба поставити вручну (це рідкісні, "небезпечні" файли,
#      автоматично їх не чіпаємо, щоб не затерти щось важливе)
#
# Використання:
#   Просто запусти:  .\update.ps1
#   (з будь-якої теки — шляхи нижче абсолютні)

$ErrorActionPreference = "Stop"

# ==== НАЛАШТУЙ ОДИН РАЗ ПІД СЕБЕ, ЯКЩО ШЛЯХИ ІНШІ ====
$AndroidProject = "C:\muzik420"
$WindowsProject = "C:\muzik420_new"
$DownloadsDir   = "$env:USERPROFILE\Downloads"
# ======================================================

Write-Host "🔍 Шукаю останній архів оновлення в $DownloadsDir ..." -ForegroundColor Cyan

$zip = Get-ChildItem -Path $DownloadsDir -Filter "muzik420_lib_update*.zip" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $zip) {
    Write-Host "❌ Не знайшов жодного muzik420_lib_update*.zip у $DownloadsDir" -ForegroundColor Red
    Write-Host "   Завантаж архів і поклади його в Downloads, потім запусти скрипт ще раз." -ForegroundColor Yellow
    exit 1
}

Write-Host "📦 Знайдено: $($zip.Name) ($([math]::Round($zip.Length/1KB)) КБ, $($zip.LastWriteTime))" -ForegroundColor Green

$extractPath = Join-Path $DownloadsDir ("muzik420_update_" + [System.IO.Path]::GetFileNameWithoutExtension($zip.Name))
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
Expand-Archive -Path $zip.FullName -DestinationPath $extractPath -Force

Write-Host "📂 Розпаковано в $extractPath" -ForegroundColor Green

$libSource = Join-Path $extractPath "lib"
if (-not (Test-Path $libSource)) {
    Write-Host "❌ У архіві немає папки lib\ — щось не так з файлом." -ForegroundColor Red
    exit 1
}

# ---- Android ----
if (Test-Path $AndroidProject) {
    $androidLib = Join-Path $AndroidProject "lib"
    Write-Host "📱 Копіюю lib\ в Android-проєкт ($androidLib) ..." -ForegroundColor Cyan
    Copy-Item "$libSource\*" -Destination $androidLib -Recurse -Force

    $pubspecSource = Join-Path $extractPath "pubspec.yaml"
    if (Test-Path $pubspecSource) {
        Write-Host "📱 Копіюю pubspec.yaml в Android-проєкт ..." -ForegroundColor Cyan
        Copy-Item $pubspecSource -Destination (Join-Path $AndroidProject "pubspec.yaml") -Force
    }
    Write-Host "✅ Android-проєкт оновлено" -ForegroundColor Green
} else {
    Write-Host "⚠️  Android-проєкт не знайдено за шляхом $AndroidProject — пропускаю" -ForegroundColor Yellow
}

# ---- Windows ----
if (Test-Path $WindowsProject) {
    $windowsLib = Join-Path $WindowsProject "lib"
    Write-Host "🖥️  Копіюю lib\ в Windows-проєкт ($windowsLib) ..." -ForegroundColor Cyan
    Copy-Item "$libSource\*" -Destination $windowsLib -Recurse -Force
    # pubspec.yaml НЕ копіюємо сюди навмисно — у Windows-проєкту інший
    # набір залежностей (window_manager вже нативний, без Android-пакетів).
    Write-Host "✅ Windows-проєкт оновлено (pubspec.yaml НЕ чіпали навмисно)" -ForegroundColor Green
} else {
    Write-Host "⚠️  Windows-проєкт не знайдено за шляхом $WindowsProject — пропускаю" -ForegroundColor Yellow
}

# ---- Додаткові файли (маніфест/нативний splash) — тільки попередження ----
$manifestFile = Join-Path $extractPath "manifest_new.xml"
$nativeSplashDir = Join-Path $extractPath "native_splash"
if ((Test-Path $manifestFile) -or (Test-Path $nativeSplashDir)) {
    Write-Host ""
    Write-Host "ℹ️  В архіві є додаткові файли, які НЕ копіюються автоматично" -ForegroundColor Yellow
    Write-Host "   (це нативні Android-ресурси, їх краще ставити вручну щоразу, коли вони змінюються):" -ForegroundColor Yellow
    if (Test-Path $manifestFile) { Write-Host "   - manifest_new.xml -> android\app\src\main\AndroidManifest.xml" -ForegroundColor Yellow }
    if (Test-Path $nativeSplashDir) { Write-Host "   - native_splash\*  -> android\app\src\main\res\..." -ForegroundColor Yellow }
    Write-Host "   Дивись останні інструкції в чаті, якщо треба поставити саме ці файли." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 Готово! Тепер:" -ForegroundColor Green
Write-Host "   Android:  cd $AndroidProject; flutter clean; flutter pub get; flutter build apk --debug"
Write-Host "   Windows:  cd $WindowsProject; flutter pub get; flutter run -d windows"
