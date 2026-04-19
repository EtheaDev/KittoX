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
    function HandleKXViewRequest(const AViewName: string): Boolean;
    function HandleKXDataRequest(const AViewName: string): Boolean;
    function HandleKXDeleteRequest(const AViewName: string): Boolean;
    function HandleKXToolRequest(const AViewName, AToolName: string): Boolean;
    function HandleKXLoginRequest: Boolean;
    function HandleKXResetPasswordRequest: Boolean;
    function HandleKXChangePasswordRequest: Boolean;
    function HandleKXFormRequest(const AViewName: string): Boolean;
    function HandleKXLookupRequest(const AViewName: string): Boolean;
    function HandleKXSaveRequest(const AViewName: string): Boolean;
    function HandleKXWizardFinishRequest(const AViewName: string): Boolean;
    function HandleKXSaveCacheRequest(const AViewName: string): Boolean;
    function HandleKXBlobRequest(const AViewName, AFieldName: string): Boolean;
    function HandleKXTempUploadRequest(const AViewName, AFieldName: string): Boolean;
    function HandleKXDetailDataRequest(const AViewName: string;
      ADetailIndex: Integer): Boolean;
    function HandleKXDetailSaveRequest(const AViewName: string;
      ADetailIndex: Integer): Boolean;
    function HandleKXDetailDeleteRequest(const AViewName: string;
      ADetailIndex: Integer): Boolean;
    /// <summary>
    ///  Populates a record's field values from the current POST data.
    ///  Shared by HandleKXSaveRequest, HandleKXDetailSaveRequest, HandleKXWizardFinishRequest.
    /// </summary>
    procedure PopulateRecordFromPost(ARecord: TKViewTableRecord;
      AViewTable: TKViewTable; AIsInsert: Boolean);
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
    procedure DeactivateInstance;

    procedure UpdateObserver(const ASubject: IEFSubject; const AContext: string = ''); override;
    procedure AddedTo(const AList: TKWebRouteList; const AIndex: Integer); override;

    property Config: TKConfig read FConfig;
    procedure ReloadConfig;

    function GetHomeView: TKView;
    procedure DisplayView(const AName: string); overload;
    procedure DisplayView(const AView: TKView); overload;
    function FindPageTemplate(const APageName: string): string;
    function GetPageTemplate(const APageName: string): string;
    property Path: string read FPath;

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

    function GetImageURL(const AResourceName: string; const ASuffix: string = ''): string;
    function FindImageURL(const AResourceName: string; const ASuffix: string = ''): string;

    function GetImagePathName(const AResourceName: string; const ASuffix: string = ''): string;
    function FindImagePathName(const AResourceName: string; const ASuffix: string = ''): string;

    procedure ReloadOrDisplayHomeView;
    function GetLoginView: TKView;
    procedure DisplayHomeView;
    procedure DisplayLoginView;
    procedure Toast(const AMessage: string);
    procedure Navigate(const AURL: string);

    procedure DownloadFile(const AServerFileName, AFileName: string; const AContentType: string = ''; const AInline: Boolean = True);
    procedure DownloadStream(const AStream: TStream; const AFileName: string; const AContentType: string = ''; const AInline: Boolean = True);
    procedure DownloadBytes(const ABytes: TBytes; const AFileName: string; const AContentType: string = ''; const AInline: Boolean = True);
    /// <summary>
    ///  Checks user credentials (fetched from Query parameters UserName and Passwords)
    ///  and returns True if the current authenticator allows them, or if the
    ///  user was already authenticated in this session.
    /// </summary>
    function Authenticate: Boolean;


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
  Kitto.Html.Form,
  Kitto.Store,
  Kitto.Html.Utils,
  Kitto.Html.Panel,
  Kitto.Html.FormController,
  Kitto.Html.Wizard,
  Kitto.Rules.Wizard,
  Kitto.Html.GroupingList,
  Kitto.Html.TemplateDataPanel,
  EF.Sys,
  EF.DB,
  EF.SQL,
  Kitto.SQL,
  Kitto.Web.Routing.Route,
  Kitto.Web.Routing.Scripts,
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

function TKWebApplication.DoHandleRequest(const ARequest: TKWebRequest;
  const AResponse: TKWebResponse; const AURL: TKWebURL): Boolean;
