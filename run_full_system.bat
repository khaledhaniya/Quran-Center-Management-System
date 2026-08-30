@echo off
cd /d "%~dp0"
chcp 65001 > nul
title Quran Center Full System

echo ========================================================
echo   [Al-Bayan Quran Center] - Launching Full System
echo ========================================================
echo.

where dotnet >nul 2>nul
if %errorlevel% equ 0 (
    netstat -ano | findstr :5070 >nul 2>nul
    if %errorlevel% neq 0 (
        echo [1/2] Starting Backend API (http://localhost:5070)...
        start "Backend API" /min cmd /c "cd /d "%~dp0QuranCircles.Api\QuranCircles.Api" && dotnet run --urls=http://localhost:5070"
        timeout /t 3 /nobreak >nul
    ) else (
        echo [1/2] Backend API is already running on port 5070.
    )
)

echo [2/2] Opening Web Application & Mobile in Browser...
start http://localhost:5070

rem If Flutter mobile build exists, open it in another tab
if exist "%~dp0QuranCircles.Mobile\build\web\index.html" (
    start http://localhost:5070/mobile/index.html
)

echo.
echo ========================================================
echo   System launched successfully!
echo   Main Web Portal: http://localhost:5070
echo ========================================================
echo.
pause
