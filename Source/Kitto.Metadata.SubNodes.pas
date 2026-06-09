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
///  Sub-node classes for YAML config blocks with a fixed set of properties.
///  Each class represents a single named YAML node that contains configuration
///  values (not a collection of N children). Properties are decorated with
///  YAML attributes for KIDE RTTI discovery.
/// </summary>
unit Kitto.Metadata.SubNodes;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Metadata.Types;

type
  /// <summary>
  ///  Configuration for the SunEditor rich-text toolbar on HTMLMemo fields.
  ///  YAML path: Field/HTMLEditor
  /// </summary>
  /// <example>
  ///  HTMLEditor:
  ///    EnableFont: True
  ///    EnableFontSize: True
  ///    EnableFormat: True
  ///    EnableColors: True
  ///    EnableAlignments: True
  ///    EnableLinks: True
  ///    EnableLists: True
  ///    EnableSourceEdit: True
  /// </example>
  TKHTMLEditorConfig = class(TEFNode)
  private
    function GetEnableFont: Boolean;
    function GetEnableFontSize: Boolean;
    function GetEnableFormat: Boolean;
    function GetEnableColors: Boolean;
    function GetEnableAlignments: Boolean;
    function GetEnableLinks: Boolean;
    function GetEnableLists: Boolean;
    function GetEnableSourceEdit: Boolean;
  public
    [YamlNode('EnableFont', 'False', 'Show font family selector in toolbar')]
    property EnableFont: Boolean read GetEnableFont;

    [YamlNode('EnableFontSize', 'False', 'Show font size selector in toolbar')]
    property EnableFontSize: Boolean read GetEnableFontSize;

    [YamlNode('EnableFormat', 'False', 'Show bold/italic/underline/strike buttons')]
    property EnableFormat: Boolean read GetEnableFormat;

    [YamlNode('EnableColors', 'False', 'Show font color and highlight color pickers')]
    property EnableColors: Boolean read GetEnableColors;

    [YamlNode('EnableAlignments', 'False', 'Show text alignment buttons')]
    property EnableAlignments: Boolean read GetEnableAlignments;

    [YamlNode('EnableLinks', 'False', 'Show insert/edit hyperlink button')]
    property EnableLinks: Boolean read GetEnableLinks;

    [YamlNode('EnableLists', 'False', 'Show bulleted and numbered list buttons')]
    property EnableLists: Boolean read GetEnableLists;

    [YamlNode('EnableSourceEdit', 'False', 'Show view/edit HTML source button')]
    property EnableSourceEdit: Boolean read GetEnableSourceEdit;
  end;

  /// <summary>
  ///  Thumbnail dimensions for IsPicture blob fields.
  ///  YAML path: Field/IsPicture/Thumbnail
  /// </summary>
  /// <example>
  ///  IsPicture: True
  ///    Thumbnail:
  ///      Width: 150
  ///      Height: 150
  /// </example>
  TKThumbnailConfig = class(TEFNode)
  private
    function GetWidth: Integer;
    function GetHeight: Integer;
  public
    [YamlNode('Width', '150', 'Thumbnail width in pixels')]
    property Width: Integer read GetWidth;

    [YamlNode('Height', '150', 'Thumbnail height in pixels')]
    property Height: Integer read GetHeight;
  end;

  /// <summary>
  ///  Preview window dimensions for FileReference fields.
  ///  YAML path: Field/PreviewWindow
  /// </summary>
  /// <example>
  ///  PreviewWindow: True
  ///    Width: 226
  ///    Height: 320
  /// </example>
  TKPreviewWindowConfig = class(TEFNode)
  private
    function GetWidth: Integer;
    function GetHeight: Integer;
  public
    [YamlNode('Width', '226', 'Preview window width in pixels')]
    property Width: Integer read GetWidth;

    [YamlNode('Height', '320', 'Preview window height in pixels')]
    property Height: Integer read GetHeight;
  end;

  /// <summary>
  ///  Global form layout defaults read from Config.yaml ? Defaults/Layout.
  ///  YAML path: Defaults/Layout
  /// </summary>
  /// <example>
  ///  Defaults:
  ///    Layout:
  ///      MemoWidth: 60
  ///      MaxFieldWidth: 60
  ///      MinFieldWidth: 5
  ///      Char_Width_Factor: 0.85
  ///      Char_Height_Factor: 0.8
  ///      RequiredLabelTemplate: <b>{label}*</b>
  ///      LabelSeparator: ": "
  /// </example>
  TKLayoutDefaultsConfig = class(TEFNode)
  private
    function GetMemoWidth: Integer;
    function GetMaxFieldWidth: Integer;
    function GetMinFieldWidth: Integer;
    function GetCharWidthFactor: Double;
    function GetCharHeightFactor: Double;
    function GetRequiredLabelTemplate: string;
    function GetLabelSeparator: string;
  public
    [YamlNode('MemoWidth', '60', 'Default width in characters for memo fields')]
    property MemoWidth: Integer read GetMemoWidth;

    [YamlNode('MaxFieldWidth', '60', 'Maximum field width in characters')]
    property MaxFieldWidth: Integer read GetMaxFieldWidth;

    [YamlNode('MinFieldWidth', '5', 'Minimum field width in characters')]
    property MinFieldWidth: Integer read GetMinFieldWidth;

    [YamlNode('Char_Width_Factor', '1.0', 'Multiplier for field widths in ch units')]
    property CharWidthFactor: Double read GetCharWidthFactor;

    [YamlNode('Char_Height_Factor', '1.0', 'Multiplier for HTMLMemo editor heights')]
    property CharHeightFactor: Double read GetCharHeightFactor;

    [YamlNode('RequiredLabelTemplate', '<b>{label}*</b>',
      'HTML template for required field labels ({label} is replaced)')]
    property RequiredLabelTemplate: string read GetRequiredLabelTemplate;

    [YamlNode('LabelSeparator', ': ', 'String appended after field labels')]
    property LabelSeparator: string read GetLabelSeparator;
  end;

  /// <summary>
  ///  Login form local storage options.
  ///  YAML path: Controller/LocalStorage
  /// </summary>
  /// <example>
  ///  LocalStorage:
  ///    Mode: Password
  ///    AskUser: True
  ///    AutoLogin: False
  /// </example>
  TKLocalStorageConfig = class(TEFNode)
  private
    function GetMode: string;
    function GetAskUser: Boolean;
    function GetAutoLogin: Boolean;
    function GetAskUserDefault: Boolean;
  public
    [YamlNode('Mode', '', 'Credentials to store: empty, UserName, or Password')]
    property Mode: string read GetMode;

    [YamlNode('AskUser', 'True', 'Show checkbox asking user to enable local storage')]
    property AskUser: Boolean read GetAskUser;

    [YamlNode('AutoLogin', 'True', 'Automatically submit login if credentials are stored')]
    property AutoLogin: Boolean read GetAutoLogin;

    [YamlNode('AskUser/Default', 'False', 'Default state of the AskUser checkbox')]
    property AskUserDefault: Boolean read GetAskUserDefault;
  end;

  /// <summary>
  ///  Filter panel configuration for List controllers.
  ///  YAML path: Controller/Filters
  /// </summary>
  /// <example>
  ///  Filters:
  ///    DisplayLabel: Search
  ///    LabelWidth: 80
  ///    Connector: and
  ///    Collapsed: False
  ///    Items:
  ///      FreeSearch: ...
  /// </example>
  TKFilterPanelConfig = class(TEFNode)
  private
    function GetDisplayLabel: string;
    function GetLabelWidth: Integer;
    function GetConnector: string;
    function GetCollapsed: Boolean;
    function GetColumnWidth: Integer;
    function GetLabelAlign: string;
  public
    [YamlNode('DisplayLabel', 'Filters', 'Title shown on the filter panel', True)]
    property DisplayLabel: string read GetDisplayLabel;

    [YamlNode('LabelWidth', '80', 'Width in pixels for filter field labels')]
    property LabelWidth: Integer read GetLabelWidth;

    [YamlNode('Connector', 'and', 'Logical connector: and/or')]
    property Connector: string read GetConnector;

    [YamlNode('Collapsed', 'True', 'Show filter panel initially collapsed')]
    property Collapsed: Boolean read GetCollapsed;

    [YamlNode('ColumnWidth', '50', 'Column width for filter layout')]
    property ColumnWidth: Integer read GetColumnWidth;

    [YamlNode('LabelAlign', 'Top', 'Label alignment: Top, Left, Right')]
    property LabelAlign: string read GetLabelAlign;
  end;

  /// <summary>
  ///  Chart legend configuration.
  ///  YAML path: Chart/Legend
  /// </summary>
  /// <example>
  ///  Chart:
  ///    Legend:
  ///      Docked: top
  /// </example>
  TKChartLegendConfig = class(TEFNode)
  private
    function GetDocked: string;
  public
    [YamlNode('Docked', 'top', 'Legend position: top, bottom, left, right')]
    property Docked: string read GetDocked;
  end;

  /// <summary>
  ///  Server settings from Config.yaml.
  ///  YAML path: Server
  /// </summary>
  TKServerConfig = class(TEFNode)
  private
    function GetPort: Integer;
    function GetSessionTimeOut: Integer;
    function GetThreadPoolSize: Integer;
    function GetBindAddress: string;
  public
    [YamlNode('Port', '8080', 'HTTP server port')]
    property Port: Integer read GetPort;

    [YamlNode('SessionTimeOut', '10', 'Session timeout in minutes')]
    property SessionTimeOut: Integer read GetSessionTimeOut;

    [YamlNode('ThreadPoolSize', '20', 'Number of threads in the server pool')]
    property ThreadPoolSize: Integer read GetThreadPoolSize;

    [YamlNode('BindAddress', 'Bind to specific interface (e.g. 127.0.0.1 for loopback only). Empty = all interfaces')]
    property BindAddress: string read GetBindAddress;
  end;

  /// <summary>
  ///  Default credentials for authentication.
  ///  YAML path: Auth/Defaults
  /// </summary>
  TKAuthDefaultsConfig = class(TEFNode)
  private
    function GetUserName: string;
    function GetPassword: string;
  public
    [YamlNode('UserName', 'Default user name')]
    property UserName: string read GetUserName;

    [YamlNode('Password', 'Default password')]
    property Password: string read GetPassword;
  end;

  /// <summary>
  ///  Cookie attributes for the JWT token cookie issued by Auth: JWT.
  ///  YAML path: Auth/Cookie (only meaningful when Auth: JWT)
  /// </summary>
  TKAuthCookieConfig = class(TEFNode)
  private
    function GetCookieName: string;
    function GetCookiePath: string;
    function GetHttpOnly: Boolean;
    function GetSecure: Boolean;
    function GetSameSite: string;
  public
    [YamlNode('Name', 'kx_token', 'Cookie name carrying the JWT')]
    property Name: string read GetCookieName;

    [YamlNode('Path', 'Cookie path scope. Default: TKWebApplication.Path (the AppPath of this app)')]
    property Path: string read GetCookiePath;

    [YamlNode('HttpOnly', 'False', 'Whether the cookie is invisible to JavaScript (recommended)')]
    property HttpOnly: Boolean read GetHttpOnly;

    [YamlNode('Secure', 'False', 'Whether the cookie is only sent over HTTPS (recommended)')]
    property Secure: Boolean read GetSecure;

    [YamlNode('SameSite', 'Lax', 'SameSite attribute. Strict | Lax | None | empty (omit attribute)')]
    property SameSite: string read GetSameSite;
  end;

  /// <summary>
  ///  Selection of optional claims embedded in the JWT issued by Auth: JWT.
  ///  YAML path: Auth/Claims (only meaningful when Auth: JWT)
  /// </summary>
  TKAuthClaimsConfig = class(TEFNode)
  private
    function GetIncludeRoles: Boolean;
    function GetIncludeDB: Boolean;
    function GetIncludeDisplayName: Boolean;
    function GetIncludeLanguage: Boolean;
  public
    [YamlNode('IncludeRoles', 'True', 'Embed the user roles list as a custom claim')]
    property IncludeRoles: Boolean read GetIncludeRoles;

    [YamlNode('IncludeDB', 'False', 'Embed the active environment / database name as the db claim')]
    property IncludeDB: Boolean read GetIncludeDB;

    [YamlNode('IncludeDisplayName', 'False', 'Embed the user display name as the name claim')]
    property IncludeDisplayName: Boolean read GetIncludeDisplayName;

    [YamlNode('IncludeLanguage', 'False', 'Embed the active language as the lang claim')]
    property IncludeLanguage: Boolean read GetIncludeLanguage;

    // IncludeACL intentionally not exposed here: it is auto-derived in
    // TKJWTConfig.Parse from the configured AccessControl (JWT vs. anything
    // else). Keeping it out of the user-facing schema prevents the footgun
    // of "AccessControl: JWT but IncludeACL: False" misconfigurations.
  end;

  /// <summary>
  ///  Authentication settings from Config.yaml.
  ///  YAML path: Auth
  /// </summary>
  TKAuthConfig = class(TEFNode)
  private
    function GetIsClearPassword: Boolean;
    function GetIsPassepartoutEnabled: Boolean;
    function GetPassepartoutPassword: string;
    function GetReadUserCommandText: string;
    function GetSetPasswordCommandText: string;
    function GetAfterAuthenticateCommandText: string;
    function GetFileName: string;
    function GetDefaults: TKAuthDefaultsConfig;
    function GetInner: TKAuthConfig;
    function GetSigningAlgorithm: string;
    function GetSigningKey: string;
    function GetSigningPublicKey: string;
    function GetIssuer: string;
    function GetAudience: string;
    function GetTokenLifetime: Integer;
    function GetSlidingThreshold: Integer;
    function GetClockSkew: Integer;
    function GetCookie: TKAuthCookieConfig;
    function GetClaims: TKAuthClaimsConfig;
    function GetDatabaseChoices: string;
  public
    [YamlNode('IsClearPassword', 'Whether passwords are stored in clear text')]
    property IsClearPassword: Boolean read GetIsClearPassword;

    [YamlNode('IsPassepartoutEnabled', 'Enable passepartout (master) password')]
    property IsPassepartoutEnabled: Boolean read GetIsPassepartoutEnabled;

    [YamlNode('PassepartoutPassword', 'Master password value')]
    property PassepartoutPassword: string read GetPassepartoutPassword;

    [YamlNode('ReadUserCommandText', 'SQL command to read user record')]
    property ReadUserCommandText: string read GetReadUserCommandText;

    [YamlNode('SetPasswordCommandText', 'SQL command to set user password')]
    property SetPasswordCommandText: string read GetSetPasswordCommandText;

    [YamlNode('AfterAuthenticateCommandText', 'SQL command executed after authentication')]
    property AfterAuthenticateCommandText: string read GetAfterAuthenticateCommandText;

    [YamlNode('FileName', 'Text file path for text-file authentication')]
    property FileName: string read GetFileName;

    [YamlNode('DatabaseChoices', 'Comma-separated list of Databases/<Name> entries the user can pick at login. Empty = no environment combo on the login page. Embedded in the db claim when Auth: JWT.')]
    property DatabaseChoices: string read GetDatabaseChoices;

    [YamlSubNode('Defaults', TKAuthDefaultsConfig, 'Default credentials')]
    property Defaults: TKAuthDefaultsConfig read GetDefaults;

    // --- Auth: JWT specific keys (ignored by other authenticator classes) ---

    [YamlSubNode('Inner', TKAuthConfig, 'Inner authenticator wrapped by Auth: JWT (DB / TextFile / OSDB / custom). Performs the actual credential check; the JWT envelope wraps the result.')]
    property Inner: TKAuthConfig read GetInner;

    [YamlNode('SigningAlgorithm', 'HS256', 'JWT signing algorithm. HS256 / HS384 / HS512 (HMAC, no OpenSSL) or RS256 / RS384 / RS512 / ES256 / ES384 / ES512 (asymmetric, requires OpenSSL DLLs)')]
    property SigningAlgorithm: string read GetSigningAlgorithm;

    [YamlNode('SigningKey', 'JWT signing key. Accepts env:VAR_NAME (env var), file:/path (raw bytes from a file), or any other value as inline literal (DEV ONLY). A TKJWTSigningKeyRegistry provider registered from UseKitto.pas takes precedence.')]
    property SigningKey: string read GetSigningKey;

    [YamlNode('SigningPublicKey', 'PEM public key for verifier-only deploys with asymmetric algorithms (RS*/ES*). Accepts the same env: / file: / inline prefixes as SigningKey.')]
    property SigningPublicKey: string read GetSigningPublicKey;

    [YamlNode('Issuer', 'JWT iss claim. Defaults to the application name. Validated on every request.')]
    property Issuer: string read GetIssuer;

    [YamlNode('Audience', 'kx-app', 'JWT aud claim. Validated on every request.')]
    property Audience: string read GetAudience;

    [YamlNode('TokenLifetime', '3600', 'exp - iat in seconds. Default 1 hour.')]
    property TokenLifetime: Integer read GetTokenLifetime;

    [YamlNode('SlidingThreshold', '600', 'When (exp - now) drops below this many seconds, the auth gate re-issues the cookie with a fresh exp on the current response. 0 = disable sliding.')]
    property SlidingThreshold: Integer read GetSlidingThreshold;

    [YamlNode('ClockSkew', '60', 'Allowance in seconds for clock skew between client and server during exp/nbf/iat validation.')]
    property ClockSkew: Integer read GetClockSkew;

    [YamlSubNode('Cookie', TKAuthCookieConfig, 'JWT cookie attributes (HttpOnly / Secure / SameSite / Path / Name)')]
    property Cookie: TKAuthCookieConfig read GetCookie;

    [YamlSubNode('Claims', TKAuthClaimsConfig, 'Optional profile claims embedded in the JWT (roles, db, language, ACL, ...)')]
    property Claims: TKAuthClaimsConfig read GetClaims;
  end;

  /// <summary>
  ///  Grid defaults from Config.yaml.
  ///  YAML path: Defaults/Grid
  /// </summary>
  /// <example>
  ///  Defaults:
  ///    Grid:
  ///      PageRecordCount: 100
  ///      DefaultAction: Edit
  /// </example>
  TKDefaultsGridConfig = class(TEFNode)
  private
    function GetPageRecordCount: Integer;
    function GetDefaultAction: string;
  public
    [YamlNode('PageRecordCount', '100', 'Number of records per grid page')]
    property PageRecordCount: Integer read GetPageRecordCount;

    [YamlNode('DefaultAction', 'Edit', 'Default action on grid row double-click')]
    property DefaultAction: string read GetDefaultAction;
  end;

  /// <summary>
  ///  Window defaults from Config.yaml.
  ///  YAML path: Defaults/Window
  /// </summary>
  /// <example>
  ///  Defaults:
  ///    Window:
  ///      Width: 800
  ///      Height: 600
  /// </example>
  TKDefaultsWindowConfig = class(TEFNode)
  private
    function GetWidth: Integer;
    function GetHeight: Integer;
  public
    [YamlNode('Width', '800', 'Default window width in pixels')]
    property Width: Integer read GetWidth;

    [YamlNode('Height', '600', 'Default window height in pixels')]
    property Height: Integer read GetHeight;
  end;

  /// <summary>
  ///  SMTP email settings from Config.yaml.
  ///  YAML path: Email/SMTP/Default
  /// </summary>
  /// <example>
  ///  Email:
  ///    SMTP:
  ///      Default:
  ///        UseTLS: False
  ///        HostName: smtp.example.com
  ///        Port: 25
  ///        UserName: user
  ///        Password: pass
  /// </example>
  TKSMTPConfig = class(TEFNode)
  private
    function GetUseTLS: Boolean;
    function GetHostName: string;
    function GetPort: Integer;
    function GetUserName: string;
    function GetPassword: string;
  public
    [YamlNode('UseTLS', 'True', 'Use TLS encryption for SMTP')]
    property UseTLS: Boolean read GetUseTLS;

    [YamlNode('HostName', 'SMTP server host name')]
    property HostName: string read GetHostName;

    [YamlNode('Port', '25', 'SMTP server port')]
    property Port: Integer read GetPort;

    [YamlNode('UserName', 'SMTP authentication user name')]
    property UserName: string read GetUserName;

    [YamlNode('Password', 'SMTP authentication password')]
    property Password: string read GetPassword;
  end;

  /// <summary>
  ///  Text file logging settings from Config.yaml.
  ///  YAML path: Log/TextFile
  /// </summary>
  /// <example>
  ///  Log:
  ///    TextFile:
  ///      IsEnabled: False
  ///      FileName: log.txt
  /// </example>
  TKLogTextFileConfig = class(TEFNode)
  private
    function GetIsEnabled: Boolean;
    function GetFileName: string;
  public
    [YamlNode('IsEnabled', 'True', 'Enable text file logging')]
    property IsEnabled: Boolean read GetIsEnabled;

    [YamlNode('FileName', 'Log file path')]
    property FileName: string read GetFileName;
  end;

  /// <summary>
  ///  Access control settings from Config.yaml.
  ///  YAML path: AccessControl
  /// </summary>
  /// <example>
  ///  AccessControl:
  ///    ReadPermissionsCommandText: SELECT * FROM PERMISSIONS
  ///    ReadRolesCommandText: SELECT * FROM ROLES
  /// </example>
  TKAccessControlConfig = class(TEFNode)
  private
    function GetReadPermissionsCommandText: string;
    function GetReadRolesCommandText: string;
  public
    [YamlNode('ReadPermissionsCommandText', 'SQL command to read permissions. Used by AccessControl: DB at runtime and by Auth: JWT at login when AccessControl: JWT is configured (the JWT then snapshots the rows into the kx_acl claim).')]
    property ReadPermissionsCommandText: string read GetReadPermissionsCommandText;

    [YamlNode('ReadRolesCommandText', 'SQL command to read roles. Used by AccessControl: DB at runtime and by Auth: JWT at login when AccessControl: JWT is configured.')]
    property ReadRolesCommandText: string read GetReadRolesCommandText;

    // AccessControl: JWT has no user-tunable keys: it is closed-world
    // (claim is authoritative). For DB-driven evaluation, configure
    // AccessControl: DB instead — Auth: JWT can still be used independently
    // for authentication.
  end;

  /// <summary>
  ///  User format settings from Config.yaml.
  ///  YAML path: UserFormats
  /// </summary>
  /// <example>
  ///  UserFormats:
  ///    Date: dd/mm/yyyy
  ///    Time: hh:nn:ss
  /// </example>
  TKUserFormatsConfig = class(TEFNode)
  private
    function GetDate: string;
    function GetTime: string;
  public
    [YamlNode('Date', 'Date display format')]
    property Date: string read GetDate;

    [YamlNode('Time', 'Time display format')]
    property Time: string read GetTime;
  end;

  /// <summary>
  ///  Login form panel settings.
  ///  YAML path: Controller/FormPanel
  /// </summary>
  /// <example>
  ///  Controller:
  ///    FormPanel:
  ///      LabelWidth: 100
  ///      BodyStyle: padding:10px
  /// </example>
  TKLoginFormPanelConfig = class(TEFNode)
  private
    function GetLabelWidth: Integer;
    function GetBodyStyle: string;
  public
    [YamlNode('LabelWidth', '100', 'Width in pixels for form field labels')]
    property LabelWidth: Integer read GetLabelWidth;

    [YamlNode('BodyStyle', 'CSS style for form panel body')]
    property BodyStyle: string read GetBodyStyle;
  end;

  /// <summary>
  ///  Border icons for the desktop embedded window.
  ///  YAML path: Desktop/BorderIcons
  /// </summary>
  TKDesktopBorderIconsConfig = class(TEFNode)
  private
    function GetBiSystemMenu: Boolean;
    function GetBiMinimize: Boolean;
    function GetBiMaximize: Boolean;
    function GetBiHelp: Boolean;
  public
    [YamlNode('biSystemMenu', 'False', 'Show system menu icon')]
    property BiSystemMenu: Boolean read GetBiSystemMenu;

    [YamlNode('biMinimize', 'False', 'Show minimize button')]
    property BiMinimize: Boolean read GetBiMinimize;

    [YamlNode('biMaximize', 'False', 'Show maximize button')]
    property BiMaximize: Boolean read GetBiMaximize;

    [YamlNode('biHelp', 'True', 'Show help button')]
    property BiHelp: Boolean read GetBiHelp;
  end;

  /// <summary>
  ///  Desktop embedded mode settings — controls the VCL window properties
  ///  when the application runs inside a TEdgeBrowser.
  ///  YAML path: Desktop
  /// </summary>
  TKDesktopConfig = class(TEFNode)
  private
    function GetClientWidth: Integer;
    function GetClientHeight: Integer;
    function GetMaximized: Boolean;
    function GetResizable: Boolean;
    function GetPosition: string;
    function GetBorderIcons: TKDesktopBorderIconsConfig;
  public
    [YamlNode('ClientWidth', '1000', 'Window client width in pixels')]
    property ClientWidth: Integer read GetClientWidth;

    [YamlNode('ClientHeight', '900', 'Window client height in pixels')]
    property ClientHeight: Integer read GetClientHeight;

    [YamlNode('Maximized', 'True', 'Start window maximized')]
    property Maximized: Boolean read GetMaximized;

    [YamlNode('Resizable', 'False', 'Allow window resizing (False = fixed size)')]
    property Resizable: Boolean read GetResizable;

    [YamlNode('Position', 'poScreenCenter', 'Window position (TPosition value)')]
    property Position: string read GetPosition;

    [YamlSubNode('BorderIcons', TKDesktopBorderIconsConfig, 'Window border icons (system menu, minimize, maximize, help)')]
    property BorderIcons: TKDesktopBorderIconsConfig read GetBorderIcons;
  end;

  /// <summary>
  ///  Per-mode theme palette (sub-node Light / Dark of Theme).
  ///  YAML path: Theme/Light, Theme/Dark
  /// </summary>
  TKThemeModeConfig = class(TEFNode)
  private
    function GetPrimaryColor: string;
  public
    [YamlNode('Primary-Color', 'Accent/chrome colour for this mode (CSS colour name or #hex). Empty = neutral default palette.')]
    property PrimaryColor: string read GetPrimaryColor;
  end;

  /// <summary>
  ///  Application colour theme. Single root node with the active Mode, the
  ///  end-user opt-in, the shared font/icon settings, and the per-mode
  ///  palettes (Light / Dark sub-nodes). Replaces the old flat `Theme: &lt;Mode&gt;`
  ///  / sibling-Theme-nodes models.
  ///
  ///  All runtime consumption goes through the class methods (which operate on
  ///  the raw Theme TEFNode), keeping every Theme read encapsulated here:
  ///   - TKWebApplication.RenderHTMLHead → DataThemeAttr / BuildBootScript /
  ///     BuildStyleBlock / ResolveIconStyle / ResolveIconSize
  ///   - TKXThemeSwitcherController → IsUserSelectionEnabled
  ///
  ///  YAML path: Theme
  /// </summary>
  /// <example>
  ///  Theme:
  ///    Mode: Auto
  ///    UserSelection: True
  ///    Font-Family: Segoe UI
  ///    Font-Size: 13px
  ///    IconStyle: outlined
  ///    IconSize: Medium
  ///    Light:
  ///      Primary-Color: FireBrick
  ///    Dark:
  ///      Primary-Color: Gold
  /// </example>
  TKThemeConfig = class(TEFNode)
  private
    function GetMode: TKTheme;
    function GetUserSelection: Boolean;
    function GetFontFamily: string;
    function GetFontSize: string;
    function GetIconStyle: TKIconStyle;
    function GetIconSize: TKIconSize;
    function GetLight: TKThemeModeConfig;
    function GetDark: TKThemeModeConfig;
    /// Chrome/accent/status CSS custom properties for a Primary-Color ('' -> '').
    class function BuildChromeVars(const APrimary: string): string; static;
    /// True if the (hex or CSS-named) colour has high luminance (ITU-R BT.601).
    class function IsCssColorLight(const AColor: string): Boolean; static;
    /// Light/Dark Primary-Color with fallback to a flat Primary-Color on the
    /// Theme node (backward-compat with the old single-node model).
    class function ResolvePrimary(const AThemeNode: TEFNode; const ASubNode: string): string; static;
  public
    [YamlNode('Mode', 'Auto', 'Theme mode: Auto (follow OS) | Light | Dark')]
    property Mode: TKTheme read GetMode;

    [YamlNode('UserSelection', 'True', 'Let the end user pick the theme via the ThemeSwitcher controller (only honoured when Mode=Auto). Runtime default when the node is absent is False; the attribute carries the inverse (True) so adding the node in KIDE writes the meaningful, behaviour-changing value.')]
    property UserSelection: Boolean read GetUserSelection;

    [YamlNode('Font-Family', 'UI font family, shared across modes')]
    property FontFamily: string read GetFontFamily;

    [YamlNode('Font-Size', '12px', 'Base font size in CSS units, shared across modes')]
    property FontSize: string read GetFontSize;

    [YamlNode('IconStyle', 'filled', 'Material Design icon style (resolved server-side, does not switch live)')]
    property IconStyle: TKIconStyle read GetIconStyle;

    [YamlNode('IconSize', 'Medium', 'Default icon size (resolved server-side, does not switch live)')]
    property IconSize: TKIconSize read GetIconSize;

    [YamlSubNode('Light', TKThemeModeConfig, 'Light-mode palette (Primary-Color)')]
    property Light: TKThemeModeConfig read GetLight;

    [YamlSubNode('Dark', TKThemeModeConfig, 'Dark-mode palette (Primary-Color)')]
    property Dark: TKThemeModeConfig read GetDark;

    // --- Runtime API: class methods operating on the raw Theme TEFNode -------
    // (config sub-node getters are RTTI-discovery-only / return nil at runtime,
    //  so consumption is via these class methods, keeping theme logic here.)

    /// Active mode as lowercase 'auto' | 'light' | 'dark'. Reads Theme/Mode,
    /// falling back to the node value (old `Theme: &lt;Mode&gt;` format), else 'auto'.
    class function ResolveMode(const AThemeNode: TEFNode): string; static;

    /// The html data-theme attribute: ' data-theme="light"' / '"dark"', or ''
    /// for Auto (CSS @media handles the OS preference).
    class function DataThemeAttr(const AThemeNode: TEFNode): string; static;

    /// True when Mode=Auto and Theme/UserSelection is True — gates the switcher.
    class function IsUserSelectionEnabled(const AThemeNode: TEFNode): Boolean; static;

    /// Theme/IconStyle as a YAML string (default 'filled'); nil node -> default.
    class function ResolveIconStyle(const AThemeNode: TEFNode): string; static;

    /// Theme/IconSize as a YAML string (default 'Medium'); nil node -> default.
    class function ResolveIconSize(const AThemeNode: TEFNode): string; static;

    /// FOUC-safe inline boot &lt;script&gt; for &lt;head&gt; — applies the localStorage
    /// theme override before CSS paints. '' unless Mode=Auto + UserSelection.
    class function BuildBootScript(const AThemeNode: TEFNode; const AAppName: string): string; static;

    /// The &lt;style&gt; block: :root (light palette) + html[data-theme="dark"] +
    /// prefers-color-scheme media query (dark palette, only if a dark
    /// Primary-Color resolves). '' when nothing to override.
    class function BuildStyleBlock(const AThemeNode: TEFNode): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Generics.Collections;

