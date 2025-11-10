@echo off
setlocal enabledelayedexpansion

echo Installing MD-Accounting Backend Windows Service...
cd /d "%~dp0"

REM Check NSSM availability
nssm version >nul 2>&1
if %errorlevel% neq 0 (
    if exist "D:\nssm-2.24\win64\nssm.exe" (
        set "NSSM_PATH=D:\nssm-2.24\win64\nssm.exe"
    ) else (
        echo NSSM not found. Please install NSSM first.
        pause
        exit /b 1
    )
) else (
    set "NSSM_PATH=nssm"
)

echo Checking existing service...
sc query "MD-Accounting-Backend" >nul 2>&1
if %errorlevel%==0 (
    echo Service already exists. Removing old one...
    "%NSSM_PATH%" remove "MD-Accounting-Backend" confirm
)

echo Installing service...
"%NSSM_PATH%" install "MD-Accounting-Backend" "%~dp0start_backend.bat"

if %errorlevel% neq 0 (
    echo ERROR: Failed to install service
    pause
    exit /b 1
)

"%NSSM_PATH%" set "MD-Accounting-Backend" DisplayName "MD-Accounting Backend"
"%NSSM_PATH%" set "MD-Accounting-Backend" Description "Prisma + Node.js backend for MD-Accounting"
"%NSSM_PATH%" set "MD-Accounting-Backend" Start SERVICE_AUTO_START
"%NSSM_PATH%" set "MD-Accounting-Backend" AppDirectory "%~dp0"
"%NSSM_PATH%" set "MD-Accounting-Backend" AppStdout "%~dp0logs\backend_out.log"
"%NSSM_PATH%" set "MD-Accounting-Backend" AppStderr "%~dp0logs\backend_err.log"

echo Service installed successfully!
"%NSSM_PATH%" start "MD-Accounting-Backend"
echo Service started successfully!
pause
endlocal