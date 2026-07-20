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

unit Kitto.Web.Engine;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Classes,
  System.Generics.Collections,
  Web.HTTPApp,
  EF.ObserverIntf,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Web.Routes,
  Kitto.Web.Session,
  Kitto.Web.URL;

type
  /// <summary>
  ///  Kitto engine route. Handles sub-routes (such as the application route)
  ///  and manages a list of active sessions. Also keeps the current session
  ///  in TKWebSession updated. It is normally embedded in a TKWebServer but can
  ///  be used as-is (for example inside an ISAPI dll or Apache module).
  /// </summary>
  TKWebEngine = class(TKWebRouteList)
  private type
    TKWebEngineSessionProc = TProc<TKWebEngine, TKWebSession>;
  private
    FCharset: string;
    FSessions: TKWebSessions;
    FSessionIDCookieName: string;
    FSessionCleanupThread: TKWebSessionCleanupThread;
    FActive: Boolean;
    FSessionCleanupInterval: Double;
    FAuthCarriesSessionId: Boolean;
    FOnSessionStart: TKWebEngineSessionProc;
    FOnSessionEnd: TKWebEngineSessionProc;
    procedure EnsureSession(const AURL: TKWebURL);
    function GetSessionIdFromRequest: string;
    procedure SetSessionIdIntoResponse(const ASession: TKWebSession; const ARemove: Boolean);
    procedure SetActive(const Value: Boolean);
    procedure DoSessionStart(ASession: TKWebSession);
    procedure DoSessionEnd(ASession: TKWebSession);
  protected
    procedure BeforeHandleRequest(const ARequest: TKWebRequest; const AResponse: TKWebResponse;
      const AURL: TKWebURL; var AIsAllowed: Boolean); override;
    procedure AfterHandleRequest(const ARequest: TKWebRequest;
      const AResponse: TKWebResponse; const AURL: TKWebURL; const AIsFatalError: Boolean); override;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  public
    /// <summary>Activates/deactivates the engine (starts/stops the session cleanup thread).</summary>
    property Active: Boolean read FActive write SetActive;

    /// <summary>The response charset used by the engine (from Config, default utf-8).</summary>
    property Charset: string read FCharset;
    /// <summary>Returns a snapshot of the active sessions (for diagnostics/monitoring).</summary>
    function GetSessions: TArray<TKWebSession>;

    /// <summary>
    ///  Fired when a new session has started.
    /// </summary>
    /// <remarks>
    ///  This event is queued in the main thread's context (fired through TThread.Queue).
    /// </remarks>
    property OnSessionStart: TKWebEngineSessionProc read FOnSessionStart write FOnSessionStart;
    /// <summary>
    ///  Fired just before a session ends, either prematurely or when cleaned up due to
    ///  timeout.
    /// </summary>
    /// <remarks>
    ///  This event is called in the main thread's context (fired through TThread.Queue).
    /// </remarks>
    property OnSessionEnd: TKWebEngineSessionProc read FOnSessionEnd write FOnSessionEnd;

    /// <summary>
    ///  Manufactures all kitto objects (url, request and response) base on
    ///  the provided Webbroken request and response objects, and then calls
    ///  HandleRequest and optionally disposes of the passed objects. Useful
    ///  as a HandleRequest wrapper to be called from the Indy Kitto server
    ///  or the ISAPI/Apache implementation or elsewhere.
    /// <param AOwnsObjects>
    ///  True if ARequest and AResponse should be destroyed before returning.
    /// </param>
    /// </summary>
    function SimpleHandleRequest(const ARequest: TWebRequest; const AResponse: TWebResponse;
      const AURLDocument: string; const AOwnsObjects: Boolean = False; const AHandleAllRequests: Boolean = False): Boolean;
  end;

implementation

uses
  System.StrUtils,
  {$IFDEF MSWINDOWS}
  Winapi.ActiveX,
  System.Win.ComObj,
  {$ENDIF}
  System.IOUtils,
  System.JSON,
  System.NetEncoding,
  EF.DB,
  EF.Tree,
  EF.Logger,
  Kitto.Auth,
  Kitto.Config,
  Kitto.Html.Response,
  Kitto.Web.Types;

{ TKWebEngine }

procedure TKWebEngine.AfterConstruction;
var
  LConfig: TKConfig;
  LSessionTimeOut: Double;
  LAuthType: string;
  LAuthClass: TClass;
