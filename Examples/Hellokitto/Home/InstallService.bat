@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator.
    echo Right-click and select "Run as administrator".
    pause
    exit /b 1
)
echo Installing HelloKittoX service...
"%~dp0HelloKitto.exe" -install
echo Starting HelloKittoX service...
net start HelloKittoX
echo.
echo Service installed and started.
pause
