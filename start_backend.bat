@echo off
setlocal
echo Starting MD-Accounting Backend Services...
echo.

REM === Kill any existing backend or Prisma processes ===
taskkill /F /IM node.exe /T >nul 2>&1
taskkill /F /IM prisma.exe /T >nul 2>&1

REM === Change to your backend project directory ===
cd /d "D:\Projects\flutters\app\" || (
    echo ❌ ERROR: Failed to change to project directory.
    exit /b 1
)

REM === Cleanup old Prisma temporary files ===
echo Cleaning old Prisma engine files...
del /F /Q "D:\Projects\flutters\app\lib\generated\prisma\query_engine-windows.dll.node*" >nul 2>&1

echo
exit /b 0
echo Starting Prisma service...
npx prisma generate

echo ✅ Prisma started successfully.

echo.
echo Starting Node.js backend server...
start "" node "D:\Projects\flutters\app\server.js" 

if %errorlevel% neq 0 (
    echo ❌ Prisma failed to start.
    goto :error
)


if %errorlevel% neq 0 (
    echo ❌ Error: Node.js failed to start.
    goto :error
)

echo.
echo ============================================
echo ✅  All backend services started successfully!
echo ============================================
goto :end

:error
echo.
echo ============================================
echo ⚠️  One or more services stopped unexpectedly!
echo ============================================

:end
pause
