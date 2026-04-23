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
///  KittoX GroupingList controller — renders a data grid with all records
///  grouped by a specified field, with collapsible group headers.
///  No paging (all records loaded). Inherits toolbar and filter support
///  from TKXListPanelController.
///  Replaces ExtJS TKExtGridPanel with Grouping feature.
/// </summary>
unit Kitto.Html.GroupingList;

{$I Kitto.Defines.inc}

interface

uses
  System.Types,
  EF.Tree,
  Kitto.Html.List,
  Kitto.Html.Controller,
  Kitto.Metadata.DataView,
  Kitto.Store;

type
  TKXGroupingListController = class(TKXListPanelController)
  strict private
    function GetGroupingFieldName: string;
    function GetGroupSortExpr(AViewTable: TKViewTable): string;
  strict protected
    function GetPanelCssClass: string; override;
    function RenderContent: string; override;
  public
    /// <summary>
    ///  Builds grouped data rows: group header rows with expand/collapse
    ///  toggle followed by data rows for each group.
    ///  Class function so it can be called from HandleKXDataRequest.
    /// </summary>
    class function BuildGroupedRows(AStore: TKViewTableStore;
      AViewTable: TKViewTable; const AViewName: string;
      const AGroupingFieldName: string;
      AGroupingNode: TEFNode;
      const AUrlViewName: string = ''): string;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.NetEncoding,
  Data.DB,
  EF.DB,
  EF.JSON,
  EF.StrUtils,
  EF.Localization,
  Kitto.Config,
  Kitto.Html.Base,
  Kitto.Html.Utils,
  Kitto.Metadata.Models,
  Kitto.Web.Request;

{ TKXGroupingListController }

function TKXGroupingListController.GetPanelCssClass: string;
begin
  Result := 'kx-list-panel kx-grouping-list';
end;

function TKXGroupingListController.GetGroupingFieldName: string;
begin
  Result := ViewTable.GetExpandedString('Controller/Grouping/FieldName');
  if Result = '' then
    raise Exception.Create('GroupingList controller requires Grouping/FieldName');
end;

function TKXGroupingListController.GetGroupSortExpr(AViewTable: TKViewTable): string;
var
  LSortFieldNames: TStringDynArray;
  LGroupingFieldName: string;
  I: Integer;
begin
  LSortFieldNames := AViewTable.GetStringArray('Controller/Grouping/SortFieldNames');
  if Length(LSortFieldNames) = 0 then
  begin
    LGroupingFieldName := GetGroupingFieldName;
    Result := AViewTable.FieldByName(LGroupingFieldName).QualifiedDBNameOrExpression;
  end
  else
  begin
    for I := Low(LSortFieldNames) to High(LSortFieldNames) do
      LSortFieldNames[I] := AViewTable.FieldByName(LSortFieldNames[I]).QualifiedDBNameOrExpression;
    Result := Join(LSortFieldNames, ', ');
  end;
end;

function TKXGroupingListController.RenderContent: string;
var
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LViewName: string;
  LGroupingFieldName: string;
  LGroupingNode: TEFNode;
  LSortExpr: string;
  LFilterPanelHtml: string;
  LDefaultFilterExpr: string;
  LRowClassProvider: string;
  SB: TStringBuilder;
