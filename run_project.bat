@echo off
cd /d "%~dp0"
chcp 65001 > nul
title تشغيل منظومة مركز البيان القرآني

echo ========================================================
echo   [مركز البيان القرآني] - جاري تشغيل المنظومة والواجهات
echo ========================================================
echo.

where dotnet >nul 2>nul
if %errorlevel% equ 0 (
    netstat -ano | findstr :5070 >nul 2>nul
    if %errorlevel% neq 0 (
        echo [1/2] جاري تشغيل خادم المنظومة وقاعدة البيانات (http://localhost:5070)...
        start "Backend API (QuranCircles)" /min cmd /c "cd /d "%~dp0QuranCircles.Api\QuranCircles.Api" && dotnet run --urls=http://localhost:5070"
        timeout /t 3 /nobreak >nul
    ) else (
        echo [1/2] خادم المنظومة يعمل بالفعل على المنفذ 5070.
    )
) else (
    echo [تنبيه] لم يتم العثور على حزمة .NET SDK. سيتم فتح واجهة الويب مباشرة.
)

echo [2/2] جاري فتح واجهة المنظومة في المتصفح...
start http://localhost:5070

echo.
echo ========================================================
echo   تم تشغيل النظام بنجاح!
echo   رابط الواجهة الرئيسية: http://localhost:5070
echo ========================================================
echo.
pause
