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
  EF.YAML.Attributes,
  Kitto.Metadata.SubNodes2;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXChartPanelController = class(TKXDataPanelController)
  strict private
    FViewName: string;
    function BuildChartConfig(AStore: TKViewTableStore): string;
    function BuildChartToolbar: string;
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

    /// <summary>
    ///  Builds grid table rows (tbody content) for the sidebar.
    ///  Public class function so it can be reused by the chart-data endpoint.
    /// </summary>
    class function BuildGridRows(AStore: TKViewTableStore;
      AViewTable: TKViewTable): string;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.NetEncoding,
  EF.Tree,
  EF.Localization,
  Kitto.Config,
  Kitto.Html.Base,
  Kitto.Html.Utils,
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

    // Series title
    LSeriesNode := Config.FindNode('Chart/Series/Series');
    LSeriesTitle := '';
    if Assigned(LSeriesNode) then
      LSeriesTitle := _(LSeriesNode.GetString('Title', ''));

    // Build Chart.js config JSON
    SB.Append('{"type": ').Append(JSONStr(LChartJsType));
    SB.Append(', "data": {"labels": [').Append(SBLabels.ToString).Append('], ');
    SB.Append('"datasets": [{"data": [').Append(SBData.ToString).Append(']');

    if LSeriesTitle <> '' then
      SB.Append(', "label": ').Append(JSONStr(LSeriesTitle));

    SB.Append(', "backgroundColor": [').Append(SBColors.ToString).Append(']');
    SB.Append(', "borderColor": [').Append(SBBorders.ToString).Append(']');
    SB.Append(', "borderWidth": 1}]}, ');

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

class function TKXChartPanelController.BuildGridRows(
  AStore: TKViewTableStore; AViewTable: TKViewTable): string;
var
  I, J: Integer;
  LField: TKViewField;
  LRecord: TKViewTableRecord;
  LRecordField: TKViewTableField;
  LValue, LAlign: string;
  SB: TStringBuilder;