begin
  Result := '';
  if not Assigned(View) or not (View is TKDataView) then
    Exit;

  LDataView := TKDataView(View);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  LViewName := View.PersistentName;
  LGroupingFieldName := GetGroupingFieldName;
  LGroupingNode := LViewTable.FindNode('Controller/Grouping');

  // Validate that the grouping field exists
  if LViewTable.FindField(LGroupingFieldName) = nil then
    raise Exception.CreateFmt('Grouping field %s not found in view table.', [LGroupingFieldName]);

  // Build sort expression from Grouping/SortFieldNames or grouping field
  LSortExpr := GetGroupSortExpr(LViewTable);

  // Build filter panel (if Filters/Items defined)
  LFilterPanelHtml := BuildFilterPanel(LViewName, LViewTable,
    LDefaultFilterExpr);

  // Load ALL records (no paging: start=0, count=0)
  LStore := LViewTable.CreateStore;
  try
    LStore.Load(LDefaultFilterExpr, LSortExpr, 0, 0);

    SB := TStringBuilder.Create;
    try
      // Filter panel
      SB.Append(LFilterPanelHtml);

      // Toolbar (CRUD buttons)
      SB.Append(BuildToolbar(LViewName));

      // Grid table: thead + tbody with grouped rows
      LRowClassProvider := LViewTable.GetExpandedString('Controller/RowClassProvider');
      SB.Append('<div class="kx-list-grid"><table class="kx-grid-table">');
      SB.Append(BuildColumnHeaders(LViewTable, LViewName, '', ''));
      SB.Append('<tbody id="kx-list-body-').Append(LViewName).Append('"');
      if IsActionVisible('Edit') and IsActionAllowed('Edit') then
        SB.Append(' data-dblclick="edit"')
      else if IsActionVisible('View') then
        SB.Append(' data-dblclick="view"');
      if LRowClassProvider <> '' then
        SB.Append(' data-row-class-provider="').Append(TNetEncoding.HTML.Encode(LRowClassProvider)).Append('"');
      SB.Append('>');
      SB.Append(BuildGroupedRows(LStore, LViewTable, LViewName,
        LGroupingFieldName, LGroupingNode));
      SB.Append('</tbody></table></div>');

      // No pager for GroupingList

      // Hidden state (no paging values, but needed for filter state)
      SB.Append(BuildHiddenState(LViewName, 0, '', ''));

      Result := SB.ToString;
    finally
      SB.Free;
    end;
  finally
    FreeAndNil(LStore);
  end;
end;

class function TKXGroupingListController.BuildGroupedRows(
  AStore: TKViewTableStore; AViewTable: TKViewTable;
  const AViewName, AGroupingFieldName: string;
  AGroupingNode: TEFNode;
  const AUrlViewName: string): string;
