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
///  Central configuration for a Kitto application. TKConfig is the singleton
///  that loads Config.yaml, resolves the Application and System home paths,
///  exposes the model and view catalogs, hands out per-thread cached database
///  connections, owns the macro-expansion engine and user/JS format settings,
///  and surfaces the strongly-typed config sub-nodes (Server, Auth, Theme, ...).
/// </summary>
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
  Kitto.Config.Server,
  Kitto.Config.Auth,
  Kitto.Config.Email,
  Kitto.Config.Notifications,
  Kitto.Config.UserFormats,
  Kitto.Config.AccessControl,
  Kitto.Config.Log,
  Kitto.Config.Engine,
  Kitto.Config.Database,
  Kitto.Config.Desktop,
  Kitto.Config.Theme,
  Kitto.Config.Defaults,
  Kitto.Metadata.SubNodes;

const
  /// <summary>Default base path of the REST API, used when Config.yaml does not
  /// set Server/RestBasePath. The single source of truth for the default.</summary>
  KX_DEFAULT_REST_BASE_PATH = '/api/v4';

type
  TKConfigMacroExpander = class;

  TKConfig = class;

  /// <summary>Metaclass reference to TKConfig, used to instantiate the config singleton (see SetConfigClass).</summary>
  TKConfigClass = class of TKConfig;

  /// <summary>Function returning the config instance to use (installed via OnGetInstance, e.g. one per web session).</summary>
  TKGetConfig = reference to function: TKConfig;

  /// <summary>Callback that resolves the application name (installed via OnGetAppName).</summary>
  TKConfigGetAppNameEvent = procedure (out AAppName: string) of object;

  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  /// <summary>
  ///  Application configuration singleton. Reads Config.yaml and gives access
  ///  to home paths, the model/view catalogs, per-thread cached database
  ///  connections (Database/DatabaseFor), the macro-expansion engine, format
  ///  settings and the typed configuration sub-nodes.
  /// </summary>
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
    FServer: TKServerConfig;
    FAuth: TKAuthConfig;
    FEmail: TKEmailConfig;
    FNotifications: TKNotificationsConfig;
    FUserFormats: TKUserFormatsConfig;
    FAccessControl: TKAccessControlConfig;
    FLog: TKLogConfig;
    FEngine: TKEngineConfig;
    FDefaults: TKDefaultsConfig;
    FDesktop: TKDesktopConfig;
    FUserFormatSettings: TFormatSettings;

    // Per-thread cached connections, released by ClearDatabase at end of each
    // unit of work (web request, email thread, etc.). FDatabase is a fast-path
    // slot for the default database (the 99% case); FDatabases holds connections
    // to non-default databases, lazily created on first DatabaseFor() call.
    class threadvar FDatabase: TEFDBConnection;
    class threadvar FDatabases: TObjectDictionary<string, TEFDBConnection>;
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
    function GetRestBasePath: string;
    function GetLanguagePerSession: Boolean;
    function GetFOPEnginePath: string;
    function GetUseAltLanguage: Boolean;
    function GetAppPath: string;
    function GetHandleResources: Boolean;
    function GetCharset: string;
    function GetAjaxTimeout: Integer;
    function GetGoogleMapsApiKey: string;
    function GetEmailSupport: string;
    function GetBlobPath: string;
    function GetApplicationNode: string;
    function GetLanguageId: string;
    function GetDatabaseRouterId: string;
    function GetConfigAppName: string;
    function GetHomeViewName: string;
    function GetHomeSmallViewName: string;
    function GetHomeTinyViewName: string;
    function GetLoginViewName: string;
    function GetServer: TKServerConfig;
    function GetAuth: TKAuthConfig;
    function GetEmail: TKEmailConfig;
    function GetAccessControl: TKAccessControlConfig;
    function GetUserFormats: TKUserFormatsConfig;
    function GetLog: TKLogConfig;
    function GetEngine: TKEngineConfig;
    function GetDefaults: TKDefaultsConfig;
    function GetDesktop: TKDesktopConfig;
    function GetTheme: TKThemeConfig;
    function GetNotifications: TKNotificationsConfig;
  strict protected
    function GetUploadPath: string;
    function GetConfigFileName: string; override;
    class function FindSystemHomePath: string;
  protected
    /// <summary>
    ///  Creates a NEW DB connection for the specified configured database.
    ///  Ownership is transferred to the caller. Application code should NOT
    ///  use this directly: use <see cref="Database" /> or
    ///  <see cref="DatabaseFor" /> to get a cached, per-request connection
    ///  with consistent identity across callers in the same unit of work.
    ///  Exposed as protected for framework internals and for design-time
    ///  tools that subclass TKConfig and genuinely need isolated lifecycle.
    /// </summary>
    function CreateDBConnection(const ADatabaseName: string): TEFDBConnection;
  public
    /// <summary>Returns the directory of the current module (DLL) or executable.
    /// For ISAPI/Apache DLLs returns the DLL path; for EXEs same as ParamStr(0) path.</summary>
    class function GetModulePath: string; static;
    /// <summary>Frees the singleton config instance.</summary>
    class procedure DestroyInstance;
    /// <summary>Builds the per-user format settings from the UserFormats config node.</summary>
    procedure AfterConstruction; override;
    /// <summary>Frees the view and model catalogs and the macro-expansion engine.</summary>
    destructor Destroy; override;
    /// <summary>Reloads the config from disk and refreshes the cached typed config
    /// readers in place (so held references, e.g. Config.Server, stay valid).</summary>
    procedure InvalidateConfig; override;
    /// <summary>Class-level init: picks the default config file name and the JS/JSON format settings.</summary>
    class constructor Create;
    /// <summary>Class-level cleanup: releases cached connections and the singleton instance.</summary>
    class destructor Destroy;
    /// <summary>Observer hook: forwards notifications from watched subjects to this config's observers.</summary>
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
    /// <summary>Sets the class used to instantiate the config singleton (override hook).</summary>
    class procedure SetConfigClass(const AValue: TKConfigClass);

    /// <summary>The application name (derived from the home directory, or via OnGetAppName).</summary>
    class property AppName: string read GetAppName;
    /// <summary>Optional callback to override how the application name is resolved.</summary>
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
    ///   Returns the framework-owned canonical singleton (the one created
    ///   from FConfigClass on first access), bypassing the OnGetInstance
    ///   hook. Use this when you specifically want the configured
    ///   TKConfig subclass instance regardless of whether a redirector
    ///   (e.g. KIDEX's project-config hook, or TKWebApplication's
    ///   per-request hook) is currently installed. The hook-aware
    ///   accessor is `Instance` above.
    /// </summary>
    class function GetCanonicalInstance: TKConfig; static;

    /// <summary>
    ///   Returns the per-thread cached connection for the default database.
    ///   The connection is lazily created on first access and released by
    ///   ClearDatabase at the end of each web request (the engine does it
    ///   automatically). Do NOT FreeAndNil it: the reference is shared by
    ///   all callers inside the same request. Shortcut for DatabaseFor('').
    /// </summary>
    class property Database: TEFDBConnection read GetDatabase;

    /// <summary>
    ///   Returns the per-thread cached connection for the specified database.
    ///   The connection is lazily created on first access and released by
    ///   ClearDatabase at the end of each web request (the engine does it
    ///   automatically). Do NOT FreeAndNil it: the reference is shared by
    ///   all callers inside the same request.
    ///   If ADatabaseName is empty or matches the default database name,
    ///   returns the same instance as the Database property (single cached
    ///   connection per DB per thread).
    /// </summary>
    class function DatabaseFor(const ADatabaseName: string): TEFDBConnection; static;

    /// <summary>
    ///   Releases all per-thread cached database connections, if any.
    ///   Called by the web engine at the end of each request. Non-web
    ///   entry points (background threads, console tools) must call this
    ///   at the end of their unit of work.
    /// </summary>
    class procedure ClearDatabase;

    /// <summary>
    ///   Creates a NEW, isolated DB connection for the specified database.
    ///   The caller OWNS the result and is responsible for FreeAndNil'ing it.
    ///   Use ONLY when the cached-per-request contract of Database / DatabaseFor
    ///   is unsuitable. Typical legitimate cases:
    ///     - Authentication with dynamic credentials (DBServer authenticator)
    ///       where macros resolve to different user credentials per login.
    ///     - Design-time test connections that must not pollute the app cache.
    ///     - Objects whose lifetime genuinely exceeds a single request.
    ///   For normal data access, prefer Database / DatabaseFor.
    /// </summary>
    class function CreateStandaloneDBConnection(const ADatabaseName: string): TEFDBConnection; static;

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
    /// <remarks>Decorated as the RTTI carrier of the Databases container: each
    /// child is a named connection described by TKDatabaseConfig. The property
    /// value itself (the names) is unrelated to the attribute.</remarks>
    [YamlContainer('Databases', TKDatabaseConfig, 'Named database connections')]
    property DBConnectionNames: TStringDynArray read GetDBConnectionNames;

    /// <summary>
    ///  True if <c>ADatabaseName</c> can actually be used: its
    ///  <c>Databases/&lt;Name&gt;</c> block is defined AND the DB adapter it
    ///  references (FD, ODAC, DBX, ADO, ...) is registered — i.e. the matching
    ///  <c>EF.DB.*</c> unit is compiled into this build. Returns False for a
    ///  commented-out block or for an adapter whose unit is not in the app's
    ///  uses. Used e.g. by the login "Environment" combo to hide choices that
    ///  would fail to connect.
    /// </summary>
    function IsDatabaseAvailable(const ADatabaseName: string): Boolean;

    /// <summary>
    ///  Helper function that invokes the specified anonymous method with the
    ///  cached per-request connection for the given database. The connection
    ///  is borrowed from the thread-local cache; it is not freed at the end
    ///  of the method (it is released by ClearDatabase at end of request).
    ///  For single-transaction units of work prefer <seealso>InDBTransaction</seealso>.
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

    /// <summary>Base path of the REST API (the shared prefix of every /api
    /// endpoint), from Server/RestBasePath. Normalized: leading '/', no trailing
    /// '/'. Defaults to KX_DEFAULT_REST_BASE_PATH ('/api/v4').</summary>
    [YamlNode('Server/RestBasePath', '/api/v4', 'Base path of the REST API endpoints')]
    property RestBasePath: string read GetRestBasePath;

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

    /// <summary>The macro-expansion engine for this config (expands %...% macros in config values).</summary>
    property MacroExpansionEngine: TEFMacroExpansionEngine read GetMacroExpansionEngine;

    /// <summary>Format settings for the current user/session (dates, numbers, currency).</summary>
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

    /// <summary>URL base path of this app (defaults to /&lt;appname&gt;).</summary>
    [YamlNode('AppPath', 'URL base path of this app (default /<appname>)')]
    property AppPath: string read GetAppPath;

    /// <summary>Whether the app serves its own static resources (/res/*).</summary>
    [YamlNode('Application/HandleResources', 'True', 'Let the app serve its own static resources')]
    property HandleResources: Boolean read GetHandleResources;

    /// <summary>Charset of HTTP responses.</summary>
    [YamlNode('Charset', 'utf-8', 'HTTP response charset')]
    property Charset: string read GetCharset;

    /// <summary>Client AJAX request timeout, in milliseconds.</summary>
    [YamlNode('AjaxTimeout', '100000', 'Client AJAX request timeout (ms)')]
    property AjaxTimeout: Integer read GetAjaxTimeout;

    /// <summary>Google Maps JavaScript API key (used by the GoogleMap controller).</summary>
    [YamlNode('GoogleMapsApiKey', 'Google Maps JavaScript API key')]
    property GoogleMapsApiKey: string read GetGoogleMapsApiKey;

    /// <summary>Support e-mail address shown to users (e.g. in error/help pages).</summary>
    [YamlNode('EmailSupport', 'Support e-mail address shown to users')]
    property EmailSupport: string read GetEmailSupport;

    /// <summary>Filesystem directory where uploaded BLOB/file fields are stored.</summary>
    [YamlNode('BlobPath', 'Directory where uploaded BLOB/file field contents are stored')]
    property BlobPath: string read GetBlobPath;

    /// <summary>RTTI carrier for the Application node (deployment/proxy options,
    /// e.g. HandleResources). Read by full path at run time.</summary>
    [YamlNode('Application', 'Application deployment options (e.g. partial proxy, resource handling)')]
    property ApplicationNode: string read GetApplicationNode;

    /// <summary>Default UI language code (e.g. en, it).</summary>
    [YamlNode('LanguageId', 'Default UI language code (e.g. en, it)')]
    property LanguageId: string read GetLanguageId;

    /// <summary>Database router plugin id (routes model -> database at run time).
    /// The router's own configuration lives in the node's children and is
    /// plugin-specific, so only the id is described here.</summary>
    [YamlNode('DatabaseRouter', 'Database router plugin id (routes model -> database)')]
    property DatabaseRouterId: string read GetDatabaseRouterId;

    /// <summary>The application name node. Distinct from the class property
    /// AppName (which derives the name from the module file / OnGetAppName): this
    /// is the RTTI carrier of the optional 'AppName' YAML override.</summary>
    [YamlNode('AppName', 'Application name (defaults to the module file name)')]
    property ConfigAppName: string read GetConfigAppName;

    /// <summary>The desktop home view. Its value names an external view, or the
    /// node carries an inline view definition (resolved via FindViewByNode).</summary>
    [YamlViewNode('HomeView', 'Desktop home view: an existing view name, or an inline view definition')]
    property HomeViewName: string read GetHomeViewName;

    /// <summary>The tablet / phone-landscape home view (falls back to HomeView).</summary>
    [YamlViewNode('HomeSmallView', 'Tablet/landscape home view: a view name or an inline view definition')]
    property HomeSmallViewName: string read GetHomeSmallViewName;

    /// <summary>The small-phone-portrait home view (falls back to HomeSmallView/HomeView).</summary>
    [YamlViewNode('HomeTinyView', 'Small-phone home view: a view name or an inline view definition')]
    property HomeTinyViewName: string read GetHomeTinyViewName;

    /// <summary>The login view. Its value names an external view, or the node
    /// carries an inline view definition (resolved via FindViewByNode).</summary>
    [YamlViewNode('Login', 'Login view: an existing view name, or an inline view definition')]
    property LoginViewName: string read GetLoginViewName;

    [YamlSubNode('Server', TKServerConfig, 'HTTP server settings (Port, SessionTimeOut, ThreadPoolSize)')]
    property Server: TKServerConfig read GetServer;

    [YamlSubNode('Auth', TKAuthConfig, 'Authentication settings')]
    property Auth: TKAuthConfig read GetAuth;

    [YamlSubNode('Email', TKEmailConfig, 'E-mail settings: the SMTP servers the application sends through')]
    property Email: TKEmailConfig read GetEmail;

    [YamlSubNode('AccessControl', TKAccessControlConfig, 'Access control settings (SQL commands)')]
    property AccessControl: TKAccessControlConfig read GetAccessControl;

    [YamlSubNode('UserFormats', TKUserFormatsConfig, 'User date/time format overrides')]
    property UserFormats: TKUserFormatsConfig read GetUserFormats;

    [YamlSubNode('Log', TKLogConfig, 'Logging settings: Level and the TextFile sub-node')]
    property Log: TKLogConfig read GetLog;

    [YamlSubNode('Engine', TKEngineConfig, 'Web engine settings (Session TimeOut and CleanupInterval)')]
    property Engine: TKEngineConfig read GetEngine;

    [YamlSubNode('Defaults', TKDefaultsConfig, 'Application-wide UI defaults (Help, Spacing, FormPanel, Window, Grid, AlwaysNotifyChange)')]
    property Defaults: TKDefaultsConfig read GetDefaults;

    [YamlSubNode('Desktop', TKDesktopConfig, 'Desktop embedded mode settings (window size, position, border icons)')]
    property Desktop: TKDesktopConfig read GetDesktop;

    [YamlSubNode('Theme', TKThemeConfig, 'Colour theme: Mode (Auto/Light/Dark), UserSelection, fonts, icons, and per-mode Light/Dark palettes')]
    property Theme: TKThemeConfig read GetTheme;

    [YamlSubNode('Notifications', TKNotificationsConfig, 'Notification Center (bell, top-right): opt-in')]
    property Notifications: TKNotificationsConfig read GetNotifications;

    // NB: HelpChat is no longer declared here. TKHelpChatConfig moved to the chat
    // domain (Kitto.Chat.Provider) with [YamlConfigNode('HelpChat')]; KIDE
    // discovers it via RTTI scan, so Kitto.Config does not reference the chat domain.

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
    /// <summary>Creates the macro expander bound to the given config instance.</summary>
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
  Kitto.Web.Session,
  Kitto.Types,
  Kitto.DatabaseRouter,
  Kitto.Metadata.Context;

