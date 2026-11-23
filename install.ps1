# MPV Glass Lampa Setup Script
param (
    [switch]$PortableOnly,
    [switch]$InstallToAppData
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   MPV ModernGlass + Lampa Setup Script  " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Extract Portable Binaries if not already extracted
$mpvExe = Join-Path $scriptDir "mpv.exe"
$archive = Join-Path $scriptDir "bin\mpv-portable.7z"

if (-not (Test-Path $mpvExe)) {
    if (Test-Path $archive) {
        Write-Host "[1/3] Извлечение портативной сборки MPV..." -ForegroundColor Yellow
        tar -xf $archive -C $scriptDir
        if (Test-Path $mpvExe) {
            Write-Host "      Готово! mpv.exe успешно извлечен." -ForegroundColor Green
        } else {
            Write-Host "      Ошибка при распаковке архива." -ForegroundColor Red
        }
    } else {
        Write-Host "[!] Архив bin\mpv-portable.7z не найден." -ForegroundColor Red
    }
} else {
    Write-Host "[1/3] Портативный mpv.exe уже присутствует в папке." -ForegroundColor Green
}

# 2. Copy to %APPDATA%\mpv if requested
if ($InstallToAppData) {
    Write-Host "[2/3] Установка конфигурации в %APPDATA%\mpv..." -ForegroundColor Yellow
    $appdataMpv = "$env:APPDATA\mpv"
    $configSource = Join-Path $scriptDir "portable_config"
    
    New-Item -ItemType Directory -Force -Path "$appdataMpv\fonts" | Out-Null
    New-Item -ItemType Directory -Force -Path "$appdataMpv\scripts" | Out-Null
    New-Item -ItemType Directory -Force -Path "$appdataMpv\script-opts" | Out-Null

    Copy-Item "$configSource\mpv.conf" "$appdataMpv\mpv.conf" -Force
    Copy-Item "$configSource\input.conf" "$appdataMpv\input.conf" -Force
    Copy-Item "$configSource\fonts\*" "$appdataMpv\fonts\" -Force
    Copy-Item "$configSource\scripts\*" "$appdataMpv\scripts\" -Force
    Copy-Item "$configSource\script-opts\*" "$appdataMpv\script-opts\" -Force
    Write-Host "      Готово! Конфигурация скопирована в $appdataMpv" -ForegroundColor Green
} else {
    Write-Host "[2/3] Конфигурация готова в режиме Portable (папка portable_config)." -ForegroundColor Green
}

# 3. Output Lampa instructions
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "      Настройка в Lampa Desktop:         " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "1. Откройте приложение Lampa Desktop."
Write-Host "2. Перейдите в: Настройки -> Плеер."
Write-Host "3. В пункте 'Тип плеера' выберите: 'Другой'."
Write-Host "4. В поле 'Путь к плееру' укажите следующий путь:"
Write-Host "   $mpvExe" -ForegroundColor Yellow
Write-Host "5. Нажмите Enter и запускайте фильмы/сериалы!"
Write-Host "=========================================" -ForegroundColor Cyan
