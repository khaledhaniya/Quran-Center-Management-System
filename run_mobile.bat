@echo off
cd /d "%~dp0"
title Quran Center Mobile Launcher

echo ========================================================
echo   Quran Center - Mobile App Launcher
echo ========================================================
echo.

where flutter >nul 2>nul
if %errorlevel% equ 0 (
    echo Launching Flutter App on Chrome...
    cd /d "%~dp0QuranCircles.Mobile"
    flutter run -d chrome
) else (
    echo [Notice] Flutter SDK is not installed on this computer.
    echo Opening Web Application in Browser instead...
    start "" "%~dp0QuranCircles.Web\index.html"
)

echo.
pause