var
  I, J: Integer;
  LRecord: TKViewTableRecord;
  LField: TKViewField;
  LRecordField: TKViewTableField;
  LGroupField: TKViewField;
  LValue, LGroupValue, LPrevGroup: string;
  LAlign: string;
  LIsBool, LIsDateTime, LIsCurrency: Boolean;
  LChecked: string;
  LUserFmt: TFormatSettings;
  LCurrSymbol: string;
  LCaptionField: TKModelField;
  LCaptionValue: string;
  LGroupIndex: Integer;
  LStartCollapsed: Boolean;
  LShowCount, LShowName: Boolean;
  LItemName, LPluralItemName, LFieldLabel: string;
  LColCount: Integer;
  LGroupCounts: TStringList;
  LToggleIcon: string;
  LDisplayStyle: string;
  LCountText: string;
  LHeaderText: string;
  LHasRowClassProvider: Boolean;
  SB, SBKey: TStringBuilder;

  // Builds the ' data-fields="{...}"' attribute for a record so that the
  // client-side kxGrid.applyRowClasses can feed the values to the
  // RowClassProvider JS function. Returns '' when no RowClassProvider is
  // defined on the view. For data rows the record is the row's own record;
  // for group header rows it is the first record of the group (all records
  // of a group share the same value of the grouping field, so any record
  // that depends only on that field returns a constant class — this is what
  // lets the header receive the same colour as its data rows).
  function BuildRowDataFieldsAttr(ARecord: TKViewTableRecord): string;
  var
    K: Integer;
    LFld: TKViewField;
    LRecFld: TKViewTableField;
    SBF: TStringBuilder;
  begin
    Result := '';
    if not LHasRowClassProvider then
      Exit;
    SBF := TStringBuilder.Create;
    try
      SBF.Append('{');
      for K := 0 to AViewTable.FieldCount - 1 do
      begin
        LFld := AViewTable.Fields[K];
        if LFld.IsBlob and not (LFld.DataType is TEFMemoDataType) then
          Continue;
        LRecFld := ARecord.FindField(LFld.AliasedName);
        if not Assigned(LRecFld) then
          Continue;
        if SBF.Length > 1 then
          SBF.Append(',');
        SBF.Append('"').Append(LFld.AliasedName).Append('":');
        if LRecFld.IsNull then
          SBF.Append('null')
        else if LFld.DataType is TEFBooleanDataType then
          SBF.Append(IfThen(LRecFld.AsBoolean, 'true', 'false'))
        else if LFld.DataType is TEFNumericDataTypeBase then
          SBF.Append(LRecFld.GetAsJSONValue(False, False))
        else
          SBF.Append(QuoteJSONValue(LRecFld.AsString));
      end;
      SBF.Append('}');
      Result := ' data-fields="' + TNetEncoding.HTML.Encode(SBF.ToString) + '"';
    finally
      SBF.Free;
    end;
  end;

  // Pre-scan to count records per group
  procedure CountGroups;
  var
    K: Integer;
    LRec: TKViewTableRecord;
    LGrpField: TKViewTableField;
    LGrpVal: string;
  begin
    for K := 0 to AStore.RecordCount - 1 do
    begin
      LRec := AStore.Records[K];
      LGrpField := LRec.FindField(LGroupField.AliasedName);
      if Assigned(LGrpField) then
        LGrpVal := LGrpField.AsString
      else
        LGrpVal := '';
      J := LGroupCounts.IndexOf(LGrpVal);
      if J < 0 then
        LGroupCounts.AddObject(LGrpVal, TObject(1))
      else
        LGroupCounts.Objects[J] := TObject(NativeInt(LGroupCounts.Objects[J]) + 1);
    end;
  end;

