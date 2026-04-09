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

unit Kitto.Config;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Types,
  System.Generics.Collections,
  EF.Tree,
  EF.Macros,
  EF.Classes,
  EF.DB,
  EF.ObserverIntf,
  EF.YAML.Attributes,
  Kitto.Auth,
  Kitto.Metadata.Models,
  Kitto.Metadata.Views,
  Kitto.Metadata.SubNodes;

type
  TKConfigMacroExpander = class;

  TKConfig = class;

  TKConfigClass = class of TKConfig;

  TKGetConfig = reference to function: TKConfig;

  TKConfigGetAppNameEvent = procedure (out AAppName: string) of object;

  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKConfig = class(TEFComponent)
  strict private
  class var
    FAppHomePath: string;
    FAppName: string;
    FJSFormatSettings: TFormatSettings;
    FBaseConfigFileName: string;
    FOnGetInstance: TKGetConfig;
    FInstance: TKConfig;
    FSystemHomePath: string;
    FConfigClass: TKConfigClass;
    FOnGetAppName: TKConfigGetAppNameEvent;
  var
    FMacroExpansionEngine: TEFMacroExpansionEngine;
    FModels: TKModels;
    FViews: TKViews;
    FUserFormatSettings: TFormatSettings;

    class function GetInstance: TKConfig; static;
    class function GetAppName: string; static;
    class function GetAppHomePath: string; static;
    class procedure SetAppHomePath(const AValue: string); static;
    class function GetSystemHomePath: string; static;
    class procedure SetSystemHomePath(const AValue: string); static;
    class function GetDatabase: TEFDBConnection; static;

    function GetDBConnectionNames: TStringDynArray;
    function GetMultiFieldSeparator: string;
    function GetDBAdapter(const ADatabaseName: string): TEFDBAdapter;
    function GetMacroExpansionEngine: TEFMacroExpansionEngine;
    function GetAppTitle: string;
    function GetAppIcon: string;
    function GetModels: TKModels;
    function GetViews: TKViews;
    function GetDefaultDatabaseName: string;
    function GetDatabaseName: string;
    function GetLanguagePerSession: Boolean;
    function GetFOPEnginePath: string;
    function GetUseAltLanguage: Boolean;
    function GetServer: TKServerConfig;
    function GetAuth: TKAuthConfig;
    function GetAccessControl: TKAccessControlConfig;
    function GetUserFormats: TKUserFormatsConfig;
    function GetLogTextFile: TKLogTextFileConfig;
    function GetDesktop: TKDesktopConfig;
  strict protected
    function GetUploadPath: string;
    function GetConfigFileName: string; override;
    class function FindSystemHomePath: string;
  public
    /// <summary>Returns the directory of the current module (DLL) or executable.
    /// For ISAPI/Apache DLLs returns the DLL path; for EXEs same as ParamStr(0) path.</summary>
    class function GetModulePath: string; static;
    class procedure DestroyInstance;
    procedure AfterConstruction; override;
    destructor Destroy; override;
    class constructor Create;
    class destructor Destroy;
    procedure UpdateObserver(const ASubject: IEFSubject;
      const AContext: string = ''); override;
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
  public
    class procedure SetConfigClass(const AValue: TKConfigClass);

    class property AppName: string read GetAppName;
    class property OnGetAppName: TKConfigGetAppNameEvent read FOnGetAppName write FOnGetAppName;

    /// <summary>
    ///   <para>Returns or changes the Application Home path.</para>
    ///   <para>The Application Home path defaults to the exe file directory
    ///   unless specified through the '-home' command line argument.</para>
    ///   <para>Setting this property, if necessary, should be done at
    ///   application startup, preferably in a unit's initialization
    ///   section.</para>
    /// </summary>
    /// <remarks>Changing this property affects all TKConfg instances created
    /// from that point on, not existing instances.</remarks>
    class property AppHomePath: string read GetAppHomePath write SetAppHomePath;

    /// <summary>
    ///   <para>Returns or changes the System Home path, which is used to find
    ///   any resources that are not found in the Application Home path.
    ///   Generally, the System Home path contains all predefined metadata and
    ///   resources of the framework.</para>
    ///   <para>The System Home path defaults to a "Home" directory inside a
    ///   nearby directory named "KittoX". The following paths, relative to the
    ///   executable directory, are searched in order:</para>
    ///   <list type="number">
    ///     <item>..\Externals\KittoX\Home\</item>
    ///     <item>..\..\ext\KittoX\Home\</item>
    ///     <item>..\..\Externals\KittoX\Home\</item>
    ///     <item>..\..\..\KittoX\Home\</item>
    ///     <item>..\..\..\..\KittoX\Home\</item>
    ///     <item>%KITTOX%\Home\</item>
    ///   </list>
    ///   <para>The first existing path is used. If none of these exist, the
    ///   value of AppHomePath is assumed.</para>
    ///   <para>If no default is suitable for your application, you can set
    ///   this property at application startup, preferably in a unit's
    ///   initialization section. If you also need to set AppHomePath, do it
    ///   <b>before</b> setting this property.</para>
    /// </summary>
    /// <remarks>Changing this property affects all TKConfg instances created
    /// from that point on, not existing instances.</remarks>
    class property SystemHomePath: string read GetSystemHomePath write SetSystemHomePath;

    /// <summary>
    ///   Returns the full path of the Metadata directory inside the home path.
    /// </summary>
    class function GetMetadataPath: string;

    /// <summary>
    ///  Format settings for Javascript/JSON data encoded in text format. use
    ///  it, don't change it.
    /// </summary>
    class property JSFormatSettings: TFormatSettings read FJSFormatSettings;

    /// <summary>
    ///  Name of the config file. Defaults to Config.yaml. Changing this
    ///  property only affects instances created afterwards.
    /// </summary>
    class property BaseConfigFileName: string read FBaseConfigFileName write FBaseConfigFileName;

    /// <summary>
    ///  Sets a?global function that returns the global config object. In web
    ///  applications there will be a config object per session.
    /// </summary>
    class property OnGetInstance: TKGetConfig read FOnGetInstance write FOnGetInstance;

    /// <summary>
    ///  Returns a singleton instance.
    /// </summary>
    class property Instance: TKConfig read GetInstance;

    /// <summary>
    ///   Returns the database instance.
    /// </summary>
    class property Database: TEFDBConnection read GetDatabase;

    /// <summary>
    ///  A reference to the model catalog, opened on first access.
    /// </summary>
    property Models: TKModels read GetModels;

    /// <summary>
    ///  A reference to the view catalog, opened on first access.
    /// </summary>
    property Views: TKViews read GetViews;

    /// <summary>Makes sure catalogs are recreated at next access.</summary>
    procedure InvalidateCatalogs;

    /// <summary>
    ///  Returns the names of all defined database
    ///  connections.
    /// </summary>
    property DBConnectionNames: TStringDynArray read GetDBConnectionNames;

    /// <summary>
    ///  Creates a DB connection for the specified configured database.
    ///  The caller is responsible for the life cycle of the object.
    /// </summary>
    function CreateDBConnection(const ADatabaseName: string): TEFDBConnection;
    /// <summary>
    ///  Helper function that creates a DB connection, passes it to an anonymous method
    ///  then destroys it. Use it for DB read access and single update instructions.
    ///  For multiple update instructions please use <seealso>InDBTransaction</seealso>.
    /// </summary>
    procedure InDBConnection(const ADatabaseName: string; const AProc: TProc<TEFDBConnection>);
    /// <summary>
    ///  Helper function that creates a DB connection, starts a transaction and calls
    ///  the specified anonymous method. If the method raises an exception, then the
    ///  transaction is rolled back (and the exception is propagated), otherwise
    ///  it's committed after the method returns.
    ///  Finally, the connection object is destroyed. Use this method for multiple
    ///  update statements that need to be enclosed in a single database transaction.
    ///  For read operations or single update operations, please use <seealso>InDBConnection</seealso>.
    ///  then destroys it. Use it for DB read access and single update instructions.
    ///  For multiple update instructions please use <seealso>InDBTransaction</seealso>.
    /// </summary>
    procedure InDBTransaction(const ADatabaseName: string; const AProc: TProc<TEFDBConnection>);
    /// <summary>
    ///  Helper function that creates a DB connection, returns the value of the
    ///  connection's GetSingletonValue method, then destroys it.
    /// </summary>
    function GetDBSingletonValue(const ADatabaseName, ASQLStatement: string): Variant;

    /// <summary>Default DatabaseName to use when not specified elsewhere. Can
    /// be set through the DatabaseRouter/DatabaseName node or through the
    /// DefaultDatabaseName node.</summary>
    [YamlNode('DefaultDatabaseName', 'Main', 'Default database connection name')]
    property DatabaseName: string read GetDatabaseName;

    /// <summary>
    ///  Returns the application title, to be used for captions, about
    ///  boxes, etc.
    /// </summary>
    [YamlNode('AppTitle', 'Kitto', 'Application title for captions and about boxes')]
    property AppTitle: string read GetAppTitle;

    /// <summary>
    ///  Returns the application Icon, to be used mobile apps
    ///  and Browser
    /// </summary>
    [YamlNode('AppIcon', 'kitto_128', 'Application icon name for browser and mobile')]
    property AppIcon: string read GetAppIcon;

    /// <summary>
    ///  Global expansion engine. Kitto-specific macro expanders should be
    ///  added here at run time. This engine is chained to the default engine,
    ///  so all default EF macros are supported.
    /// </summary>
    /// <summary>
    ///  Reads help configuration from Defaults/Help node.
    ///  AShowLink is True if HRef is configured (non-empty).
    /// </summary>
    procedure GetHelpSupport(out AShowLink: Boolean;
      out AHRef, AHRefStyle, AShortText, ALongText: string);

    property MacroExpansionEngine: TEFMacroExpansionEngine read GetMacroExpansionEngine;

    property UserFormatSettings: TFormatSettings read FUserFormatSettings;

    [YamlNode('MultiFieldSeparator', '~', 'Separator for multi-field composite keys')]
    property MultiFieldSeparator: string read GetMultiFieldSeparator;

    [YamlNode('LanguagePerSession', 'False', 'Allow language selection per session')]
    property LanguagePerSession: Boolean read GetLanguagePerSession;

    [YamlNode('UseAltLanguage', 'False', 'Enable alternate language for localizable labels')]
    property UseAltLanguage: Boolean read GetUseAltLanguage;

    /// <summary>
    ///   <para>Returns or changes the home path for FOP engine.</para>
    /// </summary>
    [YamlNode('FOPEnginePath', 'Path to Apache FOP engine for PDF generation')]
    property FOPEnginePath: string read GetFOPEnginePath;

    /// <summary>
    ///   <para>Returns or changes the Upload path accessible via %UPLOAD_PATH% macro.</para>
    /// </summary>
    [YamlNode('UploadPath', 'Directory for uploaded files (expands %HOME_PATH%)')]
    property UploadPath: string read GetUploadPath;

    [YamlSubNode('Server', TKServerConfig, 'HTTP server settings (Port, SessionTimeOut, ThreadPoolSize)')]
    property Server: TKServerConfig read GetServer;

    [YamlSubNode('Auth', TKAuthConfig, 'Authentication settings')]
    property Auth: TKAuthConfig read GetAuth;

    [YamlSubNode('AccessControl', TKAccessControlConfig, 'Access control settings (SQL commands)')]
    property AccessControl: TKAccessControlConfig read GetAccessControl;

    [YamlSubNode('UserFormats', TKUserFormatsConfig, 'User date/time format overrides')]
    property UserFormats: TKUserFormatsConfig read GetUserFormats;

    [YamlSubNode('Log/TextFile', TKLogTextFileConfig, 'Text file logging settings')]
    property LogTextFile: TKLogTextFileConfig read GetLogTextFile;

    [YamlSubNode('Desktop', TKDesktopConfig, 'Desktop embedded mode settings (window size, position, border icons)')]
    property Desktop: TKDesktopConfig read GetDesktop;

    /// <summary>Access to the current authenticator. Delegates to
    /// TKWebApplication.Current.Authenticator for backward compatibility
    /// with Kitto 1/2 code that used TKConfig.Instance.Authenticator.</summary>
    function Authenticator: TKAuthenticator;
  end;

  /// <summary>
  ///   <para>
  ///     A macro expander that can expand globally available macros.
  ///   </para>
  ///   <para>
  ///     %HOME_PATH% = TKConfig.Instance.GetAppHomePath.
  ///   </para>
  ///   <para>
  ///     It also expands any macros in the Config namespace to the
  ///     corresponding environment config string. Example:
  ///   </para>
  ///   <para>
  ///     %Config:AppTitle% = The string value of the AppTitle node in
  ///     Config.yaml.
  ///   </para>
  /// </summary>
  TKConfigMacroExpander = class(TEFTreeMacroExpander)
  strict private
    FConfig: TKConfig;
  strict protected
    property Config: TKConfig read FConfig;
    procedure InternalExpand(var AString: string); override;
  public
    constructor Create(const AConfig: TKConfig); reintroduce;
  end;

