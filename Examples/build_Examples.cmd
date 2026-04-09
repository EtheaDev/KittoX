@echo off
setlocal enabledelayedexpansion
title KittoX Examples Builder

:: ============================================================
:: KittoX Examples Build Script
:: Builds HelloKitto, TasKitto, KEmployee in multiple deploy modes
:: ============================================================

:: --- Delphi BDS path ---
set DEFAULT_BDS=C:\BDS\Studio\37.0
echo.
echo ============================================
echo   KittoX Examples Builder
echo ============================================
echo.
echo Default Delphi BDS path: %DEFAULT_BDS%
set /p "BDS_PATH=Enter BDS path (or press Enter for default): "
if "%BDS_PATH%"=="" set BDS_PATH=%DEFAULT_BDS%

:: Verify the path exists
if not exist "%BDS_PATH%\bin\rsvars.bat" (
    echo.
    echo ERROR: rsvars.bat not found in %BDS_PATH%\bin\
    echo Please check the BDS path and try again.
    pause
    goto :eof
)

:: Initialize Delphi environment via rsvars.bat
echo.
echo Initializing Delphi environment from %BDS_PATH%...
call "%BDS_PATH%\bin\rsvars.bat"
echo BDS = %BDS%
echo.

:: --- Select examples to build ---
echo Which examples do you want to build?
echo   [A] All (HelloKitto, TasKitto, KEmployee)
echo   [H] HelloKitto only
echo   [T] TasKitto only
echo   [K] KEmployee only
echo   [Q] Quit
echo.
choice /c AHTKQ /n /m "Select [A/H/T/K/Q]: "
set EXAMPLE_CHOICE=%errorlevel%
if %EXAMPLE_CHOICE%==5 goto :eof

:: --- Select deploy modes ---
echo.
echo Which deploy modes do you want to build?
echo   [A] All (Desktop, ISAPI, Apache, Embedded)
echo   [D] Desktop (Standalone GUI / Windows Service) - Win64
echo   [I] ISAPI (IIS) - Win64
echo   [P] Apache Module - Win32
echo   [E] Windows Embedded (WebView2) - Win64
echo   [Q] Quit
echo.
choice /c ADIPEQ /n /m "Select [A/D/I/P/E/Q]: "
set MODE_CHOICE=%errorlevel%
if %MODE_CHOICE%==6 goto :eof

set BUILD_DESKTOP=0
set BUILD_ISAPI=0
set BUILD_APACHE=0
set BUILD_EMBEDDED=0

if %MODE_CHOICE%==1 (
    set BUILD_DESKTOP=1
    set BUILD_ISAPI=1
    set BUILD_APACHE=1
    set BUILD_EMBEDDED=1
)
if %MODE_CHOICE%==2 set BUILD_DESKTOP=1
if %MODE_CHOICE%==3 set BUILD_ISAPI=1
if %MODE_CHOICE%==4 set BUILD_APACHE=1
if %MODE_CHOICE%==5 set BUILD_EMBEDDED=1

:: Save the starting directory
set START_DIR=%CD%
set ERRORS=0

:: --- Build functions ---
if %EXAMPLE_CHOICE%==1 goto :BuildAll
if %EXAMPLE_CHOICE%==2 goto :BuildHelloKitto
if %EXAMPLE_CHOICE%==3 goto :BuildTasKitto
if %EXAMPLE_CHOICE%==4 goto :BuildKEmployee
goto :Done

:BuildAll
call :BuildHelloKitto
call :BuildTasKitto
call :BuildKEmployee
goto :Done

:: ============================================================
:BuildHelloKitto
:: ============================================================
echo.
echo =============================================
echo   Building HelloKitto...
echo =============================================
cd /d "%START_DIR%\HelloKitto\Projects"

