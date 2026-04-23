@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator.
    echo Right-click and select "Run as administrator".
    pause
    exit /b 1
)
echo Installing TasKittoX service...
"%~dp0TasKitto.exe" -install
echo Starting TasKittoX service...
net start TaskittoX
echo.
echo Service installed and started.
pause
