@echo off
:: Builds the KittoX test suite for Linux64 and runs it in the Ubuntu of WSL.
::   run_tests_linux.cmd [config] [nobuild]
::     [config]  : Debug | Release   (default: Debug)
::     [nobuild] : pass "nobuild" to run the last build without compiling
::
:: Needs, once: Tools\Linux\Install-KittoXLinux.ps1 and Import-LinuxSdk.ps1.
:: The databases are the same as on Windows (Data\TestDatabases.yaml): WSL in
:: mirrored networking sees this machine's 127.0.0.1.
::
:: Exit code: 0 = all tests passed, 1 = build failed or some test failed.
setlocal

set CFG=%~1
if "%CFG%"=="" set CFG=Debug
if "%KX_WSL_DISTRO%"=="" set KX_WSL_DISTRO=Ubuntu-24.04
set BIN=%~dp0Bin\Linux64\%CFG%

if /i not "%~2"=="nobuild" (
  call "%~dp0build_linux.cmd" %CFG%
  if errorlevel 1 (
    echo [ERROR] Linux build failed.
    exit /b 1
  )
)

if not exist "%BIN%\KittoXTests" (
  echo [ERROR] "%BIN%\KittoXTests" not found: build it first.
  exit /b 1
)

:: D:\x\y -> /mnt/d/x/y
set WBIN=%BIN:\=/%
set DRIVE=%WBIN:~0,1%
for %%L in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do if /i "%DRIVE%"=="%%L" set DRIVE=%%L
set WBIN=/mnt/%DRIVE%%WBIN:~2%

echo.
echo === Running the tests in %KX_WSL_DISTRO%: %WBIN%
wsl.exe -d %KX_WSL_DISTRO% --cd "%WBIN%" -- ./KittoXTests
set RESULT=%ERRORLEVEL%
if %RESULT%==0 (echo All tests passed on Linux.) else (echo Some tests failed on Linux. Report: "%BIN%\dunitx-results.xml")
exit /b %RESULT%
