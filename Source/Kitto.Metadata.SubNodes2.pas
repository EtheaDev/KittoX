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
///  Sub-node classes for YAML config blocks — Part 2.
///  ViewTable controller config, layout elements, chart nodes, filter items,
///  and DB adapter connection configs.
/// </summary>
unit Kitto.Metadata.SubNodes2;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Metadata.SubNodes;

type

  { ---------- Grouping sub-nodes ---------- }

  /// <summary>
  ///  ShowCount sub-node inside Grouping.
  ///  YAML path: Controller/Grouping/ShowCount
  /// </summary>
  TKGroupingShowCountConfig = class(TEFNode)
  private
    function GetItemName: string;
    function GetPluralItemName: string;
    function GetTemplate: string;
  public
    [YamlNode('ItemName', 'Singular item name displayed in count')]
    property ItemName: string read GetItemName;

    [YamlNode('PluralItemName', 'Plural item name displayed in count')]
    property PluralItemName: string read GetPluralItemName;

    [YamlNode('Template', 'Custom template for count display')]
    property Template: string read GetTemplate;
  end;

  /// <summary>
  ///  Grouping configuration for list controllers.
  ///  YAML path: Controller/Grouping
  /// </summary>
  TKGroupingConfig = class(TEFNode)
  private
    function GetFieldName: string;
    function GetSortFieldNames: string;
    function GetEnableMenu: Boolean;
    function GetStartCollapsed: Boolean;
    function GetShowName: Boolean;
    function GetShowCount: TKGroupingShowCountConfig;
  public
    [YamlRequiredNode('FieldName', 'Field used for grouping rows')]
    property FieldName: string read GetFieldName;

    [YamlNode('SortFieldNames', 'Comma-separated fields to sort within groups')]
    property SortFieldNames: string read GetSortFieldNames;

    [YamlNode('EnableMenu', 'False', 'Show grouping context menu')]
    property EnableMenu: Boolean read GetEnableMenu;

    [YamlNode('StartCollapsed', 'False', 'Initially collapse all groups')]
    property StartCollapsed: Boolean read GetStartCollapsed;

    [YamlNode('ShowName', 'False', 'Display group field name in header')]
    property ShowName: Boolean read GetShowName;

    [YamlSubNode('ShowCount', TKGroupingShowCountConfig, 'Show count display options')]
    property ShowCount: TKGroupingShowCountConfig read GetShowCount;
  end;

  { ---------- Popup window ---------- }

  /// <summary>
  ///  Popup window dimensions for form controllers.
  ///  YAML path: Controller/PopupWindow
  /// </summary>
  TKPopupWindowConfig = class(TEFNode)
  private
    function GetWidth: Integer;
    function GetHeight: Integer;
  public
    [YamlNode('Width', '800', 'Popup window width in pixels')]
    property Width: Integer read GetWidth;

    [YamlNode('Height', '600', 'Popup window height in pixels')]
    property Height: Integer read GetHeight;
  end;

  { ---------- Form controller button ---------- }

  /// <summary>
  ///  Custom button inside a FormController.
  ///  YAML path: Controller/FormController/Button
  /// </summary>
  TKFormControllerButtonConfig = class(TEFNode)
  private
    function GetCaption: string;
    function GetToolTip: string;
  public
    [YamlNode('Caption', 'Button caption text')]
    property Caption: string read GetCaption;

    [YamlNode('ToolTip', 'Button tooltip text')]
    property ToolTip: string read GetToolTip;
  end;

  { ---------- Form controller ---------- }

  /// <summary>
  ///  Form controller behaviour settings.
  ///  YAML path: Controller/FormController
  /// </summary>
  TKFormControllerConfig = class(TEFNode)
  private
    function GetKeepOpenAfterOperation: Boolean;
    function GetButtonScale: string;
    function GetCloneButton: TKFormControllerButtonConfig;
    function GetConfirmButton: TKFormControllerButtonConfig;
    function GetCancelButton: TKFormControllerButtonConfig;
    function GetCloseButton: TKFormControllerButtonConfig;
  public
    [YamlNode('KeepOpenAfterOperation', 'False', 'Keep form open after save/delete')]
    property KeepOpenAfterOperation: Boolean read GetKeepOpenAfterOperation;

    [YamlNode('ButtonScale', 'CSS scale class for form buttons')]
    property ButtonScale: string read GetButtonScale;

    [YamlSubNode('CloneButton', TKFormControllerButtonConfig, 'Clone/duplicate button')]
    property CloneButton: TKFormControllerButtonConfig read GetCloneButton;

    [YamlSubNode('ConfirmButton', TKFormControllerButtonConfig, 'Save/confirm button')]
    property ConfirmButton: TKFormControllerButtonConfig read GetConfirmButton;

    [YamlSubNode('CancelButton', TKFormControllerButtonConfig, 'Cancel button')]
    property CancelButton: TKFormControllerButtonConfig read GetCancelButton;

    [YamlSubNode('CloseButton', TKFormControllerButtonConfig, 'Close button')]
    property CloseButton: TKFormControllerButtonConfig read GetCloseButton;
  end;

  { ---------- ToolViews ---------- }

  /// <summary>
  ///  Single tool view item inside a ToolViews container.
  ///  YAML path: Controller/ToolViews/{ToolName}
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKToolViewItem = class(TEFNode)
  private
    function GetDisplayLabel: string;
    function GetImageName: string;
    function GetControllerType: string;
    function GetRequireSelection: Boolean;
    function GetAutoRefresh: string;
    function GetConfirmationMessage: string;
  public
    [YamlNode('DisplayLabel', 'Label shown on the tool button', True)]
    property DisplayLabel: string read GetDisplayLabel;

    [YamlNode('ImageName', 'Icon name for the tool button')]
    property ImageName: string read GetImageName;

    [YamlNode('Controller', 'Controller type for this tool')]
    property ControllerType: string read GetControllerType;

    [YamlNode('RequireSelection', 'False', 'Require a selected record before executing')]
    property RequireSelection: Boolean read GetRequireSelection;

    [YamlNode('AutoRefresh', 'All', 'Refresh mode after execution: All, Current, None')]
    property AutoRefresh: string read GetAutoRefresh;

    [YamlNode('ConfirmationMessage', 'User confirmation prompt before executing', True)]
    property ConfirmationMessage: string read GetConfirmationMessage;
  end;

  /// <summary>
  ///  Container for tool view items.
  ///  YAML path: Controller/ToolViews
  /// </summary>
  [YamlChildType('DownloadText', '', 'Download as text file')]
  [YamlChildType('DownloadCSV', '', 'Download as CSV file')]
  [YamlChildType('DownloadExcel', '', 'Download as Excel file')]
  [YamlChildType('DownloadMergedPDF', '', 'Download as merged PDF')]
  [YamlChildType('DownloadFOPReport', '', 'Download PDF via FOP')]
  [YamlChildType('DownloadHTMLReport', '', 'Download HTML report via XSL')]
  [YamlChildType('DownloadFile', '', 'Download a server file')]
  [YamlChildType('UploadFile', '', 'Upload a file')]
  [YamlChildType('UploadExcel', '', 'Upload and import Excel file')]
  [YamlChildType('ExecuteSQLCommand', '', 'Execute SQL command')]
  [YamlChildType('SendEmail', '', 'Send email')]
  [YamlChildType('DisplayView', '', 'Display a view')]
  [YamlChildType('URL', '', 'Open a URL')]
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKToolViewsConfig = class(TEFNode)
  end;

  { ---------- ViewTable Controller ---------- }

  /// <summary>
  ///  Controller-level settings for a ViewTable list controller.
  ///  YAML path: Controller
  /// </summary>
  TKViewTableControllerConfig = class(TEFNode)
  private
    function GetAutoOpen: Boolean;
    function GetPageRecordCount: Integer;
    function GetPagingTools: Boolean;
    function GetRowClassProvider: string;
    function GetAllowViewing: Boolean;
    function GetPreventEditing: Boolean;
    function GetPreventAdding: Boolean;
    function GetPreventDeleting: Boolean;
    function GetAllowDuplicating: Boolean;
    function GetToolViews: TKToolViewsConfig;
    function GetPopupWindow: TKPopupWindowConfig;
    function GetGrouping: TKGroupingConfig;
    function GetFormController: TKFormControllerConfig;
  public
    [YamlNode('AutoOpen', 'False', 'Automatically open the first record in edit form')]
    property AutoOpen: Boolean read GetAutoOpen;

    [YamlNode('PageRecordCount', 'Number of records per page')]
    property PageRecordCount: Integer read GetPageRecordCount;

    [YamlNode('PagingTools', 'True', 'Show paging toolbar')]
    property PagingTools: Boolean read GetPagingTools;

    [YamlNode('RowClassProvider', 'Server-side function returning CSS class per row')]
    property RowClassProvider: string read GetRowClassProvider;

    [YamlNode('AllowViewing', 'False', 'Show a read-only View button')]
    property AllowViewing: Boolean read GetAllowViewing;

    [YamlNode('PreventEditing', 'False', 'Hide the Edit button')]
    property PreventEditing: Boolean read GetPreventEditing;

    [YamlNode('PreventAdding', 'False', 'Hide the Add button')]
    property PreventAdding: Boolean read GetPreventAdding;

    [YamlNode('PreventDeleting', 'False', 'Hide the Delete button')]
    property PreventDeleting: Boolean read GetPreventDeleting;

    [YamlNode('AllowDuplicating', 'False', 'Show a Duplicate button')]
    property AllowDuplicating: Boolean read GetAllowDuplicating;

    [YamlSubNode('ToolViews', TKToolViewsConfig, 'Tool buttons and actions')]
    property ToolViews: TKToolViewsConfig read GetToolViews;

    [YamlSubNode('PopupWindow', TKPopupWindowConfig, 'Modal window size for add/edit')]
    property PopupWindow: TKPopupWindowConfig read GetPopupWindow;

    [YamlSubNode('Grouping', TKGroupingConfig, 'Row grouping configuration')]
    property Grouping: TKGroupingConfig read GetGrouping;

    [YamlSubNode('FormController', TKFormControllerConfig, 'Form controller options')]
    property FormController: TKFormControllerConfig read GetFormController;
  end;

  { ---------- Layout elements ---------- }

  /// <summary>
  ///  Field-level layout overrides.
  ///  YAML path: Layout/Field
  /// </summary>
  TKLayoutFieldConfig = class(TEFNode)
  private
    function GetCharWidth: Integer;
    function GetDisplayWidth: Integer;
    function GetAlignment: string;
    function GetIsReadOnly: Boolean;
    function GetDisplayFormat: string;
  public
    [YamlNode('CharWidth', 'Field width in characters')]
    property CharWidth: Integer read GetCharWidth;

    [YamlNode('DisplayWidth', 'Display width override in characters')]
    property DisplayWidth: Integer read GetDisplayWidth;

    [YamlNode('Alignment', 'Text alignment: left, center, right')]
    property Alignment: string read GetAlignment;

    [YamlNode('IsReadOnly', 'False', 'Force field to read-only in this layout')]
    property IsReadOnly: Boolean read GetIsReadOnly;

    [YamlNode('DisplayFormat', 'Format string for display rendering')]
    property DisplayFormat: string read GetDisplayFormat;
  end;

  /// <summary>
  ///  FieldSet grouping in a layout.
  ///  YAML path: Layout/FieldSet
  /// </summary>
  TKLayoutFieldSetConfig = class(TEFNode)
  private
    function GetTitle: string;
    function GetCollapsible: Boolean;
  public
    [YamlNode('Title', 'FieldSet title')]
    property Title: string read GetTitle;

    [YamlNode('Collapsible', 'False', 'Allow the fieldset to be collapsed')]
    property Collapsible: Boolean read GetCollapsible;
  end;

  { ---------- Chart sub-nodes ---------- }

  /// <summary>
  ///  Style options for a chart series.
  ///  YAML path: Chart/Series/SeriesItem/Style
  /// </summary>
  TKChartSeriesStyleConfig = class(TEFNode)
  private
    function GetColor: string;
    function GetImage: string;
    function GetMode: string;
  public
    [YamlNode('Color', 'Fill or stroke color')]
    property Color: string read GetColor;

    [YamlNode('Image', 'Background image URL')]
    property Image: string read GetImage;

    [YamlNode('Mode', 'Rendering mode')]
    property Mode: string read GetMode;
  end;

  /// <summary>
  ///  Chart series item configuration.
  ///  YAML path: Chart/Series/SeriesItem
  /// </summary>
  TKChartSeriesConfig = class(TEFNode)
  private
    function GetType: string;
    function GetXField: string;
    function GetYField: string;
    function GetDisplayName: string;
    function GetStyle: TKChartSeriesStyleConfig;
  public
    [YamlNode('Type', 'Series type: bar, line, pie, area')]
    property &Type: string read GetType;

    [YamlNode('XField', 'X axis data field')]
    property XField: string read GetXField;

    [YamlNode('YField', 'Y axis data field')]
    property YField: string read GetYField;

    [YamlNode('DisplayName', 'Legend label for this series')]
    property DisplayName: string read GetDisplayName;

    [YamlSubNode('Style', TKChartSeriesStyleConfig, 'Series visual style')]
    property Style: TKChartSeriesStyleConfig read GetStyle;
  end;

  /// <summary>
  ///  Chart axis configuration (X or Y).
  ///  YAML path: Chart/Axes/X or Chart/Axes/Y
  /// </summary>
  TKChartAxisConfig = class(TEFNode)
  private
    function GetField: string;
    function GetTitle: string;
    function GetMajorTimeUnit: string;
    function GetMajorUnit: string;
    function GetMinorUnit: string;
    function GetMax: string;
    function GetMin: string;
  public
    [YamlNode('Field', 'Data field bound to this axis')]
    property Field: string read GetField;

    [YamlNode('Title', 'Axis title text')]
    property Title: string read GetTitle;

    [YamlNode('MajorTimeUnit', 'Time unit for major ticks (day, month, year)')]
    property MajorTimeUnit: string read GetMajorTimeUnit;

    [YamlNode('MajorUnit', 'Major tick interval')]
    property MajorUnit: string read GetMajorUnit;

    [YamlNode('MinorUnit', 'Minor tick interval')]
    property MinorUnit: string read GetMinorUnit;

    [YamlNode('Max', 'Axis maximum value')]
    property Max: string read GetMax;

    [YamlNode('Min', 'Axis minimum value')]
    property Min: string read GetMin;
  end;

  /// <summary>
  ///  Root chart configuration.
  ///  YAML path: Chart
  /// </summary>
  TKChartConfig = class(TEFNode)
  private
    function GetType: string;
    function GetChartStyle: string;
    function GetTipRenderer: string;
    function GetDataField: string;
    function GetCategoryField: string;
    function GetLegend: TKChartLegendConfig;
    function GetSeries: TEFNode;
    function GetAxes: TEFNode;
  public
    [YamlNode('Type', 'Chart type: cartesian, polar')]
    property &Type: string read GetType;

    [YamlNode('ChartStyle', 'CSS style applied to the chart container')]
    property ChartStyle: string read GetChartStyle;

    [YamlNode('TipRenderer', 'JS function name for tooltip rendering')]
    property TipRenderer: string read GetTipRenderer;

    [YamlNode('DataField', 'Primary data field name')]
    property DataField: string read GetDataField;

    [YamlNode('CategoryField', 'Category axis field name')]
    property CategoryField: string read GetCategoryField;

    [YamlSubNode('Legend', TKChartLegendConfig, 'Chart legend')]
    property Legend: TKChartLegendConfig read GetLegend;

    [YamlContainer('Series', TKChartSeriesConfig, 'Chart data series')]
    property Series: TEFNode read GetSeries;

    [YamlContainer('Axes', TKChartAxisConfig, 'Chart axes')]
    property Axes: TEFNode read GetAxes;
  end;

  { ---------- Filter item types ---------- }

  /// <summary>
  ///  Free-text search filter.
  ///  YAML path: Filters/Items/FreeSearch
  /// </summary>
  TKFilterItemFreeSearch = class(TEFNode)
  private
    function GetDefaultValue: string;
    function GetExpressionTemplate: string;
  public
    [YamlNode('DefaultValue', 'Initial search text')]
    property DefaultValue: string read GetDefaultValue;

    [YamlRequiredNode('ExpressionTemplate', 'SQL WHERE template with {value} placeholder')]
    property ExpressionTemplate: string read GetExpressionTemplate;
  end;

  /// <summary>
  ///  Dynamic list filter populated by a SQL query.
  ///  YAML path: Filters/Items/DynaList
  /// </summary>
  TKFilterItemDynaList = class(TEFNode)
  private
    function GetExpressionTemplate: string;
    function GetCommandText: string;
    function GetWidth: Integer;
    function GetListWidth: Integer;
    function GetAutoCompleteMinChars: Integer;
  public
    [YamlRequiredNode('ExpressionTemplate', 'SQL WHERE template with {value} placeholder')]
    property ExpressionTemplate: string read GetExpressionTemplate;

    [YamlRequiredNode('CommandText', 'SQL query returning key/display pairs')]
    property CommandText: string read GetCommandText;

    [YamlNode('Width', '20', 'Input width in characters')]
    property Width: Integer read GetWidth;

    [YamlNode('ListWidth', '20', 'Dropdown list width in characters')]
    property ListWidth: Integer read GetListWidth;

    [YamlNode('AutoCompleteMinChars', '0', 'Min chars before autocomplete triggers')]
    property AutoCompleteMinChars: Integer read GetAutoCompleteMinChars;
  end;

  /// <summary>
  ///  Date-range search filter.
  ///  YAML path: Filters/Items/DateSearch
  /// </summary>
  TKFilterItemDateSearch = class(TEFNode)
  private
    function GetDefaultValue: string;
    function GetExpressionTemplate: string;
  public
    [YamlNode('DefaultValue', 'Initial date value')]
    property DefaultValue: string read GetDefaultValue;

    [YamlRequiredNode('ExpressionTemplate', 'SQL WHERE template with {value} placeholder')]
    property ExpressionTemplate: string read GetExpressionTemplate;
  end;

  /// <summary>
  ///  Static list filter with predefined items.
  ///  YAML path: Filters/Items/List
  /// </summary>
  TKFilterItemList = class(TEFNode)
  private
    function GetWidth: Integer;
    function GetListWidth: Integer;
    function GetAutoCompleteMinChars: Integer;
  public
    [YamlNode('Width', '20', 'Input width in characters')]
    property Width: Integer read GetWidth;

    [YamlNode('ListWidth', '20', 'Dropdown list width in characters')]
    property ListWidth: Integer read GetListWidth;

    [YamlNode('AutoCompleteMinChars', '0', 'Min chars before autocomplete triggers')]
    property AutoCompleteMinChars: Integer read GetAutoCompleteMinChars;
  end;

  /// <summary>
  ///  Apply/Search button in a filter panel.
  ///  YAML path: Filters/Items/ApplyButton
  /// </summary>
  TKFilterItemApplyButton = class(TEFNode)
  private
    function GetImageName: string;
  public
    [YamlNode('ImageName', 'Find', 'Icon name for the apply button')]
    property ImageName: string read GetImageName;
  end;

  /// <summary>
  ///  Column break in filter panel layout.
  ///  YAML path: Filters/Items/ColumnBreak
  /// </summary>
  TKFilterItemColumnBreak = class(TEFNode)
  private
    function GetLabelWidth: Integer;
  public
    [YamlNode('LabelWidth', '50', 'Label width in pixels for the next column')]
    property LabelWidth: Integer read GetLabelWidth;
  end;

  /// <summary>
  ///  Spacer element in a filter panel.
  ///  YAML path: Filters/Items/Spacer
  /// </summary>
  TKFilterItemSpacer = class(TEFNode)
  private
    function GetWidth: Integer;
  public
    [YamlNode('Width', '1', 'Spacer width in characters')]
    property Width: Integer read GetWidth;
  end;

  { ---------- DB Adapter connection configs ---------- }

  /// <summary>
  ///  FireDAC connection parameters.
  ///  YAML path: DatabaseRouter/DatabaseName/Connection
  /// </summary>
  TEFDBFDConnectionConfig = class(TEFNode)
  private
    function GetDriverID: string;
    function GetServer: string;
    function GetApplicationName: string;
    function GetDatabase: string;
    function GetOSAuthent: string;
    function GetIsolation: string;
    function GetUser_Name: string;
    function GetPassword: string;
    function GetCharacterSet: string;
    function GetProtocol: string;
  public
    [YamlNode('DriverID', 'FireDAC driver identifier (e.g. MSSQL, FB, PG)')]
    property DriverID: string read GetDriverID;

    [YamlNode('Server', 'Database server host name or address')]
    property Server: string read GetServer;

    [YamlNode('ApplicationName', 'Application name reported to the server')]
    property ApplicationName: string read GetApplicationName;

    [YamlNode('Database', 'Database name or path')]
    property Database: string read GetDatabase;

    [YamlNode('OSAuthent', 'OS-level authentication (Yes/No)')]
    property OSAuthent: string read GetOSAuthent;

    [YamlNode('Isolation', 'Transaction isolation level')]
    property Isolation: string read GetIsolation;

    [YamlNode('User_Name', 'Database user name')]
    property User_Name: string read GetUser_Name;

    [YamlNode('Password', 'Database password')]
    property Password: string read GetPassword;

    [YamlNode('CharacterSet', 'Connection character set')]
    property CharacterSet: string read GetCharacterSet;

    [YamlNode('Protocol', 'Network protocol')]
    property Protocol: string read GetProtocol;
  end;

  /// <summary>
  ///  DBExpress connection parameters.
  ///  YAML path: DatabaseRouter/DatabaseName/Connection
  /// </summary>
  TEFDBDBXConnectionConfig = class(TEFNode)
  private
    function GetDriverName: string;
    function GetDatabase: string;
    function GetUser_Name: string;
    function GetPassword: string;
    function GetServerCharSet: string;
    function GetWaitOnLocks: string;
    function GetIsolationLevel: string;
    function GetHostName: string;
  public
    [YamlNode('DriverName', 'DBExpress driver name')]
    property DriverName: string read GetDriverName;

    [YamlNode('Database', 'Database name or path')]
    property Database: string read GetDatabase;

    [YamlNode('User_Name', 'Database user name')]
    property User_Name: string read GetUser_Name;

    [YamlNode('Password', 'Database password')]
    property Password: string read GetPassword;

    [YamlNode('ServerCharSet', 'Server character set')]
    property ServerCharSet: string read GetServerCharSet;

    [YamlNode('WaitOnLocks', 'Wait on locks behaviour')]
    property WaitOnLocks: string read GetWaitOnLocks;

    [YamlNode('IsolationLevel', 'Transaction isolation level')]
    property IsolationLevel: string read GetIsolationLevel;

    [YamlNode('HostName', 'Database server host name')]
    property HostName: string read GetHostName;
  end;

  /// <summary>
  ///  ADO/OLEDB connection parameters.
  ///  YAML path: DatabaseRouter/DatabaseName/Connection
  /// </summary>
  TEFDBADOConnectionConfig = class(TEFNode)
  private
    function GetProvider: string;
    function GetTrusted_Connection: string;
    function GetInitialCatalog: string;
    function GetDataSource: string;
    function GetUserId: string;
    function GetPassword: string;
  public
    [YamlNode('Provider', 'OLE DB provider name')]
    property Provider: string read GetProvider;

    [YamlNode('Trusted_Connection', 'Use Windows integrated auth (yes/no)')]
    property Trusted_Connection: string read GetTrusted_Connection;

    [YamlNode('Initial Catalog', 'Database (catalog) name')]
    property InitialCatalog: string read GetInitialCatalog;

    [YamlNode('Data Source', 'Server name or instance')]
    property DataSource: string read GetDataSource;

    [YamlNode('User Id', 'Database user name')]
    property UserId: string read GetUserId;

    [YamlNode('Password', 'Database password')]
    property Password: string read GetPassword;
  end;

