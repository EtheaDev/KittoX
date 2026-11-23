<#
.SYNOPSIS
  Puts the JWT path of a KittoX application under concurrent requests of the
  same session, on both HTTP stacks. It is not a measure of speed: what counts
  is the column of the errors, and above all whether any of them is a 500.

.DESCRIPTION
  run_load.ps1 serves HelloKitto, which has no login (Auth: Null). This one
  serves TasKitto: a database behind the login, a JWT in the kx_token cookie,
  the access control read from its claims. With a JWT the session is the one
  the token names (its 'sid' claim), so every request carrying the same token
  lands on the same session object - which is exactly what has to be shaken.

  It needs KXLoadServerTasKitto.exe (KXLoadServer.dpr compiled with -DTASKITTO:
  see the README) and the TasKitto database of Config.yaml reachable.

  For each stack it logs in once, then runs:

    data     kx/view/Customers/data with the token: the token verified, the
             session re-hydrated from its claims, the access control, a query -
             all of it on ONE session object, from every thread.
    page     kx/view/Dashboard with the token: the same, through the rendering
             of a view.
    reload   the two tabs. One generator reads 'data' while another reloads the
             home page WITH the same token: the page refresh replacing the
             session object other requests are being served on, over and over.
             Reaching the home logs the user out and REVOKES the token, on
             purpose (the first reload after a login is the exception), so
             from then on the 'data' requests are refused: 404s are the
             expected answer here, nearly all of them. What must not come
             back is a 500.
    reload-session
             the same, but the reloading tab sends the session cookie only.
             The home still logs the session out, but with no token in the
             request there is nothing to revoke: every 'data' request logs
             the session back in from its own token, and the two fight over
             the same session object for the whole run. Most 'data' requests
             succeed; a few are caught between the logout and the next login
             and are refused with a 404. Again, no 500 is the point.

  It logs in again before every run, so that each starts from a fresh token.

.EXAMPLE
  & .\run_load_jwt.ps1
  & .\run_load_jwt.ps1 -Seconds 15 -Concurrency 2,8,32
#>
[CmdletBinding()]
param(
  [int]    $Port        = 8099,
  [int]    $Seconds     = 8,
  [int]    $Warmup      = 2,
  [int[]]  $Concurrency = @(2, 8, 32),
  [string[]] $Engines   = @('indy', 'httpsys'),
  [string[]] $Scenarios = @('data', 'page', 'reload', 'reload-session'),
  [string] $UserName    = 'admin',
  [string] $Password    = 'password',
  [string] $Database    = 'FireDAC_MSSQL'
)

$ErrorActionPreference = 'Stop'

# Same guard as run_load.ps1, for the same reason: "powershell -File" hands the
# array over as one string, and 2,8,32 becomes the number 2832.
foreach ($c in $Concurrency) {
  if ($c -lt 1 -or $c -gt 1024) {
    throw "Concurrency $c is not a level of concurrency, it is a typo. Start the script with the call operator."
  }
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$server = Join-Path $here 'KXLoadServerTasKitto.exe'
$client = Join-Path $here 'KXLoadTest.exe'
foreach ($exe in @($server, $client)) {
  if (-not (Test-Path $exe)) { throw "Not built: $exe. See the README in this folder." }
}

$base = "http://localhost:$Port/taskittox/"
$urls = @{
  data = $base + 'kx/view/Customers/data'
  page = $base + 'kx/view/Dashboard'
}

# Logs in and returns the Cookie header to send: session and token. The token
# cookie is Secure, and no HTTP client sends a Secure cookie back over plain
# http to anything it does not consider a secure context - which is why it is
# read from the answer and passed by hand, instead of trusting a cookie jar.
function Get-LoginCookie {
  $first = Invoke-WebRequest -Uri $base -UseBasicParsing -TimeoutSec 30
  $sid = ([regex]'TaskittoX=([^;,\s]+)').Match([string]$first.Headers['Set-Cookie']).Groups[1].Value
  $request = [System.Net.HttpWebRequest]::Create($base + 'kx/login')
  $request.Method = 'POST'
  $request.AllowAutoRedirect = $false
  $request.ContentType = 'application/x-www-form-urlencoded'
  $request.Headers.Add('Cookie', "TaskittoX=$sid")
  $body = [Text.Encoding]::UTF8.GetBytes(
    "UserName=$([uri]::EscapeDataString($UserName))&Password=$([uri]::EscapeDataString($Password))&DatabaseName=$([uri]::EscapeDataString($Database))")
  $request.ContentLength = $body.Length
  $stream = $request.GetRequestStream(); $stream.Write($body, 0, $body.Length); $stream.Close()
  try { $response = $request.GetResponse() } catch [System.Net.WebException] { $response = $_.Exception.Response }
  $set = [string]$response.Headers['Set-Cookie']
  $response.Close()
  $token = ([regex]'kx_token=([^;,\s]+)').Match($set).Groups[1].Value
  $session = ([regex]'TaskittoX=([^;,\s]+)').Match($set).Groups[1].Value
  if (-not $token) { throw "Login refused: no kx_token came back. Is the database of Config.yaml reachable, and are the credentials right?" }
  "TaskittoX=$session; kx_token=$token"
}

$serverSeconds = ($Scenarios.Count * $Concurrency.Count * ($Seconds + $Warmup + 6)) + 90

Write-Host ''
Write-Host "KittoX JWT load test (TasKitto) - $($Engines -join ' vs '), port $Port, ${Seconds}s per run (+${Warmup}s warm-up)"
Write-Host ''

foreach ($engine in $Engines) {
  Write-Host "=== $engine ===" -ForegroundColor Cyan
  $out = Join-Path $here "server-jwt-$engine.out"
  $err = Join-Path $here "server-jwt-$engine.err"
  $proc = Start-Process -FilePath $server -WindowStyle Hidden -PassThru `
    -ArgumentList "--engine=$engine", "--port=$Port", "--bind=localhost", "--seconds=$serverSeconds" `
    -RedirectStandardOutput $out -RedirectStandardError $err
  try {
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
        $cookie = Get-LoginCookie
        $common = @("--concurrency=$c", "--seconds=$Seconds", "--warmup=$Warmup")
        if ($scenario -like 'reload*') {
          # Two generators, one session: the home being reloaded while the view
          # is being read. The home goes without X-KittoX - it is a page load.
          $homeCookie = $cookie
          if ($scenario -eq 'reload-session') { $homeCookie = ($cookie -split ';')[0] }
          # Quoted by hand: Start-Process joins the arguments with spaces and
          # quotes nothing, so "session; token" arrived as two arguments and
          # the token was lost - the first version of this script measured
          # 'reload-session' while saying 'reload'.
          $homeArgs = @("--url=$base", "--label=$engine/$scenario-home", "`"--cookie=$homeCookie`"") + $common
          $homeOut = Join-Path $here 'reload-home.out'
          $reloader = Start-Process -FilePath $client -NoNewWindow -PassThru `
            -RedirectStandardOutput $homeOut -ArgumentList $homeArgs
          & $client "--url=$($urls['data'])" "--label=$engine/$scenario-data" '--header=X-KittoX: true' "--cookie=$cookie" @common
          $reloader.WaitForExit()
          Get-Content $homeOut
          Remove-Item $homeOut -ErrorAction SilentlyContinue
        }
        else {
          & $client "--url=$($urls[$scenario])" "--label=$engine/$scenario" '--header=X-KittoX: true' "--cookie=$cookie" @common
        }
      }
    }
  }
  finally {
    if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
    Start-Sleep -Milliseconds 500
  }
  Write-Host ''
}
