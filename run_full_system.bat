@echo off
cd /d "%~dp0"
title Quran Center Full System

echo ========================================================
echo   Launching Quran Center (Web + Mobile + API)...
echo ========================================================
echo.

where dotnet >nul 2>nul
if %errorlevel% equ 0 (
    echo [1/3] Starting Backend API on http://localhost:5070 ...
    start "Backend API" /min cmd /c "cd /d "%~dp0QuranCircles.Api\QuranCircles.Api" && dotnet run --urls=http://localhost:5070"
)

echo [2/3] Opening Web Application...
where php >nul 2>nul
if %errorlevel% equ 0 (
    start "Web Server (PHP)" /min cmd /c "cd /d "%~dp0QuranCircles.Web" && php -S localhost:8000"
    timeout /t 2 >nul
    start http://localhost:8000
) else (
    start "" "%~dp0QuranCircles.Web\index.html"
)

echo [3/3] Checking Flutter Mobile App...
where flutter >nul 2>nul
if %errorlevel% equ 0 (
    echo Launching Flutter App on Chrome...
    start "Flutter Mobile" cmd /c "cd /d "%~dp0QuranCircles.Mobile" && flutter run -d chrome"
) else (
    echo [Notice] Flutter SDK not installed on this machine yet.
    echo Opened Web Portal instead.
)

echo.
echo ========================================================
echo   System launched!
echo ========================================================
echo.
pause
