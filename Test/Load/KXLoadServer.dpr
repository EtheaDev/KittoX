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

/// The server under measurement: a KittoX application served headless, on the
/// stack named on the command line. It is the console host of the framework
/// with the stack taken from an argument instead of from the configuration,
/// which is what lets the same application be measured on both without
/// editing a file between runs.
///
/// It serves HelloKitto by default: the example everybody has, with a real
/// home page and a real static resource.
///
/// Compiled with -DTASKITTO it links the units of TasKitto instead, and serves
/// that: the example with a database behind the login and a JWT in the
/// cookie, which is the path HelloKitto (Auth: Null) never takes. The units of
/// an application register its controllers, rules and authenticator, so which
/// application is served is decided when compiling, not with --home alone.
///
///   KXLoadServer --engine=indy --port=8099 [--home=<path>] [--bind=localhost]
///                [--seconds=0]
///
/// --seconds=0 (the default) waits for a line on standard input, which is what
/// a person wants; a number is what a script wants, because a process started
/// without a console reads end-of-file at once.
program KXLoadServer;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  EF.Logger,
  Kitto.Config,
  Kitto.Web.Application,
  Kitto.Web.Host,
{$IFDEF TASKITTO}
  Rules in '..\..\Examples\TasKitto\Source\Rules.pas',
  Auth in '..\..\Examples\TasKitto\Source\Auth.pas',
  UseKitto in '..\..\Examples\TasKitto\Source\UseKitto.pas';
{$ELSE}
  Controllers in '..\..\Examples\HelloKitto\Source\Controllers.pas',
  Rules in '..\..\Examples\HelloKitto\Source\Rules.pas',
  UseKitto in '..\..\Examples\HelloKitto\Source\UseKitto.pas';
{$ENDIF}

const
{$IFDEF TASKITTO}
  DEFAULT_HOME = '..\..\Examples\TasKitto\Home\';
{$ELSE}
  DEFAULT_HOME = '..\..\Examples\HelloKitto\Home\';
{$ENDIF}

function Arg(const AName, ADefault: string): string;
var
  I: Integer;
  LPrefix: string;
begin
  LPrefix := '--' + AName + '=';
  for I := 1 to ParamCount do
    if ParamStr(I).StartsWith(LPrefix, True) then
      Exit(ParamStr(I).Substring(LPrefix.Length));
  Result := ADefault;
end;

var
  LHost: TKWebHost;
  LApplication: TKWebApplication;
  LPort, LSeconds: Integer;
  LEngine, LBind, LHome: string;

begin
  try
    LHome := Arg('home', ExtractFilePath(ParamStr(0)) + DEFAULT_HOME);
    LHome := IncludeTrailingPathDelimiter(ExpandFileName(LHome));
    TKConfig.AppHomePath := LHome;
    TKConfig.SystemHomePath := IncludeTrailingPathDelimiter(
      ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\..\Home'));

    LEngine := Arg('engine', 'indy');
    LPort := StrToIntDef(Arg('port', '8099'), 8099);
    LBind := Arg('bind', 'localhost');
    LSeconds := StrToIntDef(Arg('seconds', '0'), 0);

    WriteLn('--- KittoX load server ---');
    WriteLn('Home:   ', TKConfig.AppHomePath);
    WriteLn('Engine: ', LEngine);
    WriteLn('Port:   ', LPort);
    WriteLn('Bind:   ', LBind);
    Flush(Output);

    LHost := TKWebHost.CreateByName(LEngine);
    try
      LApplication := TKWebApplication.Create;
      LHost.Engine.AddRoute(LApplication);
      LHost.Setup(LApplication.Config);
      LHost.DefaultPort := LPort;
      LHost.BindAddress := LBind;
      LHost.Active := True;

      WriteLn('READY ', LHost.EngineName, ' ', LApplication.GetHomeURL(LPort));
      Flush(Output);

      if LSeconds > 0 then
        Sleep(LSeconds * 1000)
      else
      begin
        WriteLn('Press enter to stop.');
        Flush(Output);
        ReadLn;
      end;

      LHost.Active := False;
      WriteLn('STOPPED');
      Flush(Output);
    finally
      LHost.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('FAILED: ', E.ClassName, ': ', E.Message);
      Flush(Output);
      ExitCode := 1;
    end;
  end;
end.
