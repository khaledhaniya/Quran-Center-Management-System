@echo off
setlocal
cd /d "%~dp0"
title Al-Bayan Quran Mobile App Launcher

echo ========================================================
echo   Starting Al-Bayan Quran Mobile Application...
echo ========================================================
echo.

rem 1. Check if backend API is running on port 5070
netstat -aon | findstr :5070 | findstr LISTENING >nul 2>&1
if %errorlevel% neq 0 (
    echo [1/2] Server is not running. Starting Server on http://localhost:5070 ...
    where dotnet >nul 2>nul
    if %errorlevel% neq 0 (
        echo [ERROR] .NET SDK is not installed or not in PATH!
        pause
        exit /b 1
    )
    start "Al-Bayan Server" /D "%~dp0QuranCircles.Api\QuranCircles.Api" cmd /k "dotnet run --urls=http://localhost:5070"
    echo Initializing database and mobile app build...
    ping 127.0.0.1 -n 5 >nul
) else (
    echo [1/2] Server is already active on http://localhost:5070
)

rem 2. Open Mobile Web interface
echo [2/2] Launching Mobile App in your browser...
start http://localhost:5070/mobile/index.html

echo.
echo ========================================================
echo   Mobile App is running successfully!
echo   URL: http://localhost:5070/mobile/index.html
echo ========================================================
echo.
pause
