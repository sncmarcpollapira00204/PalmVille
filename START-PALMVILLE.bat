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
echo [2/2] Starting Rojo on the PalmVille project...
echo Keep this window open while using Rojo in Roblox Studio.
echo Press Ctrl+C in this window to stop Rojo.
echo.
rojo serve default.project.json

echo.
echo Rojo has stopped.
pause