begin
  if AStore.RecordCount = 0 then
  begin
    J := 0;
    for I := 0 to AViewTable.FieldCount - 1 do
      if AViewTable.Fields[I].IsVisible and not AViewTable.Fields[I].IsBlob then
        Inc(J);
    Result := '<tr class="kx-list-empty"><td colspan="' + IntToStr(J) + '">' +
      TNetEncoding.HTML.Encode(_('No records found.')) + '</td></tr>';
    Exit;
  end;

  SB := TStringBuilder.Create;
  try
    for I := 0 to AStore.RecordCount - 1 do
    begin
      LRecord := AStore.Records[I];
      SB.Append('<tr>');
      for J := 0 to AViewTable.FieldCount - 1 do
      begin
        LField := AViewTable.Fields[J];
        if not LField.IsVisible or LField.IsBlob then
          Continue;
        LAlign := LField.DataType.GetDefaultColumnAlignment;
        LRecordField := LRecord.FindField(LField.AliasedName);
        if Assigned(LRecordField) and not LRecordField.IsNull then
        begin
          LValue := LRecordField.GetAsJSONValue(True, False);
          if SameText(LValue, 'null') then
            LValue := '';
        end
        else
          LValue := '';
        SB.Append('<td style="text-align:').Append(LAlign).Append('">');
        SB.Append(TNetEncoding.HTML.Encode(LValue)).Append('</td>');
      end;
      SB.Append('</tr>');
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXChartPanelController.BuildChartToolbar: string;
begin
  Result :=
    '<div class="kx-list-toolbar">' +
      '<button type="button" class="kx-toolbar-btn"' +
      ' onclick="kxChart.refresh(''' + FViewName + ''')">' +
      GetIconHTML('refresh') +
      ' <span class="kx-btn-label">' +
      TNetEncoding.HTML.Encode(_('Refresh')) + '</span>' +
      '</button>' +
    '</div>';
end;

function TKXChartPanelController.RenderContent: string;
var
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LControllerNode: TEFNode;
  LWestNode, LEastNode: TEFNode;
  LSidebarWidth: Integer;
  LChartConfig: string;
  I: Integer;
  LField: TKViewField;
  SB, SBSidebar: TStringBuilder;
begin
  Result := '';
  if not Assigned(View) or not (View is TKDataView) then
    Exit;

  LDataView := TKDataView(View);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // Check sidebar position from the View's Controller node
  LControllerNode := View.FindNode('Controller');
  LWestNode := nil;
  LEastNode := nil;
  if Assigned(LControllerNode) then
  begin
    LWestNode := LControllerNode.FindNode('WestController');
    LEastNode := LControllerNode.FindNode('EastController');
  end;

  // Load all records (no paging)
  LStore := LViewTable.CreateStore;
  try
    LStore.Load('', '', 0, 0);

    // Build chart JSON config
    LChartConfig := BuildChartConfig(LStore);

    // Build sidebar grid HTML (toolbar + table)
    SBSidebar := TStringBuilder.Create;
    SB := TStringBuilder.Create;
    try
      SBSidebar.Append(BuildChartToolbar);
      SBSidebar.Append('<div class="kx-chart-grid"><table class="kx-grid-table"><thead><tr>');
      for I := 0 to LViewTable.FieldCount - 1 do
      begin
        LField := LViewTable.Fields[I];
        if not LField.IsVisible or LField.IsBlob then
          Continue;
        SBSidebar.Append('<th>').Append(TNetEncoding.HTML.Encode(_(LField.DisplayLabel))).Append('</th>');
      end;
      SBSidebar.Append('</tr></thead><tbody id="kx-chart-grid-').Append(FViewName).Append('">');
      SBSidebar.Append(BuildGridRows(LStore, LViewTable));
      SBSidebar.Append('</tbody></table></div>');

      // Assemble layout: west sidebar + chart area + east sidebar

      // West sidebar + splitter
      if Assigned(LWestNode) then
      begin
        LSidebarWidth := LWestNode.GetInteger('Width', 400);
        SB.Append('<div class="kx-chart-sidebar kx-chart-sidebar-west" style="width:').Append(IntToStr(LSidebarWidth)).Append('px">');
        SB.Append(SBSidebar.ToString);
        SB.Append('<div class="kx-splitter kx-splitter-h" data-direction="horizontal" data-side="end"></div>');
        SB.Append('</div>');
      end;

      // Chart area (canvas)
      SB.Append('<div class="kx-chart-area"><canvas id="kx-chart-canvas-').Append(FViewName).Append('"></canvas></div>');

      // East sidebar + splitter
      if Assigned(LEastNode) then
      begin
        LSidebarWidth := LEastNode.GetInteger('Width', 400);
        SB.Append('<div class="kx-chart-sidebar kx-chart-sidebar-east" style="width:').Append(IntToStr(LSidebarWidth)).Append('px">');
        SB.Append('<div class="kx-splitter kx-splitter-h" data-direction="horizontal" data-side="start"></div>');
        SB.Append(SBSidebar.ToString);
        SB.Append('</div>');
      end;

      // Chart.js initialization script
      SB.Append('<script>kxChart.init(').Append(JSONStr(FViewName)).Append(', ').Append(LChartConfig).Append(');</script>');

      Result := SB.ToString;
    finally
      SB.Free;
      SBSidebar.Free;
    end;
  finally
    FreeAndNil(LStore);
  end;
end;

function TKXChartPanelController.GetChart: TKChartConfig;
begin
  Result := nil; // RTTI discovery only
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('ChartPanel', TKXChartPanelController);
  TKXScriptRegistry.Instance.RegisterScript('/js/chart.umd.min.js');

finalization
  TKXControllerRegistry.Instance.UnregisterClass('ChartPanel');

end.
