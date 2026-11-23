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
///  Base data panel controllers for KittoX. TKXDataPanelController provides
///  CRUD action visibility and ACL logic (same as ExtJS
///  TKExtDataPanelController.SetViewTable) plus the builders every data
///  presenter shares (filter panel, toolbar, pager, hidden state). On top of it,
///  TKXDataPanelCompositeController is the data-list host (List) that owns the
///  data context and hosts presenters in its regions, and
///  TKXDataPanelLeafController is a presenter (GridPanel, TemplateDataPanel,
///  ChartPanel, CalendarPanel) that works stand-alone or hosted.
///  Subclasses also: TKXFormPanelController.
/// </summary>
unit Kitto.Html.DataPanel;

{$I Kitto.Defines.inc}

interface

uses
  System.Generics.Collections,
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Metadata.Types,
  Kitto.Html.Base,
  Kitto.Html.Panel,
  Kitto.Html.Filters,
  Kitto.Metadata.DataView;

const
  /// <summary>Default page size of a paged data presenter (grid or cards) when
  /// Controller/PagingTools/PageRecordCount is not given.</summary>
  DEFAULT_PAGE_RECORD_COUNT = 20;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXDataPanelController = class abstract(TKXPanelControllerBase)
  strict private
    FVisibleActions: TDictionary<string, Boolean>;
    FAllowedActions: TDictionary<string, Boolean>;
    FViewTable: TKViewTable;
    function GetPreventAdding: Boolean;
    function GetPreventEditing: Boolean;
    function GetPreventDeleting: Boolean;
    function GetAllowDuplicating: Boolean;
    function GetAllowViewing: Boolean;
    function GetPreventHelp: Boolean;
    function GetPreventRefreshing: Boolean;
    function GetToolButtonScale: string;
    function GetFilters: TKFilterPanelConfig;
  strict protected
    /// <summary>
    ///  Returns the ViewTable for the current DataView.
    ///  Resolves on first call from the View property.
    /// </summary>
    function GetViewTable: TKViewTable;

    /// <summary>
    ///  Override in subclasses to declare which action names are supported
    ///  (e.g. 'Add', 'Edit', 'Delete', 'View', 'Dup').
    ///  Default returns True for all standard actions.
    /// </summary>
    function IsActionSupported(const AActionName: string): Boolean; virtual;

    /// <summary>
    ///  Reads YAML config flags and populates the visibility/allowed dictionaries.
    ///  Called from DoDisplay. Mirrors ExtJS TKExtDataPanelController.SetViewTable logic.
    ///  Checks Config (direct + CenterController path), ViewTable.Controller path,
    ///  View.IsReadOnly, ViewTable.IsReadOnly, and ACL (IsAccessGranted).
    /// </summary>
    procedure InitActions; virtual;

    /// <summary>Sets one action's visibility and permission. A hosted
    /// presenter uses it to take over the actions its host computed.</summary>
    procedure SetAction(const AActionName: string; const AVisible, AAllowed: Boolean);

    procedure DoDisplay; override;

    /// <summary>
    ///  Reads a Boolean config value checking both the direct Config path
    ///  and the CenterController subpath (for KittoX YAML compatibility).
    ///  Example: GetConfigBoolean('AllowViewing') checks Config/AllowViewing
    ///  then Config/CenterController/AllowViewing.
    /// </summary>
    function GetConfigBoolean(const APath: string;
      ADefault: Boolean = False): Boolean; virtual;
    function GetConfigString(const APath: string;
      const ADefault: string = ''): string; virtual;

    /// <summary>
    ///  Builds the collapsible filter panel shown above the data presenter.
    ///  Lives on the data panel (not on the grid): the filter belongs to the
    ///  list of data, whatever presents it (grid, cards, chart).
    ///  AUrlViewName: when non-empty, used for hx-get URL paths (AViewName for IDs).
    /// </summary>
    function BuildFilterPanel(const AViewName: string;
      AViewTable: TKViewTable; out ADefaultFilterExpr: string;
      const AUrlViewName: string = ''): string;
    /// <summary>
    ///  Builds the CRUD toolbar (Add, Dup, Edit, Delete, View, Refresh, Help,
    ///  ToolViews). In lookup mode, emits the hidden lookup inputs instead.
    ///  AUrlViewName: when non-empty, used for URL paths (AViewName for IDs).
    /// </summary>
    function BuildToolbar(const AViewName: string;
      const AUrlViewName: string = ''): string;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;

    /// <summary>The view table this data panel operates on.</summary>
    property ViewTable: TKViewTable read GetViewTable;

    /// <summary>Returns True if the action button should be visible.</summary>
    function IsActionVisible(const AActionName: string): Boolean;

    /// <summary>Returns True if the action is visible AND the user has ACL permission.</summary>
    function IsActionAllowed(const AActionName: string): Boolean;

    [YamlNode('PreventAdding', 'False', 'Hide the Add button')]
    property PreventAdding: Boolean read GetPreventAdding;
    [YamlNode('PreventEditing', 'False', 'Hide the Edit button')]
    property PreventEditing: Boolean read GetPreventEditing;
    [YamlNode('PreventDeleting', 'False', 'Hide the Delete button')]
    property PreventDeleting: Boolean read GetPreventDeleting;
    [YamlNode('AllowDuplicating', 'False', 'Show the Duplicate button')]
    property AllowDuplicating: Boolean read GetAllowDuplicating;
    [YamlNode('AllowViewing', 'False', 'Show the View (read-only) button')]
    property AllowViewing: Boolean read GetAllowViewing;
    [YamlNode('PreventHelp', 'False', 'Hide the contextual Help button on this data view')]
    property PreventHelp: Boolean read GetPreventHelp;
    [YamlNode('PreventRefreshing', 'False', 'Hide the Refresh button')]
    property PreventRefreshing: Boolean read GetPreventRefreshing;

    [YamlNode('ToolButtonScale', 'small', 'Toolbar button scale: small / medium / large')]
    [YamlEnumType(TypeInfo(TKToolButtonScale))]
    property ToolButtonScale: string read GetToolButtonScale;
    /// <summary>RTTI carrier of the Filters sub-node (the filter panel shown
    /// above the data presenter). The getter returns nil: the sub-tree is
    /// described by TKFilterPanelConfig, which is what the validator and
    /// designer read.</summary>
    [YamlSubNode('Filters', TKFilterPanelConfig, 'Filter panel: the filter items shown above the data')]
    property Filters: TKFilterPanelConfig read GetFilters;

    /// <summary>Builds the hidden state &lt;div&gt; carrying sort/dir/limit (and the
    /// lookup context) so it survives HTMX search/paging via hx-include. Shared by
    /// every presenter (grid, cards); callers may qualify it with any descendant.</summary>
    class function BuildHiddenState(const AViewName: string;
      ALimit: Integer; const ASort, ADir: string;
      const AUrlViewName: string = ''): string;

    /// <summary>Builds the pager (page buttons / record range) for the given
    /// totals. Shared by every paged presenter (grid, cards).</summary>
    class function BuildPager(const AViewName: string;
      ATotal, AStart, ALimit: Integer;
      const AUrlViewName: string = ''): string;

    /// <summary>
    ///  In lookup mode (mode=lookup with cv/cf query/state fields), returns the
    ///  expanded LookupFilter of the calling reference field, so a dedicated
    ///  IsLookup presenter honors the same restriction the inline data-options
    ///  combo would apply (e.g. {MasterRecord.PaganteId}). {MasterRecord.*}/
    ///  {Field} macros are resolved against the calling form's session record.
    ///  Returns '' when not in lookup mode or the calling field has no
    ///  LookupFilter.
    /// </summary>
    class function GetLookupContextFilter: string;
  end;

  TKXDataPanelCompositeController = class;

  /// <summary>
  ///  A data presenter: shows the records of a view table in one way (grid,
  ///  cards, chart, calendar). On its own (Controller: TemplateDataPanel at the
  ///  root of a view) it makes its data context itself and renders its filter
  ///  panel and toolbar; hosted in a region of a TKXDataPanelCompositeController
  ///  (the Center of a List, a WestController: GridPanel) it takes the shared
  ///  context from the host: the actions the host computed, the host's filter
  ///  expression for its initial load, the host's list-level options as a
  ///  fallback for its own. Kitto1 had TKExtDataPanelLeafController; here the
  ///  "shared store" is the view table plus the filter expression, since every
  ///  presenter loads per request from its own endpoint.
  /// </summary>
  TKXDataPanelLeafController = class abstract(TKXDataPanelController)
  strict private
    FHostPanel: TKXDataPanelCompositeController;
    FRegionName: string;
  strict protected
    /// <summary>Hosted: takes over the host's actions, narrowed to those this
    /// presenter supports. Stand-alone: computes them from its own config.</summary>
    procedure InitActions; override;
    /// <summary>Own (presentation) options first, then the host's list-level
    /// ones, so ToolButtonScale or PreventHelp set on the List reach a hosted
    /// grid, and a calendar's DefaultView is read from its own node.</summary>
    function GetConfigBoolean(const APath: string;
      ADefault: Boolean = False): Boolean; override;
    function GetConfigString(const APath: string;
      const ADefault: string = ''): string; override;
    /// <summary>
    ///  The filter panel for this presenter's rendering. Stand-alone it is built
    ///  here (BuildFilterPanel); hosted it returns '' and the host's filter
    ///  expression, because the host has rendered the panel above the presenter
    ///  and owns the expression its default values select.
    /// </summary>
    function ResolveFilterPanel(const AViewAlias: string;
      AViewTable: TKViewTable; out ADefaultFilterExpr: string;
      const AUrlViewName: string = ''): string;
  public
    /// <summary>The composite hosting this presenter, nil when stand-alone.</summary>
    property HostPanel: TKXDataPanelCompositeController read FHostPanel;
    /// <summary>The region of the host this presenter sits in ('Center', 'West', ...).</summary>
    property RegionName: string read FRegionName;
    /// <summary>True when hosted by a composite data panel.</summary>
    function IsHosted: Boolean;
    /// <summary>Attaches this presenter to its host, before Display.</summary>
    procedure AttachToHost(const AHost: TKXDataPanelCompositeController;
      const ARegionName: string);
    /// <summary>Renders the presenter's content without panel chrome: the host
    /// puts it inside its own chrome (Center) or region. The presenter's own
    /// regions (e.g. a NorthController: StatusBar above a hosted form) wrap the
    /// content; a presenter with none renders its content as is.</summary>
    function RenderHosted: string; virtual;
    /// <summary>The presenter's panel CSS class, for the host's chrome.</summary>
    function HostedCssClass: string;
  end;

  /// <summary>
  ///  A data-list host: owns the data context (view table, filter panel and its
  ///  expression, action flags) and hosts the presenters that show the data in
  ///  its regions. The Center presenter is created here (CenterView, or
  ///  CenterController with the default type filled in when the node is missing
  ///  or carries only options) and rendered bare inside this panel's chrome,
  ///  which takes the presenter's CSS class; the other regions go through the
  ///  standard border-layout rendering with a hook that attaches each presenter
  ///  to this host. Kitto1 had TKExtDataPanelCompositeController.
  /// </summary>
  TKXDataPanelCompositeController = class abstract(TKXDataPanelController)
  strict private
    FFilterExpression: string;
    FCenterPresenter: IKXController;
    FCenterLeaf: TKXDataPanelLeafController;
    function EnsureCenterPresenter: IKXController;
    function HookRegion(const AController: IKXController;
      const ARegionName: string; out AContent: string): Boolean;
  strict protected
    /// <summary>
    ///  Default controller type for a region whose node is missing or has no
    ///  value ('' = no default: the region stays empty). The List answers
    ///  'GridPanel' for 'Center', which is what makes "Controller: List" alone
    ///  render a grid.
    /// </summary>
    function GetRegionDefaultControllerClass(const ARegionName: string): string; virtual;
    function GetRegionRenderHook: TKXRegionRenderHook; override;
    function GetPanelCssClass: string; override;
    /// <summary>Filter panel of the host, then the Center presenter, bare.</summary>
    function RenderContent: string; override;
    /// <summary>Builds the filter panel and remembers the expression its
    /// default values select (FilterExpression), for the presenters.</summary>
    function RenderFilterPanel(const AViewAlias, AUrlViewName: string): string;
  public
    /// <summary>The WHERE expression selected by the filter panel's default
    /// values, valid once RenderContent has built the panel. Presenters use it
    /// for their initial load so grid and chart show the same rows.</summary>
    property FilterExpression: string read FFilterExpression;
    /// <summary>The Center presenter, created on first render.</summary>
    property CenterPresenter: IKXController read FCenterPresenter;
    /// <summary>List-level option lookup for hosted presenters (own Config,
    /// with the CenterController/ compatibility fallback).</summary>
    function ResolveOptionString(const APath, ADefault: string): string;
    function ResolveOptionBoolean(const APath: string; ADefault: Boolean): Boolean;
  end;

