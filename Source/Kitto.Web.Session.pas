{ -------------------------------------------------------------------------------
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
  ------------------------------------------------------------------------------- }

{ -------------------------------------------------------------------------------
  Loosely based on code from ExtPascal
  Author: Wanderlan Santos dos Anjos. wanderlan.anjos@gmail.com
  Home: http://extpascal.googlecode.com
  License: BSD, http://www.opensource.org/licenses/bsd-license.php
  ------------------------------------------------------------------------------- }

/// <summary>
///  Server-side user session support for KittoX. Defines TKWebSession (the
///  per-user session object, kept thread-local via a threadvar), TKWebSessions
///  (the thread-safe session list with find/create/cleanup), the periodic
///  cleanup thread, and a per-session gnugettext-based localization tool.
/// </summary>
unit Kitto.Web.Session;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Classes,
  System.Generics.Collections,
  Kitto.gnugettext,
  EF.Intf,
  EF.Tree,
  EF.Localization,
  EF.ObserverIntf,
  Kitto.Html.Base,
  Kitto.Config,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView,
  Kitto.Web.Request;

type
  /// <summary>
  ///  Represents the server side of a user client session.
  ///  Holds all objects and data pertaining to the user session.
  /// </summary>
  TKWebSession = class(TEFSubjectAndObserver)
  private
    FSessionId: string;
    FLanguage: string;
    FDatabaseName: string;
    FReloadingHome: Boolean;
    FViewportWidthInInches: Integer;
    FAutoOpenViewName: string;
    FAuthData: TEFNode;
    FIsAuthenticated: Boolean;
    FOpenControllers: TList<IKXController>;
    FHomeController: IKXController;
    FLoginController: IKXController;
    FControllerContainer: IKXContainer;
    FHomeViewNodeName: string;
    FViewportContent: string;
    FViewportWidth: Integer;
    FGettextInstance: TGnuGettextInstance;
    FDisplayName: string;
    FIsSessionLost: Boolean;
    FScreenWidth: Integer;
    FScreenHeight: Integer;
    FIsMobileBrowser: Boolean;
    FLastRequestInfo: TKWebRequestInfo;
    FCreationDateTime: TDateTime;
    FTimeout: Double;
    FStores: TObjectDictionary<string, TKViewTableStore>;
    // Requests currently being served on this object, and whether it has left
    // the session list. Both belong to TKWebSessions and are read and written
    // only under its lock: see TKWebSessions.ReleaseSession.
    FRequestCount: Integer;
    FIsRetired: Boolean;
    class threadvar FCurrent: TKWebSession;
    function GetDisplayName: string;
    procedure SetLanguage(const AValue: string);
    class function GetCurrent: TKWebSession; static;
    class procedure SetCurrent(const Value: TKWebSession); static;
  strict protected
    function GetViewportContent: string; virtual;
    function GetManifestFileName: string; virtual;
  public
    /// <summary>Sets the session language from the request query, else from config.</summary>
    procedure SetLanguageFromQueriesOrConfig(const AConfig: TKConfig);
    /// <summary>True when the next request to the application root is a reload
    /// the application itself has just asked for — the redirect that follows a
    /// login, a language change, or an operation that sends the user back to
    /// the home page. Reaching the root normally logs the user out, on purpose:
    /// this flag tells it apart from a fresh page load by the browser. Home
    /// clears it once it has served the page.</summary>
    property ReloadingHome: Boolean read FReloadingHome write FReloadingHome;

    /// <summary>The default viewport width (in inches-derived pixels) for mobile layout.</summary>
    function GetDefaultViewportWidth: Integer;
  public
    /// <summary>Creates a session for the given client address, id and timeout (minutes).</summary>
    constructor Create(const AClientAddress, ASessionId: string; const ATimeout: Double);
    procedure AfterConstruction; override;
    destructor Destroy; override;

    /// <summary>When the session was created (used for timeout/expiry).</summary>
    property CreationDateTime: TDateTime read FCreationDateTime;
    /// <summary>
    ///  The current session's UUID.
    /// </summary>
    property SessionId: string read FSessionId;
    /// <summary>The session timeout in minutes.</summary>
    property Timeout: Double read FTimeout;
    /// <summary>The active language id; setting it re-applies localization.</summary>
    property Language: string read FLanguage write SetLanguage;

    /// <summary>
    ///  Name of the database connection currently active for this session.
    ///  When empty, the application falls back to Config.DefaultDatabaseName.
    ///  Set at login time when the user picks an "environment" via the
    ///  Auth/DatabaseChoices combo. Persisted across sessions: under
    ///  Auth: JWT via the 'db' claim in kx_token (re-hydrated by
    ///  AuthorizeRequest at every request); under non-JWT auth via the
    ///  legacy kx_db cookie (30-day lifetime).
    /// </summary>
    property DatabaseName: string read FDatabaseName write FDatabaseName;

    /// <summary>
    ///  Gives access to a copy of the auth data that was last passed
    ///  to Authenticate (and possibly modified by the object during
    ///  authentication).
    /// </summary>
    property AuthData: TEFNode read FAuthData;
    /// <summary>
    ///  Brackets a wholesale rewrite of AuthData (clear, assign) and the copy a
    ///  page refresh takes of it. Two requests of the same session run on two
    ///  threads: without this, the refresh of one copied the tree while the
    ///  logout of the other was freeing its nodes. It does NOT make every read
    ///  of AuthData safe against a concurrent rewrite - it makes the rewrites
    ///  and the copy atomic with respect to each other.
    /// </summary>
    procedure LockAuthData;
    /// <summary>Ends the section opened by LockAuthData.</summary>
    procedure UnlockAuthData;
    /// <summary>
    ///  Returns True if authentication has successfully taken
    ///  place.
    /// </summary>
    property IsAuthenticated: Boolean read FIsAuthenticated write FIsAuthenticated;

    /// <summary>
    ///  A reference to the main container of controllers.
    /// </summary>
    property ControllerContainer: IKXContainer read FControllerContainer write FControllerContainer;
    /// <summary>The controllers currently open in this session.</summary>
    property OpenControllers: TList<IKXController> read FOpenControllers;
    /// <summary>The home (main) controller instance.</summary>
    property HomeController: IKXController read FHomeController write FHomeController;
    /// <summary>The login controller instance.</summary>
    property LoginController: IKXController read FLoginController write FLoginController;
    /// <summary>Viewport width in inches (mobile scaling hint).</summary>
    property ViewportWidthInInches: Integer read FViewportWidthInInches write FViewportWidthInInches;
    /// <summary>Name of a view to open automatically after login, if any.</summary>
    property AutoOpenViewName: string read FAutoOpenViewName write FAutoOpenViewName;
    /// <summary>Node name of the home view for this session.</summary>
    property HomeViewNodeName: string read FHomeViewNodeName write FHomeViewNodeName;
    /// <summary>The HTML meta viewport content emitted in the page.</summary>
    property ViewportContent: string read FViewportContent write FViewportContent;
    /// <summary>
    ///  Viewport width in mobile applications.
    /// </summary>
    property ViewportWidth: Integer read FViewportWidth write FViewportWidth;

    /// <summary>
    ///  Screen width in CSS pixels, detected from kx_sw cookie or UA heuristic.
    /// </summary>
    property ScreenWidth: Integer read FScreenWidth write FScreenWidth;
    /// <summary>
    ///  Screen height in CSS pixels, detected from kx_sw cookie or UA heuristic.
    /// </summary>
    property ScreenHeight: Integer read FScreenHeight write FScreenHeight;
    /// <summary>
    ///  True if the client is a mobile browser (phone or tablet).
    /// </summary>
    property IsMobileBrowser: Boolean read FIsMobileBrowser write FIsMobileBrowser;

    /// <summary>
    ///  If the specified object is found in the list of open controllers,
    ///  it is removed from the list. Otherwise nothing happens.
    ///  Used by view hosts to notify the session that a controller was closed.
    /// </summary>
    procedure RemoveController(const AController: IKXController);

    /// <summary>
    ///  Replaces the session ID with a freshly generated one and clears
    ///  the IsSessionLost flag. The session object itself is preserved
    ///  (state already gathered for this request — Language, DatabaseName,
    ///  client address — survives), only its identity changes. The new ID
    ///  is sent back as a cookie at AfterHandleRequest time.
    ///  Called by the login handler before authenticating, both for
    ///  session-fixation hardening and to recover from stale cookies
    ///  pointing to an expired/lost server-side session.
    /// </summary>
    procedure RegenerateId;
    /// <summary>Display name for the session (falls back to SessionId when unset).</summary>
    property DisplayName: string read GetDisplayName write FDisplayName;

    /// <summary>Snapshot of the last request's data (user agent, client address, time),
    /// kept alive after the request object itself is destroyed.</summary>
    property LastRequestInfo: TKWebRequestInfo read FLastRequestInfo;
    /// <summary>
    ///  True if this session was created to replace a lost session
    ///  (client had a cookie but the server no longer knows the session,
    ///  e.g. after a server restart).
    /// </summary>
    property IsSessionLost: Boolean read FIsSessionLost write FIsSessionLost;
    /// <summary>Sets the default language without triggering a full language refresh.</summary>
    procedure SetDefaultLanguage(const AValue: string);

    /// <summary>
    ///  True if the session has expired, based on the value of Timeout and
    ///  the current time.
    /// </summary>
    function HasExpired: Boolean;

    /// <summary>
    ///  Registers a store for a view name. The session becomes owner of the store
    ///  (it will be freed when unregistered or when the session is destroyed).
    ///  If a store was already registered for this view, it is freed and replaced.
    /// </summary>
    procedure RegisterStore(const AViewName: string; AStore: TKViewTableStore);

    /// <summary>
    ///  Returns the store registered for the given view name, or nil if none.
    /// </summary>
    function FindStore(const AViewName: string): TKViewTableStore;

    /// <summary>
    ///  Removes and frees the store registered for the given view name.
    ///  Does nothing if no store is registered for that name.
    /// </summary>
    procedure UnregisterStore(const AViewName: string);

    /// <summary>
    ///  Globally accessible reference to the current thread's active session.
    /// </summary>
    class property Current: TKWebSession read GetCurrent write SetCurrent;
  end;

  /// <summary>
  ///  This class serves two purposes: redirects localization calls to a
  ///  per-session instance of dxgettext so we can have per-session language
  ///  selection, and configures Kitto's localization scheme based on two text
  ///  domains (the application's default.mo and Kitto's own Kitto.mo). The
  ///  former is located under the application home directory, the latter
  ///  under the system home directory.
  /// </summary>
  TKWebSessionLocalizationTool = class(TEFNoRefCountObject, IInterface, IEFInterface, IEFLocalizationTool)
  private const
    KITTO_TEXT_DOMAIN = 'Kitto';
  private
    function GetGnuGettextInstance: TGnuGettextInstance;
  public
    /// <summary>Returns Self as a TObject (IEFInterface support).</summary>
    function AsObject: TObject;
    /// <summary>Translates AString via the Kitto text domain, falling back to the app domain.</summary>
    function TranslateString(const AString: string;
      const AIdString: string = ''): string;
    /// <summary>Translates the captions of AComponent using both text domains.</summary>
    procedure TranslateComponent(const AComponent: TComponent);
    /// <summary>Switches the current (per-session) instance to the given language id.</summary>
    procedure ForceLanguage(const ALanguageId: string);
    /// <summary>Returns the language id currently active on the per-session instance.</summary>
    function GetCurrentLanguageId: string;
    procedure AfterConstruction; override;
  end;

  /// <summary>
  ///  Thread-safe list of active TKWebSession objects. Owns the sessions it
  ///  holds and provides atomic find/create, lookup by id or client address,
  ///  removal and expiry-based cleanup. Fires OnSessionStart/OnSessionEnd.
  /// </summary>
  /// <summary>
  ///  Read-only snapshot of one session, for monitoring. Exists so that a
  ///  caller outside the sessions lock never holds a TKWebSession POINTER:
  ///  the cleanup thread frees expired sessions, so a pointer handed out and
  ///  read later is a dangling one. That produced access violations in the
  ///  desktop host's session monitor — on the GUI thread, so neither the
  ///  request pipeline nor the log ever saw them, they surfaced as Windows
  ///  exception dialogs. Values are copied under the lock; the id lets a
  ///  caller ask for an action on that session, again under the lock.
  /// </summary>
  TKWebSessionInfo = record
    Id: string;
    DisplayName: string;
    CreationDateTime: TDateTime;
    LastRequestDateTime: TDateTime;
    UserName: string;
    ClientAddress: string;
    UserAgent: string;
  end;

  TKWebSessions = class
  private type
    TKWebSessionProc = TProc<TKWebSession>;
  private
    FSessions: TObjectList<TKWebSession>;
    // Sessions that have left FSessions while a request was still being served
    // on them. They are freed by ReleaseSession, when the last request ends.
    FRetiredSessions: TObjectList<TKWebSession>;
    FTimeout: Double;
    FOnSessionEnd: TKWebSessionProc;
    FOnSessionStart: TKWebSessionProc;
    function CreateNewSessionId: string;
    function FindSessionById(const ASessionId: string): TKWebSession;
    procedure RetireOrFree(const ASession: TKWebSession);
  protected
    procedure SessionAdded(const ASession: TKWebSession);
    procedure SessionRemoved(const ASession: TKWebSession);
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  public
    /// <summary>Creates the session list with the given per-session timeout (minutes).</summary>
    constructor Create(const ATimeout: Double);

    /// <summary>
    ///  Creates a new sessions and adds it to the list.
    /// </summary>
    function NewSession(const AClientAddress: string; const ASessionId: string = ''): TKWebSession;

    /// <summary>
    ///  Atomically finds or creates a session. A request is matched to an
    ///  existing session ONLY by the session id it presents: if ASessionId
    ///  matches a live session that session is returned, otherwise a NEW session
    ///  is created — never one belonging to another client. AClientAddress is
    ///  recorded on the new session, it is not a matching key. ACreated is set to
    ///  True when a new session was created.
    ///  The session is returned ACQUIRED: it counts one more request being
    ///  served on it, and will not be freed - by a page refresh, by the cleanup
    ///  thread, by anybody - until the caller gives it back with
    ///  ReleaseSession. Every call must be paired with one.
    /// </summary>
    function FindOrCreateSession(const ASessionId, AClientAddress: string;
      out ACreated: Boolean): TKWebSession;

    /// <summary>
    ///  Page refresh: replaces ASession, which the caller has acquired, with a
    ///  new session carrying the same id, and returns the new one, acquired in
    ///  its place. The authentication state, the database and the
    ///  application-issued reload flag are carried over; everything else (open
    ///  stores above all) starts empty, which is what a page load means.
    ///  The old object is NOT freed here: other requests of the same session
    ///  may be in flight on other threads, holding a pointer to it. It leaves
    ///  the list at once, so no new request finds it, and is freed when the
    ///  last request being served on it ends.
    ///  The language is left to the caller, because setting it goes through
    ///  the current thread's session.
    /// </summary>
    function RenewSession(const ASession: TKWebSession;
      const AClientAddress: string): TKWebSession;

    /// <summary>
    ///  Gives back a session acquired by FindOrCreateSession or RenewSession.
    ///  If the session has left the list in the meantime and this was the last
    ///  request on it, it is freed here.
    /// </summary>
    procedure ReleaseSession(const ASession: TKWebSession);

    /// <summary>
    ///  Returns all sessions as an array for reporting and diagnostic purposes.
    /// </summary>
    /// <summary>Snapshot of every live session, built under the lock. Use this
    /// instead of handing out session objects — see TKWebSessionInfo.</summary>
    function GetSessionInfos: TArray<TKWebSessionInfo>;
    /// <summary>Renames the session with the given id, under the lock. Returns
    /// False when that session no longer exists.</summary>
    function SetSessionDisplayName(const ASessionId, ADisplayName: string): Boolean;

    /// <summary>
    ///  How many sessions have left the list and are waiting for their last
    ///  request to end before being freed. Zero when the server is idle: a
    ///  number that stays above zero then means a request acquired a session
    ///  and never gave it back.
    /// </summary>
    function GetRetiredSessionCount: Integer;

    /// <summary>
    ///  Removes the specified session from the list, so that no new request
    ///  finds it, and frees it - at once if no request is being served on it,
    ///  otherwise when the last one ends (ReleaseSession).
    /// </summary>
    procedure RemoveSession(const ASession: TKWebSession);

    /// <summary>Removes and frees all sessions.</summary>
    procedure ClearSessions;

    /// <summary>Removes and frees the sessions that have expired (per their
    /// timeout). A session with a request in flight is never expired: it is
    /// in use by definition, whatever its last recorded activity says.</summary>
    procedure CleanupExpiredSessions;

    /// <summary>Fired when a new session is created.</summary>
    property OnSessionStart: TKWebSessionProc read FOnSessionStart write FOnSessionStart;
    /// <summary>Fired when a session is removed/ended.</summary>
    property OnSessionEnd: TKWebSessionProc read FOnSessionEnd write FOnSessionEnd;
  end;

  /// <summary>
  ///  Periodically cleans up the list of active sessions by disposing of
  ///  the stale ones.
  /// </summary>
  TKWebSessionCleanupThread = class(TThread)
  private
    FSessions: TKWebSessions;
    FInterval: Double;
    procedure WaitInterval;
  protected
    procedure Execute; override;
  public
    const DEFAULT_INTERVAL = 30 * OneSecond;
    /// <summary>Creates the cleanup thread for the given session list, waking every AInterval.</summary>
    constructor Create(const ASessions: TKWebSessions; const AInterval: Double);
  end;

