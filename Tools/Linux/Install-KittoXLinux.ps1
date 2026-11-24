#Requires -Version 5.1
<#
.SYNOPSIS
  Installs and prepares the Ubuntu (WSL) used to run KittoX Linux64 builds.

.DESCRIPTION
  Run once, after WSL itself is installed (wsl --install) and Windows has been
  restarted. Safe to run again: every step checks before acting.

    1. Sets WSL to "mirrored" networking, so that 127.0.0.1 inside Linux is the
       Windows machine: the tests reach SQL Server, PostgreSQL... exactly as
       they do on Windows, with the same TestDatabases.yaml.
    2. Installs the Ubuntu distribution, without the interactive first-run
       questions.
    3. Runs setup_ubuntu.sh as root: user, packages, database clients, PAServer.
    4. Restarts WSL and checks the result.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File Tools\Linux\Install-KittoXLinux.ps1
#>
param(
  [string]$Distro = 'Ubuntu-24.04',
  [string]$LinuxUser = 'kittox',
  [string]$BdsPath = $(if ($env:BDS) { $env:BDS } else { 'C:\BDS\Studio\37.0' })
)

$ErrorActionPreference = 'Stop'

function Write-Step([string]$Text) { Write-Host "`n=== $Text" -ForegroundColor Cyan }

# wsl.exe writes its own messages in UTF-16; Linux programs it runs write UTF-8.
function Invoke-WslAdmin([string[]]$Arguments) {
  $prev = [Console]::OutputEncoding
  [Console]::OutputEncoding = [Text.Encoding]::Unicode
  try { (& wsl.exe @Arguments 2>&1 | Out-String).Trim() }
  finally { [Console]::OutputEncoding = $prev }
}

function Get-WslDistros {
  $out = Invoke-WslAdmin @('--list', '--quiet')
  if ($LASTEXITCODE -ne 0) { return @() }
  @($out -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function ConvertTo-WslPath([string]$WindowsPath) {
  $full = [IO.Path]::GetFullPath($WindowsPath)
  '/mnt/' + $full.Substring(0, 1).ToLower() + ($full.Substring(2) -replace '\\', '/')
}

# --- 0. WSL usable? -------------------------------------------------------------
Write-Step 'WSL'
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
  throw 'WSL is not installed. In an administrator PowerShell: wsl --install --no-distribution, then restart Windows.'
}
$status = Invoke-WslAdmin @('--status')
Write-Host $status
if ($status -match 'virtualizza|virtualization') {
  throw 'WSL 2 cannot start yet. If you have just installed WSL, restart Windows and run this script again.'
}

# --- 1. Mirrored networking -----------------------------------------------------
Write-Step 'Networking: mirrored (127.0.0.1 in Linux = this Windows machine)'
$wslConfig = Join-Path $env:USERPROFILE '.wslconfig'
$needShutdown = $false
if (-not (Test-Path $wslConfig)) {
  Set-Content -Path $wslConfig -Encoding ASCII -Value "[wsl2]`r`nnetworkingMode=mirrored`r`n"
  $needShutdown = $true
} else {
  $text = Get-Content $wslConfig -Raw
  if ($text -match '(?im)^\s*networkingMode\s*=\s*(\S+)') {
    if ($Matches[1] -ne 'mirrored') {
      Write-Warning "$wslConfig sets networkingMode=$($Matches[1]); left as it is. The tests need 'mirrored' to reach the databases on 127.0.0.1."
    }
  } elseif ($text -match '(?im)^\s*\[wsl2\]') {
    $text = $text -replace '(?im)^(\s*\[wsl2\][^\r\n]*\r?\n)', "`$1networkingMode=mirrored`r`n"
    Set-Content -Path $wslConfig -Encoding ASCII -Value $text -NoNewline
    $needShutdown = $true
  } else {
    Add-Content -Path $wslConfig -Encoding ASCII -Value "`r`n[wsl2]`r`nnetworkingMode=mirrored"
    $needShutdown = $true
  }
}
Write-Host (Get-Content $wslConfig -Raw)

# --- 2. Distribution ------------------------------------------------------------
Write-Step "Distribution $Distro"
if ((Get-WslDistros) -notcontains $Distro) {
  Write-Host 'Downloading and installing (a few minutes)...'
  Invoke-WslAdmin @('--install', '--distribution', $Distro, '--no-launch') | Write-Host
  if ((Get-WslDistros) -notcontains $Distro) {
    # Older store-style packages register only when their launcher runs;
    # "install --root" registers without asking for a user.
    $launcher = 'ubuntu' + ($Distro -replace '[^0-9]', '') + '.exe'
    if (Get-Command $launcher -ErrorAction SilentlyContinue) {
      & $launcher install --root
    }
  }
  if ((Get-WslDistros) -notcontains $Distro) {
    throw "$Distro did not register. Run 'wsl --install -d $Distro' by hand, close it after it asks for a user, then run this script again."
  }
} else {
  Write-Host 'Already installed.'
}

# --- 3. Setup inside Linux ------------------------------------------------------
Write-Step 'Packages and configuration inside Linux (setup_ubuntu.sh)'
$setup = ConvertTo-WslPath (Join-Path $PSScriptRoot 'setup_ubuntu.sh')
$paServer = Join-Path $BdsPath 'PAServer\LinuxPAServer37.0.tar.gz'
$paServerArg = if (Test-Path $paServer) { ConvertTo-WslPath $paServer } else { '' }
# tr strips CR: the script may have been checked out with Windows line endings.
& wsl.exe -d $Distro -u root -- bash -c "tr -d '\r' < '$setup' | bash -s -- '$LinuxUser' '$paServerArg'"
if ($LASTEXITCODE -ne 0) { throw "setup_ubuntu.sh failed (exit $LASTEXITCODE)." }

# --- 4. Restart and check -------------------------------------------------------
Write-Step 'Restarting WSL so the settings take effect'
if ($needShutdown) { & wsl.exe --shutdown } else { & wsl.exe --terminate $Distro | Out-Null }

Write-Step 'Check'
# No double quotes inside: Windows PowerShell 5.1 drops them when passing
# arguments to a native program, and bash then gets a broken command line.
& wsl.exe -d $Distro -- bash -c 'echo user: $(whoami); echo systemd: $(ps -p 1 -o comm=)'
$sql = & wsl.exe -d $Distro -- bash -c "timeout 3 bash -c '</dev/tcp/127.0.0.1/1435' 2>/dev/null && echo reachable || echo NOT reachable"
Write-Host "SQL Server 127.0.0.1:1435 from Linux: $sql"

Write-Host "`nUbuntu is ready. Next: Tools\Linux\Import-LinuxSdk.ps1" -ForegroundColor Green
