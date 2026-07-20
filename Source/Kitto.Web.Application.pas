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

unit Kitto.Web.Application;

interface

uses
  System.Types,
  System.SysUtils,
  System.Classes,
  EF.Macros,
  EF.Tree,
  EF.Intf,
  EF.ObserverIntf,
  Kitto.Auth,
  Kitto.AccessControl,
  Kitto.Config,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView,
  Kitto.Store,
  Kitto.Web.Routes,
  Kitto.Web.URL,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Html.Base,
  Kitto.Html.Controller;


type

  TKWebApplication = class;

  TKApplicationMacroExpander = class(TEFTreeMacroExpander)
  private
    FApplication: TKWebApplication;
  strict protected
    procedure InternalExpand(var AString: string); override;
  public
    /// <summary>Creates the macro expander bound to the given application.</summary>
    constructor Create(const AApplication: TKWebApplication); reintroduce;
  end;

  TKWebApplication = class(TKWebRoute)
  strict private
    FConfig: TKConfig;
    FPath: string;
    FLoginNode: TEFNode;
    FOwnsLoginNode: Boolean;
    FMacroExpander: TKApplicationMacroExpander;
    FResourcePath: string;
    FResourceLocalPath1: string;
    FResourceLocalPath2: string;
    FAuthenticator: TKAuthenticator;
    FAccessController: TKAccessController;
    FHandleResources: Boolean;
    class threadvar FCurrent: TKWebApplication;
    function GetDefaultHomeViewNodeNames(const ASuffix: string): TStringDynArray;
    procedure DetectScreenSize;
    procedure Home;
    procedure FreeLoginNode;
    procedure ServeHomePage(const ABodyContent: string);
    function GetManifestFileName: string;


    procedure Reload;
    class function GetCurrent: TKWebApplication; static;
    class procedure SetCurrent(const AValue: TKWebApplication); static;
    function GetAuthenticator: TKAuthenticator;
    function GetAccessController: TKAccessController;
    procedure InitConfig;
    /// <summary>
    ///  Adds a .png extension to the resource name.
    ///  ASuffix, if specified, is added before the file extension.
    ///  If the image name ends with _ and a two-digit number among 16, 24, 32, and 48,
    ///  then the suffix is added before the _.
    /// </summary>
    class function AdaptImageName(const AResourceName: string; const ASuffix: string = ''): string;
  public
    // --- Internal helpers shared with the attribute-based handlers ---
    // Exposed as public so the extracted handlers (Kitto.Web.Handler.View, …)
    // can call them via TKWebApplication.Current. The legacy /kx/* dispatch has
    // been fully removed (routing refactor complete); DoHandleRequest now only
    // serves Home, delegating every /kx/* endpoint to its attribute route.
    /// <summary>
    ///  Returns True when AView grants AMode to the current session.
    ///  On deny: sets TKWebResponse.Current.StatusCode := 404 and logs
    ///  'ACL deny: ...' at LOG_DETAILED. UI components (TreePanel,
    ///  ToolBar, …) already filter on IsAccessGranted; this is the
    ///  matching server-side gate for every HandleKX* route.
    ///  Caller pattern: `if not IsViewAccessGranted(LView, ACM_X) then
    ///  Exit(True);`. Returning True (not False) tells the engine the
    ///  request has been handled, so SimpleHandleRequest's "unknown
    ///  request" fallback does NOT overwrite our empty 404 body with
    ///  its HTML page (the client would otherwise parse it and
    ///  accumulate orphan DOM nodes on every retry).
    /// </summary>
    function IsViewAccessGranted(const AView: TKView; const AMode: string): Boolean;
    /// <summary>
    ///  Resolves AViewName via Config.Views.FindView. On miss: sets
    ///  StatusCode := 404 and logs 'View not found: ...' at LOG_DETAILED.
    ///  Caller pattern: `LView := FindViewOrSetNotFound(AViewName);
    ///  if not Assigned(LView) then Exit(True);`. Pair with
    ///  IsViewAccessGranted to enforce the correct access mode AFTER the
    ///  view is resolved (modes that depend on request fields like _op
    ///  cannot be decided before the handler reads them). See
    ///  IsViewAccessGranted for why Exit(True) is required.
    /// </summary>
    function FindViewOrSetNotFound(const AViewName: string): TKView;
    /// <summary>
    ///  Returns True when AView is a TKDataView (the type required by
    ///  every data/CRUD endpoint). On miss: sets StatusCode := 404 — a
    ///  request for /kx/data/<Foo> where Foo exists but is not a data
    ///  view is "no such resource" at this URL.
    ///  Caller pattern: `if not RequireDataView(LView) then Exit(True);`.
    /// </summary>
    function RequireDataView(const AView: TKView): Boolean;
    // HandleKX{Tool,Lookup,WizardFinish,Blob,TempUpload,NotifyChange}Request +
    // NotifyFieldChangeHandler + HandleKXDetail{Data,Save,Delete}Request
    // migrated to Kitto.Web.Handler.View
    /// <summary>
    ///  Populates a record's field values from the current POST data.
    ///  Shared by HandleKXSaveRequest, HandleKXDetailSaveRequest, HandleKXWizardFinishRequest.
    /// </summary>
    procedure PopulateRecordFromPost(ARecord: TKViewTableRecord;
      AViewTable: TKViewTable; AIsInsert: Boolean);
    /// <summary>
    ///  Applies a single field's POST value to the record, replicating the
    ///  type-aware logic of PopulateRecordFromPost. Used by the notify
    ///  endpoint to apply only the trigger field.
    /// </summary>
    procedure PopulateRecordFieldFromPost(ARecord: TKViewTableRecord;
      AViewField: TKViewField; AIsInsert: Boolean);
    /// <summary>Builds an ORDER BY expression from CSV sort/dir request fields.
    /// Fields not in AViewTable are silently dropped (anti SQL injection).</summary>
    function BuildSortExpression(AViewTable: TKViewTable;
      const ASort, ADir: string): string;
    /// <summary>Adjusts controller modal/size for the current context.
    /// Mobile: forces IsModal + Maximized. Desktop non-modal: clears dimensions.</summary>
    procedure AdjustControllerForContext(const AController: IKXController);
  protected
    function DoHandleRequest(const ARequest: TKWebRequest; const AResponse: TKWebResponse; const AURL: TKWebURL): Boolean; override;
  public
    class constructor Create;
    class destructor Destroy;
    procedure AfterConstruction; override;
    destructor Destroy; override;

    /// <summary>Sets up thread-local singletons (Authenticator, AccessController, Macros).
    /// Must be called before any handler that accesses metadata or stores.</summary>
    procedure ActivateInstance;
    /// <summary>Clears the thread-local singletons set by ActivateInstance (call in a finally).</summary>
    procedure DeactivateInstance;

    /// <summary>IEFObserver hook; reacts to configuration/subject change notifications.</summary>
    procedure UpdateObserver(const ASubject: IEFSubject; const AContext: string = ''); override;
    /// <summary>Called when the app is added to the route chain: registers the attribute
    /// router and the static-resource route ahead of this legacy handler.</summary>
    procedure AddedTo(const AList: TKWebRouteList; const AIndex: Integer); override;

    /// <summary>The application's configuration (Config.yaml catalog).</summary>
    property Config: TKConfig read FConfig;
    /// <summary>Reloads the configuration from disk.</summary>
    procedure ReloadConfig;

    /// <summary>Returns the application's home view.</summary>
    function GetHomeView: TKView;
    /// <summary>Displays the view with the given name.</summary>
    procedure DisplayView(const AName: string); overload;
    /// <summary>Displays the given view.</summary>
    procedure DisplayView(const AView: TKView); overload;
    /// <summary>The application base URL path (e.g. '/taskittox').</summary>
    property Path: string read FPath;

    /// <summary>The application bound to the current thread (per-request threadvar).</summary>
    class property Current: TKWebApplication read GetCurrent write SetCurrent;

    /// <summary>
    ///  Returns the URL for the specified resource, based on the first
    ///  existing file in the ordered list of resource folders. If no existing
    ///  file is found, an exception is raised.
    /// </summary>
    /// <param name="AResourceFileName">
    ///  Resource file name relative to the resource folder. Examples:
    ///  some_image.png, js\some_library.js.
    /// </param>
    function GetResourceURL(const AResourceFileName: string): string;

    /// <summary>Returns the URL for the specified resource, based on the first
    /// existing file in the ordered list of resource folders. If no existing
    /// file is found, returns ''.</summary>
    /// <param name="AResourceFileName">Resource file name relative to the
    /// resource folder. Examples: some_image.png, js\some_library.js.</param>
    function FindResourceURL(const AResourceFileName: string): string;

    /// <summary>
    ///   Returns the full pathname for the specified resource, based on the first
    ///   existing file in the ordered list of resource folders. If no existing
    ///   file is found, an exception is raised.
    /// </summary>
    /// <param name="AResourceFileName">
    ///   Resource file name relative to the resource folder. Examples:
    ///   some_image.png, js\some_library.js.
    /// </param>
    function GetResourcePathName(const AResourceFileName: string): string;

    /// <summary>
    ///  Returns the full pathname for the specified resource, based on
    ///  the first existing file in the ordered list of resource folders. If no
    ///  existing file is found, returns ''.
    /// </summary>
    /// <param name="AResourceFileName">
    ///  Resource file name relative to the resource folder.
    ///  Examples: some_image.png, js\some_library.js.
    /// </param>
    function FindResourcePathName(const AResourceFileName: string): string;

    /// <summary>Returns the URL of the named image resource (raises if not found).</summary>
    function GetImageURL(const AResourceName: string; const ASuffix: string = ''): string;
    /// <summary>Returns the URL of the named image resource, or '' if not found.</summary>
    function FindImageURL(const AResourceName: string; const ASuffix: string = ''): string;

    /// <summary>Returns the full path of the named image resource (raises if not found).</summary>
    function GetImagePathName(const AResourceName: string; const ASuffix: string = ''): string;
    /// <summary>Returns the full path of the named image resource, or '' if not found.</summary>
    function FindImagePathName(const AResourceName: string; const ASuffix: string = ''): string;

    /// <summary>Reloads (or displays) the home view, e.g. after a language change.</summary>
    procedure ReloadOrDisplayHomeView;
    /// <summary>Returns the application's login view.</summary>
    function GetLoginView: TKView;
    /// <summary>Renders and serves the home view page.</summary>
    procedure DisplayHomeView;
    /// <summary>Renders and serves the login view page.</summary>
    procedure DisplayLoginView;
    /// <summary>Emits a client-side toast notification with the given message.</summary>
    procedure Toast(const AMessage: string);
    /// <summary>Emits a client-side navigation to the given URL.</summary>
    procedure Navigate(const AURL: string);

    /// <summary>Serves a server file as a download (or inline) response.</summary>
    procedure DownloadFile(const AServerFileName, AFileName: string; const AContentType: string = ''; const AInline: Boolean = True);
    /// <summary>Serves the given stream as a download (or inline) response; takes ownership of AStream.</summary>
    procedure DownloadStream(const AStream: TStream; const AFileName: string; const AContentType: string = ''; const AInline: Boolean = True);
    /// <summary>Serves the given bytes as a download (or inline) response.</summary>
    procedure DownloadBytes(const ABytes: TBytes; const AFileName: string; const AContentType: string = ''; const AInline: Boolean = True);
    /// <summary>
    ///  Checks user credentials (fetched from Query parameters UserName and Passwords)
    ///  and returns True if the current authenticator allows them, or if the
    ///  user was already authenticated in this session.
    /// </summary>
    function Authenticate: Boolean;


    /// <summary>Builds the URL for a method call (AppPath + namespace + object/method).</summary>
    function GetMethodURL(const AObjectName, AMethodName: string): string;

    /// <summary>
    ///  Returns the Home URL of the Kitto application assuming the URL is
    ///  visited from localhost.
    /// </summary>
    function GetHomeURL(const ATCPPort: Integer): string;
    /// <summary>
    ///  True if tooltips are enabled for the application. By default, tooltips
    ///  are enabled for desktop browsers and disabled for mobile browsers.
    /// </summary>
    function TooltipsEnabled: Boolean;

    /// <summary>
    ///  When the active authenticator is a TKJWTAuthenticator, validates the
    ///  kx_token cookie, hydrates the session from the verified claims, and
    ///  slides the cookie expiration if approaching. No-op for other
    ///  authenticators. Public so the attribute router (TKXRoutingRoute) can
    ///  give attribute-routed requests the same JWT hydration as the legacy path.
    /// </summary>
    procedure AuthorizeJWTRequest;

    /// <summary>
    ///  Renders a modal error dialog into the current response as an HTMX
    ///  overlay. AIsFatal=True signals a fatal error (session teardown + reload
    ///  to login); False lets the user dismiss and retry. Public so the
    ///  error-handler request filter (Kitto.Web.Routing.AppFilters) renders
    ///  exceptions uniformly for both the attribute and legacy pipelines.
    /// </summary>
    procedure RenderErrorDialog(const AMessage: string; const AIsFatal: Boolean);

    /// <summary>
    ///  True if the named view exists and is declared public (empty ACURI, i.e.
    ///  reachable without authentication via ACName in YAML). Used by the
    ///  authorization filter to exempt public views from the auth gate.
    /// </summary>
    function IsPublicView(const AViewName: string): Boolean;

    /// <summary>Populates AuthData.DatabaseName (raw config name) and
    ///  AuthData.Environment (Databases/Name/DisplayLabel if present, falling
    ///  back to the raw name) so the corresponding %Auth:* macros resolve.
    ///  Public so the auth handler (Kitto.Web.Handler.Auth) can call it.</summary>
    procedure DeclareDatabaseMacros(const AAuthData: TEFNode);


    /// <summary>
    ///  Renders AView through its controller and returns the full HTML body
    ///  (create controller -> Display -> Render). When AView declares no
    ///  controller type, ADefaultControllerType is used (e.g. 'Login').
    /// </summary>
    function RenderViewAsPage(const AView: TKView; const ADefaultControllerType: string = ''): string;
    /// <summary>
    ///  Renders AView and serves it wrapped in the _Page template (theme,
    ///  scripts) via ServeHomePage. Reusable entry point for page handlers.
    /// </summary>
    procedure ServeViewAsPage(const AView: TKView; const ADefaultControllerType: string = '');

    procedure Logout;

    /// <summary>Returns the current authenticator instance, creating it
    /// on first access from the Auth configuration node.</summary>
    property Authenticator: TKAuthenticator read GetAuthenticator;
  end;

