@echo off
cd /d "%~dp0"
title GitHub Sync - AlBayan Quran Center
echo ========================================================
echo   Updating and Pushing Project to GitHub...
echo ========================================================
git status
echo.
git add .
git commit -m "Update and sync project changes to GitHub Pages"
git push origin main
echo.
echo ========================================================
echo   Done! Check your repository and GitHub Pages.
echo ========================================================
pause
