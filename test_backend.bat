@echo off
echo Testing Backend Service API endpoints...
echo.

cd /d "%~dp0"

set BASE_URL=http://localhost:3000

echo Testing getAll accounts...
curl -X GET "%BASE_URL%/api/accounts/getAll?page=1&limit=10" -H "Content-Type: application/json"
echo.

echo Testing getById accounts (ID 1)...
curl -X GET "%BASE_URL%/api/accounts/get/1" -H "Content-Type: application/json"
echo.

echo Testing create account...
curl -X POST "%BASE_URL%/api/accounts/create" -H "Content-Type: application/json" -d "{\"name\":\"Test Account\",\"type\":\"Asset\"}"
echo.

echo Testing get stored procedures...
curl -X GET "%BASE_URL%/api/stored-procedures" -H "Content-Type: application/json"
echo.

echo Testing get GL accounts...
curl -X GET "%BASE_URL%/api/accounts" -H "Content-Type: application/json"
echo.

echo Testing raw query...
curl -X POST "%BASE_URL%/api/raw-query" -H "Content-Type: application/json" -d "{\"query\":\"SELECT 1 as test\"}"
echo.

echo Backend service testing completed.
pause