{ TKHTMLEditorConfig }

function TKHTMLEditorConfig.GetEnableFont: Boolean;
begin
  Result := GetBoolean('EnableFont', True);
end;

function TKHTMLEditorConfig.GetEnableFontSize: Boolean;
begin
  Result := GetBoolean('EnableFontSize', True);
end;

function TKHTMLEditorConfig.GetEnableFormat: Boolean;
begin
  Result := GetBoolean('EnableFormat', True);
end;

function TKHTMLEditorConfig.GetEnableColors: Boolean;
begin
  Result := GetBoolean('EnableColors', True);
end;

function TKHTMLEditorConfig.GetEnableAlignments: Boolean;
begin
  Result := GetBoolean('EnableAlignments', True);
end;

function TKHTMLEditorConfig.GetEnableLinks: Boolean;
begin
  Result := GetBoolean('EnableLinks', True);
end;

function TKHTMLEditorConfig.GetEnableLists: Boolean;
begin
  Result := GetBoolean('EnableLists', True);
end;

function TKHTMLEditorConfig.GetEnableSourceEdit: Boolean;
begin
  Result := GetBoolean('EnableSourceEdit', True);
end;

{ TKThumbnailConfig }

function TKThumbnailConfig.GetWidth: Integer;
begin
  Result := GetInteger('Width', 150);
