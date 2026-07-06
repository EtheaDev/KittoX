@echo off
setlocal enabledelayedexpansion
title KittoX Examples Builder

:: ============================================================
:: KittoX Examples Build Script
:: Builds HelloKitto, TasKitto, KEmployee in multiple deploy modes.
::
:: INTERACTIVE (no arguments): shows the menus, as before.
::
:: COMMAND LINE:
::   build_Examples.cmd <example> [mode] [config] [bdspath]
::     <example> : All | HelloKitto | TasKitto | KEmployee   (H / T / K accepted)
::     [mode]    : All | Desktop | ISAPI | Apache | Embedded (default: Desktop)
::     [config]  : Release | Debug                           (default: Release)
::     [bdspath] : Delphi BDS path                           (default below)
::
::   Examples:
::     build_Examples.cmd TasKitto                 (TasKitto, Desktop, Release)
::     build_Examples.cmd TasKitto Desktop Debug   (TasKitto, Desktop, Debug)
::     build_Examples.cmd HelloKitto ISAPI
::     build_Examples.cmd All All Release
::
::   Non-interactive mode skips the final pause and sets the exit code to the
::   number of failed builds (0 = success), so it can be used from CI/automation.
:: ============================================================

:: --- Delphi BDS path (default) ---
set DEFAULT_BDS=C:\BDS\Studio\37.0

set INTERACTIVE=1
set CFG=Release
set EXAMPLE_CHOICE=0
set BUILD_DESKTOP=0
set BUILD_ISAPI=0
set BUILD_APACHE=0
set BUILD_EMBEDDED=0

:: --- Command-line argument handling ---
if "%~1"=="" goto :Interactive
if "%~1"=="/?" goto :Usage
if /i "%~1"=="-h" goto :Usage
if /i "%~1"=="--help" goto :Usage

set INTERACTIVE=0

:: example (arg 1)
if /i "%~1"=="All"        set EXAMPLE_CHOICE=1
if /i "%~1"=="HelloKitto" set EXAMPLE_CHOICE=2
if /i "%~1"=="H"          set EXAMPLE_CHOICE=2
if /i "%~1"=="TasKitto"   set EXAMPLE_CHOICE=3
if /i "%~1"=="T"          set EXAMPLE_CHOICE=3
if /i "%~1"=="KEmployee"  set EXAMPLE_CHOICE=4
if /i "%~1"=="K"          set EXAMPLE_CHOICE=4
if %EXAMPLE_CHOICE%==0 (
    echo.
    echo ERROR: unknown example "%~1".
    goto :Usage
)

:: mode (arg 2, default Desktop)
set MODE=%~2
if "%MODE%"=="" set MODE=Desktop
if /i "%MODE%"=="All" (
    set BUILD_DESKTOP=1
    set BUILD_ISAPI=1
    set BUILD_APACHE=1
    set BUILD_EMBEDDED=1
) else if /i "%MODE%"=="Desktop" (
    set BUILD_DESKTOP=1
) else if /i "%MODE%"=="ISAPI" (
    set BUILD_ISAPI=1
) else if /i "%MODE%"=="Apache" (
    set BUILD_APACHE=1
) else if /i "%MODE%"=="Embedded" (
    set BUILD_EMBEDDED=1
) else (
    echo.
    echo ERROR: unknown mode "%MODE%".
    goto :Usage
)

:: config (arg 3, default Release)
if not "%~3"=="" set CFG=%~3
if /i not "%CFG%"=="Release" if /i not "%CFG%"=="Debug" (
    echo.
    echo ERROR: unknown config "%CFG%" ^(use Release or Debug^).
    goto :Usage
)

:: bds path (arg 4, default)
set BDS_PATH=%~4
if "%BDS_PATH%"=="" set BDS_PATH=%DEFAULT_BDS%

goto :SetupEnv

:: ============================================================
:Interactive
:: ============================================================
echo.
echo ============================================
echo   KittoX Examples Builder
echo ============================================
echo.
echo Default Delphi BDS path: %DEFAULT_BDS%
set /p "BDS_PATH=Enter BDS path (or press Enter for default): "
if "%BDS_PATH%"=="" set BDS_PATH=%DEFAULT_BDS%

:: --- Select examples to build ---
echo.
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

goto :SetupEnv

