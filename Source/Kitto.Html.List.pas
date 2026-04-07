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
///  KittoX List controller — renders a data grid with server-side pagination,
///  column sorting, and FreeSearch filtering using HTMX.
///  Replaces TKExtGridPanel from Kitto.Ext.GridPanel.
/// </summary>
unit Kitto.Html.List;

{$I Kitto.Defines.inc}

interface

uses
  System.Types,
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Html.DataPanel,
  Kitto.Html.Controller,
  Kitto.Html.Filters,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView;

const
  DEFAULT_PAGE_RECORD_COUNT = 20;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXListPanelController = class(TKXDataPanelController)
  strict protected
    /// <summary>
    ///  Builds the collapsible filter panel above the grid.
    ///  AUrlViewName: when non-empty, used for hx-get URL paths (AViewName for IDs).
    /// </summary>
    function BuildFilterPanel(const AViewName: string;
      AViewTable: TKViewTable; out ADefaultFilterExpr: string;
      const AUrlViewName: string = ''): string;
    /// <summary>
    ///  Builds the CRUD toolbar (Add, Dup, Edit, Delete, View buttons).
    ///  In lookup mode, shows Select/Cancel instead.
    ///  AUrlViewName: when non-empty, used for URL paths (AViewName for IDs).
    /// </summary>
    function BuildToolbar(const AViewName: string;
      const AUrlViewName: string = ''): string;
    function GetPanelCssClass: string; override;
    function RenderContent: string; override;
  public
    class function BuildDataRows(AStore: TKViewTableStore;
      AViewTable: TKViewTable; const AViewName: string;
      const AUrlViewName: string = '';
      ALayout: TKLayout = nil): string;

    class function BuildColumnHeaders(AViewTable: TKViewTable;
      const AViewName, ACurrentSort, ACurrentDir: string;
      const AUrlViewName: string = '';
      ALayout: TKLayout = nil): string;

    class function BuildPager(const AViewName: string;
      ATotal, AStart, ALimit: Integer;
      const AUrlViewName: string = ''): string;

    class function BuildHiddenState(const AViewName: string;
      ALimit: Integer; const ASort, ADir: string;
      const AUrlViewName: string = ''): string;
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
  Kitto.Html.TemplateDataPanel,
  EF.JSON;

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


{ TKXListPanelController }

function TKXListPanelController.GetPanelCssClass: string;
begin
  Result := 'kx-list-panel';
end;

