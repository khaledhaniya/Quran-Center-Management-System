@echo off
setlocal enableextensions
chcp 65001 > nul
cd /d "%~dp0"

title تشغيل نظام مركز البيان القرآني

echo ========================================================
echo   [مركز البيان القرآني] - تشغيل المنظومة الكاملة
echo ========================================================
echo.

rem 1. فحص توفر محرك دوت نت
where dotnet >nul 2>nul
if %errorlevel% neq 0 (
    echo [خطأ] محرك .NET غير مثبت على هذا الجهاز! يرجى تثبيت .NET 9 SDK.
    pause
    exit /b 1
)

rem 2. تنظيف وإغلاق أي عملية سابقة معلقة على المنفذ 5070
for /f "tokens=5" %%a in ('netstat -aon ^| findstr :5070 ^| findstr LISTENING') do (
    echo [تنبيه] إغلاق عملية سابقة معلقة على المنفذ 5070 (PID: %%a)...
    taskkill /F /PID %%a >nul 2>&1
)

rem 3. تشغيل خادم النظام وقاعدة البيانات والـ API
echo [1/2] جاري تشغيل خادم المنظومة وقاعدة البيانات (http://localhost:5070)...
start "خادم مركز البيان (Backend API)" /D "%~dp0QuranCircles.Api\QuranCircles.Api" cmd /c "dotnet run --urls=http://localhost:5070"

rem 4. الانتظار لتهيئة قاعدة البيانات
echo جاري تهيئة الاتصال بقاعدة البيانات وملفات النظام...
timeout /t 4 /nobreak > nul

rem 5. فتح واجهة المنظومة في المتصفح تلقائياً
echo [2/2] فتح المنظومة في المتصفح...
start http://localhost:5070

echo.
echo ========================================================
echo   ✅ تم تشغيل النظام بنجاح!
echo   رابط المنظومة: http://localhost:5070
echo ========================================================
echo.
pause