procedure TKConfig.AfterConstruction;
var
  LDecimalSeparator: string;
  LThousandSeparator: string;
begin
  inherited;
  { TODO : allow to change format settings on a per-user basis. }
  FUserFormatSettings := FormatSettings.Create;

  if UserFormats.Time <> '' then
    FUserFormatSettings.ShortTimeFormat := UserFormats.Time;
  if Pos('.', FUserFormatSettings.ShortTimeFormat) > 0 then
    FUserFormatSettings.TimeSeparator := '.'
  else
    FUserFormatSettings.TimeSeparator := ':';

  if UserFormats.Date <> '' then
    FUserFormatSettings.ShortDateFormat := UserFormats.Date;
  if Pos('.', FUserFormatSettings.ShortDateFormat) > 0 then
    FUserFormatSettings.DateSeparator := '.'
  else if Pos('-', FUserFormatSettings.ShortDateFormat) > 0 then
    FUserFormatSettings.DateSeparator := '-'
  else
    FUserFormatSettings.DateSeparator := '/';

  LDecimalSeparator := UserFormats.Decimal;
  if LDecimalSeparator <> '' then
    FUserFormatSettings.DecimalSeparator := LDecimalSeparator[1];

  LThousandSeparator := UserFormats.Thousand;
  if LThousandSeparator <> '' then
    FUserFormatSettings.ThousandSeparator := LThousandSeparator[1];

  if UserFormats.Currency <> '' then
    FUserFormatSettings.CurrencyString := UserFormats.Currency;

  //Set also global FormatSettings variable
  FormatSettings := FUserFormatSettings;
