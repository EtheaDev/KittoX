@echo off
:: Builds the three KittoX demos for Linux64, copies them into the Ubuntu of
:: WSL and installs each one as a systemd service, enabled and started.
::   deploy_examples_linux.cmd [config] [nobuild]
::     [config]  : Debug | Release   (default: Release)
::     [nobuild] : pass "nobuild" to deploy the last builds
::
:: Prerequisites, once: Install-KittoXLinux.ps1, Import-LinuxSdk.ps1, and for
:: KEmployee a Firebird with the EMPLOYEE database (setup_firebird_employee.sh).
::
:: Then, from the Windows browser (127.0.0.1, not localhost: see README.md):
::   http://127.0.0.1:3621/hellokittox/   administrator / password
::   http://127.0.0.1:3622/taskittox/     admin / password
::   http://127.0.0.1:3623/kemployeex/    tesla / password (public LDAP)
::
:: The services share the ports with Windows (mirrored networking): stop them
:: before running the Windows builds of the same demos:
::   wsl -d Ubuntu-24.04 -u root -- systemctl disable --now kittox-hellokitto kittox-taskitto kittox-kemployee
setlocal

set CFG=%~1
if "%CFG%"=="" set CFG=Release
if "%KX_WSL_DISTRO%"=="" set KX_WSL_DISTRO=Ubuntu-24.04
for %%I in ("%~dp0..\..") do set KX=%%~fI

set NOBUILD=%~2
for %%A in (HelloKitto TasKitto KEmployee) do (
  call :Deploy %%A
  if errorlevel 1 exit /b 1
)
exit /b 0

:: A subroutine, not the body of the for: inside a parenthesized block cmd
:: parses the whole block at once, and the \" of the bash command breaks it.
:Deploy
echo.
echo ===== %1
call "%~dp0deploy_app_linux.cmd" "%KX%\Examples\%1\Projects\%1.dpr" %CFG% %NOBUILD%
if errorlevel 1 (
  echo [ERROR] %1: build or deploy failed.
  exit /b 1
)
:: As the default user through sudo, not with -u root: install_service.sh
:: runs the service as the user who called sudo.
wsl.exe -d %KX_WSL_DISTRO% -- bash -c "tr -d '\r' < \"$(wslpath '%~dp0install_service.sh')\" | sudo bash -s -- %1"
if errorlevel 1 (
  echo [ERROR] %1: service installation failed.
  exit /b 1
)
exit /b 0
