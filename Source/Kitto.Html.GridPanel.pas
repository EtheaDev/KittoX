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
///  KittoX GridPanel controller — the grid presenter of a data list: sortable
///  column headers, data rows, server-side paging and lookup mode, HTMX-driven.
///  It shows the records; the list of records itself (filters, action flags)
///  belongs to the List host (Kitto.Html.List), whose default Center presenter
///  this is, and which can also host it beside another presenter
///  (WestController: GridPanel next to a chart). Stand-alone it builds its own
///  filter panel. Registered as 'GridPanel', the presenter name Kitto1 YAML
///  already uses (CenterController: GridPanel, WestController: GridPanel).
///  Replaces TKExtGridPanel from Kitto.Ext.GridPanel.
/// </summary>
unit Kitto.Html.GridPanel;

{$I Kitto.Defines.inc}

interface

uses
  System.Types,
  EF.Tree,
  Kitto.Html.DataPanel,
  Kitto.Html.Controller,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView;

type
  /// <summary>
  ///  Grid presenter: renders the toolbar, the column headers, the data rows,
  ///  the pager and the lookup Select/Cancel bar for the records of its
  ///  ViewTable; the filter panel comes from the host when hosted, from the
  ///  data panel base when stand-alone. Base class for TKXGroupingListController.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXGridPanelController = class(TKXDataPanelLeafController)
  strict protected
    function GetPanelCssClass: string; override;
  public
    /// <summary>
    ///  Renders the grid content (filter panel, toolbar, table, pager, state).
    ///  Public on purpose: a data-list host renders its presenter's CONTENT
    ///  inside its own panel chrome, without going through Render (which would
    ///  add a second chrome around it).
    /// </summary>
    function RenderContent: string; override;

    /// <summary>Builds the grid data rows (&lt;tr&gt;…) for the given store/layout — the
    /// tbody content swapped by HTMX on filter/sort/paging.</summary>
    class function BuildDataRows(AStore: TKViewTableStore;
      AViewTable: TKViewTable; const AViewName: string;
      const AUrlViewName: string = '';
      ALayout: TKLayout = nil): string;

    /// <summary>Builds the grid column headers (with sort links reflecting the
    /// current sort/dir). AHiddenFieldName, when given, names a field that must
    /// not get a column: a grouped grid uses it to leave out the field it
    /// groups by, whose value is already in every group header.</summary>
    class function BuildColumnHeaders(AViewTable: TKViewTable;
      const AViewName, ACurrentSort, ACurrentDir: string;
      const AUrlViewName: string = '';
      ALayout: TKLayout = nil;
      const AHiddenFieldName: string = ''): string;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.Math,
  System.NetEncoding,
  Data.DB,
  EF.DB,
  EF.Localization,
  EF.Types,
  Kitto.Config,
  Kitto.Store,
  Kitto.Html.Base,
  Kitto.Html.Editors,
  Kitto.Html.Utils,
  Kitto.Html.Tools,
  Kitto.Metadata.Models,
  Kitto.Web.Request,
  Kitto.Web.Session,
  EF.Macros,
  EF.JSON;

{ TKXGridPanelController }

function TKXGridPanelController.GetPanelCssClass: string;
begin
  // Same panel class as the List so a grid looks the same wherever it renders.
  Result := 'kx-list-panel';
end;