end;

destructor TKConfig.Destroy;
begin
  inherited;
  FreeAndNil(FServer);
  FreeAndNil(FAuth);
  FreeAndNil(FEmail);
  FreeAndNil(FNotifications);
  FreeAndNil(FUserFormats);
  FreeAndNil(FAccessControl);
  FreeAndNil(FLog);
  FreeAndNil(FEngine);
  FreeAndNil(FDefaults);
  FreeAndNil(FDesktop);
  FreeAndNil(FViews);
  FreeAndNil(FModels);
  FreeAndNil(FMacroExpansionEngine);
end;

procedure TKConfig.InvalidateConfig;
begin
  inherited; // frees the YAML tree; Config reloads lazily on next access
  // Keep the cached reader instances stable: re-read their fields in place from
  // the freshly reloaded tree (any code holding Config.Server keeps working).
  if FServer <> nil then
    FServer.Refresh(Config.FindNode('Server'));
  if FAuth <> nil then
    FAuth.Refresh(Config.FindNode('Auth'));
  if FEmail <> nil then
    FEmail.Refresh(Config.FindNode('Email'));
  if FNotifications <> nil then
    FNotifications.Refresh(Config.FindNode('Notifications'));
  if FUserFormats <> nil then
    FUserFormats.Refresh(Config.FindNode('UserFormats'));
  if FAccessControl <> nil then
    FAccessControl.Refresh(Config.FindNode('AccessControl'));
  if FLog <> nil then
    FLog.Refresh(Config.FindNode('Log'));
  if FEngine <> nil then
    FEngine.Refresh(Config.FindNode('Engine'));
  if FDefaults <> nil then
    FDefaults.Refresh(Config.FindNode('Defaults'));
  if FDesktop <> nil then
    FDesktop.Refresh(Config.FindNode('Desktop'));
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
begin
  Assert(Assigned(AProc), 'Assigned(AProc)');

  // The connection is borrowed from the per-thread cache; not freed here.
  // It will be released by TKConfig.ClearDatabase at end of unit of work.
  AProc(DatabaseFor(ADatabaseName));
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
  LDatabaseNode: TEFNode;
