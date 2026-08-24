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

echo [2/3] Opening Web Application on http://localhost:8000 ...
if exist "C:\xampp\php\php.exe" (
    start "Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Web" && C:\xampp\php\php.exe -S localhost:8000"
    timeout /t 1 >nul
    start http://localhost:8000
) else (
    where php >nul 2>nul
    if %errorlevel% equ 0 (
        start "Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Web" && php -S localhost:8000"
        timeout /t 1 >nul
        start http://localhost:8000
    )
)

echo [3/3] Opening Flutter Mobile App (Web) on http://localhost:9000 ...
if exist "C:\xampp\php\php.exe" (
    start "Flutter Mobile Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Mobile\build\web" && C:\xampp\php\php.exe -S localhost:9000"
    timeout /t 1 >nul
    start http://localhost:9000
) else (
    where php >nul 2>nul
    if %errorlevel% equ 0 (
        start "Flutter Mobile Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Mobile\build\web" && php -S localhost:9000"
        timeout /t 1 >nul
        start http://localhost:9000
    ) else (
        start "" "%~dp0QuranCircles.Mobile\build\web\index.html"
    )
)

echo.
echo ========================================================
echo   All Systems Launched Successfully!
echo   Admin/Teacher Web: http://localhost:8000
echo   Flutter Mobile Web: http://localhost:9000
echo ========================================================
echo.
pause
