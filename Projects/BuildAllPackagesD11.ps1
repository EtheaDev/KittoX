<#
.SYNOPSIS
    Rebuilds all KittoX packages (Core + Enterprise) for Delphi 11.

.DESCRIPTION
    Wrapper around BuildPackages.ps1 that loops over the two packages
    (KittoXCore.dproj and KittoXEnterprise.dproj). Always builds for
    Win32: the Delphi 11 IDE itself is 32-bit and can only load Win32
    design-time BPLs. Build a 64-bit application against this version
    by compiling the application's own .dproj separately, but the
    framework packages stay Win32 here.

    To verify the 64-bit toolchain on the framework, use
    BuildAllPackagesD12.ps1 or BuildAllPackagesD13.ps1.

.PARAMETER BDSRoot
    Root folder of RAD Studio installations (default: C:\BDS\Studio).

.PARAMETER Config
    Build configuration: Debug or Release (default: Release).

.PARAMETER Target
    MSBuild target: Build, Clean or Rebuild (default: Rebuild).

.EXAMPLE
    .\BuildAllPackagesD11.ps1
    # Rebuilds Core + Enterprise for D11, Win32, Release.

.EXAMPLE
    .\BuildAllPackagesD11.ps1 -Target Build -Config Debug
    # Incremental Debug build of Core + Enterprise for D11, Win32.
#>
param(
    [string]$BDSRoot = "C:\BDS\Studio",

    [ValidateSet("Debug", "Release")]
    [string]$Config = "Release",

    [ValidateSet("Build", "Clean", "Rebuild")]
    [string]$Target = "Rebuild"
)

$ErrorActionPreference = "Stop"
$DelphiVersion = "D11"

# Win32 is the only valid platform for design-time packages on D11
# (the IDE is 32-bit; 64-bit design-time was introduced in D12).
$Platforms = @("Win32")

$ScriptDir = $PSScriptRoot
$BuildScript = Join-Path $ScriptDir "BuildPackages.ps1"
if (-not (Test-Path $BuildScript)) {
    Write-Error "BuildPackages.ps1 not found in $ScriptDir"
    exit 1
}

$Packages = @("KittoXCore.dproj", "KittoXEnterprise.dproj")

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