:: ============================================================
:SetupEnv
:: ============================================================
:: Verify the BDS path exists
if not exist "%BDS_PATH%\bin\rsvars.bat" (
    echo.
    echo ERROR: rsvars.bat not found in %BDS_PATH%\bin\
    echo Please check the BDS path and try again.
    if "%INTERACTIVE%"=="1" pause
    endlocal & exit /b 1
)

:: Initialize Delphi environment via rsvars.bat
echo.
echo Initializing Delphi environment from %BDS_PATH%...
call "%BDS_PATH%\bin\rsvars.bat"
echo BDS = %BDS%
echo Config = %CFG%
echo.

:: Base directory = the folder this script lives in (so it works regardless of
:: the current working directory). Strip the trailing backslash from %~dp0.
set "START_DIR=%~dp0"
if "%START_DIR:~-1%"=="\" set "START_DIR=%START_DIR:~0,-1%"
set ERRORS=0

:: --- Dispatch ---
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
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo HelloKitto.dproj /fl /flp:logfile=HelloKitto_Desktop.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_ISAPI%==1 (
    echo   [ISAPI] HelloKittoISAPI.dproj ^(Win64^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo HelloKittoISAPI.dproj /fl /flp:logfile=HelloKitto_ISAPI.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_APACHE%==1 (
    echo   [Apache] mod_hellokitto.dproj ^(Win32^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win32 /nologo mod_hellokitto.dproj /fl /flp:logfile=HelloKitto_Apache.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_EMBEDDED%==1 (
    echo   [Embedded] HelloKittoDesktop.dproj ^(Win64^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo HelloKittoDesktop.dproj /fl /flp:logfile=HelloKitto_Embedded.log;verbosity=diagnostic
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
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo TasKitto.dproj /fl /flp:logfile=TasKitto_Desktop.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_ISAPI%==1 (
    echo   [ISAPI] TasKittoISAPI.dproj ^(Win64^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo TasKittoISAPI.dproj /fl /flp:logfile=TasKitto_ISAPI.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_APACHE%==1 (
    echo   [Apache] mod_taskitto.dproj ^(Win32^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win32 /nologo mod_taskitto.dproj /fl /flp:logfile=TasKitto_Apache.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_EMBEDDED%==1 (
    echo   [Embedded] TasKittoDesktop.dproj ^(Win64^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo TasKittoDesktop.dproj /fl /flp:logfile=TasKitto_Embedded.log;verbosity=diagnostic
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
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo KEmployee.dproj /fl /flp:logfile=KEmployee_Desktop.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_ISAPI%==1 (
    echo   [ISAPI] KEmployeeISAPI.dproj ^(Win64^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo KEmployeeISAPI.dproj /fl /flp:logfile=KEmployee_ISAPI.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_APACHE%==1 (
    echo   [Apache] mod_kemployee.dproj ^(Win32^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win32 /nologo mod_kemployee.dproj /fl /flp:logfile=KEmployee_Apache.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_EMBEDDED%==1 (
    echo   [Embedded] KEmployeeDesktop.dproj ^(Win64^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo KEmployeeDesktop.dproj /fl /flp:logfile=KEmployee_Embedded.log;verbosity=diagnostic
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
    echo   Build completed with %ERRORS% error^(s^).
    echo   Check the .log files in each Projects folder for details.
)
echo =============================================
echo.
if "%INTERACTIVE%"=="1" pause
endlocal & exit /b %ERRORS%

:: ============================================================
:Usage
:: ============================================================
echo.
echo Usage: build_Examples.cmd ^<example^> [mode] [config] [bdspath]
echo.
echo   ^<example^> : All ^| HelloKitto ^| TasKitto ^| KEmployee   (H / T / K accepted)
echo   [mode]    : All ^| Desktop ^| ISAPI ^| Apache ^| Embedded  (default: Desktop)
echo   [config]  : Release ^| Debug                           (default: Release)
echo   [bdspath] : Delphi BDS path                           (default: %DEFAULT_BDS%)
echo.
echo   Examples:
echo     build_Examples.cmd TasKitto
echo     build_Examples.cmd TasKitto Desktop Debug
echo     build_Examples.cmd HelloKitto ISAPI
echo     build_Examples.cmd All All Release
echo.
echo   Run with no arguments for the interactive menu.
echo.
endlocal & exit /b 1