implementation

{ TKGroupingShowCountConfig }

function TKGroupingShowCountConfig.GetItemName: string;
begin
  Result := GetString('ItemName');
end;

function TKGroupingShowCountConfig.GetPluralItemName: string;
begin
  Result := GetString('PluralItemName');
end;

function TKGroupingShowCountConfig.GetTemplate: string;
begin
  Result := GetString('Template');
end;

{ TKGroupingConfig }

function TKGroupingConfig.GetFieldName: string;
begin
  Result := GetString('FieldName');
end;

function TKGroupingConfig.GetSortFieldNames: string;
begin
  Result := GetString('SortFieldNames');
end;

function TKGroupingConfig.GetEnableMenu: Boolean;
begin
  Result := GetBoolean('EnableMenu', False);
end;

function TKGroupingConfig.GetStartCollapsed: Boolean;
begin
  Result := GetBoolean('StartCollapsed', False);
end;

function TKGroupingConfig.GetShowName: Boolean;
begin
  Result := GetBoolean('ShowName', False);
end;

function TKGroupingConfig.GetShowCount: TKGroupingShowCountConfig;
begin
  Result := nil; // RTTI discovery only
end;

{ TKPopupWindowConfig }

function TKPopupWindowConfig.GetWidth: Integer;
begin
  Result := GetInteger('Width', 800);