implementation

uses
  System.StrUtils,
  System.IOUtils,
  System.Math,
  System.NetEncoding,
  System.Generics.Collections,
  System.Rtti,
  Data.DB,
  Kitto.TemplatePro,
  EF.Logger,
  EF.StrUtils,
  EF.Localization,
  EF.Types,
  Kitto.Types,
  Kitto.Web.Types,
  Kitto.Web.Session,
  Kitto.Html.TemplateEngine,
  Kitto.Html.Response,
  Kitto.Html.List,
  Kitto.Html.Filters,
  Kitto.Metadata.Models,
  Kitto.Metadata.SubNodes,
  Kitto.Html.Form,
  Kitto.Html.Utils,
  Kitto.Html.Panel,
  Kitto.Html.FormController,
  Kitto.Html.Wizard,
  Kitto.Rules,
  Kitto.Rules.Wizard,
  Kitto.Html.GroupingList,
  Kitto.Html.TemplateDataPanel,
  EF.Sys,
  EF.DB,
  EF.SQL,
  Kitto.SQL,
  Kitto.Web.Routing.Route,
  Kitto.Web.Routing.Scripts,
  Kitto.Web.Routing.Filters,
  Kitto.Web.Routing.AppFilters,
  EF.JSON,
  Web.HTTPApp;

{ TKApplicationMacroExpander }

constructor TKApplicationMacroExpander.Create(const AApplication: TKWebApplication);
begin
  Assert(Assigned(AApplication));

  // We will pass Session.AuthData dynamically as needed, so we initialize the
  // expander with nil. We inherit from TEFTreeExpander only to inherit its
  // functionality.
  inherited Create(nil, 'Auth');
  FApplication := AApplication;
end;

procedure TKApplicationMacroExpander.InternalExpand(var AString: string);
const
  IMAGE_MACRO_HEAD = '%IMAGE(';
  MACRO_TAIL = ')%';
