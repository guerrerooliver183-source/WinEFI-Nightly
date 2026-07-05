@echo off
title WinEFI Startup Script
setlocal enabledelayedexpansion

:: Check for arguments
if "%~1"=="" (
    echo Usage: %~nx0 -Install ^| -Uninstall
    pause
    exit /b 1
)

set ACTION=%~1
set INSTALL_DIR=C:\Program Files (x86)\WinEFI
set TEMP_DIR=%LOCALAPPDATA%\Temp\WinEFI-Temp
set BOOTRES_DLL=%SystemRoot%\Boot\Resources\bootres.dll
set EXTRACTED_DIR=%TEMP_DIR%\bootres_extracted
set WINLOGO_BMP=%EXTRACTED_DIR%\winlogo3.bmp
set SPLASH_BMP=%INSTALL_DIR%\splash.bmp

echo Processing WinEFI %ACTION%...

if /I "%ACTION%"=="-Install" (
    echo [1/4] Checking and creating directories...
    powershell -Command "if (-not (Test-Path '%INSTALL_DIR%')) { New-Item -Path '%INSTALL_DIR%' -ItemType Directory | Out-Null }"
    powershell -Command "if (-not (Test-Path '%TEMP_DIR%')) { New-Item -Path '%TEMP_DIR%' -ItemType Directory | Out-Null }"

    echo [2/4] Running bootres extraction...
    if exist "%INSTALL_DIR%\ExtractBootres.bat" (
        call "%INSTALL_DIR%\ExtractBootres.bat" "%BOOTRES_DLL%" "%EXTRACTED_DIR%"
    ) else (
        echo Warning: ExtractBootres.bat not found.
    )

    echo [3/4] Updating splash image...
    if exist "%WINLOGO_BMP%" (
        powershell -Command "Copy-Item -Path '%WINLOGO_BMP%' -Destination '%SPLASH_BMP%' -Force"
        echo Splash image updated successfully.
    ) else (
        echo Warning: winlogo3.bmp not found, skipping replacement.
    )

    echo [4/4] Installing HackBGRT...
    if exist "%INSTALL_DIR%\setup.exe" (
        start /wait "" "%INSTALL_DIR%\setup.exe" batch install enable-bcdedit allow-secure-boot
    ) else (
        echo Error: HackBGRT setup.exe not found.
    )

    echo Installation process finished.
)

if /I "%ACTION%"=="-Uninstall" (
    echo [1/2] Uninstalling HackBGRT...
    if exist "%INSTALL_DIR%\setup.exe" (
        start /wait "" "%INSTALL_DIR%\setup.exe" batch uninstall
    ) else (
        echo Warning: HackBGRT setup.exe not found for uninstallation.
    )

    echo [2/2] Cleaning up...
    :: Registry and Task Scheduler are handled by the main installer
    echo Uninstallation process finished.
)

echo.
echo Process completed.
exit /b 0