implementation

uses
  EF.StrUtils,
  EF.Logger,
  Kitto.Web.Response,
  Kitto.Web.Application;

{ TKWebSession }

function TKWebSession.GetViewportContent: string;
begin
  Result := '';
end;

function TKWebSession.HasExpired: Boolean;
var
  LLastActivity: TDateTime;
begin
  // Until the first request refreshes it (LastRequestInfo.SetData in the
  // engine's BeforeHandleRequest), FLastRequestInfo.DateTime is 0 — so a
  // brand-new session read as expired the instant it was created, before the
  // request that created it had even been served. The cleanup thread, which
  // runs concurrently and frees whatever HasExpired reports, could therefore
  // free the session while the request thread that just got it back from
  // FindOrCreateSession was still using it: a use-after-free, easy to hit under
  // the churn of cookie-less requests behind a reverse proxy. Count from the
  // creation time (set in AfterConstruction, before the session is ever added
  // to the list) until the first request records a later activity time.
  LLastActivity := FLastRequestInfo.DateTime;
  if FCreationDateTime > LLastActivity then
    LLastActivity := FCreationDateTime;
  Result := Now > LLastActivity + FTimeout;
end;

constructor TKWebSession.Create(const AClientAddress, ASessionId: string; const ATimeout: Double);
begin
  Assert(ASessionId <> '', 'ASessionId <> ''''');
  Assert(AClientAddress <> '', 'AClientAddress <> ''''');

  inherited Create;
  FSessionId := ASessionId;
  FLastRequestInfo.ClearData;
  FLastRequestInfo.ClientAddress := AClientAddress;
  FTimeout := ATimeout;
  FStores := TObjectDictionary<string, TKViewTableStore>.Create([doOwnsValues]);
