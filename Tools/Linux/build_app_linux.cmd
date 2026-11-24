@echo off
:: Compiles a KittoX application for Linux64 with dcclinux64.
::   build_app_linux.cmd <project.dpr> [config] [bdspath]
::     <project.dpr> : the standalone project, e.g.
::                     Examples\HelloKitto\Projects\HelloKitto.dpr
::                     (Kitto.Vcl.Start runs it headless on Linux)
::     [config]      : Debug | Release   (default: Release)
::     [bdspath]     : Delphi BDS path   (default: the BDS environment variable,
::                                        else C:\BDS\Studio\37.0)
::
:: Units go to <project dir>\..\Lib\Linux64\<config>, the executable next to
:: them: Tools\Linux\deploy_app_linux.cmd copies it with the application Home
:: into the Ubuntu of WSL.
:: The Linux system libraries come from Tools\Linux\Import-LinuxSdk.ps1
:: (KX_LINUX_SDK, default %LOCALAPPDATA%\KittoX\LinuxSDK\Ubuntu-24.04).
::
:: Exit code: the compiler's (0 = built and linked).
setlocal

if "%~1"=="" (
  echo Usage: %~nx0 ^<project.dpr^> [Debug^|Release] [bdspath]
  exit /b 2
)
if not exist "%~f1" (
  echo [ERROR] "%~f1" not found.
  exit /b 2
)
set DPR=%~nx1
set PROJ=%~dp1.

set CFG=%~2
if "%CFG%"=="" set CFG=Release
set BDS_PATH=%~3
if "%BDS_PATH%"=="" if not "%BDS%"=="" set BDS_PATH=%BDS%
if "%BDS_PATH%"=="" set BDS_PATH=C:\BDS\Studio\37.0

set DCC=%BDS_PATH%\bin\dcclinux64.exe
if not exist "%DCC%" (
  echo [ERROR] dcclinux64.exe not found in "%BDS_PATH%\bin".
  echo         The Linux compiler needs Delphi Enterprise or Architect.
  exit /b 2
)

if /i "%CFG%"=="Release" (set DEFINES=RELEASE) else (set DEFINES=DEBUG)

:: KittoX root: two levels above this script.
for %%I in ("%~dp0..\..") do set KX=%%~fI
set SRC=%KX%\Source
set UNITS=%SRC%;%SRC%\EF;%SRC%\ThirdParty;%SRC%\ThirdParty\MarkdownProcessor\source;%SRC%\ThirdParty\delphi-jose-jwt\Source\Common;%SRC%\ThirdParty\delphi-jose-jwt\Source\JOSE

for %%I in ("%PROJ%\..\Lib\Linux64\%CFG%") do set OUT=%%~fI
if not exist "%OUT%" mkdir "%OUT%"

:: --- Linux SDK (system libraries for the linker) ---
if "%KX_LINUX_SDK%"=="" set KX_LINUX_SDK=%LOCALAPPDATA%\KittoX\LinuxSDK\Ubuntu-24.04
if not exist "%KX_LINUX_SDK%\usr\lib\x86_64-linux-gnu\libc.so" (
  echo [ERROR] No Linux SDK in "%KX_LINUX_SDK%". Run Tools\Linux\Import-LinuxSdk.ps1.
  exit /b 2
)
set GCCDIR=
for /d %%G in ("%KX_LINUX_SDK%\usr\lib\gcc\x86_64-linux-gnu\*") do set GCCDIR=%%G
set LINKOPTS=--syslibroot:"%KX_LINUX_SDK%" --libpath:"%KX_LINUX_SDK%\usr\lib\x86_64-linux-gnu;%GCCDIR%;%BDS_PATH%\lib\linux64\release"

:: The project's {$R *.res} is produced by the IDE (or MSBuild) from the .dproj,
:: and is not part of the sources. When it is missing, an empty one in the
:: output folder lets the build go on; the real one, if a Windows build left it
:: next to the .dpr, is found first.
if not exist "%PROJ%\%~n1.res" if not exist "%OUT%\%~n1.res" (
  type nul > "%OUT%\%~n1.rc"
  "%BDS_PATH%\bin\brcc32.exe" -fo"%OUT%\%~n1.res" "%OUT%\%~n1.rc" > nul
  del "%OUT%\%~n1.rc"
)

pushd "%PROJ%"
"%DCC%" -B -Q -D%DEFINES% -NSSystem;Xml;Data;Datasnap;Web;Soap -U"%UNITS%" -R"%OUT%" -NU"%OUT%" -E"%OUT%" %LINKOPTS% %DPR%
set RESULT=%ERRORLEVEL%
popd

if %RESULT%==0 echo Built: "%OUT%\%~n1"
exit /b %RESULT%
