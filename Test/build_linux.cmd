@echo off
:: Compiles the KittoX test suite for Linux64 with dcclinux64.
::   build_linux.cmd [config] [bdspath]
::     [config]  : Debug | Release   (default: Debug)
::     [bdspath] : Delphi BDS path   (default: the BDS environment variable,
::                                    else C:\BDS\Studio\37.0)
::
:: The Linux system libraries come from the folder that
:: Tools\Linux\Import-LinuxSdk.ps1 fills (KX_LINUX_SDK, default
:: %LOCALAPPDATA%\KittoX\LinuxSDK\Ubuntu-24.04): no IDE, no PAServer.
:: Without it every unit still compiles and only the final link fails, with
:: "unable to find library -lc" and the like: still the check that matters
:: while porting, because compiler errors come first.
:: The executable lands in Bin\Linux64\<config>; Test\run_tests_linux.cmd runs it.
::
:: Exit code: the compiler's (0 = built and linked).
setlocal

set CFG=%~1
if "%CFG%"=="" set CFG=Debug
set BDS_PATH=%~2
if "%BDS_PATH%"=="" if not "%BDS%"=="" set BDS_PATH=%BDS%
if "%BDS_PATH%"=="" set BDS_PATH=C:\BDS\Studio\37.0

set DCC=%BDS_PATH%\bin\dcclinux64.exe
if not exist "%DCC%" (
  echo [ERROR] dcclinux64.exe not found in "%BDS_PATH%\bin".
  echo         The Linux compiler needs Delphi Enterprise or Architect.
  exit /b 2
)

if /i "%CFG%"=="Release" (set DEFINES=RELEASE) else (set DEFINES=DEBUG)

:: Same layout and search path as Projects\D13\KittoXTests.dproj.
set PROJ=%~dp0Projects\D13
set DCU=%~dp0Lib\D13\Linux64\%CFG%
set BIN=%~dp0Bin\Linux64\%CFG%
if not exist "%DCU%" mkdir "%DCU%"
if not exist "%BIN%" mkdir "%BIN%"

set SRC=..\..\..\Source
set UNITS=..\..\Source;%SRC%;%SRC%\EF;%SRC%\ThirdParty;%SRC%\ThirdParty\MarkdownProcessor\source;%SRC%\ThirdParty\delphi-jose-jwt\Source\Common;%SRC%\ThirdParty\delphi-jose-jwt\Source\JOSE

:: --- Linux SDK (system libraries for the linker) ---
if "%KX_LINUX_SDK%"=="" set KX_LINUX_SDK=%LOCALAPPDATA%\KittoX\LinuxSDK\Ubuntu-24.04
set LINKOPTS=
if exist "%KX_LINUX_SDK%\usr\lib\x86_64-linux-gnu\libc.so" (
  set GCCDIR=
  for /d %%G in ("%KX_LINUX_SDK%\usr\lib\gcc\x86_64-linux-gnu\*") do set GCCDIR=%%G
  call set LINKOPTS=--syslibroot:"%KX_LINUX_SDK%" --libpath:"%KX_LINUX_SDK%\usr\lib\x86_64-linux-gnu;%%GCCDIR%%;%BDS_PATH%\lib\linux64\release"
) else (
  echo [WARN] No Linux SDK in "%KX_LINUX_SDK%": units will compile, the link will fail.
  echo        Run Tools\Linux\Import-LinuxSdk.ps1 to create it.
)

pushd "%PROJ%"
"%DCC%" -B -Q -D%DEFINES% -NSSystem;Xml;Data;Datasnap;Web;Soap -U"%UNITS%" -NU"%DCU%" -E"%BIN%" %LINKOPTS% KittoXTests.dpr
set RESULT=%ERRORLEVEL%
popd

exit /b %RESULT%
