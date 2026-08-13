@echo off

set "BASE_DIR=%~dp0"

echo ================================================
echo   Quran Center - Starting Project...
echo ================================================

rem 1. Start Backend API on port 5070
echo [1/3] Starting Backend API...
start "Backend API" /min /D "%BASE_DIR%QuranCircles.Api\QuranCircles.Api" dotnet run

rem 2. Start Frontend Server on port 8000
echo [2/3] Starting Frontend Server...
start "Frontend Server" /min /D "%BASE_DIR%QuranCircles.Web" php -S localhost:8000

rem 3. Wait for servers to start (8 seconds)
echo [3/3] Waiting for servers...
ping 127.0.0.1 -n 8 > nul

rem 4. Open browser
echo Opening browser...
start http://localhost:8000

echo ================================================
echo   Project started successfully!
echo   Frontend: http://localhost:8000
echo   API:      http://localhost:5070
echo ================================================
echo.
echo   To stop: close the CMD windows
echo   (Backend API and Frontend Server)
echo ================================================
pause