function TKXListPanelController.RenderContent: string;
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
  LTemplateFile: string;
  LSortExpr: string;
  LSortFieldNames: TStringDynArray;
  LInitialSort: string;
  LPagingTools: Boolean;
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

  // PagingTools: opt-in paging (default false)
  LPagingTools := LViewTable.GetBoolean('Controller/PagingTools');

  // Check for TemplateFileName (directly or via legacy CenterController)
  LTemplateFile := Config.GetString('TemplateFileName',
    Config.GetString('CenterController/TemplateFileName'));
  if LTemplateFile <> '' then
  begin

    // Build filter panel (if Filters/Items defined)
    LFilterPanelHtml := BuildFilterPanel(LViewAlias, LViewTable,
      LDefaultFilterExpr, LUrlViewName);

    // Build sort expression from MainTable/Controller/SortFieldNames
    LSortExpr := '';
    begin
      LSortFieldNames := LViewTable.GetStringArray('Controller/SortFieldNames');
      if Length(LSortFieldNames) > 0 then
      begin
        var J: Integer;
        for J := Low(LSortFieldNames) to High(LSortFieldNames) do
          LSortFieldNames[J] := LViewTable.FieldByName(LSortFieldNames[J]).QualifiedDBNameOrExpression;
        LSortExpr := string.Join(', ', LSortFieldNames);
      end;
    end;

    // Paging: only when PagingTools is enabled
    if LPagingTools then
      LPageSize := LViewTable.GetInteger('Controller/PagingTools/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT)
    else
      LPageSize := 0;

    LStore := LViewTable.CreateStore;
    try
      LTotal := LStore.Load(LDefaultFilterExpr, LSortExpr, 0, LPageSize);

      SB := TStringBuilder.Create;
      try
        // Filter panel
        SB.Append(LFilterPanelHtml);

        // Toolbar (CRUD buttons)
        SB.Append(BuildToolbar(LViewAlias, LUrlViewName));

        // Card container (replaces grid table)
        SB.Append('<div class="kx-template-content" id="kx-list-body-')
          .Append(LViewAlias).Append('"');
        if IsActionVisible('Edit') and IsActionAllowed('Edit') then
          SB.Append(' data-dblclick="edit"')
        else if IsActionVisible('View') then
          SB.Append(' data-dblclick="view"');
        SB.Append('>');
        SB.Append(TKXTemplateDataPanelController.BuildSelectableCards(
          LStore, LViewTable, Config, LViewAlias));
        SB.Append('</div>');

        // Pager (only when PagingTools is enabled)
        if LPagingTools then
          SB.Append(BuildPager(LViewAlias, LTotal, 0, LPageSize, LUrlViewName));

        // Hidden state
        SB.Append(BuildHiddenState(LViewAlias, LPageSize, '', '', LUrlViewName));

        Result := SB.ToString;
      finally
        SB.Free;
      end;
    finally
      FreeAndNil(LStore);
    end;
    Exit;
  end;

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

  // Build filter panel (if Filters/Items defined)
  LFilterPanelHtml := BuildFilterPanel(LViewAlias, LViewTable,
    LDefaultFilterExpr, LUrlViewName);

  // Load first page of data (with default filter and sort expression)
  LStore := LViewTable.CreateStore;
  try
    LTotal := LStore.Load(LDefaultFilterExpr, LSortExpr, 0, LPageSize);

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
      if IsActionVisible('Edit') and IsActionAllowed('Edit') then
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

function TKXListPanelController.BuildFilterPanel(const AViewName: string;
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
        SBCol.Append('<div class="kx-filter-row" style="visibility:hidden">&nbsp;</div>');
        Continue;
      end
      // --- ApplyButton: handled separately after the loop ---
      else if SameText(LFilterType, 'ApplyButton') then
        Continue;

      // Open filter row
      SBCol.Append('<div class="kx-filter-row">');
      SBCol.Append('<label class="kx-filter-label" style="min-width:');
      SBCol.Append(IntToStr(LCurrentLabelWidth));
      SBCol.Append('px">');
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
        if not LHasApplyButton then
          LCtx.ExtraAttrs := LHxAttrs + 'hx-trigger="input changed delay:300ms, search"'
        else
          LCtx.ExtraAttrs := '';
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
          LDBConnection := TKConfig.Instance.CreateDBConnection(
            LNode.GetString('DatabaseName', AViewTable.DatabaseName));
          try
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
          finally
            FreeAndNil(LDBConnection);
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
        LCtx.TriggerWidthStyle := '';
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
        LCtx.TriggerWidthStyle := '';
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
        LCtx.TriggerWidthStyle := '';
        if not LHasApplyButton then
          LCtx.ExtraAttrs := LHxAttrs + 'hx-trigger="change"'
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
          LCtx.ExtraAttrs := LHxAttrs + 'hx-trigger="change"'
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
          LCtx.ExtraAttrs := LHxAttrs + 'hx-trigger="change"'
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
      SBCol.Append('</div>');
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

function TKXListPanelController.BuildToolbar(const AViewName: string;
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
    if ARequiresSelection then
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

    // Help button (visible only if Defaults/Help/HRef is configured)
    var LShowHelp: Boolean;
    var LHelpHRef, LHelpHRefStyle, LHelpShort, LHelpLong: string;
    TKConfig.Instance.GetHelpSupport(LShowHelp, LHelpHRef, LHelpHRefStyle, LHelpShort, LHelpLong);
    if LShowHelp and Assigned(View) then
    begin
      var LHelpUrl := Format(LHelpHRef, [View.PersistentName]);
      LHelpLong := Format(LHelpLong, [LDisplayLabel]);
      SB.Append('<button class="kx-toolbar-btn"');
      SB.Append(' title="').Append(TNetEncoding.HTML.Encode(LHelpLong)).Append('"');
      SB.Append(' onclick="window.open(''').Append(TNetEncoding.HTML.Encode(LHelpUrl)).Append(''',''_blank'')"');
      SB.Append('>').Append(GetIconHTML('help'));
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

class function TKXListPanelController.BuildColumnHeaders(
  AViewTable: TKViewTable; const AViewName, ACurrentSort, ACurrentDir: string;
  const AUrlViewName: string; ALayout: TKLayout): string;
var
  I, LCount: Integer;
  LField: TKViewField;
  LLayoutNode: TEFNode;
  LLabel: string;
  LAlign: string;
  LWidthStyle: string;
  LDisplayWidth: Integer;
  LSortable: Boolean;
  LSortClass: string;
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
      Result := True;
    end;
  end;

begin
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

      // Determine initial sort CSS class (arrows rendered via CSS ::after)
      LSortClass := '';
      if SameText(ACurrentSort, LFieldName) then
      begin
        if SameText(ACurrentDir, 'asc') then
          LSortClass := ' kx-sort-asc'
        else if SameText(ACurrentDir, 'desc') then
          LSortClass := ' kx-sort-desc';
      end;

      if LSortable then
      begin
        SB.Append('<th class="kx-col-sortable').Append(LSortClass).Append('" ');
        SB.Append('data-field="').Append(LFieldName).Append('" ');
        SB.Append('style="text-align:').Append(LAlign).Append(';').Append(LWidthStyle).Append('" ');
        SB.Append('hx-get="kx/view/').Append(LUrlName).Append('/data" ');
        SB.Append('hx-target="#kx-list-body-').Append(AViewName).Append('" ');
        SB.Append('hx-include="').Append(LInc).Append('" ');
        SB.Append('onclick="kxGrid.prepareSort(this,''').Append(AViewName).Append(''')" ');
        SB.Append('>');
        SB.Append(TNetEncoding.HTML.Encode(LLabel));
        SB.Append('</th>');
      end
      else
      begin
        SB.Append('<th style="text-align:').Append(LAlign).Append(';').Append(LWidthStyle).Append('">');
        SB.Append(TNetEncoding.HTML.Encode(LLabel)).Append('</th>');
      end;
    end;
    SB.Append('</tr></thead>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TKXListPanelController.BuildDataRows(
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
  SB, SBKey, SBFields: TStringBuilder;

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
            SB.Append('<td style="text-align:').Append(LAlign).Append('">');
            SB.Append(TNetEncoding.HTML.Encode(LValue)).Append('</td>');
          end
          else if LIsCurrency then
          begin
            LValue := LField.DataType.NodeToJSONValue(True, LRecordField, LUserFmt, False);
            if SameText(LValue, 'null') then
              LValue := '';
            SB.Append('<td style="text-align:right">');
            if (LValue <> '') and (LCurrSymbol <> '') then
              SB.Append(TNetEncoding.HTML.Encode(LCurrSymbol + ' ' + LValue))
            else
              SB.Append(TNetEncoding.HTML.Encode(LValue));
            SB.Append('</td>');
          end
          else
          begin
            LValue := LRecordField.GetAsJSONValue(True, False);
            if SameText(LValue, 'null') then
              LValue := '';
            SB.Append('<td style="text-align:').Append(LAlign).Append('">');
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

class function TKXListPanelController.BuildPager(const AViewName: string;
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

  procedure AppendPagerButton(const ALabel: string; ATargetStart: Integer;
    ADisabled: Boolean);
  begin
    if ADisabled then
      SB.Append('<button disabled>').Append(ALabel).Append('</button>')
    else
    begin
      SB.Append('<button hx-get="kx/view/').Append(LUrlName).Append('/data" ');
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
    AppendPagerButton(GetIconHTML('first_page'), 0, LCurrentPage <= 1);
    AppendPagerButton(GetIconHTML('chevron_left'), LPrevStart, LCurrentPage <= 1);
    AppendPagerButton(GetIconHTML('chevron_right'), LNextStart, LCurrentPage >= LTotalPages);
    AppendPagerButton(GetIconHTML('last_page'), LLastStart, LCurrentPage >= LTotalPages);
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

class function TKXListPanelController.BuildHiddenState(const AViewName: string;
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
  Result := Result + '</div>';
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('List', TKXListPanelController);

end.