begin
  Result := GetDBAdapter(ADatabaseName).CreateDBConnection;
  try
    LDatabaseNode := Config.GetNode('Databases/' + ADatabaseName + '/Connection');
    Result.Config.AddChild(TEFNode.Clone(LDatabaseNode));
    LConfig := Config.FindNode('Databases/' + ADatabaseName + '/Config');
    if Assigned(LConfig) then
      Result.Config.AddChild(TEFNode.Clone(LConfig));
    // Per-database opt-in: wrap SQL identifiers in dialect-specific delimiters
    // so that table/column names containing spaces are valid (see KITTOX docs).
    Result.DelimitIdentifiers := Config.GetBoolean('Databases/' + ADatabaseName + '/DelimitedIdent', False);
    // The name this database is known by: unique among the Databases entries,
    // and what the connection pool is keyed on (see TEFDBFDConnection).
    Result.DatabaseName := ADatabaseName;
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
  // Per-session override (login "environment" combo): if the current session
  // has picked a specific database, that takes precedence over both the
  // DatabaseRouter and the configured DefaultDatabaseName.
  if (TKWebSession.Current <> nil) and (TKWebSession.Current.DatabaseName <> '') then
    Exit(TKWebSession.Current.DatabaseName);

  LDatabaseRouterNode := Config.FindNode('DatabaseRouter');
  if Assigned(LDatabaseRouterNode) then
    Result := TKDatabaseRouterFactory.Instance.GetDatabaseName(
      LDatabaseRouterNode.AsString, Self, LDatabaseRouterNode)
  else
    Result := GetDefaultDatabaseName;
