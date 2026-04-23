@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator.
    echo Right-click and select "Run as administrator".
    pause
    exit /b 1
)
echo Stopping TasKittoX service...
net stop TaskittoX 2>nul
echo Uninstalling TasKittoX service...
"%~dp0TasKitto.exe" -uninstall
echo.
echo Service stopped and uninstalled.
pause