if %BUILD_DESKTOP%==1 (
    echo   [Desktop] HelloKitto.dproj ^(Win64^)...
    msbuild /t:Build /p:config=Release /p:platform=Win64 /nologo HelloKitto.dproj /fl /flp:logfile=HelloKitto_Desktop.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_ISAPI%==1 (
    echo   [ISAPI] HelloKittoISAPI.dproj ^(Win64^)...
    msbuild /t:Build /p:config=Release /p:platform=Win64 /nologo HelloKittoISAPI.dproj /fl /flp:logfile=HelloKitto_ISAPI.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_APACHE%==1 (
    echo   [Apache] mod_hellokitto.dproj ^(Win32^)...
    msbuild /t:Build /p:config=Release /p:platform=Win32 /nologo mod_hellokitto.dproj /fl /flp:logfile=HelloKitto_Apache.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_EMBEDDED%==1 (
    echo   [Embedded] HelloKittoDesktop.dproj ^(Win64^)...
    msbuild /t:Build /p:config=Release /p:platform=Win64 /nologo HelloKittoDesktop.dproj /fl /flp:logfile=HelloKitto_Embedded.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
cd /d "%START_DIR%"
goto :eof

:: ============================================================
:BuildTasKitto
:: ============================================================
echo.
echo =============================================
echo   Building TasKitto...
echo =============================================
cd /d "%START_DIR%\TasKitto\Projects"

if %BUILD_DESKTOP%==1 (
    echo   [Desktop] TasKitto.dproj ^(Win64^)...
    msbuild /t:Build /p:config=Release /p:platform=Win64 /nologo TasKitto.dproj /fl /flp:logfile=TasKitto_Desktop.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_ISAPI%==1 (
    echo   [ISAPI] TasKittoISAPI.dproj ^(Win64^)...
    msbuild /t:Build /p:config=Release /p:platform=Win64 /nologo TasKittoISAPI.dproj /fl /flp:logfile=TasKitto_ISAPI.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_APACHE%==1 (
    echo   [Apache] mod_taskitto.dproj ^(Win32^)...
    msbuild /t:Build /p:config=Release /p:platform=Win32 /nologo mod_taskitto.dproj /fl /flp:logfile=TasKitto_Apache.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_EMBEDDED%==1 (
    echo   [Embedded] TasKittoDesktop.dproj ^(Win64^)...
    msbuild /t:Build /p:config=Release /p:platform=Win64 /nologo TasKittoDesktop.dproj /fl /flp:logfile=TasKitto_Embedded.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
cd /d "%START_DIR%"
goto :eof

:: ============================================================
:BuildKEmployee
:: ============================================================
echo.
echo =============================================
echo   Building KEmployee...
echo =============================================
cd /d "%START_DIR%\KEmployee\Projects"

if %BUILD_DESKTOP%==1 (
    echo   [Desktop] KEmployee.dproj ^(Win64^)...
    msbuild /t:Build /p:config=Release /p:platform=Win64 /nologo KEmployee.dproj /fl /flp:logfile=KEmployee_Desktop.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_ISAPI%==1 (
    echo   [ISAPI] KEmployeeISAPI.dproj ^(Win64^)...
    msbuild /t:Build /p:config=Release /p:platform=Win64 /nologo KEmployeeISAPI.dproj /fl /flp:logfile=KEmployee_ISAPI.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_APACHE%==1 (
    echo   [Apache] mod_kemployee.dproj ^(Win32^)...
    msbuild /t:Build /p:config=Release /p:platform=Win32 /nologo mod_kemployee.dproj /fl /flp:logfile=KEmployee_Apache.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_EMBEDDED%==1 (
    echo   [Embedded] KEmployeeDesktop.dproj ^(Win64^)...
    msbuild /t:Build /p:config=Release /p:platform=Win64 /nologo KEmployeeDesktop.dproj /fl /flp:logfile=KEmployee_Embedded.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
cd /d "%START_DIR%"
goto :eof

:: ============================================================
:Done
:: ============================================================
echo.
echo =============================================
if %ERRORS%==0 (
    echo   Build completed successfully!
) else (
    echo   Build completed with %ERRORS% error(s).
    echo   Check the .log files in each Projects folder for details.
)
echo =============================================
echo.
pause
endlocal
