@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator.
    echo Right-click and select "Run as administrator".
    pause
    exit /b 1
)
echo Installing KEmployeeX service...
"%~dp0KEmployee.exe" -install
echo Starting KEmployeeX service...
net start KEmployeeX
echo.
echo Service installed and started.
pause