end;

function TKPopupWindowConfig.GetHeight: Integer;
begin
  Result := GetInteger('Height', 600);
end;

{ TKFormControllerButtonConfig }

function TKFormControllerButtonConfig.GetCaption: string;
begin
  Result := GetString('Caption');
end;

function TKFormControllerButtonConfig.GetToolTip: string;
begin
  Result := GetString('ToolTip');
end;

{ TKFormControllerConfig }

function TKFormControllerConfig.GetKeepOpenAfterOperation: Boolean;
begin
  Result := GetBoolean('KeepOpenAfterOperation', False);
end;

function TKFormControllerConfig.GetButtonScale: string;
begin
  Result := GetString('ButtonScale');
end;

function TKFormControllerConfig.GetCloneButton: TKFormControllerButtonConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKFormControllerConfig.GetConfirmButton: TKFormControllerButtonConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKFormControllerConfig.GetCancelButton: TKFormControllerButtonConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKFormControllerConfig.GetCloseButton: TKFormControllerButtonConfig;
begin
  Result := nil; // RTTI discovery only
end;

{ TKToolViewItem }

function TKToolViewItem.GetDisplayLabel: string;
begin
  Result := GetString('DisplayLabel');
end;

function TKToolViewItem.GetImageName: string;
begin
  Result := GetString('ImageName');
