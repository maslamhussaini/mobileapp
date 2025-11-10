@echo off
setlocal enabledelayedexpansion

echo Installing MD-Accounting Backend Service...
echo.

cd /d "%~dp0"

echo Checking for NSSM (Non-Sucking Service Manager)...
nssm version >nul 2>&1
if %errorlevel% neq 0 (
    echo NSSM not found in PATH. Checking specific location...
    if exist "D:\nssm-2.24\win64\nssm.exe" (
        echo Found NSSM at D:\nssm-2.24\win64\nssm.exe
        set "NSSM_PATH=D:\nssm-2.24\win64\nssm.exe"
    ) else (
        echo ERROR: NSSM is not installed.
        echo Please download NSSM from https://nssm.cc/download
        echo Extract nssm.exe to a folder in your PATH or to C:\Windows\System32\
        echo.
        pause
        exit /b 1
    )
) else (
    set "NSSM_PATH=nssm"
)

echo NSSM found. Installing service...
echo.

sc query "MD-Accounting-Backend" >nul 2>&1
if %errorlevel%==0 (
    echo Service already exists. Removing old one...
    "%NSSM_PATH%" remove "MD-Accounting-Backend" confirm
)

"%NSSM_PATH%" install "MD-Accounting-Backend" "%~dp0start_backend.bat"

if %errorlevel% neq 0 (
    echo ERROR: Failed to install service
    pause
    exit /b 1
)

echo.
echo Configuring service...
"%NSSM_PATH%" set "MD-Accounting-Backend" DisplayName "MD-Accounting Backend Service"
"%NSSM_PATH%" set "MD-Accounting-Backend" Description "Backend services for MD-Accounting System (Prisma + Node.js)"
"%NSSM_PATH%" set "MD-Accounting-Backend" Start SERVICE_AUTO_START
"%NSSM_PATH%" set "MD-Accounting-Backend" AppDirectory "%~dp0"
"%NSSM_PATH%" set "MD-Accounting-Backend" AppStdout "%~dp0logs\backend_out.log"
"%NSSM_PATH%" set "MD-Accounting-Backend" AppStderr "%~dp0logs\backend_err.log"

echo.
echo Service installed successfully!
echo.
echo Starting service now...
"%NSSM_PATH%" start "MD-Accounting-Backend"

echo.
echo The service will automatically start when Windows boots.
echo To stop:   nssm stop "MD-Accounting-Backend"
echo To remove: nssm remov
