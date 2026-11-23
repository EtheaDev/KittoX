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
///  Request-pipeline engine for KittoX. TKWebEngine is the root route that
///  orchestrates the whole request lifecycle: it ensures/creates the per-user
///  session, sets up the thread-local request/response objects, dispatches to
///  its child routes, manages session cookies and cleanup, and fires the
///  session start/end events. Hosted by TKWebServer (Indy) or the WebBroker
///  bridge (ISAPI/Apache).
/// </summary>
unit Kitto.Web.Engine;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Classes,
  System.Generics.Collections,
  Web.HTTPApp,
  EF.ObserverIntf,
  EF.Tree,
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
    /// <summary>
    ///  Carries the session ID, not the session object, and deliberately so.
    ///  Both events are delivered through TThread.Queue, i.e. ASYNCHRONOUSLY on
    ///  the main thread — while OnSessionEnd is fired from inside RemoveSession /
    ///  CleanupExpiredSessions, one statement before the session is FREED. A
    ///  closure capturing the object therefore read freed memory by the time it
    ///  ran: a use-after-free that surfaced as access violations in the desktop
    ///  host, on the main thread, so neither the request pipeline nor the log
    ///  caught them. Its signature in the log was the line
    ///  "Session  terminating." with an EMPTY id — 115 of them in one session of
    ///  testing, next to others that happened to win the race and printed a real
    ///  id.
    /// </summary>
    TKWebEngineSessionProc = TProc<TKWebEngine, string>;
  private
    FCharset: string;
    FSessions: TKWebSessions;
    FSessionIDCookieName: string;
    FSessionCleanupThread: TKWebSessionCleanupThread;
    FActive: Boolean;
    FSessionCleanupInterval: Double;
    FAuthCarriesSessionId: Boolean;
    FJWTCookieName: string;
    FOnSessionStart: TKWebEngineSessionProc;
    FOnSessionEnd: TKWebEngineSessionProc;
    procedure EnsureSession(const AURL: TKWebURL);
    procedure ReleaseCurrentSession;
    procedure FinishRequest(const ARequest: TKWebRequest; const AResponse: TKWebResponse;
      const AURL: TKWebURL; const AIsFatalError: Boolean);
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
    /// <summary>Snapshot of the active sessions for diagnostics/monitoring. Returns
    /// copied values, never session objects: see TKWebSessionInfo for why.</summary>
    function GetSessionInfos: TArray<TKWebSessionInfo>;
    /// <summary>Renames one session, resolved by id under the sessions lock.</summary>
    function SetSessionDisplayName(const ASessionId, ADisplayName: string): Boolean;

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

/// <summary>
///  The session timeout a configuration asks for, in minutes.
///  <para><c>Engine/Session/TimeOut</c> is the node. <c>Server/SessionTimeOut</c>
///  is read when that one is missing: it is where the New Project wizard wrote
///  the value for years, into a node the engine never looked at, so every
///  project it generated has it there. Neither gives 10.</para>
/// </summary>
function ReadSessionTimeOutMinutes(const AConfig: TEFTree): Integer;

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
  EF.Logger,
  EF.Localization,
  Kitto.Auth,
  Kitto.Types,
  Kitto.Config,
  Kitto.Config.Auth,
  Kitto.Web.Routing.Registry,
  Kitto.Html.Response,
  Kitto.Web.Types;

function ReadSessionTimeOutMinutes(const AConfig: TEFTree): Integer;
begin
  Assert(Assigned(AConfig), 'AConfig');
  Result := AConfig.GetInteger('Engine/Session/TimeOut',
    AConfig.GetInteger('Server/SessionTimeOut', 10));