end;

function TKConfig.GetRestBasePath: string;
begin
  Result := Trim(Config.GetString('Server/RestBasePath', KX_DEFAULT_REST_BASE_PATH));
  if Result = '' then
    Result := KX_DEFAULT_REST_BASE_PATH;
  // Normalize: exactly one leading '/', no trailing '/'.
  while (Length(Result) > 1) and (Result[Length(Result)] = '/') do
    Delete(Result, Length(Result), 1);
  if Result[1] <> '/' then
    Result := '/' + Result;
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

function TKConfig.IsDatabaseAvailable(const ADatabaseName: string): Boolean;
var
  LDbAdapterKey: string;
begin
  // The Databases/<Name> block must exist (not commented out) ...
  if not Assigned(Config.FindNode('Databases/' + ADatabaseName)) then
    Exit(False);
  // ... and the adapter it references (the node value: FD, ODAC, DBX, ADO, ...)
  // must be registered, i.e. its EF.DB.* unit is compiled into this build.
  LDbAdapterKey := Config.GetExpandedString('Databases/' + ADatabaseName);
  Result := (LDbAdapterKey <> '') and TEFDBAdapterRegistry.Instance.HasDBAdapter(LDbAdapterKey);
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

  // The model layer does not know the configuration: it asks
  // TKMetadataContext for the alternate language, the default database and
  // the macro engine. A KittoX application answers from its configuration,
  // resolved at each call (the database name depends on the session).
  TKMetadataContext.OnGetUseAltLanguage :=
    function: Boolean
    begin
      Result := TKConfig.Instance.UseAltLanguage;
    end;
  TKMetadataContext.OnGetDefaultDatabaseName :=
    function: string
    begin
      Result := TKConfig.Instance.DatabaseName;
    end;
  TKMetadataContext.OnGetMacroExpansionEngine :=
    function: TEFMacroExpansionEngine
    begin
      Result := TKConfig.Instance.MacroExpansionEngine;
    end;
  TKMetadataContext.OnGetCurrentUserName :=
    function: string
    begin
      Result := TKAuthenticator.Current.UserName;
    end;
