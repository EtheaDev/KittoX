{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   This file is part of KittoX Enterprise Edition.
   Licensed under the AGPL-3.0 or Ethea Commercial License.
   See LICENSE-ENTERPRISE for details.
-------------------------------------------------------------------------------}

/// <summary>
///   Attribute-routed handler for chart data requests.
///   Returns JSON with labels, data arrays, and grid HTML for Chart.js panels.
/// </summary>
unit Kitto.Web.Handler.Chart;

{$I Kitto.Defines.inc}
{$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}

interface

uses
  Kitto.Web.Routing.Attributes,
  Kitto.Metadata.DataView;

type
  [TKXPath('/kx/view/{ViewName}')]
  TKXChartHandler = class
  public
    [TKXPath('/chart-data')]
    [TKXGET]
    procedure HandleChartData(
      [TKXPathParam('ViewName')] const AViewName: string;
      [TKXContext] ADataView: TKDataView);
  end;

implementation

uses
  System.SysUtils,
  EF.Tree,
  Kitto.Metadata.Views,
  Kitto.Store,
  Kitto.Web.Response,
  Kitto.Html.ChartPanel,
  Kitto.Web.Routing.Registry;

procedure TKXChartHandler.HandleChartData(const AViewName: string;
  ADataView: TKDataView);
var
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LControllerNode, LCenterNode, LSeriesNode: TEFNode;
  LLabelField, LDataField: string;
  I: Integer;
  LRecord: TKViewTableRecord;
  LRecordField: TKViewTableField;
  LGridHtml, LJson: string;
  LFmt: TFormatSettings;
  SBLabels, SBData: TStringBuilder;
begin
  Assert(Assigned(ADataView), 'ADataView Assigned');
  Assert(Assigned(ADataView.MainTable), 'ADataView.MainTable Assigned');

  LViewTable := ADataView.MainTable;

  // Read chart field names from the CenterController config
  LControllerNode := ADataView.FindNode('Controller');
  if not Assigned(LControllerNode) then
    Exit;
  LCenterNode := LControllerNode.FindNode('CenterController');
  if not Assigned(LCenterNode) then
    Exit;
  LSeriesNode := LCenterNode.FindNode('Chart/Series/Series');
  if not Assigned(LSeriesNode) then
    Exit;

  // Determine label and data field names
  LLabelField := LSeriesNode.GetString('XField', '');
  if LLabelField = '' then
    LLabelField := LSeriesNode.GetString('Label/Field', '');
  LDataField := LSeriesNode.GetString('YField', '');
  if LDataField = '' then
    LDataField := LSeriesNode.GetString('AngleField', '');

  LFmt := TFormatSettings.Create;
  LFmt.DecimalSeparator := '.';
  LFmt.ThousandSeparator := #0;

  // Load all records
  LStore := LViewTable.CreateStore;
  try
    LStore.Load('', '', 0, 0);

    // Build JSON arrays for labels and data
    SBLabels := TStringBuilder.Create;
    SBData := TStringBuilder.Create;
    try
      for I := 0 to LStore.RecordCount - 1 do
      begin
        LRecord := LStore.Records[I];
        if I > 0 then
        begin
          SBLabels.Append(', ');
          SBData.Append(', ');
        end;

        LRecordField := LRecord.FindField(LLabelField);
        if Assigned(LRecordField) and not LRecordField.IsNull then
          SBLabels.Append(TKXChartPanelController.JSONStr(LRecordField.AsString))
        else
          SBLabels.Append('""');

        LRecordField := LRecord.FindField(LDataField);
        if Assigned(LRecordField) and not LRecordField.IsNull then
          SBData.Append(FormatFloat('0.####', LRecordField.AsFloat, LFmt))
        else
          SBData.Append('0');
      end;

      // Build grid HTML rows for sidebar refresh
      LGridHtml := TKXChartPanelController.BuildGridRows(LStore, LViewTable);
      LGridHtml := TKXChartPanelController.JSONStr(LGridHtml);

      // Assemble JSON response
      LJson := '{"labels": [' + SBLabels.ToString + '], "data": [' +
        SBData.ToString + '], "gridHtml": ' + LGridHtml + '}';
    finally
      SBData.Free;
      SBLabels.Free;
    end;

    TKWebResponse.Current.Items.Clear;
    TKWebResponse.Current.Items.AddHTML(LJson);
    TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
  finally
    FreeAndNil(LStore);
  end;
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXChartHandler);

finalization
  TKXResourceRegistry.Instance.UnregisterResource(TKXChartHandler);

end.