implementation

uses
  System.StrUtils,
  System.Variants,
  System.IOUtils,
  EF.Sys,
  EF.StrUtils,
  EF.YAML,
  EF.Localization,
  Kitto.Web.Application,
  Kitto.Types,
  Kitto.DatabaseRouter;

procedure TKConfig.AfterConstruction;
var
  LDecimalSeparator: string;
  LThousandSeparator: string;
begin
  inherited;
  { TODO : allow to change format settings on a per-user basis. }
  FUserFormatSettings := FormatSettings.Create;

  FUserFormatSettings.ShortTimeFormat := Config.GetString('UserFormats/Time', FUserFormatSettings.ShortTimeFormat);
  if Pos('.', FUserFormatSettings.ShortTimeFormat) > 0 then
    FUserFormatSettings.TimeSeparator := '.'
  else
    FUserFormatSettings.TimeSeparator := ':';

  FUserFormatSettings.ShortDateFormat := Config.GetString('UserFormats/Date', FUserFormatSettings.ShortDateFormat);
  if Pos('.', FUserFormatSettings.ShortDateFormat) > 0 then
    FUserFormatSettings.DateSeparator := '.'
  else if Pos('-', FUserFormatSettings.ShortDateFormat) > 0 then
    FUserFormatSettings.DateSeparator := '-'
  else
    FUserFormatSettings.DateSeparator := '/';

  LDecimalSeparator := Config.GetString('UserFormats/Decimal', '');
  if LDecimalSeparator <> '' then
    FUserFormatSettings.DecimalSeparator := LDecimalSeparator[1];

  LThousandSeparator := Config.GetString('UserFormats/Thousand', '');
  if LThousandSeparator <> '' then
    FUserFormatSettings.ThousandSeparator := LThousandSeparator[1];

  FUserFormatSettings.CurrencyString :=
    Config.GetString('UserFormats/Currency', FUserFormatSettings.CurrencyString);

  //Set also global FormatSettings variable
  FormatSettings := FUserFormatSettings;
