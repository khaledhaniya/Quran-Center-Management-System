@echo off
cd /d "%~dp0"
title Quran Center Launcher

echo ========================================================
echo   Starting Quran Center System (Localhost:8000)...
echo ========================================================
echo.

where dotnet >nul 2>nul
if %errorlevel% equ 0 (
    echo [1/2] Starting Backend API on http://localhost:5070 ...
    start "Backend API" /min cmd /c "cd /d "%~dp0QuranCircles.Api\QuranCircles.Api" && dotnet run --urls=http://localhost:5070"
) else (
    echo [Notice] .NET SDK not detected locally. Web will use cloud/local API.
)

echo [2/2] Starting Web Application Server on http://localhost:8000 ...

if exist "C:\xampp\php\php.exe" (
    start "Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Web" && C:\xampp\php\php.exe -S localhost:8000"
    timeout /t 2 >nul
    start http://localhost:8000
    goto launched
)

where php >nul 2>nul
if %errorlevel% equ 0 (
    start "Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Web" && php -S localhost:8000"
    timeout /t 2 >nul
    start http://localhost:8000
    goto launched
)

where python >nul 2>nul
if %errorlevel% equ 0 (
    start "Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Web" && python -m http.server 8000"
    timeout /t 2 >nul
    start http://localhost:8000
    goto launched
)

where npx >nul 2>nul
if %errorlevel% equ 0 (
    start "Web Server" /min cmd /c "cd /d "%~dp0QuranCircles.Web" && npx -y serve -p 8000 ."
    timeout /t 2 >nul
    start http://localhost:8000
    goto launched
)

start "" "%~dp0QuranCircles.Web\index.html"

:launched
echo.
echo ========================================================
echo   Quran Center Web Application Launched Successfully!
echo   Local Web URL: http://localhost:8000
echo ========================================================
echo.
pause
