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

/// <summary>
///  What a stand-alone KittoX application talks to when it wants to be served:
///  an engine, a port, and a switch. Which HTTP stack is behind it -
///  <b>Indy</b> or <b>HTTP.sys</b> - is read from <c>Server/Engine</c> and is
///  not the business of the window, the service or the console that starts it.
///  <para>Before this unit the three of them named <c>TKWebServer</c>, an Indy
///  class, and choosing another stack would have meant touching all three. The
///  surface they actually used was six members wide, and this is it.</para>
///  <para>What is <b>not</b> here, on purpose: the preview of KIDEX and the
///  embedded host (<see cref="Kitto.Vcl.Embedded" />) keep naming the Indy
///  server. They run inside another process, on a port nobody reserved, to be
///  read by an embedded browser: a kernel-mode queue would buy them nothing
///  and would ask for a URL reservation they have no way to get.</para>
/// </summary>
unit Kitto.Web.Host;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils
  , Kitto.Config
  , Kitto.Web.Engine
  ;

type
  /// <summary>
  ///  A host of the KittoX engine. Owns the engine and the stack that feeds
  ///  it; everything a starter needs is on this class.
  /// </summary>
  TKWebHost = class abstract
  strict protected
    function GetEngine: TKWebEngine; virtual; abstract;
    function GetActive: Boolean; virtual; abstract;
    procedure SetActive(const AValue: Boolean); virtual; abstract;
    function GetDefaultPort: Integer; virtual; abstract;
    procedure SetDefaultPort(const AValue: Integer); virtual; abstract;
    function GetBindAddress: string; virtual; abstract;
    procedure SetBindAddress(const AValue: string); virtual; abstract;
  public
    /// <summary>Reads port, bind address and the rest from the application
    /// configuration. Called once, after the routes have been added.</summary>
    procedure Setup(const AConfig: TKConfig); virtual; abstract;

    /// <summary>The name of the stack behind this host, for a log line and for
    /// the window that shows it.</summary>
    function EngineName: string; virtual; abstract;

    /// <summary>The engine this host serves.</summary>
    property Engine: TKWebEngine read GetEngine;
    /// <summary>Starting and stopping.</summary>
    property Active: Boolean read GetActive write SetActive;
    /// <summary>The port it listens on.</summary>
    property DefaultPort: Integer read GetDefaultPort write SetDefaultPort;

    /// <summary>
    ///  Which interface to answer on, when it is not the one the configuration
    ///  says. Empty is every one of them.
    ///  <para>It is written after <c>Setup</c> and before <c>Active</c>, and it
    ///  is what a program driven by arguments needs: a load test, a tool, a
    ///  second instance beside a running one. With HTTP.sys it is also the
    ///  difference between a URL that needs a reservation and one that does
    ///  not.</para>
    /// </summary>
    property BindAddress: string read GetBindAddress write SetBindAddress;

    /// <summary>
    ///  The host the configuration asks for: <c>Server/Engine</c>, which is
    ///  <c>Indy</c> unless it says otherwise.
    ///  <para>A name that is not a stack - a typo, a stack this build does not
    ///  have - falls back to Indy and says so in the log rather than refusing
    ///  to start: an application that will not come up is a worse answer than
    ///  one that comes up on the stack it always used.</para>
    /// </summary>
    class function CreateDefault: TKWebHost;

    /// <summary>The Indy host, whatever the configuration says. For the places
    /// that have a reason: the preview, the embedded host, a test.</summary>
    class function CreateIndy: TKWebHost;

    /// <summary>
    ///  The host of a given name - <c>indy</c>, <c>httpsys</c> - for a program
    ///  that is told which one to use instead of reading it. A name that is not
    ///  a stack gives Indy, as it does when the configuration says it.
    /// </summary>
    class function CreateByName(const AEngine: string): TKWebHost;
  end;

const
  /// <summary>Values of <c>Server/Engine</c>.</summary>
  KX_SERVER_ENGINE_INDY = 'indy';
  KX_SERVER_ENGINE_HTTPSYS = 'httpsys';

implementation

uses
  System.Classes
  , EF.Logger
  , EF.Localization
  , Kitto.Web.Server
{$IFDEF MSWINDOWS}
  , Kitto.Web.Server.HttpSys
{$ENDIF}
  ;

type
  /// <summary>The Indy host: the one KittoX has always had.</summary>
  TKIndyWebHost = class(TKWebHost)
  strict private
    FServer: TKWebServer;
  strict protected
    function GetEngine: TKWebEngine; override;
    function GetActive: Boolean; override;
    procedure SetActive(const AValue: Boolean); override;
    function GetDefaultPort: Integer; override;
    procedure SetDefaultPort(const AValue: Integer); override;
    function GetBindAddress: string; override;
    procedure SetBindAddress(const AValue: string); override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Setup(const AConfig: TKConfig); override;
    function EngineName: string; override;
  end;

