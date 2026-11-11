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
///  WebBroker bridge for KittoX. Hosts a single global TKWebEngine and adapts
///  TWebRequest/TWebResponse to it, so the same engine can serve requests under
///  IIS (ISAPI) or Apache without any application-specific code.
/// </summary>
unit Kitto.WebBroker.Handler;

{$I Kitto.Defines.inc}

interface

uses
  Web.HTTPApp,
  Kitto.Web.Engine;

type
  /// <summary>
  ///  Singleton object that maintains a global instance of a Kitto engine.
  ///  Together with TKWebModule, provides for zero-code implementation of
  ///  Webbroker-based Kitto apps (just create a standard WebBroker app and
  ///  add the Kitto.WebBroker.WebModule unit to the uses clause).
  /// </summary>
  TKWebBrokerHandler = class
  private
    FEngine: TKWebEngine;
    class var FCurrent: TKWebBrokerHandler;
    class function GetCurrent: TKWebBrokerHandler; static;
    function GetEngine: TKWebEngine;
    procedure InitializeEngine;
  public
    class constructor Create;
    class destructor Destroy;
    procedure AfterConstruction; override;
    destructor Destroy; override;
  public
    /// <summary>The process-wide singleton handler instance.</summary>
    class property Current: TKWebBrokerHandler read GetCurrent;

    /// <summary>The hosted web engine, lazily created on first access.</summary>
    property Engine: TKWebEngine read GetEngine;

    /// <summary>Builds the full URL from the WebBroker request and delegates it to the
    /// engine; returns True when handled (always True — emits a diagnostic 500 page on
    /// no-match or on exception).</summary>
    function HandleRequest(const ARequest: TWebRequest; const AResponse: TWebResponse): Boolean;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.NetEncoding,
  EF.Tree,
  EF.Logger,
  EF.Logger.TextFile,
  EF.Macros,
  Kitto.Config,
  Kitto.Web.Application;

{ TKWebBrokerHandler }

procedure DebugLog(const AMsg: string);
var
  LFile: TextFile;
  LPath: string;
begin
  // Write to a fixed log file next to the DLL for early diagnostics
  LPath := ExtractFilePath(GetModuleName(HInstance)) + 'webbroker_debug.log';
  try
    AssignFile(LFile, LPath);
    if FileExists(LPath) then
      Append(LFile)
    else
      Rewrite(LFile);
    try
      WriteLn(LFile, FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + AMsg);
    finally
      CloseFile(LFile);
    end;
  except
    // Silently ignore if we can't write
  end;
end;

procedure TKWebBrokerHandler.AfterConstruction;
begin
  inherited;
  // Defer all initialization to GetEngine (lazy init on first request).
  // The class constructor runs at DLL load time — doing heavy work there
  // (TKConfig, TKWebEngine, DB connections) can deadlock Apache.
end;

procedure TKWebBrokerHandler.InitializeEngine;
var
  LConfig: TKConfig;
  LLogNode: TEFNode;
begin
  DebugLog('InitializeEngine: start');
  DebugLog('ModulePath = ' + TKConfig.GetModulePath);
  DebugLog('AppHomePath = ' + TKConfig.AppHomePath);
  DebugLog('SystemHomePath = ' + TKConfig.SystemHomePath);

  // Initialize logging from Config.yaml
  try
    DebugLog('Creating TKConfig...');
    LConfig := TKConfig.Create;
    try
      DebugLog('Config created, reading Log node...');
      LLogNode := LConfig.Config.FindNode('Log');
      TEFLogger.Instance.Configure(LLogNode, TEFMacroExpansionEngine.Instance);
      TEFLogger.Instance.Log('WebBroker: Logging initialized from ' + LConfig.BaseConfigFileName, TEFLogger.LOG_DEBUG);
      TEFLogger.Instance.Log('WebBroker: AppHomePath = ' + TKConfig.AppHomePath, TEFLogger.LOG_DEBUG);
      TEFLogger.Instance.Log('WebBroker: SystemHomePath = ' + TKConfig.SystemHomePath, TEFLogger.LOG_DEBUG);
      DebugLog('Logging configured OK');
    finally
      FreeAndNil(LConfig);
    end;
  except
    on E: Exception do
    begin
      DebugLog('Error initializing config: ' + E.Message);
      TEFLogger.Instance.Log('WebBroker: Error initializing config: ' + E.Message);
    end;
  end;

  DebugLog('Creating TKWebEngine...');
  try
    FEngine := TKWebEngine.Create;
    FEngine.AddRoute(TKWebApplication.Create);
    FEngine.Active := True;
    DebugLog('TKWebEngine created, application added, activated OK');
  except
    on E: Exception do
      DebugLog('Error creating TKWebEngine: ' + E.Message);
  end;
  DebugLog('InitializeEngine: done');
end;

class constructor TKWebBrokerHandler.Create;
begin
  FCurrent := TKWebBrokerHandler.Create;
end;

class destructor TKWebBrokerHandler.Destroy;
begin
  FreeAndNil(FCurrent);
