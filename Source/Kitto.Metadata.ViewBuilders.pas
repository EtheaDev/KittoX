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
///  View builders that auto-generate a data view from a model at runtime,
///  one per presentation: a list view (TKAutoListViewBuilder), a form view
///  (TKAutoFormViewBuilder), a grouped list (TKAutoGroupingListViewBuilder),
///  a template-rendered panel (TKAutoTemplateDataViewBuilder), a chart
///  (TKAutoChartViewBuilder), a calendar (TKAutoCalendarViewBuilder) and a
///  map (TKAutoGoogleMapViewBuilder), registered as 'AutoList', 'AutoForm',
///  'AutoGroupingList', 'AutoTemplateData', 'AutoChart', 'AutoCalendar' and
///  'AutoGoogleMap'. Used when a view is referenced through a 'Build ...'
///  expression instead of a YAML file.
///
///  Where the controller ends up differs on purpose: a presenter that needs
///  the data context and the filter panel of a host (the chart, the calendar)
///  is built as the Center of a List, which is the shape every hand-written
///  view of that kind has; one that makes its own context (the grid, the form,
///  the template panel, the map) sits at the root of the view.
/// </summary>
unit Kitto.Metadata.ViewBuilders;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  Kitto.Metadata.Models,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView;

type
  /// <summary>
  ///  Base class for the auto view builders. Builds a data view for a model,
  ///  adding all fields, detail tables and a free-search filter; descendants
  ///  supply the controller type and any view customization.
  /// </summary>
  TKAutoViewBuilderBase = class(TKViewBuilder)
  strict private
    function BuildSearchString(const AFields: TKViewFields): string;
    /// <summary>
    ///  Gives AViewTable its Fields node. ASourceFields, when passed, is a
    ///  Fields node the caller already has and wins over the list generated
    ///  from AModel; it must be passed per table, never looked up from the
    ///  builder's configuration, or the main table's fields would be applied to
    ///  every nested detail table as well.
    /// </summary>
    procedure AddFields(const AViewTable: TKViewTable; const AModel: TKModel;
      const ASourceFields: TEFNode = nil);
    procedure AddDetailTables(const AViewTable: TKViewTable;
      const AModel: TKModel);
  strict protected
    function GetControllerType: string; virtual; abstract;
    function GetModel: TKModel;
    procedure CustomizeView(const AView: TKView); virtual;
  public
    /// <summary>Builds and returns the data view for the configured model.</summary>
    function BuildView(const AViews: TKViews;
      const APersistentName: string = '';
      const ANode: TEFNode = nil): TKView; override;
  end;

  /// <summary>Auto view builder that produces a List (grid) view. Registered as 'AutoList'.</summary>
  TKAutoListViewBuilder = class(TKAutoViewBuilderBase)
  strict protected
    function GetControllerType: string; override;
  end;

  /// <summary>Auto view builder that produces a Form view (in Add mode). Registered as 'AutoForm'.</summary>
  TKAutoFormViewBuilder = class(TKAutoViewBuilderBase)
  strict protected
    function GetControllerType: string; override;
    procedure CustomizeView(const AView: TKView); override;
  end;

  /// <summary>
  ///  Auto view builder that produces a GroupingList view: a grid whose rows
  ///  are collected under a header for each distinct value of one field.
  ///  Registered as 'AutoGroupingList'.
  ///  Beside Model, the builder node takes GroupingFieldName (required: the
  ///  field the rows are grouped by) and, optionally, SortFieldNames,
  ///  StartCollapsed, ShowName and ShowCount, which are passed through to the
  ///  controller's Grouping node only when present, so that anything left out
  ///  keeps the controller's own default.
  /// </summary>
  TKAutoGroupingListViewBuilder = class(TKAutoViewBuilderBase)
  strict protected
    function GetControllerType: string; override;
    procedure CustomizeView(const AView: TKView); override;
  end;

  /// <summary>
  ///  Auto view builder that produces a TemplateDataPanel view: the records
  ///  are rendered through an HTML template instead of a grid. Registered as
  ///  'AutoTemplateData'. The builder node needs either TemplateFileName (a
  ///  template file looked up among the application resources) or Template
  ///  (inline markup); without one of the two the controller would render an
  ///  error placeholder instead of the data.
  /// </summary>
  TKAutoTemplateDataViewBuilder = class(TKAutoViewBuilderBase)
  strict protected
    function GetControllerType: string; override;
    procedure CustomizeView(const AView: TKView); override;
  end;

  /// <summary>
  ///  Auto view builder that produces a chart view: a List hosting a
  ///  ChartPanel as its Center presenter. Registered as 'AutoChart'.
  ///  Beside Model, the builder node takes LabelFieldName and ValueFieldName
  ///  (both required: the field whose values label the bars or the slices, and
  ///  the numeric field they are sized by) and, optionally, ChartType
  ///  (Cartesian, the default, or Polar), SeriesType (Bar/Line for Cartesian,
  ///  Pie/Pie3D for Polar), SeriesDisplayName, Title, ValueAxisTitle, Donut,
  ///  LegendPosition, and GridPosition/GridWidth to put a grid beside the
  ///  chart.
  /// </summary>
  TKAutoChartViewBuilder = class(TKAutoViewBuilderBase)
  strict protected
    function GetControllerType: string; override;
    procedure CustomizeView(const AView: TKView); override;
  end;

  /// <summary>
  ///  Auto view builder that produces a calendar view: a List hosting a
  ///  CalendarPanel as its Center presenter. Registered as 'AutoCalendar'.
  ///  Beside Model, the builder node takes StartDateFieldName (required) and,
  ///  optionally, EndDateFieldName (defaulting to the start field, for records
  ///  that are a point in time), IdFieldName, TitleFieldName,
  ///  EventTypeFieldName, EventNotesFieldName - which become the calendar
  ///  mapping under the view table's Model node - plus DefaultView,
  ///  SlotMinTime, SlotMaxTime, DefaultEventMinutes and EventTemplate, which
  ///  are passed through to the panel.
  /// </summary>
  TKAutoCalendarViewBuilder = class(TKAutoViewBuilderBase)
  strict protected
    function GetControllerType: string; override;
    procedure CustomizeView(const AView: TKView); override;
  end;

  /// <summary>
  ///  Auto view builder that produces a map view: Controller GoogleMap, whose
  ///  markers are geocoded from the address fields of each record.
  ///  Registered as 'AutoGoogleMap'. Beside Model, the builder node takes
  ///  AddressFields (required, a comma-separated list) and, optionally,
  ///  TitleField, InfoFields, Zoom, CenterLatitude, CenterLongitude,
  ///  MapTypeId, SidebarPosition and SidebarWidth.
  /// </summary>
  TKAutoGoogleMapViewBuilder = class(TKAutoViewBuilderBase)
  strict protected
    function GetControllerType: string; override;
    procedure CustomizeView(const AView: TKView); override;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  EF.Localization,
  Kitto.Config,
  Kitto.Types;

