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
  EF.YAML.Attributes;

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
    [YamlNode('EnableFont', 'True', 'Show font family selector in toolbar')]
    property EnableFont: Boolean read GetEnableFont;

    [YamlNode('EnableFontSize', 'True', 'Show font size selector in toolbar')]
    property EnableFontSize: Boolean read GetEnableFontSize;

    [YamlNode('EnableFormat', 'True', 'Show bold/italic/underline/strike buttons')]
    property EnableFormat: Boolean read GetEnableFormat;

    [YamlNode('EnableColors', 'True', 'Show font color and highlight color pickers')]
    property EnableColors: Boolean read GetEnableColors;

    [YamlNode('EnableAlignments', 'True', 'Show text alignment buttons')]
    property EnableAlignments: Boolean read GetEnableAlignments;

    [YamlNode('EnableLinks', 'True', 'Show insert/edit hyperlink button')]
    property EnableLinks: Boolean read GetEnableLinks;

    [YamlNode('EnableLists', 'True', 'Show bulleted and numbered list buttons')]
    property EnableLists: Boolean read GetEnableLists;

    [YamlNode('EnableSourceEdit', 'True', 'Show view/edit HTML source button')]
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

    [YamlNode('AskUser', 'False', 'Show checkbox asking user to enable local storage')]
    property AskUser: Boolean read GetAskUser;

    [YamlNode('AutoLogin', 'False', 'Automatically submit login if credentials are stored')]
    property AutoLogin: Boolean read GetAutoLogin;

    [YamlNode('AskUser/Default', 'True', 'Default state of the AskUser checkbox')]
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

    [YamlNode('Collapsed', 'False', 'Show filter panel initially collapsed')]
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

    [YamlSubNode('Defaults', TKAuthDefaultsConfig, 'Default credentials')]
    property Defaults: TKAuthDefaultsConfig read GetDefaults;
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
    [YamlNode('UseTLS', 'False', 'Use TLS encryption for SMTP')]
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
    [YamlNode('IsEnabled', 'False', 'Enable text file logging')]
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
    [YamlNode('ReadPermissionsCommandText', 'SQL command to read permissions')]
    property ReadPermissionsCommandText: string read GetReadPermissionsCommandText;

    [YamlNode('ReadRolesCommandText', 'SQL command to read roles')]
    property ReadRolesCommandText: string read GetReadRolesCommandText;
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
    [YamlNode('biSystemMenu', 'True', 'Show system menu icon')]
    property BiSystemMenu: Boolean read GetBiSystemMenu;

    [YamlNode('biMinimize', 'True', 'Show minimize button')]
    property BiMinimize: Boolean read GetBiMinimize;

    [YamlNode('biMaximize', 'True', 'Show maximize button')]
    property BiMaximize: Boolean read GetBiMaximize;

    [YamlNode('biHelp', 'False', 'Show help button')]
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

    [YamlNode('Maximized', 'False', 'Start window maximized')]
    property Maximized: Boolean read GetMaximized;

    [YamlNode('Resizable', 'True', 'Allow window resizing (False = fixed size)')]
    property Resizable: Boolean read GetResizable;

    [YamlNode('Position', 'poScreenCenter', 'Window position (TPosition value)')]
    property Position: string read GetPosition;

    [YamlSubNode('BorderIcons', TKDesktopBorderIconsConfig, 'Window border icons (system menu, minimize, maximize, help)')]
    property BorderIcons: TKDesktopBorderIconsConfig read GetBorderIcons;
  end;

implementation

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

end.
