@echo off
cd /d "%~dp0"
title Quran Center Launcher

echo ========================================================
echo   Starting Quran Center System...
echo ========================================================
echo.

where dotnet >nul 2>nul
if %errorlevel% equ 0 (
    echo [1/2] Starting Backend API on http://localhost:5070 ...
    start "Backend API" /min cmd /c "cd /d "%~dp0QuranCircles.Api\QuranCircles.Api" && dotnet run --urls=http://localhost:5070"
) else (
    echo [Notice] .NET SDK not detected locally. Using cloud server.
)

echo [2/2] Opening Web Application...
where php >nul 2>nul
if %errorlevel% equ 0 (
    start "Web Server (PHP)" /min cmd /c "cd /d "%~dp0QuranCircles.Web" && php -S localhost:8000"
    timeout /t 2 >nul
    start http://localhost:8000
) else (
    where npx >nul 2>nul
    if %errorlevel% equ 0 (
        start "Web Server (NPX)" /min cmd /c "cd /d "%~dp0QuranCircles.Web" && npx -y serve -p 8000 ."
        timeout /t 2 >nul
        start http://localhost:8000
    ) else (
        start "" "%~dp0QuranCircles.Web\index.html"
    )
)

echo.
echo ========================================================
echo   Quran Center Web Application Launched Successfully!
echo ========================================================
echo.
pause