{ TKAutoViewBuilderBase }

procedure TKAutoViewBuilderBase.AddFields(const AViewTable: TKViewTable;
  const AModel: TKModel; const ASourceFields: TEFNode);
var
  LFields: TKViewFields;
  I: Integer;
begin
  Assert(Assigned(AViewTable), 'Assigned(AViewTable)');
  Assert(Assigned(AModel), 'Assigned(AModel)');

  LFields := AViewTable.AddChild(TKViewFields.Create('Fields')) as TKViewFields;

  // The case that needs this is a detail table declared under
  // DetailTables/Table in a master view with no ViewName of its own: that node
  // is the only place carrying what the master view says about those columns --
  // IsVisible, DisplayLabel, DisplayWidth, the order they appear in -- and
  // rebuilding the list from the model discards all of it.
  //
  // Assign, not TEFNode.Clone: Clone is a (virtual) constructor, so calling it
  // on TEFNode yields plain TEFNodes, while TKViewFields must hold TKViewField
  // children -- BuildView casts this very node to TKViewFields. Assign creates
  // each child through the destination's GetChildClass.
  if Assigned(ASourceFields) and (ASourceFields.ChildCount > 0) then
    LFields.Assign(ASourceFields)
  else
    for I := 0 to AModel.FieldCount - 1 do
      LFields.AddChild(TKViewField.Create(AModel.Fields[I].FieldName));
end;

procedure TKAutoViewBuilderBase.AddDetailTables(const AViewTable: TKViewTable;
  const AModel: TKModel);
var
  I: Integer;
  LDetailTable: TKViewTable;