end;

destructor TKConfig.Destroy;
begin
  inherited;
  FreeAndNil(FViews);
  FreeAndNil(FModels);
  FreeAndNil(FMacroExpansionEngine);
end;

function TKConfig.Authenticator: TKAuthenticator;
begin
  Result := TKWebApplication.Current.Authenticator;
end;

procedure TKConfig.UpdateObserver(const ASubject: IEFSubject;
  const AContext: string);
begin
  inherited;
  NotifyObservers(AContext);
end;

procedure TKConfig.InDBConnection(const ADatabaseName: string; const AProc: TProc<TEFDBConnection>);
var
  LDBConnection: TEFDBConnection;
begin
  Assert(Assigned(AProc));

  LDBConnection := CreateDBConnection(ADatabaseName);
  try
    AProc(LDBConnection);
  finally
    FreeAndNil(LDBConnection);
  end;
end;

procedure TKConfig.InDBTransaction(const ADatabaseName: string; const AProc: TProc<TEFDBConnection>);
begin
  InDBConnection(ADatabaseName,
    procedure (ADBConnection: TEFDBConnection)
    begin
      ADBConnection.StartTransaction;
      try
        AProc(ADBConnection);
        ADBConnection.CommitTransaction;
      except
        ADBConnection.RollbackTransaction;
        raise;
      end;
    end);