var
  LPosHead: Integer;
  LPosTail: Integer;
  LName: string;
  LURL: string;
  LRest: string;
begin
  inherited InternalExpand(AString);
  if TKWebSession.Current <> nil then
  begin
    ExpandMacros(AString, '%SESSION_ID%', TKWebSession.Current.SessionId);
    ExpandMacros(AString, '%LANGUAGE_ID%', TKWebSession.Current.Language);
    // Expand %Auth:*%.
    if Assigned(TKWebSession.Current.AuthData) then
      ExpandTreeMacros(AString, TKWebSession.Current.AuthData);
  end;

  if FApplication <> nil then
  begin
    LPosHead := Pos(IMAGE_MACRO_HEAD, AString);
    if LPosHead > 0 then
    begin
      LPosTail := PosEx(MACRO_TAIL, AString, LPosHead + 1);
      if LPosTail > 0 then
      begin
        LName := Copy(AString, LPosHead + Length(IMAGE_MACRO_HEAD),
          LPosTail - (LPosHead + Length(IMAGE_MACRO_HEAD)));
        LURL := FApplication.GetImageURL(LName);
        LRest := Copy(AString, LPosTail + Length(MACRO_TAIL), MaxInt);
        InternalExpand(LRest);
        Delete(AString, LPosHead, MaxInt);
        Insert(LURL, AString, Length(AString) + 1);
        Insert(LRest, AString, Length(AString) + 1);
      end;
    end;
  end;
end;

{ TWebKApplication }


procedure TKWebApplication.AfterConstruction;
begin
  inherited;
  FOwnsLoginNode := False;
  InitConfig;
end;

destructor TKWebApplication.Destroy;
begin
  FreeLoginNode;
  FreeAndNil(FAuthenticator);
  FreeAndNil(FAccessController);
  FreeAndNil(FConfig);
  inherited;
end;

procedure TKWebApplication.InitConfig;
begin
  FConfig := TKConfig.Create;
  FMacroExpander := TKApplicationMacroExpander.Create(Self);
  FConfig.MacroExpansionEngine.AddExpander(FMacroExpander);
  FPath := FConfig.Config.GetString('AppPath', '/' + Config.AppName.ToLower);
  FResourcePath := FPath + '/res';
  FResourceLocalPath1 := TPath.Combine(FConfig.AppHomePath, 'Resources');
  FResourceLocalPath2 := TPath.Combine(FConfig.SystemHomePath, 'Resources');
  FHandleResources := FConfig.Config.GetBoolean('Application/HandleResources', True);
end;

procedure TKWebApplication.ReloadConfig;
begin
  FreeLoginNode;
  FreeAndNil(FAuthenticator);
  FreeAndNil(FAccessController);
  FreeAndNil(FConfig);
  InitConfig;
end;


procedure TKWebApplication.AddedTo(const AList: TKWebRouteList; const AIndex: Integer);
begin
  inherited;
  // Reusing AIndex means we add the routes in reverse order.
  // Order (from first to last tried): Static → Routing → Application (this).

  // Attribute-based routing: handles registered resource handlers.
  // Inserted before this route so decorated handlers take priority;
  // unmatched requests fall through to DoHandleRequest.
  AList.AddRoute(TKXRoutingRoute.Create(FPath, Self), AIndex);

  // Try resources before routing as the switch code is faster for
  // the static routes.
  if FHandleResources then
    AList.AddRoute(TKMultipleStaticWebRoute.Create(
      FResourcePath + '/',
      [FResourceLocalPath1, FResourceLocalPath2]), AIndex);
end;

procedure TKWebApplication.FreeLoginNode;
begin
  // Free login node only if one was manufactured.
  if FOwnsLoginNode and Assigned(FLoginNode) then
  begin
    Config.Views.DeleteNonpersistentObject(FLoginNode);
    FreeAndNil(FLoginNode);
  end;
  FLoginNode := nil;
end;

function TKWebApplication.GetHomeURL(const ATCPPort: Integer): string;
begin
  Result := 'http://localhost';
  if ATCPPort <> 80 then
    Result := Result + ':' + ATCPPort.ToString;
  Result := Result + FPath + '/';
end;

function TKWebApplication.GetHomeView: TKView;
var
  LNodeNames: TStringDynArray;
begin
  if TKWebSession.Current.HomeViewNodeName <> '' then
  begin
    SetLength(LNodeNames, 1);
    LNodeNames[0] := TKWebSession.Current.HomeViewNodeName;
  end
  else
    LNodeNames := GetDefaultHomeViewNodeNames('View');
  Result := Config.Views.FindViewByNode(Config.Config.FindNode(LNodeNames));
  if not Assigned(Result) then
    Result := Config.Views.ViewByName(GetDefaultHomeViewNodeNames(''));
end;

function TKWebApplication.GetLoginView: TKView;
begin
  if not Assigned(FLoginNode) then
  begin
    FOwnsLoginNode := False;
    FLoginNode := Config.Config.FindNode('Login');
    if not Assigned(FLoginNode) then
    begin
      Result := Config.Views.FindView('Login');
      if Assigned(Result) then
        Exit;

      FLoginNode := TEFNode.Create('Login');
      try
        FOwnsLoginNode := True;
        FLoginNode.SetString('Controller', 'Login');
      except
        FreeAndNil(FLoginNode);
        FOwnsLoginNode := False;
        raise;
      end;
    end;
  end;
  Result := Config.Views.FindViewByNode(FLoginNode);
  if not Assigned(Result) then
    raise Exception.Create('Login View not found');
end;

procedure TKWebApplication.DetectScreenSize;
var
  LScreenWH: string;
  LPos: Integer;
  LWidth, LHeight: Integer;
begin
  // 1. Try cookie kx_sw (set by JavaScript on previous page load)
  LScreenWH := TKWebRequest.Current.GetCookie('kx_sw');
  if LScreenWH <> '' then
  begin
    LPos := Pos('x', LScreenWH);
    if LPos > 0 then
    begin
      LWidth := StrToIntDef(Copy(LScreenWH, 1, LPos - 1), 0);
      LHeight := StrToIntDef(Copy(LScreenWH, LPos + 1, MaxInt), 0);
      if (LWidth > 0) and (LHeight > 0) then
      begin
        TKWebSession.Current.ScreenWidth := LWidth;
        TKWebSession.Current.ScreenHeight := LHeight;
        TKWebSession.Current.IsMobileBrowser := TKWebRequest.Current.IsMobileBrowser;
        Exit;
      end;
    end;
  end;

  // 2. Fallback: UA heuristic (first visit, no cookie yet)
  if TKWebRequest.Current.IsMobileBrowser then
  begin
    TKWebSession.Current.IsMobileBrowser := True;
    if TKWebRequest.Current.IsBrowserIPhone then
    begin
      TKWebSession.Current.ScreenWidth := 390;   // iPhone typical
      TKWebSession.Current.ScreenHeight := 844;
    end
    else if TKWebRequest.Current.IsBrowserIPad then
    begin
      TKWebSession.Current.ScreenWidth := 820;   // iPad typical
      TKWebSession.Current.ScreenHeight := 1180;
    end
    else // Android phone/tablet
    begin
      TKWebSession.Current.ScreenWidth := 412;   // Android typical
      TKWebSession.Current.ScreenHeight := 915;
    end;
  end
  else
  begin
    // Desktop: no screen detection needed, will use HomeView
    TKWebSession.Current.IsMobileBrowser := False;
    TKWebSession.Current.ScreenWidth := 1920;
    TKWebSession.Current.ScreenHeight := 1080;
  end;
end;

function TKWebApplication.GetDefaultHomeViewNodeNames(const ASuffix: string): TStringDynArray;
var
  LWidthInInches: Integer;
  LLandscape: Boolean;
begin
  LWidthInInches := TKWebSession.Current.ScreenWidth div 96;
  LLandscape := TKWebSession.Current.ScreenWidth > TKWebSession.Current.ScreenHeight;

  if TKWebSession.Current.IsMobileBrowser and (LWidthInInches <= 5) and not LLandscape then
  begin
    // Tiny phone in portrait: HomeTiny -> HomeSmall -> Home
    SetLength(Result, 3);
    Result[0] := 'HomeTiny' + ASuffix;
    Result[1] := 'HomeSmall' + ASuffix;
    Result[2] := 'Home' + ASuffix;
  end
  else if TKWebSession.Current.IsMobileBrowser and (LWidthInInches <= 10) then
  begin
    // Tablet or phone in landscape: HomeSmall -> Home
    SetLength(Result, 2);
    Result[0] := 'HomeSmall' + ASuffix;
    Result[1] := 'Home' + ASuffix;
  end
  else
  begin
    // Desktop
    SetLength(Result, 1);
    Result[0] := 'Home' + ASuffix;
  end;