/// <summary>
///  Returns the hx-include CSS selector for a given view name: the hidden state
///  div and the filter form (if present). If #kx-filter-form-{ViewName} does not
///  exist, HTMX silently ignores it. Shared by the filter panel and the grid's
///  headers/pager, which all post the same state.
/// </summary>
function HxInclude(const AViewName: string): string;

/// <summary>Combines two SQL WHERE expressions with AND, tolerating empty
/// operands (either side may be ''). Used to AND the filter panel's expression
/// with the lookup context filter before loading a presenter's store.</summary>
function CombineWhere(const A, B: string): string;

/// <summary>Builds the WHERE expression selected by the current values of a
/// data panel's filter panel, read from the request as f_N fields (the way the
/// filter form posts them): AControllerNode is the view's Controller node that
/// carries Filters/Items and Filters/Connector. '' when there is no filter
/// panel or no node. Shared by every data endpoint (grid rows, chart data,
/// calendar events) so all presenters of a view apply the same filter.</summary>
function BuildRequestFilterExpression(const AControllerNode: TEFNode): string;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.Math,
  System.NetEncoding,
  Data.DB,
  EF.DB,
  EF.Types,
  EF.Localization,
  Kitto.Config,
  Kitto.AccessControl,
  Kitto.Metadata.Views,
  Kitto.Html.Controller,
  Kitto.Html.BorderPanel,
  Kitto.Html.Editors,
  Kitto.Html.Utils,
  Kitto.Html.Tools,
  Kitto.Web.Request,
  Kitto.Web.Session,
  EF.Macros;

{ TKXDataPanelController }

procedure TKXDataPanelController.AfterConstruction;
begin
  inherited;
  FVisibleActions := TDictionary<string, Boolean>.Create;
  FAllowedActions := TDictionary<string, Boolean>.Create;
end;

destructor TKXDataPanelController.Destroy;
begin
  FreeAndNil(FAllowedActions);
  FreeAndNil(FVisibleActions);
  inherited;
end;

function TKXDataPanelController.GetViewTable: TKViewTable;
begin
  if not Assigned(FViewTable) then
  begin
    if Assigned(View) and (View is TKDataView) then
      FViewTable := TKDataView(View).MainTable;
  end;
  Result := FViewTable;
end;

function TKXDataPanelController.GetConfigBoolean(const APath: string;
  ADefault: Boolean): Boolean;
begin
  // Check direct Config path first, then CenterController subpath
  Result := Config.GetBoolean(APath,
    Config.GetBoolean('CenterController/' + APath, ADefault));
end;

function TKXDataPanelController.GetConfigString(const APath: string;
  const ADefault: string): string;
begin
  Result := Config.GetString(APath,
    Config.GetString('CenterController/' + APath, ADefault));
end;

function TKXDataPanelController.IsActionSupported(const AActionName: string): Boolean;
begin
  // All standard CRUD actions are supported by default.
  // Subclasses can override to restrict (e.g. InplaceEditing hides Edit).
  Result := True;
end;

procedure TKXDataPanelController.InitActions;
var
  LIsReadOnly: Boolean;
  LVT: TKViewTable;
begin
  FVisibleActions.Clear;
  FAllowedActions.Clear;

  LVT := GetViewTable;
  if not Assigned(LVT) then
    Exit;

  LIsReadOnly := View.GetBoolean('IsReadOnly') or LVT.IsReadOnly;

  // Add è visible unless PreventAdding or read-only
  FVisibleActions.AddOrSetValue('Add',
    IsActionSupported('Add')
    and not LVT.PreventAdding
    and not GetConfigBoolean('PreventAdding')
    and not LIsReadOnly);
  FAllowedActions.AddOrSetValue('Add',
    FVisibleActions['Add'] and LVT.IsAccessGranted(ACM_ADD));

  // Dup è visible only if AllowDuplicating and not read-only
  FVisibleActions.AddOrSetValue('Dup',
    IsActionSupported('Dup')
    and (LVT.GetBoolean('Controller/AllowDuplicating')
      or GetConfigBoolean('AllowDuplicating'))
    and not LIsReadOnly);
  FAllowedActions.AddOrSetValue('Dup',
    FVisibleActions['Dup'] and LVT.IsAccessGranted(ACM_ADD));

  // Edit è visible unless PreventEditing or read-only
  FVisibleActions.AddOrSetValue('Edit',
    IsActionSupported('Edit')
    and not LVT.PreventEditing
    and not GetConfigBoolean('PreventEditing')
    and not LIsReadOnly);
  FAllowedActions.AddOrSetValue('Edit',
    FVisibleActions['Edit'] and LVT.IsAccessGranted(ACM_MODIFY));

  // Delete è visible unless PreventDeleting or read-only
  FVisibleActions.AddOrSetValue('Delete',
    IsActionSupported('Delete')
    and not LVT.PreventDeleting
    and not GetConfigBoolean('PreventDeleting')
    and not LIsReadOnly);
  FAllowedActions.AddOrSetValue('Delete',
    FVisibleActions['Delete'] and LVT.IsAccessGranted(ACM_DELETE));

  // View è visible only if AllowViewing
  FVisibleActions.AddOrSetValue('View',
    IsActionSupported('View')
    and (LVT.GetBoolean('Controller/AllowViewing')
      or GetConfigBoolean('AllowViewing')));
  FAllowedActions.AddOrSetValue('View',
    FVisibleActions['View'] and LVT.IsAccessGranted(ACM_VIEW));

  // Refresh — visible by default if actions are supported, hidden with PreventRefreshing
  FVisibleActions.AddOrSetValue('Refresh',
    IsActionSupported('Refresh')
    and not LVT.GetBoolean('Controller/PreventRefreshing')
    and not GetConfigBoolean('PreventRefreshing'));
  FAllowedActions.AddOrSetValue('Refresh', FVisibleActions['Refresh']);
