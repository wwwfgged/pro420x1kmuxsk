# update.ps1 - automatic install of the latest muzik420_lib_update*.zip
# (ASCII only on purpose: Windows PowerShell 5.1 breaks on UTF-8 without BOM)
#
# Usage:
#   .\update.ps1          copy files into both projects
#   .\update.ps1 -Push    ... and also git commit + push (starts nothing by itself;
#                         then press "Start new build" in Codemagic for the iOS IPA)

param([switch]$Push)

$ErrorActionPreference = "Stop"

# ---- edit once if your paths differ ----
$AndroidProject = "C:\muzik420"
$WindowsProject = "C:\muzik420_new"   # also the git repo that Codemagic builds iOS from
$DownloadsDir   = "$env:USERPROFILE\Downloads"
# ----------------------------------------

Write-Host "Looking for the newest muzik420_lib_update*.zip in $DownloadsDir ..." -ForegroundColor Cyan
$zip = Get-ChildItem -Path $DownloadsDir -Filter "muzik420_lib_update*.zip" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $zip) {
    Write-Host "No muzik420_lib_update*.zip found in $DownloadsDir" -ForegroundColor Red
    exit 1
}
Write-Host ("Found: " + $zip.Name + " (" + $zip.LastWriteTime + ")") -ForegroundColor Green

$extract = Join-Path $DownloadsDir "muzik420_update_tmp"
if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
Expand-Archive -Path $zip.FullName -DestinationPath $extract -Force

$libSrc = Join-Path $extract "lib"
if (-not (Test-Path $libSrc)) { Write-Host "No lib folder inside the archive" -ForegroundColor Red; exit 1 }

if (Test-Path $AndroidProject) {
    Copy-Item "$libSrc\*" -Destination (Join-Path $AndroidProject "lib") -Recurse -Force
    $pub = Join-Path $extract "pubspec.yaml"
    if (Test-Path $pub) { Copy-Item $pub -Destination (Join-Path $AndroidProject "pubspec.yaml") -Force }
    Write-Host "Android project updated" -ForegroundColor Green
} else { Write-Host "Android project not found: $AndroidProject (skipped)" -ForegroundColor Yellow }

if (Test-Path $WindowsProject) {
    Copy-Item "$libSrc\*" -Destination (Join-Path $WindowsProject "lib") -Recurse -Force
    $cm = Join-Path $extract "codemagic.yaml"
    if (Test-Path $cm) { Copy-Item $cm -Destination (Join-Path $WindowsProject "codemagic.yaml") -Force }
    Write-Host "Windows/iOS project updated (pubspec.yaml left untouched on purpose)" -ForegroundColor Green
    if ($Push) {
        Push-Location $WindowsProject
        git add -A
        git commit -m "update from archive"
        git push
        Pop-Location
        Write-Host "Pushed. Now press Start new build in Codemagic." -ForegroundColor Green
    }
} else { Write-Host "Windows project not found: $WindowsProject (skipped)" -ForegroundColor Yellow }

Write-Host ""
Write-Host "Done. Next:" -ForegroundColor Green
Write-Host "  Windows: cd $WindowsProject ; flutter pub get ; flutter run -d windows"
Write-Host "  Android: cd $AndroidProject ; flutter pub get ; flutter build apk --debug"
