@echo off
title Quran Center Mobile Launcher

echo Starting API and Flutter Mobile Web...

rem Start API if not already running
netstat -ano | findstr :5070 >nul 2>nul
if %errorlevel% neq 0 (
    start /min cmd /c "cd /d "%~dp0QuranCircles.Api\QuranCircles.Api" && dotnet run --urls=http://localhost:5070"
    timeout /t 3 /nobreak >nul
)

start "" "http://localhost:5070/mobile/index.html"