begin
  inherited;
  // Standard config objects are per application; we need to create our own
  // instance in order to read engine-wide params.
  LConfig := TKConfig.Create;
  try
    { TODO :  No multiple applications until we can have multiple cookie names. }
    FSessionIDCookieName := LConfig.AppName;
    FCharset := LConfig.Config.GetString('Charset', 'utf-8');
    LSessionTimeOut := LConfig.Config.GetInteger('Engine/Session/TimeOut', 10) * OneMinute;
    FSessionCleanupInterval := LConfig.Config.GetInteger('Engine/Session/CleanupInterval') * OneSecond;
    FSessions := TKWebSessions.Create(LSessionTimeOut);
    FSessions.OnSessionStart := DoSessionStart;
    FSessions.OnSessionEnd := DoSessionEnd;
    // Probe the registered authenticator class for whether its credential
    // already carries the session id (JWT does, plain DB / TextFile / Null
    // do not). We must cache the answer here because by the time
    // SetSessionIdIntoResponse runs from AfterHandleRequest, the per-thread
    // TKAuthenticator.Current has been cleared by DeactivateInstance.
    LAuthType := LConfig.Config.GetExpandedString('Auth', NODE_NULL_VALUE);
    LAuthClass := TKAuthenticatorRegistry.Instance.FindClass(LAuthType);
    FAuthCarriesSessionId := Assigned(LAuthClass)
      and TKAuthenticatorClass(LAuthClass).CarriesSessionIdInCredential;
  finally
    FreeAndNil(LConfig);
  end;
end;

destructor TKWebEngine.Destroy;
begin
  Active := False;
  FreeAndNil(FSessions);
  inherited;
end;

function TKWebEngine.GetSessionIdFromRequest: string;

  function TryDecodeSidFromTokenCookie(const ACompactToken: string;
    out ASid: string): Boolean;
  // Decodes the payload portion of a compact JWT WITHOUT verifying the
  // signature, only to extract the 'sid' custom claim used for binding the
  // request to its server-side TKWebSession. Verification of the signature
  // happens later in TKAuthenticator.AuthorizeRequest before any data is
  // served, so the unsafe decode here grants no privilege. Implemented
  // inline so this engine unit does not depend on Kitto.Web.JWT (and on
  // the JOSE third-party library) — apps that don't use Auth: JWT can
  // build the framework without having JOSE on their search path.
  var
    LParts: TArray<string>;
    LSafe: string;
    LPad: Integer;
    LPayloadBytes: TBytes;
    LJson: TJSONObject;
    LValue: TJSONValue;
  begin
    Result := False;
    ASid := '';
    if Trim(ACompactToken) = '' then
      Exit;
    LParts := ACompactToken.Split(['.']);
    if Length(LParts) < 2 then
      Exit;
    LSafe := StringReplace(LParts[1], '-', '+', [rfReplaceAll]);
    LSafe := StringReplace(LSafe, '_', '/', [rfReplaceAll]);
    LPad := Length(LSafe) mod 4;
    if LPad > 0 then
      LSafe := LSafe + StringOfChar('=', 4 - LPad);
    try
      LPayloadBytes := TNetEncoding.Base64.DecodeStringToBytes(LSafe);
      LJson := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(LPayloadBytes)) as TJSONObject;
      if not Assigned(LJson) then
        Exit;
      try
        LValue := LJson.GetValue('sid');
        if Assigned(LValue) then
        begin
          ASid := LValue.Value;
          Result := ASid <> '';
        end;
      finally
        LJson.Free;
      end;
    except
      Result := False;
    end;
  end;

var
  LToken, LSidFromJWT: string;
begin
  // Legacy session id cookie (used by Auth: DB / TextFile / Null and similar).
  Result := TKWebRequest.Current.GetCookie(FSessionIDCookieName);
  if Result <> '' then
    Exit;
  // JWT path: the kx_token cookie carries a signed token whose 'sid' claim
  // is the session correlator.
  LToken := TKWebRequest.Current.GetCookie('kx_token');
  if (LToken <> '') and TryDecodeSidFromTokenCookie(LToken, LSidFromJWT) then
    Result := LSidFromJWT;
end;

procedure TKWebEngine.SetActive(const Value: Boolean);
begin
  if FActive <> Value then
  begin
    FActive := Value;
    if FActive then
      FSessionCleanupThread := TKWebSessionCleanupThread.Create(FSessions, FSessionCleanupInterval)
    else
    begin
      if Assigned(FSessionCleanupThread) then
      begin
        FSessionCleanupThread.Terminate;
        FSessionCleanupThread.WaitFor;
        FreeAndNil(FSessionCleanupThread);
      end;
      FSessions.ClearSessions;
    end;
  end;