end;

function TKToolViewItem.GetControllerType: string;
begin
  Result := GetString('Controller');
end;

function TKToolViewItem.GetRequireSelection: Boolean;
begin
  Result := GetBoolean('RequireSelection', False);
end;

function TKToolViewItem.GetAutoRefresh: string;
begin
  Result := GetString('AutoRefresh', 'All');
end;

function TKToolViewItem.GetConfirmationMessage: string;
begin
  Result := GetString('ConfirmationMessage');
end;

{ TKViewTableControllerConfig }

function TKViewTableControllerConfig.GetAutoOpen: Boolean;
begin
  Result := GetBoolean('AutoOpen', False);
end;

function TKViewTableControllerConfig.GetPageRecordCount: Integer;
begin
  Result := GetInteger('PageRecordCount');
end;

function TKViewTableControllerConfig.GetPagingTools: Boolean;
begin
  Result := GetBoolean('PagingTools', True);
end;

function TKViewTableControllerConfig.GetRowClassProvider: string;
begin
  Result := GetString('RowClassProvider');
end;

function TKViewTableControllerConfig.GetAllowViewing: Boolean;
begin
  Result := GetBoolean('AllowViewing', False);
end;

function TKViewTableControllerConfig.GetPreventEditing: Boolean;
begin
  Result := GetBoolean('PreventEditing', False);
