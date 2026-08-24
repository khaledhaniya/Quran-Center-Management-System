@echo off
cd /d "%~dp0"
title Quran Center Launcher

echo ========================================================
echo   Starting Quran Center System (Localhost:8000)...
echo ========================================================
echo.

where dotnet >nul 2>nul
if %errorlevel% equ 0 (
    echo [1/2] Starting Backend API on http://localhost:5070 ...
    start "Backend API" /min cmd /c "cd /d "%~dp0QuranCircles.Api\QuranCircles.Api" && dotnet run --urls=http://localhost:5070"
)

echo [2/2] Starting Web Application Server on http://localhost:8000 ...

start "Quran Web Server (Port 8000)" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1" -Port 8000 -Path "%~dp0QuranCircles.Web"

timeout /t 2 >nul
start http://localhost:8000

echo.
echo ========================================================
echo   Quran Center Web Application Launched Successfully!
echo   Local Web URL: http://localhost:8000
echo ========================================================
echo.
pause
