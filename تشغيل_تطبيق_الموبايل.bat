@echo off
cd /d "%~dp0"
title Quran Center Flutter Mobile Launcher

echo ========================================================
echo   Quran Center - Flutter Mobile App Launcher (Web)
echo ========================================================
echo.
echo Starting Flutter Mobile Web on http://localhost:9000 ...

start "Flutter Mobile Server (Port 9000)" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1" -Port 9000 -Path "%~dp0QuranCircles.Mobile\build\web"

timeout /t 2 >nul
start http://localhost:9000

echo.
echo ========================================================
echo   Flutter Mobile App (Web) is now Running on:
echo   http://localhost:9000
echo ========================================================
echo.
pause