end;

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
    LSessionTimeOut := ReadSessionTimeOutMinutes(LConfig.Config) * OneMinute;
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
    // Fail here, and say what is wrong, if Auth names a class nobody registered
    // — a typo, or more often an authenticator unit missing from the project's
    // UseKitto.pas (only Auth: Null is registered by the core; DB, DBCrypt,
    // DBServer, TextFile, Ini, OSDB, LDAP and JWT each come from their own unit).
    //
    // Without this check the application starts and then serves a BLANK PAGE for
    // every request, with nothing in the log: the class is looked up again by
    // TKWebApplication.GetAuthenticator, from ActivateInstance, which runs
    // BEFORE the request filter chain is built — so the error-handler filter
    // never sees the exception and no dialog is ever rendered. Verified.
    if not Assigned(LAuthClass) then
    begin
{$IFDEF KITTOX_PREVIEW_MODE}
      // Preview (KIDEX): an app may declare a custom authenticator registered by
      // its own code (e.g. 'TasKitto'), which KIDEX does not link. Do NOT fail
      // here — TKWebApplication.GetAuthenticator applies the real fallback (DB,
      // else Null). This probe only needs a class to read FAuthCarriesSessionId
      // from below, and that is derived from the Auth/JWT node, not LAuthClass,
      // so simply logging and carrying on is enough. Compiled out in an app build.
      TEFLogger.Instance.Log(Format('[PREVIEW MODE] Auth "%s" is not registered ' +
        '(app-specific code not linked into KIDEX); the application will fall back ' +
        'to the standard authenticator.', [LAuthType]));
{$ELSE}
      // Logged as well as raised: on a Windows service, an ISAPI dll or an
      // Apache module nobody sees the dialog, and the log file is the only
      // place the operator can find out why the application will not start.
      TEFLogger.Instance.LogFmt('Auth: %s is not a registered authenticator. '+
        'Add the unit that registers it to UseKitto.pas. Registered: %s.',
        [LAuthType, String.Join(', ', TKAuthenticatorRegistry.Instance.GetClassIds)],
        TEFLogger.LOG_ALWAYS);
      raise EKError.CreateFmt(
        _('Auth: %s is not a registered authenticator. Check the spelling, and make sure the unit that registers it (e.g. Kitto.Auth.%s) is in your project''s UseKitto.pas. Registered: %s.'),
        [LAuthType, LAuthType,
         String.Join(', ', TKAuthenticatorRegistry.Instance.GetClassIds)]);
{$ENDIF}
    end;
    // Session-id-in-credential is a property of the JWT envelope: the credential
    // carries the 'sid' claim exactly when the auth config declares a JWT
    // sub-block (Auth/JWT), so no separate session-id cookie is emitted.
    FAuthCarriesSessionId := Assigned(LConfig.Config.FindNode('Auth/JWT'));
    // Same node, and the same default, the JWT engine itself reads when it
    // writes the cookie (TKJWTConfig): an application that renames it must
    // still find its session id here.
    FJWTCookieName := LConfig.Config.GetString('Auth/JWT/Cookie/Name', DEFAULT_JWT_COOKIE_NAME);
    // Expand the '{apibase}' placeholder in the REST routes with the configured
    // base path (Server/RestBasePath, default '/api/v4') now that the config is
    // loaded, before any request is served. No-op for non-REST routes / apps.
    TKXResourceRegistry.Instance.ResolveApiBase(LConfig.RestBasePath);
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
  LToken, LSidFromJWT, LAuth: string;
begin
  // Legacy session id cookie (used by Auth: DB / TextFile / Null and similar).
  Result := TKWebRequest.Current.GetCookie(FSessionIDCookieName);
  if Result <> '' then
    Exit;
  // JWT path: the token carries a signed 'sid' claim used as the session
  // correlator. The browser SPA sends it in the token cookie (kx_token unless
  // Auth/JWT/Cookie/Name says otherwise); a stateless
  // REST client sends it in the Authorization: Bearer header. Reading the sid
  // from the header too means repeated calls with the same token reuse ONE
  // server-side session (1 per token) instead of creating a fresh one per
  // request (which would leak sessions until timeout).
  LToken := TKWebRequest.Current.GetCookie(FJWTCookieName);
  if LToken = '' then
  begin
    LAuth := TKWebRequest.Current.GetHeaderField('Authorization');
    if LAuth.StartsWith('Bearer ', True) then
      LToken := Trim(LAuth.Substring(7));
  end;
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
  Assert(Assigned(ASession), 'Assigned(ASession)');

  // The session id cookie is written for EVERY authenticator, JWT included.
  // It used to be skipped when the credential carried the id itself (Auth/JWT),
  // on the grounds that a second cookie only shadowed kx_token in DevTools. But
  // it is the ONLY correlator a request can present in the two cases where the
  // token cookie is absent: before there is a token at all (the login page and
  // everything it loads) and outside the token cookie's path (the static
  // resources under /res, since the JWT cookie is scoped to the application
  // path). A request that presents no id gets a NEW session, so one login page
  // produced one anonymous session per file it loaded - dozens of them in the
  // log, all userless, until the real one appeared at login.
  //
  // This is not a relaxation of the r373 session rule: a request is still
  // matched to a session ONLY by an identifier it presents, never by its client
  // address. It just gives the client an identifier to present.
  //
  // HttpOnly and SameSite=Lax because for the authenticators that do NOT carry
  // the id in the credential this cookie IS the credential: script must not be
  // able to read it, and it must not travel on cross-site requests. Secure is
  // deliberately False - applications are routinely deployed over plain HTTP on
  // an intranet, and a Secure cookie would never come back from there. Path is
  // '/' so that the static resource routes, which live outside the application
  // path, are served inside the session that asked for them.
  //
  // No expiry of its own (NO_EXPIRY: a browser session cookie). The cookie used
  // to expire after Session.Timeout, refreshed at every response, "to keep it in
  // step with the server". That bought nothing - the server is the authority on
  // how long a session lives, and an id whose session is gone opens nothing -
  // and it cost the one thing the cookie is for after a timeout: at the end of
  // an idle period the browser dropped the cookie at the same moment the server
  // dropped the session, so the next click arrived without an id, got a fresh
  // anonymous session and an opaque 404 ("Resource not found") instead of the
  // "Session lost or expired" dialog, which can only be raised when the server
  // receives an id it no longer knows (EnsureSession). With no expiry the
  // browser keeps presenting the old id and the dialog comes up however long
  // the page was left open. Session lifetime is unchanged: Engine/Session/
  // TimeOut and the cleanup thread decide it, exactly as before.
  if ARemove then
    TKWebResponse.Current.SetSecureCookie(FSessionIDCookieName, ASession.SessionId,
      Now - 7, '/', True, False, 'Lax')
  else
    TKWebResponse.Current.SetSecureCookie(FSessionIDCookieName, ASession.SessionId,
      TKWebResponse.NO_EXPIRY, '/', True, False, 'Lax');
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
            // PathInfo is attacker-controlled and was reflected verbatim into
            // the page: a request path carrying markup executed as script in the
            // victim's browser. Encode it, as RenderMessageDialog already does.
            '<body>Unknown request: ' + TNetEncoding.HTML.Encode(ARequest.PathInfo) + '</body>' +
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
  LLanguage: string;