end;

destructor TKWebSession.Destroy;
begin
  FreeAndNil(FStores);
  NilEFIntf(FHomeController);
  NilEFIntf(FLoginController);
  NilEFIntf(FControllerContainer);

  FreeAndNil(FOpenControllers);
  FreeAndNil(FAuthData);
  FreeAndNil(FGettextInstance);
  inherited;
end;

procedure TKWebSession.LockAuthData;
begin
  // The monitor of the session itself: nothing else uses it.
  TMonitor.Enter(Self);
end;

procedure TKWebSession.UnlockAuthData;
begin
  TMonitor.Exit(Self);
end;

procedure TKWebSession.RegisterStore(const AViewName: string; AStore: TKViewTableStore);
begin
  // If a store was already registered for this view, it is freed and replaced
  // (TObjectDictionary with doOwnsValues frees the old value on AddOrSetValue).
  // Requests of the same session run in parallel - a page asks for several
  // views at once - and a dictionary does not survive two threads adding to
  // it. The lock guards the dictionary, not what is done with a store once
  // found.
  TMonitor.Enter(FStores);
  try
    FStores.AddOrSetValue(AViewName, AStore);
  finally
    TMonitor.Exit(FStores);
  end;
end;

function TKWebSession.FindStore(const AViewName: string): TKViewTableStore;
begin
  TMonitor.Enter(FStores);
  try
    if not FStores.TryGetValue(AViewName, Result) then
      Result := nil;
  finally
    TMonitor.Exit(FStores);
  end;
