@echo off
echo Starting MD-Accounting Backend Services...
echo.

REM Change directory to your project folder
cd /d "D:\Projects\flutters\app\"

echo Checking Node.js installation...
node -v
if %errorlevel% neq 0 (
    echo ❌ Node.js not found! Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

echo.
echo Checking npm installation...
npm -v
if %errorlevel% neq 0 (
    echo ❌ npm not found! Please reinstall Node.js to include npm.
    pause
    exit /b 1
)

echo.
echo Starting Prisma service...
npx prisma generate
if %errorlevel% neq 0 (
    echo ❌ Prisma failed to start.
    goto :error
)
echo ✅ Prisma started successfully.

echo.
echo Starting Node.js backend server...
start "" node "D:\Projects\flutters\app\server.js"
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