end;

destructor TKWebBrokerHandler.Destroy;
begin
  FreeAndNil(FEngine);
  inherited;
end;

class function TKWebBrokerHandler.GetCurrent: TKWebBrokerHandler;
begin
  Result := FCurrent;
end;

function TKWebBrokerHandler.GetEngine: TKWebEngine;
begin
  if not Assigned(FEngine) then
    InitializeEngine;
  Result := FEngine;
end;

function TKWebBrokerHandler.HandleRequest(const ARequest: TWebRequest;
  const AResponse: TWebResponse): Boolean;
var
  LURL: string;
begin
  // Build the full URL path from the request.
  // ISAPI: PathInfo = full path (e.g. /hellokittox/kx/view/...), ScriptName = alias
  // Apache: ScriptName = app alias (e.g. /hellokittox), PathInfo = path after alias (e.g. /kx/view/...)
  // Standalone: URL = full path
  if ARequest.ScriptName <> '' then
    LURL := ARequest.ScriptName + ARequest.PathInfo  // Apache module (PathInfo empty on the app root)
  else if ARequest.PathInfo <> '' then
    LURL := ARequest.PathInfo                         // ISAPI
  else
    LURL := ARequest.URL;                             // Fallback
  // If the URL is the app root without trailing slash, redirect the browser
  // so that relative URLs in the HTML (e.g. "kx/login") resolve correctly.
  if (LURL <> '') and (LURL[Length(LURL)] <> '/')
    and not LURL.Contains('/kx/')
    and not LURL.Contains('/res/') then
  begin
    // The slash goes into the path; the query string is re-attached after it.
    LURL := LURL + '/';
    if ARequest.Query <> '' then
      LURL := LURL + '?' + ARequest.Query;
    AResponse.SendRedirect(LURL);
    Result := True;
    Exit;
  end;
  TEFLogger.Instance.Log('WebBroker Request: Method=' + ARequest.Method +
    ' PathInfo=' + ARequest.PathInfo +
    ' URL=' + ARequest.URL +
    ' ScriptName=' + ARequest.ScriptName, TEFLogger.LOG_DEBUG);
  try
    Result := Engine.SimpleHandleRequest(ARequest, AResponse, LURL);
    if not Result then
    begin
      // No route matched — return diagnostic 500 instead of empty 200
      AResponse.StatusCode := 500;
      AResponse.ContentType := 'text/html; charset=utf-8';
      AResponse.Content :=
        '<html><head><meta charset="utf-8"><title>KittoX Configuration Error</title></head><body>' +
        '<h1>500 &mdash; KittoX Configuration Error</h1>' +
        '<p>The request was not handled by any route.</p>' +
        '<ul>' +
        // PathInfo/URL/ScriptName are attacker-controlled and were reflected
        // verbatim: a crafted request path executed as script in the browser.
        '<li><b>PathInfo:</b> ' + TNetEncoding.HTML.Encode(ARequest.PathInfo) + '</li>' +
        '<li><b>URL:</b> ' + TNetEncoding.HTML.Encode(ARequest.URL) + '</li>' +
        '<li><b>ScriptName:</b> ' + TNetEncoding.HTML.Encode(ARequest.ScriptName) + '</li>' +
        '<li><b>AppHomePath:</b> ' + TNetEncoding.HTML.Encode(TKConfig.AppHomePath) + '</li>' +
        '<li><b>SystemHomePath:</b> ' + TNetEncoding.HTML.Encode(TKConfig.SystemHomePath) + '</li>' +
        '<li><b>Config file:</b> ' + TNetEncoding.HTML.Encode(TKConfig.AppHomePath + 'Metadata\' + TKConfig.BaseConfigFileName) + '</li>' +
        '</ul>' +
        '<p>Check that Config.yaml exists and AppPath matches the web server application alias (IIS virtual directory or Apache Location).</p>' +
        '</body></html>';
      AResponse.SendResponse;
      Result := True;
    end;
  except
    on E: Exception do
    begin
      TEFLogger.Instance.Log('WebBroker HandleRequest error: ' + E.Message);
      AResponse.StatusCode := 500;
      AResponse.ContentType := 'text/html; charset=utf-8';
      AResponse.Content :=
        '<html><head><meta charset="utf-8"><title>KittoX Error</title></head><body>' +
        '<h1>500 &mdash; KittoX Internal Error</h1>' +
        // E.Message can carry reflected request data; encode it too.
        '<p><b>Error:</b> ' + TNetEncoding.HTML.Encode(E.Message) + '</p>' +
        '<ul>' +
        '<li><b>AppHomePath:</b> ' + TNetEncoding.HTML.Encode(TKConfig.AppHomePath) + '</li>' +
        '<li><b>SystemHomePath:</b> ' + TNetEncoding.HTML.Encode(TKConfig.SystemHomePath) + '</li>' +
        '</ul>' +
        '</body></html>';
      AResponse.SendResponse;
      Result := True;
    end;
  end;
end;

end.