var
  LKXViewName: string;
  LKXToolName: string;
  LKXBlobFieldName: string;
  LKXDetailIndex: Integer;

  function IsHomeRequest: Boolean;
  begin
    Result := TKWebRequest.Current.IsPageRefresh(AURL.Document);
  end;

  function IsKXDataRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/data';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

  function IsKXDeleteRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/delete';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

  function IsKXToolRequest(out AViewName, AToolName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LRest: string;
    LToolPos: Integer;
  begin
    Result := False;
    AViewName := '';
    AToolName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    if not StartsText(LPrefix, LFullPath) then
      Exit;
    LRest := Copy(LFullPath, Length(LPrefix) + 1, MaxInt);
    // LRest should be like: ViewName/tool/ToolName
    LToolPos := Pos('/tool/', LRest);
    if LToolPos = 0 then
      Exit;
    AViewName := Copy(LRest, 1, LToolPos - 1);
    AToolName := Copy(LRest, LToolPos + 6, MaxInt); // 6 = Length('/tool/')
    if (AToolName <> '') and (AToolName[Length(AToolName)] = '/') then
      AToolName := Copy(AToolName, 1, Length(AToolName) - 1);
    Result := (AViewName <> '') and (AToolName <> '');
  end;

// Form request matcher — kx/view/{ViewName}/form
  function IsKXFormRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/form';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

// Lookup request matcher — kx/view/{ViewName}/lookup
  function IsKXLookupRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/lookup';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

// Save request matcher — kx/view/{ViewName}/save
  function IsKXSaveRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/save';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

// Form close request matcher — kx/view/{ViewName}/form-close
  function IsKXFormCloseRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/form-close';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

// Enter-edit request matcher — kx/view/{ViewName}/enter-edit
  function IsKXEnterEditRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/enter-edit';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

// Save cache request matcher — kx/view/{ViewName}/save-cache
  function IsKXSaveCacheRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/save-cache';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

// Chart data request matcher — kx/view/{ViewName}/chart-data
  function IsKXChartDataRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/chart-data';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

// Calendar data request matcher — kx/view/{ViewName}/calendar-data
  function IsKXCalendarDataRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/calendar-data';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

// Map data request matcher — kx/view/{ViewName}/map-data
  function IsKXMapDataRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/map-data';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

// Wizard finish request matcher — kx/view/{ViewName}/wizard-finish
  function IsKXWizardFinishRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LSuffix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    LSuffix := '/wizard-finish';
    if StartsText(LPrefix, LFullPath) and EndsText(LSuffix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1,
        Length(LFullPath) - Length(LPrefix) - Length(LSuffix));
      Result := AViewName <> '';
    end;
  end;

// Blob serve request matcher — kx/view/{ViewName}/blob/{FieldName}
  function IsKXBlobRequest(out AViewName, AFieldName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LBlobPrefix: string;
    LRest: string;
    LSlashPos: Integer;
  begin
    Result := False;
    AViewName := '';
    AFieldName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    if not StartsText(LPrefix, LFullPath) then
      Exit;
    LRest := Copy(LFullPath, Length(LPrefix) + 1, MaxInt);
    // LRest = '{ViewName}/blob/{FieldName}'
    LBlobPrefix := '/blob/';
    LSlashPos := Pos(LBlobPrefix, LRest);
    if LSlashPos <= 0 then
      Exit;
    AViewName := Copy(LRest, 1, LSlashPos - 1);
    AFieldName := Copy(LRest, LSlashPos + Length(LBlobPrefix), MaxInt);
    // Strip trailing slash if present
    if (AFieldName <> '') and (AFieldName[Length(AFieldName)] = '/') then
      AFieldName := Copy(AFieldName, 1, Length(AFieldName) - 1);
    Result := (AViewName <> '') and (AFieldName <> '');
  end;

// Temp upload request matcher — POST kx/view/{ViewName}/upload/{FieldName}
  function IsKXTempUploadRequest(out AViewName, AFieldName: string): Boolean;
  var
    LFullPath, LPrefix, LRest: string;
    LSlashPos: Integer;
  begin
    Result := False;
    AViewName := '';
    AFieldName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    if not StartsText(LPrefix, LFullPath) then Exit;
    LRest := Copy(LFullPath, Length(LPrefix) + 1, MaxInt);
    LSlashPos := Pos('/upload/', LRest);
    if LSlashPos <= 0 then Exit;
    AViewName := Copy(LRest, 1, LSlashPos - 1);
    AFieldName := Copy(LRest, LSlashPos + 8, MaxInt); // 8 = Length('/upload/')
    if (AFieldName <> '') and (AFieldName[Length(AFieldName)] = '/') then
      AFieldName := Copy(AFieldName, 1, Length(AFieldName) - 1);
    Result := (AViewName <> '') and (AFieldName <> '');
  end;

// Detail data request matcher — kx/view/{ViewName}/detail/{Index}/data
  function IsKXDetailDataRequest(out AViewName: string; out ADetailIndex: Integer): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
    LRest: string;
    LDetailPrefix: string;
    LDetailPos, LDataPos: Integer;
    LIndexStr: string;
  begin
    Result := False;
    AViewName := '';
    ADetailIndex := -1;
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    if not StartsText(LPrefix, LFullPath) then
      Exit;
    LRest := Copy(LFullPath, Length(LPrefix) + 1, MaxInt);
    // LRest = '{ViewName}/detail/{Index}/data'
    LDetailPrefix := '/detail/';
    LDetailPos := Pos(LDetailPrefix, LRest);
    if LDetailPos <= 0 then
      Exit;
    AViewName := Copy(LRest, 1, LDetailPos - 1);
    LRest := Copy(LRest, LDetailPos + Length(LDetailPrefix), MaxInt);
    // LRest = '{Index}/data'
    LDataPos := Pos('/data', LRest);
    if LDataPos <= 0 then
      Exit;
    LIndexStr := Copy(LRest, 1, LDataPos - 1);
    ADetailIndex := StrToIntDef(LIndexStr, -1);
    Result := (AViewName <> '') and (ADetailIndex >= 0);
  end;

  // Detail save request matcher — kx/view/{ViewName}/detail/{Index}/save
  function IsKXDetailSaveRequest(out AViewName: string; out ADetailIndex: Integer): Boolean;
  var
    LFullPath, LPrefix, LRest, LDetailPrefix, LIndexStr: string;
    LDetailPos, LSavePos: Integer;
  begin
    Result := False;
    AViewName := '';
    ADetailIndex := -1;
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    if not StartsText(LPrefix, LFullPath) then Exit;
    LRest := Copy(LFullPath, Length(LPrefix) + 1, MaxInt);
    LDetailPrefix := '/detail/';
    LDetailPos := Pos(LDetailPrefix, LRest);
    if LDetailPos <= 0 then Exit;
    AViewName := Copy(LRest, 1, LDetailPos - 1);
    LRest := Copy(LRest, LDetailPos + Length(LDetailPrefix), MaxInt);
    LSavePos := Pos('/save', LRest);
    if LSavePos <= 0 then Exit;
    LIndexStr := Copy(LRest, 1, LSavePos - 1);
    ADetailIndex := StrToIntDef(LIndexStr, -1);
    Result := (AViewName <> '') and (ADetailIndex >= 0);
  end;

  // Detail delete request matcher — kx/view/{ViewName}/detail/{Index}/delete
  function IsKXDetailDeleteRequest(out AViewName: string; out ADetailIndex: Integer): Boolean;
  var
    LFullPath, LPrefix, LRest, LDetailPrefix, LIndexStr: string;
    LDetailPos, LDeletePos: Integer;
  begin
    Result := False;
    AViewName := '';
    ADetailIndex := -1;
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    if not StartsText(LPrefix, LFullPath) then Exit;
    LRest := Copy(LFullPath, Length(LPrefix) + 1, MaxInt);
    LDetailPrefix := '/detail/';
    LDetailPos := Pos(LDetailPrefix, LRest);
    if LDetailPos <= 0 then Exit;
    AViewName := Copy(LRest, 1, LDetailPos - 1);
    LRest := Copy(LRest, LDetailPos + Length(LDetailPrefix), MaxInt);
    LDeletePos := Pos('/delete', LRest);
    if LDeletePos <= 0 then Exit;
    LIndexStr := Copy(LRest, 1, LDeletePos - 1);
    ADetailIndex := StrToIntDef(LIndexStr, -1);
    Result := (AViewName <> '') and (ADetailIndex >= 0);
  end;

  function IsKXViewRequest(out AViewName: string): Boolean;
  var
    LFullPath: string;
    LPrefix: string;
  begin
    Result := False;
    AViewName := '';
    LFullPath := AURL.Path + AURL.Document;
    LPrefix := FPath + '/kx/view/';
    if StartsText(LPrefix, LFullPath) then
    begin
      AViewName := Copy(LFullPath, Length(LPrefix) + 1, MaxInt);
      if (AViewName <> '') and (AViewName[Length(AViewName)] = '/') then
        AViewName := Copy(AViewName, 1, Length(AViewName) - 1);
      Result := AViewName <> '';
    end;
  end;

  function IsKXLoginRequest: Boolean;
  begin
    Result := StartsText(FPath + '/kx/login', AURL.Path + AURL.Document);
  end;

  function IsKXResetPasswordRequest: Boolean;
  begin
    Result := StartsText(FPath + '/kx/resetpassword', AURL.Path + AURL.Document);
  end;

  function IsKXChangePasswordRequest: Boolean;
  begin
    Result := StartsText(FPath + '/kx/changepassword', AURL.Path + AURL.Document);
  end;

  procedure Error(const AMessage: string; const AIsFatal: Boolean);
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
    // Retarget the HTMX swap to body/beforeend so the dialog
    // appears as a modal overlay without replacing the current content.
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
      try
        // Session lost after server restart: raise so the except block
        // shows a fatal error dialog with reload.
        // Home requests pass through: the normal flow shows the login page.
        if TKWebSession.Current.IsSessionLost and not IsHomeRequest then
          raise Exception.Create(_('Session lost or expired, please restart!'));
        if IsHomeRequest then
        begin
          TEFLogger.Instance.Log('DoHandleRequest: IsHomeRequest=True, calling Home', TEFLogger.LOG_DEBUG);
          Home;
          Result := True;
        end
        else if IsKXLoginRequest then
        begin
          Result := HandleKXLoginRequest;
        end
        else if IsKXResetPasswordRequest then
        begin
          Result := HandleKXResetPasswordRequest;
        end
        else if IsKXChangePasswordRequest then
        begin
          Result := HandleKXChangePasswordRequest;
        end
        else if IsKXToolRequest(LKXViewName, LKXToolName) then
        begin
          Result := HandleKXToolRequest(LKXViewName, LKXToolName);
        end
        else if IsKXLookupRequest(LKXViewName) then
        begin
          Result := HandleKXLookupRequest(LKXViewName);
        end
        else if IsKXTempUploadRequest(LKXViewName, LKXBlobFieldName) then
        begin
          Result := HandleKXTempUploadRequest(LKXViewName, LKXBlobFieldName);
        end
        else if IsKXBlobRequest(LKXViewName, LKXBlobFieldName) then
        begin
          Result := HandleKXBlobRequest(LKXViewName, LKXBlobFieldName);
        end
        else if IsKXFormRequest(LKXViewName) then
        begin
          Result := HandleKXFormRequest(LKXViewName);
        end
        // Detail endpoints must be checked BEFORE generic /save and /delete
        // because URLs like /detail/0/save and /detail/0/delete also end
        // with /save and /delete respectively.
        else if IsKXDetailSaveRequest(LKXViewName, LKXDetailIndex) then
        begin
          Result := HandleKXDetailSaveRequest(LKXViewName, LKXDetailIndex);
        end
        else if IsKXDetailDeleteRequest(LKXViewName, LKXDetailIndex) then
        begin
          Result := HandleKXDetailDeleteRequest(LKXViewName, LKXDetailIndex);
        end
        else if IsKXDetailDataRequest(LKXViewName, LKXDetailIndex) then
        begin
          Result := HandleKXDetailDataRequest(LKXViewName, LKXDetailIndex);
        end
        else if IsKXDeleteRequest(LKXViewName) then
        begin
          Result := HandleKXDeleteRequest(LKXViewName);
        end
        else if IsKXSaveRequest(LKXViewName) then
        begin
          Result := HandleKXSaveRequest(LKXViewName);
        end
        else if IsKXEnterEditRequest(LKXViewName) then
        begin
          // Apply edit-record rules when transitioning from ViewMode to EditMode.
          // The client calls this before enabling the form fields.
          var LEnterEditStore := TKWebSession.Current.FindStore(LKXViewName);
          if Assigned(LEnterEditStore) and (LEnterEditStore.RecordCount > 0) then
            LEnterEditStore.Records[0].ApplyEditRecordRules;
          TKXWebResponse.Current.SendFragment('');
          Result := True;
        end
        else if IsKXFormCloseRequest(LKXViewName) then
        begin
          // Release session store when form is cancelled/closed without saving
          TKWebSession.Current.UnregisterStore(LKXViewName);
          TKXWebResponse.Current.SendFragment('');
          Result := True;
        end
        else if IsKXSaveCacheRequest(LKXViewName) then
        begin
          Result := HandleKXSaveCacheRequest(LKXViewName);
        end
        // Chart/Calendar/Map: migrated to Kitto.Web.Handler.Chart/Calendar/Map
        else if IsKXWizardFinishRequest(LKXViewName) then
        begin
          Result := HandleKXWizardFinishRequest(LKXViewName);
        end
        else if IsKXDataRequest(LKXViewName) then
        begin
          Result := HandleKXDataRequest(LKXViewName);
        end
        else if IsKXViewRequest(LKXViewName) then
        begin
          Result := HandleKXViewRequest(LKXViewName);
        end;
        // If not handled, let the route system continue.
      except
        on E: Exception do
        begin
          // Every exception bubbling out of a request handler is displayed
          // as a NON-FATAL modal dialog so the session stays alive and the
          // user can fix the input and retry (e.g. an invalid date in a
          // filter that reached SQL Server). E.Message is used because, for
          // EEFDBError, it already contains the fully-formatted
          // "Errore <sql-error> nella query: {GUID}" wrapping built in
          // EEFDBError.CreateForQuery (see EF.DB.pas). The "Load error:"
          // prefix identifies the origin of the failure to the end user.
          Error(_('Load error:') + ' ' + E.Message, False);
          Result := True;
        end;
      end;
    finally
      DeactivateInstance;
    end;
  end
  else
    TEFLogger.Instance.Log('DoHandleRequest: path NOT matched. URL.Path="' +
      AURL.Path + '" expected="' + FPath + '/*"', TEFLogger.LOG_DEBUG);
end;

function TKWebApplication.HandleKXLoginRequest: Boolean;
var
  LAuthData: TEFNode;
  LAuthenticator: TKAuthenticator;
  LUserName, LPassword, LLanguage: string;
begin
  Result := True;
  LAuthenticator := GetAuthenticator;

  // Read data from POST form body (application/x-www-form-urlencoded)
  LUserName := TKWebRequest.Current.GetField('UserName');
  LPassword := TKWebRequest.Current.GetField('Password');
  LLanguage := TKWebRequest.Current.GetField('Language');

  if LLanguage <> '' then
  begin
    TKWebSession.Current.RefreshingLanguage := True;
    TKWebSession.Current.Language := LLanguage;
  end;

  LAuthData := TEFNode.Create;
  try
    LAuthenticator.DefineAuthData(LAuthData);
    if LUserName <> '' then
      LAuthData.SetString('UserName', LUserName);
    if LPassword <> '' then
      LAuthData.SetString('Password', LPassword);

    if LAuthenticator.Authenticate(LAuthData) then
    begin
      // Prevent Home from calling Logout on the next request (the redirect).
      // RefreshingLanguage=True causes Home to skip Logout, preserving the auth state.
      TKWebSession.Current.RefreshingLanguage := True;
      // Login succeeded: return a hidden marker element with the redirect URL.
      // The login form's JavaScript detects this element after HTMX swap,
      // saves localStorage data, and performs the redirect.
      // (We don't use HX-Redirect header because WebBroker's SetCustomHeader
      // formats headers as Name=Value instead of Name: Value.)
      TKWebResponse.Current.Items.Clear;
      TKWebResponse.Current.Items.AddHTML(
        '<div id="kx-login-success" data-redirect="' + FPath + '/" style="display:none"></div>');
    end
    else
    begin
      // Login failed: return HTML fragment with error message
      TKWebResponse.Current.Items.Clear;
      TKWebResponse.Current.Items.AddHTML(
        '<div class="kx-login-error">' +
          TNetEncoding.HTML.Encode(_('Invalid login.')) +
        '</div>');
    end;
  finally
    LAuthData.Free;
  end;
end;

function TKWebApplication.HandleKXResetPasswordRequest: Boolean;
var
  LParams: TEFNode;
  LAuthenticator: TKAuthenticator;
  LUserName, LEmailAddress: string;
begin
  Result := True;
  LAuthenticator := GetAuthenticator;

  LUserName := TKWebRequest.Current.GetField('UserName');
  LEmailAddress := TKWebRequest.Current.GetField('EmailAddress');

  LParams := TEFNode.Create;
  try
    LParams.SetString('UserName', LUserName);
    LParams.SetString('EmailAddress', LEmailAddress);
    try
      LAuthenticator.ResetPassword(LParams);
      // Show info dialog; OK button also closes the ResetPassword overlay behind it.
      TKWebResponse.Current.Items.Clear;
      TKWebResponse.Current.SetCustomHeader('HX-Retarget', 'body');
      TKWebResponse.Current.SetCustomHeader('HX-Reswap', 'beforeend');
      TKWebResponse.Current.Items.AddHTML(
        '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
          '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
            '<div class="kx-msgbox-header kx-msgbox-info">' +
              '<div class="kx-msgbox-icon kx-msgbox-icon-info"></div>' +
              '<span>' + _('Reset Password') + '</span>' +
            '</div>' +
            '<div class="kx-msgbox-body">' +
              TNetEncoding.HTML.Encode(
                _('A new temporary password was generated and sent to the specified e-mail address.')) +
            '</div>' +
            '<div class="kx-msgbox-footer">' +
              '<button onclick="' +
                'var dlg=document.querySelector(''.kx-dialog-overlay'');' +
                'if(dlg)dlg.remove();' +
                'this.closest(''.kx-msgbox-overlay'').remove();">OK</button>' +
            '</div>' +
          '</div>' +
        '</div>');
    except
      on E: Exception do
      begin
        // Show error dialog (same pattern as global Error handler).
        TKWebResponse.Current.Items.Clear;
        TKWebResponse.Current.SetCustomHeader('HX-Retarget', 'body');
        TKWebResponse.Current.SetCustomHeader('HX-Reswap', 'beforeend');
        TKWebResponse.Current.Items.AddHTML(
          '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
            '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
              '<div class="kx-msgbox-header kx-msgbox-error">' +
                '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
                '<span>' + _('Error') + '</span>' +
              '</div>' +
              '<div class="kx-msgbox-body">' +
                TNetEncoding.HTML.Encode(E.Message) +
              '</div>' +
              '<div class="kx-msgbox-footer">' +
                '<button onclick="this.closest(''.kx-msgbox-overlay'').remove();">OK</button>' +
              '</div>' +
            '</div>' +
          '</div>');
      end;
    end;
  finally
    LParams.Free;
  end;
end;

function TKWebApplication.HandleKXChangePasswordRequest: Boolean;
var
  LAuthenticator: TKAuthenticator;
  LOldPassword, LNewPassword, LConfirmNewPassword: string;
  LOldPasswordHash, LStoredHash: string;
  LErrorMsg: string;

  function GetPasswordHash(const AClearPassword: string): string;
  begin
    if LAuthenticator.IsClearPassword then
      Result := AClearPassword
    else
      Result := GetStringHash(AClearPassword);
  end;

  procedure RespondError(const AMsg: string);
  begin
    TKWebResponse.Current.Items.Clear;
    TKWebResponse.Current.Items.AddHTML(
      '<div class="kx-login-error">' +
        TNetEncoding.HTML.Encode(AMsg) +
      '</div>');
  end;

begin
  Result := True;
  LAuthenticator := GetAuthenticator;

  LOldPassword := TKWebRequest.Current.GetField('OldPassword');
  LNewPassword := TKWebRequest.Current.GetField('NewPassword');
  LConfirmNewPassword := TKWebRequest.Current.GetField('ConfirmNewPassword');

  LStoredHash := LAuthenticator.Password;
  LOldPasswordHash := GetPasswordHash(LOldPassword);

  LErrorMsg := '';
  if LOldPasswordHash <> LStoredHash then
    LErrorMsg := _('Old Password is wrong.')
  else if GetPasswordHash(LNewPassword) = LStoredHash then
    LErrorMsg := _('New Password must be different than old password.')
  else if LNewPassword <> LConfirmNewPassword then
    LErrorMsg := _('Confirm New Password is wrong.');

  if LErrorMsg <> '' then
  begin
    RespondError(LErrorMsg);
    Exit;
  end;

  try
    LAuthenticator.Password := LConfirmNewPassword;
    // Success: show info dialog, then redirect to home (forces re-login).
    TKWebResponse.Current.Items.Clear;
    TKWebResponse.Current.SetCustomHeader('HX-Retarget', 'body');
    TKWebResponse.Current.SetCustomHeader('HX-Reswap', 'beforeend');
    TKWebResponse.Current.Items.AddHTML(
      '<div class="kx-msgbox-overlay">' +
        '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
          '<div class="kx-msgbox-header kx-msgbox-info">' +
            '<div class="kx-msgbox-icon kx-msgbox-icon-info"></div>' +
            '<span>' + _('Change Password') + '</span>' +
          '</div>' +
          '<div class="kx-msgbox-body">' +
            TNetEncoding.HTML.Encode(
              _('Password changed successfully. You will be redirected to the login page.')) +
          '</div>' +
          '<div class="kx-msgbox-footer">' +
            '<button onclick="window.location.href=''' + FPath + '/'';">OK</button>' +
          '</div>' +
        '</div>' +
      '</div>');
    Logout;
  except
    on E: Exception do
      RespondError(E.Message);
  end;
end;

function TKWebApplication.HandleKXViewRequest(const AViewName: string): Boolean;
var
  LView: TKView;
  LController: IKXController;
  LObject: TKXComponent;
  LHtml: string;
  LControllerNode, LCenterNode: TEFNode;
  LControllerType: string;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LFormController: TKXFormPanelController;
  LOperation, LDefaultFilter: string;

  // Views rendered via kx/view/ are normally embedded in a tab.
  // The tab provides the close button, so AllowClose (dialog overlay) is
  // suppressed — unless the view declares IsModal: True, or the controller
  // inherits from TKXFormController (which is modal by default).
  procedure AdjustForContext;
  begin
    AdjustControllerForContext(LController);
  end;

begin
  Result := False;
  LView := Config.Views.FindView(AViewName);
  if Assigned(LView) then
  begin
    try
      // Check for CenterController interception (e.g. Controller: List / CenterController: ChartPanel)
      // Only intercept when CenterController specifies a controller type (non-empty value).
      // Views like ActivityInput use CenterController as config-only (AllowDuplicating, etc.)
      // without a controller type — those must NOT be intercepted.
      LCenterNode := nil;
      LControllerNode := LView.FindNode('Controller');
      if Assigned(LControllerNode) then
      begin
        LCenterNode := LControllerNode.FindNode('CenterController');
        if Assigned(LCenterNode) and (LCenterNode.AsString = '') then
          LCenterNode := nil; // Config-only node, not a controller type
      end;

      // IsModal is now a property of the controller, read from YAML in DoDisplay.
      // No need to pre-read it here.

      // Standalone Form controller: load record via DefaultFilter
      // (e.g. UserForm with Controller: Form / Operation: Edit)
      LControllerType := '';
      if Assigned(LControllerNode) then
        LControllerType := LControllerNode.AsString;
      if SameText(LControllerType, 'Form') and (LView is TKDataView) then
      begin
        LDataView := TKDataView(LView);
        LViewTable := LDataView.MainTable;
        LOperation := LView.GetExpandedString('Controller/Operation', 'edit');
        LController := TKXControllerFactory.Instance.CreateController(LView);
        if LController is TKXFormPanelController then
        begin
          LFormController := TKXFormPanelController(LController);
          if MatchText(LOperation, ['edit', 'view']) then
          begin
            // Load record using FilterExpression from Controller config
            // (same as Kitto1 TKExtFormPanelController.InitFlags).
            // FilterExpression supports macro expansion (e.g. %AUTH_CODFISC%).
            // Falls back to ViewTable.DefaultFilter if no FilterExpression.
            LStore := LViewTable.CreateStore;
            LDefaultFilter := LView.GetExpandedString('Controller/FilterExpression');
            if LDefaultFilter = '' then
              LDefaultFilter := LViewTable.DefaultFilter;
            LStore.Load(LDefaultFilter, '', 0, 0);
            if LStore.RecordCount >= 1 then
            begin
              LFormController.FormRecord := LStore.Records[0];
              // Initialize detail stores for master-detail transactional save
              if (LViewTable.DetailTableCount > 0) and MatchText(LOperation, ['edit', 'view']) then
              begin
                LStore.Records[0].EnsureDetailStores;
                LStore.Records[0].LoadDetailStores;
              end;
              // Register store in session for subsequent blob/save/detail requests
              TKWebSession.Current.RegisterStore(AViewName, LStore);
            end;
          end;
          LFormController.Operation := LOperation;
          LFormController.Config.SetString('Operation', LOperation);
          LController.Display;
          AdjustForContext;
          LHtml := LController.Render;
        end
        else
        begin
          LController.Display;
          AdjustForContext;
          LHtml := LController.Render;
        end;
      end
      else if Assigned(LCenterNode) then
      begin
        LController := TKXControllerFactory.Instance.CreateController(LView, nil, LCenterNode);
        LController.Display;
        AdjustForContext;
        LHtml := LController.Render;
      end
      else
      begin
        LController := TKXControllerFactory.Instance.CreateController(LView);
        LController.Display;
        AdjustForContext;
        LHtml := LController.Render;
      end;

      // Wizard modal: replace generic dialog id/close with wizard-specific ones
      if (LController.AsObject is TKXWizardController) and
        (LController.AsObject as TKXPanelControllerBase).IsModal then
      begin
        LHtml := ReplaceStr(LHtml,
          'id="kx-' + AViewName + '"',
          'id="kx-form-overlay-' + AViewName + '"');
        LHtml := ReplaceStr(LHtml,
          'onclick="this.closest(''.kx-dialog-overlay'').remove();"',
          'onclick="kxWizard.cancel(''' + AViewName + ''');"');
      end;
    except
      on E: Exception do
      begin
        LHtml := Format(
          '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
            '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
              '<div class="kx-msgbox-header kx-msgbox-error">' +
                '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
                '<span>%s</span>' +
              '</div>' +
              '<div class="kx-msgbox-body">%s</div>' +
              '<div class="kx-msgbox-footer">' +
                '<button onclick="this.closest(''.kx-msgbox-overlay'').remove()">OK</button>' +
              '</div>' +
            '</div>' +
          '</div>',
          [TNetEncoding.HTML.Encode(AViewName),
           TNetEncoding.HTML.Encode(E.Message)]);
      end;
    end;
    TKXWebResponse.Current.SendFragment(LHtml);
    Result := True;
  end
  else
  begin
    // No named view found. Treat AViewName as a controller type
    // (used by inline views like "Controller: Logout" in tree menus).
    try
      LObject := TKXControllerRegistry.Instance.GetClass(AViewName).Create;
    except
      Exit;
    end;
    try
      if Supports(LObject, IKXController, LController) then
      begin
        LObject := nil; // Interface owns the object now; prevent double-free in except
        LController.Display;
        LHtml := LController.Render;
        TKXWebResponse.Current.SendFragment(LHtml);
        Result := True;
      end
      else
        FreeAndNil(LObject);
    except
      FreeAndNil(LObject);
      raise;
    end;
  end;
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

function TKWebApplication.HandleKXDataRequest(const AViewName: string): Boolean;
var
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LTotal: Integer;
  LStart, LLimit: Integer;
  LSort, LDir: string;
  LFilterExpr, LSortExpr: string;
  LFilterItemsNode: TEFNode;
  LFilterConnector: string;
  LControllerNode: TEFNode;
  LViewField: TKViewField;
  LHtml: string;
  LViewAlias: string;
  LUrlViewName: string;
  LIsGroupingList: Boolean;
  LPagingTools: Boolean;
  LGroupingFieldName: string;
  LGroupingNode: TEFNode;
  LSortFieldNames: TStringDynArray;
  I: Integer;
begin
  Result := False;
  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) then
    Exit;
  if not (LView is TKDataView) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // Detect GroupingList or TemplateDataPanel controller
  LIsGroupingList := SameText(LView.GetString('Controller'), 'GroupingList');

  // PagingTools: opt-in paging (default false)
  LPagingTools := LViewTable.GetBoolean('Controller/PagingTools');

  // Read viewAlias from hidden state (set by lookup mode)
  LViewAlias := TKWebRequest.Current.GetField('viewAlias');
  if LViewAlias <> '' then
    LUrlViewName := AViewName   // use real view name for URLs
  else
  begin
    LViewAlias := AViewName;    // no alias: use AViewName for both
    LUrlViewName := '';
  end;

  // Read query parameters
  LStart := StrToIntDef(TKWebRequest.Current.GetField('start'), 0);
  if LPagingTools then
    LLimit := StrToIntDef(TKWebRequest.Current.GetField('limit'),
      LViewTable.GetInteger('Controller/PagingTools/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT))
  else
    LLimit := 0;
  LSort := TKWebRequest.Current.GetField('sort');
  LDir := TKWebRequest.Current.GetField('dir');

  // Build filter expression from all active filters
  LFilterExpr := '';
  LControllerNode := LView.FindNode('Controller');
  if Assigned(LControllerNode) then
  begin
    LFilterItemsNode := LControllerNode.FindNode('Filters/Items');
    if Assigned(LFilterItemsNode) then
    begin
      LFilterConnector := LControllerNode.GetString('Filters/Connector', 'and');
      LFilterExpr := BuildFilterExpression(
        LFilterItemsNode, LFilterConnector,
        function(AIndex: Integer): string
        begin
          Result := TKWebRequest.Current.GetField('f_' + IntToStr(AIndex));
        end);
    end;
  end;

  // GroupingList: override sort and paging
  if LIsGroupingList then
  begin
    LGroupingNode := LViewTable.FindNode('Controller/Grouping');
    LGroupingFieldName := '';
    if Assigned(LGroupingNode) then
      LGroupingFieldName := LGroupingNode.GetExpandedString('FieldName');

    // Build sort from SortFieldNames or grouping field
    LSortExpr := '';
    LSortFieldNames := LViewTable.GetStringArray('Controller/Grouping/SortFieldNames');
    if Length(LSortFieldNames) > 0 then
    begin
      for I := Low(LSortFieldNames) to High(LSortFieldNames) do
        LSortFieldNames[I] := LViewTable.FieldByName(LSortFieldNames[I]).QualifiedDBNameOrExpression;
      LSortExpr := Join(LSortFieldNames, ', ');
    end
    else if LGroupingFieldName <> '' then
    begin
      LViewField := LViewTable.FindField(LGroupingFieldName);
      if Assigned(LViewField) then
        LSortExpr := LViewField.QualifiedDBNameOrExpression;
    end;

    // Load ALL records (no paging)
    LStore := LViewTable.CreateStore;
    try
      LStore.Load(LFilterExpr, LSortExpr, 0, 0);

      // Build grouped rows only (no pager OOB)
      LHtml := TKXGroupingListController.BuildGroupedRows(
        LStore, LViewTable, LViewAlias, LGroupingFieldName,
        LGroupingNode, LUrlViewName) +
        // OOB: hidden state (update filter state, no paging)
        TKXListPanelController.BuildHiddenState(LViewAlias, 0, '', '', LUrlViewName);

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + LViewAlias + '"',
        'id="kx-list-state-' + LViewAlias + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
      Result := True;
    finally
      FreeAndNil(LStore);
    end;
  end
  else if SameText(LView.GetString('Controller'), 'TemplateDataPanel') then
  begin
    // TemplateDataPanel: re-render template with all records (no paging)
    LSortExpr := '';
    begin
      var LTplSortFieldNames := LViewTable.GetStringArray('Controller/SortFieldNames');
      if Length(LTplSortFieldNames) > 0 then
      begin
        for I := Low(LTplSortFieldNames) to High(LTplSortFieldNames) do
          LTplSortFieldNames[I] := LViewTable.FieldByName(LTplSortFieldNames[I]).QualifiedDBNameOrExpression;
        LSortExpr := Join(LTplSortFieldNames, ', ');
      end;
    end;

    LStore := LViewTable.CreateStore;
    try
      LStore.Load(LFilterExpr, LSortExpr, 0, 0);

      LHtml := TKXTemplateDataPanelController.BuildTemplateContent(
        LStore, LViewTable, LView.FindNode('Controller'), LViewAlias) +
        // OOB: hidden state (update filter state, no paging)
        TKXListPanelController.BuildHiddenState(LViewAlias, 0, '', '', LUrlViewName);

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + LViewAlias + '"',
        'id="kx-list-state-' + LViewAlias + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
      Result := True;
    finally
      FreeAndNil(LStore);
    end;
  end
  else if Assigned(LControllerNode) and
    (LControllerNode.GetString('TemplateFileName',
      LControllerNode.GetString('CenterController/TemplateFileName')) <> '') then
  begin
    // List + TemplateFileName — re-render selectable cards (paged if PageRecordCount defined)
    LSortExpr := '';
    begin
      var LCardSortFieldNames := LViewTable.GetStringArray('Controller/SortFieldNames');
      if Length(LCardSortFieldNames) > 0 then
      begin
        for I := Low(LCardSortFieldNames) to High(LCardSortFieldNames) do
          LCardSortFieldNames[I] := LViewTable.FieldByName(LCardSortFieldNames[I]).QualifiedDBNameOrExpression;
        LSortExpr := Join(LCardSortFieldNames, ', ');
      end;
    end;

    // Paging: only when PagingTools is enabled
    if LPagingTools then
    begin
      var LCardPageSize := LViewTable.GetInteger('Controller/PagingTools/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT);
      LStart := StrToIntDef(TKWebRequest.Current.GetField('start'), 0);
      LLimit := LCardPageSize;
    end
    else
    begin
      LStart := 0;
      LLimit := 0;
    end;

    LStore := LViewTable.CreateStore;
    try
      LTotal := LStore.Load(LFilterExpr, LSortExpr, LStart, LLimit);

      LHtml := TKXTemplateDataPanelController.BuildSelectableCards(
        LStore, LViewTable, LControllerNode,
        LViewAlias);

      // Pager OOB (only when PagingTools is enabled)
      if LPagingTools then
      begin
        LHtml := LHtml +
          TKXListPanelController.BuildPager(LViewAlias, LTotal, LStart, LLimit, LUrlViewName);
        LHtml := ReplaceStr(LHtml,
          'id="kx-list-pager-' + LViewAlias + '"',
          'id="kx-list-pager-' + LViewAlias + '" hx-swap-oob="true"');
      end;

      // OOB: hidden state
      LHtml := LHtml +
        TKXListPanelController.BuildHiddenState(LViewAlias, LLimit, '', '', LUrlViewName);

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + LViewAlias + '"',
        'id="kx-list-state-' + LViewAlias + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
      Result := True;
    finally
      FreeAndNil(LStore);
    end;
  end
  else
  begin
    // Standard List controller: paged data with sort
    // Build sort expression — only if field exists in view table (prevents SQL injection)
    LSortExpr := '';
    if LSort <> '' then
    begin
      LViewField := LViewTable.FindField(LSort);
      if Assigned(LViewField) then
      begin
        LSortExpr := LViewField.QualifiedDBNameOrExpression;
        if SameText(LDir, 'desc') then
          LSortExpr := LSortExpr + ' desc'
        else
          LSortExpr := LSortExpr + ' asc';
      end;
    end;

    // Load data
    LStore := LViewTable.CreateStore;
    try
      LTotal := LStore.Load(LFilterExpr, LSortExpr, LStart, LLimit);

      // Build response: main content (rows for tbody innerHTML swap)
      // + OOB updates for pager and state.
      // Use LViewAlias for element IDs, LUrlViewName for URL paths.
      // Main target content: raw rows (swapped into tbody via hx-target)
      LHtml :=
        TKXListPanelController.BuildDataRows(LStore, LViewTable, LViewAlias, LUrlViewName,
          LViewTable.FindLayout('Grid'));

      // OOB: pager (only when PagingTools is enabled)
      if LPagingTools then
      begin
        LHtml := LHtml +
          TKXListPanelController.BuildPager(LViewAlias, LTotal, LStart, LLimit, LUrlViewName);
        LHtml := ReplaceStr(LHtml,
          'id="kx-list-pager-' + LViewAlias + '"',
          'id="kx-list-pager-' + LViewAlias + '" hx-swap-oob="true"');
      end;

      // OOB: hidden state (updates sort/dir)
      LHtml := LHtml +
        TKXListPanelController.BuildHiddenState(LViewAlias, LLimit, LSort, LDir, LUrlViewName);

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + LViewAlias + '"',
        'id="kx-list-state-' + LViewAlias + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
      Result := True;
    finally
      FreeAndNil(LStore);
    end;
  end;
end;

function TKWebApplication.HandleKXDeleteRequest(const AViewName: string): Boolean;
var
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LDeleteStore, LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LTotal: Integer;
  LStart, LLimit: Integer;
  LSort, LDir: string;
  LFilterExpr, LSortExpr, LKeyFilter: string;
  LFilterItemsNode: TEFNode;
  LFilterConnector: string;
  LControllerNode: TEFNode;
  LViewField: TKViewField;
  LKeyStr: string;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldName, LFieldValue: string;
  LHtml: string;
  LPagingTools: Boolean;
  I: Integer;
begin
  Result := False;
  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) then
    Exit;
  if not (LView is TKDataView) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // PagingTools: opt-in paging (default false)
  LPagingTools := LViewTable.GetBoolean('Controller/PagingTools');

  // Parse key from POST parameter (URL-encoded field=value pairs separated by &)
  LKeyStr := TKWebRequest.Current.GetField('key');
  if LKeyStr = '' then
    Exit;

  // Build SQL filter from key fields (validated against ViewTable)
  LKeyFilter := '';
  LKeyParts := LKeyStr.Split(['&']);
  for I := 0 to Length(LKeyParts) - 1 do
  begin
    LPair := LKeyParts[I].Split(['=']);
    if Length(LPair) = 2 then
    begin
      LFieldName := TNetEncoding.URL.Decode(LPair[0]);
      LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
      // Only accept key fields that exist in the ViewTable (prevents SQL injection)
      LViewField := LViewTable.FindField(LFieldName);
      if Assigned(LViewField) and LViewField.IsKey then
      begin
        if LKeyFilter <> '' then
          LKeyFilter := LKeyFilter + ' and ';
        LKeyFilter := LKeyFilter + LViewField.QualifiedDBNameOrExpression +
          ' = ''' + ReplaceStr(LFieldValue, '''', '''''') + '''';
      end;
    end;
  end;

  if LKeyFilter = '' then
    Exit;

  // Load the record to delete, mark as deleted, and save via Model
  LDeleteStore := LViewTable.CreateStore;
  try
    LDeleteStore.Load(LKeyFilter, '', 0, 1);
    if LDeleteStore.RecordCount > 0 then
    begin
      LRecord := LDeleteStore.Records[0];
      LRecord.MarkAsDeleted;
      LViewTable.Model.SaveRecord(LRecord, True, nil);
    end;
  finally
    FreeAndNil(LDeleteStore);
  end;

  // Now return refreshed data (same logic as HandleKXDataRequest)
  // Build filter expression from active filters
  LFilterExpr := '';
  LControllerNode := LView.FindNode('Controller');
  if Assigned(LControllerNode) then
  begin
    LFilterItemsNode := LControllerNode.FindNode('Filters/Items');
    if Assigned(LFilterItemsNode) then
    begin
      LFilterConnector := LControllerNode.GetString('Filters/Connector', 'and');
      LFilterExpr := BuildFilterExpression(
        LFilterItemsNode, LFilterConnector,
        function(AIndex: Integer): string
        begin
          Result := TKWebRequest.Current.GetField('f_' + IntToStr(AIndex));
        end);
    end;
  end;

  // GroupingList: return grouped rows (no paging)
  if SameText(LView.GetString('Controller'), 'GroupingList') then
  begin
    LSortExpr := '';
    begin
      var LSortFieldNames := LViewTable.GetStringArray('Controller/Grouping/SortFieldNames');
      if Length(LSortFieldNames) > 0 then
      begin
        for I := Low(LSortFieldNames) to High(LSortFieldNames) do
          LSortFieldNames[I] := LViewTable.FieldByName(LSortFieldNames[I]).QualifiedDBNameOrExpression;
        LSortExpr := Join(LSortFieldNames, ', ');
      end
      else
      begin
        var LGrpFieldName := LViewTable.GetExpandedString('Controller/Grouping/FieldName');
        if LGrpFieldName <> '' then
        begin
          LViewField := LViewTable.FindField(LGrpFieldName);
          if Assigned(LViewField) then
            LSortExpr := LViewField.QualifiedDBNameOrExpression;
        end;
      end;
    end;

    LStore := LViewTable.CreateStore;
    try
      LStore.Load(LFilterExpr, LSortExpr, 0, 0);
      LHtml := TKXGroupingListController.BuildGroupedRows(
        LStore, LViewTable, AViewName,
        LViewTable.GetExpandedString('Controller/Grouping/FieldName'),
        LViewTable.FindNode('Controller/Grouping')) +
        TKXListPanelController.BuildHiddenState(AViewName, 0, '', '');

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + AViewName + '"',
        'id="kx-list-state-' + AViewName + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
      Result := True;
    finally
      FreeAndNil(LStore);
    end;
  end
  else if Assigned(LControllerNode) and
    (LControllerNode.GetString('TemplateFileName',
      LControllerNode.GetString('CenterController/TemplateFileName')) <> '') then
  begin
    // List + TemplateFileName — re-render selectable cards after delete
    LSortExpr := '';
    begin
      var LCardSortFieldNames := LViewTable.GetStringArray('Controller/SortFieldNames');
      if Length(LCardSortFieldNames) > 0 then
      begin
        for I := Low(LCardSortFieldNames) to High(LCardSortFieldNames) do
          LCardSortFieldNames[I] := LViewTable.FieldByName(LCardSortFieldNames[I]).QualifiedDBNameOrExpression;
        LSortExpr := Join(LCardSortFieldNames, ', ');
      end;
    end;

    // Paging: only when PagingTools is enabled
    if LPagingTools then
    begin
      var LCardPageSize := LViewTable.GetInteger('Controller/PagingTools/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT);
      LStart := 0;
      LLimit := LCardPageSize;
    end
    else
    begin
      LStart := 0;
      LLimit := 0;
    end;

    LStore := LViewTable.CreateStore;
    try
      LTotal := LStore.Load(LFilterExpr, LSortExpr, LStart, LLimit);

      LHtml := TKXTemplateDataPanelController.BuildSelectableCards(
        LStore, LViewTable, LControllerNode,
        AViewName);

      // Pager OOB (only when PagingTools is enabled)
      if LPagingTools then
      begin
        LHtml := LHtml +
          TKXListPanelController.BuildPager(AViewName, LTotal, LStart, LLimit);
        LHtml := ReplaceStr(LHtml,
          'id="kx-list-pager-' + AViewName + '"',
          'id="kx-list-pager-' + AViewName + '" hx-swap-oob="true"');
      end;

      // OOB: hidden state
      LHtml := LHtml +
        TKXListPanelController.BuildHiddenState(AViewName, LLimit, '', '');

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + AViewName + '"',
        'id="kx-list-state-' + AViewName + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
      Result := True;
    finally
      FreeAndNil(LStore);
    end;
  end
  else
  begin
    // Standard List: refresh after delete
    LStart := 0; // Reset to first page after delete
    if LPagingTools then
      LLimit := StrToIntDef(TKWebRequest.Current.GetField('limit'),
        LViewTable.GetInteger('Controller/PagingTools/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT))
    else
      LLimit := 0;
    LSort := TKWebRequest.Current.GetField('sort');
    LDir := TKWebRequest.Current.GetField('dir');

    // Build sort expression
    LSortExpr := '';
    if LSort <> '' then
    begin
      LViewField := LViewTable.FindField(LSort);
      if Assigned(LViewField) then
      begin
        LSortExpr := LViewField.QualifiedDBNameOrExpression;
        if SameText(LDir, 'desc') then
          LSortExpr := LSortExpr + ' desc'
        else
          LSortExpr := LSortExpr + ' asc';
      end;
    end;

    // Load data and return response
    LStore := LViewTable.CreateStore;
    try
      LTotal := LStore.Load(LFilterExpr, LSortExpr, LStart, LLimit);
      LHtml :=
        TKXListPanelController.BuildDataRows(LStore, LViewTable, AViewName, '',
          LViewTable.FindLayout('Grid'));

      // Pager OOB (only when PagingTools is enabled)
      if LPagingTools then
      begin
        LHtml := LHtml +
          TKXListPanelController.BuildPager(AViewName, LTotal, LStart, LLimit);
        LHtml := ReplaceStr(LHtml,
          'id="kx-list-pager-' + AViewName + '"',
          'id="kx-list-pager-' + AViewName + '" hx-swap-oob="true"');
      end;

      LHtml := LHtml +
        TKXListPanelController.BuildHiddenState(AViewName, LLimit, LSort, LDir);

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + AViewName + '"',
        'id="kx-list-state-' + AViewName + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
      Result := True;
    finally
      FreeAndNil(LStore);
    end;
  end;
end;

function TKWebApplication.HandleKXToolRequest(const AViewName, AToolName: string): Boolean;
var
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LToolViewsNode, LToolNode: TEFNode;
  LToolView: TKView;
  LToolController: IKXController;
  LStore: TKViewTableStore;
  LKeyStr, LKeyFilter, LFilterExpr: string;
  LFilterItemsNode: TEFNode;
  LFilterConnector: string;
  LControllerNode: TEFNode;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldName, LFieldValue: string;
  LViewField: TKViewField;
  I: Integer;
begin
  Result := False;
  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) or not (LView is TKDataView) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // Find the tool node under Controller/ToolViews
  LToolViewsNode := LViewTable.FindNode('Controller/ToolViews');
  if not Assigned(LToolViewsNode) then
    Exit;
  LToolNode := LToolViewsNode.FindNode(AToolName);
  if not Assigned(LToolNode) then
    Exit;

  // Create tool view from node and instantiate tool controller
  LToolView := Config.Views.ViewByNode(LToolNode);
  LToolController := TKXControllerFactory.Instance.CreateController(LToolView);

  // Load data store with current filters or specific record
  LStore := LViewTable.CreateStore;
  try
    LKeyStr := TKWebRequest.Current.GetField('key');
    if LKeyStr <> '' then
    begin
      // Load specific record by key (for RequireSelection tools)
      LKeyFilter := '';
      LKeyParts := LKeyStr.Split(['&']);
      for I := 0 to Length(LKeyParts) - 1 do
      begin
        LPair := LKeyParts[I].Split(['=']);
        if Length(LPair) = 2 then
        begin
          LFieldName := TNetEncoding.URL.Decode(LPair[0]);
          LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
          LViewField := LViewTable.FindField(LFieldName);
          if Assigned(LViewField) and LViewField.IsKey then
          begin
            if LKeyFilter <> '' then
              LKeyFilter := LKeyFilter + ' and ';
            LKeyFilter := LKeyFilter + LViewField.QualifiedDBNameOrExpression +
              ' = ''' + ReplaceStr(LFieldValue, '''', '''''') + '''';
          end;
        end;
      end;
      if LKeyFilter <> '' then
        LStore.Load(LKeyFilter, '', 0, 0);
    end
    else
    begin
      // Load all data with current filters (for export tools)
      LFilterExpr := '';
      LControllerNode := LView.FindNode('Controller');
      if Assigned(LControllerNode) then
      begin
        LFilterItemsNode := LControllerNode.FindNode('Filters/Items');
        if Assigned(LFilterItemsNode) then
        begin
          LFilterConnector := LControllerNode.GetString('Filters/Connector', 'and');
          LFilterExpr := BuildFilterExpression(
            LFilterItemsNode, LFilterConnector,
            function(AIndex: Integer): string
            begin
              Result := TKWebRequest.Current.GetField('f_' + IntToStr(AIndex));
            end);
        end;
      end;
      LStore.Load(LFilterExpr, '', 0, 0);
    end;

    // Set Sys objects on the tool controller's Config for tool execution
    LToolController.Config.SetObject('Sys/ServerStore', LStore);
    LToolController.Config.SetObject('Sys/ViewTable', LViewTable);
    if LStore.RecordCount > 0 then
      LToolController.Config.SetObject('Sys/Record', LStore.Records[0]);

    // Execute the tool (calls ExecuteTool + AfterExecuteTool)
    // For download tools: DownloadStream sets Content-Disposition and content stream.
    // For non-download tools: response may be empty or have a success indicator.
    LToolController.Display;

    Result := True;
  finally
    // Clear Sys/ references before freeing store to avoid dangling pointers
    LToolController.Config.SetObject('Sys/ServerStore', nil);
    LToolController.Config.SetObject('Sys/ViewTable', nil);
    LToolController.Config.SetObject('Sys/Record', nil);
    FreeAndNil(LStore);
  end;
end;

function TKWebApplication.HandleKXDetailDataRequest(const AViewName: string;
  ADetailIndex: Integer): Boolean;
var
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LDetailTable: TKViewTable;
  LDetailViewName: string;
  LDetailView: TKView;
  LDetailDataView: TKDataView;
  LDetailViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LKeyStr: string;
  LFilterExpr: string;
  LDetailRef: TKModelDetailReference;
  LRefField: TKModelField;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldName, LFieldValue: string;
  LViewAlias: string;
  LHtml: string;
  LToolbar: string;
  LDisplayLabel: string;
  LDetailControllerNode: TEFNode;
  LPreventAdding, LPreventEditing, LPreventDeleting: Boolean;
  LSessionStore: TKViewTableStore;
  I: Integer;
  LViewBuilder: TKViewBuilder;
  LOwnsStore: Boolean;
begin
  Result := False;
  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) or not (LView is TKDataView) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  if ADetailIndex >= LViewTable.DetailTableCount then
    Exit;

  LDetailTable := LViewTable.DetailTables[ADetailIndex];
  LKeyStr := TKWebRequest.Current.GetQueryField('key');

  // Get ViewName from detail table config; auto-build a View if not specified
  LDetailViewName := LDetailTable.GetString('ViewName');
  if LDetailViewName = '' then
  begin
    // Classic mode: auto-build a View for the detail model (like auto-built views)
    LDetailViewName := LDetailTable.ModelName;
    LDetailView := Config.Views.FindView(LDetailViewName);
    if not Assigned(LDetailView) or not (LDetailView is TKDataView) then
    begin
      LViewBuilder := TKViewBuilderFactory.Instance.CreateObject('AutoList');
      try
        LViewBuilder.SetString('Model', LDetailViewName);
        // Copy detail table Controller config (e.g., Form/Layout) to auto-built view
        var LSourceCtrlNode := LDetailTable.FindNode('Controller');
        if Assigned(LSourceCtrlNode) then
          LViewBuilder.AddChild(TEFNode.Create('MainTable')).AddChild(TEFNode.Clone(LSourceCtrlNode));
        LViewBuilder.BuildView(Config.Views, LDetailViewName, nil);
      finally
        FreeAndNil(LViewBuilder);
      end;
    end;
  end;

  // Load the referenced (or auto-built) view and render it as a detail grid
  LDetailView := Config.Views.FindView(LDetailViewName);
  if not Assigned(LDetailView) or not (LDetailView is TKDataView) then
    Exit;

  LDetailDataView := TKDataView(LDetailView);
  LDetailViewTable := LDetailDataView.MainTable;
  if not Assigned(LDetailViewTable) then
    Exit;

  // Build FK filter: find the reference from detail model to master model
  LFilterExpr := '';
  LRefField := nil;
  LDetailRef := LViewTable.Model.FindDetailReferenceByModelName(LDetailViewTable.ModelName);
  if Assigned(LDetailRef) then
  begin
    LRefField := LDetailRef.ReferenceField;
    if Assigned(LRefField) and LRefField.IsReference then
    begin
      // The reference field (e.g. PROJECT) has sub-fields (e.g. PROJECT_ID)
      // that are the actual FK columns. Match each master key field with the
      // corresponding sub-field by name.
      var LRefSubFields := LRefField.GetReferenceFields;
      LKeyParts := LKeyStr.Split(['&']);
      for I := 0 to Length(LKeyParts) - 1 do
      begin
        LPair := LKeyParts[I].Split(['=']);
        if Length(LPair) = 2 then
        begin
          LFieldName := TNetEncoding.URL.Decode(LPair[0]);
          LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
          // Find the FK sub-field matching this master key field name
          for var J := 0 to Length(LRefSubFields) - 1 do
          begin
            if SameText(LRefSubFields[J].FieldName, LFieldName) or
               SameText(LRefSubFields[J].DBColumnName, LFieldName) then
            begin
              if LFilterExpr <> '' then
                LFilterExpr := LFilterExpr + ' and ';
              LFilterExpr := LFilterExpr +
                LDetailViewTable.Model.DBTableName + '.' +
                LRefSubFields[J].DBColumnName + ' = ''' +
                ReplaceStr(LFieldValue, '''', '''''') + '''';
              Break;
            end;
          end;
        end;
      end;
    end;
  end;

  // Note: LFilterExpr may be empty for new records (Add). That's OK when
  // a session store is available — the detail store is already linked to the
  // master record. The filter is only needed for the DB fallback path.

  // Use an aliased view name to avoid HTML id conflicts with the main grid
  LViewAlias := 'dtl_' + AViewName + '_' + IntToStr(ADetailIndex);

  // Read detail controller config (PreventAdding/Editing/Deleting)
  LDetailControllerNode := LDetailTable.FindNode('Controller');
  if Assigned(LDetailControllerNode) then
  begin
    LPreventAdding := LDetailControllerNode.GetBoolean('PreventAdding');
    LPreventEditing := LDetailControllerNode.GetBoolean('PreventEditing');
    LPreventDeleting := LDetailControllerNode.GetBoolean('PreventDeleting');
  end
  else
  begin
    LPreventAdding := False;
    LPreventEditing := False;
    LPreventDeleting := False;
  end;

  LDisplayLabel := _(LDetailViewTable.DisplayLabel);

  // Build detail toolbar with CRUD buttons.
  // Uses kxForm.openDetailForm / deleteDetailRecord which track detail context
  // for post-save refresh of the correct detail tab.
  LToolbar := '<div class="kx-list-toolbar" id="kx-list-toolbar-' + LViewAlias + '">';
  // openDetailForm(detailView, op, aliasView, tabIndex, masterView, masterKey, fkField)
  if not LPreventAdding then
  begin
    var LFKFieldName := '';
    if Assigned(LRefField) then
      LFKFieldName := LRefField.FieldName;
    LToolbar := LToolbar +
      '<button type="button" class="kx-toolbar-btn" title="' + TNetEncoding.HTML.Encode(Format(_('Add %s'), [LDisplayLabel])) + '"' +
      ' onclick="kxForm.openDetailForm(''' + LDetailViewName + ''',''add'',''' +
      LViewAlias + ''',' + IntToStr(ADetailIndex) + ',''' +
      AViewName + ''',''' + LKeyStr + ''',''' +
      LFKFieldName + ''')">' +
      GetIconHTML('new_record') + '</button>';
  end;
  if not LPreventEditing then
    LToolbar := LToolbar +
      '<button type="button" class="kx-toolbar-btn kx-requires-selection" disabled' +
      ' title="' + TNetEncoding.HTML.Encode(Format(_('Edit %s'), [LDisplayLabel])) + '"' +
      ' onclick="kxForm.openDetailForm(''' + LDetailViewName + ''',''edit'',''' +
      LViewAlias + ''',' + IntToStr(ADetailIndex) + ',''' +
      AViewName + ''',''' + LKeyStr + ''','''')">' +
      GetIconHTML('edit_record') + '</button>';
  if not LPreventDeleting then
    LToolbar := LToolbar +
      '<button type="button" class="kx-toolbar-btn kx-requires-selection" disabled' +
      ' title="' + TNetEncoding.HTML.Encode(Format(_('Delete %s'), [LDisplayLabel])) + '"' +
      ' onclick="kxForm.deleteDetailRecord(''' + LDetailViewName + ''',''' +
      LViewAlias + ''',' + IntToStr(ADetailIndex) + ',''' +
      AViewName + ''',''' + LKeyStr + ''',''' +
      ReplaceStr(_('Confirm'), '''', '\''') + ''',''' +
      ReplaceStr(Format(_('Selected %s will be deleted. Are you sure?'), [LDisplayLabel]), '''', '\''') + ''',''' +
      ReplaceStr(_('Yes'), '''', '\''') + ''',''' +
      ReplaceStr(_('No'), '''', '\''') + ''')">' +
      GetIconHTML('delete_record') + '</button>';
  LToolbar := LToolbar +
    '<input type="hidden" id="kx-selected-key-' + LViewAlias + '" value="" />';
  LToolbar := LToolbar + '</div>';

  // Try to use the detail store from the session (master record's DetailStores).
  // If found, render from in-memory store (supports pending changes: rsNew/rsDirty/rsDeleted).
  // If not found, fall back to loading from DB (backward compatibility).
  LStore := nil;
  LSessionStore := TKWebSession.Current.FindStore(AViewName);
  LOwnsStore := True;
  if Assigned(LSessionStore) and (LSessionStore.RecordCount > 0) then
  begin
    var LMasterRecord := LSessionStore.Records[0];
    if LMasterRecord.DetailStoreCount > ADetailIndex then
    begin
      LStore := TKViewTableStore(LMasterRecord.DetailStores[ADetailIndex]);
      LOwnsStore := False; // Session owns this store
    end;
  end;

  if not Assigned(LStore) then
  begin
    // Fallback: load from DB (no session store available)
    if LFilterExpr = '' then
      Exit; // No session store and no FK filter (shouldn't happen)
    LStore := LDetailViewTable.CreateStore;
    LStore.Load(LFilterExpr, '', 0, 0);
    LOwnsStore := True;
  end;

  try
    // Build complete detail grid: toolbar + column headers + data rows
    LHtml := LToolbar +
      '<div class="kx-list-grid"><table class="kx-grid-table">' +
      TKXListPanelController.BuildColumnHeaders(
        LDetailViewTable, LViewAlias, '', '', LDetailViewName,
        LDetailViewTable.FindLayout('Grid')) +
      '<tbody id="kx-list-body-' + LViewAlias + '"' +
      ' data-dblclick="' + IfThen(not LPreventEditing, 'edit', 'view') + '"' +
      ' data-detail-view="' + LDetailViewName + '"' +
      ' data-alias-view="' + LViewAlias + '"' +
      ' data-detail-index="' + IntToStr(ADetailIndex) + '"' +
      ' data-master-view="' + AViewName + '"' +
      ' data-master-key="' + TNetEncoding.HTML.Encode(LKeyStr) + '"' +
      IfThen(Assigned(LRefField), ' data-fk-field="' + LRefField.FieldName + '"', '') +
      '>' +
      TKXListPanelController.BuildDataRows(
        LStore, LDetailViewTable, LViewAlias, LDetailViewName,
        LDetailViewTable.FindLayout('Grid')) +
      '</tbody></table></div>' +
      // Hidden state for HTMX data refresh
      TKXListPanelController.BuildHiddenState(LViewAlias, 0, '', '', LDetailViewName);

    TKXWebResponse.Current.SendFragment(LHtml);
    Result := True;
  finally
    if LOwnsStore then
      FreeAndNil(LStore);
  end;
end;

function TKWebApplication.HandleKXDetailSaveRequest(const AViewName: string;
  ADetailIndex: Integer): Boolean;
var
  LSessionStore: TKViewTableStore;
  LMasterRecord: TKViewTableRecord;
  LDetailStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LOperation: string;
  LView: TKView;
  LDataView: TKDataView;
  LViewTable, LDetailViewTable: TKViewTable;
  LDetailTable: TKViewTable;
  LDetailViewName: string;
  LKeyStr, LFieldName, LFieldValue: string;
  LKeyParts, LPair: TArray<string>;
  LHtml: string;
  I: Integer;
  LDefaults: TEFNode;
  LDetailRef: TKModelDetailReference;
  LRefField: TKModelField;
begin
  Result := False;

  // Find master store in session
  LSessionStore := TKWebSession.Current.FindStore(AViewName);
  if not Assigned(LSessionStore) or (LSessionStore.RecordCount = 0) then
    Exit;
  LMasterRecord := LSessionStore.Records[0];
  if LMasterRecord.DetailStoreCount <= ADetailIndex then
    Exit;
  LDetailStore := TKViewTableStore(LMasterRecord.DetailStores[ADetailIndex]);

  // Resolve detail view table
  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) or not (LView is TKDataView) then Exit;
  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) or (ADetailIndex >= LViewTable.DetailTableCount) then Exit;
  LDetailTable := LViewTable.DetailTables[ADetailIndex];

  // Get the detail view's ViewTable for field metadata
  LDetailViewName := LDetailTable.GetString('ViewName');
  if LDetailViewName = '' then
    LDetailViewName := LDetailTable.ModelName;
  var LDetailView := Config.Views.FindView(LDetailViewName);
  if Assigned(LDetailView) and (LDetailView is TKDataView) then
    LDetailViewTable := TKDataView(LDetailView).MainTable
  else
    LDetailViewTable := LDetailStore.ViewTable;

  LOperation := TKWebRequest.Current.GetField('_op');
  if LOperation = '' then
    LOperation := 'add';

  try
    if SameText(LOperation, 'add') then
    begin
      // Append new record to detail store
      LRecord := LDetailStore.Records.AppendAndInitialize;
      LDefaults := LDetailViewTable.GetDefaultValues;
      try
        LRecord.ReadFromNode(LDefaults);
      finally
        FreeAndNil(LDefaults);
      end;
      LRecord.MarkAsNew;

      // Set FK fields from master record key
      LDetailRef := LViewTable.Model.FindDetailReferenceByModelName(LDetailViewTable.ModelName);
      if Assigned(LDetailRef) then
      begin
        LRefField := LDetailRef.ReferenceField;
        if Assigned(LRefField) and LRefField.IsReference then
        begin
          var LRefSubFields := LRefField.GetReferenceFields;
          var LMasterKeyFields := LViewTable.Model.GetKeyFieldNames;
          for I := 0 to Min(Length(LRefSubFields), Length(LMasterKeyFields)) - 1 do
          begin
            var LMKField := LMasterRecord.FindField(LMasterKeyFields[I]);
            if Assigned(LMKField) then
              LRecord.FieldByName(LRefSubFields[I].FieldName).Assign(LMKField);
          end;
        end;
      end;

      // Populate fields from POST data
      PopulateRecordFromPost(LRecord, LDetailViewTable, True);
    end
    else if SameText(LOperation, 'edit') then
    begin
      // Find existing record by key
      LKeyStr := TKWebRequest.Current.GetField('_key');
      LRecord := nil;
      if LKeyStr <> '' then
      begin
        LKeyParts := LKeyStr.Split(['&']);
        for I := 0 to LDetailStore.RecordCount - 1 do
        begin
          var LCandidate := LDetailStore.Records[I];
          if LCandidate.State = rsDeleted then Continue;
          var LMatch := True;
          for var K := 0 to Length(LKeyParts) - 1 do
          begin
            LPair := LKeyParts[K].Split(['=']);
            if Length(LPair) = 2 then
            begin
              LFieldName := TNetEncoding.URL.Decode(LPair[0]);
              LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
              var LF := LCandidate.FindField(LFieldName);
              if not Assigned(LF) or (LF.AsString <> LFieldValue) then
              begin
                LMatch := False;
                Break;
              end;
            end;
          end;
          if LMatch then
          begin
            LRecord := LCandidate;
            Break;
          end;
        end;
      end;

      if not Assigned(LRecord) then
        raise Exception.Create(_('Detail record not found.'));

      // Update fields from POST data
      PopulateRecordFromPost(LRecord, LDetailViewTable, False);
      LRecord.MarkAsModified;
    end;

    // Success: close detail form and reload detail tab
    var LDetailViewParam := TKWebRequest.Current.GetField('_detailView');
    if LDetailViewParam = '' then
      LDetailViewParam := LDetailViewName;
    var LMasterKey := TKWebRequest.Current.GetField('_masterKey');
    LHtml := '<script>kxForm.onDetailSaveSuccess(''' +
      LDetailViewParam + ''',''' + AViewName + ''',' +
      IntToStr(ADetailIndex) + ',''' + LMasterKey + ''');</script>';
    TKXWebResponse.Current.SendFragment(LHtml);
    Result := True;
  except
    on E: Exception do
    begin
      LHtml :=
        '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
          '<div class="kx-msgbox-dialog kx-msgbox-error" onclick="event.stopPropagation()">' +
            '<div class="kx-msgbox-header kx-msgbox-error">' +
              '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
              '<span>' + TNetEncoding.HTML.Encode(_('Error')) + '</span>' +
              '<button class="kx-msgbox-close" onclick="this.closest(''.kx-msgbox-overlay'').remove()">' + GetIconHTML('close') + '</button>' +
            '</div>' +
            '<div class="kx-msgbox-body">' +
              TNetEncoding.HTML.Encode(E.Message) +
            '</div>' +
            '<div class="kx-msgbox-footer">' +
              '<button class="kx-msgbox-btn-yes" onclick="this.closest(''.kx-msgbox-overlay'').remove()">OK</button>' +
            '</div>' +
          '</div>' +
        '</div>';
      TKXWebResponse.Current.SendFragment(LHtml);
      Result := True;
    end;
  end;
end;

function TKWebApplication.HandleKXDetailDeleteRequest(const AViewName: string;
  ADetailIndex: Integer): Boolean;
var
  LSessionStore: TKViewTableStore;
  LMasterRecord: TKViewTableRecord;
  LDetailStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LKeyStr, LFieldName, LFieldValue: string;
  LKeyParts, LPair: TArray<string>;
  I: Integer;
begin
  Result := False;

  // Find master store in session
  LSessionStore := TKWebSession.Current.FindStore(AViewName);
  if not Assigned(LSessionStore) or (LSessionStore.RecordCount = 0) then
    Exit;
  LMasterRecord := LSessionStore.Records[0];
  if LMasterRecord.DetailStoreCount <= ADetailIndex then
    Exit;
  LDetailStore := TKViewTableStore(LMasterRecord.DetailStores[ADetailIndex]);

  // Find record by key
  LKeyStr := TKWebRequest.Current.GetField('key');
  if LKeyStr = '' then
    LKeyStr := TKWebRequest.Current.GetQueryField('key');
  if LKeyStr = '' then
    Exit;

  LRecord := nil;
  LKeyParts := LKeyStr.Split(['&']);
  for I := 0 to LDetailStore.RecordCount - 1 do
  begin
    var LCandidate := LDetailStore.Records[I];
    if LCandidate.State = rsDeleted then Continue;
    var LMatch := True;
    for var K := 0 to Length(LKeyParts) - 1 do
    begin
      LPair := LKeyParts[K].Split(['=']);
      if Length(LPair) = 2 then
      begin
        LFieldName := TNetEncoding.URL.Decode(LPair[0]);
        LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
        var LF := LCandidate.FindField(LFieldName);
        if not Assigned(LF) or (LF.AsString <> LFieldValue) then
        begin
          LMatch := False;
          Break;
        end;
      end;
    end;
    if LMatch then
    begin
      LRecord := LCandidate;
      Break;
    end;
  end;

  if not Assigned(LRecord) then
    Exit;

  // Mark as deleted (or clean if was new — never needs DB DELETE)
  if LRecord.State = rsNew then
    LRecord.MarkAsClean
  else
    LRecord.MarkAsDeleted;

  // Return empty response — client will reload the detail tab
  TKXWebResponse.Current.SendFragment('');
  Result := True;
end;

function TKWebApplication.HandleKXFormRequest(const AViewName: string): Boolean;
var
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LOperation: string;
  LKeyStr, LKeyFilter: string;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldName, LFieldValue: string;
  LViewField: TKViewField;
  LController: IKXController;
  LFormController: TKXFormPanelController;
  LHtml: string;
  I: Integer;
begin
  Result := False;
  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) then
    Exit;
  if not (LView is TKDataView) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // Read operation and key from query string
  LOperation := TKWebRequest.Current.GetQueryField('op');
  if LOperation = '' then
    LOperation := 'edit';
  LKeyStr := TKWebRequest.Current.GetQueryField('key');

  // Create store and load record
  LStore := LViewTable.CreateStore;
  try
    LRecord := nil;
    if SameText(LOperation, 'edit') or SameText(LOperation, 'view') or
       SameText(LOperation, 'dup') then
    begin
      if LKeyStr = '' then
        Exit;

      // Build SQL filter from key
      LKeyFilter := '';
      LKeyParts := LKeyStr.Split(['&']);
      for I := 0 to Length(LKeyParts) - 1 do
      begin
        LPair := LKeyParts[I].Split(['=']);
        if Length(LPair) = 2 then
        begin
          LFieldName := TNetEncoding.URL.Decode(LPair[0]);
          LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
          LViewField := LViewTable.FindField(LFieldName);
          if Assigned(LViewField) and LViewField.IsKey then
          begin
            if LKeyFilter <> '' then
              LKeyFilter := LKeyFilter + ' and ';
            LKeyFilter := LKeyFilter + LViewField.QualifiedDBNameOrExpression +
              ' = ''' + ReplaceStr(LFieldValue, '''', '''''') + '''';
          end;
        end;
      end;

      if LKeyFilter = '' then
        Exit;

      LStore.Load(LKeyFilter, '', 0, 1);
      if LStore.RecordCount > 0 then
        LRecord := LStore.Records[0]
      else
        Exit; // Record not found

      // Apply operation-specific rules (matching Kitto1 flow).
      // ApplyAfterShowEditWindowRules is called later, after form rendering.
      if SameText(LOperation, 'edit') then
        LRecord.ApplyEditRecordRules
      else if SameText(LOperation, 'dup') then
        LRecord.ApplyDuplicateRecordRules;
    end
    else if SameText(LOperation, 'add') then
    begin
      // Create new record with defaults (macro-expanded, e.g. %COMPACT_GUID%, {date})
      LRecord := LStore.Records.AppendAndInitialize;
      var LAddDefaults := LViewTable.GetDefaultValues;
      try
        LRecord.ReadFromNode(LAddDefaults);
      finally
        FreeAndNil(LAddDefaults);
      end;
      LRecord.ApplyNewRecordRules;

      // FK pre-fill: when adding from a detail grid, the master record key
      // is passed as query params: fkField=REFERENCE_NAME&masterKey=PK_FIELD%3Dvalue
      // Example: fkField=PROJECT&masterKey=PROJECT_ID%3Dxxx
      // The masterKey fields are set directly on the record (flat structure).
      begin
        var LFKFieldName := TNetEncoding.URL.Decode(
          TKWebRequest.Current.GetQueryField('fkField'));
        var LMasterKey := TNetEncoding.URL.Decode(
          TKWebRequest.Current.GetQueryField('masterKey'));
        if (LFKFieldName <> '') and (LMasterKey <> '') then
        begin
          // Store fields are flat: PROJECT_ID is a direct child of the record,
          // not nested under the PROJECT reference node. Set each master key
          // field directly on the record.
          var LMKParts := LMasterKey.Split(['&']);
          for var K := 0 to Length(LMKParts) - 1 do
          begin
            var LMKPair := LMKParts[K].Split(['=']);
            if Length(LMKPair) = 2 then
            begin
              var LMKName := TNetEncoding.URL.Decode(LMKPair[0]);
              var LMKValue := TNetEncoding.URL.Decode(LMKPair[1]);
              var LMKField := LRecord.FindField(LMKName);
              if Assigned(LMKField) then
                LMKField.AsString := LMKValue;
            end;
          end;
        end;
      end;
    end;

    // Create form controller (force 'Form' controller type, not the view's 'List' type)
    LController := TKXControllerFactory.Instance.CreateController(LView, nil, nil, 'Form');
    if not (LController is TKXFormPanelController) then
      Exit;
    LFormController := TKXFormPanelController(LController);

    // Set form controller properties
    LFormController.Operation := LOperation;
    LFormController.FormRecord := LRecord;
    LFormController.Config.SetString('Operation', LOperation);
    // FK field from detail context: mark as read-only in the form
    LFormController.FKFieldName := TNetEncoding.URL.Decode(
      TKWebRequest.Current.GetQueryField('fkField'));

    LController.Display;
    AdjustControllerForContext(LController);
    LHtml := LController.Render;

    // Replace the generic dialog overlay id with a form-specific one
    LHtml := ReplaceStr(LHtml,
      'id="kx-' + AViewName + '"',
      'id="kx-form-overlay-' + AViewName + '"');

    // Replace the close button to use kxForm.cancel
    LHtml := ReplaceStr(LHtml,
      'onclick="this.closest(''.kx-dialog-overlay'').remove();"',
      'onclick="kxForm.cancel(''' + AViewName + ''');"');

    // Initialize detail stores for master-detail transactional save.
    // EnsureDetailStores creates empty detail stores linked to the master record;
    // LoadDetailStores populates them from the database.
    if Assigned(LRecord) and (LViewTable.DetailTableCount > 0) then
    begin
      LRecord.EnsureDetailStores;
      // Load detail records from DB only for edit/view (add starts with empty details)
      if MatchText(LOperation, ['edit', 'view']) then
        LRecord.LoadDetailStores;
    end;

    // Register store in session for subsequent blob/save/detail requests
    TKWebSession.Current.RegisterStore(AViewName, LStore);
    LStore := nil; // Session owns the store now; prevent finally from freeing it

    TKXWebResponse.Current.SendFragment(LHtml);

    // Apply after-show rules (always, regardless of operation).
    // In the unified flow, the form always "shows" first, then switches to edit if needed.
    if Assigned(LRecord) then
      LRecord.ApplyAfterShowEditWindowRules;

    Result := True;
  finally
    FreeAndNil(LStore);
  end;
end;

function TKWebApplication.HandleKXLookupRequest(const AViewName: string): Boolean;
var
  LView: TKView;
  LController: IKXController;
  LPanel: TKXPanelControllerBase;
  LHtml: string;
  LViewAlias: string;
begin
  Result := False;
  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) then
    Exit;

  LController := TKXControllerFactory.Instance.CreateController(LView);
  LController.Display;

  // Override panel properties for dialog rendering
  if LController is TKXPanelControllerBase then
  begin
    LPanel := TKXPanelControllerBase(LController);
    LPanel.IsModal := True;
    LPanel.AllowClose := True;
    if LPanel.Title <> '' then
      LPanel.Title := Format(_('Select: %s'), [LPanel.Title]);
  end;

  LHtml := LController.Render;

  // Replace the generic dialog overlay id with a lookup-specific aliased one
  LViewAlias := 'lkp_' + AViewName;
  LHtml := ReplaceStr(LHtml,
    'id="kx-' + AViewName + '"',
    'id="kx-' + LViewAlias + '"');

  // Replace the close button to use kxForm.closeLookup
  LHtml := ReplaceStr(LHtml,
    'onclick="this.closest(''.kx-dialog-overlay'').remove();"',
    'onclick="kxForm.closeLookup(''' + LViewAlias + ''');"');

  TKXWebResponse.Current.SendFragment(LHtml);
  Result := True;
end;

function TKWebApplication.HandleKXTempUploadRequest(const AViewName, AFieldName: string): Boolean;
var
  LView: TKView;
  LViewTable: TKViewTable;
  LViewField: TKViewField;
  LFiles: TAbstractWebRequestFiles;
  LTempDir, LStoredName: string;
  LUploadStream: TFileStream;
  LJson: string;
begin
  Result := False;
  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) or not (LView is TKDataView) then Exit;
  LViewTable := TKDataView(LView).MainTable;
  if not Assigned(LViewTable) then Exit;
  LViewField := LViewTable.FindField(AFieldName);
  if not Assigned(LViewField) or not (LViewField.DataType is TKFileReferenceDataType) then Exit;

  LFiles := TKWebRequest.Current.Files;
  if LFiles.Count = 0 then Exit;

  // Per-session temp directory (isolated by session ID, cleaned up by age)
  LTempDir := TPath.Combine(TPath.Combine(TPath.GetTempPath, 'kxupload'),
    TKWebSession.Current.SessionId);
  ForceDirectories(LTempDir);

  LStoredName := CreateCompactGuidStr + ExtractFileExt(LFiles[0].FileName);
  LUploadStream := TFileStream.Create(TPath.Combine(LTempDir, LStoredName),
    fmCreate or fmShareExclusive);
  try
    LFiles[0].Stream.Position := 0;
    LUploadStream.CopyFrom(LFiles[0].Stream, 0);
  finally
    LUploadStream.Free;
  end;

  LJson := '{"ok":true,"temp":"' + LStoredName + '"}';
  TKWebResponse.Current.ReplaceContentStream(TStringStream.Create(LJson, TEncoding.UTF8));
  TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
  Result := True;
end;

function TKWebApplication.HandleKXBlobRequest(const AViewName, AFieldName: string): Boolean;
var
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LViewField: TKViewField;
  LKeyStr, LKeyFilter: string;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldNamePart, LFieldValue: string;
  LBytes: TBytes;
  LExt, LContentType, LFileName: string;
  LIsDownload: Boolean;
  LStream: TBytesStream;
  I: Integer;
begin
  Result := False;
  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) or not (LView is TKDataView) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  LViewField := LViewTable.FindField(AFieldName);
  if not Assigned(LViewField) then Exit;
  if not LViewField.IsBlob and not (LViewField.DataType is TKFileReferenceDataType) then Exit;

  // Serve a temp file (uploaded via AJAX before form save) — no record needed
  if LViewField.DataType is TKFileReferenceDataType then
  begin
    var LTempParam := TKWebRequest.Current.GetQueryField('temp');
    if LTempParam <> '' then
    begin
      var LTempDir := TPath.Combine(TPath.Combine(TPath.GetTempPath, 'kxupload'),
        TKWebSession.Current.SessionId);
      var LTempFilePath := TPath.Combine(LTempDir, LTempParam);
      if not TFile.Exists(LTempFilePath) then
      begin
        TKWebResponse.Current.StatusCode := 404;
        TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
        TKWebResponse.Current.ReplaceContentStream(TStringStream.Create('{"error":"File not found"}', TEncoding.UTF8));
        Result := True;
        Exit;
      end;
      var LDisplayName := TNetEncoding.URL.Decode(TKWebRequest.Current.GetQueryField('name'));
      if LDisplayName = '' then LDisplayName := LTempParam;
      LIsDownload := SameText(TKWebRequest.Current.GetQueryField('download'), '1');
      // Read into memory so the file handle is closed before transfer starts.
      // This avoids EIdSocketError #10053 when PDF viewers make range requests
      // and abort the initial connection mid-stream.
      var LFileBytes: TBytes;
      var LFStream := TFileStream.Create(LTempFilePath, fmOpenRead or fmShareDenyWrite);
      try
        SetLength(LFileBytes, LFStream.Size);
        if Length(LFileBytes) > 0 then
          LFStream.ReadBuffer(LFileBytes[0], Length(LFileBytes));
      finally
        LFStream.Free;
      end;
      var LTempStream := TBytesStream.Create(LFileBytes);
      if LIsDownload then
        DownloadStream(LTempStream, LDisplayName, '', False)
      else
        DownloadStream(LTempStream, LDisplayName, '', True);
      Result := True;
      Exit;
    end;
  end;

  LStore := nil;

  // Try to get the record from the session store (registered when form was opened).
  // This avoids a full SELECT * query — the blob is lazy-loaded on AsBytes access.
  LStore := TKWebSession.Current.FindStore(AViewName);
  if Assigned(LStore) and (LStore.RecordCount > 0) then
    LRecord := LStore.Records[0]
  else
  begin
    // Fallback: load from DB (for cases where no session store exists).
    // Qualify key fields with table name to avoid ambiguity in JOINs.
    LKeyStr := TKWebRequest.Current.GetQueryField('key');
    if LKeyStr = '' then
      Exit;

    LKeyFilter := '';
    LKeyParts := LKeyStr.Split(['&']);
    for I := 0 to Length(LKeyParts) - 1 do
    begin
      LPair := LKeyParts[I].Split(['=']);
      if Length(LPair) = 2 then
      begin
        LFieldNamePart := TNetEncoding.URL.Decode(LPair[0]);
        LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
        // Qualify field name with table name to avoid ambiguity
        LViewField := LViewTable.FindField(LFieldNamePart);
        if Assigned(LViewField) then
        begin
          if LKeyFilter <> '' then
            LKeyFilter := LKeyFilter + ' and ';
          LKeyFilter := LKeyFilter + LViewField.QualifiedDBNameOrExpression +
            ' = ''' + ReplaceStr(LFieldValue, '''', '''''') + '''';
        end;
      end;
    end;

    if LKeyFilter = '' then
      Exit;

    LStore := LViewTable.CreateStore;
    try
      LStore.Load(LKeyFilter, '', 0, 1);
      if LStore.RecordCount = 0 then
        Exit;
      LRecord := LStore.Records[0];
    except
      FreeAndNil(LStore);
      raise;
    end;
  end;

  if not Assigned(LRecord) then
    Exit;

  // Re-read the view field (it may have been overwritten by the key field lookup above)
  LViewField := LViewTable.FindField(AFieldName);

  // FileReference fields: file lives on disk; DB field holds the stored filename only.
  if LViewField.DataType is TKFileReferenceDataType then
  begin
    try
      var LStoredName := LRecord.FieldByName(LViewField.FieldNamesForUpdate).AsString;
      if LStoredName = '' then
      begin
        if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
          FreeAndNil(LStore);
        TKWebResponse.Current.StatusCode := 404;
        TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
        TKWebResponse.Current.ReplaceContentStream(TStringStream.Create('{"error":"File not found"}', TEncoding.UTF8));
        Result := True;
        Exit;
      end;
      var LDirPath := LViewField.GetExpandedString('Path');
      if LDirPath = '' then
      begin
        if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
          FreeAndNil(LStore);
        Exit; // config error — leave as 404 "unknown request"
      end;
      var LFilePath := TPath.Combine(LDirPath, LStoredName);
      if not TFile.Exists(LFilePath) then
      begin
        if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
          FreeAndNil(LStore);
        TKWebResponse.Current.StatusCode := 404;
        TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
        TKWebResponse.Current.ReplaceContentStream(TStringStream.Create('{"error":"File not found"}', TEncoding.UTF8));
        Result := True;
        Exit;
      end;
      // Prefer companion field value as display filename (original name)
      var LDisplayName := LStoredName;
      var LFNField := LViewField.FileNameField;
      if LFNField <> '' then
      begin
        var LCompField := LRecord.FindField(LFNField);
        if Assigned(LCompField) and not LCompField.IsNull and (LCompField.AsString <> '') then
          LDisplayName := LCompField.AsString;
      end;
      LIsDownload := SameText(TKWebRequest.Current.GetQueryField('download'), '1');
      // Read into memory before serving to avoid EIdSocketError #10053 when PDF
      // viewers make Range requests and abort the initial connection mid-stream.
      var LDiskBytes: TBytes;
      var LDiskFS := TFileStream.Create(LFilePath, fmOpenRead or fmShareDenyWrite);
      try
        SetLength(LDiskBytes, LDiskFS.Size);
        if Length(LDiskBytes) > 0 then
          LDiskFS.ReadBuffer(LDiskBytes[0], Length(LDiskBytes));
      finally
        LDiskFS.Free;
      end;
      var LFileStream := TBytesStream.Create(LDiskBytes);
      // Empty content type → DownloadStream calls GetFileMimeType(LDisplayName)
      if LIsDownload then
        DownloadStream(LFileStream, LDisplayName, '', False)
      else
        DownloadStream(LFileStream, LDisplayName, '', True);
    except
      if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
        FreeAndNil(LStore);
      raise;
    end;
    if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
      FreeAndNil(LStore);
    Result := True;
    Exit;
  end;

  try
    LBytes := LRecord.FieldByName(LViewField.FieldNamesForUpdate).AsBytes;
  except
    // If the fallback store was created, free it
    if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
      FreeAndNil(LStore);
    raise;
  end;

  if Length(LBytes) = 0 then
  begin
    if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
      FreeAndNil(LStore);
    TKWebResponse.Current.StatusCode := 404;
    TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
    TKWebResponse.Current.ReplaceContentStream(TStringStream.Create('{"error":"File not found"}', TEncoding.UTF8));
    Result := True;
    Exit;
  end;

  // Detect image format
  LExt := GetDataType(LBytes, 'dat');
  if SameText(LExt, 'jpg') then
    LContentType := 'image/jpeg'
  else if SameText(LExt, 'png') then
    LContentType := 'image/png'
  else if SameText(LExt, 'gif') then
    LContentType := 'image/gif'
  else if SameText(LExt, 'bmp') then
    LContentType := 'image/bmp'
  else if SameText(LExt, 'tif') then
    LContentType := 'image/tiff'
  else
    LContentType := 'application/octet-stream';

  LIsDownload := SameText(TKWebRequest.Current.GetQueryField('download'), '1');
  LFileName := AViewName + '_' + AFieldName + '.' + LExt;

  LStream := TBytesStream.Create(LBytes);
  if LIsDownload then
    DownloadStream(LStream, LFileName, LContentType, False)
  else
    DownloadStream(LStream, LFileName, LContentType, True);

  // Free fallback store (session store is owned by session, don't free it)
  if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
    FreeAndNil(LStore);

  Result := True;
end;

procedure TKWebApplication.PopulateRecordFromPost(ARecord: TKViewTableRecord;
  AViewTable: TKViewTable; AIsInsert: Boolean);
var
  I, J: Integer;
  LViewField: TKViewField;
  LFieldName, LPostValue, LDatePart, LTimePart: string;
  LFiles: TAbstractWebRequestFiles;
begin
  for I := 0 to AViewTable.FieldCount - 1 do
  begin
    LViewField := AViewTable.Fields[I];
    if AIsInsert then
    begin
      if not LViewField.CanInsert then Continue;
    end
    else
    begin
      if LViewField.IsKey then Continue;
      if not LViewField.CanUpdate then Continue;
    end;
    if LViewField.IsBlob and not (LViewField.DataType is TEFMemoDataType) then
      Continue;
    // FileReference fields are handled below (file save section), not here
    if LViewField.DataType is TKFileReferenceDataType then
      Continue;

    LFieldName := LViewField.FieldNamesForUpdate;

    // Handle DateTime split fields
    if LViewField.DataType is TEFDateTimeDataType then
    begin
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
          LViewField.DataType.ValueToDateTime(LPostValue);
      end
      else
        // Only time without date: set to null (time alone is not valid)
        ARecord.FieldByName(LFieldName).SetToNull(True);
      Continue;
    end;

    LPostValue := TKWebRequest.Current.GetField(LFieldName);

    if LViewField.DataType is TEFBooleanDataType then
      ARecord.FieldByName(LFieldName).Value :=
        SameText(LPostValue, 'true') or SameText(LPostValue, '1')
    else if LViewField.DataType is TEFDateDataType then
    begin
      if LPostValue = '' then
        ARecord.FieldByName(LFieldName).SetToNull(True)
      else
        ARecord.FieldByName(LFieldName).Value :=
          LViewField.DataType.ValueToDate(LPostValue);
    end
    else if LViewField.DataType is TEFTimeDataType then
    begin
      if LPostValue = '' then
        ARecord.FieldByName(LFieldName).SetToNull(True)
      else
        ARecord.FieldByName(LFieldName).Value :=
          LViewField.DataType.ValueToTime(LPostValue);
    end
    else if LViewField.DataType is TEFIntegerDataType then
    begin
      if LPostValue = '' then
        ARecord.FieldByName(LFieldName).SetToNull(True)
      else
        ARecord.FieldByName(LFieldName).Value := StrToIntDef(LPostValue, 0);
    end
    else if LViewField.DataType is TEFDecimalNumericDataTypeBase then
    begin
      if LPostValue = '' then
        ARecord.FieldByName(LFieldName).SetToNull(True)
      else
      begin
        if (LViewField.DataType is TEFCurrencyDataType) and (FormatSettings.CurrencyString <> '') then
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
      else if not LViewField.IsRequired then
        ARecord.FieldByName(LFieldName).SetToNull(not AIsInsert);
    end;
  end;

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

function TKWebApplication.HandleKXSaveCacheRequest(const AViewName: string): Boolean;
var
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LView: TKView;
  LViewTable: TKViewTable;
  LOperation: string;
  LHtml: string;
  LDefaults: TEFNode;
begin
  Result := False;

  LStore := TKWebSession.Current.FindStore(AViewName);
  if not Assigned(LStore) then
    Exit;

  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) or not (LView is TKDataView) then
    Exit;
  LViewTable := TKDataView(LView).MainTable;
  if not Assigned(LViewTable) then
    Exit;

  LOperation := TKWebRequest.Current.GetField('_op');

  try
    if LStore.RecordCount > 0 then
      LRecord := LStore.Records[0]
    else
    begin
      // Add: create new record in session store
      LRecord := LStore.Records.AppendAndInitialize;
      LDefaults := LViewTable.GetDefaultValues;
      try
        LRecord.ReadFromNode(LDefaults);
      finally
        FreeAndNil(LDefaults);
      end;
      LRecord.MarkAsNew;
    end;

    // Populate fields from POST data
    PopulateRecordFromPost(LRecord, LViewTable, SameText(LOperation, 'add'));

    // Mark as modified (keep rsNew if it was new)
    if LRecord.State = rsClean then
      LRecord.MarkAsModified;

    // Success: switch to ViewMode, enable Save All
    LHtml := '<script>kxForm.onSaveCacheSuccess(''' + AViewName + ''');</script>';
    TKXWebResponse.Current.SendFragment(LHtml);
    Result := True;
  except
    on E: Exception do
    begin
      LHtml :=
        '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
          '<div class="kx-msgbox-dialog kx-msgbox-error" onclick="event.stopPropagation()">' +
            '<div class="kx-msgbox-header kx-msgbox-error">' +
              '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
              '<span>' + TNetEncoding.HTML.Encode(_('Error')) + '</span>' +
              '<button class="kx-msgbox-close" onclick="this.closest(''.kx-msgbox-overlay'').remove()">' + GetIconHTML('close') + '</button>' +
            '</div>' +
            '<div class="kx-msgbox-body">' + TNetEncoding.HTML.Encode(E.Message) + '</div>' +
            '<div class="kx-msgbox-footer">' +
              '<button class="kx-msgbox-btn-yes" onclick="this.closest(''.kx-msgbox-overlay'').remove()">OK</button>' +
            '</div>' +
          '</div>' +
        '</div>';
      TKXWebResponse.Current.SendFragment(LHtml);
      Result := True;
    end;
  end;
end;

function TKWebApplication.HandleKXSaveRequest(const AViewName: string): Boolean;
var
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LOperation: string;
  LKeyStr, LKeyFilter: string;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldName, LFieldValue: string;
  LViewField: TKViewField;
  LDefaults: TEFNode;
  I: Integer;
  LHtml: string;
  LOwnsStore: Boolean;
begin
  Result := False;
  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) then
    Exit;
  if not (LView is TKDataView) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // Read operation and key from POST body
  LOperation := TKWebRequest.Current.GetField('_op');
  if LOperation = '' then
    LOperation := 'edit';
  LKeyStr := TKWebRequest.Current.GetField('_key');

  // Try to use the session store (with attached detail stores for transactional save).
  // Falls back to creating a new store if no session store is found.
  LStore := TKWebSession.Current.FindStore(AViewName);
  LOwnsStore := not Assigned(LStore);
  if LOwnsStore then
    LStore := LViewTable.CreateStore;
  try
    try
      // Treat 'view' as 'edit': if a save arrives from a view-mode form,
      // the user switched to edit mode on the client side.
      if SameText(LOperation, 'edit') or SameText(LOperation, 'view') then
      begin
        if LOwnsStore then
        begin
          // No session store: load from DB (fallback)
          if LKeyStr = '' then
            raise Exception.Create(_('Missing record key.'));
          LKeyFilter := '';
          LKeyParts := LKeyStr.Split(['&']);
          for I := 0 to Length(LKeyParts) - 1 do
          begin
            LPair := LKeyParts[I].Split(['=']);
            if Length(LPair) = 2 then
            begin
              LFieldName := TNetEncoding.URL.Decode(LPair[0]);
              LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
              LViewField := LViewTable.FindField(LFieldName);
              if Assigned(LViewField) and LViewField.IsKey then
              begin
                if LKeyFilter <> '' then
                  LKeyFilter := LKeyFilter + ' and ';
                LKeyFilter := LKeyFilter + LViewField.QualifiedDBNameOrExpression +
                  ' = ''' + ReplaceStr(LFieldValue, '''', '''''') + '''';
              end;
            end;
          end;
          if LKeyFilter = '' then
            raise Exception.Create(_('Invalid record key.'));
          LStore.Load(LKeyFilter, '', 0, 1);
          if LStore.RecordCount = 0 then
            raise Exception.Create(_('Record not found.'));
        end;

        LRecord := LStore.Records[0];

        // SaveAll: record is already up-to-date from save-cache, just persist.
        // Normal save: populate from POST data first.
        if not SameText(TKWebRequest.Current.GetField('_saveAll'), 'true') then
        begin
          PopulateRecordFromPost(LRecord, LViewTable, False);
          LRecord.MarkAsModified;
        end;
        // SaveRecord with cascading: PersistRecord persists master, then
        // PersistDetailStores handles all attached detail stores in same transaction.
        LViewTable.Model.SaveRecord(LRecord, True, nil);
      end
      else if SameText(LOperation, 'add') or SameText(LOperation, 'dup') then
      begin
        if not LOwnsStore and (LStore.RecordCount > 0) then
        begin
          // Session store: use the existing record (pre-populated by save-cache)
          LRecord := LStore.Records[0];
          PopulateRecordFromPost(LRecord, LViewTable, True);
        end
        else
        begin
          // No session store: create new record
          LRecord := LStore.Records.AppendAndInitialize;
          LDefaults := LViewTable.GetDefaultValues;
          try
            LRecord.ReadFromNode(LDefaults);
          finally
            FreeAndNil(LDefaults);
          end;
          LRecord.MarkAsNew;
          PopulateRecordFromPost(LRecord, LViewTable, True);
        end;
        LViewTable.Model.SaveRecord(LRecord, True, nil);
      end;

      // Success: return script based on post-save mode
      if TKWebRequest.Current.GetField('_clone') = 'true' then
        LHtml := '<script>kxForm.onCloneSuccess(''' + AViewName + ''');</script>'
      else if TKWebRequest.Current.GetField('_keepopen') = 'true' then
        LHtml := '<script>kxForm.onSaveKeepOpen(''' + AViewName + ''');</script>'
      else
      begin
        LHtml := '<script>kxForm.onSaveSuccess(''' + AViewName + ''');</script>';
        // Form is closing: release session store
        TKWebSession.Current.UnregisterStore(AViewName);
      end;
      TKXWebResponse.Current.SendFragment(LHtml);
      Result := True;
    except
      on E: Exception do
      begin
        // Error: return error dialog overlay
        LHtml :=
          '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
            '<div class="kx-msgbox-dialog kx-msgbox-error" onclick="event.stopPropagation()">' +
              '<div class="kx-msgbox-header kx-msgbox-error">' +
                '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
                '<span>' + TNetEncoding.HTML.Encode(_('Error')) + '</span>' +
                '<button class="kx-msgbox-close" onclick="this.closest(''.kx-msgbox-overlay'').remove()">' + GetIconHTML('close') + '</button>' +
              '</div>' +
              '<div class="kx-msgbox-body">' +
                TNetEncoding.HTML.Encode(E.Message) +
              '</div>' +
              '<div class="kx-msgbox-footer">' +
                '<button class="kx-msgbox-btn-yes" onclick="this.closest(''.kx-msgbox-overlay'').remove()">OK</button>' +
              '</div>' +
            '</div>' +
          '</div>';
        TKXWebResponse.Current.SendFragment(LHtml);
        Result := True;
      end;
    end;
  finally
    if LOwnsStore then
      FreeAndNil(LStore);
  end;
end;

function TKWebApplication.HandleKXWizardFinishRequest(const AViewName: string): Boolean;
var
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LDefaults: TEFNode;
  I: Integer;
  LHtml: string;
  LRulesNode, LRuleNode: TEFNode;
  LRuleImpl: TKXWizardRuleImpl;
  LRules: TObjectList<TKXWizardRuleImpl>;
begin
  Result := False;
  LView := Config.Views.FindView(AViewName);
  if not Assigned(LView) then
    Exit;
  if not (LView is TKDataView) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  LStore := LViewTable.CreateStore;
  try
    try
      // Create new record with defaults
      LRecord := LStore.Records.AppendAndInitialize;
      LDefaults := LViewTable.GetDefaultValues;
      try
        LRecord.ReadFromNode(LDefaults);
      finally
        FreeAndNil(LDefaults);
      end;
      LRecord.MarkAsNew;
      PopulateRecordFromPost(LRecord, LViewTable, True);

      // Instantiate wizard rules from Controller/Rules node
      LRules := TObjectList<TKXWizardRuleImpl>.Create(True);
      try
        LRulesNode := LView.FindNode('Controller/Rules');
        if Assigned(LRulesNode) then
        begin
          for I := 0 to LRulesNode.ChildCount - 1 do
          begin
            LRuleNode := LRulesNode.Children[I];
            if TKXWizardRuleRegistry.Instance.HasClass(LRuleNode.Name) then
            begin
              LRuleImpl := TKXWizardRuleRegistry.Instance.CreateObject(LRuleNode.Name);
              LRuleImpl.Config := LRuleNode;
              LRules.Add(LRuleImpl);
            end;
          end;
        end;

        // BeforeExecute callbacks
        for I := 0 to LRules.Count - 1 do
          LRules[I].BeforeExecute(LRecord);

        LViewTable.Model.SaveRecord(LRecord, True, nil);

        // AfterExecute callbacks
        for I := 0 to LRules.Count - 1 do
          LRules[I].AfterExecute(LRecord);
      finally
        LRules.Free;
      end;

      // Success: return script to close wizard and refresh
      LHtml := '<script>kxWizard.onFinishSuccess(''' + AViewName + ''');</script>';
      TKXWebResponse.Current.SendFragment(LHtml);
      Result := True;
    except
      on E: Exception do
      begin
        LHtml :=
          '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
            '<div class="kx-msgbox-dialog kx-msgbox-error" onclick="event.stopPropagation()">' +
              '<div class="kx-msgbox-header kx-msgbox-error">' +
                '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
                '<span>' + TNetEncoding.HTML.Encode(_('Error')) + '</span>' +
                '<button class="kx-msgbox-close" onclick="this.closest(''.kx-msgbox-overlay'').remove()">' + GetIconHTML('close') + '</button>' +
              '</div>' +
              '<div class="kx-msgbox-body">' +
                TNetEncoding.HTML.Encode(E.Message) +
              '</div>' +
              '<div class="kx-msgbox-footer">' +
                '<button class="kx-msgbox-btn-yes" onclick="this.closest(''.kx-msgbox-overlay'').remove()">OK</button>' +
              '</div>' +
            '</div>' +
          '</div>';
        TKXWebResponse.Current.SendFragment(LHtml);
        Result := True;
      end;
    end;
  finally
    //if LOwnsStore then
      FreeAndNil(LStore);
  end;
end;

function TKWebApplication.GetMethodURL(const AObjectName, AMethodName: string): string;
begin
  Result := FPath + '/' + TKWebRequest.APP_NAMESPACE + '/' + IfThen(AObjectName <> '',  AObjectName + '/', '') + AMethodName;
end;

procedure TKWebApplication.ActivateInstance;
begin
  FCurrent := Self;
  TEFMacroExpansionEngine.OnGetInstance :=
    function: TEFMacroExpansionEngine
    begin
      Result := Config.MacroExpansionEngine
    end;
  TKAuthenticator.Current := GetAuthenticator;
  TKAccessController.Current := GetAccessController;
end;

procedure TKWebApplication.DeactivateInstance;
begin
  FCurrent := nil;
  TEFMacroExpansionEngine.OnGetInstance := nil;
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
end;

procedure TKWebApplication.DisplayHomeView;
var
  LView: TKView;
  LController: IKXController;
  LBodyContent: string;
begin
  if TKAuthenticator.Current.MustChangePassword then
  begin
    LView := Config.Views.ViewByName('ChangePassword');
    TKWebSession.Current.AutoOpenViewName := '';
  end
  else
    LView := GetHomeView;

  LController := TKXControllerFactory.Instance.CreateController(LView);
  LController.Display;
  LBodyContent := LController.Render;

  if TKWebSession.Current.AutoOpenViewName <> '' then
  begin
    DisplayView(TKWebSession.Current.AutoOpenViewName);
    TKWebSession.Current.AutoOpenViewName := '';
  end;

  ServeHomePage(LBodyContent);
end;

procedure TKWebApplication.DisplayLoginView;
var
  LLoginView: TKView;
  LController: IKXController;
  LBodyContent: string;
begin
  LLoginView := GetLoginView;
  // LoginView may have Controller: with no type value (properties are children).
  // Default to 'Login' controller type, same as the ExtJS version did.
  if LLoginView.ControllerType = '' then
    LController := TKXControllerFactory.Instance.CreateController(LLoginView, nil, nil, 'Login')
  else
    LController := TKXControllerFactory.Instance.CreateController(LLoginView);
  LController.Display;
  LBodyContent := LController.Render;
  ServeHomePage(LBodyContent);
end;

procedure TKWebApplication.Home;
var
  LAuthenticator: TKAuthenticator;
  LBodyContent: string;
  LView: TKView;
  LController: IKXController;
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

  // LoginView may have Controller: with no type value (properties are children).
  // Default to 'Login' controller type, same as the ExtJS version did.
  if LView.ControllerType = '' then
    LController := TKXControllerFactory.Instance.CreateController(LView, nil, nil, 'Login')
  else
    LController := TKXControllerFactory.Instance.CreateController(LView);
  LController.Display;
  LBodyContent := LController.Render;

  TKWebSession.Current.RefreshingLanguage := False;
  ServeHomePage(LBodyContent);
end;


function TKWebApplication.GetAccessController: TKAccessController;
var
  LType: string;
  LConfig: TEFNode;
  I: Integer;
begin
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
end;

function TKWebApplication.GetAuthenticator: TKAuthenticator;
var
  LType: string;
  LConfig: TEFNode;
  I: Integer;
begin
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

function IsCssColorLight(const AColor: string): Boolean;
var
  LColor, LHex: string;
  R, G, B: Integer;
  LLuminance: Double;
  LColorMap: TDictionary<string, string>;
begin
  LColor := LowerCase(Trim(AColor));
  LHex := '';

  // Handle hex colors directly
  if (LColor <> '') and (LColor[1] = '#') then
    LHex := LColor
  else
  begin
    // Map common CSS named colors to hex for luminance computation
    LColorMap := TDictionary<string, string>.Create;
    try
      // Yellows / Golds
      LColorMap.Add('gold', '#FFD700');
      LColorMap.Add('yellow', '#FFFF00');
      LColorMap.Add('khaki', '#F0E68C');
      LColorMap.Add('darkkhaki', '#BDB76B');
      LColorMap.Add('goldenrod', '#DAA520');
      LColorMap.Add('darkgoldenrod', '#B8860B');
      // Oranges
      LColorMap.Add('orange', '#FFA500');
      LColorMap.Add('darkorange', '#FF8C00');
      LColorMap.Add('coral', '#FF7F50');
      LColorMap.Add('tomato', '#FF6347');
      LColorMap.Add('orangered', '#FF4500');
      // Reds
      LColorMap.Add('red', '#FF0000');
      LColorMap.Add('crimson', '#DC143C');
      LColorMap.Add('firebrick', '#B22222');
      LColorMap.Add('darkred', '#8B0000');
      LColorMap.Add('maroon', '#800000');
      // Pinks
      LColorMap.Add('pink', '#FFC0CB');
      LColorMap.Add('hotpink', '#FF69B4');
      LColorMap.Add('deeppink', '#FF1493');
      LColorMap.Add('salmon', '#FA8072');
      LColorMap.Add('lightsalmon', '#FFA07A');
      // Purples
      LColorMap.Add('purple', '#800080');
      LColorMap.Add('indigo', '#4B0082');
      LColorMap.Add('darkviolet', '#9400D3');
      LColorMap.Add('darkorchid', '#9932CC');
      LColorMap.Add('mediumpurple', '#9370DB');
      LColorMap.Add('slateblue', '#6A5ACD');
      LColorMap.Add('darkslateblue', '#483D8B');
      LColorMap.Add('violet', '#EE82EE');
      LColorMap.Add('plum', '#DDA0DD');
      LColorMap.Add('magenta', '#FF00FF');
      LColorMap.Add('fuchsia', '#FF00FF');
      // Blues
      LColorMap.Add('blue', '#0000FF');
      LColorMap.Add('darkblue', '#00008B');
      LColorMap.Add('navy', '#000080');
      LColorMap.Add('midnightblue', '#191970');
      LColorMap.Add('royalblue', '#4169E1');
      LColorMap.Add('dodgerblue', '#1E90FF');
      LColorMap.Add('steelblue', '#4682B4');
      LColorMap.Add('cornflowerblue', '#6495ED');
      LColorMap.Add('deepskyblue', '#00BFFF');
      LColorMap.Add('lightblue', '#ADD8E6');
      LColorMap.Add('lightskyblue', '#87CEFA');
      // Greens
      LColorMap.Add('green', '#008000');
      LColorMap.Add('darkgreen', '#006400');
      LColorMap.Add('forestgreen', '#228B22');
      LColorMap.Add('seagreen', '#2E8B57');
      LColorMap.Add('olive', '#808000');
      LColorMap.Add('olivedrab', '#6B8E23');
      LColorMap.Add('darkolivegreen', '#556B2F');
      LColorMap.Add('teal', '#008080');
      LColorMap.Add('darkcyan', '#008B8B');
      LColorMap.Add('lime', '#00FF00');
      LColorMap.Add('limegreen', '#32CD32');
      LColorMap.Add('lightgreen', '#90EE90');
      LColorMap.Add('springgreen', '#00FF7F');
      LColorMap.Add('aqua', '#00FFFF');
      LColorMap.Add('cyan', '#00FFFF');
      LColorMap.Add('turquoise', '#40E0D0');
      // Browns
      LColorMap.Add('brown', '#A52A2A');
      LColorMap.Add('saddlebrown', '#8B4513');
      LColorMap.Add('sienna', '#A0522D');
      LColorMap.Add('chocolate', '#D2691E');
      LColorMap.Add('peru', '#CD853F');
      LColorMap.Add('tan', '#D2B48C');
      LColorMap.Add('sandybrown', '#F4A460');
      // Grays
      LColorMap.Add('black', '#000000');
      LColorMap.Add('dimgray', '#696969');
      LColorMap.Add('gray', '#808080');
      LColorMap.Add('darkgray', '#A9A9A9');
      LColorMap.Add('silver', '#C0C0C0');
      LColorMap.Add('lightgray', '#D3D3D3');
      LColorMap.Add('white', '#FFFFFF');
      LColorMap.Add('slategray', '#708090');
      LColorMap.Add('darkslategray', '#2F4F4F');

      if not LColorMap.TryGetValue(LColor, LHex) then
      begin
        Result := False; // Unknown color name: assume dark (safe for white text)
        Exit;
      end;
    finally
      LColorMap.Free;
    end;
  end;

  // Parse hex to RGB
  if Length(LHex) = 4 then // #RGB shorthand
  begin
    R := StrToIntDef('$' + LHex[2] + LHex[2], 0);
    G := StrToIntDef('$' + LHex[3] + LHex[3], 0);
    B := StrToIntDef('$' + LHex[4] + LHex[4], 0);
  end
  else if Length(LHex) >= 7 then // #RRGGBB
  begin
    R := StrToIntDef('$' + Copy(LHex, 2, 2), 0);
    G := StrToIntDef('$' + Copy(LHex, 4, 2), 0);
    B := StrToIntDef('$' + Copy(LHex, 6, 2), 0);
  end
  else
  begin
    Result := False;
    Exit;
  end;

  // Perceived luminance (ITU-R BT.601)
  LLuminance := 0.299 * R + 0.587 * G + 0.114 * B;
  Result := LLuminance > 160;
end;

procedure TKWebApplication.ServeHomePage(const ABodyContent: string);
var
  LPageHtml: string;
  LTemplatePath: string;
  LIconLink: string;
  LAppleIconLink: string;
  LManifestLink: string;
  LLoadingImageURL: string;
  LTheme: string;
  LThemeAttr: string;
  LThemeNode: TEFNode;
  LPrimaryColor, LFontFamily, LFontSize: string;
  LThemeStyle: string;
  LChromeText, LChromeBlock, LFontBlock: string;
begin
  // Build data-theme attribute from Config Theme setting
  LTheme := LowerCase(Config.Config.GetString('Theme', 'Auto'));
  if LTheme = 'light' then
    LThemeAttr := ' data-theme="light"'
  else if LTheme = 'dark' then
    LThemeAttr := ' data-theme="dark"'
  else
    LThemeAttr := ''; // 'auto' or unset: no attribute, CSS @media handles it

  // Build theme style overrides from Config Theme sub-nodes
  LThemeStyle := '';
  // Set icon style and default size from Theme config
  LThemeNode := Config.Config.FindNode('Theme');
  if Assigned(LThemeNode) then
  begin
    SetIconStyle(LThemeNode.GetString('IconStyle', 'filled'));
    SetDefaultIconSize(LThemeNode.GetString('IconSize', 'Medium'));
  end
  else
  begin
    SetIconStyle('filled');
    SetDefaultIconSize('Medium');
  end;

  if Assigned(LThemeNode) then
  begin
    LPrimaryColor := LThemeNode.GetString('Primary-Color');
    LFontFamily := LThemeNode.GetString('Font-Family');
    LFontSize := LThemeNode.GetString('Font-Size');

    if (LPrimaryColor <> '') or (LFontFamily <> '') or (LFontSize <> '') then
    begin
      // Font overrides (theme-independent, only in :root)
      LFontBlock := '';
      if LFontFamily <> '' then
        LFontBlock := LFontBlock +
          '--kx-font:"' + LFontFamily + '",sans-serif;';
      if LFontSize <> '' then
        LFontBlock := LFontBlock +
          '--kx-font-size:' + LFontSize + ';';

      // Chrome/accent block (shared between light and dark themes)
      LChromeBlock := '';
      if LPrimaryColor <> '' then
      begin
        // Determine chrome text color based on primary color luminance
        if IsCssColorLight(LPrimaryColor) then
          LChromeText := '#1a1a1a' // Dark text for light chrome backgrounds
        else
          LChromeText := '#ecf0f1'; // Light text for dark chrome backgrounds
        LChromeBlock :=
          // Chrome palette derived from Primary-Color via color-mix()
          '--kx-chrome:' + LPrimaryColor + ';' +
          '--kx-chrome-dark:color-mix(in srgb,' + LPrimaryColor + ',black 25%);' +
          '--kx-chrome-hover:color-mix(in srgb,' + LPrimaryColor + ',white 15%);' +
          '--kx-chrome-mid:color-mix(in srgb,' + LPrimaryColor + ',white 22%);' +
          '--kx-chrome-light:color-mix(in srgb,' + LPrimaryColor + ',white 30%);' +
          '--kx-chrome-text:' + LChromeText + ';' +
          '--kx-chrome-btn-hover:' + IfThen(LChromeText = '#ecf0f1',
            'rgba(255,255,255,0.15)', 'rgba(0,0,0,0.10)') + ';' +
          // Status bar follows chrome
          '--kx-status-bg:color-mix(in srgb,' + LPrimaryColor + ',black 25%);' +
          '--kx-status-text:' + LChromeText + ';' +
          '--kx-status-border:color-mix(in srgb,' + LPrimaryColor + ',black 40%);' +
          // Accent = primary color
          '--kx-accent:' + LPrimaryColor + ';' +
          '--kx-accent-bg:color-mix(in srgb,' + LPrimaryColor + ',white 85%);' +
          '--kx-accent-ring:color-mix(in srgb,' + LPrimaryColor + ' 15%,transparent);';
      end;

      // :root block — light theme: font + chrome + page text derived from primary
      LThemeStyle := '<style>:root{' + LFontBlock + LChromeBlock;
      if LPrimaryColor <> '' then
        LThemeStyle := LThemeStyle +
          // Page text derived from primary (very dark shade) — light theme only
          '--kx-text:color-mix(in srgb,' + LPrimaryColor + ',black 60%);' +
          '--kx-text-secondary:color-mix(in srgb,' + LPrimaryColor + ',black 40%);' +
          '--kx-text-muted:color-mix(in srgb,' + LPrimaryColor + ',black 20%);' +
          // Tree text follows page text
          '--kx-tree-folder-text:color-mix(in srgb,' + LPrimaryColor + ',black 60%);' +
          '--kx-tree-leaf-text:color-mix(in srgb,' + LPrimaryColor + ',black 60%);';
      LThemeStyle := LThemeStyle + '}';

      // Dark theme blocks — higher specificity, chrome+accent only (no page text override)
      if LChromeBlock <> '' then
        LThemeStyle := LThemeStyle +
          // Explicit dark: html[data-theme="dark"] (specificity 0,1,1 > 0,1,0)
          'html[data-theme="dark"]{' + LChromeBlock + '}' +
          // Auto dark: same overrides within prefers-color-scheme media query
          '@media(prefers-color-scheme:dark){:root:not([data-theme]){' + LChromeBlock + '}}';

      LThemeStyle := LThemeStyle + '</style>';
    end;
  end;

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

function TKWebApplication.FindPageTemplate(const APageName: string): string;
var
  LFileName: string;
begin
  LFileName := FindResourcePathName(APageName + '.html');
  if LFileName <> '' then
  begin
    Result := TextFileToString(LFileName, TKWebResponse.Current.Items.Encoding);
    TEFMacroExpansionEngine.Instance.Expand(Result);
  end;
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

function TKWebApplication.GetPageTemplate(const APageName: string): string;
begin
  Result := FindPageTemplate(APageName);
  if Result = '' then
    raise Exception.CreateFmt('Template not found for page %s', [APageName]);
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
