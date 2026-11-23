@rem ---- Explorer pause: when started by double click the window stays open at the end ----
@if defined EXPLORER_PAUSE_CHILD goto :explorer_pause_skip
@if not "%~1"=="" goto :explorer_pause_skip
@echo %cmdcmdline% | "%SystemRoot%\System32\find.exe" /i "%~nx0" > NUL
@if errorlevel 1 goto :explorer_pause_skip
@echo %cmdcmdline% | "%SystemRoot%\System32\find.exe" /i "call " > NUL
@if not errorlevel 1 goto :explorer_pause_skip
@set EXPLORER_PAUSE_CHILD=1
@"%ComSpec%" /c ""%~f0""
@set EXPLORER_PAUSE_RC=%errorlevel%
@echo.
@pause
@exit /b %EXPLORER_PAUSE_RC%
:explorer_pause_skip
@echo off
setlocal enabledelayedexpansion
title KittoX Examples Builder

:: ============================================================
:: KittoX Examples Build Script
:: Builds HelloKitto, TasKitto, KEmployee, SportClubManager in multiple
:: deploy modes.
::
:: INTERACTIVE (no arguments): shows the menus, as before.
::
:: COMMAND LINE:
::   build_Examples.cmd <example> [mode] [config] [bdspath]
::     <example> : All | HelloKitto | TasKitto | KEmployee | SportClubManager
::                 (H / T / K / S accepted)
::     [mode]    : All | Desktop | ISAPI | Apache | Embedded (default: Desktop)
::     [config]  : Release | Debug                           (default: Release)
::     [bdspath] : Delphi BDS path  (default: the BDS_PATH environment variable,
::                 else the newest Delphi found in the registry: 13, 12, 11, 10.4)
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
:: Every Delphi writes its install folder in the registry at
:: HK(CU|LM)\Software\Embarcadero\BDS\<version>\RootDir:
::   37.0 = Delphi 13, 23.0 = Delphi 12, 22.0 = Delphi 11, 21.0 = Delphi 10.4.
:: Newest first; a BDS_PATH environment variable, when set, wins over the
:: lookup; the historical C:\BDS\Studio\37.0 is the last resort.
set DEFAULT_BDS=
if not "%BDS_PATH%"=="" set "DEFAULT_BDS=%BDS_PATH%"
if "%DEFAULT_BDS%"=="" call :FindBDS 37.0
if "%DEFAULT_BDS%"=="" call :FindBDS 23.0
if "%DEFAULT_BDS%"=="" call :FindBDS 22.0
if "%DEFAULT_BDS%"=="" call :FindBDS 21.0
if "%DEFAULT_BDS%"=="" set DEFAULT_BDS=C:\BDS\Studio\37.0

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
if /i "%~1"=="SportClubManager" set EXAMPLE_CHOICE=5
if /i "%~1"=="S"          set EXAMPLE_CHOICE=5
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
echo   [A] All (HelloKitto, TasKitto, KEmployee, SportClubManager)
echo   [H] HelloKitto only
echo   [T] TasKitto only
echo   [K] KEmployee only
echo   [S] SportClubManager only
echo   [Q] Quit
echo.
choice /c AHTKSQ /n /m "Select [A/H/T/K/S/Q]: "
set EXAMPLE_CHOICE=%errorlevel%
if %EXAMPLE_CHOICE%==6 goto :eof

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
if %EXAMPLE_CHOICE%==5 goto :BuildSportClubManager
goto :Done

:BuildAll
call :BuildHelloKitto
call :BuildTasKitto
call :BuildKEmployee
call :BuildSportClubManager
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
:BuildSportClubManager
:: ============================================================
echo.
echo =============================================
echo   Building SportClubManager...
echo =============================================
cd /d "%START_DIR%\SportClubManager\Projects"

:: Optional FlexCel build of the Excel export (see
:: SportClubManager\Source\SCM.Defines.inc): set the FLEXCEL environment
:: variable to the folder holding the FlexCel .dcu for the platform being
:: built, and it is passed on to msbuild. Unset, the export is built on the
:: framework ADO engine.
set "FLEXCEL_PROP="
if not "%FLEXCEL%"=="" set "FLEXCEL_PROP=/p:FLEXCEL=%FLEXCEL%"
if not "%FLEXCEL%"=="" echo   FlexCel: %FLEXCEL%

if %BUILD_DESKTOP%==1 (
    echo   [Desktop] SportClubManager.dproj ^(Win64^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo %FLEXCEL_PROP% SportClubManager.dproj /fl /flp:logfile=SportClubManager_Desktop.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_ISAPI%==1 (
    echo   [ISAPI] SportClubManagerISAPI.dproj ^(Win64^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo %FLEXCEL_PROP% SportClubManagerISAPI.dproj /fl /flp:logfile=SportClubManager_ISAPI.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_APACHE%==1 (
    echo   [Apache] mod_sportclubmanager.dproj ^(Win32^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win32 /nologo %FLEXCEL_PROP% mod_sportclubmanager.dproj /fl /flp:logfile=SportClubManager_Apache.log;verbosity=diagnostic
    if errorlevel 1 (echo   *** FAILED *** & set /a ERRORS+=1) else (echo   OK)
)
if %BUILD_EMBEDDED%==1 (
    echo   [Embedded] SportClubManagerDesktop.dproj ^(Win64^)...
    msbuild /t:Build /p:config=%CFG% /p:platform=Win64 /nologo %FLEXCEL_PROP% SportClubManagerDesktop.dproj /fl /flp:logfile=SportClubManager_Embedded.log;verbosity=diagnostic
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
echo   ^<example^> : All ^| HelloKitto ^| TasKitto ^| KEmployee ^| SportClubManager
echo                 (H / T / K / S accepted)
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

:: ============================================================
:FindBDS <version>
::   Sets DEFAULT_BDS to the RootDir of that BDS version (HKCU first, then
::   HKLM), without the trailing backslash, and only if it holds rsvars.bat.
:: ============================================================
call :ReadRootDir HKCU %~1
if "%DEFAULT_BDS%"=="" call :ReadRootDir HKLM %~1
:: Delayed expansion here: a %VAR:~-1% substring on an EMPTY variable breaks the
:: parse of the whole line (the version is not installed), !VAR:~-1! does not.
if "!DEFAULT_BDS:~-1!"=="\" set "DEFAULT_BDS=!DEFAULT_BDS:~0,-1!"
if not "%DEFAULT_BDS%"=="" if not exist "%DEFAULT_BDS%\bin\rsvars.bat" set DEFAULT_BDS=
exit /b 0

:: ============================================================
:ReadRootDir <hive> <version>
::   reg query prints "    RootDir    REG_SZ    C:\...\Studio\<version>\";
::   the line is picked by its first token (no "find": a Unix find.exe on
::   the PATH, e.g. under Git Bash, would break it) and tokens=1,2,* keeps
::   the whole path even when it contains spaces.
:: ============================================================
for /f "tokens=1,2,*" %%A in ('reg query "%~1\Software\Embarcadero\BDS\%~2" /v RootDir 2^>nul') do (
  if /i "%%A"=="RootDir" set "DEFAULT_BDS=%%C"
)
exit /b 0