function TKXGridPanelController.RenderContent: string;
var
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LTotal: Integer;
  LPageSize: Integer;
  LViewName: string;
  LViewAlias: string;
  LUrlViewName: string;
  LIsLookup: Boolean;
  LFilterPanelHtml: string;
  LDefaultFilterExpr: string;
  LSortExpr: string;
  LSortFieldNames: TStringDynArray;
  LInitialSort: string;
  LPagingTools: Boolean;
  LAutoOpen: Boolean;
  LGridLayout: TKLayout;
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

  LGridLayout := LViewTable.FindLayout('Grid');
  LViewName := View.PersistentName;

  // Detect lookup mode (set by HandleKXLookupRequest via query param)
  LIsLookup := SameText(TKWebRequest.Current.GetQueryField('mode'), 'lookup');
  if LIsLookup then
  begin
    LViewAlias := 'lkp_' + LViewName;
    LUrlViewName := LViewName;
  end
  else
  begin
    LViewAlias := LViewName;
    LUrlViewName := '';  // empty = use AViewName for URLs (backward compat)
  end;

  // IsLarge drives the defaults:
  //   PagingTools default = IsLarge
  //   AutoOpen     default = not IsLarge
  // When AutoOpen is False the grid does not auto-load; user applies a filter
  // or clicks Refresh to populate it.
  LPagingTools := LViewTable.GetBoolean('Controller/PagingTools', LViewTable.IsLarge);
  LAutoOpen := LViewTable.GetBoolean('Controller/AutoOpen', not LViewTable.IsLarge);

  // Standard grid rendering
  // Paging: only when PagingTools is enabled
  if LPagingTools then
    LPageSize := LViewTable.GetInteger('Controller/PagingTools/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT)
  else
    LPageSize := 0;

  // Build sort expression from MainTable/Controller/SortFieldNames
  LSortExpr := '';
  LInitialSort := '';
  LSortFieldNames := LViewTable.GetStringArray('Controller/SortFieldNames');
  if Length(LSortFieldNames) > 0 then
  begin
    LInitialSort := LSortFieldNames[0]; // First sort field for column indicator
    var J: Integer;
    for J := Low(LSortFieldNames) to High(LSortFieldNames) do
      LSortFieldNames[J] := LViewTable.FieldByName(LSortFieldNames[J]).QualifiedDBNameOrExpression;
    LSortExpr := string.Join(', ', LSortFieldNames);
  end;

  // Filter panel (if Filters/Items defined): the host's when hosted, which
  // then only hands over the expression its defaults select.
  LFilterPanelHtml := ResolveFilterPanel(LViewAlias, LViewTable,
    LDefaultFilterExpr, LUrlViewName);

  // Load first page of data (with default filter and sort expression).
  // AutoOpen=False (default when IsLarge=True) skips the initial load —
  // user populates the grid by applying a filter or clicking Refresh.
  LStore := LViewTable.CreateStore;
  try
    if LAutoOpen then
      LTotal := LStore.Load(CombineWhere(LDefaultFilterExpr, GetLookupContextFilter), LSortExpr, 0, LPageSize)
    else
      LTotal := 0;

    SB := TStringBuilder.Create;
    try
      // Filter panel
      SB.Append(LFilterPanelHtml);

      // Toolbar (CRUD buttons or Select/Cancel in lookup mode)
      SB.Append(BuildToolbar(LViewAlias, LUrlViewName));

      // Grid table: thead + tbody
      LRowClassProvider := LViewTable.GetExpandedString('Controller/RowClassProvider');
      SB.Append('<div class="kx-list-grid"><table class="kx-grid-table">');
      SB.Append(BuildColumnHeaders(LViewTable, LViewAlias, LInitialSort, 'asc', LUrlViewName, LGridLayout));
      SB.Append('<tbody id="kx-list-body-').Append(LViewAlias).Append('"');
      // In lookup mode a double click picks the row, which is what the user
      // came here for. Opening a form would be wrong twice over: the grid is
      // there to choose a value, and the name in scope is the lkp_ alias, which
      // is not a view - the request would 404.
      if LIsLookup then
        SB.Append(' data-dblclick="select"')
      else if IsActionVisible('Edit') and IsActionAllowed('Edit') then
        SB.Append(' data-dblclick="edit"')
      else if IsActionVisible('View') then
        SB.Append(' data-dblclick="view"');
      if LRowClassProvider <> '' then
        SB.Append(' data-row-class-provider="').Append(TNetEncoding.HTML.Encode(LRowClassProvider)).Append('"');
      SB.Append('>');
      SB.Append(BuildDataRows(LStore, LViewTable, LViewAlias, LUrlViewName, LGridLayout));
      SB.Append('</tbody></table></div>');

      // Pager (only when PagingTools is enabled)
      if LPagingTools then
        SB.Append(BuildPager(LViewAlias, LTotal, 0, LPageSize, LUrlViewName));

      // Hidden state inputs (with initial sort info)
      SB.Append(BuildHiddenState(LViewAlias, LPageSize, LInitialSort, 'asc', LUrlViewName));

      // Lookup mode footer: Select + Cancel buttons at the bottom
      if LIsLookup then
      begin
        SB.Append('<div class="kx-lookup-select-bar">');
        SB.Append('<button type="button" class="kx-form-btn kx-requires-selection" disabled');
        SB.Append(' onclick="kxForm.onLookupSelect(''').Append(LViewAlias).Append(''')">');
        SB.Append(GetIconHTML('accept')).Append(' ');
        SB.Append(TNetEncoding.HTML.Encode(_('Select')));
        SB.Append('</button>');
        SB.Append('<button type="button" class="kx-form-btn kx-form-btn-cancel"');
        SB.Append(' onclick="kxForm.closeLookup(''').Append(LViewAlias).Append(''')">');
        SB.Append(GetIconHTML('cancel')).Append(' ');
        SB.Append(TNetEncoding.HTML.Encode(_('Cancel')));
        SB.Append('</button></div>');
      end;

      Result := SB.ToString;
    finally
      SB.Free;
    end;
  finally
    FreeAndNil(LStore);
  end;
end;

class function TKXGridPanelController.BuildColumnHeaders(
  AViewTable: TKViewTable; const AViewName, ACurrentSort, ACurrentDir: string;
  const AUrlViewName: string; ALayout: TKLayout;
  const AHiddenFieldName: string): string;
var
  I, LCount: Integer;
  LField: TKViewField;
  LHiddenField: TKViewField;
  LLayoutNode: TEFNode;
  LLabel: string;
  LAlign: string;
  LWidthStyle: string;
  LDisplayWidth: Integer;
  LSortable: Boolean;
  LSortClass: string;
  LSortIndexAttr: string;
  LFieldName: string;
  LInc: string;
  LUrlName: string;
  SB: TStringBuilder;

  function GetFieldForIndex(AIndex: Integer; out AField: TKViewField;
    out ALayoutNode: TEFNode): Boolean;
  var
    LNode: TEFNode;
    LName: string;
  begin
    Result := False;
    ALayoutNode := nil;
    if Assigned(ALayout) then
    begin
      // Iterate layout nodes in order
      LNode := ALayout.Children[AIndex];
      if not SameText(LNode.Name, 'Field') then
        Exit;
      LName := LNode.AsString;
      AField := AViewTable.FindField(LName);
      if not Assigned(AField) then
        Exit;
      if Assigned(LHiddenField) and (AField = LHiddenField) then
        Exit;
      ALayoutNode := LNode;
      Result := True;
    end
    else
    begin
      // No layout: iterate ViewTable fields, skip invisible and binary blobs
      // (Memo/HTMLMemo are text blobs and must be shown in the grid)
      AField := AViewTable.Fields[AIndex];
      if not AField.IsVisible or (AField.IsBlob and not (AField.DataType is TEFMemoDataType)) then
        Exit;
      if Assigned(LHiddenField) and (AField = LHiddenField) then
        Exit;
      Result := True;
    end;
  end;

begin
  if AHiddenFieldName <> '' then
    LHiddenField := AViewTable.FindField(AHiddenFieldName)
  else
    LHiddenField := nil;

  if AUrlViewName <> '' then
    LUrlName := AUrlViewName
  else
    LUrlName := AViewName;
  LInc := HxInclude(AViewName);

  if Assigned(ALayout) then
    LCount := ALayout.ChildCount
  else
    LCount := AViewTable.FieldCount;

  SB := TStringBuilder.Create;
  try
    SB.Append('<thead id="kx-list-head-').Append(AViewName).Append('"><tr>');
    for I := 0 to LCount - 1 do
    begin
      if not GetFieldForIndex(I, LField, LLayoutNode) then
        Continue;

      // DisplayLabel override from layout
      LLabel := '';
      if Assigned(LLayoutNode) then
      begin
        if LLayoutNode.GetBoolean('HideLabel') then
          LLabel := ''
        else
          LLabel := LLayoutNode.GetString('DisplayLabel');
      end;
      if LLabel = '' then
      begin
        LLabel := LField.DisplayLabel_Grid;
        if LLabel = '' then
          LLabel := LField.DisplayLabel;
      end;
      // Localize the column header like every other label: without this a
      // metadata DisplayLabel written as a gettext marker (e.g. "_(Phase)") was
      // emitted verbatim into the <th>. _() both strips the "_(...)" marker and
      // translates, and is a no-op passthrough for a plain string.
      if LLabel <> '' then
        LLabel := _(LLabel);

      // Align override from layout
      if Assigned(LLayoutNode) and (LLayoutNode.GetString('Align') <> '') then
        LAlign := LLayoutNode.GetString('Align')
      else
        LAlign := LField.DataType.GetDefaultColumnAlignment;

      // DisplayWidth from layout (in ch units)
      LWidthStyle := '';
      if Assigned(LLayoutNode) then
        LDisplayWidth := LLayoutNode.GetInteger('DisplayWidth')
      else
        LDisplayWidth := 0;
      if LDisplayWidth > 0 then
        LWidthStyle := 'width:' + IntToStr(LDisplayWidth) + 'ch;';

      LFieldName := LField.FieldName;

      LSortable := True;

      // Determine initial sort CSS class (arrows rendered via CSS ::after).
      // ACurrentSort/ACurrentDir are CSV lists supporting multi-column sort:
      // a column is marked with kx-sort-asc/desc when its name matches any
      // element, and with data-sort-index (1-based) when more than one key
      // is active.
      LSortClass := '';
      LSortIndexAttr := '';
      var LSortFields: TArray<string> := ACurrentSort.Split([',']);
      var LSortDirs: TArray<string> := ACurrentDir.Split([',']);
      for var K := 0 to High(LSortFields) do
        if SameText(LSortFields[K].Trim, LFieldName) then
        begin
          if (K <= High(LSortDirs)) and SameText(LSortDirs[K].Trim, 'desc') then
            LSortClass := ' kx-sort-desc'
          else
            LSortClass := ' kx-sort-asc';
          if Length(LSortFields) > 1 then
            LSortIndexAttr := ' data-sort-index="' + IntToStr(K + 1) + '"';
          Break;
        end;

      if LSortable then
      begin
        SB.Append('<th class="kx-col-sortable').Append(LSortClass).Append('" ');
        SB.Append('data-field="').Append(LFieldName).Append('"').Append(LSortIndexAttr).Append(' ');
        SB.Append('style="text-align:').Append(LAlign).Append(';').Append(LWidthStyle).Append('" ');
        SB.Append('hx-get="kx/view/').Append(LUrlName).Append('/data" ');
        SB.Append('hx-target="#kx-list-body-').Append(AViewName).Append('" ');
        SB.Append('hx-include="').Append(LInc).Append('" ');
        SB.Append('onclick="kxGrid.prepareSort(this,''').Append(AViewName).Append(''',event)" ');
        SB.Append('>');
        SB.Append(TNetEncoding.HTML.Encode(LLabel));
        // Resize handle: user-adjustable column width (ephemeral, no persistence).
        SB.Append('<span class="kx-col-resize" onmousedown="kxGrid.startColResize(event,this)"></span>');
        SB.Append('</th>');
      end
      else
      begin
        SB.Append('<th style="text-align:').Append(LAlign).Append(';').Append(LWidthStyle).Append('">');
        SB.Append(TNetEncoding.HTML.Encode(LLabel));
        SB.Append('<span class="kx-col-resize" onmousedown="kxGrid.startColResize(event,this)"></span>');
        SB.Append('</th>');
      end;
    end;
    SB.Append('</tr></thead>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TKXGridPanelController.BuildDataRows(
  AStore: TKViewTableStore; AViewTable: TKViewTable;
  const AViewName: string; const AUrlViewName: string;
  ALayout: TKLayout): string;
var
  I, J, LColCount: Integer;
  LRecord: TKViewTableRecord;
  LField: TKViewField;
  LLayoutNode: TEFNode;
  LRecordField: TKViewTableField;
  LValue: string;
  LAlign: string;
  LIsBool: Boolean;
  LIsDateTime: Boolean;
  LIsCurrency: Boolean;
  LChecked: string;
  LUserFmt: TFormatSettings;
  LCurrSymbol: string;
  LCaptionField: TKModelField;
  LCaptionValue: string;
  LRowClassProvider: string;
  SB, SBKey, SBFields, SBAutoAdd: TStringBuilder;
  LIsLookup: Boolean;
  LCallingViewName, LCallingFieldName: string;
  LCallingView: TKView;
  LCallingTable: TKViewTable;
  LCallingViewField: TKViewField;
  LAutoAddNode: TEFNode;
  LAutoAddSourceFields, LAutoAddAliases: TArray<string>;
  LAutoAddSrcField: TKViewField;

  function GetCellField(AIndex: Integer; out AField: TKViewField;
    out ALayoutNode: TEFNode): Boolean;
  var
    LNode: TEFNode;
    LName: string;
  begin
    Result := False;
    ALayoutNode := nil;
    if Assigned(ALayout) then
    begin
      LNode := ALayout.Children[AIndex];
      if not SameText(LNode.Name, 'Field') then
        Exit;
      LName := LNode.AsString;
      AField := AViewTable.FindField(LName);
      if not Assigned(AField) then
        Exit;
      ALayoutNode := LNode;
      Result := True;
    end
    else
    begin
      AField := AViewTable.Fields[AIndex];
      if not AField.IsVisible or (AField.IsBlob and not (AField.DataType is TEFMemoDataType)) then
        Exit;
      Result := True;
    end;
  end;

begin
  LUserFmt := TKConfig.Instance.UserFormatSettings;
  LCurrSymbol := LUserFmt.CurrencyString;

  if Assigned(ALayout) then
    LColCount := ALayout.ChildCount
  else
    LColCount := AViewTable.FieldCount;

  // Find caption field for data-caption attribute (used by lookup selection)
  LCaptionField := nil;
  if Assigned(AViewTable.Model) then
    LCaptionField := AViewTable.Model.FindCaptionField;

  // RowClassProvider: JS function that returns a CSS class for each row
  LRowClassProvider := AViewTable.GetExpandedString('Controller/RowClassProvider');

  // Lookup mode: resolve AutoAddFields metadata of the calling reference field
  // so each row can carry the values to fan-out into the calling form.
  LAutoAddSourceFields := nil;
  LAutoAddAliases := nil;
  LIsLookup := SameText(TKWebRequest.Current.GetQueryField('mode'), 'lookup');
  if LIsLookup then
  begin
    LCallingViewName := TKWebRequest.Current.GetQueryField('cv');
    LCallingFieldName := TKWebRequest.Current.GetQueryField('cf');
    if (LCallingViewName <> '') and (LCallingFieldName <> '') then
    begin
      LCallingView := TKConfig.Instance.Views.FindView(LCallingViewName);
      if Assigned(LCallingView) and (LCallingView is TKDataView) then
      begin
        LCallingTable := TKDataView(LCallingView).MainTable;
        if Assigned(LCallingTable) then
        begin
          LCallingViewField := LCallingTable.FindField(LCallingFieldName);
          if Assigned(LCallingViewField) and Assigned(LCallingViewField.ModelField) then
          begin
            LAutoAddNode := LCallingViewField.ModelField.FindNode('AutoAddFields');
            if Assigned(LAutoAddNode) and (LAutoAddNode.ChildCount > 0) then
            begin
              SetLength(LAutoAddSourceFields, LAutoAddNode.ChildCount);
              SetLength(LAutoAddAliases, LAutoAddNode.ChildCount);
              for J := 0 to LAutoAddNode.ChildCount - 1 do
              begin
                LAutoAddSourceFields[J] := LAutoAddNode.Children[J].Name;
                LAutoAddAliases[J] := LAutoAddNode.Children[J].AsExpandedString;
              end;
            end;
          end;
        end;
      end;
    end;
  end;

  if AStore.RecordCount = 0 then
  begin
    // Count visible columns for colspan
    J := 0;
    for I := 0 to LColCount - 1 do
      if GetCellField(I, LField, LLayoutNode) then
        Inc(J);
    Result := '<tr class="kx-list-empty"><td colspan="' + IntToStr(J) + '">' +
      TNetEncoding.HTML.Encode(_('No records found.')) + '</td></tr>';
    Exit;
  end;

  SB := TStringBuilder.Create;
  SBKey := TStringBuilder.Create;
  try
    for I := 0 to AStore.RecordCount - 1 do
    begin
      LRecord := AStore.Records[I];

      // Skip deleted records (in-memory detail stores may contain rsDeleted records
      // that haven't been persisted yet — they should not be rendered in the grid)
      if LRecord.State = rsDeleted then
        Continue;

      // A pending detail row with a database-generated key has no key yet:
      // give it a temporary one, or every such row would share the empty key
      // and opening/saving/deleting any of them would reach the first one.
      LRecord.EnsureTemporaryKey;

      // Build URL-encoded key string for row selection (field=value&field2=value2)
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

      // Extract caption value for data-caption attribute
      LCaptionValue := '';
      if Assigned(LCaptionField) then
      begin
        LRecordField := LRecord.FindField(LCaptionField.FieldName);
        if Assigned(LRecordField) and not LRecordField.IsNull then
          LCaptionValue := LRecordField.AsString;
      end;

      SB.Append('<tr data-key="').Append(SBKey.ToString).Append('"');
      SB.Append(' data-caption="').Append(TNetEncoding.HTML.Encode(LCaptionValue)).Append('"');

      // AutoAddFields: emit JSON {alias: value} from the referenced model record
      // so onLookupSelect can fan-out the values into the calling form.
      if Length(LAutoAddSourceFields) > 0 then
      begin
        SBAutoAdd := TStringBuilder.Create;
        try
          SBAutoAdd.Append('{');
          for J := 0 to High(LAutoAddSourceFields) do
          begin
            LAutoAddSrcField := AViewTable.FindField(LAutoAddSourceFields[J]);
            if not Assigned(LAutoAddSrcField) then
              Continue;
            LRecordField := LRecord.FindField(LAutoAddSrcField.AliasedName);
            if not Assigned(LRecordField) then
              Continue;
            if SBAutoAdd.Length > 1 then
              SBAutoAdd.Append(',');
            SBAutoAdd.Append('"').Append(LAutoAddAliases[J]).Append('":');
            if LRecordField.IsNull then
              SBAutoAdd.Append('null')
            else if LAutoAddSrcField.DataType is TEFBooleanDataType then
              SBAutoAdd.Append(IfThen(LRecordField.AsBoolean, 'true', 'false'))
            else if LAutoAddSrcField.DataType is TEFNumericDataTypeBase then
              SBAutoAdd.Append(LRecordField.GetAsJSONValue(False, False))
            else
              SBAutoAdd.Append(QuoteJSONValue(LRecordField.AsString));
          end;
          SBAutoAdd.Append('}');
          SB.Append(' data-autoadd="').Append(TNetEncoding.HTML.Encode(SBAutoAdd.ToString)).Append('"');
        finally
          SBAutoAdd.Free;
        end;
      end;

      // RowClassProvider: emit field values as JSON for client-side class computation
      if LRowClassProvider <> '' then
      begin
        SBFields := TStringBuilder.Create;
        try
          SBFields.Append('{');
          for J := 0 to AViewTable.FieldCount - 1 do
          begin
            LField := AViewTable.Fields[J];
            if LField.IsBlob and not (LField.DataType is TEFMemoDataType) then
              Continue;
            LRecordField := LRecord.FindField(LField.AliasedName);
            if not Assigned(LRecordField) then
              Continue;
            if SBFields.Length > 1 then
              SBFields.Append(',');
            SBFields.Append('"').Append(LField.AliasedName).Append('":');
            if LRecordField.IsNull then
              SBFields.Append('null')
            else if LField.DataType is TEFBooleanDataType then
              SBFields.Append(IfThen(LRecordField.AsBoolean, 'true', 'false'))
            else if LField.DataType is TEFNumericDataTypeBase then
              SBFields.Append(LRecordField.GetAsJSONValue(False, False))
            else
              SBFields.Append(QuoteJSONValue(LRecordField.AsString));
          end;
          SBFields.Append('}');
          SB.Append(' data-fields="').Append(TNetEncoding.HTML.Encode(SBFields.ToString)).Append('"');
        finally
          SBFields.Free;
        end;
      end;

      SB.Append(' onclick="kxGrid.select(this,''').Append(AViewName).Append(''')"');
      SB.Append(' ondblclick="kxGrid.rowDblClick(this,''').Append(AViewName).Append(''')">');

      for J := 0 to LColCount - 1 do
      begin
        if not GetCellField(J, LField, LLayoutNode) then
          Continue;

        // Align override from layout
        if Assigned(LLayoutNode) and (LLayoutNode.GetString('Align') <> '') then
          LAlign := LLayoutNode.GetString('Align')
        else
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
            // HTMLMemo fields contain HTML markup: no tooltip (raw tags would show).
            if (LValue <> '') and not (LField.DataType is TKHTMLMemoDataType) then
              SB.Append(' data-full="').Append(TNetEncoding.HTML.Encode(LValue)).Append('"');
            SB.Append('>');
            // HTMLMemo fields contain trusted HTML content — render without encoding
            if LField.DataType is TKHTMLMemoDataType then
              SB.Append(LValue)
            else
              SB.Append(TNetEncoding.HTML.Encode(LValue));
            SB.Append('</td>');
          end;
        end
        else
          SB.Append('<td></td>');
      end;
      SB.Append('</tr>');
    end;
    // If all records were skipped (e.g. all rsDeleted), show empty message
    if SB.Length = 0 then
    begin
      J := 0;
      for I := 0 to LColCount - 1 do
        if GetCellField(I, LField, LLayoutNode) then
          Inc(J);
      SB.Append('<tr class="kx-list-empty"><td colspan="').Append(IntToStr(J)).Append('">');
      SB.Append(TNetEncoding.HTML.Encode(_('No records found.')));
      SB.Append('</td></tr>');
    end;
    Result := SB.ToString;
  finally
    SBKey.Free;
    SB.Free;
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('GridPanel', TKXGridPanelController);

end.