end;


function TKWebApplication.FindViewOrSetNotFound(const AViewName: string): TKView;
begin
  Result := Config.Views.FindView(AViewName);
  if not Assigned(Result) then
  begin
    if Assigned(TKWebResponse.Current) then
      TKWebResponse.Current.StatusCode := 404;
    TEFLogger.Instance.LogFmt('View not found: "%s"', [AViewName],
      TEFLogger.LOG_DETAILED);
  end;
end;


function TKWebApplication.IsViewAccessGranted(const AView: TKView;
  const AMode: string): Boolean;
var
  LUser: string;
  LSession: TKWebSession;
begin
  Assert(Assigned(AView));
  Result := AView.IsAccessGranted(AMode);
  if not Result then
  begin
    LSession := TKWebSession.Current;
    if Assigned(LSession) and Assigned(LSession.AuthData) then
      LUser := LSession.AuthData.GetString('UserName')
    else
      LUser := '';
    TEFLogger.Instance.LogFmt(
      'ACL deny: user "%s" requested view "%s" mode %s',
      [LUser, AView.PersistentName, AMode], TEFLogger.LOG_DETAILED);
    if Assigned(TKWebResponse.Current) then
      TKWebResponse.Current.StatusCode := 404;
  end;
end;


function TKWebApplication.RequireDataView(const AView: TKView): Boolean;
begin
  Assert(Assigned(AView));
  Result := AView is TKDataView;
  if not Result and Assigned(TKWebResponse.Current) then
    TKWebResponse.Current.StatusCode := 404;
end;


procedure TKWebApplication.DisplayView(const AName: string);
begin
  Assert(AName <> '');

  DisplayView(Config.Views.ViewByName(AName));
end;


procedure TKWebApplication.DisplayView(const AView: TKView);
var
  LController: IKXController;
  LHtml: string;
begin
  Assert(Assigned(AView));

  if AView.IsAccessGranted(ACM_VIEW) then
  begin
    LController := TKXControllerFactory.Instance.CreateController(AView);
    LController.Display;
    LHtml := LController.Render;
    TKXWebResponse.Current.SendFragment(LHtml);
  end;
end;


class constructor TKWebApplication.Create;
begin
  TKConfig.OnGetInstance :=
    function: TKConfig
    begin
      if FCurrent <> nil then
        Result := FCurrent.Config
      else
        Result := nil;
    end;
  // Resolve the macro expansion engine from the per-thread current application
  // (FCurrent is a threadvar). Registered ONCE here, exactly like
  // TKConfig.OnGetInstance above, instead of being set/torn-down on every request
  // in ActivateInstance/DeactivateInstance. That per-request churn mutated a
  // process-global, reference-counted function reference and also triggered
  // FreeAndNil(FInstance) inside SetOnGetInstance on every call: under Indy's
  // worker-thread pool one request could free the closure / the engine while
  // another was using it in TEFMacroExpansionEngine.GetInstance -> intermittent
  // AV (surfaced e.g. while expanding %IMAGE% during the login region render).
  // Reading the threadvar FCurrent at call time is thread-safe; FCurrent=nil
  // falls back to the default engine.
  TEFMacroExpansionEngine.OnGetInstance :=
    function: TEFMacroExpansionEngine
    begin
      if FCurrent <> nil then
        Result := FCurrent.Config.MacroExpansionEngine
      else
        Result := nil;
    end;
end;

class procedure TKWebApplication.SetCurrent(const AValue: TKWebApplication);
begin
  FCurrent := AValue;
end;


procedure TKWebApplication.DownloadBytes(const ABytes: TBytes; const AFileName, AContentType: string; const AInline: Boolean);
begin
  DownloadStream(TBytesStream.Create(ABytes), AFileName, AContentType, AInline);
end;

procedure TKWebApplication.DownloadFile(const AServerFileName, AFileName, AContentType: string; const AInline: Boolean);
begin
  DownloadStream(TFileStream.Create(AServerFileName, fmOpenRead, fmShareDenyNone), AFileName, AContentType, AInline);
end;

procedure TKWebApplication.DownloadStream(const AStream: TStream; const AFileName, AContentType: string; const AInline: Boolean);
begin
  if Assigned(AStream) then
  begin
    TKWebResponse.Current.SetCustomHeader('Content-Disposition',
      Format('%s; filename="%s"', [IfThen(AInline, 'inline', 'attachment'), ExtractFileName(AFileName)]));
    TKWebResponse.Current.ReplaceContentStream(AStream);
    if AContentType <> '' then
      TKWebResponse.Current.ContentType := AContentType
    else
      TKWebResponse.Current.ContentType := GetFileMimeType(AFileName);
  end;
end;

{ TKWebApplication }

function TKWebApplication.IsPublicView(const AViewName: string): Boolean;
var
  LView: TKView;
begin
  Result := False;
  if AViewName = '' then
    Exit;
  LView := Config.Views.FindView(AViewName);
  Result := Assigned(LView) and (LView.GetACURI = '');
end;

procedure TKWebApplication.RenderErrorDialog(const AMessage: string;
  const AIsFatal: Boolean);
var
  LEncodedMsg: string;
  LOKAction: string;
  LOverlayClick: string;
begin
  if AIsFatal then
  begin
    SignalFatalError;
    // Fatal error: session will be destroyed, reload to go back to login.
    LOKAction := 'window.location.reload()';
    LOverlayClick := '';
  end
  else
  begin
    // Non-fatal: just dismiss the dialog.
    LOKAction := 'this.closest(''.kx-msgbox-overlay'').remove()';
    LOverlayClick := ' onclick="this.remove()"';
  end;
  LEncodedMsg := TNetEncoding.HTML.Encode(AMessage).Replace(sLineBreak, '<br/>');
  TKWebResponse.Current.Items.Clear;
  // Retarget the HTMX swap to body/beforeend so the dialog appears as a modal
  // overlay without replacing the current content.
  TKWebResponse.Current.SetCustomHeader('HX-Retarget', 'body');
  TKWebResponse.Current.SetCustomHeader('HX-Reswap', 'beforeend');
  TKWebResponse.Current.Items.AddHTML(
    '<div class="kx-msgbox-overlay"' + LOverlayClick + '>' +
      '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
        '<div class="kx-msgbox-header kx-msgbox-error">' +
          '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
          '<span>' + _('Error') + '</span>' +
        '</div>' +
        '<div class="kx-msgbox-body">' + LEncodedMsg + '</div>' +
        '<div class="kx-msgbox-footer">' +
          '<button onclick="' + LOKAction + '">OK</button>' +
        '</div>' +
      '</div>' +
    '</div>');
end;

function TKWebApplication.DoHandleRequest(const ARequest: TKWebRequest;
  const AResponse: TKWebResponse; const AURL: TKWebURL): Boolean;

  function IsHomeRequest: Boolean;
  begin
    Result := TKWebRequest.Current.IsPageRefresh(AURL.Document);
  end;

