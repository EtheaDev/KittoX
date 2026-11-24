@echo off
:: Builds a KittoX application for Linux64 and copies it into the Ubuntu of WSL.
::   deploy_app_linux.cmd <project.dpr> [config] [nobuild]
::     <project.dpr> : e.g. Examples\HelloKitto\Projects\HelloKitto.dpr
::     [config]      : Debug | Release   (default: Release)
::     [nobuild]     : pass "nobuild" to deploy the last build
::
:: Result, in the home of the default WSL user (see deploy_app.sh):
::   ~/kittox/Home/                  KittoX system Home
::   ~/kittox/App/<App>/Home/<App>   application Home and executable
:: Then, from Windows:
::   wsl -d Ubuntu-24.04 -- ~/kittox/App/<App>/Home/<App>
:: and open http://localhost:<Server/Port>/<AppPath> in the Windows browser
:: (WSL in mirrored networking: same localhost).
::
:: The application Home is the folder next to the project folder (..\Home),
:: as in every KittoX example.
setlocal

if "%~1"=="" (
  echo Usage: %~nx0 ^<project.dpr^> [Debug^|Release] [nobuild]
  exit /b 2
)
set CFG=%~2
if "%CFG%"=="" set CFG=Release
if "%KX_WSL_DISTRO%"=="" set KX_WSL_DISTRO=Ubuntu-24.04

if /i not "%~3"=="nobuild" (
  call "%~dp0build_app_linux.cmd" "%~f1" %CFG%
  if errorlevel 1 exit /b 1
)

for %%I in ("%~dp0..\..") do set KX=%%~fI
for %%I in ("%~dp1..\Home") do set APPHOME=%%~fI
for %%I in ("%~dp1..\Lib\Linux64\%CFG%\%~n1") do set EXE=%%~fI
if not exist "%EXE%" (
  echo [ERROR] "%EXE%" not found: build it first.
  exit /b 1
)

:: tr strips CR: the script may have been checked out with Windows line endings.
:: wslpath turns the Windows paths into /mnt/<drive>/... inside Linux.
wsl.exe -d %KX_WSL_DISTRO% -- bash -c "tr -d '\r' < \"$(wslpath '%~dp0deploy_app.sh')\" | bash -s -- \"$(wslpath '%KX%')\" \"$(wslpath '%APPHOME%')\" \"$(wslpath '%EXE%')\""
exit /b %ERRORLEVEL%
