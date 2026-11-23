@echo off
chcp 65001 >nul
title Установка MPV Glass для Lampa

echo =========================================
echo    MPV ModernGlass + Lampa Setup
echo =========================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"

echo.
pause