end;

function TKThumbnailConfig.GetHeight: Integer;
begin
  Result := GetInteger('Height', 150);
end;

{ TKPreviewWindowConfig }

function TKPreviewWindowConfig.GetWidth: Integer;
begin
  Result := GetInteger('Width', 226);
end;

function TKPreviewWindowConfig.GetHeight: Integer;
begin
  Result := GetInteger('Height', 320);
end;

{ TKLayoutDefaultsConfig }

function TKLayoutDefaultsConfig.GetMemoWidth: Integer;
begin
  Result := GetInteger('MemoWidth', 60);
end;

function TKLayoutDefaultsConfig.GetMaxFieldWidth: Integer;
begin
  Result := GetInteger('MaxFieldWidth', 60);
end;

function TKLayoutDefaultsConfig.GetMinFieldWidth: Integer;
begin
  Result := GetInteger('MinFieldWidth', 5);
end;

function TKLayoutDefaultsConfig.GetCharWidthFactor: Double;
begin
  Result := GetFloat('Char_Width_Factor', 1.0);
end;

function TKLayoutDefaultsConfig.GetCharHeightFactor: Double;
begin
  Result := GetFloat('Char_Height_Factor', 1.0);
end;

function TKLayoutDefaultsConfig.GetRequiredLabelTemplate: string;
begin
  Result := GetString('RequiredLabelTemplate', '<b>{label}*</b>');
