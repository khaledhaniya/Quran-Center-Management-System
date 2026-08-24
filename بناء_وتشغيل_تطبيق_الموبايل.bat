@echo off
cd /d "%~dp0QuranCircles.Mobile"
title Building and Running Latest Flutter Mobile Web

echo ========================================================
echo   Building Latest Flutter Mobile App for Web...
echo ========================================================
echo.

where flutter >nul 2>nul
if %errorlevel% equ 0 (
    echo Compiling latest Dart code and screens to Web...
    flutter build web
    if %errorlevel% equ 0 (
        echo.
        echo [Success] Flutter Web Build finished!
    ) else (
        echo [Warning] Build error occurred. Trying to run live Chrome mode...
        flutter run -d chrome
        goto done
    )
) else (
    echo [Notice] Flutter command not found in global path.
    echo Please make sure Flutter SDK is installed and added to PATH.
)

cd /d "%~dp0"
echo Starting Web Server for Flutter Mobile on http://localhost:9000 ...
start "Flutter Mobile Server" /min powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1" -Port 9000 -Path "%~dp0QuranCircles.Mobile\build\web"

timeout /t 2 >nul
start http://localhost:9000

:done
echo.
echo ========================================================
echo   Done! Check your browser at http://localhost:9000
echo ========================================================
echo.
pause