{$IFDEF MSWINDOWS}
  /// <summary>The HTTP.sys host.</summary>
  TKHttpSysWebHost = class(TKWebHost)
  strict private
    FServer: TKHttpSysServer;
  strict protected
    function GetEngine: TKWebEngine; override;
    function GetActive: Boolean; override;
    procedure SetActive(const AValue: Boolean); override;
    function GetDefaultPort: Integer; override;
    procedure SetDefaultPort(const AValue: Integer); override;
    function GetBindAddress: string; override;
    procedure SetBindAddress(const AValue: string); override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Setup(const AConfig: TKConfig); override;
    function EngineName: string; override;
  end;
{$ENDIF}

{ TKWebHost }

class function TKWebHost.CreateIndy: TKWebHost;
begin
  Result := TKIndyWebHost.Create;
end;

class function TKWebHost.CreateDefault: TKWebHost;
var
  LConfig: TKConfig;
  LEngine: string;
begin
  // Server-wide, like the port: read from a configuration of its own, because
  // the application configs are per application.
  LConfig := TKConfig.Create;
  try
    LEngine := LConfig.Config.GetString('Server/Engine', KX_SERVER_ENGINE_INDY);
  finally
    LConfig.Free;
  end;
  Result := CreateByName(LEngine);
end;

class function TKWebHost.CreateByName(const AEngine: string): TKWebHost;
var
  LEngine: string;
begin
  LEngine := AEngine.Trim.ToLower;

  if (LEngine = '') or (LEngine = KX_SERVER_ENGINE_INDY) then
    Exit(TKIndyWebHost.Create);

{$IFDEF MSWINDOWS}
  if LEngine = KX_SERVER_ENGINE_HTTPSYS then
    Exit(TKHttpSysWebHost.Create);
{$ENDIF}

  TEFLogger.Instance.LogHigh(Format(
    _('Server/Engine says "%s", which this build does not have: starting on Indy.'),
    [LEngine]));
  Result := TKIndyWebHost.Create;
end;

{ TKIndyWebHost }

constructor TKIndyWebHost.Create;
begin
  inherited Create;
  FServer := TKWebServer.Create(nil);
end;

destructor TKIndyWebHost.Destroy;
begin
  FServer.Free;
  inherited;
end;

function TKIndyWebHost.EngineName: string;
begin
  Result := 'Indy';
end;

function TKIndyWebHost.GetEngine: TKWebEngine;
begin
  Result := FServer.Engine;
end;

function TKIndyWebHost.GetActive: Boolean;
begin
  Result := FServer.Active;
end;

procedure TKIndyWebHost.SetActive(const AValue: Boolean);
begin
  FServer.Active := AValue;
end;

function TKIndyWebHost.GetDefaultPort: Integer;
begin
  Result := FServer.DefaultPort;
end;

procedure TKIndyWebHost.SetDefaultPort(const AValue: Integer);
begin
  FServer.DefaultPort := AValue;
end;

procedure TKIndyWebHost.Setup(const AConfig: TKConfig);
begin
  FServer.Setup(AConfig);
end;

function TKIndyWebHost.GetBindAddress: string;
begin
  if FServer.Bindings.Count > 0 then
    Result := FServer.Bindings[0].IP
  else
    Result := '';
end;

procedure TKIndyWebHost.SetBindAddress(const AValue: string);
begin
  // The bindings are the way Indy says it: one entry, address and port. Empty
  // puts back every interface, which is what no bindings at all means.
  FServer.Bindings.Clear;
  if AValue <> '' then
    with FServer.Bindings.Add do
    begin
      IP := AValue;
      Port := FServer.DefaultPort;
    end;
end;

{$IFDEF MSWINDOWS}

{ TKHttpSysWebHost }

constructor TKHttpSysWebHost.Create;
begin
  inherited Create;
  FServer := TKHttpSysServer.Create;
end;

destructor TKHttpSysWebHost.Destroy;
begin
  FServer.Free;
  inherited;
end;

function TKHttpSysWebHost.EngineName: string;
begin
  Result := 'HTTP.sys';
end;

function TKHttpSysWebHost.GetEngine: TKWebEngine;
begin
  Result := FServer.Engine;
end;

function TKHttpSysWebHost.GetActive: Boolean;
begin
  Result := FServer.Active;
end;

procedure TKHttpSysWebHost.SetActive(const AValue: Boolean);
begin
  FServer.Active := AValue;
end;

function TKHttpSysWebHost.GetDefaultPort: Integer;
begin
  Result := FServer.DefaultPort;
end;

procedure TKHttpSysWebHost.SetDefaultPort(const AValue: Integer);
begin
  FServer.DefaultPort := AValue;
end;

procedure TKHttpSysWebHost.Setup(const AConfig: TKConfig);
begin
  FServer.Setup(AConfig);
end;

function TKHttpSysWebHost.GetBindAddress: string;
begin
  Result := FServer.BindAddress;
end;

procedure TKHttpSysWebHost.SetBindAddress(const AValue: string);
begin
  FServer.BindAddress := AValue;
end;

{$ENDIF}

end.