end;

procedure TKConfig.InvalidateCatalogs;
begin
  FreeAndNil(FViews);
  FreeAndNil(FModels);
end;

function TKConfig.CreateDBConnection(const ADatabaseName: string): TEFDBConnection;
var
  LConfig: TEFNode;
begin
  Result := GetDBAdapter(ADatabaseName).CreateDBConnection;
  try
    Result.Config.AddChild(TEFNode.Clone(Config.GetNode('Databases/' + ADatabaseName + '/Connection')));
    LConfig := Config.FindNode('Databases/' + ADatabaseName + '/Config');
    if Assigned(LConfig) then
      Result.Config.AddChild(TEFNode.Clone(LConfig));
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TKConfig.GetDBConnectionNames: TStringDynArray;
var
  LNode: TEFNode;
begin
  LNode := Config.FindNode('Databases');
  if Assigned(LNode) then
    Result := LNode.GetChildNames
  else
    Result := nil;
end;

function TKConfig.GetDBSingletonValue(const ADatabaseName, ASQLStatement: string): Variant;
var
  LResult: Variant;
begin
  InDBConnection(ADatabaseName,
    procedure (ADBConnection: TEFDBConnection)
    begin
      LResult := ADBConnection.GetSingletonValue(ASQLStatement);
    end);
  Result := LResult;
