@echo off
setlocal
title PalmVille - Git Sync + Rojo

cd /d "%~dp0"

echo.
echo ==========================================
echo   PALMVILLE - START DEVELOPMENT
echo ==========================================
echo.

where git >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Git is not installed or not in PATH.
    echo Install Git for Windows, then try again.
    pause
    exit /b 1
)

where rojo >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Rojo is not installed or not in PATH.
    echo Install Rojo and make sure the rojo command works in CMD.
    pause
    exit /b 1
)

git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
    echo [ERROR] This file must stay inside the PalmVille Git repository.
    pause
    exit /b 1
)

for /f "delims=" %%B in ('git branch --show-current') do set "CURRENT_BRANCH=%%B"
if not "%CURRENT_BRANCH%"=="feature/fivem-inspired-mobile-graphics" (
    echo [ERROR] Wrong Git branch: %CURRENT_BRANCH%
    echo Expected: feature/fivem-inspired-mobile-graphics
    echo Switch branches manually before running this launcher.
    pause
    exit /b 1
)

echo [1/2] Checking GitHub for updates...
git pull --ff-only origin feature/fivem-inspired-mobile-graphics
if errorlevel 1 (
    echo.
    echo [ERROR] Git pull failed. Rojo was not started.
    echo Resolve the Git issue first, then run this file again.
    pause
    exit /b 1
)

echo.
echo [2/2] Checking Rojo port 34872...
netstat -ano -p tcp | findstr /R /C:":34872 .*LISTENING" >nul
if not errorlevel 1 (
    echo.
    echo [OK] Port 34872 is already in use.
    echo A Rojo server may already be running.
    echo Do NOT start another Rojo instance.
    echo.
    echo In Roblox Studio, connect the Rojo plugin to:
    echo 127.0.0.1:34872
    echo.
    echo If Studio cannot connect, close the old Rojo terminal
    echo and run this launcher again.
    echo.
    pause
    exit /b 0
)

echo [OK] Port is free. Starting Rojo...
echo Keep this window open while using Rojo in Roblox Studio.
echo Press Ctrl+C in this window to stop Rojo.
echo.
rojo serve default.project.json

echo.
echo Rojo has stopped.
pause