end;

function TKViewTableControllerConfig.GetPreventAdding: Boolean;
begin
  Result := GetBoolean('PreventAdding', False);
end;

function TKViewTableControllerConfig.GetPreventDeleting: Boolean;
begin
  Result := GetBoolean('PreventDeleting', False);
end;

function TKViewTableControllerConfig.GetAllowDuplicating: Boolean;
begin
  Result := GetBoolean('AllowDuplicating', False);
end;

function TKViewTableControllerConfig.GetToolViews: TKToolViewsConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKViewTableControllerConfig.GetPopupWindow: TKPopupWindowConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKViewTableControllerConfig.GetGrouping: TKGroupingConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKViewTableControllerConfig.GetFormController: TKFormControllerConfig;
begin
  Result := nil; // RTTI discovery only
end;

{ TKLayoutFieldConfig }

function TKLayoutFieldConfig.GetCharWidth: Integer;
begin
  Result := GetInteger('CharWidth');
end;

function TKLayoutFieldConfig.GetDisplayWidth: Integer;
begin
  Result := GetInteger('DisplayWidth');
end;

function TKLayoutFieldConfig.GetAlignment: string;
begin
  Result := GetString('Alignment');
end;

function TKLayoutFieldConfig.GetIsReadOnly: Boolean;
begin
  Result := GetBoolean('IsReadOnly', False);
