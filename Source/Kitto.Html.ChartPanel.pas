{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   This file is part of KittoX Enterprise Edition.
   Licensed under the AGPL-3.0 or Ethea Commercial License.
   See LICENSE-ENTERPRISE for details.
-------------------------------------------------------------------------------}

/// <summary>
///  KittoX ChartPanel controller renders a Chart.js chart with optional
///  grid sidebar for data display. Replaces TKExtChartPanel from Kitto.Ext.ChartPanel.
///  Supports bar, line, pie, and doughnut chart types mapped from ExtJS YAML config.
/// </summary>
unit Kitto.Html.ChartPanel;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.DataPanel,
  Kitto.Html.Controller,
  Kitto.Metadata.DataView,
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Metadata.Types;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
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
  ///  Label shown on each point/slice of a series. Only Field is honoured by
  ///  the Chart.js renderer (read as Series/Label/Field).
  ///  YAML path: Chart/Series/SeriesItem/Label
  /// </summary>
  TKChartSeriesLabelConfig = class(TEFNode)
  private
    function GetField: string;
  public
    [YamlNode('Field', 'Data field shown as the point/slice label')]
    property Field: string read GetField;
  end;

  /// <summary>
  ///  A text sprite. The renderer uses the first sprite's Text as chart title.
  ///  YAML path: Chart/Sprites/Sprite
  /// </summary>
  TKChartSpriteConfig = class(TEFNode)
  private
    function GetText: string;
  public
    [YamlNode('Text', 'Sprite text; the first Text sprite becomes the chart title')]
    property Text: string read GetText;
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
    function GetAngleField: string;
    function GetTitle: string;
    function GetDonut: Integer;
    function GetLabel: TKChartSeriesLabelConfig;
  public
    [YamlNode('Type', 'Series type: Bar, Line, Pie, Pie3D')]
    [YamlEnumType(TypeInfo(TKSeriesType))]
    property &Type: string read GetType;

    [YamlNode('XField', 'X axis data field')]
    property XField: string read GetXField;

    [YamlNode('YField', 'Y axis data field')]
    property YField: string read GetYField;

    [YamlNode('DisplayName', 'Legend label for this series (older name; Title is used when both are given)')]
    property DisplayName: string read GetDisplayName;

    [YamlSubNode('Style', TKChartSeriesStyleConfig, 'Series visual style')]
    property Style: TKChartSeriesStyleConfig read GetStyle;

    [YamlNode('AngleField', 'Value field of a Pie/Pie3D series (slice size)')]
    property AngleField: string read GetAngleField;

    [YamlNode('Title', 'Series title, shown in the legend/tooltip')]
    property Title: string read GetTitle;

    [YamlNode('Donut', '0', 'Donut hole percentage for Pie/Pie3D (0 = full pie)')]
    property Donut: Integer read GetDonut;

    [YamlSubNode('Label', TKChartSeriesLabelConfig, 'Per-point/slice label')]
    property &Label: TKChartSeriesLabelConfig read GetLabel;
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
    function GetPosition: string;
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

    [YamlNode('Position', 'Axis position: Left, Right, Top, Bottom (Left = Y axis title)')]
    [YamlEnumValue('Left', 'Left (Y axis)')]
    [YamlEnumValue('Right', 'Right')]
    [YamlEnumValue('Top', 'Top')]
    [YamlEnumValue('Bottom', 'Bottom (X axis)')]
    property Position: string read GetPosition;
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
    [YamlEnumValue('top', 'Legend at the top')]
    [YamlEnumValue('bottom', 'Legend at the bottom')]
    [YamlEnumValue('left', 'Legend on the left')]
    [YamlEnumValue('right', 'Legend on the right')]
    property Docked: string read GetDocked;
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
    function GetSprites: TEFNode;
  public
    [YamlNode('Type', 'Chart type: cartesian, polar')]
    [YamlEnumType(TypeInfo(TKChartType))]
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

    [YamlContainer('Sprites', TKChartSpriteConfig, 'Text sprites (the first one is the chart title)')]
    property Sprites: TEFNode read GetSprites;
  end;

  /// <summary>
  ///  Chart presenter (Chart.js): renders the canvas and the chart configuration
  ///  built from all the records of its ViewTable. Hosted in a List it shows the
  ///  same filtered data as the other presenters; a grid beside it is a real
  ///  GridPanel in a West/East region of the List, not a sidebar of its own.
  /// </summary>
  TKXChartPanelController = class(TKXDataPanelLeafController)
  strict private
    FViewName: string;
    function BuildChartConfig(AStore: TKViewTableStore): string;
    function GetChartJsType: string;
    function GetLabelFieldName: string;
    function GetDataFieldName: string;
    function GetChart: TKChartConfig;
  strict protected
    function GetDefaultIsModal: Boolean; override;
    function GetPanelCssClass: string; override;
    function IsActionSupported(const AActionName: string): Boolean; override;
    procedure DoDisplay; override;
    function RenderContent: string; override;
  public
    [YamlSubNode('Chart', TKChartConfig, 'Chart configuration')]
    property Chart: TKChartConfig read GetChart;

    /// <summary>
    ///  Escapes a string value for JSON output (adds surrounding double quotes).
    /// </summary>
    class function JSONStr(const AValue: string): string;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  EF.Localization,
  Kitto.Config,
  Kitto.Html.Base,
  Kitto.Web.Routing.Scripts;