end;

procedure TKWebSession.UnregisterStore(const AViewName: string);
begin
  // TObjectDictionary frees the store object on Remove.
  TMonitor.Enter(FStores);
  try
    FStores.Remove(AViewName);
  finally
    TMonitor.Exit(FStores);
  end;
end;

class procedure TKWebSession.SetCurrent(const Value: TKWebSession);
begin
  FCurrent := Value;
end;

procedure TKWebSession.SetDefaultLanguage(const AValue: string);
var
  LTag: string;
  P: Integer;
begin
  if Language <> '' then
    Exit;
  // AValue is a raw Accept-Language header, e.g.
  //   "it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7"  or  "it,en-US;q=0.7,en;q=0.3".
  // Parse the FIRST (highest priority) tag only. The previous implementation
  // scanned for the first '-' in the WHOLE header, so for a header whose first
  // tag has no region (e.g. "it,en-US;...") it grabbed the "-US" of a LATER tag
  // and silently selected the wrong language (English) despite Italian being
  // preferred.
  LTag := Trim(AValue);
  P := Pos(',', LTag);
  if P > 0 then
    LTag := Copy(LTag, 1, P - 1);
  P := Pos(';', LTag);              // drop the ";q=..." quality value
  if P > 0 then
    LTag := Copy(LTag, 1, P - 1);
  LTag := Trim(LTag).Replace('_', '-');
  if LTag = '' then
    Exit;
  // Split base language and optional region ("it-IT" -> "it_IT"; "it" -> "it").
  // gnugettext falls back "it_IT" -> "it" when no regional catalog exists.
  P := Pos('-', LTag);
  if P > 0 then
    Language := LowerCase(Copy(LTag, 1, P - 1)) + '_' +
                UpperCase(Copy(LTag, P + 1, Length(LTag)))
  else
    Language := LowerCase(LTag);