end;

function TKLayoutFieldConfig.GetDisplayFormat: string;
begin
  Result := GetString('DisplayFormat');
end;

{ TKLayoutFieldSetConfig }

function TKLayoutFieldSetConfig.GetTitle: string;
begin
  Result := GetString('Title');
end;

function TKLayoutFieldSetConfig.GetCollapsible: Boolean;
begin
  Result := GetBoolean('Collapsible', False);
end;

{ TKChartSeriesStyleConfig }

function TKChartSeriesStyleConfig.GetColor: string;
begin
  Result := GetString('Color');
end;

function TKChartSeriesStyleConfig.GetImage: string;
begin
  Result := GetString('Image');
end;

function TKChartSeriesStyleConfig.GetMode: string;
begin
  Result := GetString('Mode');
end;

{ TKChartSeriesConfig }

function TKChartSeriesConfig.GetType: string;
begin
  Result := GetString('Type');
end;

function TKChartSeriesConfig.GetXField: string;
begin
  Result := GetString('XField');
end;

function TKChartSeriesConfig.GetYField: string;
begin
  Result := GetString('YField');
end;

function TKChartSeriesConfig.GetDisplayName: string;
begin
  Result := GetString('DisplayName');
end;

function TKChartSeriesConfig.GetStyle: TKChartSeriesStyleConfig;
begin
  Result := nil; // RTTI discovery only