begin
  Assert(Assigned(ARequest));
  Assert(Assigned(AResponse));

  Result := False;
  TEFLogger.Instance.Log('DoHandleRequest: URL.Path="' + AURL.Path +
    '" URL.Document="' + AURL.Document + '" FPath="' + FPath + '"', TEFLogger.LOG_DEBUG);
  if StrMatchesEx(AURL.Path, FPath + '/*') then
  begin
    TEFLogger.Instance.Log('DoHandleRequest: path matched, activating instance', TEFLogger.LOG_DEBUG);
    ActivateInstance;
    try
      // Cross-cutting concerns (JWT hydration, session-lost + authentication
      // gate, error-to-dialog) are handled by the global request filter chain
      // (Kitto.Web.Routing.AppFilters), shared with the attribute-based pipeline.
      //
      // Every /kx/* endpoint is now attribute-routed and served BEFORE this
      // legacy dispatch: auth (login/resetpassword/changepassword/logout) via
      // TKXAuthHandler; the whole view domain (view/data/form/save/save-cache/
      // delete/enter-edit/form-close/lookup/wizard-finish/detail·data·save·
      // delete/tool/upload/notify/blob) via TKXViewHandlerBase; chart/calendar/
      // map via their enterprise handlers — each carrying its own gate context
      // (e.g. [TKXAnonymous] for auth, public-view exemption in the attribute
      // route). The ONLY request that still reaches here is Home (page refresh):
      // it is public and its session may legitimately be lost, so both gates
      // are waived exactly for it. Anything else under FPath is unmatched and
      // falls through to a 404 after the (fully authenticated) chain runs.
      var LChain: TKXFilterChain := TKXFilterChain.Create(TKXRequestContext.Create(
        AURL.Path, ARequest.Method,
        {AllowUnauthenticated} IsHomeRequest,
        {AllowSessionLost} IsHomeRequest));
      try
        LChain.RunBefore;
        if LChain.Context.Handled then
          Result := True
        else
        try
        if IsHomeRequest then
        begin
          TEFLogger.Instance.Log('DoHandleRequest: IsHomeRequest=True, calling Home', TEFLogger.LOG_DEBUG);
          Home;
          Result := True;
        end;
        // If not handled, let the route system continue (→ 404).
        except
          on E: Exception do
            // The error-handler filter turns the exception into a NON-FATAL
            // modal dialog (session stays alive); if no filter handled it, it
            // propagates. Matches the previous inline behaviour.
            if LChain.HandleException(E) then
              Result := True
            else
              raise;
        end;
      finally
        LChain.RunAfter;
        LChain.Free;
      end;
    finally
      DeactivateInstance;
    end;
  end
  else
    TEFLogger.Instance.Log('DoHandleRequest: path NOT matched. URL.Path="' +
      AURL.Path + '" expected="' + FPath + '/*"', TEFLogger.LOG_DEBUG);
end;

procedure TKWebApplication.DeclareDatabaseMacros(const AAuthData: TEFNode);
var
  LDatabaseName: string;
  LLabelNode: TEFNode;
  LEnvironment: string;
begin
  Assert(Assigned(AAuthData));
  // Raw config name of the active database (session override, then default).
  LDatabaseName := Config.DatabaseName;
  AAuthData.SetString('DatabaseName', LDatabaseName);

  // Environment = friendly DisplayLabel of the active database, or the raw
  // name when no label is configured. Matches the value shown in the login
  // combo so the StatusBar / dialog titles can display the same text.
  LLabelNode := Config.Config.FindNode(
    'Databases/' + LDatabaseName + '/DisplayLabel');
  if Assigned(LLabelNode) and (LLabelNode.AsExpandedString <> '') then
    LEnvironment := LLabelNode.AsExpandedString
  else
    LEnvironment := LDatabaseName;
  AAuthData.SetString('Environment', LEnvironment);
end;

// HandleKXChartDataRequest: migrated to Kitto.Web.Handler.Chart
// HandleKXMapDataRequest: migrated to Kitto.Web.Handler.Map
// HandleKXCalendarDataRequest: migrated to Kitto.Web.Handler.Calendar

procedure TKWebApplication.AdjustControllerForContext(const AController: IKXController);
var
  LPanel: TKXPanelControllerBase;
begin
  if AController.AsObject is TKXPanelControllerBase then
  begin
    LPanel := TKXPanelControllerBase(AController.AsObject);
    if TKWebSession.Current.IsMobileBrowser then
    begin
      // Mobile: every fragment view is modal and maximized (fullscreen).
      // Not called for the initial Home/Login page.
      // Width/Height getters return 0 when Maximized is True.
      LPanel.IsModal := True;
      LPanel.Maximized := True;
    end
    else if not LPanel.IsModal then
    begin
      // Desktop non-modal: inline in tab, clear fixed dimensions.
      LPanel.Width := 0;
      LPanel.Height := 0;
    end;
  end;
end;
// via body.kx-mobile selectors on .kx-dialog and .kx-dialog-overlay.

// Bodies of HandleKXChartDataRequest, HandleKXMapDataRequest, HandleKXCalendarDataRequest
// removed — migrated to Kitto.Web.Handler.Chart/Map/Calendar.

function TKWebApplication.BuildSortExpression(AViewTable: TKViewTable;
  const ASort, ADir: string): string;
var
  LFields, LDirs: TArray<string>;
  LViewField: TKViewField;
  I: Integer;
  LSB: TStringBuilder;
begin
  Result := '';
  if ASort = '' then Exit;
  LFields := ASort.Split([',']);
  LDirs := ADir.Split([',']);
  LSB := TStringBuilder.Create;
  try
    for I := 0 to High(LFields) do
    begin
      LViewField := AViewTable.FindField(LFields[I].Trim);
      if not Assigned(LViewField) then Continue; // invalid → drop (anti SQL injection)
      if LSB.Length > 0 then LSB.Append(', ');
      LSB.Append(LViewField.QualifiedDBNameOrExpression);
      if (I <= High(LDirs)) and SameText(LDirs[I].Trim, 'desc') then
        LSB.Append(' desc')
      else
        LSB.Append(' asc');
    end;
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

// HandleKXToolRequest, HandleKXTempUploadRequest, HandleKXNotifyChangeRequest,
// NotifyFieldChangeHandler, HandleKXBlobRequest migrated to TKXViewHandlerBase
// (Kitto.Web.Handler.View)

procedure TKWebApplication.PopulateRecordFieldFromPost(
  ARecord: TKViewTableRecord; AViewField: TKViewField; AIsInsert: Boolean);
var
  LFieldName, LPostValue, LDatePart, LTimePart: string;
begin
  if AIsInsert then
  begin
    if not AViewField.CanInsert then Exit;
  end
  else
  begin
    if AViewField.IsKey then Exit;
    if not AViewField.CanUpdate then Exit;
  end;
  if AViewField.IsBlob and not (AViewField.DataType is TEFMemoDataType) then
    Exit;
  // FileReference fields are handled by the dedicated file-save section, not here
  if AViewField.DataType is TKFileReferenceDataType then
    Exit;

  LFieldName := AViewField.FieldNamesForUpdate;

  // Handle DateTime split fields
  if AViewField.DataType is TEFDateTimeDataType then
  begin
    // Skip if neither half of the DateTime input is in POST: the field was
    // not rendered (e.g. IsVisible=False) and we must preserve the record's
    // current value (often computed by an AfterFieldChange rule during the
    // notify cycle).
    if not (TKWebRequest.Current.HasField(LFieldName + '__date') or
            TKWebRequest.Current.HasField(LFieldName + '__time')) then
      Exit;
    LDatePart := TKWebRequest.Current.GetField(LFieldName + '__date');
    LTimePart := TKWebRequest.Current.GetField(LFieldName + '__time');
    if (LDatePart = '') and (LTimePart = '') then
      // Both empty: set to null (allows clearing a DateTime field)
      ARecord.FieldByName(LFieldName).SetToNull(True)
    else if LDatePart <> '' then
    begin
      // Date present: combine with time (default 00:00 if time is empty)
      LPostValue := LDatePart;
      if LTimePart <> '' then
        LPostValue := LPostValue + ' ' + LTimePart;
      ARecord.FieldByName(LFieldName).Value :=
        AViewField.DataType.ValueToDateTime(LPostValue);
    end
    else
      // Only time without date: set to null (time alone is not valid)
      ARecord.FieldByName(LFieldName).SetToNull(True);
    Exit;
  end;

  // Skip fields not present in the POST: typically IsVisible=False fields
  // that the form doesn't render. Their record value (often computed by an
  // AfterFieldChange rule during the notify cycle) must be preserved, not
  // overwritten with null.
  if not TKWebRequest.Current.HasField(LFieldName) then
    Exit;

  LPostValue := TKWebRequest.Current.GetField(LFieldName);

  if AViewField.DataType is TEFBooleanDataType then
    ARecord.FieldByName(LFieldName).Value :=
      SameText(LPostValue, 'true') or SameText(LPostValue, '1')
  else if AViewField.DataType is TEFDateDataType then
  begin
    if LPostValue = '' then
      ARecord.FieldByName(LFieldName).SetToNull(True)
    else
      ARecord.FieldByName(LFieldName).Value :=
        AViewField.DataType.ValueToDate(LPostValue);
  end
  else if AViewField.DataType is TEFTimeDataType then
  begin
    if LPostValue = '' then
      ARecord.FieldByName(LFieldName).SetToNull(True)
    else
      ARecord.FieldByName(LFieldName).Value :=
        AViewField.DataType.ValueToTime(LPostValue);
  end
  else if AViewField.DataType is TEFIntegerDataType then
  begin
    if LPostValue = '' then
      ARecord.FieldByName(LFieldName).SetToNull(True)
    else
      ARecord.FieldByName(LFieldName).Value := StrToIntDef(LPostValue, 0);
  end
  else if AViewField.DataType is TEFDecimalNumericDataTypeBase then
  begin
    if LPostValue = '' then
      ARecord.FieldByName(LFieldName).SetToNull(True)
    else
    begin
      if (AViewField.DataType is TEFCurrencyDataType) and (FormatSettings.CurrencyString <> '') then
        LPostValue := Trim(ReplaceStr(LPostValue, FormatSettings.CurrencyString, ''));
      ARecord.FieldByName(LFieldName).Value :=
        StrToFloatDef(ReplaceStr(LPostValue, FormatSettings.DecimalSeparator, '.'), 0,
          TFormatSettings.Invariant);
    end;
  end
  else
  begin
    if LPostValue <> '' then
      ARecord.FieldByName(LFieldName).Value := LPostValue
    else if not AViewField.IsRequired then
      ARecord.FieldByName(LFieldName).SetToNull(not AIsInsert);
  end;