end;

function TKLayoutDefaultsConfig.GetLabelSeparator: string;
begin
  Result := GetString('LabelSeparator', ': ');
end;

{ TKLocalStorageConfig }

function TKLocalStorageConfig.GetMode: string;
begin
  Result := GetString('Mode');
end;

function TKLocalStorageConfig.GetAskUser: Boolean;
begin
  Result := GetBoolean('AskUser');
end;

function TKLocalStorageConfig.GetAutoLogin: Boolean;
begin
  Result := GetBoolean('AutoLogin', False);
end;

function TKLocalStorageConfig.GetAskUserDefault: Boolean;
begin
  Result := GetBoolean('AskUser/Default', True);
end;

{ TKFilterPanelConfig }

function TKFilterPanelConfig.GetDisplayLabel: string;
begin
  Result := GetString('DisplayLabel', 'Filters');
end;

function TKFilterPanelConfig.GetLabelWidth: Integer;
begin
  Result := GetInteger('LabelWidth', 80);
end;

function TKFilterPanelConfig.GetConnector: string;
begin
  Result := GetString('Connector', 'and');
end;

function TKFilterPanelConfig.GetCollapsed: Boolean;
begin
  Result := GetBoolean('Collapsed', False);
end;

function TKFilterPanelConfig.GetColumnWidth: Integer;
begin
  Result := GetInteger('ColumnWidth', 50);
