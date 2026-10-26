@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator.
    echo Right-click and select "Run as administrator".
    pause
    exit /b 1
)
echo Stopping HelloKittoX service...
net stop HelloKittoX 2>nul
echo Uninstalling HelloKittoX service...
"%~dp0HelloKitto.exe" -uninstall
echo.
echo Service stopped and uninstalled.
pause
