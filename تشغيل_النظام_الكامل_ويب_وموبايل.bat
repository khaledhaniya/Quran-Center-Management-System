@echo off
cd /d "%~dp0"
title Quran Center Full System Launcher

echo ========================================================
echo   Launching Quran Center (Web + Mobile + API)...
echo ========================================================
echo.

where dotnet >nul 2>nul
if %errorlevel% equ 0 (
    echo [1/3] Starting Backend API on http://localhost:5070 ...
    start "Backend API" /min cmd /c "cd /d "%~dp0QuranCircles.Api\QuranCircles.Api" && dotnet run --urls=http://localhost:5070"
)

echo [2/3] Starting Web Application on http://localhost:8000 ...
start "Quran Web Server (Port 8000)" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1" -Port 8000 -Path "%~dp0QuranCircles.Web"
timeout /t 1 >nul
start http://localhost:8000

echo [3/3] Starting Flutter Mobile App (Web) on http://localhost:9000 ...
start "Flutter Mobile Server (Port 9000)" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1" -Port 9000 -Path "%~dp0QuranCircles.Mobile\build\web"
timeout /t 1 >nul
start http://localhost:9000

echo.
echo ========================================================
echo   All Systems Launched Successfully!
echo   Admin/Teacher Web: http://localhost:8000
echo   Flutter Mobile Web: http://localhost:9000
echo ========================================================
echo.
pause