end;

{ TKChartAxisConfig }

function TKChartAxisConfig.GetField: string;
begin
  Result := GetString('Field');
end;

function TKChartAxisConfig.GetTitle: string;
begin
  Result := GetString('Title');
end;

function TKChartAxisConfig.GetMajorTimeUnit: string;
begin
  Result := GetString('MajorTimeUnit');
end;

function TKChartAxisConfig.GetMajorUnit: string;
begin
  Result := GetString('MajorUnit');
end;

function TKChartAxisConfig.GetMinorUnit: string;
begin
  Result := GetString('MinorUnit');
end;

function TKChartAxisConfig.GetMax: string;
begin
  Result := GetString('Max');
end;

function TKChartAxisConfig.GetMin: string;
begin
  Result := GetString('Min');
end;

{ TKChartConfig }

function TKChartConfig.GetType: string;
begin
  Result := GetString('Type');
end;

function TKChartConfig.GetChartStyle: string;
begin
  Result := GetString('ChartStyle');
end;

function TKChartConfig.GetTipRenderer: string;
begin
  Result := GetString('TipRenderer');
end;

function TKChartConfig.GetDataField: string;
begin
  Result := GetString('DataField');
end;

function TKChartConfig.GetCategoryField: string;
begin
  Result := GetString('CategoryField');
end;

function TKChartConfig.GetLegend: TKChartLegendConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKChartConfig.GetSeries: TEFNode;
begin
  Result := nil; // RTTI discovery only
end;

function TKChartConfig.GetAxes: TEFNode;
begin
  Result := nil; // RTTI discovery only
end;

{ TKFilterItemFreeSearch }

function TKFilterItemFreeSearch.GetDefaultValue: string;
begin
  Result := GetString('DefaultValue');
end;

function TKFilterItemFreeSearch.GetExpressionTemplate: string;
begin
  Result := GetString('ExpressionTemplate');
end;

{ TKFilterItemDynaList }

function TKFilterItemDynaList.GetExpressionTemplate: string;
begin
  Result := GetString('ExpressionTemplate');