end;

procedure TKXDataPanelController.DoDisplay;
begin
  InitActions;
  inherited;
end;

function TKXDataPanelController.GetPreventAdding: Boolean;
begin
  Result := GetConfigBoolean('PreventAdding');
end;

function TKXDataPanelController.GetPreventEditing: Boolean;
begin
  Result := GetConfigBoolean('PreventEditing');
end;

function TKXDataPanelController.GetPreventDeleting: Boolean;
begin
  Result := GetConfigBoolean('PreventDeleting');
end;

function TKXDataPanelController.GetAllowDuplicating: Boolean;
begin
  Result := GetConfigBoolean('AllowDuplicating');
end;

function TKXDataPanelController.GetAllowViewing: Boolean;
begin
  Result := GetConfigBoolean('AllowViewing');
end;

function TKXDataPanelController.GetPreventHelp: Boolean;
begin
  Result := GetConfigBoolean('PreventHelp');
end;

function TKXDataPanelController.GetPreventRefreshing: Boolean;
begin
  Result := GetConfigBoolean('PreventRefreshing');
end;

function TKXDataPanelController.IsActionVisible(const AActionName: string): Boolean;
begin
  if not FVisibleActions.TryGetValue(AActionName, Result) then
    Result := False;
end;

function TKXDataPanelController.IsActionAllowed(const AActionName: string): Boolean;
begin
  if not FAllowedActions.TryGetValue(AActionName, Result) then
    Result := False;
end;

procedure TKXDataPanelController.SetAction(const AActionName: string;
  const AVisible, AAllowed: Boolean);
begin
  FVisibleActions.AddOrSetValue(AActionName, AVisible);
  FAllowedActions.AddOrSetValue(AActionName, AAllowed);
end;

/// <summary>
///  Returns the hx-include CSS selector for a given view name.
///  Includes the hidden state div and the filter form (if present).
///  If #kx-filter-form-{ViewName} doesn't exist, HTMX silently ignores it.
/// </summary>
function HxInclude(const AViewName: string): string;
begin
  Result := '#kx-list-state-' + AViewName +
    ', #kx-filter-form-' + AViewName;
end;

function TKXDataPanelController.GetToolButtonScale: string;
begin
  Result := GetConfigString('ToolButtonScale', 'small');
end;

function TKXDataPanelController.GetFilters: TKFilterPanelConfig;
begin
  // RTTI carrier only: the Filters sub-tree is resolved to TKFilterPanelConfig
  // via the [YamlSubNode] attribute, not through this accessor.
  Result := nil;
end;

/// <summary>
///  Width style of a filter input from the filter's Width node, in characters
///  as in the form editors, plus the padding allowance. The same value gives
///  a text input and a select the same outer width (box-sizing is border-box
///  on .kx-filter-input), so filters stacked in a column line up. Empty when
///  Width is absent or zero: the input keeps its natural size.
/// </summary>
const
  // Closing tag of a filter row; SameRow takes it back to extend the row.
  ROW_CLOSE_TAG = '</div>';

function FilterWidthStyle(const ANode: TEFNode): string;
var
  LWidth: Integer;
begin
  LWidth := ANode.GetInteger('Width', 0);
  if LWidth <= 0 then
    Exit('');
  Result := 'width:' + IntToStr(LWidth + INPUT_EXTRA_CHS) + 'ch';
end;

function TKXDataPanelController.BuildFilterPanel(const AViewName: string;
  AViewTable: TKViewTable; out ADefaultFilterExpr: string;
  const AUrlViewName: string): string;
var
  LFiltersNode, LItemsNode, LNode, LSubItemsNode, LSubNode: TEFNode;
  I, J: Integer;
  LFilterType, LLabel, LDisplayLabel, LConnector: string;
  LLabelWidth, LCurrentLabelWidth: Integer;
  LCollapsed, LHasApplyButton, LIsSingleSelect: Boolean;
  LHxAttrs, LInc: string;
  LDefaultValues: array of string;
  LDBConnection: TEFDBConnection;
  LDBQuery: TEFDBQuery;
  LCommandText, LDefaultValue: string;
  LDefaultKey: string;
  LImageName: string;
  LUrlName: string;
  SB, SBCol, SBCols: TStringBuilder;
