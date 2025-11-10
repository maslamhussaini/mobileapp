# MD-Accounting Backend Windows Service Setup

This guide explains how to set up the MD-Accounting backend services (Prisma + Node.js) to run automatically when Windows starts.

## Prerequisites

1. **Node.js** - Must be installed and available in PATH
2. **NSSM (Non-Sucking Service Manager)** - Download from https://nssm.cc/download
   - Extract `nssm.exe` to `D:\nssm-2.24\win64\` (already done) or to a folder in your PATH (e.g., `C:\Windows\System32\`)

## Files Created

- `start_backend.bat` - Batch file to start the backend services
- `install_service.bat` - Script to install the Windows service
- `README_Windows_Service.md` - This documentation

## Installation Steps

1. **Download and Install NSSM**
   ```
   Download NSSM from https://nssm.cc/download
   Extract nssm.exe to C:\Windows\System32\ or add to PATH
   ```

2. **Run the Service Installer**
   ```
   Right-click on install_service.bat and "Run as administrator"
   Or open Command Prompt as administrator and run: install_service.bat
   ```

3. **Verify Installation**
   ```
   Open Services (services.msc)
   Look for "MD-Accounting Backend Service"
   Check that Startup Type is "Automatic"
   ```

## Service Management

### Start Service
```cmd
nssm start "MD-Accounting-Backend"
```

### Stop Service
```cmd
nssm stop "MD-Accounting-Backend"
```

### Restart Service
```cmd
nssm restart "MD-Accounting-Backend"
```

### Remove Service
```cmd
nssm remove "MD-Accounting-Backend"
```

### Check Service Status
```cmd
nssm status "MD-Accounting-Backend"
```

## Manual Operation

If you prefer not to use the Windows service, you can run the backend manually:

1. Double-click `start_backend.bat`
2. Or run in Command Prompt: `start_backend.bat`

## Troubleshooting

### Service Won't Start
1. Check that Node.js is installed and in PATH
2. Verify that the project directory exists and has proper permissions
3. Check Windows Event Viewer for error details

### Port Already in Use
If port 3000 is already in use:
1. Stop the service: `nssm stop "MD-Accounting-Backend"`
2. Wait a few seconds
3. Start the service: `nssm start "MD-Accounting-Backend"`

### Database Connection Issues
1. Ensure SQL Server is running
2. Check the `.env` file has correct DATABASE_URL
3. Verify database credentials

## Service Logs

Service output is logged to Windows Event Viewer:
- Open Event Viewer → Windows Logs → Application
- Look for events from "MD-Accounting-Backend"

## Automatic Startup

Once installed, the service will:
- Start automatically when Windows boots
- Restart automatically if it crashes
- Run in the background without a visible window

## Security Notes

- The service runs with the same permissions as the user who installed it
- Consider running as a dedicated service account for production use
- Ensure the database connection string in `.env` is secure