begin
  Assert(Assigned(AViewTable), 'Assigned(AViewTable)');
  Assert(Assigned(AModel), 'Assigned(AModel)');

  for I := 0 to AModel.DetailReferenceCount - 1 do
  begin
    LDetailTable := TKViewTable.Create;
    try
      LDetailTable.Name := 'Table';
      LDetailTable.SetString('Model', AModel.DetailReferences[I].DetailModel.ModelName);
      AViewTable.AddDetailTable(LDetailTable);
      AddFields(LDetailTable, LDetailTable.Model);
      AddDetailTables(LDetailTable, LDetailTable.Model);
    except
      FreeAndNil(LDetailTable);
    end;
  end;
end;

function TKAutoViewBuilderBase.BuildView(const AViews: TKViews;
  const APersistentName: string; const ANode: TEFNode): TKView;
var
  LMainTable: TKViewTable;
  LModel: TKModel;
  LFilters: TEFNode;
  LFilterItems: TEFNode;
  LSearchItem: TEFNode;
  LSourceControllerNode: TEFNode;
  LSourceMainTableControllerNode: TEFNode;
  LSourceDisplayLabelNode: TEFNode;
  LControllerNode: TEFNode;
  LResourceName: TEFNode;
begin
  inherited;
  LModel := GetModel;
  Result := TKDataView.Create;
  try
    Result.SetString('Type', 'Data');
    if APersistentName <> '' then
    begin
      Result.PersistentName := APersistentName;
      AViews.AddObject(Result);
    end
    else if ANode <> nil then
      AViews.AddNonpersistentObject(Result, ANode);

    LResourceName := FindNode('ResourceName');
    if Assigned(LResourceName) then
      Result.SetString('ResourceName', LResourceName.AsString);

    if TKConfig.Instance.UseAltLanguage then
    begin
      LSourceDisplayLabelNode := FindNode('DisplayLabel2');
      if Assigned(LSourceDisplayLabelNode) then
        Result.SetString('DisplayLabel2', LSourceDisplayLabelNode.AsString);
    end
    else
    begin
      LSourceDisplayLabelNode := FindNode('DisplayLabel');
      if Assigned(LSourceDisplayLabelNode) then
        Result.SetString('DisplayLabel', LSourceDisplayLabelNode.AsString);
    end;

    LSourceControllerNode := FindNode('Controller');
    if Assigned(LSourceControllerNode) then
      Result.AddChild(TEFNode.Clone(LSourceControllerNode));
    LControllerNode := Result.SetString('Controller', GetControllerType);

    LMainTable := Result.AddChild(TKViewTable.Create('MainTable')) as TKViewTable;
    LMainTable.SetString('Model', LModel.ModelName);

    // MainTable/Fields, when declared, wins over the list generated from the
    // model. See AddFields.
    AddFields(LMainTable, LModel, FindNode('MainTable/Fields'));
    AddDetailTables(LMainTable, LModel);

    LFilters := LControllerNode.AddChild('Filters');
    if TKConfig.Instance.UseAltLanguage then
      LFilters.SetString('DisplayLabel2', _(Format(_('Search %s'), [LModel.PluralDisplayLabel])))
    else
      LFilters.SetString('DisplayLabel', _(Format(_('Search %s'), [LModel.PluralDisplayLabel])));
    LFilterItems := LFilters.AddChild('Items');
    LSearchItem := LFilterItems.AddChild('FreeSearch', _('Free Search'));
    LSearchItem.SetString('ExpressionTemplate', BuildSearchString(
      LMainTable.ChildByName('Fields') as TKViewFields));

    LSourceMainTableControllerNode := FindNode('MainTable/Controller');
    if Assigned(LSourceMainTableControllerNode) then
      {LMainTableController := }LMainTable.AddChild(TEFNode.Clone(LSourceMainTableControllerNode))
    else
      {LMainTableController := }LMainTable.AddChild('Controller');
    CustomizeView(Result);
  except
    if APersistentName <> '' then
      AViews.RemoveObject(Result)
    else if ANode <> nil then
      AViews.DeleteNonpersistentObject(ANode);
    FreeAndNil(Result);
    raise;
  end;
end;

procedure TKAutoViewBuilderBase.CustomizeView(const AView: TKView);
begin
end;

function TKAutoViewBuilderBase.BuildSearchString(const AFields: TKViewFields): string;
var
  I: Integer;
