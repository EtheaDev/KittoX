<#
.SYNOPSIS
    Builds KittoX packages using MSBuild and RAD Studio.

.DESCRIPTION
    Configures the RAD Studio environment via rsvars.bat and invokes MSBuild
    on the specified project. Supports Delphi 10.4, 11, 12 and 13.

.PARAMETER DelphiVersion
    Delphi version: D10_4, D11, D12 or D13 (default: D13)

.PARAMETER BDSRoot
    Root folder of RAD Studio installations.
    Default: C:\BDS\Studio
    The script appends the version-specific subfolder (21.0, 22.0, 23.0, 37.0).

.PARAMETER Platform
    Target platform: Win32 or Win64 (default: Win32). Note that on D10_4
    and D11 the IDE is 32-bit so design-time packages are Win32 only;
    Win64 design-time packages require D12 or later (64-bit IDE).

.PARAMETER Config
    Build configuration: Debug or Release (default: Debug)

.PARAMETER Project
    Project file name without path (default: KittoXCore.dproj)

.PARAMETER Target
    MSBuild target: Build, Clean, Rebuild (default: Build)

.EXAMPLE
    .\Build.ps1
    # Builds KittoXCore with Delphi 13, Win32, Debug

.EXAMPLE
    .\Build.ps1 -DelphiVersion D13 -Config Release -Platform Win64
    # Builds KittoXCore with Delphi 13, Win64, Release

.EXAMPLE
    .\Build.ps1 -Target Clean
    # Cleans the KittoXCore project
#>

param(
    [ValidateSet("D10_4", "D11", "D12", "D13")]
    [string]$DelphiVersion = "D13",

    [string]$BDSRoot = "C:\BDS\Studio",

    [ValidateSet("Win32", "Win64")]
    [string]$Platform = "Win32",

    [ValidateSet("Debug", "Release")]
    [string]$Config = "Release",

    [string]$Project = "KittoXCore.dproj",

    [ValidateSet("Build", "Clean", "Rebuild")]
    [string]$Target = "Build"
)

$ErrorActionPreference = "Stop"

# Map Delphi version to BDS version subfolder
$bdsVersionMap = @{
    "D10_4" = "21.0"
    "D11"   = "22.0"
    "D12"   = "23.0"
    "D13"   = "37.0"
}

$bdsVersion = $bdsVersionMap[$DelphiVersion]
$bdsPath = Join-Path $BDSRoot $bdsVersion
$rsvars = Join-Path $bdsPath "bin\rsvars.bat"

# Validate paths
if (-not (Test-Path $bdsPath)) {
    Write-Error "RAD Studio not found at: $bdsPath"
    exit 1
}
if (-not (Test-Path $rsvars)) {
    Write-Error "rsvars.bat not found at: $rsvars"
    exit 1
}

$projectDir = Join-Path $PSScriptRoot "$DelphiVersion"
$projectPath = Join-Path $projectDir $Project

if (-not (Test-Path $projectPath)) {
    Write-Error "Project not found: $projectPath"
    exit 1
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " KittoX Build" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Delphi:   $DelphiVersion (BDS $bdsVersion)" -ForegroundColor White
Write-Host " Project:  $Project" -ForegroundColor White
Write-Host " Platform: $Platform" -ForegroundColor White
Write-Host " Config:   $Config" -ForegroundColor White
Write-Host " Target:   $Target" -ForegroundColor White
Write-Host " BDS Path: $bdsPath" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan

# Build the cmd command that sources rsvars.bat then runs MSBuild
$msbuildArgs = "`"$projectPath`" /t:$Target /p:Config=$Config /p:Platform=$Platform /v:minimal /nologo"
$cmd = "call `"$rsvars`" && msbuild $msbuildArgs"

Write-Host ""
Write-Host "Executing: msbuild $Project /t:$Target /p:Config=$Config /p:Platform=$Platform" -ForegroundColor Yellow
Write-Host ""

# Run via cmd /c so rsvars.bat environment is inherited by msbuild
cmd /c $cmd

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BUILD FAILED (exit code $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}
else {
    Write-Host ""
    Write-Host "BUILD SUCCEEDED" -ForegroundColor Green
    exit 0
}
