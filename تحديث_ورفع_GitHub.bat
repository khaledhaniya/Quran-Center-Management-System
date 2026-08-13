@echo off
title GitHub Sync - AlBayan Quran Center
echo ========================================================
echo   Updating and Pushing Project to GitHub...
echo ========================================================
cd /d "c:\xampp\htdocs\Quran Center"
git add .
git commit -m "Auto sync updates"
git push origin main
echo ========================================================
echo   Push to GitHub Completed Successfully!
echo ========================================================
pause