const
  CHART_COLORS: array[0..11] of string = (
    'rgba(54, 162, 235, 0.7)',
    'rgba(255, 99, 132, 0.7)',
    'rgba(255, 206, 86, 0.7)',
    'rgba(75, 192, 192, 0.7)',
    'rgba(153, 102, 255, 0.7)',
    'rgba(255, 159, 64, 0.7)',
    'rgba(199, 199, 199, 0.7)',
    'rgba(83, 102, 255, 0.7)',
    'rgba(255, 99, 255, 0.7)',
    'rgba(99, 255, 132, 0.7)',
    'rgba(255, 180, 99, 0.7)',
    'rgba(132, 99, 255, 0.7)'
  );

  CHART_BORDER_COLORS: array[0..11] of string = (
    'rgba(54, 162, 235, 1)',
    'rgba(255, 99, 132, 1)',
    'rgba(255, 206, 86, 1)',
    'rgba(75, 192, 192, 1)',
    'rgba(153, 102, 255, 1)',
    'rgba(255, 159, 64, 1)',
    'rgba(199, 199, 199, 1)',
    'rgba(83, 102, 255, 1)',
    'rgba(255, 99, 255, 1)',
    'rgba(99, 255, 132, 1)',
    'rgba(255, 180, 99, 1)',
    'rgba(132, 99, 255, 1)'
  );

{ TKXChartPanelController }

function TKXChartPanelController.GetDefaultIsModal: Boolean;
begin
  Result := False;
end;

function TKXChartPanelController.GetPanelCssClass: string;
begin
  Result := 'kx-chart-panel';
end;

function TKXChartPanelController.IsActionSupported(const AActionName: string): Boolean;
begin
  // Chart is read-only display — no CRUD actions
  Result := False;
end;

procedure TKXChartPanelController.DoDisplay;
begin
  inherited;
  if Assigned(View) then
    FViewName := View.PersistentName
  else
    FViewName := '';
end;