end;

function TKConfig.GetDatabaseName: string;
var
  LDatabaseRouterNode: TEFNode;
begin
  LDatabaseRouterNode := Config.FindNode('DatabaseRouter');
  if Assigned(LDatabaseRouterNode) then
    Result := TKDatabaseRouterFactory.Instance.GetDatabaseName(
      LDatabaseRouterNode.AsString, Self, LDatabaseRouterNode)
  else
    Result := GetDefaultDatabaseName;
end;

function TKConfig.GetDefaultDatabaseName: string;
begin
  Result := Config.GetExpandedString('DefaultDatabaseName', 'Main');
end;

function TKConfig.GetFOPEnginePath: string;
begin
  Result := Config.GetExpandedString('FOPEnginePath');
end;

function TKConfig.GetDBAdapter(const ADatabaseName: string): TEFDBAdapter;
var
  LDbAdapterKey: string;
begin
  Try
    LDbAdapterKey := Config.GetExpandedString('Databases/' + ADatabaseName);
    Result := TEFDBAdapterRegistry.Instance[LDbAdapterKey];
  except
    raise EKError.CreateFmt(_('DB connection type "%s" for database "%s" not available'),
      [LDbAdapterKey, ADatabaseName]);
  end;
end;

function TKConfig.GetMacroExpansionEngine: TEFMacroExpansionEngine;
begin
  if not Assigned(FMacroExpansionEngine) then
  begin
    FMacroExpansionEngine := TEFMacroExpansionEngine.Create;
    FMacroExpansionEngine.OnGetFormatSettings :=
      function: TFormatSettings
      begin
        Result := UserFormatSettings;
      end;
    AddStandardMacroExpanders(FMacroExpansionEngine);
    FMacroExpansionEngine.AddExpander(TKConfigMacroExpander.Create(Self));
  end;
  Result := FMacroExpansionEngine;
end;

class function TKConfig.GetMetadataPath: string;
begin
  Result := GetAppHomePath + IncludeTrailingPathDelimiter('Metadata');
end;

function TKConfig.GetModels: TKModels;
begin
  if not Assigned(FModels) then
  begin
    FModels := TKModels.Create;
    FModels.AttachObserver(Self);
    FModels.Path := GetMetadataPath + 'Models';
    FModels.Open;
  end;
  Result := FModels;
end;

function TKConfig.GetMultiFieldSeparator: string;
begin
  Result := Config.GetString('MultiFieldSeparator', '~');
end;

class function TKConfig.GetSystemHomePath: string;
begin
  if FSystemHomePath <> '' then
    Result := FSystemHomePath
  else
    Result := FindSystemHomePath;
  Result := IncludeTrailingPathDelimiter(Result);
end;

function TKConfig.GetUploadPath: string;
begin
  Result := Config.GetExpandedString('UploadPath');
end;

function TKConfig.GetUseAltLanguage: Boolean;
begin
  Result := Config.GetBoolean('UseAltLanguage', False);
end;

function TKConfig.GetViews: TKViews;
begin
  if not Assigned(FViews) then
  begin
    FViews := TKViews.Create(Models);
    FViews.AttachObserver(Self);
    FViews.Layouts.AttachObserver(Self);
    FViews.Path := GetMetadataPath + 'Views';
    FViews.Open;
  end;
  Result := FViews;
end;

class constructor TKConfig.Create;
var
  LAppName: string;
  LDefaultConfig: string;
begin
  LAppName := ChangeFileExt(ExtractFileName(GetModuleName(HInstance)),'');
  FConfigClass := TKConfig;
  LDefaultConfig := Format('Config_%s.yaml',[LAppName]);
  if FileExists(GetMetadataPath + LDefaultConfig) then
    FBaseConfigFileName := LDefaultConfig
  else
    FBaseConfigFileName := 'Config.yaml';

  FJSFormatSettings := TFormatSettings.Create;
  FJSFormatSettings.DecimalSeparator := '.';
  FJSFormatSettings.ThousandSeparator := ',';
  FJSFormatSettings.ShortDateFormat := 'yyyy/mm/dd';
  FJSFormatSettings.ShortTimeFormat := 'hh:nn:ss';
  FJSFormatSettings.DateSeparator := '/';
  FJSFormatSettings.TimeSeparator := ':';
  TEFYAMLReader.FormatSettings := FJSFormatSettings;
