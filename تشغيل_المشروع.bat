@echo off
setlocal enableextensions
chcp 65001 > nul
set "BASE_DIR=%~dp0"

title تشغيل نظام مركز البيان القرآني

echo ========================================================
echo   [مركز البيان القرآني] - تشغيل المنظومة الكاملة
echo ========================================================
echo.

rem 1. فحص وتشغيل خادم الـ API
echo [1/2] فحص وتشغيل خادم الـ API (http://localhost:5070)...
dotnet --version > nul 2>&1
if %errorlevel% equ 0 (
    netstat -ano | findstr :5070 > nul
    if %errorlevel% neq 0 (
        start "Backend API (QuranCircles)" /min /D "%BASE_DIR%QuranCircles.Api\QuranCircles.Api" dotnet run --urls=http://localhost:5070
        timeout /t 3 /nobreak > nul
    )
)

rem 2. فتح واجهة النظام
echo [2/2] فتح المنظومة في المتصفح...
start http://localhost:5070

echo.
echo ========================================================
echo   تم تشغيل النظام بنجاح!
echo   الرابط المحلي: http://localhost:5070
echo ========================================================
echo.
pause