end;

procedure TKWebEngine.SetSessionIdIntoResponse(const ASession: TKWebSession; const ARemove: Boolean);
begin
  Assert(Assigned(ASession));

  // When the configured authenticator's credential already carries the session
  // id (e.g. JWT 'sid' claim) the legacy session id cookie named after
  // AppName would just shadow kx_token in DevTools. Skip writing it on normal
  // requests so the response stays minimal. We still emit an expired cookie
  // on session end to clear any stale legacy cookie left over from older
  // framework builds.
  if FAuthCarriesSessionId and (not ARemove) then
    Exit;

  if ARemove then
    TKWebResponse.Current.SetCookie(FSessionIDCookieName, ASession.SessionId, Now - 7)
  else
    TKWebResponse.Current.SetCookie(FSessionIDCookieName, ASession.SessionId, Now + ASession.Timeout);
end;

function TKWebEngine.SimpleHandleRequest(const ARequest: TWebRequest; const AResponse: TWebResponse;
  const AURLDocument: string; const AOwnsObjects: Boolean = False; const AHandleAllRequests: Boolean = False): Boolean;
var
  LURL: TKWebURL;
begin
  TEFLogger.Instance.Log('SimpleHandleRequest: URLDocument="' + AURLDocument + '"', TEFLogger.LOG_DEBUG);
  LURL := TKWebURL.Create(AURLDocument);
  try
    TEFLogger.Instance.Log('SimpleHandleRequest: URL.Path="' + LURL.Path +
      '" URL.Document="' + LURL.Document + '" URL.Host="' + LURL.Host + '"', TEFLogger.LOG_DEBUG);
    TKWebRequest.Current := TKWebRequest.Create(ARequest, AOwnsObjects);
    try
      TKWebResponse.Current := TKWebResponse.Create(AResponse, AOwnsObjects);
      try
        Result := HandleRequest(TKWebRequest.Current, TKWebResponse.Current, LURL);
        TEFLogger.Instance.Log('SimpleHandleRequest: HandleRequest returned ' +
          BoolToStr(Result, True), TEFLogger.LOG_DEBUG);

        if not Result and AHandleAllRequests then
        begin
          { TODO : Fetch the appname and other data from config to display meaningful error }
          AResponse.ContentType := 'text/html';
          AResponse.Content :=
            '<html>' +
            '<head><title>Web Server Application</title></head>' +
            '<body>Unknown request: ' + ARequest.PathInfo + '</body>' +
            '</html>';
          AResponse.StatusCode := 404;
          AResponse.HTTPRequest.URL.Empty;
          AResponse.SendResponse;
        end;
      finally
        TKXWebResponse.ClearCurrent;
        TKWebResponse.ClearCurrent;
        TKConfig.ClearDatabase;
      end;
    finally
      TKWebRequest.ClearCurrent;
    end;
  finally
    FreeAndNil(LURL);
  end;
end;

procedure TKWebEngine.EnsureSession(const AURL: TKWebURL);
var
  LSessionId: string;
  LSession: TKWebSession;
  LClientAddress: string;
  LCreated: Boolean;
  LWasAuthenticated: Boolean;
  LAuthDataCopy: TEFNode;
  LRefreshingLanguage: Boolean;
  LLanguage: string;
  LDatabaseName: string;
