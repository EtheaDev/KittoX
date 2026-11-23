<#
.SYNOPSIS
  Measures a KittoX application on both HTTP stacks, Indy and HTTP.sys, and
  prints the two sets of numbers side by side.

.DESCRIPTION
  For each stack it starts KXLoadServer on that stack, runs KXLoadTest against
  it for every scenario and every level of concurrency, then stops it. The two
  runs are sequential and use the same port: they never overlap, and neither
  pays for the other.

  Scenarios:
    home     the home page of the application, with the session cookie:
             the whole pipeline - session, routing, metadata, rendering
    static   a stylesheet out of Resources, with the session cookie: the short
             path, where the stack itself weighs most
    cold     the home page WITHOUT a cookie: every request opens a session.
             Not what a browser does, and that is the point - it measures what
             a storm of first visits costs

  What it does not measure, and has to be said: the generator runs on the same
  machine as the server, so the two share the processor. The numbers are good
  for comparing one stack with the other - which is what they are for - and
  not for stating how many requests a server can take.

.EXAMPLE
  .\run_load.ps1
  .\run_load.ps1 -Seconds 20 -Concurrency 1,16,64 -Scenarios home,static
#>
[CmdletBinding()]
param(
  [int]    $Port        = 8099,
  [int]    $Seconds     = 10,
  [int]    $Warmup      = 2,
  [int[]]  $Concurrency = @(1, 8, 32, 64),
  [string[]] $Engines   = @('indy', 'httpsys'),
  [string[]] $Scenarios = @('home', 'static', 'cold'),
  [string] $Csv         = ''
)

$ErrorActionPreference = 'Stop'

# A guard, and it is not pedantry: started as "powershell -File run_load.ps1
# -Concurrency 1,8,32,64" the array arrives as ONE string and PowerShell reads
# it as the number 183264. That run started a hundred and eighty-three thousand
# threads against the server and produced nothing but timeouts. Start the script
# with the call operator instead, and if a level of concurrency still looks like
# a typo, stop here.
foreach ($c in $Concurrency) {
  if ($c -lt 1 -or $c -gt 1024) {
    throw "Concurrency $c is not a level of concurrency, it is a typo. If the script was started with 'powershell -File', the array arrived as one string: use the call operator instead."
  }
}
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$server = Join-Path $here 'KXLoadServer.exe'
$client = Join-Path $here 'KXLoadTest.exe'

foreach ($exe in @($server, $client)) {
  if (-not (Test-Path $exe)) {
    throw "Not built: $exe. See the README in this folder."
  }
}

if (-not $Csv) { $Csv = Join-Path $here ('results-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.csv') }

$base = "http://localhost:$Port/hellokittox/"
$urls = @{
  home   = $base
  static = $base + 'res/css/kittox.css'
  cold   = $base
}

# Enough for every scenario of one engine, plus room to spare: the server is
# stopped as soon as the run is over anyway.
$serverSeconds = ($Scenarios.Count * $Concurrency.Count * ($Seconds + $Warmup + 3)) + 60

Write-Host ''
Write-Host "KittoX load test - $($Engines -join ' vs '), port $Port, ${Seconds}s per run (+${Warmup}s warm-up)"
Write-Host ("Processor: {0} logical cores" -f [Environment]::ProcessorCount)
Write-Host "Results: $Csv"
Write-Host ''

foreach ($engine in $Engines) {
  Write-Host "=== $engine ===" -ForegroundColor Cyan

  $out = Join-Path $here "server-$engine.out"
  $err = Join-Path $here "server-$engine.err"
  $proc = Start-Process -FilePath $server -WindowStyle Hidden -PassThru `
    -ArgumentList "--engine=$engine", "--port=$Port", "--bind=localhost", "--seconds=$serverSeconds" `
    -RedirectStandardOutput $out -RedirectStandardError $err

  try {
    # Wait for it to answer rather than for a number of seconds: a machine that
    # is busy starts slower, and a fixed wait would measure that.
    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
      Start-Sleep -Milliseconds 500
      try {
        $r = Invoke-WebRequest -Uri $base -UseBasicParsing -TimeoutSec 5
        if ($r.StatusCode -eq 200) { $ready = $true; break }
      } catch { }
    }
    if (-not $ready) {
      Write-Host (Get-Content $out -ErrorAction SilentlyContinue) -ForegroundColor Red
      throw "$engine did not come up."
    }

    foreach ($scenario in $Scenarios) {
      foreach ($c in $Concurrency) {
        $args = @(
          "--url=$($urls[$scenario])",
          "--concurrency=$c",
          "--seconds=$Seconds",
          "--warmup=$Warmup",
          "--label=$engine/$scenario",
          "--csv=$Csv"
        )
        # Every scenario but 'cold' reuses one session, as a browser does.
        if ($scenario -ne 'cold') { $args += '--session' }
        & $client @args
      }
    }
  }
  finally {
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
    Start-Sleep -Milliseconds 500
  }
  Write-Host ''
}

# ---- the comparison, which is the point of all this ------------------------
if (Test-Path $Csv) {
  $rows = Import-Csv $Csv -Delimiter ';'
  Write-Host '=== Requests per second ===' -ForegroundColor Cyan
  $byKey = @{}
  foreach ($row in $rows) {
    $engine, $scenario = $row.label -split '/'
    $key = "$scenario|$($row.concurrency)"
    if (-not $byKey.ContainsKey($key)) { $byKey[$key] = @{} }
    $byKey[$key][$engine] = [double]$row.rps
    $byKey[$key]["p99_$engine"] = [double]$row.p99_ms
    $byKey[$key]["err_$engine"] = [int]$row.errors
  }
  $table = foreach ($key in ($byKey.Keys | Sort-Object)) {
    $scenario, $c = $key -split '\|'
    $indy = $byKey[$key]['indy']
    $http = $byKey[$key]['httpsys']
    [PSCustomObject]@{
      Scenario = $scenario
      Conc     = [int]$c
      'Indy'   = if ($indy) { [math]::Round($indy, 0) } else { '-' }
      'HTTP.sys' = if ($http) { [math]::Round($http, 0) } else { '-' }
      'Ratio'  = if ($indy -and $http -and $indy -gt 0) { [math]::Round($http / $indy, 2) } else { '-' }
      'p99 Indy'    = if ($byKey[$key]['p99_indy']) { [math]::Round($byKey[$key]['p99_indy'], 1) } else { '-' }
      'p99 HTTP.sys' = if ($byKey[$key]['p99_httpsys']) { [math]::Round($byKey[$key]['p99_httpsys'], 1) } else { '-' }
      'err I/H' = "$($byKey[$key]['err_indy'])/$($byKey[$key]['err_httpsys'])"
    }
  }
  $table | Sort-Object Scenario, Conc | Format-Table -AutoSize
}