class function TKXChartPanelController.JSONStr(const AValue: string): string;
begin
  Result := StringReplace(AValue, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13#10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\n', [rfReplaceAll]);
  Result := '"' + Result + '"';
end;

function TKXChartPanelController.GetChartJsType: string;
var
  LChartType, LSeriesType: string;
  LDonut: Integer;
  LSeriesNode: TEFNode;
begin
  LChartType := Config.GetString('Chart/Type', 'Cartesian');
  LSeriesNode := Config.FindNode('Chart/Series/Series');
  if Assigned(LSeriesNode) then
    LSeriesType := LSeriesNode.GetString('Type', '')
  else
    LSeriesType := '';

  if SameText(LChartType, 'Polar') then
  begin
    if SameText(LSeriesType, 'Pie3D') or SameText(LSeriesType, 'Pie') then
    begin
      LDonut := 0;
      if Assigned(LSeriesNode) then
        LDonut := LSeriesNode.GetInteger('Donut', 0);
      if LDonut > 0 then
        Result := 'doughnut'
      else
        Result := 'pie';
    end
    else
      Result := 'pie';
  end
  else if SameText(LChartType, 'Cartesian') then
  begin
    if SameText(LSeriesType, 'Bar') then
      Result := 'bar'
    else if SameText(LSeriesType, 'Line') then
      Result := 'line'
    else
      Result := 'bar';
  end
  else
    Result := 'bar';
end;

function TKXChartPanelController.GetLabelFieldName: string;
var
  LSeriesNode: TEFNode;
begin
  LSeriesNode := Config.FindNode('Chart/Series/Series');
  if not Assigned(LSeriesNode) then
    Exit('');
  // Cartesian: XField; Polar: Label/Field
  Result := LSeriesNode.GetString('XField', '');
  if Result = '' then
    Result := LSeriesNode.GetString('Label/Field', '');
end;

function TKXChartPanelController.GetDataFieldName: string;
var
  LSeriesNode: TEFNode;
begin
  LSeriesNode := Config.FindNode('Chart/Series/Series');
  if not Assigned(LSeriesNode) then
    Exit('');
  // Cartesian: YField; Polar: AngleField
  Result := LSeriesNode.GetString('YField', '');
  if Result = '' then
    Result := LSeriesNode.GetString('AngleField', '');
end;

function TKXChartPanelController.BuildChartConfig(AStore: TKViewTableStore): string;
var
  I: Integer;
  LRecord: TKViewTableRecord;
  LRecordField: TKViewTableField;
  LLabelField, LDataField: string;
  LChartJsType: string;
  LFmt: TFormatSettings;
  LLegendNode, LSpritesNode, LAxesNode, LAxisNode, LSeriesNode: TEFNode;
  LLegendPos, LTitleText, LSeriesTitle, LYAxisTitle: string;
  LIsPolar: Boolean;
  SB, SBLabels, SBData, SBColors, SBBorders: TStringBuilder;
begin
  LLabelField := GetLabelFieldName;
  LDataField := GetDataFieldName;
  LChartJsType := GetChartJsType;
  LIsPolar := (LChartJsType = 'pie') or (LChartJsType = 'doughnut');

  LFmt := TFormatSettings.Create;
  LFmt.DecimalSeparator := '.';
  LFmt.ThousandSeparator := #0;

  // Build data arrays from store records
  SBLabels := TStringBuilder.Create;
  SBData := TStringBuilder.Create;
  SBColors := TStringBuilder.Create;
  SBBorders := TStringBuilder.Create;
  SB := TStringBuilder.Create;
  try
    for I := 0 to AStore.RecordCount - 1 do
    begin
      LRecord := AStore.Records[I];
      if I > 0 then
      begin
        SBLabels.Append(', ');
        SBData.Append(', ');
        SBColors.Append(', ');
        SBBorders.Append(', ');
      end;

      LRecordField := LRecord.FindField(LLabelField);
      if Assigned(LRecordField) and not LRecordField.IsNull then
        SBLabels.Append(JSONStr(LRecordField.AsString))
      else
        SBLabels.Append('""');

      LRecordField := LRecord.FindField(LDataField);
      if Assigned(LRecordField) and not LRecordField.IsNull then
        SBData.Append(FormatFloat('0.####', LRecordField.AsFloat, LFmt))
      else
        SBData.Append('0');

      SBColors.Append('"').Append(CHART_COLORS[I mod Length(CHART_COLORS)]).Append('"');
      SBBorders.Append('"').Append(CHART_BORDER_COLORS[I mod Length(CHART_BORDER_COLORS)]).Append('"');
    end;

    // Series title: Title, or DisplayName when Title is missing. DisplayName
    // is the older node (declared since r383 and used by hand-written views)
    // that this code never read, so those views showed "undefined" in the
    // legend as soon as one was docked.
    LSeriesNode := Config.FindNode('Chart/Series/Series');
    LSeriesTitle := '';
    if Assigned(LSeriesNode) then
    begin
      LSeriesTitle := _(LSeriesNode.GetString('Title', ''));
      if LSeriesTitle = '' then
        LSeriesTitle := _(LSeriesNode.GetString('DisplayName', ''));
    end;

    // Build Chart.js config JSON
    SB.Append('{"type": ').Append(JSONStr(LChartJsType));
    SB.Append(', "data": {"labels": [').Append(SBLabels.ToString).Append('], ');
    SB.Append('"datasets": [{"data": [').Append(SBData.ToString).Append(']');

    if LSeriesTitle <> '' then
      SB.Append(', "label": ').Append(JSONStr(LSeriesTitle));

    SB.Append(', "backgroundColor": [').Append(SBColors.ToString).Append(']');
    SB.Append(', "borderColor": [').Append(SBBorders.ToString).Append(']');
    SB.Append(', "borderWidth": 1');
    // Allinea l'area di hit dei punti del line chart al loro raggio visibile (default Chart.js e' 1px)
    if LChartJsType = 'line' then
      SB.Append(', "pointRadius": 4, "pointHoverRadius": 6, "pointHitRadius": 4');
    SB.Append('}]}, ');

    // Options
    SB.Append('"options": {"responsive": true, "maintainAspectRatio": false, ');

    // Plugins
    SB.Append('"plugins": {');

    // Legend
    LLegendNode := Config.FindNode('Chart/Legend');
    if Assigned(LLegendNode) then
    begin
      LLegendPos := LLegendNode.GetString('Docked', 'top');
      SB.Append('"legend": {"position": ').Append(JSONStr(LowerCase(LLegendPos)));
      SB.Append(', "labels": {"font": {"size": 14}}}');
    end
    else if LIsPolar then
      SB.Append('"legend": {"position": "top", "labels": {"font": {"size": 14}}}')
    else
      SB.Append('"legend": {"display": false}');

    // Title
    LTitleText := '';
    LSpritesNode := Config.FindNode('Chart/Sprites');
    if Assigned(LSpritesNode) then
      for I := 0 to LSpritesNode.ChildCount - 1 do
      begin
        LTitleText := _(LSpritesNode.Children[I].GetString('Text', ''));
        if LTitleText <> '' then
          Break;
      end;
    if LTitleText <> '' then
    begin
      SB.Append(', "title": {"display": true, "text": ').Append(JSONStr(LTitleText));
      SB.Append(', "font": {"size": 20, "weight": "bold"}}');
    end
    else
      SB.Append(', "title": {"display": false}');

    SB.Append('}'); // close plugins

    // Scales (cartesian only)
    if not LIsPolar then
    begin
      LAxesNode := Config.FindNode('Chart/Axes');
      if Assigned(LAxesNode) then
      begin
        LYAxisTitle := '';
        for I := 0 to LAxesNode.ChildCount - 1 do
        begin
          LAxisNode := LAxesNode.Children[I];
          if SameText(LAxisNode.GetString('Position', ''), 'Left') then
            LYAxisTitle := _(LAxisNode.GetString('Title', ''));
        end;
        SB.Append(', "scales": {');
        if LYAxisTitle <> '' then
        begin
          SB.Append('"y": {"beginAtZero": true, "title": {"display": true, "text": ');
          SB.Append(JSONStr(LYAxisTitle)).Append(', "font": {"size": 14}}}');
        end
        else
          SB.Append('"y": {"beginAtZero": true}');
        SB.Append('}');
      end
      else
        SB.Append(', "scales": {"y": {"beginAtZero": true}}');
    end;

    SB.Append('}}');
    Result := SB.ToString;
  finally
    SBBorders.Free;
    SBColors.Free;
    SBData.Free;
    SBLabels.Free;
    SB.Free;
  end;
end;

function TKXChartPanelController.RenderContent: string;
var
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LFilterExpr: string;
  LChartConfig: string;
  SB: TStringBuilder;
begin
  Result := '';
  if not Assigned(View) or not (View is TKDataView) then
    Exit;

  LDataView := TKDataView(View);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // Hosted in a List, the chart shows the same data as the other presenters:
  // the host's filter panel selects its initial rows too. All records, no
  // paging (a chart has no page).
  if IsHosted then
    LFilterExpr := HostPanel.FilterExpression
  else
    LFilterExpr := '';

  LStore := LViewTable.CreateStore;
  try
    LStore.Load(LFilterExpr, '', 0, 0);

    // Build chart JSON config
    LChartConfig := BuildChartConfig(LStore);

    SB := TStringBuilder.Create;
    try
      // Chart area (canvas). Wrapper interno per rispettare il padding di
      // .kx-chart-area (un canvas absolute figlio diretto lo ignorerebbe).
      SB.Append('<div class="kx-chart-area"><div class="kx-chart-canvas-wrap"><canvas id="kx-chart-canvas-').Append(FViewName).Append('"></canvas></div></div>');

      // Chart.js initialization script
      SB.Append('<script>kxChart.init(').Append(JSONStr(FViewName)).Append(', ').Append(LChartConfig).Append(');</script>');

      Result := SB.ToString;
    finally
      SB.Free;
    end;
  finally
    FreeAndNil(LStore);
  end;
end;

function TKXChartPanelController.GetChart: TKChartConfig;
begin
  Result := nil; // RTTI discovery only
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

{ TKChartSeriesLabelConfig }

function TKChartSeriesLabelConfig.GetField: string;
begin
  Result := GetString('Field');
end;

{ TKChartSpriteConfig }

function TKChartSpriteConfig.GetText: string;
begin
  Result := GetString('Text');
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

function TKChartSeriesConfig.GetAngleField: string;
begin
  Result := GetString('AngleField');
end;

function TKChartSeriesConfig.GetTitle: string;
begin
  Result := GetString('Title');
end;

function TKChartSeriesConfig.GetDonut: Integer;
begin
  Result := GetInteger('Donut', 0);
end;

function TKChartSeriesConfig.GetLabel: TKChartSeriesLabelConfig;
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

function TKChartAxisConfig.GetPosition: string;
begin
  Result := GetString('Position');
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

function TKChartConfig.GetSprites: TEFNode;
begin
  Result := nil; // RTTI discovery only
end;

{ TKChartLegendConfig }

function TKChartLegendConfig.GetDocked: string;
begin
  Result := GetString('Docked', 'top');
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('ChartPanel', TKXChartPanelController);
  TKXScriptRegistry.Instance.RegisterScript('/js/chart.umd.min.js');

finalization
  TKXControllerRegistry.Instance.UnregisterClass('ChartPanel');

end.