end;

class function TKWebSession.GetCurrent: TKWebSession;
begin
  Result := FCurrent;
end;

function TKWebSession.GetDefaultViewportWidth: Integer;
begin
  Result := FViewportWidthInInches * 96;
end;

procedure TKWebSession.RemoveController(const AController: IKXController);
begin
  if Assigned(FOpenControllers) then
    FOpenControllers.Remove(AController);
end;

procedure TKWebSession.RegenerateId;
begin
  // FindSessionById iterates and matches on the SessionId property, so
  // changing FSessionId in place is enough — no manager re-indexing needed.
  FSessionId := CreateCompactGuidStr;
  FIsSessionLost := False;
end;

procedure TKWebSession.SetLanguage(const AValue: string);
begin
  FLanguage := AValue;
  TEFLocalizationToolRegistry.CurrentTool.ForceLanguage(FLanguage);
  TEFLogger.Instance.LogFmt('Language %s set.', [FLanguage], TEFLogger.LOG_DETAILED);
end;

procedure TKWebSession.SetLanguageFromQueriesOrConfig(const AConfig: TKConfig);
var
  LLanguageId: string;
begin
  LLanguageId := TKWebRequest.Current.GetQueryField('lang');
  if LLanguageId = '' then
    LLanguageId := AConfig.Config.GetString('LanguageId');
  if LLanguageId <> '' then
    Language := LLanguageId;