end;

class destructor TKConfig.Destroy;
begin
  // Before the instance goes: nobody must reach it through the context.
  TKMetadataContext.ResetCallbacks;
  // Clean up the per-thread cached connections for the main thread.
  // Worker threads are expected to call ClearDatabase themselves at the
  // end of each unit of work (the web engine does it automatically).
  ClearDatabase;
  FreeAndNil(FInstance);
end;

function TKConfig.GetAppTitle: string;
begin
  Result := Config.GetString('AppTitle', 'Kitto');
end;

function TKConfig.GetAppPath: string;
begin
  Result := Config.GetString('AppPath', '/' + AppName.ToLower);
end;

function TKConfig.GetHandleResources: Boolean;
begin
  Result := Config.GetBoolean('Application/HandleResources', True);
end;

function TKConfig.GetCharset: string;
begin
  Result := Config.GetString('Charset', 'utf-8');
end;

function TKConfig.GetAjaxTimeout: Integer;
begin
  Result := Config.GetInteger('AjaxTimeout', 100000);
end;

function TKConfig.GetGoogleMapsApiKey: string;
begin
  Result := Config.GetString('GoogleMapsApiKey', '');
end;

function TKConfig.GetEmailSupport: string;
begin
  Result := Config.GetString('EmailSupport', '');
