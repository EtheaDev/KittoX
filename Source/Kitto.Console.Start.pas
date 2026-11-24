{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------}

unit Kitto.Console.Start;

{$I Kitto.Defines.inc}

interface

uses
  EF.Logger;

type
  /// <summary>
  ///  Starts the web server without a user interface.
  ///  On Windows it runs until Enter is pressed. On Linux (and any POSIX
  ///  system) it runs until SIGTERM, SIGINT or SIGHUP: that is how systemd
  ///  stops a service, and Ctrl+C in a terminal. Waiting on the console instead
  ///  would not work under systemd, whose stdin is /dev/null: ReadLn returns at
  ///  once and the server would stop as soon as it started.
  ///  Command line: -c <config file name> picks the configuration, -home <path>
  ///  the application home (see TKConfig).
  /// </summary>
  TKStart = class
  public
    class procedure Start;
  end;

  /// <summary>
  ///  Writes the log to the standard output. Enabled by Log/Console/IsEnabled;
  ///  on POSIX it is on unless that is explicitly False, because the standard
  ///  output of a systemd service is the journal (journalctl -u <service>).
  /// </summary>
  TKConsoleLogEndpoint = class(TEFLogEndpoint)
  protected
    procedure DoLog(const AString: string); override;
  end;

implementation

uses
  System.SysUtils,
  {$IFDEF POSIX}
  System.SyncObjs,
  Posix.Signal,
  {$ENDIF}
  EF.Localization,
  EF.Macros,
  EF.Sys,
  EF.Tree,
  Kitto.Config,
  Kitto.Web.Host,
  Kitto.Web.Application;

{$IFDEF POSIX}
var
  // Log lines come from the request threads too: without it they interleave.
  _ConsoleLock: TCriticalSection;

/// <summary>
///  The set of signals that stop the server.
/// </summary>
function TerminationSignals: sigset_t;
begin
  sigemptyset(Result);
  sigaddset(Result, SIGTERM);
  sigaddset(Result, SIGINT);
  sigaddset(Result, SIGHUP);
end;

/// <summary>
///  Blocks the termination signals in the calling thread, so that they wait
///  for sigwait instead of killing the process. Must run on the main thread
///  before any other thread is created: a thread inherits the mask of the one
///  that creates it, and a signal is delivered to any thread that does not
///  block it - an Indy worker thread would take the default action, which is
///  to end the process without stopping the server or closing anything.
///  SIGPIPE is ignored: a write to a connection the other side has closed
///  must be an error to handle, not the end of the process.
/// </summary>
procedure BlockTerminationSignals;
var
  LSet: sigset_t;
begin
  LSet := TerminationSignals;
  pthread_sigmask(SIG_BLOCK, @LSet, nil);
  signal(SIGPIPE, TSignalHandler(SIG_IGN));
end;

/// <summary>
///  Waits for one of the termination signals and returns it.
/// </summary>
function WaitForTerminationSignal: Integer;
var
  LSet: sigset_t;
begin
  LSet := TerminationSignals;
  Result := 0;
  // sigwait returns an error number, not -1 with errno, and is not interrupted
  // by signals outside the set: a non-zero result is a real failure, and then
  // stopping is the only safe course.
  if sigwait(LSet, @Result) <> 0 then
    Result := 0;
end;

function SignalName(const ASignal: Integer): string;
begin
  case ASignal of
    SIGTERM: Result := 'SIGTERM';
    SIGINT: Result := 'SIGINT';
    SIGHUP: Result := 'SIGHUP';
  else
    Result := IntToStr(ASignal);
  end;
end;
{$ENDIF}

{ TKStart }

class procedure TKStart.Start;
var
  LLogEndPoint: TKConsoleLogEndpoint;
  LServer: TKWebHost;
  LApplication: TKWebApplication;
  {$IFDEF POSIX}
  LSignal: Integer;
  {$ENDIF}

  procedure Configure;
  var
    LConfig: TKConfig;
    LLogNode: TEFNode;
    LCustomConfig: string;
  begin
    LCustomConfig := GetCmdLineParamValue('c');
    if LCustomConfig <> '' then
      TKConfig.BaseConfigFileName := LCustomConfig;
    LConfig := TKConfig.Create;
    try
      LLogNode := LConfig.Config.FindNode('Log');
      {$IFDEF MSWINDOWS}
      if Assigned(LLogNode) and LLogNode.GetBoolean('Console/IsEnabled') then
        LLogEndPoint := TKConsoleLogEndpoint.Create;
      {$ELSE}
      if not Assigned(LLogNode) or LLogNode.GetBoolean('Console/IsEnabled', True) then
        LLogEndPoint := TKConsoleLogEndpoint.Create;
      {$ENDIF}
      // After the endpoint exists, so that it receives the configuration too.
      TEFLogger.Instance.Configure(LLogNode, TEFMacroExpansionEngine.Instance);
      TEFLogger.Instance.Log(Format('Using configuration: %s', [LConfig.BaseConfigFileName]));
    finally
      FreeAndNil(LConfig);
    end;
  end;

begin
  {$IFDEF POSIX}
  BlockTerminationSignals;
  {$ENDIF}
  LLogEndPoint := nil;
  Configure;
  try
    WriteLn(Format(_('Build date: %s'), [DateTimeToStr(GetFileDateTime(ParamStr(0)))]));
    TEFLogger.Instance.LogDetailed('Console start. Initializing web server...');
    // Which stack serves it is in Server/Engine; the console does not care.
    LServer := TKWebHost.CreateDefault;
    try
      LApplication := TKWebApplication.Create;
      LServer.Engine.AddRoute(LApplication);
      TEFLogger.Instance.LogDetailed('Console start. Turning on web server...');
      LServer.Active := True;
      TEFLogger.Instance.LogDetailed('Console start. Web server on (' +
        LServer.EngineName + ').');
      TEFLogger.Instance.Log(Format(_('Home URL: %s'), [LApplication.GetHomeURL(LServer.DefaultPort)]));
      {$IFDEF MSWINDOWS}
      WriteLn('Press enter to exit.');
      ReadLn;
      {$ELSE}
      TEFLogger.Instance.Log('Running. Stop with Ctrl+C or SIGTERM (systemctl stop).');
      LSignal := WaitForTerminationSignal;
      TEFLogger.Instance.Log(Format('Received %s. Stopping web server...', [SignalName(LSignal)]));
      {$ENDIF}
      LServer.Active := False;
      TEFLogger.Instance.Log('Web server stopped.');
    finally
      FreeAndNil(LServer);
    end;
  finally
    FreeAndNil(LLogEndPoint);
  end;
end;

{ TKConsoleLogEndpoint }

procedure TKConsoleLogEndpoint.DoLog(const AString: string);
begin
  inherited;
  {$IFDEF POSIX}
  _ConsoleLock.Enter;
  try
    Writeln(AString);
    // Under systemd the standard output is a pipe to the journal, which the
    // RTL buffers: without the flush lines reach the journal late, in bursts,
    // and the last ones before a crash not at all.
    Flush(Output);
  finally
    _ConsoleLock.Leave;
  end;
  {$ELSE}
  Writeln(AString);
  {$ENDIF}
end;

{$IFDEF POSIX}
initialization
  _ConsoleLock := TCriticalSection.Create;

finalization
  FreeAndNil(_ConsoleLock);
{$ENDIF}

end.