begin
  Assert(Assigned(AFields), 'Assigned(AFields)');

  Result := '';
  for I := 0 to AFields.FieldCount - 1 do
  begin
    // A computed field (one with an Expression) has no column of its own:
    // its QualifiedDBName names something the database does not have, and
    // the whole search would fail on it. ACTIVITY_CALENDAR.Title is one.
    if AFields[I].IsVisible and AFields[I].DataType.IsText
      and (not Assigned(AFields[I].ModelField) or (AFields[I].ModelField.Expression = '')) then
    begin
      if Result = '' then
        Result := '(' + AFields[I].QualifiedDBName + ' like ''%{value}%'')'
      else
        Result := Result + ' or (' + AFields[I].QualifiedDBName + ' like ''%{value}%'')';
    end;
  end;
end;

function TKAutoViewBuilderBase.GetModel: TKModel;
begin
  Assert(Assigned(Views), 'Assigned(Views)');
  Assert(Assigned(Views.Models), 'Assigned(Views.Models)');

  Result := Views.Models.ModelByName(GetString('Model'));
end;

{ TKAutoListViewBuilder }

function TKAutoListViewBuilder.GetControllerType: string;
begin
  Result := 'List';
end;

{ TKAutoFormViewBuilder }

procedure TKAutoFormViewBuilder.CustomizeView(const AView: TKView);
begin
  inherited;
  AView.SetString('Controller/Operation', 'Add');
end;

function TKAutoFormViewBuilder.GetControllerType: string;
begin
  Result := 'Form';
end;

{ TKAutoGroupingListViewBuilder }

function TKAutoGroupingListViewBuilder.GetControllerType: string;
begin
  Result := 'GroupingList';
end;

procedure TKAutoGroupingListViewBuilder.CustomizeView(const AView: TKView);
var
  LModel: TKModel;
  LFieldName: string;
  LGrouping: TEFNode;

  // Copies ANodeName from the builder's own configuration to the Grouping
  // node, and only if it is there: an absent node must leave the controller's
  // default alone, which writing a value unconditionally would not do.
  procedure PassThrough(const ANodeName: string);
  var
    LNode: TEFNode;
  begin
    LNode := FindNode(ANodeName);
    if Assigned(LNode) then
      LGrouping.AddChild(TEFNode.Clone(LNode));
  end;

begin
  inherited;
  LModel := GetModel;

  LFieldName := GetString('GroupingFieldName');
  if LFieldName = '' then
    raise EKError.Create(_('AutoGroupingList: GroupingFieldName is required - ' +
      'it names the field whose value collects the rows into groups.'));
  if not Assigned(LModel.FindField(LFieldName)) then
    raise EKError.CreateFmt(_('AutoGroupingList: field %s not found in model %s.'),
      [LFieldName, LModel.ModelName]);

  // The Grouping node hangs off the VIEW TABLE's controller, not the view's:
  // TKXGroupingListController reads it as 'Controller/Grouping/...' through
  // ViewTable. Written one level up it would be silently ignored and the
  // controller would refuse to render for want of a grouping field.
  LGrouping := AView.GetNode('MainTable/Controller/Grouping', True);
  LGrouping.SetString('FieldName', LFieldName);

  PassThrough('SortFieldNames');
  PassThrough('StartCollapsed');
  PassThrough('ShowName');
  PassThrough('ShowCount');
end;

{ TKAutoTemplateDataViewBuilder }

function TKAutoTemplateDataViewBuilder.GetControllerType: string;
begin
  Result := 'TemplateDataPanel';
end;

procedure TKAutoTemplateDataViewBuilder.CustomizeView(const AView: TKView);
var
  LTemplateFileName: string;
  LTemplate: string;
begin
  inherited;
  LTemplateFileName := GetString('TemplateFileName');
  LTemplate := GetString('Template');
  if (LTemplateFileName = '') and (LTemplate = '') then
    raise EKError.Create(_('AutoTemplateData: either TemplateFileName or ' +
      'Template is required - the panel renders the records through a ' +
      'template and has nothing to draw without one.'));

  // TemplateFileName wins, as it does in the controller (see LoadTemplate in
  // Kitto.Html.TemplateDataPanel): the inline Template is its fallback.
  if LTemplateFileName <> '' then
    AView.SetString('Controller/TemplateFileName', LTemplateFileName)
  else
    AView.SetString('Controller/Template', LTemplate);

  // The panel is display-only - IsActionSupported refuses every CRUD action -
  // so the view table says so rather than offering buttons that do nothing.
  AView.SetBoolean('MainTable/IsReadOnly', True);

  // ...and the free-search filter the base builder adds for a grid is dropped:
  // this panel is normally a card or a KPI tile over a handful of records, and
  // a search box above it would be furniture nobody asked for. Add a Filters
  // node by hand when the template does render a searchable list.
  AView.DeleteNode('Controller/Filters');