end;

function TKConfig.GetBlobPath: string;
begin
  Result := Config.GetString('BlobPath', '');
end;

function TKConfig.GetApplicationNode: string;
begin
  // RTTI carrier only: the Application block is read by full path at run time.
  Result := '';
end;

function TKConfig.GetLanguageId: string;
begin
  Result := Config.GetString('LanguageId', '');
end;

function TKConfig.GetDatabaseRouterId: string;
begin
  Result := Config.GetString('DatabaseRouter', '');
end;

function TKConfig.GetConfigAppName: string;
begin
  Result := Config.GetString('AppName', '');
end;

function TKConfig.GetHomeViewName: string;
begin
  Result := Config.GetString('HomeView', '');
end;

function TKConfig.GetHomeSmallViewName: string;
begin
  Result := Config.GetString('HomeSmallView', '');
end;

function TKConfig.GetHomeTinyViewName: string;
begin
  Result := Config.GetString('HomeTinyView', '');
end;

function TKConfig.GetLoginViewName: string;
begin
  Result := Config.GetString('Login', '');
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

class function TKConfig.GetCanonicalInstance: TKConfig;
begin
  // Lazily allocate the framework-owned singleton, ignoring any hook.
  // FConfigClass is set by SetConfigClass at unit init time (e.g. KIDEX
  // sets it to TKideConfig). Used by code paths that need the configured
  // subclass instance regardless of any active redirection — most
  // notably TKideConfig.GetInstance, which returns the KIDEX-specific
  // config even when a project's hook redirects TKConfig.Instance to
  // a TProjectConfig.
  if not Assigned(FInstance) then
    FInstance := FConfigClass.Create;
  Result := FInstance;
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
  // Fast path for the default database: no dictionary lookup.
  if not Assigned(FDatabase) then
    FDatabase := TKConfig.Instance.CreateDBConnection(TKConfig.Instance.DatabaseName);
  Result := FDatabase;
end;

class function TKConfig.DatabaseFor(const ADatabaseName: string): TEFDBConnection;
var
  LDefaultName: string;
  LResolvedName: string;