end;

function TKFilterPanelConfig.GetLabelAlign: string;
begin
  Result := GetString('LabelAlign', 'Top');
end;

{ TKChartLegendConfig }

function TKChartLegendConfig.GetDocked: string;
begin
  Result := GetString('Docked', 'top');
end;

{ TKServerConfig }

function TKServerConfig.GetPort: Integer;
begin
  Result := GetInteger('Port', 8080);
end;

function TKServerConfig.GetSessionTimeOut: Integer;
begin
  Result := GetInteger('SessionTimeOut', 10);
end;

function TKServerConfig.GetThreadPoolSize: Integer;
begin
  Result := GetInteger('ThreadPoolSize', 20);
end;

function TKServerConfig.GetBindAddress: string;
begin
  Result := GetString('BindAddress');
end;

{ TKAuthConfig }

function TKAuthConfig.GetIsClearPassword: Boolean;
begin
  Result := GetBoolean('IsClearPassword');
end;

function TKAuthConfig.GetIsPassepartoutEnabled: Boolean;
begin
  Result := GetBoolean('IsPassepartoutEnabled');
end;

function TKAuthConfig.GetPassepartoutPassword: string;
begin
  Result := GetString('PassepartoutPassword');
end;

function TKAuthConfig.GetReadUserCommandText: string;
begin
  Result := GetString('ReadUserCommandText');
