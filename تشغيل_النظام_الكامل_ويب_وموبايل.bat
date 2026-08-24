@echo off
setlocal enableextensions
chcp 65001 > nul
set "BASE_DIR=%~dp0"

title تشغيل النظام المتكامل (الواجهة الخلفية + الويب + تطبيق الموبايل)

echo ========================================================
echo   [مركز البيان القرآني] - مشغل النظام الكامل (Full Suite)
echo ========================================================
echo.

rem 1. تشغيل خادم الـ API
echo [1/3] فحص وتشغيل خادم الـ API...
dotnet --version > nul 2>&1
if %errorlevel% equ 0 (
    netstat -ano | findstr :5070 > nul
    if %errorlevel% neq 0 (
        start "Backend API (QuranCircles)" /min /D "%BASE_DIR%QuranCircles.Api\QuranCircles.Api" dotnet run --urls=http://localhost:5070
        timeout /t 3 /nobreak > nul
    ) else (
        echo خادم الـ API يعمل بالفعل على المنفذ 5070.
    )
) else (
    echo [تنبيه] لم يتم العثور على .NET SDK، سيتم استخدام الاتصال بالخادم السحابي.
)

rem 2. تشغيل بوابة الويب
echo [2/3] تشغيل بوابة الويب (http://localhost:8000)...
where php > nul 2>&1
if %errorlevel% equ 0 (
    start "Web Portal (PHP)" /min /D "%BASE_DIR%QuranCircles.Web" php -S localhost:8000
) else (
    where npx > nul 2>&1
    if %errorlevel% equ 0 (
        start "Web Portal (NPX)" /min /D "%BASE_DIR%QuranCircles.Web" npx -y serve -p 8000 .
    ) else (
        start "" "%BASE_DIR%QuranCircles.Web\index.html"
    )
)
start http://localhost:8000

rem 3. تشغيل تطبيق الموبايل عبر Flutter
echo [3/3] فحص وتشغيل تطبيق فلاتر للموبايل...
flutter --version > nul 2>&1
if %errorlevel% equ 0 (
    start "Mobile App (Flutter Web)" /D "%BASE_DIR%QuranCircles.Mobile" flutter run -d chrome
) else (
    echo [ملاحظة] حزمة Flutter SDK غير مثبتة على هذا الجهاز، تم فتح بوابة الويب بنجاح.
)

echo.
echo ========================================================
echo   تم إطلاق النظام بنجاح!
echo   - بوابة الويب: http://localhost:8000
echo   - خادم الـ API: http://localhost:5070
echo ========================================================
echo.
ping 127.0.0.1 -n 4 > nul