end;

{ TKAutoChartViewBuilder }

function TKAutoChartViewBuilder.GetControllerType: string;
begin
  // Not 'ChartPanel': the chart is a presenter, and every hand-written chart
  // view hosts it in the Center of a List (TasKitto's ActivityBarChart and
  // ActivityPieChart, SportClubManager's dashboards). The List owns the data
  // context and renders the filter panel the base builder adds, and it is what
  // lets a grid sit beside the chart in a side region showing the same rows.
  Result := 'List';
end;

procedure TKAutoChartViewBuilder.CustomizeView(const AView: TKView);
var
  LModel: TKModel;
  LChartType: string;
  LSeriesType: string;
  LLabelFieldName: string;
  LValueFieldName: string;
  LGridPosition: string;
  LIsPolar: Boolean;
  LValue: string;
  LInteger: Integer;
  LChart: TEFNode;
  LSeries: TEFNode;
  LAxes: TEFNode;
  LAxis: TEFNode;

  procedure CheckField(const AFieldName, ARole: string);
  begin
    if not Assigned(LModel.FindField(AFieldName)) then
      raise EKError.CreateFmt(_('AutoChart: %s field %s not found in model %s.'),
        [ARole, AFieldName, LModel.ModelName]);
  end;

begin
  inherited;
  LModel := GetModel;

  LLabelFieldName := GetString('LabelFieldName');
  LValueFieldName := GetString('ValueFieldName');
  if LLabelFieldName = '' then
    raise EKError.Create(_('AutoChart: LabelFieldName is required - it names ' +
      'the field whose values label the bars or the slices.'));
  if LValueFieldName = '' then
    raise EKError.Create(_('AutoChart: ValueFieldName is required - it names ' +
      'the numeric field the bars or the slices are sized by.'));
  CheckField(LLabelFieldName, _('label'));
  CheckField(LValueFieldName, _('value'));

  LChartType := GetString('ChartType', 'Cartesian');
  if not MatchText(LChartType, ['Cartesian', 'Polar']) then
    raise EKError.CreateFmt(_('AutoChart: unknown ChartType %s. It is either ' +
      'Cartesian (bars and lines, with axes) or Polar (pies).'), [LChartType]);
  LIsPolar := SameText(LChartType, 'Polar');

  LSeriesType := GetString('SeriesType');
  if LSeriesType = '' then
    if LIsPolar then
      LSeriesType := 'Pie'
    else
      LSeriesType := 'Bar';
  // The renderer maps the pair (chart type, series type) to a Chart.js type and
  // falls back to a bar chart for anything it does not recognize: a mismatch
  // would silently draw something nobody asked for instead of being reported.
  if LIsPolar then
  begin
    if not MatchText(LSeriesType, ['Pie', 'Pie3D']) then
      raise EKError.CreateFmt(_('AutoChart: series type %s does not belong to ' +
        'a Polar chart; use Pie or Pie3D.'), [LSeriesType]);
  end
  else if not MatchText(LSeriesType, ['Bar', 'Line']) then
    raise EKError.CreateFmt(_('AutoChart: series type %s does not belong to a ' +
      'Cartesian chart; use Bar or Line.'), [LSeriesType]);

  AView.SetString('Controller/CenterController', 'ChartPanel');
  LChart := AView.GetNode('Controller/CenterController/Chart', True);
  LChart.SetString('Type', LChartType);

  // One series, at the fixed path the renderer reads: Chart/Series/Series, a
  // Series container holding a Series item. A second item would be ignored.
  LSeries := LChart.GetNode('Series/Series', True);
  LSeries.SetString('Type', LSeriesType);
  if LIsPolar then
  begin
    // A pie sizes its slices by AngleField and labels them by Label/Field;
    // a cartesian series takes the same two fields as Y and X.
    LSeries.SetString('AngleField', LValueFieldName);
    LSeries.SetString('Label/Field', LLabelFieldName);
    LInteger := GetInteger('Donut', 0);
    if LInteger > 0 then
      LSeries.SetInteger('Donut', LInteger);
  end
  else
  begin
    LSeries.SetString('XField', LLabelFieldName);
    LSeries.SetString('YField', LValueFieldName);
    // The Left axis is the one the renderer reads the value-axis title from;
    // Bottom is the category axis. Both are written so that the pair is there
    // for whoever edits the view afterwards.
    LAxes := LChart.GetNode('Axes', True);
    LAxis := LAxes.AddChild('Axis');
    LAxis.SetString('Position', 'Left');
    LValue := GetString('ValueAxisTitle');
    if LValue <> '' then
      LAxis.SetString('Title', LValue);
    LAxes.AddChild('Axis').SetString('Position', 'Bottom');
  end;

  // The series name goes in Title: it is what TKXChartPanelController reads
  // for the legend and the tooltips, what ChartPanel.md documents, and what
  // the hand-written chart views use. The config class declares DisplayName
  // too, but the runtime does not read it, and a legend showed "undefined".
  LValue := GetString('SeriesDisplayName');
  if LValue <> '' then
    LSeries.SetString('Title', LValue);

  // The first sprite's text is the chart title.
  LValue := GetString('Title');
  if LValue <> '' then
    LChart.GetNode('Sprites', True).AddChild('Sprite').SetString('Text', LValue);

  LValue := GetString('LegendPosition');
  if LValue <> '' then
  begin
    if not MatchText(LValue, ['top', 'bottom', 'left', 'right']) then
      raise EKError.CreateFmt(_('AutoChart: unknown LegendPosition %s; it is ' +
        'top, bottom, left or right.'), [LValue]);
    LChart.SetString('Legend/Docked', LowerCase(LValue));
  end;

  // A grid beside the chart is a real GridPanel in a side region of the List,
  // not a sidebar of the chart: both presenters then show the same filtered
  // rows, because the List is the one holding the data context.
  LValue := GetString('GridPosition');
  if LValue <> '' then
  begin
    if SameText(LValue, 'West') then
      LGridPosition := 'West'
    else if SameText(LValue, 'East') then
      LGridPosition := 'East'
    else
      raise EKError.CreateFmt(_('AutoChart: unknown GridPosition %s; the grid ' +
        'goes West or East of the chart.'), [LValue]);
    AView.SetString('Controller/' + LGridPosition + 'Controller', 'GridPanel');
    AView.SetInteger('Controller/' + LGridPosition + 'Controller/Width',
      GetInteger('GridWidth', 400));
    AView.SetBoolean('Controller/' + LGridPosition + 'Controller/Split', True);
  end;

  // A chart is a reading of the data, not a way into it - IsActionSupported
  // refuses every CRUD action - and every hand-written chart view says so on
  // its view table.
  AView.SetBoolean('MainTable/IsReadOnly', True);

  // ...and no free-search filter above it: it would filter the chart (and the
  // grid beside it, when there is one), but no hand-written chart view has
  // one, and a search box over a chart is not what anyone asked for. Add a
  // Filters node by hand when it is wanted.
  AView.DeleteNode('Controller/Filters');
