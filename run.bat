@echo off
setlocal
cd /d "%~dp0"
title Al-Bayan Quran System Launcher

echo ========================================================
echo   Starting Al-Bayan Quran Center Management System...
echo ========================================================
echo.

rem Check dotnet installation
where dotnet >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] .NET SDK is not installed or not found in PATH!
    pause
    exit /b 1
)

rem Kill any previous process on port 5070
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :5070 ^| findstr LISTENING') do (
    taskkill /F /PID %%a >nul 2>&1
)

rem Launch the Backend API
echo [1/2] Starting System Server on http://localhost:5070 ...
start "Al-Bayan Server" /D "%~dp0QuranCircles.Api\QuranCircles.Api" cmd /k "dotnet run --urls=http://localhost:5070"

rem Wait 4 seconds for database and server to initialize
echo Initializing database and web files...
ping 127.0.0.1 -n 5 >nul

rem Open default browser
echo [2/2] Opening Web Application in your browser...
start http://localhost:5070

echo.
echo ========================================================
echo   System is running successfully!
echo   Open: http://localhost:5070
echo ========================================================
echo.
pause