end;

procedure TKWebApplication.PopulateRecordFromPost(ARecord: TKViewTableRecord;
  AViewTable: TKViewTable; AIsInsert: Boolean);
var
  I, J: Integer;
  LViewField: TKViewField;
  LFieldName: string;
  LFiles: TAbstractWebRequestFiles;
begin
  // Disable change notifications during the bulk update — derived/joined data
  // for Reference fields was already refreshed by the per-field notify cycle,
  // there is no need to re-fire the cascade for every assignment here. Mirrors
  // Kitto1 TKExtDataPanelController.UpdateRecord (DisableChangeNotifications
  // wrapping the value-set loop).
  ARecord.Store.DoWithChangeNotificationsDisabled(
    procedure
    var
      LI: Integer;
    begin
      for LI := 0 to AViewTable.FieldCount - 1 do
        PopulateRecordFieldFromPost(ARecord, AViewTable.Fields[LI], AIsInsert);
    end);

  // The bulk set above runs with change notifications disabled, so the
  // FieldChanged cascade that resolves reference captions/AutoAddFields does
  // not fire. Refresh them explicitly here (only where the caption is still
  // empty), so reference descriptions show immediately for freshly-added
  // in-memory records — mirroring Kitto1's FieldChanged behavior.
  ARecord.RefreshDerivedReferenceValues;

  // Handle blob fields (IsPicture upload)
  LFiles := TKWebRequest.Current.Files;
  for I := 0 to AViewTable.FieldCount - 1 do
  begin
    LViewField := AViewTable.Fields[I];
    if not LViewField.IsBlob then Continue;
    if AIsInsert and not LViewField.CanInsert then Continue;
    if not AIsInsert and not LViewField.CanUpdate then Continue;
    LFieldName := LViewField.FieldNamesForUpdate;

    // Check for clear flag (edit mode)
    if not AIsInsert then
    begin
      var LClearFlag := TKWebRequest.Current.GetField(LFieldName + '__clear');
      if SameText(LClearFlag, '1') then
      begin
        ARecord.FieldByName(LFieldName).SetToNull(True);
        Continue;
      end;
    end;

    for J := 0 to LFiles.Count - 1 do
    begin
      if SameText(LFiles[J].FieldName, LFieldName) and
         (LFiles[J].Stream.Size > 0) then
      begin
        ARecord.FieldByName(LFieldName).LoadBytesFromStream(LFiles[J].Stream);
        Break;
      end;
    end;
  end;

  // Handle FileReference fields: save uploaded file to disk, store generated filename in DB.
  // The companion FileNameField (original filename) is carried as a hidden POST field
  // and updated automatically by the regular string field loop above.
  for I := 0 to AViewTable.FieldCount - 1 do
  begin
    LViewField := AViewTable.Fields[I];
    if not (LViewField.DataType is TKFileReferenceDataType) then Continue;
    if AIsInsert and not LViewField.CanInsert then Continue;
    if not AIsInsert and not LViewField.CanUpdate then Continue;
    LFieldName := LViewField.FieldNamesForUpdate;

    var LFinalPath := LViewField.GetExpandedString('Path');

    // Priority 1: temp file from AJAX pre-save upload
    var LTempName := TKWebRequest.Current.GetField(LFieldName + '__temp');
    if LTempName <> '' then
    begin
      var LTempDir := TPath.Combine(TPath.Combine(TPath.GetTempPath, 'kxupload'),
        TKWebSession.Current.SessionId);
      var LTempSrc := TPath.Combine(LTempDir, LTempName);
      if (LFinalPath <> '') and TFile.Exists(LTempSrc) then
      begin
        // Delete previous file (edit mode)
        if not AIsInsert then
        begin
          var LOldStored := ARecord.FieldByName(LFieldName).AsString;
          if LOldStored <> '' then
          begin
            var LOldFile := TPath.Combine(LFinalPath, LOldStored);
            if TFile.Exists(LOldFile) then TFile.Delete(LOldFile);
          end;
        end;
        ForceDirectories(LFinalPath);
        TFile.Move(LTempSrc, TPath.Combine(LFinalPath, LTempName));
        ARecord.FieldByName(LFieldName).AsString := LTempName;
      end;
      Continue;
    end;

    // Priority 2: clear flag
    if not AIsInsert then
    begin
      var LClearFlag := TKWebRequest.Current.GetField(LFieldName + '__clear');
      if SameText(LClearFlag, '1') then
      begin
        var LOldStored := ARecord.FieldByName(LFieldName).AsString;
        if (LOldStored <> '') and (LFinalPath <> '') then
        begin
          var LOldFile := TPath.Combine(LFinalPath, LOldStored);
          if TFile.Exists(LOldFile) then TFile.Delete(LOldFile);
        end;
        ARecord.FieldByName(LFieldName).SetToNull(True);
        Continue;
      end;
    end;

    // Priority 3: fallback — file uploaded directly with the form (non-AJAX)
    for J := 0 to LFiles.Count - 1 do
    begin
      if SameText(LFiles[J].FieldName, LFieldName) and (LFiles[J].Stream.Size > 0) then
      begin
        if LFinalPath <> '' then
        begin
          var LOrigName := LFiles[J].FileName;
          var LStoredName := CreateCompactGuidStr + ExtractFileExt(LOrigName);
          ForceDirectories(LFinalPath);
          var LDestStream := TFileStream.Create(
            TPath.Combine(LFinalPath, LStoredName), fmCreate or fmShareExclusive);
          try
            LFiles[J].Stream.Position := 0;
            LDestStream.CopyFrom(LFiles[J].Stream, 0);
          finally
            LDestStream.Free;
          end;
          ARecord.FieldByName(LFieldName).AsString := LStoredName;
        end;
        Break;
      end;
    end;
  end;
end;

// HandleKXWizardFinishRequest migrated to TKXViewHandlerBase (Kitto.Web.Handler.View)

function TKWebApplication.GetMethodURL(const AObjectName, AMethodName: string): string;
begin
  Result := FPath + '/' + TKWebRequest.APP_NAMESPACE + '/' + IfThen(AObjectName <> '',  AObjectName + '/', '') + AMethodName;
end;

procedure TKWebApplication.ActivateInstance;
begin
  // FCurrent is a threadvar; the macro-engine resolver (registered once in the
  // class constructor) reads it, so there is no per-request global to set here.
  FCurrent := Self;
  TKAuthenticator.Current := GetAuthenticator;
  TKAccessController.Current := GetAccessController;
end;

procedure TKWebApplication.DeactivateInstance;
begin
  FCurrent := nil;
  TKAuthenticator.Current := nil;
  TKAccessController.Current := nil;
end;


function TKWebApplication.Authenticate: Boolean;
var
  LAuthData: TEFNode;
  LUserName: string;
  LPassword: string;
  LAuthenticator: TKAuthenticator;
