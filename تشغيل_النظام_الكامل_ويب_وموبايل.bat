@echo off
setlocal enableextensions
set "BASE_DIR=%~dp0"

title Quran Center - Full System Launcher (Web + Mobile)

echo ========================================================
echo   Quran Center - Full System Launcher (Web + Mobile)
echo ========================================================
echo.

rem 1. Start Backend API
echo [1/3] Starting Backend API Server (http://localhost:5070)...
netstat -ano | findstr :5070 > nul
if %errorlevel% neq 0 (
    start "Backend API (QuranCircles)" /min /D "%BASE_DIR%QuranCircles.Api\QuranCircles.Api" dotnet run --urls=http://localhost:5070
    timeout /t 5 /nobreak > nul
) else (
    echo Backend API is already running on port 5070.
)

rem 2. Start Web Frontend
echo [2/3] Starting Web Portal (http://localhost:8000)...
start "Web Portal (QuranCircles)" /min /D "%BASE_DIR%QuranCircles.Web" php -S localhost:8000
start http://localhost:8000

rem 3. Start Mobile App on Chrome
echo [3/3] Starting Mobile App on Chrome...
start "Mobile App Chrome (QuranCircles)" /D "%BASE_DIR%QuranCircles.Mobile" flutter run -d chrome

echo.
echo ========================================================
echo   Full system launched successfully!
echo   - Web Portal: http://localhost:8000
echo   - API Server: http://localhost:5070
echo   - Mobile App: Opening in Chrome...
echo ========================================================
ping 127.0.0.1 -n 4 > nul
