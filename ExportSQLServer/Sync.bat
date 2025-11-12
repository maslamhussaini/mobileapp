@echo off
echo ============================================
echo 🚀 Starting Python Scripts Execution
echo ============================================

set "PYTHON_EXE=C:\Program Files\Python313\python.exe"
set "SCRIPT_DIR=D:\Projects\Python\ExportSQLServer"

cd /d "%SCRIPT_DIR%"

set FILES=01exportGLAccount1.py 02exportGLAccount2.py 03exportbanks.py 04exportCustomers.py 05exportSuppliers.py 06exportboatsstatus.py 07exportboats.py 09exportstores.py 10exportitems.py 11exportsales.py 12exportsaleitems.py 13exportopeningbalanes.py 14exportGLTrans.py 15exportcheques.py 16exporttransferes.py 17exporttransferdetails.py 18exportpurchase.py 19exportpurchasedetail.py 20exportbillprefix.py synctime.py

for %%f in (%FILES%) do (
    echo --------------------------------------------
    echo ▶️ Running %%f ...
    "%PYTHON_EXE%" "%%f"
    if errorlevel 1 (
        echo ❌ Error in %%f. Stopping execution.
        pause
        exit /b 1
    )
    echo ✅ Finished %%f successfully.
    
)

echo ============================================
echo 🎉 All Python scripts executed successfully!
echo ============================================
pause
