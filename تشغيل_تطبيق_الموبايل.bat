@echo off
setlocal enableextensions
chcp 65001 > nul
set "BASE_DIR=%~dp0"

title تشغيل تطبيق الموبايل (Flutter) - مركز البيان القرآني

echo ========================================================
echo   [مركز البيان القرآني] - تشغيل تطبيق الموبايل (فلاتر)
echo ========================================================
echo.

rem 1. فحص وتشغيل خادم الـ API
echo [1/2] فحص خادم الـ API (http://localhost:5070)...
dotnet --version > nul 2>&1
if %errorlevel% equ 0 (
    netstat -ano | findstr :5070 > nul
    if %errorlevel% neq 0 (
        echo تشغيل خادم الـ API محلياً...
        start "Backend API (QuranCircles)" /min /D "%BASE_DIR%QuranCircles.Api\QuranCircles.Api" dotnet run --urls=http://localhost:5070
        ping 127.0.0.1 -n 3 > nul
    ) else (
        echo خادم الـ API يعمل بالفعل على المنفذ 5070.
    )
)

rem 2. تشغيل تطبيق فلاتر
echo [2/2] تشغيل تطبيق فلاتر في المتصفح...
where flutter > nul 2>&1
if %errorlevel% equ 0 (
    cd /d "%BASE_DIR%QuranCircles.Mobile"
    call flutter run -d chrome
    goto done
)

rem في حال لم يكن أمر flutter في الـ PATH العالمي، يتم فتح التطبيق مباشرة
echo فتح التطبيق في المتصفح...
start http://localhost:8000

:done
echo.
pause
