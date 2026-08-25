@echo off
setlocal enableextensions
chcp 65001 > nul
set "BASE_DIR=%~dp0"

title Quran Center - Mobile App Launcher (Flutter)

echo ========================================================
echo   Quran Center - Mobile App Launcher (Flutter)
echo ========================================================
echo.

where dotnet > nul 2>&1
if %errorlevel% equ 0 (
    netstat -ano | findstr :5070 > nul
    if %errorlevel% neq 0 (
        start "Backend API (QuranCircles)" /min /D "%BASE_DIR%QuranCircles.Api\QuranCircles.Api" dotnet run --urls=http://localhost:5070
        ping 127.0.0.1 -n 3 > nul
    )
)

set "FLUTTER_EXE=flutter"
where flutter > nul 2>&1
if %errorlevel% neq 0 (
    if exist "D:\flutter_windows_3.41.9-stable\flutter\bin\flutter.bat" (
        set "FLUTTER_EXE=D:\flutter_windows_3.41.9-stable\flutter\bin\flutter.bat"
    )
)

cd /d "%BASE_DIR%QuranCircles.Mobile"
call "%FLUTTER_EXE%" run -d chrome

echo.
pause
