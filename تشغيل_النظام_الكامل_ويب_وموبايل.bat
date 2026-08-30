@echo off
cd /d "%~dp0"
chcp 65001 > nul
title تشغيل النظام الكامل - مركز البيان القرآني

echo ========================================================
echo   [مركز البيان القرآني] - تشغيل المنظومة الكاملة (ويب + موبايل)
echo ========================================================
echo.

where dotnet >nul 2>nul
if %errorlevel% equ 0 (
    netstat -ano | findstr :5070 >nul 2>nul
    if %errorlevel% neq 0 (
        echo [1/2] جاري تشغيل خادم المنظومة والـ API (http://localhost:5070)...
        start "Backend API (QuranCircles)" /min cmd /c "cd /d "%~dp0QuranCircles.Api\QuranCircles.Api" && dotnet run --urls=http://localhost:5070"
        timeout /t 3 /nobreak >nul
    ) else (
        echo [1/2] خادم الـ API يعمل بالفعل على المنفذ 5070.
    )
)

echo [2/2] جاري فتح واجهات المنظومة...
start http://localhost:5070

if exist "%~dp0QuranCircles.Mobile\build\web\index.html" (
    start http://localhost:5070/mobile/index.html
)

echo.
echo ========================================================
echo   تم تشغيل النظام بالكامل بنجاح!
echo   لوحة الإدارة والويب: http://localhost:5070
echo ========================================================
echo.
pause
