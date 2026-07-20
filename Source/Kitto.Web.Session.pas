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
unit Kitto.Web.Session;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.Classes,
  System.Generics.Collections,
  gnugettext,
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
    FRefreshingLanguage: Boolean;
    FViewportWidthInInches: Integer;
    FAutoOpenViewName: string;
    FAuthData: TEFNode;
    FIsAuthenticated: Boolean;
    FIsBCrypted: Boolean;
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
    /// <summary>True while the language is being (re)applied; guards re-entrancy.</summary>
    property RefreshingLanguage: Boolean read FRefreshingLanguage write FRefreshingLanguage;

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
    ///  Returns True if authentication has successfully taken
    ///  place.
    /// </summary>
    property IsAuthenticated: Boolean read FIsAuthenticated write FIsAuthenticated;

    /// <summary>
    ///  Returns True if password is Crypted
    /// </summary>
    property IsBCrypted: Boolean read FIsBCrypted write FIsBCrypted;

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
    property DisplayName: string read GetDisplayName write FDisplayName;

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
    function AsObject: TObject;
    function TranslateString(const AString: string;
      const AIdString: string = ''): string;
    procedure TranslateComponent(const AComponent: TComponent);
    procedure ForceLanguage(const ALanguageId: string);
    function GetCurrentLanguageId: string;
    procedure AfterConstruction; override;
  end;

  TKWebSessions = class
  private type
    TKWebSessionProc = TProc<TKWebSession>;
  private
    FSessions: TObjectList<TKWebSession>;
    FTimeout: Double;
    FOnSessionEnd: TKWebSessionProc;
    FOnSessionStart: TKWebSessionProc;
    function CreateNewSessionId: string;
    function FindSessionById(const ASessionId: string): TKWebSession;
    function FindSessionByClientAddress(const AClientAddress: string): TKWebSession;
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
    ///  If ASessionId is provided, looks for a session with that id returns it, otherwise returns nil.
    ///  If ASessionId is not provided, looks for a session with the specified client address and
    ///  returns it, otherwise returns nil. In this case, if no client address is specified, returns nil.
    /// </summary>
    function FindSession(const ASessionId, AClientAddress: string): TKWebSession;

    /// <summary>
    ///  Atomically finds or creates a session. If ASessionId matches an existing
    ///  session it is returned; otherwise a new session is created. ACreated is
    ///  set to True when a new session was created.
    /// </summary>
    function FindOrCreateSession(const ASessionId, AClientAddress: string;
      out ACreated: Boolean): TKWebSession;

    /// <summary>
    ///  Returns all sessions as an array for reporting and diagnostic purposes.
    /// </summary>
    function GetSessions: TArray<TKWebSession>;

    /// <summary>
    ///  Deletes and frees the specified session.
    /// </summary>
    procedure RemoveSession(const ASession: TKWebSession);

    /// <summary>Removes and frees all sessions.</summary>
    procedure ClearSessions;

    /// <summary>Removes and frees the sessions that have expired (per their timeout).</summary>
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
begin
  Result := Now > FLastRequestInfo.DateTime + FTimeout;
end;

constructor TKWebSession.Create(const AClientAddress, ASessionId: string; const ATimeout: Double);
begin
  Assert(ASessionId <> '');
  Assert(AClientAddress <> '');

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

procedure TKWebSession.RegisterStore(const AViewName: string; AStore: TKViewTableStore);
begin
  // If a store was already registered for this view, it is freed and replaced
  // (TObjectDictionary with doOwnsValues frees the old value on AddOrSetValue).
  FStores.AddOrSetValue(AViewName, AStore);
end;

function TKWebSession.FindStore(const AViewName: string): TKViewTableStore;
begin
  if not FStores.TryGetValue(AViewName, Result) then
    Result := nil;
end;

procedure TKWebSession.UnregisterStore(const AViewName: string);
begin
  // TObjectDictionary frees the store object on Remove.
  FStores.Remove(AViewName);
end;

class procedure TKWebSession.SetCurrent(const Value: TKWebSession);
begin
  FCurrent := Value;
end;

procedure TKWebSession.SetDefaultLanguage(const AValue: string);
var
  I: Integer;
  LNewLanguage: string;
begin
  if Language = '' then
  begin
    LNewLanguage := AValue;
    I := Pos('-', LNewLanguage);
    if I <> 0 then
      // Convert language code
      LNewLanguage := Copy(LNewLanguage, I - 2, 2) + '_' + Uppercase(Copy(LNewLanguage, I + 1, 2));
    Language := LNewLanguage;
  end;
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
    Result := gnugettext.DefaultInstance;
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
      if LSession.HasExpired then
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
        ASession.Free;
      end;
    end;
  finally
    MonitorExit(FSessions);
  end;
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
  inherited;
end;

function TKWebSessions.GetSessions: TArray<TKWebSession>;
begin
  MonitorEnter(FSessions);
  try
    Result := FSessions.ToArray;
  finally
    MonitorExit(FSessions);
  end;
end;

function TKWebSessions.NewSession(const AClientAddress: string; const ASessionId: string = ''): TKWebSession;
var
  LSessionId: string;
begin
  Assert(AClientAddress <> '');

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

function TKWebSessions.FindSession(const ASessionId, AClientAddress: string): TKWebSession;
begin
  MonitorEnter(FSessions);
  try
    if ASessionId <> '' then
      Result := FindSessionById(ASessionId)
    else if AClientAddress <> '' then
      Result := FindSessionByClientAddress(AClientAddress)
    else
      Result := nil;
  finally
    MonitorExit(FSessions);
  end;
end;

function TKWebSessions.FindOrCreateSession(const ASessionId, AClientAddress: string;
  out ACreated: Boolean): TKWebSession;
var
  LSessionId: string;
begin
  MonitorEnter(FSessions);
  try
    // Try to find existing session
    if ASessionId <> '' then
      Result := FindSessionById(ASessionId)
    else if AClientAddress <> '' then
      Result := FindSessionByClientAddress(AClientAddress)
    else
      Result := nil;

    if Assigned(Result) then
    begin
      ACreated := False;
      Exit;
    end;

    // Create new session under the same lock
    if ASessionId <> '' then
      LSessionId := ASessionId
    else
      LSessionId := CreateNewSessionId;
    Result := TKWebSession.Create(AClientAddress, LSessionId, FTimeout);
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

function TKWebSessions.FindSessionByClientAddress(const AClientAddress: string): TKWebSession;
var
  I: Integer;
begin
  for I := 0 to FSessions.Count - 1 do
    if FSessions[I].LastRequestInfo.ClientAddress = AClientAddress then
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