begin
  LAuthenticator := GetAuthenticator;

  if LAuthenticator.IsAuthenticated then
    Result := True
  else
  begin
    LAuthData := TEFNode.Create;
    try
      LAuthenticator.DefineAuthData(LAuthData);
      LUserName := TKWebRequest.Current.GetQueryField('UserName');
      if LUserName <> '' then
        LAuthData.SetString('UserName', LUserName);
      LPassword := TKWebRequest.Current.GetQueryField('Password');
      if LPassword <> '' then
        LAuthData.SetString('Password', LPassword);
      Result := LAuthenticator.Authenticate(LAuthData);
    finally
      LAuthData.Free;
    end;
  end;
end;

procedure TKWebApplication.ReloadOrDisplayHomeView;
var
  LNewLanguageId: string;
begin
  LNewLanguageId := TKWebRequest.Current.Language;
  if (LNewLanguageId <> '') and (LNewLanguageId <> TKWebSession.Current.Language) then
  begin
    TKWebSession.Current.RefreshingLanguage := True;
    TKWebSession.Current.Language := LNewLanguageId;
  end;
  // In KittoX, after login redirect to home for a full page refresh.
  TKWebResponse.Current.SetCustomHeader('HX-Redirect', FPath + '/');
end;

class destructor TKWebApplication.Destroy;
begin
  TKConfig.OnGetInstance := nil;
  TEFMacroExpansionEngine.OnGetInstance := nil;
end;

function TKWebApplication.RenderViewAsPage(const AView: TKView;
  const ADefaultControllerType: string): string;
var
  LController: IKXController;
begin
  // A login-style view may declare a Controller node with no type value (its
  // properties are children); fall back to ADefaultControllerType in that case,
  // same as the ExtJS version did.
  if (AView.ControllerType = '') and (ADefaultControllerType <> '') then
    LController := TKXControllerFactory.Instance.CreateController(AView, nil, nil, ADefaultControllerType)
  else
    LController := TKXControllerFactory.Instance.CreateController(AView);
  LController.Display;
  Result := LController.Render;
end;

procedure TKWebApplication.ServeViewAsPage(const AView: TKView;
  const ADefaultControllerType: string);
begin
  ServeHomePage(RenderViewAsPage(AView, ADefaultControllerType));
end;

procedure TKWebApplication.DisplayHomeView;
var
  LView: TKView;
  LBodyContent: string;
begin
  if TKAuthenticator.Current.MustChangePassword then
  begin
    LView := Config.Views.ViewByName('ChangePassword');
    TKWebSession.Current.AutoOpenViewName := '';
  end
  else
    LView := GetHomeView;

  LBodyContent := RenderViewAsPage(LView);

  if TKWebSession.Current.AutoOpenViewName <> '' then
  begin
    DisplayView(TKWebSession.Current.AutoOpenViewName);
    TKWebSession.Current.AutoOpenViewName := '';
  end;

  ServeHomePage(LBodyContent);
end;

procedure TKWebApplication.DisplayLoginView;
begin
  ServeViewAsPage(GetLoginView, 'Login');
end;

procedure TKWebApplication.Home;
var
  LAuthenticator: TKAuthenticator;
  LBodyContent: string;
  LView: TKView;
begin
  if TKWebRequest.Current.IsAjax then
    raise Exception.Create('Cannot call Home page in an Ajax request.');

  LAuthenticator := GetAuthenticator;
  if not TKWebSession.Current.RefreshingLanguage then
    LAuthenticator.Logout;

  TKWebSession.Current.HomeViewNodeName := TKWebRequest.Current.GetQueryField('home');
  DetectScreenSize;

  if not TKWebSession.Current.RefreshingLanguage then
    TKWebSession.Current.SetLanguageFromQueriesOrConfig(Config);

  TKWebSession.Current.AutoOpenViewName := TKWebRequest.Current.GetQueryField('view');

  // Try authentication with default credentials, if any, and skip login
  // window if it succeeds.
  if Authenticate then
  begin
    if TKAuthenticator.Current.MustChangePassword then
      LView := Config.Views.ViewByName('ChangePassword')
    else
      LView := GetHomeView;
  end
  else
    LView := GetLoginView;

  // LoginView may have Controller: with no type value (properties are children);
  // RenderViewAsPage falls back to the 'Login' controller type in that case.
  LBodyContent := RenderViewAsPage(LView, 'Login');

  TKWebSession.Current.RefreshingLanguage := False;
  ServeHomePage(LBodyContent);
end;


function TKWebApplication.GetAccessController: TKAccessController;
var
  LType: string;
  LConfig: TEFNode;
  I: Integer;
begin
  // Double-checked locking — the Indy thread pool can fan out the very first
  // wave of requests across multiple worker threads before the lazy field
  // settles, and an unguarded `if not Assigned(...)` would let two threads
  // both create an instance, with one becoming an orphaned leak.
  if Assigned(FAccessController) then
    Exit(FAccessController);
  TMonitor.Enter(Self);
  try
    if not Assigned(FAccessController) then
    begin
      LType := Config.Config.GetExpandedString('AccessControl', NODE_NULL_VALUE);
      FAccessController := TKAccessControllerFactory.Instance.CreateObject(LType);
      LConfig := Config.Config.FindNode('AccessControl');
      if Assigned(LConfig) then
      begin
        for I := 0 to LConfig.ChildCount - 1 do
          FAccessController.Config.AddChild(TEFNode.Clone(LConfig.Children[I]));
        FAccessController.Init;
      end;
    end;
    Result := FAccessController;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TKWebApplication.AuthorizeJWTRequest;
var
  LAuth: TKAuthenticator;
begin
  // Delegate to the active authenticator. Default TKAuthenticator.AuthorizeRequest
  // is a no-op; TKJWTAuthenticator overrides to validate the kx_token cookie,
  // hydrate session state from the verified claims, and slide expiration.
  // Other authenticators are free to plug in their own per-request logic
  // (Phase C OIDC/SAML descendants, custom token schemes, etc.) without this
  // unit having to know about them.
  LAuth := GetAuthenticator;
  if Assigned(LAuth) then
    LAuth.AuthorizeRequest;
end;

function TKWebApplication.GetAuthenticator: TKAuthenticator;
var
  LType: string;
  LConfig: TEFNode;
  I: Integer;
begin
  // See GetAccessController for the rationale; same race window, same fix.
  if Assigned(FAuthenticator) then
    Exit(FAuthenticator);
  TMonitor.Enter(Self);
  try
    if not Assigned(FAuthenticator) then
    begin
      LType := Config.Config.GetExpandedString('Auth', NODE_NULL_VALUE);
      FAuthenticator := TKAuthenticatorFactory.Instance.CreateObject(LType);
      LConfig := Config.Config.FindNode('Auth');
      if Assigned(LConfig) then
        for I := 0 to LConfig.ChildCount - 1 do
          FAuthenticator.Config.AddChild(TEFNode.Clone(LConfig.Children[I]));
    end;
    Result := FAuthenticator;
  finally
    TMonitor.Exit(Self);
  end;
end;

class function TKWebApplication.GetCurrent: TKWebApplication;
begin
  Result := FCurrent;
end;


function TKWebApplication.TooltipsEnabled: Boolean;
begin
  Result := not TKWebRequest.Current.IsMobileBrowser;
end;

procedure TKWebApplication.UpdateObserver(const ASubject: IEFSubject; const AContext: string);
begin
  inherited;
  if SameText(AContext, 'LoggedIn') then
    ReloadOrDisplayHomeView;
end;

// NOTE: the former unit-level IsCssColorLight() and the inline theme-CSS
// generation have been moved into TKThemeConfig (Kitto.Metadata.SubNodes),
// so all theme reading/CSS lives behind the decorated Theme config class.

procedure TKWebApplication.ServeHomePage(const ABodyContent: string);
var
  LPageHtml: string;
  LTemplatePath: string;
  LIconLink: string;
  LAppleIconLink: string;
  LManifestLink: string;
  LLoadingImageURL: string;
  LThemeNode: TEFNode;
  LThemeAttr: string;
  LThemeStyle: string;
  LThemeBoot: string;