end;

{ TKAutoCalendarViewBuilder }

function TKAutoCalendarViewBuilder.GetControllerType: string;
begin
  // As for the chart: the calendar is a presenter, hosted in the Center of a
  // List, which is the shape of both hand-written calendar views. Unlike the
  // chart it is not read-only: its toolbar adds, edits and deletes events.
  Result := 'List';
end;

procedure TKAutoCalendarViewBuilder.CustomizeView(const AView: TKView);
var
  LModel: TKModel;
  LModelNode: TEFNode;
  LStartFieldName: string;
  LEndFieldName: string;
  LValue: string;

  // The named node of the builder's configuration, checked against the model.
  // An empty node means "not given" and is not an error here: only the start
  // date is required, the rest of the mapping has its own defaults downstream.
  function ResolveField(const ANodeName, ARole: string): string;
  begin
    Result := GetString(ANodeName);
    if (Result <> '') and not Assigned(LModel.FindField(Result)) then
      raise EKError.CreateFmt(_('AutoCalendar: %s field %s not found in model %s.'),
        [ARole, Result, LModel.ModelName]);
  end;

  procedure MapField(const AMappingName, AFieldName: string);
  begin
    if AFieldName <> '' then
      LModelNode.SetString(AMappingName, AFieldName);
  end;

  procedure PassThrough(const ANodeName: string);
  var
    LNode: TEFNode;
  begin
    LNode := FindNode(ANodeName);
    if Assigned(LNode) then
      AView.GetNode('Controller/CenterController', True).AddChild(TEFNode.Clone(LNode));
  end;

