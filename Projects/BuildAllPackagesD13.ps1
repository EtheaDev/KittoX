<#
.SYNOPSIS
    Rebuilds all KittoX packages (Core + Enterprise) for Delphi 13.

.DESCRIPTION
    Wrapper around BuildPackages.ps1 that loops over the two packages
    (KittoXCore.dproj and KittoXEnterprise.dproj) and the requested
    target platform(s). At the end prints a summary table with the
    result of each (package, platform) combination.

    Default behavior: Rebuild Release on both Win32 and Win64. Both
    bitnesses are valid for D13 design-time packages because the IDE
    itself is 64-bit native and can load both Win32 and Win64 BPLs.

.PARAMETER BDSRoot
    Root folder of RAD Studio installations (default: C:\BDS\Studio).

.PARAMETER Platform
    Target platform: Win32, Win64 or Both (default: Both).

.PARAMETER Config
    Build configuration: Debug or Release (default: Release).

.PARAMETER Target
    MSBuild target: Build, Clean or Rebuild (default: Rebuild).

.EXAMPLE
    .\BuildAllPackagesD13.ps1
    # Rebuilds Core + Enterprise for D13 on Win32 + Win64 in Release.

.EXAMPLE
    .\BuildAllPackagesD13.ps1 -Platform Win64 -Target Build
    # Builds (incremental) Core + Enterprise for D13, only Win64.
#>
param(
    [string]$BDSRoot = "C:\BDS\Studio",

    [ValidateSet("Win32", "Win64", "Both")]
    [string]$Platform = "Both",

    [ValidateSet("Debug", "Release")]
    [string]$Config = "Release",

    [ValidateSet("Build", "Clean", "Rebuild")]
    [string]$Target = "Rebuild"
)

$ErrorActionPreference = "Stop"
$DelphiVersion = "D13"

$ScriptDir = $PSScriptRoot
$BuildScript = Join-Path $ScriptDir "BuildPackages.ps1"
if (-not (Test-Path $BuildScript)) {
    Write-Error "BuildPackages.ps1 not found in $ScriptDir"
    exit 1
}

$Packages = @("KittoXCore.dproj", "KittoXEnterprise.dproj")
if ($Platform -eq "Both") { $Platforms = @("Win32", "Win64") } else { $Platforms = @($Platform) }

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " BuildAllPackages $DelphiVersion" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Packages:  $($Packages -join ', ')" -ForegroundColor White
Write-Host " Platforms: $($Platforms -join ', ')" -ForegroundColor White
Write-Host " Config:    $Config" -ForegroundColor White
Write-Host " Target:    $Target" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan

$Results = @()
$Failed = 0
$StartTime = Get-Date

foreach ($pkg in $Packages) {
    foreach ($plat in $Platforms) {
        Write-Host ""
        Write-Host "############################################" -ForegroundColor Magenta
        Write-Host "  $DelphiVersion / $pkg / $plat / $Config" -ForegroundColor Magenta
        Write-Host "############################################" -ForegroundColor Magenta

        $stepStart = Get-Date
        & $BuildScript -DelphiVersion $DelphiVersion -BDSRoot $BDSRoot -Platform $plat -Config $Config -Project $pkg -Target $Target
        $exitCode = $LASTEXITCODE
        $duration = (Get-Date) - $stepStart

        $Results += [pscustomobject]@{
            Package  = $pkg
            Platform = $plat
            Status   = if ($exitCode -eq 0) { "OK" } else { "FAIL" }
            ExitCode = $exitCode
            Seconds  = [math]::Round($duration.TotalSeconds, 1)
        }
        if ($exitCode -ne 0) { $Failed++ }
    }
}

$totalDuration = (Get-Date) - $StartTime
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " SUMMARY [$DelphiVersion]" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
$Results | Format-Table -AutoSize | Out-String | Write-Host
Write-Host ("Total elapsed: {0:N1} s" -f $totalDuration.TotalSeconds) -ForegroundColor White

if ($Failed -gt 0) {
    Write-Host "$Failed of $($Results.Count) builds FAILED" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "All $($Results.Count) builds SUCCEEDED" -ForegroundColor Green
    exit 0
}