begin
  // All theme reading + CSS generation is encapsulated in TKThemeConfig
  // (Kitto.Metadata.SubNodes), so the Theme node is managed by the same
  // decorated config-class pattern KIDEX discovers via RTTI. Here we just
  // delegate. Icon style/size are applied server-side (they don't switch live).
  LThemeNode := Config.Config.FindNode('Theme');
  SetIconStyle(TKThemeConfig.ResolveIconStyle(LThemeNode));
  SetDefaultIconSize(TKThemeConfig.ResolveIconSize(LThemeNode));
  LThemeAttr  := TKThemeConfig.DataThemeAttr(LThemeNode);
  LThemeBoot  := TKThemeConfig.BuildBootScript(LThemeNode, TKConfig.AppName);
  LThemeStyle := TKThemeConfig.BuildStyleBlock(LThemeNode);

  if Config.AppIcon <> '' then
  begin
    LIconLink := '<link rel="shortcut icon" href="' + GetImageURL(Config.AppIcon) + '"/>';
    LAppleIconLink := '<link rel="apple-touch-icon" sizes="120x120" href="' + GetImageURL(Config.AppIcon) + '"/>';
  end
  else
  begin
    LIconLink := '';
    LAppleIconLink := '';
  end;

  LManifestLink := '';
  if GetManifestFileName <> '' then
    LManifestLink := Format('<link rel="manifest" href="%s"/>', [GetManifestFileName]);

  LLoadingImageURL := FindImageURL('loading.gif');

  LTemplatePath := TKXTemplateEngine.Instance.FindTemplatePath('', '_Page');
  if LTemplatePath <> '' then
  begin
    LPageHtml := TKXTemplateEngine.Instance.Render(LTemplatePath,
      procedure(ATemplate: ITProCompiledTemplate)
      begin
        ATemplate.SetData('lang', TValue.From<string>(TKWebSession.Current.Language));
        ATemplate.SetData('charset', TValue.From<string>('utf-8'));
        if TKWebSession.Current.IsMobileBrowser then
          ATemplate.SetData('bodyClass', TValue.From<string>('kx-mobile'))
        else
          ATemplate.SetData('bodyClass', TValue.From<string>(''));
        ATemplate.SetData('appTitle', TValue.From<string>(_(Config.AppTitle)));
        ATemplate.SetData('iconLink', TValue.From<string>(LIconLink));
        ATemplate.SetData('appleIconLink', TValue.From<string>(LAppleIconLink));
        ATemplate.SetData('manifestLink', TValue.From<string>(LManifestLink));
        ATemplate.SetData('resPath', TValue.From<string>(FResourcePath));
        ATemplate.SetData('loadingImageURL', TValue.From<string>(LLoadingImageURL));
        ATemplate.SetData('loadingMessage', TValue.From<string>(Format(_('Loading %s...'), [Config.AppTitle])));
        ATemplate.SetData('themeAttr', TValue.From<string>(LThemeAttr));
        ATemplate.SetData('themeBoot', TValue.From<string>(LThemeBoot));
        ATemplate.SetData('themeStyle', TValue.From<string>(LThemeStyle));
        ATemplate.SetData('homeContent', TValue.From<string>(ABodyContent));
        ATemplate.SetData('ajaxTimeout', TValue.From<string>(
          IntToStr(Config.Config.GetInteger('AjaxTimeout', 100000))));
        ATemplate.SetData('msgErrorTitle', TValue.From<string>(_('Error')));
        ATemplate.SetData('msgTimeout', TValue.From<string>(_('Server is not responding')));
        ATemplate.SetData('btnRetry', TValue.From<string>(_('Retry')));
        ATemplate.SetData('btnReset', TValue.From<string>(_('Reset')));
        ATemplate.SetData('msgDataSaved', TValue.From<string>(_('Data saved')));
        ATemplate.SetData('msgDataDeleted', TValue.From<string>(_('Data deleted')));
        ATemplate.SetData('msgServerError', TValue.From<string>(_('Server error')));
        ATemplate.SetData('msgNotFound', TValue.From<string>(_('Resource not found')));
        ATemplate.SetData('msgInternalError', TValue.From<string>(_('Internal server error')));
        // Dynamic scripts/stylesheets registered by modules
        ATemplate.SetData('dynamicStyles', TValue.From<string>(
          TKXScriptRegistry.Instance.GetStylesheetTags(FResourcePath)));
        ATemplate.SetData('dynamicScripts', TValue.From<string>(
          TKXScriptRegistry.Instance.GetScriptTags(FResourcePath)));
      end);
  end
  else
    raise Exception.Create('Page template _Page.html not found. ' +
      'Ensure Home/Templates/_Page.html exists in the framework or application folder.');

  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(LPageHtml);
end;


function TKWebApplication.GetManifestFileName: string;
var
  LManifestFile, LURL: string;
begin
  LManifestFile := GetHomeView.GetString('MobileSettings/Android/Manifest', 'Manifest.json');
  LURL := FindResourceURL(LManifestFile);
  if LURL <> '' then
    Result := LURL
  else
    Result := '';
end;

procedure TKWebApplication.Toast(const AMessage: string);
var
  LSafeMessage: string;
begin
  // In KittoX, toast notifications are triggered via HTMX event headers.
  LSafeMessage := ReplaceStr(ReplaceStr(AMessage, '\', '\\'), '"', '\"');
  TKWebResponse.Current.SetCustomHeader('HX-Trigger', '{"showToast": "' + LSafeMessage + '"}');
end;

procedure TKWebApplication.Navigate(const AURL: string);
begin
  // In KittoX, navigation is handled via HTMX redirect header.
  TKWebResponse.Current.SetCustomHeader('HX-Redirect', AURL);
end;

procedure TKWebApplication.Logout;
begin
  GetAuthenticator.Logout;
  Reload;
end;

procedure TKWebApplication.Reload;
begin
  // HTMX evaluates <script> tags in swapped content (allowScriptTags = true).
  // We use this to trigger a full page reload from the client side.
  // Note: SetCustomHeader('HX-Refresh', 'true') does not work due to
  // WebBroker formatting headers as Name=Value instead of Name: Value.
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(
    '<script>window.location.reload();</script>');
end;

function TKWebApplication.FindResourcePathName(const AResourceFileName: string): string;
begin
  Result := Config.FindResourcePathName(AResourceFileName);
end;

function TKWebApplication.GetResourcePathName(const AResourceFileName: string): string;
begin
  Result := FindResourcePathName(AResourceFileName);
  if Result = '' then
    raise EKError.CreateFmt(_('Resource %s not found.'), [AResourceFileName]);
end;

function TKWebApplication.FindResourceURL(const AResourceFileName: string): string;
begin
  if FindResourcePathName(AResourceFileName) = '' then
    // File not found: no URL.
    Result := ''
  else
    Result := FResourcePath + '/' + StripPrefix(AResourceFileName, PathDelim).Replace(PathDelim, '/');
end;

function TKWebApplication.GetResourceURL(const AResourceFileName: string): string;
begin
  Result := FindResourceURL(AResourceFileName);
  if Result = '' then
    raise EKError.CreateFmt(_('Resource %s not found.'), [AResourceFileName]);
end;

function TKWebApplication.GetImagePathName(const AResourceName, ASuffix: string): string;
begin
  Result := GetResourcePathName(AdaptImageName(AResourceName, ASuffix));
end;

function TKWebApplication.GetImageURL(const AResourceName: string; const ASuffix: string = ''): string;
begin
  Result := GetResourceURL(AdaptImageName(AResourceName, ASuffix));
end;

function TKWebApplication.FindImagePathName(const AResourceName: string; const ASuffix: string = ''): string;
begin
  Result := FindResourcePathName(AdaptImageName(AResourceName, ASuffix));
end;

function TKWebApplication.FindImageURL(const AResourceName, ASuffix: string): string;
begin
  Result := FindResourceURL(AdaptImageName(AResourceName, ASuffix));
end;

class function TKWebApplication.AdaptImageName(const AResourceName: string; const ASuffix: string = ''): string;

  function HasSize(const AName: string): Boolean;
  begin
    Result := EndsStr('_16', AName) or EndsStr('_24', AName)
      or EndsStr('_32', AName) or EndsStr('_48', AName);
  end;

begin
  Result := AResourceName;
  if HasSize(Result) then
    Insert(ASuffix, Result, Length(Result) - 2)
  else
    Result := Result + ASuffix;
  if not Result.Contains('.') then
    Result := Result + '.png';
end;

end.