begin
  Result := '';
  ADefaultFilterExpr := '';

  // Resolve URL view name: use AUrlViewName for hx-get paths, AViewName for IDs
  if AUrlViewName <> '' then
    LUrlName := AUrlViewName
  else
    LUrlName := AViewName;

  LFiltersNode := Config.FindNode('Filters');
  if not Assigned(LFiltersNode) then
    Exit;
  LItemsNode := LFiltersNode.FindNode('Items');
  if not Assigned(LItemsNode) or (LItemsNode.ChildCount = 0) then
    Exit;

  LDisplayLabel := _(LFiltersNode.GetString('DisplayLabel', _('Filters')));
  LLabelWidth := LFiltersNode.GetInteger('LabelWidth', 80);
  LConnector := LFiltersNode.GetString('Connector', 'and');
  LCollapsed := LFiltersNode.GetBoolean('Collapsed', False);
  LHasApplyButton := LItemsNode.FindNode('ApplyButton') <> nil;

  LInc := HxInclude(AViewName);

  // HTMX attributes for live-mode filters (no ApplyButton)
  if not LHasApplyButton then
    LHxAttrs :=
      'hx-get="kx/view/' + LUrlName + '/data" ' +
      'hx-target="#kx-list-body-' + AViewName + '" ' +
      'hx-include="' + LInc + '" ' +
      'hx-vals=''{"start":"0"}'' '
  else
    LHxAttrs := '';

  // Initialize default values array
  SetLength(LDefaultValues, LItemsNode.ChildCount);

  LCurrentLabelWidth := LLabelWidth;
  SBCol := TStringBuilder.Create;
  SBCols := TStringBuilder.Create;
  try
    for I := 0 to LItemsNode.ChildCount - 1 do
    begin
      LNode := LItemsNode.Children[I];
      LFilterType := LNode.Name;
      LLabel := _(LNode.AsString);

      // --- ColumnBreak: close current column, start new one ---
      if SameText(LFilterType, 'ColumnBreak') then
      begin
        if SBCol.Length > 0 then
        begin
          SBCols.Append('<div class="kx-filter-column">');
          SBCols.Append(SBCol.ToString);
          SBCols.Append('</div>');
        end;
        SBCol.Clear;
        LCurrentLabelWidth := LNode.GetInteger('LabelWidth', LLabelWidth);
        Continue;
      end
      // --- Spacer: empty row ---
      else if SameText(LFilterType, 'Spacer') then
      begin
        // kx-filter-spacer: as tall as a row with an input, so the rows below it
        // line up with the other columns (an empty row would be text-high).
        SBCol.Append('<div class="kx-filter-row kx-filter-spacer" style="visibility:hidden">&nbsp;</div>');
        Continue;
      end
      // --- ApplyButton: handled separately after the loop ---
      else if SameText(LFilterType, 'ApplyButton') then
        Continue;

      // Open filter row. SameRow: True appends the filter to the row of the
      // previous one (a short input and a checkbox side by side, for example)
      // instead of starting a new row: the previous row's closing tag is taken
      // back and the label is inline, at its natural width, with no column
      // alignment. The first item of a column always opens a row.
      if LNode.GetBoolean('SameRow') and (SBCol.Length >= Length(ROW_CLOSE_TAG))
          and SBCol.ToString(SBCol.Length - Length(ROW_CLOSE_TAG), Length(ROW_CLOSE_TAG)).Equals(ROW_CLOSE_TAG) then
      begin
        SBCol.Length := SBCol.Length - Length(ROW_CLOSE_TAG);
        SBCol.Append('<label class="kx-filter-label kx-filter-label-inline">');
      end
      else
      begin
        SBCol.Append('<div class="kx-filter-row">');
        SBCol.Append('<label class="kx-filter-label" style="min-width:');
        SBCol.Append(IntToStr(LCurrentLabelWidth));
        SBCol.Append('px">');
      end;
      SBCol.Append(TNetEncoding.HTML.Encode(LLabel));
      SBCol.Append('</label>');

      // --- FreeSearch ---
      if SameText(LFilterType, 'FreeSearch') then
      begin
        LDefaultValue := LNode.GetExpandedString('DefaultValue');
        LDefaultValues[I] := LDefaultValue;
        var LCtx: TKXEditorContext;
        LCtx.InputId := 'kx-filter-' + AViewName + '-' + IntToStr(I);
        LCtx.InputName := 'f_' + IntToStr(I);
        LCtx.Value := LDefaultValue;
        LCtx.CssInputClass := 'kx-filter-input';
        LCtx.IsReadOnly := False;
        LCtx.IsRequired := False;
        LCtx.IsKey := False;
        LCtx.WidthStyle := FilterWidthStyle(LNode);
        if not LHasApplyButton then
          LCtx.ExtraAttrs := LHxAttrs + 'hx-trigger="input changed delay:300ms, search"'
        else
          LCtx.ExtraAttrs := '';
        // Placeholder: the label, as always, unless the filter has a
        // Placeholder: node, whose value (even empty) replaces it.
        if Assigned(LNode.FindNode('Placeholder')) then
          SBCol.Append(TKXEditorFactory.RenderSearchInput(LCtx,
            _(LNode.GetExpandedString('Placeholder'))))
        else
          SBCol.Append(TKXEditorFactory.RenderSearchInput(LCtx, LLabel));
      end
      // --- DynaList ---
      else if SameText(LFilterType, 'DynaList') then
      begin
        LDefaultValue := LNode.GetExpandedString('DefaultValue');
        LDefaultValues[I] := LDefaultValue;
        // Load options from SQL
        var LPairs: TEFPairs;
        SetLength(LPairs, 0);
        LCommandText := LNode.GetExpandedString('CommandText');
        LCommandText := ReplaceStr(LCommandText, '{query}', '');
        if LCommandText <> '' then
        begin
          LDBConnection := TKConfig.DatabaseFor(
            LNode.GetString('DatabaseName', AViewTable.DatabaseName));
          LDBQuery := LDBConnection.CreateDBQuery;
          try
            LDBQuery.CommandText := LCommandText;
            LDBQuery.Open;
            try
              while not LDBQuery.DataSet.Eof do
              begin
                SetLength(LPairs, Length(LPairs) + 1);
                LPairs[High(LPairs)].Key := LDBQuery.DataSet.Fields[0].AsString;
                LPairs[High(LPairs)].Value := LDBQuery.DataSet.Fields[1].AsString;
                LDBQuery.DataSet.Next;
              end;
            finally
              LDBQuery.Close;
            end;
          finally
            FreeAndNil(LDBQuery);
          end;
        end;
        var LCtx: TKXEditorContext;
        LCtx.InputId := 'kx-filter-' + AViewName + '-' + IntToStr(I);
        LCtx.InputName := 'f_' + IntToStr(I);
        LCtx.Value := LDefaultValue;
        LCtx.CssInputClass := 'kx-filter-input';
        LCtx.IsReadOnly := False;
        LCtx.IsRequired := False;
        LCtx.IsKey := False;
        LCtx.TriggerWidthStyle := FilterWidthStyle(LNode);
        if not LHasApplyButton then
          LCtx.ExtraAttrs := LHxAttrs + 'hx-trigger="change"'
        else
          LCtx.ExtraAttrs := '';
        SBCol.Append(TKXEditorFactory.RenderSelectInput(LCtx, LPairs, True));
      end
      // --- List (static dropdown) ---
      else if SameText(LFilterType, 'List') then
      begin
        LSubItemsNode := LNode.FindNode('Items');
        // Find default item
        LDefaultKey := '';
        if Assigned(LSubItemsNode) then
        begin
          for J := 0 to LSubItemsNode.ChildCount - 1 do
            if LSubItemsNode.Children[J].GetBoolean('IsDefault') then
            begin
              LDefaultKey := LSubItemsNode.Children[J].Name;
              Break;
            end;
          if LDefaultKey = '' then
            if LSubItemsNode.ChildCount > 0 then
              LDefaultKey := LSubItemsNode.Children[0].Name;
        end;
        LDefaultValues[I] := LDefaultKey;
        // Build pairs from YAML items
        var LPairs: TEFPairs;
        if Assigned(LSubItemsNode) then
        begin
          SetLength(LPairs, LSubItemsNode.ChildCount);
          for J := 0 to LSubItemsNode.ChildCount - 1 do
          begin
            LSubNode := LSubItemsNode.Children[J];
            LPairs[J].Key := LSubNode.Name;
            LPairs[J].Value := _(LSubNode.AsExpandedString);
          end;
        end
        else
          SetLength(LPairs, 0);
        var LCtx: TKXEditorContext;
        LCtx.InputId := 'kx-filter-' + AViewName + '-' + IntToStr(I);
        LCtx.InputName := 'f_' + IntToStr(I);
        LCtx.Value := LDefaultKey;
        LCtx.CssInputClass := 'kx-filter-input';
        LCtx.IsReadOnly := False;
        LCtx.IsRequired := False;
        LCtx.IsKey := False;
        LCtx.TriggerWidthStyle := FilterWidthStyle(LNode);
        if not LHasApplyButton then
          LCtx.ExtraAttrs := LHxAttrs + 'hx-trigger="change"'
        else
          LCtx.ExtraAttrs := '';
        SBCol.Append(TKXEditorFactory.RenderSelectInput(LCtx, LPairs, False));
      end
      // --- DateSearch ---
      else if SameText(LFilterType, 'DateSearch') then
      begin
        LDefaultValue := LNode.GetExpandedString('DefaultValue');
        LDefaultValues[I] := LDefaultValue;
        var LCtx: TKXEditorContext;
        LCtx.InputId := 'kx-filter-' + AViewName + '-' + IntToStr(I);
        LCtx.InputName := 'f_' + IntToStr(I);
        LCtx.Value := LDefaultValue;
        LCtx.CssInputClass := 'kx-filter-input';
        LCtx.IsReadOnly := False;
        LCtx.IsRequired := False;
        LCtx.IsKey := False;
        LCtx.TriggerWidthStyle := FilterWidthStyle(LNode);
        if not LHasApplyButton then
          // 'change' fires immediately on calendar-picker selection and also
          // when typed input is committed; some browsers fire it on partial
          // year typing too, which would send an incomplete date to SQL
          // Server.  The filter accepts the event only when the value is
          // empty (filter cleared) or a complete 10-char ISO date
          // (YYYY-MM-DD) with year >= 1000.  No 'blur' trigger: 'change'
          // already covers every case where the filter needs to re-apply,
          // and adding 'blur' would duplicate the request (two error
          // dialogs for the same invalid date).
          LCtx.ExtraAttrs := LHxAttrs +
            'hx-trigger="change[!this.value || (this.value.length===10 && parseInt(this.value.substring(0,4))>=1000)]"'
        else
          LCtx.ExtraAttrs := '';
        SBCol.Append(TKXEditorFactory.RenderDateInput(LCtx));
      end
      // --- TimeSearch ---
      else if SameText(LFilterType, 'TimeSearch') then
      begin
        LDefaultValue := LNode.GetExpandedString('DefaultValue');
        LDefaultValues[I] := LDefaultValue;
        var LCtx: TKXEditorContext;
        LCtx.InputId := 'kx-filter-' + AViewName + '-' + IntToStr(I);
        LCtx.InputName := 'f_' + IntToStr(I);
        LCtx.Value := LDefaultValue;
        LCtx.CssInputClass := 'kx-filter-input';
        LCtx.IsReadOnly := False;
        LCtx.IsRequired := False;
        LCtx.IsKey := False;
        LCtx.TriggerWidthStyle := '';
        if not LHasApplyButton then
          // Same rationale as DateSearch above: accept empty (cleared) or a
          // complete time ('HH:MM' is 5 chars); no 'blur' trigger to avoid
          // duplicate requests.
          LCtx.ExtraAttrs := LHxAttrs +
            'hx-trigger="change[!this.value || this.value.length>=5]"'
        else
          LCtx.ExtraAttrs := '';
        SBCol.Append(TKXEditorFactory.RenderTimeInput(LCtx));
      end
      // --- DateTimeSearch ---
      else if SameText(LFilterType, 'DateTimeSearch') then
      begin
        LDefaultValue := LNode.GetExpandedString('DefaultValue');
        LDefaultValues[I] := LDefaultValue;
        var LCtx: TKXEditorContext;
        LCtx.InputId := 'kx-filter-' + AViewName + '-' + IntToStr(I);
        LCtx.InputName := 'f_' + IntToStr(I);
        LCtx.Value := LDefaultValue;
        LCtx.TimeValue := LNode.GetExpandedString('DefaultTimeValue');
        LCtx.CssInputClass := 'kx-filter-input';
        LCtx.IsReadOnly := False;
        LCtx.IsRequired := False;
        LCtx.IsKey := False;
        LCtx.TriggerWidthStyle := '';
        LCtx.EffWidth := LNode.GetInteger('Width', 10);
        if not LHasApplyButton then
          // Same rationale as DateSearch above: accept empty (cleared) or a
          // complete 'YYYY-MM-DDTHH:MM' (>=16 chars) datetime-local value
          // with year >= 1000; no 'blur' trigger to avoid duplicate requests.
          LCtx.ExtraAttrs := LHxAttrs +
            'hx-trigger="change[!this.value || (this.value.length>=16 && parseInt(this.value.substring(0,4))>=1000)]"'
        else
          LCtx.ExtraAttrs := '';
        SBCol.Append(TKXEditorFactory.RenderDateTimeInput(LCtx));
      end
      // --- BooleanSearch ---
      else if SameText(LFilterType, 'BooleanSearch') then
      begin
        LDefaultValues[I] := '';
        var LCtx: TKXEditorContext;
        LCtx.InputId := 'kx-filter-' + AViewName + '-' + IntToStr(I);
        LCtx.InputName := 'f_' + IntToStr(I);
        LCtx.Value := '';
        LCtx.CssInputClass := 'kx-filter-checkbox';
        LCtx.IsReadOnly := False;
        LCtx.IsRequired := False;
        LCtx.IsKey := False;
        if not LHasApplyButton then
          LCtx.ExtraAttrs := 'value="1" ' + LHxAttrs + 'hx-trigger="change"'
        else
          LCtx.ExtraAttrs := 'value="1"';
        SBCol.Append(TKXEditorFactory.RenderCheckboxInput(LCtx));
      end
      // --- NumericSearch ---
      else if SameText(LFilterType, 'NumericSearch') then
      begin
        LDefaultValue := LNode.GetExpandedString('DefaultValue');
        LDefaultValues[I] := LDefaultValue;
        var LCtx: TKXEditorContext;
        LCtx.InputId := 'kx-filter-' + AViewName + '-' + IntToStr(I);
        LCtx.InputName := 'f_' + IntToStr(I);
        LCtx.Value := LDefaultValue;
        LCtx.CssInputClass := 'kx-filter-input';
        LCtx.IsReadOnly := False;
        LCtx.IsRequired := False;
        LCtx.IsKey := False;
        LCtx.WidthStyle := FilterWidthStyle(LNode);
        if not LHasApplyButton then
          LCtx.ExtraAttrs := LHxAttrs + 'hx-trigger="input changed delay:300ms"'
        else
          LCtx.ExtraAttrs := '';
        SBCol.Append(TKXEditorFactory.RenderNumberInput(LCtx));
      end
      // --- ButtonList ---
      else if SameText(LFilterType, 'ButtonList') then
      begin
        LSubItemsNode := LNode.FindNode('Items');
        // Collect default keys (items with IsDefault: True)
        LDefaultKey := '';
        if Assigned(LSubItemsNode) then
          for J := 0 to LSubItemsNode.ChildCount - 1 do
            if LSubItemsNode.Children[J].GetBoolean('IsDefault') then
            begin
              if LDefaultKey <> '' then
                LDefaultKey := LDefaultKey + ',';
              LDefaultKey := LDefaultKey + LSubItemsNode.Children[J].Name;
            end;
        LDefaultValues[I] := LDefaultKey;

        LIsSingleSelect := LNode.GetBoolean('IsSingleSelect', False);
        SBCol.Append('<div class="kx-filter-buttonlist"');
        if LIsSingleSelect then
          SBCol.Append(' data-single="true"');
        SBCol.Append('>');
        if Assigned(LSubItemsNode) then
          for J := 0 to LSubItemsNode.ChildCount - 1 do
          begin
            LSubNode := LSubItemsNode.Children[J];
            SBCol.Append('<button type="button" class="kx-filter-btn');
            if LSubNode.GetBoolean('IsDefault') then
              SBCol.Append(' kx-active');
            SBCol.Append('" data-key="');
            SBCol.Append(TNetEncoding.HTML.Encode(LSubNode.Name));
            SBCol.Append('" onclick="kxFilterBtn(this)">');
            SBCol.Append(TNetEncoding.HTML.Encode(_(LSubNode.AsExpandedString)));
            SBCol.Append('</button>');
          end;
        SBCol.Append('</div>');
        // Hidden input holds comma-separated selected keys
        SBCol.Append('<input type="hidden" name="f_').Append(IntToStr(I));
        SBCol.Append('" class="kx-filter-btnlist-value" value="');
        SBCol.Append(TNetEncoding.HTML.Encode(LDefaultKey)).Append('"');
        if not LHasApplyButton then
          SBCol.Append(' ').Append(LHxAttrs).Append('hx-trigger="change"');
        SBCol.Append(' />');
      end;

      // Close filter row
      SBCol.Append(ROW_CLOSE_TAG);
    end;

    // Close last column
    if SBCol.Length > 0 then
    begin
      SBCols.Append('<div class="kx-filter-column">');
      SBCols.Append(SBCol.ToString);
      SBCols.Append('</div>');
    end;

    // ApplyButton column
    if LHasApplyButton then
    begin
      LNode := LItemsNode.FindNode('ApplyButton');
      LLabel := _(LNode.AsExpandedString);
      if LLabel = '' then
        LLabel := _('Apply');
      LImageName := LNode.GetString('ImageName', 'search');
      SBCols.Append('<div class="kx-filter-column kx-filter-apply-col">');
      SBCols.Append('<button type="button" class="kx-filter-apply-btn" ');
      SBCols.Append('hx-get="kx/view/').Append(LUrlName).Append('/data" ');
      SBCols.Append('hx-target="#kx-list-body-').Append(AViewName).Append('" ');
      SBCols.Append('hx-include="').Append(LInc).Append('" ');
      SBCols.Append('hx-vals=''{"start":"0"}''>');
      SBCols.Append(GetIconHTML(LImageName)).Append(' ');
      SBCols.Append(TNetEncoding.HTML.Encode(LLabel));
      SBCols.Append('</button></div>');
    end;

    // Build the default filter expression for initial data load
    ADefaultFilterExpr := BuildFilterExpression(LItemsNode, LConnector,
      function(AIndex: Integer): string
      begin
        if (AIndex >= 0) and (AIndex < Length(LDefaultValues)) then
          Result := LDefaultValues[AIndex]
        else
          Result := '';
      end);

    // Wrap everything in the filter panel using standard kx-panel-* classes
    SB := TStringBuilder.Create;
    try
      SB.Append('<div class="kx-panel kx-panel-collapsible kx-filter-panel');
      if LCollapsed then
        SB.Append(' kx-panel-collapsed');
      SB.Append('" id="kx-filter-panel-').Append(AViewName).Append('">');
      // Header (clickable to toggle collapse)
      SB.Append('<div class="kx-panel-header" ');
      SB.Append('onclick="this.parentElement.classList.toggle(''kx-panel-collapsed'')">');
      SB.Append('<span class="kx-panel-title">');
      SB.Append(TNetEncoding.HTML.Encode(LDisplayLabel)).Append('</span>');
      SB.Append('<span class="kx-panel-toggle">');
      SB.Append(GetIconHTML('expand_less')).Append('</span>');
      SB.Append('</div>');
      // Body (contains the filter form)
      SB.Append('<div class="kx-panel-body" id="kx-filter-form-').Append(AViewName).Append('">');
      SB.Append('<div class="kx-filter-columns">');
      SB.Append(SBCols.ToString);
      SB.Append('</div></div></div>');
      Result := SB.ToString;
    finally
      SB.Free;
    end;
  finally
    SBCol.Free;
    SBCols.Free;
  end;