end;

function TKWebSession.GetDisplayName: string;
begin
  Result := FDisplayName;
  if Result = '' then
    Result := SessionId;
end;

procedure TKWebSession.AfterConstruction;
begin
  inherited;
  FCreationDateTime := Now;

  FAuthData := TEFNode.Create;

  FGettextInstance := TGnuGettextInstance.Create;

  FOpenControllers := TList<IKXController>.Create;
end;

function TKWebSession.GetManifestFileName: string;
begin
  Result := '';
end;

{ TKWebSessionLocalizationTool }

procedure TKWebSessionLocalizationTool.AfterConstruction;
begin
  inherited;
  // Configure the global dxgettext instance.
  GetGnuGettextInstance.bindtextdomain(KITTO_TEXT_DOMAIN,
    TKConfig.SystemHomePath + 'locale');
end;

function TKWebSessionLocalizationTool.AsObject: TObject;
begin
  Result := Self;
end;

procedure TKWebSessionLocalizationTool.ForceLanguage(const ALanguageId: string);
var
  LInstance: TGnuGettextInstance;
begin
  LInstance := GetGnuGettextInstance;
  // Configure the per-session dxgettext instance.
  LInstance.bindtextdomain(KITTO_TEXT_DOMAIN,
    TKConfig.SystemHomePath + 'locale');
  LInstance.UseLanguage(ALanguageId);
end;

function TKWebSessionLocalizationTool.GetCurrentLanguageId: string;
begin
  Result := GetGnuGettextInstance.GetCurrentLanguage;
end;

function TKWebSessionLocalizationTool.GetGnuGettextInstance: TGnuGettextInstance;
begin
  if TKWebSession.Current <> nil then
    Result := TKWebSession.Current.FGettextInstance
  else
    Result := Kitto.gnugettext.DefaultInstance;
end;

procedure TKWebSessionLocalizationTool.TranslateComponent(const AComponent: TComponent);
var
  LInstance: TGnuGettextInstance;
begin
  LInstance := GetGnuGettextInstance;
  LInstance.TranslateComponent(AComponent, KITTO_TEXT_DOMAIN);
  LInstance.TranslateComponent(AComponent, 'default');
end;

function TKWebSessionLocalizationTool.TranslateString(const AString,
  AIdString: string): string;
var
  LInstance: TGnuGettextInstance;
begin
  // Look in the Kitto text domain first, then in the application domain.
  LInstance := GetGnuGettextInstance;
  Result := LInstance.dgettext(KITTO_TEXT_DOMAIN, AString);
  if Result = AString then
    Result := LInstance.dgettext('default', AString);
end;

{ TKWebSessions }

constructor TKWebSessions.Create(const ATimeout: Double);
begin
  inherited Create;
  FTimeout := ATimeout;
end;

procedure TKWebSessions.AfterConstruction;
begin
  inherited;
  FSessions := TObjectList<TKWebSession>.Create;
  FRetiredSessions := TObjectList<TKWebSession>.Create;
end;

procedure TKWebSessions.CleanupExpiredSessions;
var
  I: Integer;
  LSession: TKWebSession;
begin
  MonitorEnter(FSessions);
  try
    for I := FSessions.Count - 1 downto 0 do
    begin
      LSession := FSessions[I];
      // A session with a request in flight is in use, whatever HasExpired
      // says: a request that outlasts the timeout, or one that arrived an
      // instant before it and has not recorded its activity yet. Freeing it
      // here pulled the object from under that request. It will be looked at
      // again at the next round.
      if (LSession.FRequestCount = 0) and LSession.HasExpired then
      begin
        FSessions.Extract(LSession);
        try
          SessionRemoved(LSession);
        finally
          FreeAndNil(LSession);
        end;
      end;
    end;
  finally
    MonitorExit(FSessions);
  end;
end;

procedure TKWebSessions.ClearSessions;
begin
  MonitorEnter(FSessions);
  try
    while FSessions.Count > 0 do
      RemoveSession(FSessions[0]);
  finally
    MonitorExit(FSessions);
  end;
end;

procedure TKWebSessions.RemoveSession(const ASession: TKWebSession);
begin
  MonitorEnter(FSessions);
  try
    if FSessions.Extract(ASession) <> nil then
    begin
      try
        SessionRemoved(ASession);
      finally
        RetireOrFree(ASession);
      end;
    end;
  finally
    MonitorExit(FSessions);
  end;