end;

function TKFilterItemDynaList.GetCommandText: string;
begin
  Result := GetString('CommandText');
end;

function TKFilterItemDynaList.GetWidth: Integer;
begin
  Result := GetInteger('Width', 20);
end;

function TKFilterItemDynaList.GetListWidth: Integer;
begin
  Result := GetInteger('ListWidth', 20);
end;

function TKFilterItemDynaList.GetAutoCompleteMinChars: Integer;
begin
  Result := GetInteger('AutoCompleteMinChars', 0);
end;

{ TKFilterItemDateSearch }

function TKFilterItemDateSearch.GetDefaultValue: string;
begin
  Result := GetString('DefaultValue');
end;

function TKFilterItemDateSearch.GetExpressionTemplate: string;
begin
  Result := GetString('ExpressionTemplate');
end;

{ TKFilterItemList }

function TKFilterItemList.GetWidth: Integer;
begin
  Result := GetInteger('Width', 20);
end;

function TKFilterItemList.GetListWidth: Integer;
begin
  Result := GetInteger('ListWidth', 20);
end;

function TKFilterItemList.GetAutoCompleteMinChars: Integer;
begin
  Result := GetInteger('AutoCompleteMinChars', 0);
end;

{ TKFilterItemApplyButton }

function TKFilterItemApplyButton.GetImageName: string;
begin
  Result := GetString('ImageName', 'Find');
end;

{ TKFilterItemColumnBreak }

function TKFilterItemColumnBreak.GetLabelWidth: Integer;
begin
  Result := GetInteger('LabelWidth', 50);
end;

{ TKFilterItemSpacer }

function TKFilterItemSpacer.GetWidth: Integer;
begin
  Result := GetInteger('Width', 1);
end;

{ TEFDBFDConnectionConfig }

function TEFDBFDConnectionConfig.GetDriverID: string;
begin
  Result := GetString('DriverID');
end;

function TEFDBFDConnectionConfig.GetServer: string;
begin
  Result := GetString('Server');
end;

function TEFDBFDConnectionConfig.GetApplicationName: string;
begin
  Result := GetString('ApplicationName');
end;

function TEFDBFDConnectionConfig.GetDatabase: string;
begin
  Result := GetString('Database');
end;

function TEFDBFDConnectionConfig.GetOSAuthent: string;
begin
  Result := GetString('OSAuthent');
end;

function TEFDBFDConnectionConfig.GetIsolation: string;
begin
  Result := GetString('Isolation');
end;

function TEFDBFDConnectionConfig.GetUser_Name: string;
begin
  Result := GetString('User_Name');
end;

function TEFDBFDConnectionConfig.GetPassword: string;
begin
  Result := GetString('Password');
end;

function TEFDBFDConnectionConfig.GetCharacterSet: string;
begin
  Result := GetString('CharacterSet');
end;

function TEFDBFDConnectionConfig.GetProtocol: string;
begin
  Result := GetString('Protocol');
end;

{ TEFDBDBXConnectionConfig }

function TEFDBDBXConnectionConfig.GetDriverName: string;
begin
  Result := GetString('DriverName');
end;

function TEFDBDBXConnectionConfig.GetDatabase: string;
begin
  Result := GetString('Database');
end;

function TEFDBDBXConnectionConfig.GetUser_Name: string;
begin
  Result := GetString('User_Name');
end;

function TEFDBDBXConnectionConfig.GetPassword: string;
begin
  Result := GetString('Password');
end;

function TEFDBDBXConnectionConfig.GetServerCharSet: string;
begin
  Result := GetString('ServerCharSet');
end;

function TEFDBDBXConnectionConfig.GetWaitOnLocks: string;
begin
  Result := GetString('WaitOnLocks');
end;

function TEFDBDBXConnectionConfig.GetIsolationLevel: string;
begin
  Result := GetString('IsolationLevel');
end;

function TEFDBDBXConnectionConfig.GetHostName: string;
begin
  Result := GetString('HostName');
end;

{ TEFDBADOConnectionConfig }

function TEFDBADOConnectionConfig.GetProvider: string;
begin
  Result := GetString('Provider');
end;

function TEFDBADOConnectionConfig.GetTrusted_Connection: string;
begin
  Result := GetString('Trusted_Connection');
end;

function TEFDBADOConnectionConfig.GetInitialCatalog: string;
begin
  Result := GetString('Initial Catalog');
end;

function TEFDBADOConnectionConfig.GetDataSource: string;
begin
  Result := GetString('Data Source');
end;

function TEFDBADOConnectionConfig.GetUserId: string;
begin
  Result := GetString('User Id');
end;

function TEFDBADOConnectionConfig.GetPassword: string;
begin
  Result := GetString('Password');
end;

end.