end;

function TKXDataPanelController.BuildToolbar(const AViewName: string;
  const AUrlViewName: string): string;
var
  LDisplayLabel: string;
  LConfirmMsg, LConfirmTitle, LYesLabel, LNoLabel: string;
  LShowLabels: Boolean;
  LToolViewsNode, LToolNode: TEFNode;
  I: Integer;
  LToolName, LToolLabel, LToolImageName, LControllerType: string;
  LToolRequireSel: Boolean;
  LToolConfirmMsg, LToolAutoRefresh, LAcceptWildcards, LAcceptAttr: string;
  LParts: TArray<string>;
  J: Integer;
  LControllerClass: TKXComponentClass;
  LIsLookup: Boolean;
  LCallbackView, LCallbackField: string;
  SB: TStringBuilder;

  procedure AppendToolbarButton(const AAction, ATooltip, AIconName, AOnClick: string;
    ARequiresSelection: Boolean);
  begin
    if not IsActionVisible(AAction) then
      Exit;
    SB.Append('<button class="kx-toolbar-btn');
    // Only mark a selection-dependent button if it is actually allowed by
    // the ACL. The kx-requires-selection class is what kxGrid.updateButtons
    // toggles `disabled` on when the user picks a row — without this guard
    // the JS would re-enable buttons that the server had statically disabled
    // (Edit/Dup/Delete for a viewer with no MODIFY/ADD/DELETE grant).
    if ARequiresSelection and IsActionAllowed(AAction) then
      SB.Append(' kx-requires-selection');
    SB.Append('"');
    if not IsActionAllowed(AAction) then
      SB.Append(' disabled')
    else if ARequiresSelection then
      SB.Append(' disabled');
    SB.Append(' title="').Append(TNetEncoding.HTML.Encode(ATooltip)).Append('"');
    SB.Append(' onclick="').Append(AOnClick).Append('"');
    SB.Append('>').Append(GetIconHTML(AIconName));
    if LShowLabels then
      SB.Append(' <span class="kx-btn-label">').Append(TNetEncoding.HTML.Encode(_(AAction))).Append('</span>');
    SB.Append('</button>');
  end;