end;

procedure TKWebSessions.RetireOrFree(const ASession: TKWebSession);
begin
  // Called under the lock, on a session already extracted from FSessions.
  // This is the one place that decides the fate of a session that has left the
  // list. It used to be freed on the spot, and that was the access violation
  // under concurrent requests of the same session: the page refresh of one
  // request freed the object another thread was still working on - its
  // gettext instance, its auth data, its strings.
  if ASession.FRequestCount > 0 then
  begin
    ASession.FIsRetired := True;
    FRetiredSessions.Add(ASession);
  end
  else
    ASession.Free;
end;

function TKWebSessions.GetRetiredSessionCount: Integer;
begin
  MonitorEnter(FSessions);
  try
    Result := FRetiredSessions.Count;
  finally
    MonitorExit(FSessions);
  end;
end;

procedure TKWebSessions.ReleaseSession(const ASession: TKWebSession);
begin
  if not Assigned(ASession) then
    Exit;
  MonitorEnter(FSessions);
  try
    Assert(ASession.FRequestCount > 0,
      'ReleaseSession without a matching acquire: ' + ASession.SessionId);
    Dec(ASession.FRequestCount);
    if ASession.FIsRetired and (ASession.FRequestCount = 0) then
      // Owned by the list: Remove frees it.
      FRetiredSessions.Remove(ASession);
  finally
    MonitorExit(FSessions);
  end;
end;

function TKWebSessions.RenewSession(const ASession: TKWebSession;
  const AClientAddress: string): TKWebSession;
var
  LListed: TKWebSession;
  LSource: TKWebSession;
begin
  Assert(Assigned(ASession), 'Assigned(ASession)');

  MonitorEnter(FSessions);
  try
    // The session this id leads to NOW. Usually ASession itself; a different
    // object when another page refresh got here first (two tabs reloading
    // together), none when the session was removed in the meantime. The state
    // is taken from the listed one, as it would be had this request arrived a
    // moment later, and that is the one replaced: an id must never lead to two
    // live sessions.
    LListed := FindSessionById(ASession.SessionId);
    if Assigned(LListed) then
      LSource := LListed
    else
      LSource := ASession;

    Result := TKWebSession.Create(AClientAddress, ASession.SessionId, FTimeout);
    // Carry the state over while nobody can find either object half-done: the
    // new one is not in the list yet. The owner of the old one may be logging
    // out or in at this very moment, on its own thread - hence the auth lock.
    LSource.LockAuthData;
    try
      Result.FIsAuthenticated := LSource.FIsAuthenticated;
      if Result.FIsAuthenticated then
        Result.FAuthData.Assign(LSource.FAuthData);
    finally
      LSource.UnlockAuthData;
    end;
    Result.FReloadingHome := LSource.FReloadingHome;
    Result.FDatabaseName := LSource.FDatabaseName;

    // The caller's acquire moves from the old object to the new one.
    Result.FRequestCount := 1;
    Assert(ASession.FRequestCount > 0,
      'RenewSession on a session not acquired: ' + ASession.SessionId);
    Dec(ASession.FRequestCount);

    if Assigned(LListed) then
      FSessions.Extract(LListed);
    FSessions.Add(Result);
    // If ASession is not the listed one it is already out of the list, and
    // whoever took it out announced its end and retired it: this request was
    // what kept it alive, so it may go now.
    if (ASession <> LListed) and ASession.FIsRetired and (ASession.FRequestCount = 0) then
      FRetiredSessions.Remove(ASession);
    if Assigned(LListed) then
    begin
      try
        SessionRemoved(LListed);
      finally
        RetireOrFree(LListed);
      end;
    end;
  finally
    MonitorExit(FSessions);
  end;
  SessionAdded(Result);
end;

procedure TKWebSessions.SessionAdded(const ASession: TKWebSession);
begin
  if Assigned(FOnSessionStart) then
    FOnSessionStart(ASession);
end;

procedure TKWebSessions.SessionRemoved(const ASession: TKWebSession);
begin
  if Assigned(FOnSessionEnd) then
    FOnSessionEnd(ASession);
end;

destructor TKWebSessions.Destroy;
begin
  FreeAndNil(FSessions);
  // Whatever is still here at shutdown had a request that never gave it back.
  FreeAndNil(FRetiredSessions);
  inherited;
end;

function TKWebSessions.GetSessionInfos: TArray<TKWebSessionInfo>;
var
  I: Integer;
  LSession: TKWebSession;