end;

function TKAuthConfig.GetSetPasswordCommandText: string;
begin
  Result := GetString('SetPasswordCommandText');
end;

function TKAuthConfig.GetAfterAuthenticateCommandText: string;
begin
  Result := GetString('AfterAuthenticateCommandText');
end;

function TKAuthConfig.GetFileName: string;
begin
  Result := GetString('FileName');
end;

function TKAuthConfig.GetDefaults: TKAuthDefaultsConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKAuthConfig.GetDatabaseChoices: string;
begin
  Result := GetString('DatabaseChoices');
end;

function TKAuthConfig.GetInner: TKAuthConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKAuthConfig.GetSigningAlgorithm: string;
begin
  Result := GetString('SigningAlgorithm', 'HS256');
end;

function TKAuthConfig.GetSigningKey: string;
begin
  Result := GetString('SigningKey');
end;

function TKAuthConfig.GetSigningPublicKey: string;
begin
  Result := GetString('SigningPublicKey');
end;

function TKAuthConfig.GetIssuer: string;
begin
  Result := GetString('Issuer');
end;

function TKAuthConfig.GetAudience: string;
begin
  Result := GetString('Audience', 'kx-app');
end;

function TKAuthConfig.GetTokenLifetime: Integer;
begin
  Result := GetInteger('TokenLifetime', 3600);
end;

function TKAuthConfig.GetSlidingThreshold: Integer;
begin
  Result := GetInteger('SlidingThreshold', 600);
end;

function TKAuthConfig.GetClockSkew: Integer;
begin
  Result := GetInteger('ClockSkew', 60);
end;

function TKAuthConfig.GetCookie: TKAuthCookieConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKAuthConfig.GetClaims: TKAuthClaimsConfig;
begin
  Result := nil; // RTTI discovery only
end;

{ TKAuthCookieConfig }

function TKAuthCookieConfig.GetCookieName: string;
begin
  Result := GetString('Name', 'kx_token');
end;

function TKAuthCookieConfig.GetCookiePath: string;
begin
  Result := GetString('Path');
end;

function TKAuthCookieConfig.GetHttpOnly: Boolean;
begin
  Result := GetBoolean('HttpOnly', True);
end;

function TKAuthCookieConfig.GetSecure: Boolean;
begin
  Result := GetBoolean('Secure', True);
end;

function TKAuthCookieConfig.GetSameSite: string;
begin
  Result := GetString('SameSite', 'Lax');
end;

{ TKAuthClaimsConfig }

function TKAuthClaimsConfig.GetIncludeRoles: Boolean;
begin
  Result := GetBoolean('IncludeRoles', False);
end;

function TKAuthClaimsConfig.GetIncludeDB: Boolean;
begin
  Result := GetBoolean('IncludeDB', True);
end;

function TKAuthClaimsConfig.GetIncludeDisplayName: Boolean;
begin
  Result := GetBoolean('IncludeDisplayName', True);
end;

function TKAuthClaimsConfig.GetIncludeLanguage: Boolean;
begin
  Result := GetBoolean('IncludeLanguage', True);
end;

{ TKAuthDefaultsConfig }

function TKAuthDefaultsConfig.GetUserName: string;
begin
  Result := GetString('UserName');
end;

function TKAuthDefaultsConfig.GetPassword: string;
begin
  Result := GetString('Password');
end;

{ TKDefaultsGridConfig }

function TKDefaultsGridConfig.GetPageRecordCount: Integer;
begin
  Result := GetInteger('PageRecordCount', 100);
end;

function TKDefaultsGridConfig.GetDefaultAction: string;
begin
  Result := GetString('DefaultAction', 'Edit');
end;

{ TKDefaultsWindowConfig }

