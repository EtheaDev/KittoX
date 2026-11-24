#Requires -Version 5.1
<#
.SYNOPSIS
  Copies from the Ubuntu (WSL) the system libraries dcclinux64 links against.

.DESCRIPTION
  The Delphi IDE does this through PAServer and its SDK Manager. For command
  line builds the compiler only needs the libraries in a folder, passed with
  --syslibroot and --libpath: this script fills that folder, and
  Test\build_linux.cmd uses it.

  Run it once after Install-KittoXLinux.ps1, and again after installing new
  development packages in Ubuntu.

  The folder is %LOCALAPPDATA%\KittoX\LinuxSDK\<distro>, or the KX_LINUX_SDK
  environment variable if set.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Tools\Linux\Import-LinuxSdk.ps1
#>
param(
  [string]$Distro = $(if ($env:KX_WSL_DISTRO) { $env:KX_WSL_DISTRO } else { 'Ubuntu-24.04' }),
  [string]$SdkPath = $(if ($env:KX_LINUX_SDK) { $env:KX_LINUX_SDK } else { Join-Path $env:LOCALAPPDATA "KittoX\LinuxSDK\$Distro" })
)

$ErrorActionPreference = 'Stop'

function ConvertTo-WslPath([string]$WindowsPath) {
  $full = [IO.Path]::GetFullPath($WindowsPath)
  '/mnt/' + $full.Substring(0, 1).ToLower() + ($full.Substring(2) -replace '\\', '/')
}

$tar = Join-Path $env:TEMP "kittox-linux-sdk-$PID.tar"
$collect = ConvertTo-WslPath (Join-Path $PSScriptRoot 'collect_sdk.sh')

Write-Host "Collecting the libraries in $Distro..."
& wsl.exe -d $Distro -u root -- bash -c "tr -d '\r' < '$collect' | bash -s -- '$(ConvertTo-WslPath $tar)'"
if ($LASTEXITCODE -ne 0) { throw "collect_sdk.sh failed (exit $LASTEXITCODE)." }

Write-Host "Extracting to $SdkPath..."
if (Test-Path $SdkPath) { Remove-Item $SdkPath -Recurse -Force }
New-Item -ItemType Directory -Force -Path $SdkPath | Out-Null
& "$env:SystemRoot\System32\tar.exe" -xf $tar -C $SdkPath
if ($LASTEXITCODE -ne 0) { throw "tar failed (exit $LASTEXITCODE)." }
Remove-Item $tar -Force

$libc = Join-Path $SdkPath 'usr\lib\x86_64-linux-gnu\libc.so'
if (-not (Test-Path $libc)) { throw "libc.so missing in ${SdkPath}: is build-essential installed in ${Distro}?" }
$gcc = Get-ChildItem (Join-Path $SdkPath 'usr\lib\gcc\x86_64-linux-gnu') -Directory | Select-Object -First 1
Write-Host "Linux SDK ready: $SdkPath (gcc $($gcc.Name))" -ForegroundColor Green
Write-Host 'Next: Test\run_tests_linux.cmd'