end;

class destructor TKConfig.Destroy;
begin
  FreeAndNil(FInstance);
end;

function TKConfig.GetAppTitle: string;
begin
  Result := Config.GetString('AppTitle', 'Kitto');
end;

procedure TKConfig.GetHelpSupport(out AShowLink: Boolean;
  out AHRef, AHRefStyle, AShortText, ALongText: string);
begin
  AHRef := Config.GetExpandedString('Defaults/Help/HRef', '');
  AHRefStyle := Config.GetExpandedString('Defaults/Help/HRefStyle', 'font-size: small');
  AShortText := Config.GetExpandedString('Defaults/Help/ShortText', _('Help...'));
  ALongText := Config.GetExpandedString('Defaults/Help/LongText', _('Help guide for "%s"...'));
  AShowLink := AHRef <> '';
end;

function TKConfig.GetConfigFileName: string;
begin
  Result := TPath.Combine(GetMetadataPath, FBaseConfigFileName);
end;

function TKConfig.GetAppIcon: string;
begin
  Result := Config.GetString('AppIcon', 'kitto_128');
end;

class function TKConfig.GetInstance: TKConfig;
begin
  Result := nil;
  if Assigned(FOnGetInstance) then
    Result := FOnGetInstance();
  if not Assigned(Result) then
  begin
    if not Assigned(FInstance) then
      FInstance := FConfigClass.Create;
    Result := FInstance;
  end;
end;

class function TKConfig.GetDatabase: TEFDBConnection;
begin
  Result := TKConfig.Instance.CreateDBConnection(TKConfig.Instance.DatabaseName);
end;

function TKConfig.GetLanguagePerSession: Boolean;
begin
  Result := Config.GetBoolean('LanguagePerSession', False);
end;

class procedure TKConfig.SetAppHomePath(const AValue: string);
begin
  FAppHomePath := AValue;
end;

class procedure TKConfig.SetConfigClass(const AValue: TKConfigClass);
begin
  FConfigClass := AValue;
end;

class procedure TKConfig.SetSystemHomePath(const AValue: string);
begin
  FSystemHomePath := AValue;
end;

class function TKConfig.GetAppName: string;
var
  LConfig: TKConfig;
begin
  if FAppName <> '' then
    Exit(FAppName);

  Result := '';
  if Assigned(FOnGetAppName) then
    FOnGetAppName(Result);

  if Result = '' then
    Result := GetCmdLineParamValue('appname');

  if Result = '' then
  begin
    LConfig := TKConfig.Create;
    try
      Result := LConfig.Config.GetString('AppName', '');
    finally
      FreeAndNil(LConfig);
    end;
  end;

  if Result = '' then
    Result := ChangeFileExt(ExtractFileName(GetModuleName(HInstance)), '');

  FAppName := Result;
end;