begin
  Result := '';
  if not Assigned(ViewTable) then
    Exit;

  LIsLookup := SameText(TKWebRequest.Current.GetQueryField('mode'), 'lookup');

  LDisplayLabel := _(ViewTable.DisplayLabel);
  // ToolButtonScale: small (default, icon-only) | medium | large (icon + text)
  LShowLabels := not SameText(GetConfigString('ToolButtonScale', 'small'), 'small');

  SB := TStringBuilder.Create;
  try
    SB.Append('<div class="kx-list-toolbar" id="kx-list-toolbar-').Append(AViewName).Append('">');

    if LIsLookup then
    begin
      // Lookup mode: no CRUD buttons, only hidden inputs.
      LCallbackView := TKWebRequest.Current.GetQueryField('cv');
      LCallbackField := TKWebRequest.Current.GetQueryField('cf');

      SB.Append('<input type="hidden" id="kx-selected-key-').Append(AViewName).Append('" value="" />');
      SB.Append('<input type="hidden" id="kx-lookup-cv-').Append(AViewName);
      SB.Append('" value="').Append(TNetEncoding.HTML.Encode(LCallbackView)).Append('" />');
      SB.Append('<input type="hidden" id="kx-lookup-cf-').Append(AViewName);
      SB.Append('" value="').Append(TNetEncoding.HTML.Encode(LCallbackField)).Append('" />');
      SB.Append('</div>');
      Result := SB.ToString;
      Exit;
    end;

    // Normal mode: CRUD toolbar

    // Delete confirmation dialog labels
    LConfirmTitle := ReplaceStr(_('Confirm'), '''', '\''');
    LConfirmMsg := Format(_('Selected %s will be deleted. Are you sure?'), [LDisplayLabel]);
    LConfirmMsg := ReplaceStr(LConfirmMsg, '''', '\''');
    LYesLabel := ReplaceStr(_('Yes'), '''', '\''');
    LNoLabel := ReplaceStr(_('No'), '''', '\''');

    // Add (no selection required)
    AppendToolbarButton('Add',
      ViewTable.GetString('Controller/Add/Tooltip', Format(_('Add %s'), [LDisplayLabel])),
      'new_record',
      'kxGrid.openForm(''' + AViewName + ''',''add'')',
      False);

    // Duplicate (requires selection)
    AppendToolbarButton('Dup',
      ViewTable.GetString('Controller/Dup/Tooltip', Format(_('Duplicate %s'), [LDisplayLabel])),
      'dup_record',
      'kxGrid.openForm(''' + AViewName + ''',''dup'')',
      True);

    // Edit (requires selection)
    AppendToolbarButton('Edit',
      ViewTable.GetString('Controller/Edit/Tooltip', Format(_('Edit %s'), [LDisplayLabel])),
      'edit_record',
      'kxGrid.openForm(''' + AViewName + ''',''edit'')',
      True);

    // Delete (requires selection, with confirmation)
    AppendToolbarButton('Delete',
      ViewTable.GetString('Controller/Delete/Tooltip', Format(_('Delete %s'), [LDisplayLabel])),
      'delete_record',
      'kxGrid.deleteRecord(''' + AViewName + ''',''' +
        LConfirmTitle + ''',''' + LConfirmMsg + ''',''' +
        LYesLabel + ''',''' + LNoLabel + ''')',
      True);

    // View (requires selection)
    AppendToolbarButton('View',
      ViewTable.GetString('Controller/View/Tooltip', Format(_('View %s'), [LDisplayLabel])),
      'view_record',
      'kxGrid.openForm(''' + AViewName + ''',''view'')',
      True);

    // Refresh (no selection required)
    AppendToolbarButton('Refresh',
      _('Refresh'),
      'refresh',
      'kxGrid.refreshData(''' + AViewName + ''')',
      False);

    // Help button. With HelpChat enabled it opens the in-app assistant with a
    // contextual question about this screen (anchored to the List controller
    // docs); otherwise (legacy) it opens the configured help URL in a new tab.
    // Shown when either the chat or a Help/HRef is available.
    var LShowHelp: Boolean;
    var LHelpHRef, LHelpHRefStyle, LHelpShort, LHelpLong: string;
    TKConfig.Instance.GetHelpSupport(LShowHelp, LHelpHRef, LHelpHRefStyle, LHelpShort, LHelpLong);
    var LHelpChatEnabled := TKConfig.Instance.Config.GetBoolean('HelpChat/Enabled', False);
    // Suppress the help button on display-only panels (e.g. dashboard KPI
    // TemplateDataPanel, where IsActionSupported is False for everything) so a
    // lone "?" doesn't sit in an otherwise-empty toolbar; also honor an explicit
    // Controller/PreventHelp opt-out on any data view.
    var LHelpSupported := IsActionSupported('Help')
      and not ViewTable.GetBoolean('Controller/PreventHelp')
      and not GetConfigBoolean('PreventHelp');
    if (LHelpChatEnabled or LShowHelp) and Assigned(View) and LHelpSupported then
    begin
      LHelpLong := Format(LHelpLong, [LDisplayLabel]);
      if LHelpChatEnabled then
      begin
        var LQuestion := Format(_('How can I use the "%s" screen?'), [LDisplayLabel]);
        SB.Append('<button type="button" class="kx-toolbar-btn kx-help-chat-btn"');
        SB.Append(' title="').Append(TNetEncoding.HTML.Encode(LHelpLong)).Append('"');
        SB.Append(' data-view="').Append(TNetEncoding.HTML.Encode(View.PersistentName)).Append('"');
        SB.Append(' data-label="').Append(TNetEncoding.HTML.Encode(LDisplayLabel)).Append('"');
        SB.Append(' data-ctype="List"');
        SB.Append(' data-question="').Append(TNetEncoding.HTML.Encode(LQuestion)).Append('"');
        SB.Append('>').Append(GetIconHTML('help'));
      end
      else
      begin
        var LHelpUrl := Format(LHelpHRef, [View.PersistentName]);
        SB.Append('<button class="kx-toolbar-btn"');
        SB.Append(' title="').Append(TNetEncoding.HTML.Encode(LHelpLong)).Append('"');
        SB.Append(' onclick="window.open(''').Append(TNetEncoding.HTML.Encode(LHelpUrl)).Append(''',''_blank'')"');
        SB.Append('>').Append(GetIconHTML('help'));
      end;
      if LShowLabels then
        SB.Append(' <span class="kx-btn-label">').Append(TNetEncoding.HTML.Encode(LHelpShort)).Append('</span>');
      SB.Append('</button>');
    end;

    // ToolView buttons (defined in MainTable/Controller/ToolViews)
    LToolViewsNode := ViewTable.FindNode('Controller/ToolViews');
    if Assigned(LToolViewsNode) and (LToolViewsNode.ChildCount > 0) then
    begin
      // Separator between CRUD and tool buttons
      SB.Append('<span class="kx-toolbar-separator"></span>');

      for I := 0 to LToolViewsNode.ChildCount - 1 do
      begin
        LToolNode := LToolViewsNode.Children[I];
        LToolName := LToolNode.Name;
        LToolLabel := _(LToolNode.GetString('DisplayLabel', LToolName));
        LToolRequireSel := LToolNode.GetBoolean('Controller/RequireSelection', True);
        LToolConfirmMsg := LToolNode.GetString('Controller/ConfirmationMessage', '');
        LToolAutoRefresh := LToolNode.GetString('Controller/AutoRefresh', '');
        LControllerType := LToolNode.GetString('Controller');

        // Resolve icon: explicit ImageName > controller class default > generic fallback
        LToolImageName := LToolNode.GetString('ImageName', '');
        if (LToolImageName = '') and (LControllerType <> '') then
        begin
          if TKXControllerRegistry.Instance.HasClass(LControllerType) then
          begin
            LControllerClass := TKXControllerRegistry.Instance.GetClass(LControllerType);
            if LControllerClass.InheritsFrom(TKXToolController) then
              LToolImageName := TKXToolControllerClass(LControllerClass).GetDefaultImageName;
          end;
        end;
        if LToolImageName = '' then
          LToolImageName := 'tool_exec';

        SB.Append('<button class="kx-toolbar-btn');
        if LToolRequireSel then
          SB.Append(' kx-requires-selection');
        SB.Append('"');
        if LToolRequireSel then
          SB.Append(' disabled');
        SB.Append(' title="').Append(TNetEncoding.HTML.Encode(LToolLabel)).Append('"');
        // Data attributes for JS executeTool handler
        SB.Append(' data-view="').Append(AViewName).Append('"');
        SB.Append(' data-tool="').Append(TNetEncoding.HTML.Encode(LToolName)).Append('"');
        if LToolRequireSel then
          SB.Append(' data-requiresel="true"');
        if LToolConfirmMsg <> '' then
          SB.Append(' data-confirm="').Append(
            TNetEncoding.HTML.Encode(ReplaceStr(_(Trim(LToolConfirmMsg)), #13#10, ' '))).Append('"');
        if LToolAutoRefresh <> '' then
          SB.Append(' data-autorefresh="').Append(TNetEncoding.HTML.Encode(LToolAutoRefresh)).Append('"');

        // Upload tool detection: controllers with 'Upload' in their name
        if ContainsText(LControllerType, 'Upload') then
        begin
          SB.Append(' data-upload="true"');
          LAcceptWildcards := LToolNode.GetString('Controller/AcceptedWildcards',
            LToolNode.GetString('Controller/WildCard', ''));
          if LAcceptWildcards <> '' then
          begin
            // Convert "*.jpg *.png" to ".jpg,.png" for HTML accept attribute
            LAcceptAttr := '';
            LParts := LAcceptWildcards.Split([' ']);
            for J := 0 to Length(LParts) - 1 do
            begin
              if LParts[J] = '*.*' then
                Continue; // accept all → omit accept attr
              if LAcceptAttr <> '' then
                LAcceptAttr := LAcceptAttr + ',';
              LAcceptAttr := LAcceptAttr + ReplaceStr(LParts[J], '*', '');
            end;
            if LAcceptAttr <> '' then
              SB.Append(' data-accept="').Append(TNetEncoding.HTML.Encode(LAcceptAttr)).Append('"');
          end;
        end;

        SB.Append(' onclick="kxGrid.executeTool(this)"');
        SB.Append('>').Append(GetIconHTML(LToolImageName));
        // Tool buttons always show their label
        SB.Append(' <span class="kx-btn-label">').Append(TNetEncoding.HTML.Encode(LToolLabel)).Append('</span>');
        SB.Append('</button>');
      end;
    end;

    // Hidden input for selected record key
    SB.Append('<input type="hidden" id="kx-selected-key-').Append(AViewName).Append('" value="" />');

    SB.Append('</div>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TKXDataPanelController.BuildHiddenState(const AViewName: string;
  ALimit: Integer; const ASort, ADir: string; const AUrlViewName: string): string;
begin
  Result :=
    '<div id="kx-list-state-' + AViewName + '" style="display:none">' +
      '<input type="hidden" name="limit" value="' + IntToStr(ALimit) + '" />' +
      '<input type="hidden" name="sort" value="' + TNetEncoding.HTML.Encode(ASort) + '" />' +
      '<input type="hidden" name="dir" value="' + TNetEncoding.HTML.Encode(ADir) + '" />';
  // In lookup mode, include viewAlias so the server can use aliased IDs in responses
  if AUrlViewName <> '' then
    Result := Result +
      '<input type="hidden" name="viewAlias" value="' +
        TNetEncoding.HTML.Encode(AViewName) + '" />';
  // In lookup mode, persist mode/cv/cf so subsequent search/paging /data
  // requests can re-apply the calling reference field's LookupFilter
  // (GetLookupContextFilter). Read from the current request (query on the
  // initial /lookup render, or state fields on later /data calls).
  if SameText(TKWebRequest.Current.GetQueryField('mode'), 'lookup') or
     SameText(TKWebRequest.Current.GetField('mode'), 'lookup') then
  begin
    var LCV := TKWebRequest.Current.GetQueryField('cv');
    if LCV = '' then LCV := TKWebRequest.Current.GetField('cv');
    var LCF := TKWebRequest.Current.GetQueryField('cf');
    if LCF = '' then LCF := TKWebRequest.Current.GetField('cf');
    Result := Result +
      '<input type="hidden" name="mode" value="lookup" />' +
      '<input type="hidden" name="cv" value="' + TNetEncoding.HTML.Encode(LCV) + '" />' +
      '<input type="hidden" name="cf" value="' + TNetEncoding.HTML.Encode(LCF) + '" />';
  end;
  Result := Result + '</div>';
end;

class function TKXDataPanelController.BuildPager(const AViewName: string;
  ATotal, AStart, ALimit: Integer; const AUrlViewName: string): string;
var
  LTotalPages: Integer;
  LCurrentPage: Integer;
  LLastStart: Integer;
  LPrevStart: Integer;
  LNextStart: Integer;
  LShowFrom, LShowTo: Integer;
  LInc: string;
  LUrlName: string;
  SB: TStringBuilder;

  procedure AppendPagerButton(const ALabel, ATitle: string;
    ATargetStart: Integer; ADisabled: Boolean);
  begin
    if ADisabled then
      SB.Append('<button disabled title="').Append(TNetEncoding.HTML.Encode(ATitle)).Append('">')
        .Append(ALabel).Append('</button>')
    else
    begin
      SB.Append('<button title="').Append(TNetEncoding.HTML.Encode(ATitle)).Append('" ');
      SB.Append('hx-get="kx/view/').Append(LUrlName).Append('/data" ');
      SB.Append('hx-target="#kx-list-body-').Append(AViewName).Append('" ');
      SB.Append('hx-include="').Append(LInc).Append('" ');
      SB.Append('hx-vals=''{"start":"').Append(IntToStr(ATargetStart)).Append('"}''>');
      SB.Append(ALabel).Append('</button>');
    end;
  end;

begin
  if AUrlViewName <> '' then
    LUrlName := AUrlViewName
  else
    LUrlName := AViewName;
  LInc := HxInclude(AViewName);
  if ALimit <= 0 then
    ALimit := 20;
  LTotalPages := Max(1, (ATotal + ALimit - 1) div ALimit);
  LCurrentPage := (AStart div ALimit) + 1;
  LLastStart := (LTotalPages - 1) * ALimit;
  LPrevStart := Max(0, AStart - ALimit);
  LNextStart := AStart + ALimit;

  SB := TStringBuilder.Create;
  try
    SB.Append('<div class="kx-list-pager" id="kx-list-pager-').Append(AViewName).Append('">');
    // Navigation: First, Prev, Next, Last
    AppendPagerButton(GetIconHTML('first_page'), _('First page') + #10 + 'CTRL+'#$2190, 0, LCurrentPage <= 1);
    AppendPagerButton(GetIconHTML('chevron_left'), _('Previous page') + #10 + #$2190, LPrevStart, LCurrentPage <= 1);
    AppendPagerButton(GetIconHTML('chevron_right'), _('Next page') + #10 + #$2192, LNextStart, LCurrentPage >= LTotalPages);
    AppendPagerButton(GetIconHTML('last_page'), _('Last page') + #10 + 'CTRL+'#$2192, LLastStart, LCurrentPage >= LTotalPages);
    // Separator + Info text
    SB.Append('<span class="kx-pager-separator"></span>');
    if ATotal = 0 then
      SB.Append('<span class="kx-pager-info">').Append(TNetEncoding.HTML.Encode(_('No records'))).Append('</span>')
    else
    begin
      LShowFrom := AStart + 1;
      LShowTo := Min(AStart + ALimit, ATotal);
      SB.Append('<span class="kx-pager-info">');
      SB.Append(Format(_('Showing %d-%d of %d'), [LShowFrom, LShowTo, ATotal]));
      SB.Append('</span>');
    end;
    SB.Append('</div>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

// Combines two SQL WHERE expressions with AND, tolerating empty operands.
function CombineWhere(const A, B: string): string;
begin
  if A = '' then
    Result := B
  else if B = '' then
    Result := A
  else
    Result := '(' + A + ') and (' + B + ')';
end;

class function TKXDataPanelController.GetLookupContextFilter: string;
var
  LMode, LCV, LCF, LFilter: string;
  LCallingView: TKView;
  LCallingTable: TKViewTable;
  LCallingField: TKViewField;
  LCallingStore: TKViewTableStore;

  function ReqVal(const AName: string): string;
  begin
    Result := TKWebRequest.Current.GetQueryField(AName);
    if Result = '' then
      Result := TKWebRequest.Current.GetField(AName);
  end;

begin
  Result := '';
  LMode := ReqVal('mode');
  if not SameText(LMode, 'lookup') then
    Exit;
  LCV := ReqVal('cv');
  LCF := ReqVal('cf');
  if (LCV = '') or (LCF = '') then
    Exit;
  LCallingView := TKConfig.Instance.Views.FindView(LCV);
  if not (LCallingView is TKDataView) then
    Exit;
  LCallingTable := TKDataView(LCallingView).MainTable;
  if not Assigned(LCallingTable) then
    Exit;
  LCallingField := LCallingTable.FindField(LCF);
  if not Assigned(LCallingField) or not LCallingField.IsReference then
    Exit;
  LFilter := LCallingField.LookupFilter;
  if LFilter = '' then
    Exit;
  // Resolve {MasterRecord.*}/{Field} macros against the calling form's session
  // record (registered under the calling view name by the form/detail handlers).
  LCallingStore := TKWebSession.Current.FindStore(LCV);
  if Assigned(LCallingStore) and (LCallingStore.RecordCount > 0) then
    LCallingStore.Records[0].ExpandExpression(LFilter);
  // Resolve generic %macros% (e.g. %Auth:PROFILEID%).
  TEFMacroExpansionEngine.Instance.Expand(LFilter);
  Result := LFilter;
end;

{ TKXDataPanelLeafController }

function TKXDataPanelLeafController.IsHosted: Boolean;
begin
  Result := Assigned(FHostPanel);
end;

procedure TKXDataPanelLeafController.AttachToHost(
  const AHost: TKXDataPanelCompositeController; const ARegionName: string);
begin
  Assert(Assigned(AHost), 'AHost');
  FHostPanel := AHost;
  FRegionName := ARegionName;
end;

procedure TKXDataPanelLeafController.InitActions;
const
  ACTIONS: array[0..5] of string = ('Add', 'Dup', 'Edit', 'Delete', 'View', 'Refresh');
var
  LAction: string;
begin
  if not Assigned(FHostPanel) then
  begin
    inherited;
    Exit;
  end;
  // The actions act on the host's data: the host computed them from its flags
  // (with the CenterController/ compatibility fallback), the view table and the
  // ACL. This presenter only narrows them to what it can show.
  for LAction in ACTIONS do
    SetAction(LAction,
      FHostPanel.IsActionVisible(LAction) and IsActionSupported(LAction),
      FHostPanel.IsActionAllowed(LAction) and IsActionSupported(LAction));
end;

function TKXDataPanelLeafController.GetConfigBoolean(const APath: string;
  ADefault: Boolean): Boolean;
begin
  if Assigned(FHostPanel) then
    Result := Config.GetBoolean(APath, FHostPanel.ResolveOptionBoolean(APath, ADefault))
  else
    Result := inherited GetConfigBoolean(APath, ADefault);
end;

function TKXDataPanelLeafController.GetConfigString(const APath: string;
  const ADefault: string): string;
begin
  if Assigned(FHostPanel) then
    Result := Config.GetString(APath, FHostPanel.ResolveOptionString(APath, ADefault))
  else
    Result := inherited GetConfigString(APath, ADefault);
end;

function TKXDataPanelLeafController.ResolveFilterPanel(const AViewAlias: string;
  AViewTable: TKViewTable; out ADefaultFilterExpr: string;
  const AUrlViewName: string): string;
begin
  if Assigned(FHostPanel) then
  begin
    Result := '';
    ADefaultFilterExpr := FHostPanel.FilterExpression;
  end
  else
    Result := BuildFilterPanel(AViewAlias, AViewTable, ADefaultFilterExpr, AUrlViewName);
end;

function TKXDataPanelLeafController.RenderHosted: string;
begin
  Result := RenderWithRegions(RenderContent);
end;

function TKXDataPanelLeafController.HostedCssClass: string;
begin
  Result := GetPanelCssClass;
end;

{ TKXDataPanelCompositeController }

function TKXDataPanelCompositeController.GetRegionDefaultControllerClass(
  const ARegionName: string): string;
begin
  Result := '';
end;

function TKXDataPanelCompositeController.ResolveOptionString(const APath,
  ADefault: string): string;
begin
  Result := GetConfigString(APath, ADefault);
end;

function TKXDataPanelCompositeController.ResolveOptionBoolean(const APath: string;
  ADefault: Boolean): Boolean;
begin
  Result := GetConfigBoolean(APath, ADefault);
end;

function TKXDataPanelCompositeController.GetRegionRenderHook: TKXRegionRenderHook;
begin
  Result := HookRegion;
end;

function TKXDataPanelCompositeController.HookRegion(const AController: IKXController;
  const ARegionName: string; out AContent: string): Boolean;
var
  LLeaf: TKXDataPanelLeafController;
begin
  Result := False;
  AContent := '';
  if not (AController.AsObject is TKXDataPanelLeafController) then
    Exit;
  LLeaf := TKXDataPanelLeafController(AController.AsObject);
  if not LLeaf.IsHosted then
    LLeaf.AttachToHost(Self, ARegionName);
  // Display inside the guard: a controller that is not a presenter is left to
  // the region renderer, which displays and renders it itself.
  AController.Display;
  if SameText(ARegionName, 'Center') then
    // The Center presenter's content goes straight into this panel's chrome,
    // which wears the presenter's CSS class (GetPanelCssClass): the very markup
    // the presenter emits on its own.
    AContent := LLeaf.RenderHosted
  else
    // A side presenter renders bare inside its region, wrapped in its own CSS
    // class for layout but with no id: the id belongs to this host.
    AContent := '<div class="' + LLeaf.HostedCssClass + '">' + LLeaf.RenderHosted + '</div>';
  Result := True;
end;

function TKXDataPanelCompositeController.EnsureCenterPresenter: IKXController;
var
  LNode: TEFNode;
  LDefaultType: string;
begin
  if not Assigned(FCenterPresenter) then
  begin
    // Kitto1 semantics, in one place: a CenterController node that is missing
    // is synthesized with the default presenter; one that is present without a
    // value (only options as children, e.g. AllowViewing) is back-filled with
    // it, keeping the children. Changing the value is how a view swaps the
    // presenter. A CenterView takes precedence, as in any border layout.
    if not Assigned(Config.FindNode('CenterView')) then
    begin
      LDefaultType := GetRegionDefaultControllerClass('Center');
      if LDefaultType <> '' then
      begin
        LNode := Config.FindNode('CenterController');
        if not Assigned(LNode) then
          LNode := Config.AddChild('CenterController');
        if LNode.AsString = '' then
          LNode.AsString := LDefaultType;
      end;
    end;
    FCenterPresenter := CreateRegionController(Config, View, 'Center');
    if Assigned(FCenterPresenter)
      and (FCenterPresenter.AsObject is TKXDataPanelLeafController) then
    begin
      FCenterLeaf := TKXDataPanelLeafController(FCenterPresenter.AsObject);
      FCenterLeaf.AttachToHost(Self, 'Center');
    end;
  end;
  Result := FCenterPresenter;
end;

function TKXDataPanelCompositeController.RenderFilterPanel(const AViewAlias,
  AUrlViewName: string): string;
begin
  Result := BuildFilterPanel(AViewAlias, ViewTable, FFilterExpression, AUrlViewName);
end;

function TKXDataPanelCompositeController.RenderContent: string;
var
  LViewAlias, LUrlViewName: string;
  LCenter: IKXController;
  LContent: string;
begin
  Result := '';
  if not Assigned(View) or not Assigned(ViewTable) then
    Exit;

  // Same alias rule as the presenters: a lookup grid works under the lkp_
  // alias and keeps the real view name for its URLs.
  if SameText(TKWebRequest.Current.GetQueryField('mode'), 'lookup') then
  begin
    LViewAlias := 'lkp_' + View.PersistentName;
    LUrlViewName := View.PersistentName;
  end
  else
  begin
    LViewAlias := View.PersistentName;
    LUrlViewName := '';
  end;

  // The filter panel is the host's: it filters the data every presenter shows.
  Result := RenderFilterPanel(LViewAlias, LUrlViewName);

  LCenter := EnsureCenterPresenter;
  if not Assigned(LCenter) then
    Exit;
  if HookRegion(LCenter, 'Center', LContent) then
    Result := Result + LContent
  else
  begin
    // Any other controller in the Center (an HtmlPanel, a view) renders itself.
    LCenter.Display;
    Result := Result + LCenter.Render;
  end;
end;

function TKXDataPanelCompositeController.GetPanelCssClass: string;
begin
  // This panel is the chrome of its Center presenter: it wears the presenter's
  // class so a grid, a chart or a calendar hosted in a List look exactly as
  // they do on their own.
  if Assigned(FCenterLeaf) then
    Result := FCenterLeaf.HostedCssClass
  else
    Result := inherited GetPanelCssClass;
end;

function BuildRequestFilterExpression(const AControllerNode: TEFNode): string;
var
  LItemsNode: TEFNode;
begin
  Result := '';
  if not Assigned(AControllerNode) then
    Exit;
  LItemsNode := AControllerNode.FindNode('Filters/Items');
  if not Assigned(LItemsNode) then
    Exit;
  Result := BuildFilterExpression(LItemsNode,
    AControllerNode.GetString('Filters/Connector', 'and'),
    function(AIndex: Integer): string
    begin
      Result := TKWebRequest.Current.GetField('f_' + IntToStr(AIndex));
    end);
end;

end.