function TKDefaultsWindowConfig.GetWidth: Integer;
begin
  Result := GetInteger('Width', 800);
end;

function TKDefaultsWindowConfig.GetHeight: Integer;
begin
  Result := GetInteger('Height', 600);
end;

{ TKSMTPConfig }

function TKSMTPConfig.GetUseTLS: Boolean;
begin
  Result := GetBoolean('UseTLS', False);
end;

function TKSMTPConfig.GetHostName: string;
begin
  Result := GetString('HostName');
end;

function TKSMTPConfig.GetPort: Integer;
begin
  Result := GetInteger('Port', 25);
end;

function TKSMTPConfig.GetUserName: string;
begin
  Result := GetString('UserName');
end;

function TKSMTPConfig.GetPassword: string;
begin
  Result := GetString('Password');
end;

{ TKLogTextFileConfig }

function TKLogTextFileConfig.GetIsEnabled: Boolean;
begin
  Result := GetBoolean('IsEnabled', False);
end;

function TKLogTextFileConfig.GetFileName: string;
begin
  Result := GetString('FileName');
end;

{ TKAccessControlConfig }

function TKAccessControlConfig.GetReadPermissionsCommandText: string;
begin
  Result := GetString('ReadPermissionsCommandText');
end;

function TKAccessControlConfig.GetReadRolesCommandText: string;
begin
  Result := GetString('ReadRolesCommandText');
end;

{ TKUserFormatsConfig }

function TKUserFormatsConfig.GetDate: string;
begin
  Result := GetString('Date');
end;

function TKUserFormatsConfig.GetTime: string;
begin
  Result := GetString('Time');
end;

{ TKLoginFormPanelConfig }

function TKLoginFormPanelConfig.GetLabelWidth: Integer;
begin
  Result := GetInteger('LabelWidth', 100);
end;

function TKLoginFormPanelConfig.GetBodyStyle: string;
begin
  Result := GetString('BodyStyle');
end;

{ TKDesktopBorderIconsConfig }

function TKDesktopBorderIconsConfig.GetBiSystemMenu: Boolean;
begin
  Result := GetBoolean('biSystemMenu', True);
end;

function TKDesktopBorderIconsConfig.GetBiMinimize: Boolean;
begin
  Result := GetBoolean('biMinimize', True);
end;

function TKDesktopBorderIconsConfig.GetBiMaximize: Boolean;
begin
  Result := GetBoolean('biMaximize', True);
end;

function TKDesktopBorderIconsConfig.GetBiHelp: Boolean;
begin
  Result := GetBoolean('biHelp', False);
end;

{ TKDesktopConfig }

function TKDesktopConfig.GetClientWidth: Integer;
begin
  Result := GetInteger('ClientWidth', 1000);
end;

function TKDesktopConfig.GetClientHeight: Integer;
begin
  Result := GetInteger('ClientHeight', 900);
end;

function TKDesktopConfig.GetMaximized: Boolean;
begin
  Result := GetBoolean('Maximized', False);
end;

function TKDesktopConfig.GetResizable: Boolean;
begin
  Result := GetBoolean('Resizable', True);
end;

function TKDesktopConfig.GetPosition: string;
begin
  Result := GetString('Position', 'poScreenCenter');
end;

function TKDesktopConfig.GetBorderIcons: TKDesktopBorderIconsConfig;
begin
  Result := nil; // RTTI discovery only — runtime access uses FindNode directly
end;

{ TKThemeModeConfig }

function TKThemeModeConfig.GetPrimaryColor: string;
begin
  Result := GetString('Primary-Color');
end;

{ TKThemeConfig }

// --- Decorated property getters (RTTI discovery; not used at runtime) -------

function TKThemeConfig.GetMode: TKTheme;
var
  S: string;
begin
  // RTTI-discovery getter (not called at runtime). Manual map keeps this unit
  // free of the KIDE-side RTTI reader; mirrors the YamlEnumValue mapping of TKTheme.
  S := LowerCase(GetString('Mode', 'Auto'));
  if S = 'light' then Result := thLight
  else if S = 'dark' then Result := thDark
  else Result := thAuto;
end;

function TKThemeConfig.GetUserSelection: Boolean;
begin
  Result := GetBoolean('UserSelection', False);
end;

function TKThemeConfig.GetFontFamily: string;
begin
  Result := GetString('Font-Family');
end;

function TKThemeConfig.GetFontSize: string;
begin
  Result := GetString('Font-Size');
end;

function TKThemeConfig.GetIconStyle: TKIconStyle;
var
  S: string;
begin
  S := LowerCase(GetString('IconStyle', 'filled'));
  if S = 'outlined' then Result := isOutlined
  else if S = 'round' then Result := isRound
  else if S = 'sharp' then Result := isSharp
  else if S = 'two-tone' then Result := isTwoTone
  else Result := isFilled;
end;

function TKThemeConfig.GetIconSize: TKIconSize;
var
  S: string;
begin
  S := LowerCase(GetString('IconSize', 'Medium'));
  if S = 'small' then Result := izSmall
  else if S = 'large' then Result := izLarge
  else Result := izMedium;
end;

function TKThemeConfig.GetLight: TKThemeModeConfig;
begin
  Result := nil; // RTTI discovery only — runtime access uses the class methods
end;

function TKThemeConfig.GetDark: TKThemeModeConfig;
begin
  Result := nil; // RTTI discovery only — runtime access uses the class methods
end;

// --- Private helpers --------------------------------------------------------

class function TKThemeConfig.IsCssColorLight(const AColor: string): Boolean;
var
  LColor, LHex: string;
  R, G, B: Integer;
  LLuminance: Double;
  LColorMap: TDictionary<string, string>;
begin
  // Perceived luminance (ITU-R BT.601). Returns True for light backgrounds so
  // the caller picks dark text on top. Handles #rgb / #rrggbb directly and maps
  // common CSS named colours to hex; unknown names default to dark (safe for
  // light text on chrome).
  LColor := LowerCase(Trim(AColor));
  LHex := '';

  if (LColor <> '') and (LColor[1] = '#') then
    LHex := LColor
  else
  begin
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
        Exit(False); // unknown name: assume dark (safe for light text)
    finally
      LColorMap.Free;
    end;
  end;

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
    Exit(False);

  LLuminance := 0.299 * R + 0.587 * G + 0.114 * B;
  Result := LLuminance > 160;
end;

class function TKThemeConfig.BuildChromeVars(const APrimary: string): string;
var
  LText: string;
