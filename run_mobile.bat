@echo off
setlocal enableextensions
chcp 65001 > nul
set "BASE_DIR=%~dp0"

title Quran Center - Mobile App Launcher

echo ========================================================
echo   Quran Center - Mobile App Launcher
echo ========================================================
echo.

where dotnet > nul 2>&1
if %errorlevel% equ 0 (
    netstat -ano | findstr :5070 > nul
    if %errorlevel% neq 0 (
        start "Backend API (QuranCircles)" /min /D "%BASE_DIR%QuranCircles.Api\QuranCircles.Api" dotnet run --urls=http://localhost:5070
        ping 127.0.0.1 -n 3 > nul
    )
)

where flutter > nul 2>&1
if %errorlevel% equ 0 (
    cd /d "%BASE_DIR%QuranCircles.Mobile"
    call flutter run -d chrome
    goto done
)

start http://localhost:8000

:done
echo.
pause