begin
  inherited;
  LModel := GetModel;

  LStartFieldName := ResolveField('StartDateFieldName', _('start date'));
  if LStartFieldName = '' then
    raise EKError.Create(_('AutoCalendar: StartDateFieldName is required - it ' +
      'names the date/time field each event starts at.'));
  LEndFieldName := ResolveField('EndDateFieldName', _('end date'));
  // A record that is a point in time (a party with one date and no end) maps
  // both ends to the same field; the calendar endpoint then gives the event
  // DefaultEventMinutes of duration instead of a zero-height strip. Written
  // out rather than left to the default, which is the literal field name
  // 'EndDate' and would be a silent miss on a model that has no such field.
  if LEndFieldName = '' then
    LEndFieldName := LStartFieldName;

  AView.SetString('Controller/CenterController', 'CalendarPanel');

  // The field mapping hangs off the view table's MODEL node, not off the
  // controller: TKXCalendarPanelController.GetCalendarFieldName and
  // TKXCalendarHandler.HandleCalendarData both read 'MainTable/Model/...'.
  LModelNode := AView.GetNode('MainTable/Model', True);
  LModelNode.SetString('CalendarStartDate', LStartFieldName);
  LModelNode.SetString('CalendarEndDate', LEndFieldName);
  MapField('CalendarId', ResolveField('IdFieldName', _('id')));
  MapField('CalendarTitle', ResolveField('TitleFieldName', _('title')));
  MapField('CalendarEventType', ResolveField('EventTypeFieldName', _('event type')));
  MapField('CalendarEventNotes', ResolveField('EventNotesFieldName', _('event notes')));

  LValue := GetString('DefaultView');
  if LValue <> '' then
  begin
    if not MatchText(LValue, ['dayGridMonth', 'timeGridWeek', 'timeGridDay']) then
      raise EKError.CreateFmt(_('AutoCalendar: unknown DefaultView %s; it is ' +
        'dayGridMonth, timeGridWeek or timeGridDay.'), [LValue]);
    AView.SetString('Controller/CenterController/DefaultView', LValue);
  end;
  PassThrough('SlotMinTime');
  PassThrough('SlotMaxTime');
  PassThrough('DefaultEventMinutes');
  PassThrough('EventTemplate');

  // No free-search filter above a calendar: the hand-written calendar views
  // have none, and the one the base builder adds is not wanted here. Add a
  // Filters node by hand when it is.
  AView.DeleteNode('Controller/Filters');
end;

{ TKAutoGoogleMapViewBuilder }

function TKAutoGoogleMapViewBuilder.GetControllerType: string;
begin
  // Unlike the chart and the calendar, the map is the view's own controller:
  // it renders its own sidebar grid beside the map, so a List around it would
  // only add a second grid. Both hand-written map views have it at the root.
  Result := 'GoogleMap';
end;

procedure TKAutoGoogleMapViewBuilder.CustomizeView(const AView: TKView);
var
  LModel: TKModel;
  LMap: TEFNode;
  LValue: string;
  LInteger: Integer;

  // A comma-separated list of field names, given back with the model's own
  // spelling and one separator. Also used for the single-field TitleField:
  // one name is a list of one, and it gets the same check.
  function ResolveFieldList(const ANodeName, ARole: string): string;
  var
    LName: string;
    LField: TKModelField;
  begin
    Result := '';
    for LName in GetString(ANodeName).Split([',']) do
    begin
      if LName.Trim = '' then
        Continue;
      LField := LModel.FindField(LName.Trim);
      if not Assigned(LField) then
        raise EKError.CreateFmt(_('AutoGoogleMap: %s field %s not found in model %s.'),
          [ARole, LName.Trim, LModel.ModelName]);
      if Result = '' then
        Result := LField.FieldName
      else
        Result := Result + ', ' + LField.FieldName;
    end;
  end;

  // Latitude and longitude go in as the text that was given, which is what the
  // hand-written map views hold: a float node would be written through the
  // YAML writer's format settings, and the decimal separator of whoever
  // happened to run the generator is not a property of the view.
  function ResolveCoordinate(const ANodeName: string): string;
  var
    LDouble: Double;
  begin
    Result := GetString(ANodeName).Trim;
    if (Result <> '') and
      not TryStrToFloat(Result, LDouble, TFormatSettings.Invariant) then
      raise EKError.CreateFmt(_('AutoGoogleMap: %s is not a number: %s. ' +
        'Coordinates are decimal degrees with a dot, e.g. 41.9028.'),
        [ANodeName, Result]);
  end;

