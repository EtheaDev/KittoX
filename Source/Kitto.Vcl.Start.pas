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

unit Kitto.Vcl.Start;

{$I Kitto.Defines.inc}

interface

type
  TKStart = class
  public
    class procedure Start;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  EF.Tree,
  EF.Logger,
  EF.Macros,
  Kitto.Config,
  EF.Sys,
  {$IFDEF MSWINDOWS}
  Vcl.Forms,
  Vcl.SvcMgr,
  Vcl.Themes,
  Vcl.Styles,
  EF.Sys.Windows,
  Kitto.Vcl.MainForm,
  Kitto.Vcl.Service;
  {$ELSE}
  Kitto.Console.Start;
  {$ENDIF}

{ TKStart }

class procedure TKStart.Start;

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
      TEFLogger.Instance.Configure(LLogNode, TEFMacroExpansionEngine.Instance);
      TEFLogger.Instance.Log(Format('Using configuration: %s',[LConfig.BaseConfigFileName]));
    finally
      FreeAndNil(LConfig);
    end;
  end;

begin
  {$IFNDEF MSWINDOWS}
  // No VCL and no Windows service elsewhere: the same program runs headless,
  // as a systemd service or from a terminal. The console start configures
  // itself (-c included), so Configure is not called here.
  Kitto.Console.Start.TKStart.Start;
  Exit;
  {$ENDIF}
  Configure;
  {$IFDEF MSWINDOWS}
  if IsRunningAsService or IsInstallingService then
  begin
    TEFLogger.Instance.Log('Starting as service.');
    if not Vcl.SvcMgr.Application.DelayInitialize or Vcl.SvcMgr.Application.Installing then
      Vcl.SvcMgr.Application.Initialize;
    Vcl.SvcMgr.Application.CreateForm(TKService, KService);
    Vcl.SvcMgr.Application.Run;
  end
  else
  begin
    TEFLogger.Instance.Log('Starting as application.');
    Vcl.Forms.Application.Initialize;
    Vcl.Forms.Application.CreateForm(TKMainForm, KMainForm);
    Vcl.Forms.Application.Run;
  end;
  {$ENDIF}
end;

initialization
  {$IFDEF MSWINDOWS}
  {$WARN SYMBOL_PLATFORM OFF}
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  {$ENDIF}

end.
