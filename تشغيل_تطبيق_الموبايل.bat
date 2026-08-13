@echo off
setlocal enableextensions
set "BASE_DIR=%~dp0"

title Quran Center - Mobile App Launcher

echo ========================================================
echo   Quran Center - Mobile App Launcher (Flutter Web)
echo ========================================================
echo.

rem 1. Check API server on port 5070
netstat -ano | findstr :5070 > nul
if %errorlevel% neq 0 (
    echo [1/2] Starting Backend API on http://localhost:5070 ...
    start "Backend API (QuranCircles)" /min /D "%BASE_DIR%QuranCircles.Api\QuranCircles.Api" dotnet run --urls=http://localhost:5070
    ping 127.0.0.1 -n 5 > nul
) else (
    echo [1/2] Backend API is already running on port 5070.
)

rem 2. Launch Flutter App
echo [2/2] Launching Flutter Mobile App on Chrome...
echo.
cd /d "%BASE_DIR%QuranCircles.Mobile"
call flutter run -d chrome

pause