begin
  LSessionId := GetSessionIdFromRequest;
  LClientAddress := TKWebRequest.Current.RemoteAddr;

  Assert(LClientAddress <> '');

  // Atomically find or create è prevents duplicate sessions when multiple
  // requests arrive concurrently (e.g. page + resources after F5/restart).
  LSession := FSessions.FindOrCreateSession(LSessionId, LClientAddress, LCreated);

  if LCreated then
  begin
    if LSessionId <> '' then
      LSession.IsSessionLost := True;
  end
  else if TKWebRequest.Current.IsPageRefresh(AURL.Document) then
  begin
    // Page refresh case - need to create a new session with the same
    // id (if available), so that other requests coming from the same client
    // before this one is served are linked to the correct session.
    // Preserve authentication state across session refresh so that
    // login redirects (KittoX) and manual F5 don't lose the auth.
    LWasAuthenticated := LSession.IsAuthenticated;
    LRefreshingLanguage := LSession.RefreshingLanguage;
    LLanguage := LSession.Language;
    LDatabaseName := LSession.DatabaseName;
    LAuthDataCopy := TEFNode.Create;
    try
      LAuthDataCopy.Assign(LSession.AuthData);
      FSessions.RemoveSession(LSession);
      LSession := FSessions.NewSession(LClientAddress, LSessionId);
      // Set Current before restoring language, so that ForceLanguage
      // (called by SetLanguage) targets the new session's gnugettext instance.
      TKWebSession.Current := LSession;
      // Transfer auth state to the new session.
      if LWasAuthenticated then
      begin
        LSession.IsAuthenticated := True;
        LSession.AuthData.Assign(LAuthDataCopy);
      end;
      LSession.RefreshingLanguage := LRefreshingLanguage;
      LSession.Language := LLanguage;
      LSession.DatabaseName := LDatabaseName;
    finally
      LAuthDataCopy.Free;
    end;
  end;

  TKWebSession.Current := LSession;

  // Restore the chosen database environment from the kx_db cookie if the
  // session does not have one yet. The cookie is set at login time and
  // survives 30 days, so the user lands on the same environment as last time.
  // Skipped when the active authenticator carries its own session-bound state
  // (Auth: JWT hydrates DatabaseName from the verified 'db' claim during
  // AuthorizeRequest, and we don't want a stale kx_db cookie to override
  // the credential's authoritative value).
  if (LSession.DatabaseName = '') and not FAuthCarriesSessionId then
    LSession.DatabaseName := TKWebRequest.Current.GetCookie('kx_db');
end;

procedure TKWebEngine.DoSessionEnd(ASession: TKWebSession);
begin
  // Clear the current session *in this thread*, as it's a threadvar...
  if ASession = TKWebSession.Current then
    TKWebSession.Current := nil;
  // ...then queue the rest in the main thread.
  TThread.Queue(nil,
    procedure
    begin
      TEFLogger.Instance.LogFmt('Session %s terminating.', [ASession.SessionId], TEFLogger.LOG_MEDIUM);
      if Assigned(FOnSessionEnd) then
        FOnSessionEnd(Self, ASession);
    end);
end;

procedure TKWebEngine.DoSessionStart(ASession: TKWebSession);
begin
  TThread.Queue(nil,
    procedure
    begin
      TEFLogger.Instance.LogFmt('New session %s.', [ASession.SessionId], TEFLogger.LOG_MEDIUM);
      if Assigned(FOnSessionStart) then
        FOnSessionStart(Self, ASession);
    end);
end;

procedure TKWebEngine.BeforeHandleRequest(const ARequest: TKWebRequest;
  const AResponse: TKWebResponse; const AURL: TKWebURL; var AIsAllowed: Boolean);
begin
  TEFLogger.Instance.LogDebug('BeforeHandleRequest: ' + AURL.GetURI);
  if not FActive then
  begin
    AIsAllowed := False;
    Exit;
  end;
  EnsureSession(AURL);
  TKWebSession.Current.SetDefaultLanguage(TKWebRequest.Current.AcceptLanguage);
  TKWebSession.Current.LastRequestInfo.SetData(TKWebRequest.Current);

  TKWebResponse.Current.Items.Charset := FCharset;
  {$IFDEF MSWINDOWS}
  if EF.DB.IsCOMNeeded then
    OleCheck(CoInitialize(nil));
  {$ENDIF}
  inherited;
end;

procedure TKWebEngine.AfterHandleRequest(const ARequest: TKWebRequest;
  const AResponse: TKWebResponse; const AURL: TKWebURL; const AIsFatalError: Boolean);
begin
  inherited;
  TEFLogger.Instance.LogDebug('AfterHandleRequest: ' + AURL.GetURI);
  if not FActive then
    Exit;
  {$IFDEF MSWINDOWS}
  if EF.DB.IsCOMNeeded then
    CoUninitialize;
  {$ENDIF}
  // Send back the session id to the client and update the expiration time.
  // remove the cookie in case of a fatal error.
  SetSessionIdIntoResponse(TKWebSession.Current, AIsFatalError);
  // Make sure cookies and custom headers are passed through.
  TKWebResponse.Current.Send;
  // It's only after rendering the response that we can kill the session in case
  // of fatal error.
  if AIsFatalError then
    FSessions.RemoveSession(TKWebSession.Current);
end;

function TKWebEngine.GetSessions: TArray<TKWebSession>;
begin
  Result := FSessions.GetSessions;
end;

end.