begin
  LDefaultName := TKConfig.Instance.DatabaseName;
  if ADatabaseName = '' then
    LResolvedName := LDefaultName
  else
    LResolvedName := ADatabaseName;

  // Default DB: fast path via dedicated threadvar (deduplication: asking for
  // the default by explicit name returns the SAME instance as TKConfig.Database).
  if SameText(LResolvedName, LDefaultName) then
  begin
    if not Assigned(FDatabase) then
      FDatabase := TKConfig.Instance.CreateDBConnection(LResolvedName);
    Exit(FDatabase);
  end;

  // Non-default DB: cached in the threadvar dictionary.
  if FDatabases = nil then
    FDatabases := TObjectDictionary<string, TEFDBConnection>.Create([doOwnsValues]);
  if not FDatabases.TryGetValue(LResolvedName, Result) then
  begin
    Result := TKConfig.Instance.CreateDBConnection(LResolvedName);
    FDatabases.Add(LResolvedName, Result);
  end;
end;

class procedure TKConfig.ClearDatabase;
begin
  FreeAndNil(FDatabase);
  // doOwnsValues releases all cached non-default connections.
  FreeAndNil(FDatabases);
end;

class function TKConfig.CreateStandaloneDBConnection(const ADatabaseName: string): TEFDBConnection;
begin
  Result := TKConfig.Instance.CreateDBConnection(ADatabaseName);
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
  // Release any per-thread cached connections first: they hold references
  // that may depend on FInstance's config tree.
  ClearDatabase;
  FreeAndNil(FInstance);
end;

function TKConfig.GetServer: TKServerConfig;
begin
  // Typed reader, created lazily and cached; reads the 'Server' subtree once.
  // Refreshed in place by InvalidateConfig on a forced config reload.
  if FServer = nil then
    FServer := TKServerConfig.Create(Config.FindNode('Server'));
  Result := FServer;
end;

function TKConfig.GetAuth: TKAuthConfig;
begin
  if FAuth = nil then
    FAuth := TKAuthConfig.Create(Config.FindNode('Auth'));
  Result := FAuth;
end;

function TKConfig.GetEmail: TKEmailConfig;
begin
  if FEmail = nil then
    FEmail := TKEmailConfig.Create(Config.FindNode('Email'));
  Result := FEmail;
end;

function TKConfig.GetAccessControl: TKAccessControlConfig;
begin
  if FAccessControl = nil then
    FAccessControl := TKAccessControlConfig.Create(Config.FindNode('AccessControl'));
  Result := FAccessControl;
end;

function TKConfig.GetUserFormats: TKUserFormatsConfig;
begin
  // Typed reader, created lazily and cached; reads the 'UserFormats' subtree once.
  if FUserFormats = nil then
    FUserFormats := TKUserFormatsConfig.Create(Config.FindNode('UserFormats'));
  Result := FUserFormats;
end;

function TKConfig.GetLog: TKLogConfig;
begin
  if FLog = nil then
    FLog := TKLogConfig.Create(Config.FindNode('Log'));
  Result := FLog;
end;

function TKConfig.GetEngine: TKEngineConfig;
begin
  if FEngine = nil then
    FEngine := TKEngineConfig.Create(Config.FindNode('Engine'));
  Result := FEngine;
end;

function TKConfig.GetDefaults: TKDefaultsConfig;
begin
  if FDefaults = nil then
    FDefaults := TKDefaultsConfig.Create(Config.FindNode('Defaults'));
  Result := FDefaults;
end;

function TKConfig.GetDesktop: TKDesktopConfig;
begin
  if FDesktop = nil then
    FDesktop := TKDesktopConfig.Create(Config.FindNode('Desktop'));
  Result := FDesktop;
end;

function TKConfig.GetTheme: TKThemeConfig;
begin
  Result := nil; // RTTI discovery only — runtime uses TKThemeConfig class methods
end;

function TKConfig.GetNotifications: TKNotificationsConfig;
begin
  if FNotifications = nil then
    FNotifications := TKNotificationsConfig.Create(Config.FindNode('Notifications'));
  Result := FNotifications;
end;


{ TKConfigMacroExpander }

constructor TKConfigMacroExpander.Create(const AConfig: TKConfig);
begin
  Assert(Assigned(AConfig), 'Assigned(AConfig)');

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