begin
  LUserFmt := TKConfig.Instance.UserFormatSettings;
  LCurrSymbol := LUserFmt.CurrencyString;
  LHasRowClassProvider := AViewTable.GetExpandedString('Controller/RowClassProvider') <> '';

  // Read grouping config
  LStartCollapsed := False;
  LShowCount := False;
  LShowName := False;
  LItemName := '';
  LPluralItemName := '';
  if Assigned(AGroupingNode) then
  begin
    LStartCollapsed := AGroupingNode.GetBoolean('StartCollapsed', False);
    LShowCount := AGroupingNode.GetBoolean('ShowCount', False);
    LShowName := AGroupingNode.GetBoolean('ShowName', False);
    LItemName := AGroupingNode.GetString('ShowCount/ItemName', '');
    LPluralItemName := AGroupingNode.GetString('ShowCount/PluralItemName', '');
  end;

  LGroupField := AViewTable.FindField(AGroupingFieldName);
  if not Assigned(LGroupField) then
  begin
    // Fallback: render as regular rows if grouping field not found
    Result := BuildDataRows(AStore, AViewTable, AViewName, AUrlViewName);
    Exit;
  end;

  LFieldLabel := _(LGroupField.DisplayLabel);

  // Count visible columns for colspan
  LColCount := 0;
  for I := 0 to AViewTable.FieldCount - 1 do
    if AViewTable.Fields[I].IsVisible and not AViewTable.Fields[I].IsBlob then
      Inc(LColCount);

  if AStore.RecordCount = 0 then
  begin
    Result := '<tr class="kx-list-empty"><td colspan="' + IntToStr(LColCount) + '">' +
      TNetEncoding.HTML.Encode(_('No records found.')) + '</td></tr>';
    Exit;
  end;

  // Pre-scan to count records per group (for ShowCount)
  LGroupCounts := TStringList.Create;
  try
    if LShowCount then
      CountGroups;

    // Find caption field for data-caption attribute
    LCaptionField := nil;
    if Assigned(AViewTable.Model) then
      LCaptionField := AViewTable.Model.FindCaptionField;

    SB := TStringBuilder.Create;
    SBKey := TStringBuilder.Create;
    try
      LPrevGroup := #1; // sentinel — never matches a real value
      LGroupIndex := -1;

      for I := 0 to AStore.RecordCount - 1 do
      begin
        LRecord := AStore.Records[I];

        // Read current group value
        LRecordField := LRecord.FindField(LGroupField.AliasedName);
        if Assigned(LRecordField) then
          LGroupValue := LRecordField.AsString
        else
          LGroupValue := '';

        // Emit group header when group changes
        if LGroupValue <> LPrevGroup then
        begin
          Inc(LGroupIndex);
          LPrevGroup := LGroupValue;

          // Determine toggle icon and display style based on StartCollapsed
          if LStartCollapsed then
          begin
            LToggleIcon := '&#x25B6;'; // ▶ (right = collapsed)
            LDisplayStyle := ' style="display:none"';
          end
          else
          begin
            LToggleIcon := '&#x25BC;'; // ▼ (down = expanded)
            LDisplayStyle := '';
          end;

          // Build header text
          LHeaderText := '';
          if LShowName then
            LHeaderText := TNetEncoding.HTML.Encode(LFieldLabel) + ': ';
          LHeaderText := LHeaderText + TNetEncoding.HTML.Encode(LGroupValue);

          // Append count if ShowCount
          if LShowCount then
          begin
            J := LGroupCounts.IndexOf(LGroupValue);
            if J >= 0 then
            begin
              LCountText := IntToStr(NativeInt(LGroupCounts.Objects[J]));
              if NativeInt(LGroupCounts.Objects[J]) = 1 then
              begin
                if LItemName <> '' then
                  LCountText := LCountText + ' ' + _(LItemName)
              end
              else
              begin
                if LPluralItemName <> '' then
                  LCountText := LCountText + ' ' + _(LPluralItemName)
                else if LItemName <> '' then
                  LCountText := LCountText + ' ' + _(LItemName);
              end;
              LHeaderText := LHeaderText + ' (' + TNetEncoding.HTML.Encode(LCountText) + ')';
            end;
          end;

          // Emit group header row. data-fields is built from the first record
          // of the group (LRecord on the iteration where the group changed) so
          // the client-side RowClassProvider, if any, can assign the same class
          // to the header as to the data rows of this group.
          SB.Append('<tr class="kx-group-row" id="kx-grp-hdr-')
            .Append(AViewName).Append('-').Append(IntToStr(LGroupIndex))
            .Append('"');
          SB.Append(BuildRowDataFieldsAttr(LRecord));
          SB.Append(' onclick="kxGrid.toggleGroup(''')
            .Append(AViewName).Append(''',').Append(IntToStr(LGroupIndex)).Append(')">');
          SB.Append('<td colspan="').Append(IntToStr(LColCount)).Append('" class="kx-group-header">');
          SB.Append('<span class="kx-group-toggle">').Append(LToggleIcon).Append('</span>');
          SB.Append(LHeaderText);
          SB.Append('</td></tr>');
        end;

        // Build URL-encoded key string for row selection
        SBKey.Clear;
        for J := 0 to AViewTable.FieldCount - 1 do
        begin
          LField := AViewTable.Fields[J];
          if LField.IsKey then
          begin
            LRecordField := LRecord.FindField(LField.AliasedName);
            if Assigned(LRecordField) then
            begin
              if SBKey.Length > 0 then
                SBKey.Append('&amp;');
              SBKey.Append(TNetEncoding.HTML.Encode(TNetEncoding.URL.Encode(LField.AliasedName)));
              SBKey.Append('=');
              SBKey.Append(TNetEncoding.HTML.Encode(TNetEncoding.URL.Encode(LRecordField.AsString)));
            end;
          end;
        end;

        // Extract caption value
        LCaptionValue := '';
        if Assigned(LCaptionField) then
        begin
          LRecordField := LRecord.FindField(LCaptionField.FieldName);
          if Assigned(LRecordField) and not LRecordField.IsNull then
            LCaptionValue := LRecordField.AsString;
        end;

        // Emit data row with group class and conditional display
        SB.Append('<tr class="kx-group-data kx-grp-').Append(AViewName).Append('-').Append(IntToStr(LGroupIndex)).Append('"');
        SB.Append(LDisplayStyle);
        SB.Append(' data-key="').Append(SBKey.ToString).Append('"');
        SB.Append(' data-caption="').Append(TNetEncoding.HTML.Encode(LCaptionValue)).Append('"');
        SB.Append(BuildRowDataFieldsAttr(LRecord));
        SB.Append(' onclick="kxGrid.select(this,''').Append(AViewName).Append(''')"');
        SB.Append(' ondblclick="kxGrid.rowDblClick(this,''').Append(AViewName).Append(''')">');

        // Render cells (same logic as BuildDataRows)
        for J := 0 to AViewTable.FieldCount - 1 do
        begin
          LField := AViewTable.Fields[J];
          if not LField.IsVisible then
            Continue;
          if LField.IsBlob then
            Continue;

          LAlign := LField.DataType.GetDefaultColumnAlignment;
          LIsBool := LField.DataType is TEFBooleanDataType;
          LIsDateTime := LField.DataType is TEFDateTimeDataTypeBase;
          LIsCurrency := LField.DataType is TEFCurrencyDataType;

          LRecordField := LRecord.FindField(LField.AliasedName);
          if Assigned(LRecordField) then
          begin
            if LIsBool then
            begin
              if LRecordField.AsBoolean then
                LChecked := ' checked'
              else
                LChecked := '';
              SB.Append('<td style="text-align:center"><input type="checkbox" disabled');
              SB.Append(LChecked).Append('></td>');
            end
            else if LIsDateTime then
            begin
              LValue := LField.DataType.NodeToJSONValue(True, LRecordField, LUserFmt, False);
              if SameText(LValue, 'null') then
                LValue := '';
              SB.Append('<td style="text-align:').Append(LAlign).Append('"');
              if LValue <> '' then
                SB.Append(' data-full="').Append(TNetEncoding.HTML.Encode(LValue)).Append('"');
              SB.Append('>').Append(TNetEncoding.HTML.Encode(LValue)).Append('</td>');
            end
            else if LIsCurrency then
            begin
              LValue := LField.DataType.NodeToJSONValue(True, LRecordField, LUserFmt, False);
              if SameText(LValue, 'null') then
                LValue := '';
              if (LValue <> '') and (LCurrSymbol <> '') then
                LValue := LCurrSymbol + ' ' + LValue;
              SB.Append('<td style="text-align:right"');
              if LValue <> '' then
                SB.Append(' data-full="').Append(TNetEncoding.HTML.Encode(LValue)).Append('"');
              SB.Append('>').Append(TNetEncoding.HTML.Encode(LValue)).Append('</td>');
            end
            else
            begin
              LValue := LRecordField.GetAsJSONValue(True, False);
              if SameText(LValue, 'null') then
                LValue := '';
              SB.Append('<td style="text-align:').Append(LAlign).Append('"');
              if LValue <> '' then
                SB.Append(' data-full="').Append(TNetEncoding.HTML.Encode(LValue)).Append('"');
              SB.Append('>').Append(TNetEncoding.HTML.Encode(LValue)).Append('</td>');
            end;
          end
          else
            SB.Append('<td></td>');
        end;
        SB.Append('</tr>');
      end;

      Result := SB.ToString;
    finally
      SBKey.Free;
      SB.Free;
    end;
  finally
    LGroupCounts.Free;
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('GroupingList', TKXGroupingListController);

end.
