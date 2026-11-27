@echo off
setlocal
chcp 65001 >nul
title Установка MPV Glass для Lampa

echo =========================================
echo    MPV ModernGlass + Lampa Setup
echo =========================================
echo.

if exist "%~dp0mpv.exe" goto ready
if not exist "%~dp0bin\mpv-portable.7z" goto failed
"%SystemRoot%\System32\tar.exe" -xf "%~dp0bin\mpv-portable.7z" -C "%~dp0."
if errorlevel 1 goto failed
if not exist "%~dp0mpv.exe" goto failed

:ready
echo Плеер готов: "%~dp0mpv.exe"
echo Инструкция по подключению Lampa и расширения находится в README.md.
echo.
pause
exit /b 0

:failed
echo Не удалось распаковать плеер. Распакуйте bin\mpv-portable.7z вручную в эту папку.
pause
exit /b 1
