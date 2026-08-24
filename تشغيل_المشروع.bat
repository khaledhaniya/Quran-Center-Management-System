@echo off
setlocal enableextensions
chcp 65001 > nul
set "BASE_DIR=%~dp0"

title تشغيل نظام مركز القرآن الكريم (API + Web)

echo ========================================================
echo   [مركز البيان القرآني] - تشغيل الخادم والواجهة
echo ========================================================
echo.

rem 1. التحقق من dotnet
dotnet --version > nul 2>&1
if %errorlevel% neq 0 (
    echo [تنبيه] لم يتم العثور على .NET SDK مثبت في مسار النظام.
    echo لتشغيل الـ API محلياً، يرجى تثبيت .NET 9.0 SDK من موقع مايكروسوفت.
    echo (يمكن للواجهة الاتصال بالخادم السحابي مباشرة عند توفره).
    echo.
) else (
    echo [1/3] تشغيل خادم الـ API (http://localhost:5070)...
    start "Backend API (QuranCircles)" /min /D "%BASE_DIR%QuranCircles.Api\QuranCircles.Api" dotnet run --urls=http://localhost:5070
)

rem 2. تشغيل خادم الويب
echo [2/3] بدء تشغيل بوابة الويب (http://localhost:8000)...
where php > nul 2>&1
if %errorlevel% equ 0 (
    start "Frontend Server (PHP)" /min /D "%BASE_DIR%QuranCircles.Web" php -S localhost:8000
) else (
    where npx > nul 2>&1
    if %errorlevel% equ 0 (
        start "Frontend Server (NPX)" /min /D "%BASE_DIR%QuranCircles.Web" npx -y serve -p 8000 .
    ) else (
        where python > nul 2>&1
        if %errorlevel% equ 0 (
            start "Frontend Server (Python)" /min /D "%BASE_DIR%QuranCircles.Web" python -m http.server 8000
        ) else (
            echo فتح الملف المباشر للمتصفح...
            start "" "%BASE_DIR%QuranCircles.Web\index.html"
        )
    )
)

rem 3. الانتظار وفتح المتصفح
echo [3/3] فتح المتصفح...
ping 127.0.0.1 -n 4 > nul
start http://localhost:8000

echo.
echo ========================================================
echo   تم تشغيل النظام بنجاح!
echo   - بوابة الويب: http://localhost:8000
echo   - خادم الـ API: http://localhost:5070
echo ========================================================
echo.
pause
