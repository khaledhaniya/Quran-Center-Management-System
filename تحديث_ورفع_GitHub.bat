@echo off
setlocal enableextensions
chcp 65001 > nul
set "BASE_DIR=%~dp0"
cd /d "%BASE_DIR%"

title رفع ومزامنة المشروع مع GitHub - مركز البيان القرآني

echo ========================================================
echo   [GitHub Sync] - نظام إدارة مراكز القرآن الكريم
echo   المسار: %BASE_DIR%
echo ========================================================
echo.

rem 1. التحقق من وجود Git
git --version > nul 2>&1
if %errorlevel% neq 0 (
    echo [خطأ] أداة Git غير مثبتة أو غير مضافة لمتغيرات النظام PATH.
    echo يرجى التأكد من تثبيت Git ثم إعادة المحاولة.
    pause
    exit /b 1
)

rem 2. التأكد من رابط المستودع Remote
git remote get-url origin > nul 2>&1
if %errorlevel% neq 0 (
    echo [إعداد] جاري ربط المستودع بـ GitHub...
    git remote add origin https://github.com/khaledhaniya/Quran-Center-Management-System.git
)

echo [1/4] جاري تفقد التغييرات والملفات...
git status -s

echo.
set "COMMIT_MSG="
set /p COMMIT_MSG="[2/4] أدخل وصف التعديل (أو اضغط Enter لرسالة تلقائية): "
if "%COMMIT_MSG%"=="" set "COMMIT_MSG=تحديثات وتطويرات شاملة في النظام والأمان والمزامنة"

echo.
echo [3/4] جاري تجهيز الملفات (Staging & Commit)...
git add .
git commit -m "%COMMIT_MSG%"

echo.
echo [4/4] جاري الرفع المباشر إلى مستودع GitHub (Pushing to origin main)...
git push origin main

if %errorlevel% equ 0 (
    echo.
    echo ========================================================
    echo   [نجاح] تم رفع ومزامنة المشروع بنجاح إلى GitHub!
    echo   الرابط: https://github.com/khaledhaniya/Quran-Center-Management-System
    echo ========================================================
) else (
    echo.
    echo ========================================================
    echo   [تنبيه] حدث خطأ أثناء الرفع، جاري محاولة الرفع مع التحقق...
    git push -u origin main
    echo ========================================================
)

echo.
pause