begin
  LSessionId := GetSessionIdFromRequest;
  LClientAddress := TKWebRequest.Current.RemoteAddr;

  Assert(LClientAddress <> '', 'LClientAddress <> ''''');

  // Atomically find or create è prevents duplicate sessions when multiple
  // requests arrive concurrently (e.g. page + resources after F5/restart).
  LSession := FSessions.FindOrCreateSession(LSessionId, LClientAddress, LCreated);

  if LCreated then
  begin
    // A non-empty session id that did not match a live session usually means the
    // session was lost (server restart / timeout). But when the credential is a
    // signed token that carries the session id (Auth: JWT), the token is
    // self-sufficient: AuthorizeRequest re-hydrates the session from its verified
    // claims (user, ACL, db, language), so a mismatch is NOT a lost session — the
    // token is the source of truth. Pure-stateless: a valid token keeps working
    // across a server restart or on a different cluster node, and never triggers
    // the "session lost, please restart" gate.
    if (LSessionId <> '') and not FAuthCarriesSessionId then
      LSession.IsSessionLost := True;
  end
  else if TKWebRequest.Current.IsPageRefresh(AURL.Document) then
  begin
    // Page refresh case - need to create a new session with the same
    // id (if available), so that other requests coming from the same client
    // before this one is served are linked to the correct session.
    // Preserve authentication state across session refresh so that
    // login redirects (KittoX) and manual F5 don't lose the auth.
    //
    // The old session is replaced, NOT freed here. It used to be - removed and
    // re-created in two steps - and any other request of the same session in
    // flight on another thread (a second tab, a reload while something is
    // loading) was left holding a pointer to freed memory: an access violation
    // on the session's gettext instance, on its auth data, on a string.
    // RenewSession swaps the two under the sessions lock and leaves the old
    // object alive until the last request on it has ended.
    LLanguage := LSession.Language;
    LSession := FSessions.RenewSession(LSession, LClientAddress);
    // Set Current before restoring language, so that ForceLanguage
    // (called by SetLanguage) targets the new session's gnugettext instance.
    TKWebSession.Current := LSession;
    LSession.Language := LLanguage;
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
var
  LSessionId: string;
begin
  // Clear the current session *in this thread*, as it's a threadvar...
  if ASession = TKWebSession.Current then
    TKWebSession.Current := nil;
  // Read everything the queued closure needs NOW, while the session is still
  // alive: this method runs one statement before the caller frees it, and the
  // closure below runs later, on the main thread. Capturing ASession instead of
  // this copy is a use-after-free — see TKWebEngineSessionProc.
  LSessionId := ASession.SessionId;
  // Log inline. TEFLogger is thread-safe, and a queued log line would be lost —
  // and its TThread.Queue record leaked — in every host without a main-thread
  // message loop: Console, ISAPI, Apache and the Windows service never pump
  // CheckSynchronize, so nothing runs or frees the queued closures, and they
  // accumulate one per session for the life of the process.
  TEFLogger.Instance.LogFmt('Session %s terminating.', [LSessionId], TEFLogger.LOG_MEDIUM);
  // The host callback must run on the main thread — only the VCL host sets one,
  // and only it pumps the queue — so queue just that, and only when set.
  if Assigned(FOnSessionEnd) then
    TThread.Queue(nil,
      procedure
      begin
        if Assigned(FOnSessionEnd) then
          FOnSessionEnd(Self, LSessionId);
      end);
end;

procedure TKWebEngine.DoSessionStart(ASession: TKWebSession);
var
  LSessionId: string;
begin
  // Same rule as DoSessionEnd: copy now, queue the copy. The session is alive
  // here, but the closure runs later and a short-lived session may already have
  // expired and been freed by then.
  LSessionId := ASession.SessionId;
  // Log inline; queue only the host callback, and only when set — see
  // DoSessionEnd for why (a queued closure never runs, and leaks, in a host
  // with no main-thread message loop).
  TEFLogger.Instance.LogFmt('New session %s.', [LSessionId], TEFLogger.LOG_MEDIUM);
  if Assigned(FOnSessionStart) then
    TThread.Queue(nil,
      procedure
      begin
        if Assigned(FOnSessionStart) then
          FOnSessionStart(Self, LSessionId);
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
  // Nothing of the previous request served by this pooled thread: if
  // EnsureSession fails before acquiring, there is no session to give back.
  TKWebSession.Current := nil;
  try
    EnsureSession(AURL);
    TKWebSession.Current.SetDefaultLanguage(TKWebRequest.Current.AcceptLanguage);
    TKWebSession.Current.LastRequestInfo.SetData(TKWebRequest.Current);

    TKWebResponse.Current.Items.Charset := FCharset;
    {$IFDEF MSWINDOWS}
    if EF.DB.IsCOMNeeded then
      OleCheck(CoInitialize(nil));
    {$ENDIF}
    inherited;
  except
    // AfterHandleRequest does not run when this method raises (see
    // TKWebRoute.HandleRequest), and it is the one that gives the session
    // back: an acquire left behind here would keep the session from ever
    // expiring.
    ReleaseCurrentSession;
    raise;
  end;
end;

procedure TKWebEngine.ReleaseCurrentSession;
var
  LSession: TKWebSession;
begin
  // Clear the pointer first: once released, nothing guarantees the object - a
  // page refresh, the cleanup thread or a removal may free it at any time.
  LSession := TKWebSession.Current;
  TKWebSession.Current := nil;
  FSessions.ReleaseSession(LSession);
end;

procedure TKWebEngine.AfterHandleRequest(const ARequest: TKWebRequest;
  const AResponse: TKWebResponse; const AURL: TKWebURL; const AIsFatalError: Boolean);
var
  LSession: TKWebSession;
begin
  // The session this request acquired in BeforeHandleRequest. Kept in a local
  // because removing it (below) clears the thread's Current - see DoSessionEnd -
  // and it still has to be given back.
  LSession := TKWebSession.Current;
  try
    FinishRequest(ARequest, AResponse, AURL, AIsFatalError);
  finally
    // Whatever happened above - a client gone before the response was sent, for
    // one - the request is over and no longer keeps the session alive.
    TKWebSession.Current := nil;
    FSessions.ReleaseSession(LSession);
  end;
end;

procedure TKWebEngine.FinishRequest(const ARequest: TKWebRequest;
  const AResponse: TKWebResponse; const AURL: TKWebURL; const AIsFatalError: Boolean);
begin
  inherited AfterHandleRequest(ARequest, AResponse, AURL, AIsFatalError);
  TEFLogger.Instance.LogDebug('AfterHandleRequest: ' + AURL.GetURI);
  if not FActive then
    Exit;
  {$IFDEF MSWINDOWS}
  if EF.DB.IsCOMNeeded then
    CoUninitialize;
  {$ENDIF}
  // Send back the session id to the client (a browser session cookie, with no
  // expiry of its own: see SetSessionIdIntoResponse); remove the cookie in
  // case of a fatal error.
  SetSessionIdIntoResponse(TKWebSession.Current, AIsFatalError);
  // Make sure cookies and custom headers are passed through.
  TKWebResponse.Current.Send;
  // It's only after rendering the response that we can kill the session in case
  // of fatal error.
  // The object outlives the removal until AfterHandleRequest gives it back.
  if AIsFatalError then
    FSessions.RemoveSession(TKWebSession.Current);
end;

function TKWebEngine.GetSessionInfos: TArray<TKWebSessionInfo>;
begin
  Result := FSessions.GetSessionInfos;
end;

function TKWebEngine.SetSessionDisplayName(const ASessionId,
  ADisplayName: string): Boolean;
begin
  Result := FSessions.SetSessionDisplayName(ASessionId, ADisplayName);
end;

end.