begin
  inherited;
  LModel := GetModel;

  LValue := ResolveFieldList('AddressFields', _('address'));
  if LValue = '' then
    raise EKError.Create(_('AutoGoogleMap: AddressFields is required - the map ' +
      'geocodes each record from the fields it names, and has nothing to place ' +
      'on the map without them.'));

  LMap := AView.GetNode('Controller/GoogleMap', True);
  LMap.SetString('AddressFields', LValue);

  LValue := ResolveFieldList('TitleField', _('title'));
  if LValue <> '' then
    LMap.SetString('TitleField', LValue);
  LValue := ResolveFieldList('InfoFields', _('info'));
  if LValue <> '' then
    LMap.SetString('InfoFields', LValue);

  LInteger := GetInteger('Zoom', 0);
  if LInteger > 0 then
    LMap.SetInteger('Zoom', LInteger);

  LValue := ResolveCoordinate('CenterLatitude');
  if LValue <> '' then
    LMap.SetString('Center/Latitude', LValue);
  LValue := ResolveCoordinate('CenterLongitude');
  if LValue <> '' then
    LMap.SetString('Center/Longitude', LValue);

  LValue := GetString('MapTypeId');
  if LValue <> '' then
  begin
    if not MatchText(LValue, ['ROADMAP', 'SATELLITE', 'HYBRID', 'TERRAIN']) then
      raise EKError.CreateFmt(_('AutoGoogleMap: unknown MapTypeId %s; it is ' +
        'ROADMAP, SATELLITE, HYBRID or TERRAIN.'), [LValue]);
    LMap.SetString('MapTypeId', UpperCase(LValue));
  end;

  LValue := GetString('SidebarPosition');
  if LValue <> '' then
  begin
    if SameText(LValue, 'West') then
      LMap.SetString('SidebarPosition', 'West')
    else if SameText(LValue, 'East') then
      LMap.SetString('SidebarPosition', 'East')
    else
      raise EKError.CreateFmt(_('AutoGoogleMap: unknown SidebarPosition %s; ' +
        'the grid beside the map goes West or East.'), [LValue]);
  end;

  LInteger := GetInteger('SidebarWidth', 0);
  if LInteger > 0 then
    LMap.SetInteger('SidebarWidth', LInteger);

  // The map controller never builds a filter panel - it has no leaf's
  // ResolveFilterPanel and no composite's host - so the FreeSearch filter the
  // base builder adds for a grid would sit in the YAML doing nothing.
  AView.DeleteNode('Controller/Filters');
end;

initialization
  TKViewBuilderRegistry.Instance.RegisterClass('AutoList', TKAutoListViewBuilder);
  TKViewBuilderRegistry.Instance.RegisterClass('AutoForm', TKAutoFormViewBuilder);
  TKViewBuilderRegistry.Instance.RegisterClass('AutoGroupingList', TKAutoGroupingListViewBuilder);
  TKViewBuilderRegistry.Instance.RegisterClass('AutoTemplateData', TKAutoTemplateDataViewBuilder);
  TKViewBuilderRegistry.Instance.RegisterClass('AutoChart', TKAutoChartViewBuilder);
  TKViewBuilderRegistry.Instance.RegisterClass('AutoCalendar', TKAutoCalendarViewBuilder);
  TKViewBuilderRegistry.Instance.RegisterClass('AutoGoogleMap', TKAutoGoogleMapViewBuilder);

finalization
  TKViewBuilderRegistry.Instance.UnregisterClass('AutoList');
  TKViewBuilderRegistry.Instance.UnregisterClass('AutoForm');
  TKViewBuilderRegistry.Instance.UnregisterClass('AutoGroupingList');
  TKViewBuilderRegistry.Instance.UnregisterClass('AutoTemplateData');
  TKViewBuilderRegistry.Instance.UnregisterClass('AutoChart');
  TKViewBuilderRegistry.Instance.UnregisterClass('AutoCalendar');
  TKViewBuilderRegistry.Instance.UnregisterClass('AutoGoogleMap');

end.
