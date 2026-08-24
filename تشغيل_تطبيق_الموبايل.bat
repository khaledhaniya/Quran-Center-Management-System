@echo off
cd /d "%~dp0"
title Quran Center Flutter Mobile Launcher

echo ========================================================
echo   Quran Center - Flutter Mobile App Launcher (Web)
echo ========================================================
echo.

where flutter >nul 2>nul
if %errorlevel% equ 0 (
    echo Launching Flutter App on Chrome...
    cd /d "%~dp0QuranCircles.Mobile"
    flutter run -d chrome
    goto done
)

echo [Info] Launching Compiled Flutter Mobile Web App on http://localhost:9000 ...

if exist "C:\xampp\php\php.exe" (
    start "Flutter Mobile Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Mobile\build\web" && C:\xampp\php\php.exe -S localhost:9000"
    timeout /t 2 >nul
    start http://localhost:9000
    goto done
)

where php >nul 2>nul
if %errorlevel% equ 0 (
    start "Flutter Mobile Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Mobile\build\web" && php -S localhost:9000"
    timeout /t 2 >nul
    start http://localhost:9000
    goto done
)

where python >nul 2>nul
if %errorlevel% equ 0 (
    start "Flutter Mobile Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Mobile\build\web" && python -m http.server 9000"
    timeout /t 2 >nul
    start http://localhost:9000
    goto done
)

where npx >nul 2>nul
if %errorlevel% equ 0 (
    start "Flutter Mobile Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Mobile\build\web" && npx -y serve -p 9000 ."
    timeout /t 2 >nul
    start http://localhost:9000
    goto done
)

start "" "%~dp0QuranCircles.Mobile\build\web\index.html"

:done
echo.
echo ========================================================
echo   Flutter Mobile App (Web) Opened on http://localhost:9000
echo ========================================================
echo.
pause