begin
  MonitorEnter(FSessions);
  try
    SetLength(Result, FSessions.Count);
    for I := 0 to FSessions.Count - 1 do
    begin
      LSession := FSessions[I];
      Result[I].Id := LSession.SessionId;
      Result[I].DisplayName := LSession.DisplayName;
      Result[I].CreationDateTime := LSession.CreationDateTime;
      Result[I].LastRequestDateTime := LSession.LastRequestInfo.DateTime;
      Result[I].UserName := LSession.AuthData.GetString('UserName');
      Result[I].ClientAddress := LSession.LastRequestInfo.ClientAddress;
      Result[I].UserAgent := LSession.LastRequestInfo.UserAgent;
    end;
  finally
    MonitorExit(FSessions);
  end;
end;

function TKWebSessions.SetSessionDisplayName(const ASessionId,
  ADisplayName: string): Boolean;
var
  LSession: TKWebSession;
begin
  MonitorEnter(FSessions);
  try
    LSession := FindSessionById(ASessionId);
    Result := Assigned(LSession);
    if Result then
      LSession.DisplayName := ADisplayName;
  finally
    MonitorExit(FSessions);
  end;
end;

function TKWebSessions.NewSession(const AClientAddress: string; const ASessionId: string = ''): TKWebSession;
var
  LSessionId: string;
begin
  Assert(AClientAddress <> '', 'AClientAddress <> ''''');

  if ASessionId <> '' then
    LSessionId := ASessionId
  else
    LSessionId := CreateNewSessionId;

  Result := TKWebSession.Create(AClientAddress, LSessionId, FTimeout);
  MonitorEnter(FSessions);
  try
    FSessions.Add(Result);
  finally
    MonitorExit(FSessions);
  end;
  SessionAdded(Result);
end;

function TKWebSessions.FindOrCreateSession(const ASessionId, AClientAddress: string;
  out ACreated: Boolean): TKWebSession;
var
  LSessionId: string;
begin
  MonitorEnter(FSessions);
  try
    // A request is matched to an existing session ONLY by the session id it
    // presents. There used to be a fallback here: with no id, the first session
    // with the same CLIENT ADDRESS was reused — which handed a request arriving
    // without the session cookie somebody else's session, authentication and
    // all. Reproduced: a legitimate user logged in, then a brand-new client with
    // no cookie asked for kx/view/<V>/data and received that user's rows, with no
    // new session created for it. Behind a reverse proxy or NAT — the normal way
    // to deploy under IIS, Apache or nginx — every user shares one address, so
    // any cookie-less request (first visit, cleared or blocked cookies, a crawler)
    // landed in whichever session existed for the proxy. No id, no match: a new
    // anonymous session is created below and the response carries its cookie.
    if ASessionId <> '' then
      Result := FindSessionById(ASessionId)
    else
      Result := nil;

    if Assigned(Result) then
    begin
      ACreated := False;
      Inc(Result.FRequestCount);
      Exit;
    end;

    // Create new session under the same lock
    if ASessionId <> '' then
      LSessionId := ASessionId
    else
      LSessionId := CreateNewSessionId;
    Result := TKWebSession.Create(AClientAddress, LSessionId, FTimeout);
    Result.FRequestCount := 1;
    FSessions.Add(Result);
    ACreated := True;
  finally
    MonitorExit(FSessions);
  end;
  if ACreated then
    SessionAdded(Result);
end;

function TKWebSessions.FindSessionById(const ASessionId: string): TKWebSession;
var
  I: Integer;
begin
  for I := 0 to FSessions.Count - 1 do
    if FSessions[I].SessionId = ASessionId then
      Exit(FSessions[I]);
  Result := nil;
end;

function TKWebSessions.CreateNewSessionId: string;
begin
  Result := CreateCompactGuidStr;
end;

{ TKWebSessionCleanupThread }

constructor TKWebSessionCleanupThread.Create(const ASessions: TKWebSessions; const AInterval: Double);
begin
  inherited Create;
  FSessions := ASessions;
  if AInterval <> 0 then
    FInterval := AInterval
  else
    FInterval := DEFAULT_INTERVAL;
end;

procedure TKWebSessionCleanupThread.Execute;
begin
  while not Terminated do
  begin
    if Assigned(FSessions) then
    begin
      MonitorEnter(FSessions);
      try
        FSessions.CleanupExpiredSessions;
      finally
        MonitorExit(FSessions);
      end;
    end;
    WaitInterval;
  end;
end;

procedure TKWebSessionCleanupThread.WaitInterval;
const
  STEP = 100;
var
  LMilliseconds: Int64;
begin
  LMilliseconds := MilliSecondsBetween(Now, Now + FInterval);
  while (LMilliseconds > 0) and not Terminated do
  begin
    Sleep(STEP);
    Dec(LMilliseconds, STEP);
  end;
end;

initialization
  TEFLocalizationToolRegistry.RegisterTool(TKWebSessionLocalizationTool.Create);

finalization
  TEFLocalizationToolRegistry.UnregisterTool;

end.
