@echo off
echo Starting Prisma and Node.js server...
echo.

cd /d "%~dp0"

echo Checking Node.js installation...
node --version
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed or not in PATH
    pause
    exit /b 1
)

echo.
echo Checking npm installation...
npm --version
if %errorlevel% neq 0 (
    echo ERROR: npm is not installed or not in PATH
    pause
    exit /b 1
)

echo.
echo Generating Prisma client...
npx prisma generate

echo.
echo Running Prisma migrations...
npx prisma migrate deploy

echo.
echo Starting Node.js server in background...
echo Server will be available at http://localhost:3000
echo.

start "" node server.js