begin
  if APrimary = '' then
    Exit('');
  if IsCssColorLight(APrimary) then
    LText := '#1a1a1a'   // dark text on a light chrome background
  else
    LText := '#ecf0f1';  // light text on a dark chrome background
  Result :=
    '--kx-chrome:' + APrimary + ';' +
    '--kx-chrome-dark:color-mix(in srgb,' + APrimary + ',black 25%);' +
    '--kx-chrome-hover:color-mix(in srgb,' + APrimary + ',white 15%);' +
    '--kx-chrome-mid:color-mix(in srgb,' + APrimary + ',white 22%);' +
    '--kx-chrome-light:color-mix(in srgb,' + APrimary + ',white 30%);' +
    '--kx-chrome-text:' + LText + ';' +
    '--kx-chrome-btn-hover:' + IfThen(LText = '#ecf0f1',
      'rgba(255,255,255,0.15)', 'rgba(0,0,0,0.10)') + ';' +
    '--kx-status-bg:color-mix(in srgb,' + APrimary + ',black 25%);' +
    '--kx-status-text:' + LText + ';' +
    '--kx-status-border:color-mix(in srgb,' + APrimary + ',black 40%);' +
    '--kx-accent:' + APrimary + ';' +
    '--kx-accent-ring:color-mix(in srgb,' + APrimary + ' 15%,transparent);';
end;

class function TKThemeConfig.ResolvePrimary(const AThemeNode: TEFNode;
  const ASubNode: string): string;
var
  LNode: TEFNode;
begin
  // Per-mode Primary-Color from the Light/Dark sub-node; fall back to a flat
  // Primary-Color on the Theme node itself (old single-node model) so legacy
  // configs keep working.
  Result := '';
  if not Assigned(AThemeNode) then
    Exit;
  LNode := AThemeNode.FindNode(ASubNode);
  if Assigned(LNode) then
    Result := LNode.GetString('Primary-Color');
  if Result = '' then
    Result := AThemeNode.GetString('Primary-Color');
end;

// --- Runtime API ------------------------------------------------------------

class function TKThemeConfig.ResolveMode(const AThemeNode: TEFNode): string;
begin
  if not Assigned(AThemeNode) then
    Exit('auto');
  // Theme/Mode (new model); fall back to the node value (old `Theme: <Mode>`).
  Result := LowerCase(AThemeNode.GetString('Mode', AThemeNode.AsString));
  if Result = '' then
    Result := 'auto';
end;

class function TKThemeConfig.DataThemeAttr(const AThemeNode: TEFNode): string;
var
  LMode: string;
begin
  LMode := ResolveMode(AThemeNode);
  if LMode = 'light' then
    Result := ' data-theme="light"'
  else if LMode = 'dark' then
    Result := ' data-theme="dark"'
  else
    Result := ''; // 'auto' or unset: no attribute, CSS @media handles it
end;

class function TKThemeConfig.IsUserSelectionEnabled(const AThemeNode: TEFNode): Boolean;
begin
  Result := Assigned(AThemeNode)
    and (ResolveMode(AThemeNode) = 'auto')
    and AThemeNode.GetBoolean('UserSelection', False);
end;

class function TKThemeConfig.ResolveIconStyle(const AThemeNode: TEFNode): string;
begin
  if Assigned(AThemeNode) then
    Result := AThemeNode.GetString('IconStyle', 'filled')
  else
    Result := 'filled';
end;

class function TKThemeConfig.ResolveIconSize(const AThemeNode: TEFNode): string;
begin
  if Assigned(AThemeNode) then
    Result := AThemeNode.GetString('IconSize', 'Medium')
  else
    Result := 'Medium';
end;

class function TKThemeConfig.BuildBootScript(const AThemeNode: TEFNode;
  const AAppName: string): string;
begin
  // FOUC-safe: applies the localStorage theme override before CSS paints.
  // Only when the user is allowed to switch (Mode=Auto + UserSelection).
  if not IsUserSelectionEnabled(AThemeNode) then
    Exit('');
  Result :=
    '<script>(function(){try{' +
      'var m=localStorage.getItem(' + AnsiQuotedStr('kx_theme:' + AAppName, '''') + ');' +
      'if(m===''light''||m===''dark'')document.documentElement.setAttribute(''data-theme'',m);' +
    '}catch(e){}})();</script>';
end;

class function TKThemeConfig.BuildStyleBlock(const AThemeNode: TEFNode): string;
var
  LLightPrimary, LDarkPrimary, LFontFamily, LFontSize, LFontBlock, LDarkBlock: string;
begin
  Result := '';
  if not Assigned(AThemeNode) then
    Exit;

  LLightPrimary := ResolvePrimary(AThemeNode, 'Light');
  LDarkPrimary := ResolvePrimary(AThemeNode, 'Dark');
  LFontFamily := AThemeNode.GetString('Font-Family');
  LFontSize := AThemeNode.GetString('Font-Size');

  if (LLightPrimary = '') and (LDarkPrimary = '') and (LFontFamily = '') and (LFontSize = '') then
    Exit; // nothing to override — the static kittox.css palette drives both modes

  LFontBlock := '';
  if LFontFamily <> '' then
    LFontBlock := LFontBlock + '--kx-font:"' + LFontFamily + '",sans-serif;';
  if LFontSize <> '' then
    LFontBlock := LFontBlock + '--kx-font-size:' + LFontSize + ';';

  // :root — light palette: font + chrome + page text derived from primary.
  Result := '<style>:root{' + LFontBlock + BuildChromeVars(LLightPrimary);
  if LLightPrimary <> '' then
    Result := Result +
      '--kx-accent-bg:color-mix(in srgb,' + LLightPrimary + ',white 85%);' +
      '--kx-text:color-mix(in srgb,' + LLightPrimary + ',black 60%);' +
      '--kx-text-secondary:color-mix(in srgb,' + LLightPrimary + ',black 40%);' +
      '--kx-text-muted:color-mix(in srgb,' + LLightPrimary + ',black 20%);' +
      '--kx-tree-folder-text:color-mix(in srgb,' + LLightPrimary + ',black 60%);' +
      '--kx-tree-leaf-text:color-mix(in srgb,' + LLightPrimary + ',black 60%);';
  Result := Result + '}';

  // Dark palette — only when a dark Primary-Color resolves. Resets text vars to
  // the dark defaults at the higher 0,1,1 specificity so the :root light greens
  // never leak into dark. When empty, the static kittox.css dark block wins.
  if LDarkPrimary <> '' then
  begin
    LDarkBlock := BuildChromeVars(LDarkPrimary) +
      '--kx-accent-bg:color-mix(in srgb,' + LDarkPrimary + ',transparent 88%);' +
      '--kx-text:#e5e7eb;' +
      '--kx-text-secondary:#9ca3af;' +
      '--kx-text-muted:#9ca3af;' +
      '--kx-tree-folder-text:#e5e7eb;' +
      '--kx-tree-leaf-text:#e5e7eb;';
    Result := Result +
      'html[data-theme="dark"]{' + LDarkBlock + '}' +
      '@media(prefers-color-scheme:dark){:root:not([data-theme]){' + LDarkBlock + '}}';
  end;

  Result := Result + '</style>';
end;

end.