class function TKConfig.GetModulePath: string;
begin
  // For DLLs (ISAPI), HInstance points to the DLL, not the host exe.
  // For EXEs, HInstance = MainInstance = ParamStr(0).
  Result := ExtractFilePath(GetModuleName(HInstance));
  // Strip the \\?\ long path prefix that Windows may add for ISAPI DLLs
  if Result.StartsWith('\\?\') then
    Result := Copy(Result, 5, MaxInt);
end;

class function TKConfig.GetAppHomePath: string;
var
  LEnvPath: string;
begin
  if FAppHomePath = '' then
  begin
    // 1. Command line: -home <path>
    FAppHomePath := GetCmdLineParamValue('home', '');
    // 2. Environment variable: KITTOX_APP_HOME
    if FAppHomePath = '' then
    begin
      LEnvPath := GetEnvironmentVariable('KITTOX_APP_HOME');
      if (LEnvPath <> '') and DirectoryExists(LEnvPath) then
        FAppHomePath := LEnvPath;
    end;
    // 3. Default: module/executable directory
    if FAppHomePath = '' then
      FAppHomePath := GetModulePath;
    if not IsAbsolutePath(FAppHomePath) then
      FAppHomePath := GetModulePath + FAppHomePath;
  end;
  Result := IncludeTrailingPathDelimiter(FAppHomePath);
end;

function TKConfig.FindResourcePathName(const AResourceFileName: string): string;
begin
  Result := TPath.Combine(AppHomePath, 'Resources') + PathDelim + StripPrefix(AResourceFileName, PathDelim);
  if not FileExists(Result) then
    Result := TPath.Combine(SystemHomePath, 'Resources') + PathDelim + StripPrefix(AResourceFileName, PathDelim);
  if not FileExists(Result) then
    Result := '';
end;

class function TKConfig.FindSystemHomePath: string;
var
  LExePath: string;

  function TryPath(const ARelPath: string): Boolean;
  begin
    Result := DirectoryExists(LExePath + ARelPath);
    if Result then
      FindSystemHomePath := LExePath + ARelPath;
  end;

begin
  LExePath := GetModulePath;

  // Development layouts (exe alongside the KittoX source tree)
  if TryPath('..\Externals\KittoX\Home\') then Exit;
  if TryPath('..\..\ext\KittoX\Home\') then Exit;
  if TryPath('..\..\Externals\KittoX\Home\') then Exit;
  if TryPath('..\..\..\KittoX\Home\') then Exit;
  if TryPath('..\..\..\..\KittoX\Home\') then Exit;

  // IIS/ISAPI deploy: DLL in App\{AppName}\Home\, System Home in ..\..\..\Home\
  // e.g. C:\inetpub\KittoX\App\HelloKitto\Home\ → C:\inetpub\KittoX\Home\
  if TryPath('..\..\..\Home\') then Exit;

  // Environment variable
  Result := '%KITTOX%\Home\';
  ExpandEnvironmentVariables(Result);
  if DirectoryExists(Result) then
    Exit;

  // Fallback: App Home is also System Home (merged deployment)
  Result := GetAppHomePath;
end;

class procedure TKConfig.DestroyInstance;
begin
  FreeAndNil(FInstance);
end;

function TKConfig.GetServer: TKServerConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKConfig.GetAuth: TKAuthConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKConfig.GetAccessControl: TKAccessControlConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKConfig.GetUserFormats: TKUserFormatsConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKConfig.GetLogTextFile: TKLogTextFileConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKConfig.GetDesktop: TKDesktopConfig;
begin
  Result := nil; // RTTI discovery only
end;

{ TKConfigMacroExpander }

constructor TKConfigMacroExpander.Create(const AConfig: TKConfig);
begin
  Assert(Assigned(AConfig));

  FConfig := AConfig;
  inherited Create(AConfig.Config, 'Config');
end;

procedure TKConfigMacroExpander.InternalExpand(var AString: string);
const
  IMAGE_MACRO_HEAD = '%IMAGE(';
  MACRO_TAIL = ')%';
  UPLOAD_PATH = '%UPLOAD_PATH%';
var
  LPosHead: Integer;
  LPosTail: Integer;
  LName: string;
  LURL: string;
  LRest: string;
begin
  inherited InternalExpand(AString);
  ExpandMacros(AString, '%HOME_PATH%', TKConfig.AppHomePath);
  ExpandMacros(AString, '%Config.AppName%', FConfig.AppName);
  ExpandMacros(AString, '%Config.AppHomePath%', FConfig.AppHomePath);
  ExpandMacros(AString, '%Config.AppTitle%', FConfig.Instance.AppTitle);
  ExpandMacros(AString, '%Config.AppIcon%', FConfig.AppIcon);
  if Pos(UPLOAD_PATH, AString) > 0 then
    ExpandMacros(AString, UPLOAD_PATH, IncludeTrailingPathDelimiter(Config.UploadPath));

  LPosHead := Pos(IMAGE_MACRO_HEAD, AString);
  if LPosHead > 0 then
  begin
    LPosTail := PosEx(MACRO_TAIL, AString, LPosHead + 1);
    if LPosTail > 0 then
    begin
      LName := Copy(AString, LPosHead + Length(IMAGE_MACRO_HEAD),
        LPosTail - (LPosHead + Length(IMAGE_MACRO_HEAD)));
      LURL := TKWebApplication.Current.GetImageURL(LName);
      LRest := Copy(AString, LPosTail + Length(MACRO_TAIL), MaxInt);
      InternalExpand(LRest);
      Delete(AString, LPosHead, MaxInt);
      Insert(LURL, AString, Length(AString) + 1);
      Insert(LRest, AString, Length(AString) + 1);
    end;
  end;
end;

end.
