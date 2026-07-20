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
///   Attribute-based handler for the "view core" data endpoints (Sprint E.2 of
///   the routing refactor). Migrated incrementally, one endpoint per commit,
///   from TKWebApplication.DoHandleRequest. Endpoints not yet migrated still
///   fall through to the legacy dispatch (the attribute router runs first).
///
///   TKXViewHandlerBase is virtual so an application can subclass it and
///   override an endpoint (or, once introduced, a hook) without forking the
///   framework. Shared logic lives in TKWebApplication as public helpers
///   (FindViewOrSetNotFound, PopulateRecordFromPost, …), reached via
///   TKWebApplication.Current.
///
///   Migrated (E.2): view (bare), data, form, save, save-cache, delete,
///   enter-edit, form-close.
///   Migrated (E.3): lookup, wizard-finish, detail data/save/delete, tool,
///   temp-upload, notify-change, blob. All view-domain endpoints now live here.
/// </summary>
unit Kitto.Web.Handler.View;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Store,
  Kitto.Metadata.DataView,
  Kitto.Web.Routing.Attributes;

type
  {$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}
  [TKXPath('/kx/view/{ViewName}')]
  TKXViewHandlerBase = class
  protected
    /// CRUD extension hooks (empty by default). Override in a subclass to add
    /// validation, audit or side effects around persistence without forking the
    /// framework. AIsInsert distinguishes add/dup (True) from edit (False).
    procedure OnBeforeSave(const ARecord: TKViewTableRecord; const AIsInsert: Boolean); virtual;
    procedure OnAfterSave(const ARecord: TKViewTableRecord; const AIsInsert: Boolean); virtual;
    procedure OnBeforeDelete(const ARecord: TKViewTableRecord); virtual;
    procedure OnAfterDelete(const ARecord: TKViewTableRecord); virtual;
    /// Record OnFieldChange callback used by HandleNotifyChange. Enumerates the
    /// changed field's ViewField rules and invokes AfterFieldChange. Mirrors
    /// Kitto1's TKExtFormPanelController.FieldChange. Protected (no RTTI) so it
    /// is never treated as a route, but remains overridable by a subclass.
    procedure NotifyFieldChangeHandler(const AField: TKField;
      const AOldValue, ANewValue: Variant); virtual;
  public
    /// Apply EditRecordRules on the session record (ViewMode -> EditMode).
    [TKXPath('/enter-edit')] [TKXPOST]
    procedure HandleEnterEdit([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// Release the session store when a form is cancelled/closed without saving.
    [TKXPath('/form-close')] [TKXPOST]
    procedure HandleFormClose([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// Render a view as an HTML fragment (bare /kx/view/{ViewName}). Falls back
    /// to treating {ViewName} as a controller class id (inline views), else 404.
    [TKXANY]
    procedure HandleView([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// List/grid data: rows + OOB pager/state. Handles GroupingList,
    /// TemplateDataPanel, selectable cards and the standard paged grid.
    /// TKXANY: the grid uses hx-get for filter/sort/pager and POST for the
    /// toolbar Refresh (kxGrid.refreshData), so /data must accept both methods.
    [TKXPath('/data')] [TKXANY]
    procedure HandleData([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// Delete a record (by key), then return refreshed rows (+ OOB pager/state).
    [TKXPath('/delete')] [TKXPOST]
    procedure HandleDelete([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// Open the form dialog (op=new/add/edit/view/dup); registers the session store.
    [TKXPath('/form')] [TKXGET]
    procedure HandleForm([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// Persist the record to the DB (with cascading detail stores).
    [TKXPath('/save')] [TKXPOST]
    procedure HandleSave([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// Write posted values back to the session store only (no DB persist).
    [TKXPath('/save-cache')] [TKXPOST]
    procedure HandleSaveCache([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// Render a view as a modal lookup dialog (aliased id + kxForm.closeLookup).
    [TKXPath('/lookup')] [TKXGET]
    procedure HandleLookup([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// Commit a brand-new record built by a wizard, running Controller/Rules
    /// before/after the save; returns a script closing the wizard on success.
    [TKXPath('/wizard-finish')] [TKXPOST]
    procedure HandleWizardFinish([TKXPathParam('ViewName')] const AViewName: string); virtual;
    /// Render a detail grid (toolbar + headers + rows). GET for the initial
    /// loadDetailTab fetch, POST for HX column-sort/pager refreshes — hence ANY.
    [TKXPath('/detail/{Index}/data')] [TKXANY]
    procedure HandleDetailData([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('Index')] const AIndex: Integer); virtual;
    /// Add/edit a detail record in the master's in-memory detail store (no DB
    /// persist until the master is saved). Returns a script reloading the tab.
    [TKXPath('/detail/{Index}/save')] [TKXPOST]
    procedure HandleDetailSave([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('Index')] const AIndex: Integer); virtual;
    /// Mark a detail record deleted (or clean if new) in the in-memory store.
    [TKXPath('/detail/{Index}/delete')] [TKXPOST]
    procedure HandleDetailDelete([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('Index')] const AIndex: Integer); virtual;
    /// Execute a tool view (Controller/ToolViews or EditController/ToolViews).
    /// The tool controller writes its own response (download stream or HTML).
    [TKXPath('/tool/{ToolName}')] [TKXPOST]
    procedure HandleTool([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('ToolName')] const AToolName: string); virtual;
    /// Store an uploaded file in a per-session temp dir before the form is
    /// saved; returns JSON {"ok":true,"temp":"<name>"}.
    [TKXPath('/upload/{FieldName}')] [TKXPOST]
    procedure HandleTempUpload([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('FieldName')] const AFieldName: string); virtual;
    /// Apply a single changed field to the session record (no save), letting
    /// AfterFieldChange rules fire, then return JSON of the fields that changed
    /// as a side effect.
    [TKXPath('/notify/{FieldName}')] [TKXPOST]
    procedure HandleNotifyChange([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('FieldName')] const AFieldName: string); virtual;
    /// Serve a BLOB/image or FileReference field as binary (inline or download).
    /// [TKXNavigable]: reachable by a top-level navigation — the client opens
    /// downloads via window.open and renders previews via <img>/<iframe> src,
    /// neither of which can send the X-KittoX header.
    [TKXPath('/blob/{FieldName}')] [TKXGET] [TKXNavigable]
    procedure HandleBlob([TKXPathParam('ViewName')] const AViewName: string;
      [TKXPathParam('FieldName')] const AFieldName: string); virtual;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.NetEncoding,
  System.Types,
  System.Math,
  System.Variants,
  System.IOUtils,
  System.Generics.Collections,
  Web.HTTPApp,
  EF.Tree,
  EF.Logger,
  EF.Sys,
  EF.StrUtils,
  EF.JSON,
  EF.Localization,
  Kitto.Rules,
  Kitto.AccessControl,
  Kitto.Metadata.Views,
  Kitto.Metadata.Models,
  Kitto.Web.Request,
  Kitto.Web.Session,
  Kitto.Web.Response,
  Kitto.Html.Response,
  Kitto.Html.Base,
  Kitto.Html.Utils,
  Kitto.Html.Controller,
  Kitto.Html.Panel,
  Kitto.Html.Form,
  Kitto.Html.Wizard,
  Kitto.Rules.Wizard,
  Kitto.Html.List,
  Kitto.Html.GroupingList,
  Kitto.Html.TemplateDataPanel,
  Kitto.Html.Filters,
  Kitto.Web.Application,
  Kitto.Web.Routing.Registry;

{ TKXViewHandlerBase }

procedure TKXViewHandlerBase.OnBeforeSave(const ARecord: TKViewTableRecord;
  const AIsInsert: Boolean);
begin
end;

procedure TKXViewHandlerBase.OnAfterSave(const ARecord: TKViewTableRecord;
  const AIsInsert: Boolean);
begin
end;

procedure TKXViewHandlerBase.OnBeforeDelete(const ARecord: TKViewTableRecord);
begin
end;

procedure TKXViewHandlerBase.OnAfterDelete(const ARecord: TKViewTableRecord);
begin
end;

procedure TKXViewHandlerBase.HandleEnterEdit(const AViewName: string);
begin
  // Apply edit-record rules when transitioning from ViewMode to EditMode.
  // The client calls this before enabling the form fields.
  var LStore := TKWebSession.Current.FindStore(AViewName);
  if Assigned(LStore) and (LStore.RecordCount > 0) then
    LStore.Records[0].ApplyEditRecordRules;
  TKXWebResponse.Current.SendFragment('');
end;

procedure TKXViewHandlerBase.HandleFormClose(const AViewName: string);
begin
  // Release session store when the form is cancelled/closed without saving.
  TKWebSession.Current.UnregisterStore(AViewName);
  TKXWebResponse.Current.SendFragment('');
end;

procedure TKXViewHandlerBase.HandleView(const AViewName: string);
var
  LApp: TKWebApplication;
  LView: TKView;
  LController: IKXController;
  LObject: TKXComponent;
  LHtml: string;
  LControllerNode, LCenterNode: TEFNode;
  LControllerType: string;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LFormController: TKXFormPanelController;
  LOperation, LDefaultFilter: string;

  procedure AdjustForContext;
  begin
    LApp.AdjustControllerForContext(LController);
  end;

begin
  LApp := TKWebApplication.Current;
  // Note: do NOT use FindViewOrSetNotFound here — when the YAML lookup fails this
  // handler has a fallback path (treat AViewName as a controller class id, used
  // by inline views like "Controller: Logout" in tree menus); a premature 404
  // must not stick to a successful fallback.
  LView := LApp.Config.Views.FindView(AViewName);
  if Assigned(LView) then
  begin
    if not LApp.IsViewAccessGranted(LView, ACM_VIEW) then
      Exit;
    try
      // CenterController interception (e.g. Controller: List / CenterController:
      // ChartPanel), only when CenterController specifies a controller type.
      LCenterNode := nil;
      LControllerNode := LView.FindNode('Controller');
      if Assigned(LControllerNode) then
      begin
        LCenterNode := LControllerNode.FindNode('CenterController');
        if Assigned(LCenterNode) and (LCenterNode.AsString = '') then
          LCenterNode := nil; // Config-only node, not a controller type
      end;

      // Standalone Form controller: load record via DefaultFilter/FilterExpression.
      LControllerType := '';
      if Assigned(LControllerNode) then
        LControllerType := LControllerNode.AsString;
      if SameText(LControllerType, 'Form') and (LView is TKDataView) then
      begin
        LDataView := TKDataView(LView);
        LViewTable := LDataView.MainTable;
        LOperation := LView.GetExpandedString('Controller/Operation', 'edit');
        LController := TKXControllerFactory.Instance.CreateController(LView);
        if LController is TKXFormPanelController then
        begin
          LFormController := TKXFormPanelController(LController);
          if MatchText(LOperation, ['edit', 'view']) then
          begin
            LStore := LViewTable.CreateStore;
            LDefaultFilter := LView.GetExpandedString('Controller/FilterExpression');
            if LDefaultFilter = '' then
              LDefaultFilter := LViewTable.DefaultFilter;
            LStore.Load(LDefaultFilter, '', 0, 0);
            if LStore.RecordCount >= 1 then
            begin
              LFormController.FormRecord := LStore.Records[0];
              // Master-detail transactional save: init detail stores.
              if (LViewTable.DetailTableCount > 0) and MatchText(LOperation, ['edit', 'view']) then
              begin
                LStore.Records[0].EnsureDetailStores;
                LStore.Records[0].LoadDetailStores;
              end;
              // Register store for subsequent blob/save/detail requests.
              TKWebSession.Current.RegisterStore(AViewName, LStore);
            end;
          end;
          LFormController.Operation := LOperation;
          LFormController.Config.SetString('Operation', LOperation);
          LController.Display;
          AdjustForContext;
          LHtml := LController.Render;
        end
        else
        begin
          LController.Display;
          AdjustForContext;
          LHtml := LController.Render;
        end;
      end
      else if Assigned(LCenterNode) then
      begin
        LController := TKXControllerFactory.Instance.CreateController(LView, nil, LCenterNode);
        LController.Display;
        AdjustForContext;
        LHtml := LController.Render;
      end
      else
      begin
        LController := TKXControllerFactory.Instance.CreateController(LView);
        LController.Display;
        AdjustForContext;
        LHtml := LController.Render;
      end;

      // Wizard modal: replace generic dialog id/close with wizard-specific ones.
      if (LController.AsObject is TKXWizardController) and
        (LController.AsObject as TKXPanelControllerBase).IsModal then
      begin
        LHtml := ReplaceStr(LHtml,
          'id="kx-' + AViewName + '"',
          'id="kx-form-overlay-' + AViewName + '"');
        LHtml := ReplaceStr(LHtml,
          'onclick="this.closest(''.kx-dialog-overlay'').remove();"',
          'onclick="kxWizard.cancel(''' + AViewName + ''');"');
      end;
    except
      on E: Exception do
        LHtml := Format(
          '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
            '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
              '<div class="kx-msgbox-header kx-msgbox-error">' +
                '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
                '<span>%s</span>' +
              '</div>' +
              '<div class="kx-msgbox-body">%s</div>' +
              '<div class="kx-msgbox-footer">' +
                '<button onclick="this.closest(''.kx-msgbox-overlay'').remove()">OK</button>' +
              '</div>' +
            '</div>' +
          '</div>',
          [TNetEncoding.HTML.Encode(AViewName),
           TNetEncoding.HTML.Encode(E.Message)]);
    end;
    TKXWebResponse.Current.SendFragment(LHtml);
  end
  else
  begin
    // No named view found. Treat AViewName as a controller type
    // (used by inline views like "Controller: Logout" in tree menus).
    try
      LObject := TKXControllerRegistry.Instance.GetClass(AViewName).Create;
    except
      // Neither YAML view nor registered controller class — genuine 404.
      if Assigned(TKWebResponse.Current) then
        TKWebResponse.Current.StatusCode := 404;
      TEFLogger.Instance.LogFmt('View not found: "%s"', [AViewName],
        TEFLogger.LOG_DETAILED);
      Exit;
    end;
    try
      if Supports(LObject, IKXController, LController) then
      begin
        LObject := nil; // Interface owns the object now; prevent double-free in except
        LController.Display;
        LHtml := LController.Render;
        TKXWebResponse.Current.SendFragment(LHtml);
      end
      else
        FreeAndNil(LObject);
    except
      FreeAndNil(LObject);
      raise;
    end;
  end;
end;

procedure TKXViewHandlerBase.HandleData(const AViewName: string);
var
  LApp: TKWebApplication;
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LTotal: Integer;
  LStart, LLimit: Integer;
  LSort, LDir: string;
  LFilterExpr, LSortExpr: string;
  LFilterItemsNode: TEFNode;
  LFilterConnector: string;
  LControllerNode: TEFNode;
  LViewField: TKViewField;
  LHtml: string;
  LViewAlias: string;
  LUrlViewName: string;
  LIsGroupingList: Boolean;
  LPagingTools: Boolean;
  LGroupingFieldName: string;
  LGroupingNode: TEFNode;
  LSortFieldNames: TStringDynArray;
  I: Integer;
begin
  LApp := TKWebApplication.Current;
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then
    Exit;
  if not LApp.IsViewAccessGranted(LView, ACM_VIEW) then
    Exit;
  if not LApp.RequireDataView(LView) then Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // Detect GroupingList or TemplateDataPanel controller
  LIsGroupingList := SameText(LView.GetString('Controller'), 'GroupingList');

  // IsLarge drives the default: PagingTools = IsLarge.
  LPagingTools := LViewTable.GetBoolean('Controller/PagingTools', LViewTable.IsLarge);

  // Read viewAlias from hidden state (set by lookup mode)
  LViewAlias := TKWebRequest.Current.GetField('viewAlias');
  if LViewAlias <> '' then
    LUrlViewName := AViewName   // use real view name for URLs
  else
  begin
    LViewAlias := AViewName;    // no alias: use AViewName for both
    LUrlViewName := '';
  end;

  // Read query parameters
  LStart := StrToIntDef(TKWebRequest.Current.GetField('start'), 0);
  if LPagingTools then
    LLimit := StrToIntDef(TKWebRequest.Current.GetField('limit'),
      LViewTable.GetInteger('Controller/PagingTools/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT))
  else
    LLimit := 0;
  LSort := TKWebRequest.Current.GetField('sort');
  LDir := TKWebRequest.Current.GetField('dir');

  // Build filter expression from all active filters
  LFilterExpr := '';
  LControllerNode := LView.FindNode('Controller');
  if Assigned(LControllerNode) then
  begin
    LFilterItemsNode := LControllerNode.FindNode('Filters/Items');
    if Assigned(LFilterItemsNode) then
    begin
      LFilterConnector := LControllerNode.GetString('Filters/Connector', 'and');
      LFilterExpr := BuildFilterExpression(
        LFilterItemsNode, LFilterConnector,
        function(AIndex: Integer): string
        begin
          Result := TKWebRequest.Current.GetField('f_' + IntToStr(AIndex));
        end);
    end;
  end;

  // Lookup mode: also apply the calling reference field's LookupFilter, so a
  // dedicated IsLookup grid honors the same restriction as the inline combo
  // (e.g. {MasterRecord.PaganteId}). Persisted via cv/cf in the hidden state.
  begin
    var LLookupCtxFilter := TKXListPanelController.GetLookupContextFilter;
    if LLookupCtxFilter <> '' then
    begin
      if LFilterExpr = '' then
        LFilterExpr := LLookupCtxFilter
      else
        LFilterExpr := '(' + LFilterExpr + ') and (' + LLookupCtxFilter + ')';
    end;
  end;

  // GroupingList: override sort and paging
  if LIsGroupingList then
  begin
    LGroupingNode := LViewTable.FindNode('Controller/Grouping');
    LGroupingFieldName := '';
    if Assigned(LGroupingNode) then
      LGroupingFieldName := LGroupingNode.GetExpandedString('FieldName');

    // Build sort from SortFieldNames or grouping field
    LSortExpr := '';
    LSortFieldNames := LViewTable.GetStringArray('Controller/Grouping/SortFieldNames');
    if Length(LSortFieldNames) > 0 then
    begin
      for I := Low(LSortFieldNames) to High(LSortFieldNames) do
        LSortFieldNames[I] := LViewTable.FieldByName(LSortFieldNames[I]).QualifiedDBNameOrExpression;
      LSortExpr := Join(LSortFieldNames, ', ');
    end
    else if LGroupingFieldName <> '' then
    begin
      LViewField := LViewTable.FindField(LGroupingFieldName);
      if Assigned(LViewField) then
        LSortExpr := LViewField.QualifiedDBNameOrExpression;
    end;

    // Load ALL records (no paging)
    LStore := LViewTable.CreateStore;
    try
      LStore.Load(LFilterExpr, LSortExpr, 0, 0);

      // Build grouped rows only (no pager OOB)
      LHtml := TKXGroupingListController.BuildGroupedRows(
        LStore, LViewTable, LViewAlias, LGroupingFieldName,
        LGroupingNode, LUrlViewName) +
        // OOB: hidden state (update filter state, no paging)
        TKXListPanelController.BuildHiddenState(LViewAlias, 0, '', '', LUrlViewName);

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + LViewAlias + '"',
        'id="kx-list-state-' + LViewAlias + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
    finally
      FreeAndNil(LStore);
    end;
  end
  else if SameText(LView.GetString('Controller'), 'TemplateDataPanel') then
  begin
    // TemplateDataPanel: re-render template with all records (no paging)
    LSortExpr := '';
    begin
      var LTplSortFieldNames := LViewTable.GetStringArray('Controller/SortFieldNames');
      if Length(LTplSortFieldNames) > 0 then
      begin
        for I := Low(LTplSortFieldNames) to High(LTplSortFieldNames) do
          LTplSortFieldNames[I] := LViewTable.FieldByName(LTplSortFieldNames[I]).QualifiedDBNameOrExpression;
        LSortExpr := Join(LTplSortFieldNames, ', ');
      end;
    end;

    LStore := LViewTable.CreateStore;
    try
      LStore.Load(LFilterExpr, LSortExpr, 0, 0);

      LHtml := TKXTemplateDataPanelController.BuildTemplateContent(
        LStore, LViewTable, LView.FindNode('Controller'), LViewAlias) +
        // OOB: hidden state (update filter state, no paging)
        TKXListPanelController.BuildHiddenState(LViewAlias, 0, '', '', LUrlViewName);

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + LViewAlias + '"',
        'id="kx-list-state-' + LViewAlias + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
    finally
      FreeAndNil(LStore);
    end;
  end
  else if Assigned(LControllerNode) and
    (LControllerNode.GetString('TemplateFileName',
      LControllerNode.GetString('CenterController/TemplateFileName')) <> '') then
  begin
    // List + TemplateFileName — re-render selectable cards (paged if PageRecordCount defined)
    LSortExpr := '';
    begin
      var LCardSortFieldNames := LViewTable.GetStringArray('Controller/SortFieldNames');
      if Length(LCardSortFieldNames) > 0 then
      begin
        for I := Low(LCardSortFieldNames) to High(LCardSortFieldNames) do
          LCardSortFieldNames[I] := LViewTable.FieldByName(LCardSortFieldNames[I]).QualifiedDBNameOrExpression;
        LSortExpr := Join(LCardSortFieldNames, ', ');
      end;
    end;

    // Paging: only when PagingTools is enabled
    if LPagingTools then
    begin
      var LCardPageSize := LViewTable.GetInteger('Controller/PagingTools/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT);
      LStart := StrToIntDef(TKWebRequest.Current.GetField('start'), 0);
      LLimit := LCardPageSize;
    end
    else
    begin
      LStart := 0;
      LLimit := 0;
    end;

    LStore := LViewTable.CreateStore;
    try
      LTotal := LStore.Load(LFilterExpr, LSortExpr, LStart, LLimit);

      LHtml := TKXTemplateDataPanelController.BuildSelectableCards(
        LStore, LViewTable, LControllerNode,
        LViewAlias);

      // Pager OOB (only when PagingTools is enabled)
      if LPagingTools then
      begin
        LHtml := LHtml +
          TKXListPanelController.BuildPager(LViewAlias, LTotal, LStart, LLimit, LUrlViewName);
        LHtml := ReplaceStr(LHtml,
          'id="kx-list-pager-' + LViewAlias + '"',
          'id="kx-list-pager-' + LViewAlias + '" hx-swap-oob="true"');
      end;

      // OOB: hidden state
      LHtml := LHtml +
        TKXListPanelController.BuildHiddenState(LViewAlias, LLimit, '', '', LUrlViewName);

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + LViewAlias + '"',
        'id="kx-list-state-' + LViewAlias + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
    finally
      FreeAndNil(LStore);
    end;
  end
  else
  begin
    // Standard List controller: paged data with (possibly multi-column) sort
    LSortExpr := LApp.BuildSortExpression(LViewTable, LSort, LDir);

    // Load data
    LStore := LViewTable.CreateStore;
    try
      LTotal := LStore.Load(LFilterExpr, LSortExpr, LStart, LLimit);

      // Main target content: raw rows (swapped into tbody via hx-target),
      // plus OOB updates for pager and state.
      LHtml :=
        TKXListPanelController.BuildDataRows(LStore, LViewTable, LViewAlias, LUrlViewName,
          LViewTable.FindLayout('Grid'));

      // OOB: pager (only when PagingTools is enabled)
      if LPagingTools then
      begin
        LHtml := LHtml +
          TKXListPanelController.BuildPager(LViewAlias, LTotal, LStart, LLimit, LUrlViewName);
        LHtml := ReplaceStr(LHtml,
          'id="kx-list-pager-' + LViewAlias + '"',
          'id="kx-list-pager-' + LViewAlias + '" hx-swap-oob="true"');
      end;

      // OOB: hidden state (updates sort/dir)
      LHtml := LHtml +
        TKXListPanelController.BuildHiddenState(LViewAlias, LLimit, LSort, LDir, LUrlViewName);

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + LViewAlias + '"',
        'id="kx-list-state-' + LViewAlias + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
    finally
      FreeAndNil(LStore);
    end;
  end;
end;

procedure TKXViewHandlerBase.HandleDelete(const AViewName: string);
var
  LApp: TKWebApplication;
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LDeleteStore, LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LTotal: Integer;
  LStart, LLimit: Integer;
  LSort, LDir: string;
  LFilterExpr, LSortExpr, LKeyFilter: string;
  LFilterItemsNode: TEFNode;
  LFilterConnector: string;
  LControllerNode: TEFNode;
  LViewField: TKViewField;
  LKeyStr: string;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldName, LFieldValue: string;
  LHtml: string;
  LPagingTools: Boolean;
  I: Integer;
begin
  LApp := TKWebApplication.Current;
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then
    Exit;
  if not LApp.IsViewAccessGranted(LView, ACM_DELETE) then
    Exit;
  if not LApp.RequireDataView(LView) then Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // IsLarge drives the default: PagingTools = IsLarge.
  LPagingTools := LViewTable.GetBoolean('Controller/PagingTools', LViewTable.IsLarge);

  // Parse key from POST parameter (URL-encoded field=value pairs separated by &)
  LKeyStr := TKWebRequest.Current.GetField('key');
  if LKeyStr = '' then
    Exit;

  // Build SQL filter from key fields (validated against ViewTable)
  LKeyFilter := '';
  LKeyParts := LKeyStr.Split(['&']);
  for I := 0 to Length(LKeyParts) - 1 do
  begin
    LPair := LKeyParts[I].Split(['=']);
    if Length(LPair) = 2 then
    begin
      LFieldName := TNetEncoding.URL.Decode(LPair[0]);
      LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
      // Only accept key fields that exist in the ViewTable (prevents SQL injection)
      LViewField := LViewTable.FindField(LFieldName);
      if Assigned(LViewField) and LViewField.IsKey then
      begin
        if LKeyFilter <> '' then
          LKeyFilter := LKeyFilter + ' and ';
        LKeyFilter := LKeyFilter + LViewField.QualifiedDBNameOrExpression +
          ' = ''' + ReplaceStr(LFieldValue, '''', '''''') + '''';
      end;
    end;
  end;

  if LKeyFilter = '' then
    Exit;

  // Load the record to delete, mark as deleted, and save via Model
  LDeleteStore := LViewTable.CreateStore;
  try
    LDeleteStore.Load(LKeyFilter, '', 0, 1);
    if LDeleteStore.RecordCount > 0 then
    begin
      LRecord := LDeleteStore.Records[0];
      LRecord.MarkAsDeleted;
      OnBeforeDelete(LRecord);
      LViewTable.Model.SaveRecord(LRecord, True, nil);
      OnAfterDelete(LRecord);
    end;
  finally
    FreeAndNil(LDeleteStore);
  end;

  // Now return refreshed data (same logic as HandleData).
  LFilterExpr := '';
  LControllerNode := LView.FindNode('Controller');
  if Assigned(LControllerNode) then
  begin
    LFilterItemsNode := LControllerNode.FindNode('Filters/Items');
    if Assigned(LFilterItemsNode) then
    begin
      LFilterConnector := LControllerNode.GetString('Filters/Connector', 'and');
      LFilterExpr := BuildFilterExpression(
        LFilterItemsNode, LFilterConnector,
        function(AIndex: Integer): string
        begin
          Result := TKWebRequest.Current.GetField('f_' + IntToStr(AIndex));
        end);
    end;
  end;

  // GroupingList: return grouped rows (no paging)
  if SameText(LView.GetString('Controller'), 'GroupingList') then
  begin
    LSortExpr := '';
    begin
      var LSortFieldNames := LViewTable.GetStringArray('Controller/Grouping/SortFieldNames');
      if Length(LSortFieldNames) > 0 then
      begin
        for I := Low(LSortFieldNames) to High(LSortFieldNames) do
          LSortFieldNames[I] := LViewTable.FieldByName(LSortFieldNames[I]).QualifiedDBNameOrExpression;
        LSortExpr := Join(LSortFieldNames, ', ');
      end
      else
      begin
        var LGrpFieldName := LViewTable.GetExpandedString('Controller/Grouping/FieldName');
        if LGrpFieldName <> '' then
        begin
          LViewField := LViewTable.FindField(LGrpFieldName);
          if Assigned(LViewField) then
            LSortExpr := LViewField.QualifiedDBNameOrExpression;
        end;
      end;
    end;

    LStore := LViewTable.CreateStore;
    try
      LStore.Load(LFilterExpr, LSortExpr, 0, 0);
      LHtml := TKXGroupingListController.BuildGroupedRows(
        LStore, LViewTable, AViewName,
        LViewTable.GetExpandedString('Controller/Grouping/FieldName'),
        LViewTable.FindNode('Controller/Grouping')) +
        TKXListPanelController.BuildHiddenState(AViewName, 0, '', '');

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + AViewName + '"',
        'id="kx-list-state-' + AViewName + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
    finally
      FreeAndNil(LStore);
    end;
  end
  else if Assigned(LControllerNode) and
    (LControllerNode.GetString('TemplateFileName',
      LControllerNode.GetString('CenterController/TemplateFileName')) <> '') then
  begin
    // List + TemplateFileName — re-render selectable cards after delete
    LSortExpr := '';
    begin
      var LCardSortFieldNames := LViewTable.GetStringArray('Controller/SortFieldNames');
      if Length(LCardSortFieldNames) > 0 then
      begin
        for I := Low(LCardSortFieldNames) to High(LCardSortFieldNames) do
          LCardSortFieldNames[I] := LViewTable.FieldByName(LCardSortFieldNames[I]).QualifiedDBNameOrExpression;
        LSortExpr := Join(LCardSortFieldNames, ', ');
      end;
    end;

    // Paging: only when PagingTools is enabled
    if LPagingTools then
    begin
      var LCardPageSize := LViewTable.GetInteger('Controller/PagingTools/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT);
      LStart := 0;
      LLimit := LCardPageSize;
    end
    else
    begin
      LStart := 0;
      LLimit := 0;
    end;

    LStore := LViewTable.CreateStore;
    try
      LTotal := LStore.Load(LFilterExpr, LSortExpr, LStart, LLimit);

      LHtml := TKXTemplateDataPanelController.BuildSelectableCards(
        LStore, LViewTable, LControllerNode,
        AViewName);

      // Pager OOB (only when PagingTools is enabled)
      if LPagingTools then
      begin
        LHtml := LHtml +
          TKXListPanelController.BuildPager(AViewName, LTotal, LStart, LLimit);
        LHtml := ReplaceStr(LHtml,
          'id="kx-list-pager-' + AViewName + '"',
          'id="kx-list-pager-' + AViewName + '" hx-swap-oob="true"');
      end;

      // OOB: hidden state
      LHtml := LHtml +
        TKXListPanelController.BuildHiddenState(AViewName, LLimit, '', '');

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + AViewName + '"',
        'id="kx-list-state-' + AViewName + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
    finally
      FreeAndNil(LStore);
    end;
  end
  else
  begin
    // Standard List: refresh after delete
    LStart := 0; // Reset to first page after delete
    if LPagingTools then
      LLimit := StrToIntDef(TKWebRequest.Current.GetField('limit'),
        LViewTable.GetInteger('Controller/PagingTools/PageRecordCount', DEFAULT_PAGE_RECORD_COUNT))
    else
      LLimit := 0;
    LSort := TKWebRequest.Current.GetField('sort');
    LDir := TKWebRequest.Current.GetField('dir');

    LSortExpr := LApp.BuildSortExpression(LViewTable, LSort, LDir);

    // Load data and return response
    LStore := LViewTable.CreateStore;
    try
      LTotal := LStore.Load(LFilterExpr, LSortExpr, LStart, LLimit);
      LHtml :=
        TKXListPanelController.BuildDataRows(LStore, LViewTable, AViewName, '',
          LViewTable.FindLayout('Grid'));

      // Pager OOB (only when PagingTools is enabled)
      if LPagingTools then
      begin
        LHtml := LHtml +
          TKXListPanelController.BuildPager(AViewName, LTotal, LStart, LLimit);
        LHtml := ReplaceStr(LHtml,
          'id="kx-list-pager-' + AViewName + '"',
          'id="kx-list-pager-' + AViewName + '" hx-swap-oob="true"');
      end;

      LHtml := LHtml +
        TKXListPanelController.BuildHiddenState(AViewName, LLimit, LSort, LDir);

      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + AViewName + '"',
        'id="kx-list-state-' + AViewName + '" hx-swap-oob="true"');

      TKXWebResponse.Current.SendFragment(LHtml);
    finally
      FreeAndNil(LStore);
    end;
  end;
end;

procedure TKXViewHandlerBase.HandleForm(const AViewName: string);
var
  LApp: TKWebApplication;
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LOperation: string;
  LKeyStr, LKeyFilter: string;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldName, LFieldValue: string;
  LViewField: TKViewField;
  LController: IKXController;
  LFormController: TKXFormPanelController;
  LHtml: string;
  I: Integer;
begin
  LApp := TKWebApplication.Current;
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then
    Exit;
  if not LApp.RequireDataView(LView) then Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // Read operation and key from query string
  LOperation := TKWebRequest.Current.GetQueryField('op');
  if LOperation = '' then
    LOperation := 'edit';
  LKeyStr := TKWebRequest.Current.GetQueryField('key');

  // ACL: mode based on the requested form operation.
  if SameText(LOperation, 'new') or SameText(LOperation, 'add') or
     SameText(LOperation, 'dup') then
  begin
    if not LApp.IsViewAccessGranted(LView, ACM_ADD) then Exit;
  end
  else if SameText(LOperation, 'view') then
  begin
    if not LApp.IsViewAccessGranted(LView, ACM_VIEW) then Exit;
  end
  else
  begin
    if not LApp.IsViewAccessGranted(LView, ACM_MODIFY) then Exit;
  end;

  // Create store and load record
  LStore := LViewTable.CreateStore;
  try
    LRecord := nil;
    if SameText(LOperation, 'edit') or SameText(LOperation, 'view') or
       SameText(LOperation, 'dup') then
    begin
      if LKeyStr = '' then
        Exit;

      // Build SQL filter from key
      LKeyFilter := '';
      LKeyParts := LKeyStr.Split(['&']);
      for I := 0 to Length(LKeyParts) - 1 do
      begin
        LPair := LKeyParts[I].Split(['=']);
        if Length(LPair) = 2 then
        begin
          LFieldName := TNetEncoding.URL.Decode(LPair[0]);
          LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
          LViewField := LViewTable.FindField(LFieldName);
          if Assigned(LViewField) and LViewField.IsKey then
          begin
            if LKeyFilter <> '' then
              LKeyFilter := LKeyFilter + ' and ';
            LKeyFilter := LKeyFilter + LViewField.QualifiedDBNameOrExpression +
              ' = ''' + ReplaceStr(LFieldValue, '''', '''''') + '''';
          end;
        end;
      end;

      if LKeyFilter = '' then
        Exit;

      LStore.Load(LKeyFilter, '', 0, 1);
      if LStore.RecordCount > 0 then
        LRecord := LStore.Records[0]
      else
        Exit; // Record not found

      if SameText(LOperation, 'edit') then
        LRecord.ApplyEditRecordRules
      else if SameText(LOperation, 'dup') then
        LRecord.ApplyDuplicateRecordRules;
    end
    else if SameText(LOperation, 'add') then
    begin
      // Create new record with defaults (macro-expanded)
      LRecord := LStore.Records.AppendAndInitialize;
      var LAddDefaults := LViewTable.GetDefaultValues;
      try
        LRecord.ReadFromNode(LAddDefaults);
      finally
        FreeAndNil(LAddDefaults);
      end;
      LRecord.ApplyNewRecordRules;

      // FK pre-fill from a detail-grid add (fkField + masterKey query params).
      begin
        var LFKFieldName := TNetEncoding.URL.Decode(
          TKWebRequest.Current.GetQueryField('fkField'));
        var LMasterKey := TNetEncoding.URL.Decode(
          TKWebRequest.Current.GetQueryField('masterKey'));
        if (LFKFieldName <> '') and (LMasterKey <> '') then
        begin
          var LRefViewField := LViewTable.FindField(LFKFieldName);
          if Assigned(LRefViewField) and LRefViewField.IsReference and
             Assigned(LRefViewField.ModelField) and
             Assigned(LRefViewField.ModelField.ReferencedModel) then
          begin
            var LFKColumns := LRefViewField.ModelField.GetFieldNames;
            var LMasterKeyNames :=
              LRefViewField.ModelField.ReferencedModel.GetKeyFieldNames;
            var LMKMap := TDictionary<string, string>.Create;
            try
              var LMKParts := LMasterKey.Split(['&']);
              for var K := 0 to Length(LMKParts) - 1 do
              begin
                var LMKPair := LMKParts[K].Split(['=']);
                if Length(LMKPair) = 2 then
                  LMKMap.AddOrSetValue(
                    TNetEncoding.URL.Decode(LMKPair[0]),
                    TNetEncoding.URL.Decode(LMKPair[1]));
              end;
              for var K := 0 to Min(Length(LFKColumns),
                                    Length(LMasterKeyNames)) - 1 do
              begin
                var LMKValue: string;
                if LMKMap.TryGetValue(LMasterKeyNames[K], LMKValue) then
                begin
                  var LFKRecField := LRecord.FindField(LFKColumns[K]);
                  if Assigned(LFKRecField) then
                    LFKRecField.AsString := LMKValue
                  else
                    LRecord.GetNode(LFKColumns[K]).AsString := LMKValue;
                end;
              end;
            finally
              LMKMap.Free;
            end;
          end;
        end;
      end;
    end;

    // Detail-grid form context: wire this store to the master record held in
    // the session (registered under the master view name), so {MasterRecord.*}
    // macros in LookupFilter/DefaultFilter resolve when rendering reference
    // lookups on the detail form (e.g. filtering by the master's Pagante).
    // The master record already carries edited field values pushed via
    // NotifyChange, so the filter sees the current selection even before save.
    if Assigned(LStore) then
    begin
      var LMasterViewName := TNetEncoding.URL.Decode(
        TKWebRequest.Current.GetQueryField('masterView'));
      if LMasterViewName <> '' then
      begin
        var LMasterSessionStore := TKWebSession.Current.FindStore(LMasterViewName);
        if Assigned(LMasterSessionStore) and (LMasterSessionStore.RecordCount > 0) then
          LStore.MasterRecord := LMasterSessionStore.Records[0];
      end;
    end;

    // Create form controller (force 'Form' controller type)
    LController := TKXControllerFactory.Instance.CreateController(LView, nil, nil, 'Form');
    if not (LController is TKXFormPanelController) then
      Exit;
    LFormController := TKXFormPanelController(LController);

    LFormController.Operation := LOperation;
    LFormController.FormRecord := LRecord;
    LFormController.Config.SetString('Operation', LOperation);
    LFormController.FKFieldName := TNetEncoding.URL.Decode(
      TKWebRequest.Current.GetQueryField('fkField'));

    LController.Display;
    LApp.AdjustControllerForContext(LController);
    LHtml := LController.Render;

    // Form-specific dialog overlay id + close handler
    LHtml := ReplaceStr(LHtml,
      'id="kx-' + AViewName + '"',
      'id="kx-form-overlay-' + AViewName + '"');
    LHtml := ReplaceStr(LHtml,
      'onclick="this.closest(''.kx-dialog-overlay'').remove();"',
      'onclick="kxForm.cancel(''' + AViewName + ''');"');

    // Initialize detail stores for master-detail transactional save.
    if Assigned(LRecord) and (LViewTable.DetailTableCount > 0) then
    begin
      LRecord.EnsureDetailStores;
      if MatchText(LOperation, ['edit', 'view']) then
        LRecord.LoadDetailStores;
    end;

    // Register store in session for subsequent blob/save/detail requests
    TKWebSession.Current.RegisterStore(AViewName, LStore);
    LStore := nil; // Session owns the store now; prevent finally from freeing it

    TKXWebResponse.Current.SendFragment(LHtml);

    if Assigned(LRecord) then
      LRecord.ApplyAfterShowEditWindowRules;
  finally
    FreeAndNil(LStore);
  end;
end;

procedure TKXViewHandlerBase.HandleSaveCache(const AViewName: string);
var
  LApp: TKWebApplication;
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LView: TKView;
  LViewTable: TKViewTable;
  LOperation: string;
  LHtml: string;
  LDefaults: TEFNode;
begin
  LApp := TKWebApplication.Current;

  LStore := TKWebSession.Current.FindStore(AViewName);
  if not Assigned(LStore) then
    Exit;

  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then Exit;
  if not LApp.RequireDataView(LView) then Exit;
  LViewTable := TKDataView(LView).MainTable;
  if not Assigned(LViewTable) then
    Exit;

  LOperation := TKWebRequest.Current.GetField('_op');

  // ACL: ADD for new/dup, MODIFY otherwise (empty op = MODIFY).
  if SameText(LOperation, 'add') or SameText(LOperation, 'new') or
     SameText(LOperation, 'dup') then
  begin
    if not LApp.IsViewAccessGranted(LView, ACM_ADD) then Exit;
  end
  else
  begin
    if not LApp.IsViewAccessGranted(LView, ACM_MODIFY) then Exit;
  end;

  try
    if LStore.RecordCount > 0 then
      LRecord := LStore.Records[0]
    else
    begin
      LRecord := LStore.Records.AppendAndInitialize;
      LDefaults := LViewTable.GetDefaultValues;
      try
        LRecord.ReadFromNode(LDefaults);
      finally
        FreeAndNil(LDefaults);
      end;
      LRecord.MarkAsNew;
    end;

    LApp.PopulateRecordFromPost(LRecord, LViewTable, SameText(LOperation, 'add'));

    if LRecord.State = rsClean then
      LRecord.MarkAsModified;

    LHtml := '<script>kxForm.onSaveCacheSuccess(''' + AViewName + ''');</script>';
    TKXWebResponse.Current.SendFragment(LHtml);
  except
    on E: Exception do
    begin
      LHtml :=
        '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
          '<div class="kx-msgbox-dialog kx-msgbox-error" onclick="event.stopPropagation()">' +
            '<div class="kx-msgbox-header kx-msgbox-error">' +
              '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
              '<span>' + TNetEncoding.HTML.Encode(_('Error')) + '</span>' +
              '<button class="kx-msgbox-close" onclick="this.closest(''.kx-msgbox-overlay'').remove()">' + GetIconHTML('close') + '</button>' +
            '</div>' +
            '<div class="kx-msgbox-body">' + TNetEncoding.HTML.Encode(E.Message) + '</div>' +
            '<div class="kx-msgbox-footer">' +
              '<button class="kx-msgbox-btn-yes" onclick="this.closest(''.kx-msgbox-overlay'').remove()">OK</button>' +
            '</div>' +
          '</div>' +
        '</div>';
      TKXWebResponse.Current.SendFragment(LHtml);
    end;
  end;
end;

procedure TKXViewHandlerBase.HandleSave(const AViewName: string);
var
  LApp: TKWebApplication;
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LOperation: string;
  LKeyStr, LKeyFilter: string;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldName, LFieldValue: string;
  LViewField: TKViewField;
  LDefaults: TEFNode;
  I: Integer;
  LHtml: string;
  LOwnsStore: Boolean;
begin
  LApp := TKWebApplication.Current;
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then
    Exit;
  if not LApp.RequireDataView(LView) then Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // Read operation and key from POST body
  LOperation := TKWebRequest.Current.GetField('_op');
  if LOperation = '' then
    LOperation := 'edit';
  LKeyStr := TKWebRequest.Current.GetField('_key');

  // ACL: ADD for new/dup commits, MODIFY for edit.
  if SameText(LOperation, 'new') or SameText(LOperation, 'add') or
     SameText(LOperation, 'dup') then
  begin
    if not LApp.IsViewAccessGranted(LView, ACM_ADD) then Exit;
  end
  else
  begin
    if not LApp.IsViewAccessGranted(LView, ACM_MODIFY) then Exit;
  end;

  // Session store (with attached detail stores) if present, else create one.
  LStore := TKWebSession.Current.FindStore(AViewName);
  LOwnsStore := not Assigned(LStore);
  if LOwnsStore then
    LStore := LViewTable.CreateStore;
  try
    try
      if SameText(LOperation, 'edit') or SameText(LOperation, 'view') then
      begin
        if LOwnsStore then
        begin
          // No session store: load from DB (fallback)
          if LKeyStr = '' then
            raise Exception.Create(_('Missing record key.'));
          LKeyFilter := '';
          LKeyParts := LKeyStr.Split(['&']);
          for I := 0 to Length(LKeyParts) - 1 do
          begin
            LPair := LKeyParts[I].Split(['=']);
            if Length(LPair) = 2 then
            begin
              LFieldName := TNetEncoding.URL.Decode(LPair[0]);
              LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
              LViewField := LViewTable.FindField(LFieldName);
              if Assigned(LViewField) and LViewField.IsKey then
              begin
                if LKeyFilter <> '' then
                  LKeyFilter := LKeyFilter + ' and ';
                LKeyFilter := LKeyFilter + LViewField.QualifiedDBNameOrExpression +
                  ' = ''' + ReplaceStr(LFieldValue, '''', '''''') + '''';
              end;
            end;
          end;
          if LKeyFilter = '' then
            raise Exception.Create(_('Invalid record key.'));
          LStore.Load(LKeyFilter, '', 0, 1);
          if LStore.RecordCount = 0 then
            raise Exception.Create(_('Record not found.'));
        end;

        LRecord := LStore.Records[0];

        // SaveAll: record already up-to-date from save-cache, just persist.
        if not SameText(TKWebRequest.Current.GetField('_saveAll'), 'true') then
        begin
          LApp.PopulateRecordFromPost(LRecord, LViewTable, False);
          LRecord.MarkAsModified;
        end;
        OnBeforeSave(LRecord, False);
        LViewTable.Model.SaveRecord(LRecord, True, nil);
        OnAfterSave(LRecord, False);
      end
      else if SameText(LOperation, 'add') or SameText(LOperation, 'dup') then
      begin
        if not LOwnsStore and (LStore.RecordCount > 0) then
        begin
          LRecord := LStore.Records[0];
          LApp.PopulateRecordFromPost(LRecord, LViewTable, True);
        end
        else
        begin
          LRecord := LStore.Records.AppendAndInitialize;
          LDefaults := LViewTable.GetDefaultValues;
          try
            LRecord.ReadFromNode(LDefaults);
          finally
            FreeAndNil(LDefaults);
          end;
          LRecord.MarkAsNew;
          LApp.PopulateRecordFromPost(LRecord, LViewTable, True);
        end;
        OnBeforeSave(LRecord, True);
        LViewTable.Model.SaveRecord(LRecord, True, nil);
        OnAfterSave(LRecord, True);
      end;

      // Success: return script based on post-save mode
      if TKWebRequest.Current.GetField('_clone') = 'true' then
        LHtml := '<script>kxForm.onCloneSuccess(''' + AViewName + ''');</script>'
      else if TKWebRequest.Current.GetField('_keepopen') = 'true' then
        LHtml := '<script>kxForm.onSaveKeepOpen(''' + AViewName + ''');</script>'
      else
      begin
        LHtml := '<script>kxForm.onSaveSuccess(''' + AViewName + ''');</script>';
        TKWebSession.Current.UnregisterStore(AViewName);
      end;
      TKXWebResponse.Current.SendFragment(LHtml);
    except
      on E: Exception do
      begin
        LHtml :=
          '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
            '<div class="kx-msgbox-dialog kx-msgbox-error" onclick="event.stopPropagation()">' +
              '<div class="kx-msgbox-header kx-msgbox-error">' +
                '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
                '<span>' + TNetEncoding.HTML.Encode(_('Error')) + '</span>' +
                '<button class="kx-msgbox-close" onclick="this.closest(''.kx-msgbox-overlay'').remove()">' + GetIconHTML('close') + '</button>' +
              '</div>' +
              '<div class="kx-msgbox-body">' +
                TNetEncoding.HTML.Encode(E.Message) +
              '</div>' +
              '<div class="kx-msgbox-footer">' +
                '<button class="kx-msgbox-btn-yes" onclick="this.closest(''.kx-msgbox-overlay'').remove()">OK</button>' +
              '</div>' +
            '</div>' +
          '</div>';
        TKXWebResponse.Current.SendFragment(LHtml);
      end;
    end;
  finally
    if LOwnsStore then
      FreeAndNil(LStore);
  end;
end;

procedure TKXViewHandlerBase.HandleLookup(const AViewName: string);
var
  LApp: TKWebApplication;
  LView: TKView;
  LController: IKXController;
  LPanel: TKXPanelControllerBase;
  LHtml: string;
  LViewAlias: string;
begin
  LApp := TKWebApplication.Current;
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then
    Exit;
  if not LApp.IsViewAccessGranted(LView, ACM_READ) then
    Exit;

  LController := TKXControllerFactory.Instance.CreateController(LView);
  LController.Display;

  // Override panel properties for dialog rendering
  if LController is TKXPanelControllerBase then
  begin
    LPanel := TKXPanelControllerBase(LController);
    LPanel.IsModal := True;
    LPanel.AllowClose := True;
    if LPanel.Title <> '' then
      LPanel.Title := Format(_('Select: %s'), [LPanel.Title]);
  end;

  LHtml := LController.Render;

  // Replace the generic dialog overlay id with a lookup-specific aliased one
  LViewAlias := 'lkp_' + AViewName;
  LHtml := ReplaceStr(LHtml,
    'id="kx-' + AViewName + '"',
    'id="kx-' + LViewAlias + '"');

  // Replace the close button to use kxForm.closeLookup
  LHtml := ReplaceStr(LHtml,
    'onclick="this.closest(''.kx-dialog-overlay'').remove();"',
    'onclick="kxForm.closeLookup(''' + LViewAlias + ''');"');

  TKXWebResponse.Current.SendFragment(LHtml);
end;

procedure TKXViewHandlerBase.HandleWizardFinish(const AViewName: string);
var
  LApp: TKWebApplication;
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LDefaults: TEFNode;
  I: Integer;
  LHtml: string;
  LRulesNode, LRuleNode: TEFNode;
  LRuleImpl: TKXWizardRuleImpl;
  LRules: TObjectList<TKXWizardRuleImpl>;
begin
  LApp := TKWebApplication.Current;
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then
    Exit;
  if not LApp.RequireDataView(LView) then Exit;
  // Wizard finish always commits a brand-new record → ADD.
  if not LApp.IsViewAccessGranted(LView, ACM_ADD) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  LStore := LViewTable.CreateStore;
  try
    try
      // Create new record with defaults
      LRecord := LStore.Records.AppendAndInitialize;
      LDefaults := LViewTable.GetDefaultValues;
      try
        LRecord.ReadFromNode(LDefaults);
      finally
        FreeAndNil(LDefaults);
      end;
      LRecord.MarkAsNew;
      LApp.PopulateRecordFromPost(LRecord, LViewTable, True);

      // Instantiate wizard rules from Controller/Rules node
      LRules := TObjectList<TKXWizardRuleImpl>.Create(True);
      try
        LRulesNode := LView.FindNode('Controller/Rules');
        if Assigned(LRulesNode) then
        begin
          for I := 0 to LRulesNode.ChildCount - 1 do
          begin
            LRuleNode := LRulesNode.Children[I];
            if TKXWizardRuleRegistry.Instance.HasClass(LRuleNode.Name) then
            begin
              LRuleImpl := TKXWizardRuleRegistry.Instance.CreateObject(LRuleNode.Name);
              LRuleImpl.Config := LRuleNode;
              LRules.Add(LRuleImpl);
            end;
          end;
        end;

        // BeforeExecute callbacks
        for I := 0 to LRules.Count - 1 do
          LRules[I].BeforeExecute(LRecord);

        OnBeforeSave(LRecord, True);
        LViewTable.Model.SaveRecord(LRecord, True, nil);
        OnAfterSave(LRecord, True);

        // AfterExecute callbacks
        for I := 0 to LRules.Count - 1 do
          LRules[I].AfterExecute(LRecord);
      finally
        LRules.Free;
      end;

      // Success: return script to close wizard and refresh
      LHtml := '<script>kxWizard.onFinishSuccess(''' + AViewName + ''');</script>';
      TKXWebResponse.Current.SendFragment(LHtml);
    except
      on E: Exception do
      begin
        LHtml :=
          '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
            '<div class="kx-msgbox-dialog kx-msgbox-error" onclick="event.stopPropagation()">' +
              '<div class="kx-msgbox-header kx-msgbox-error">' +
                '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
                '<span>' + TNetEncoding.HTML.Encode(_('Error')) + '</span>' +
                '<button class="kx-msgbox-close" onclick="this.closest(''.kx-msgbox-overlay'').remove()">' + GetIconHTML('close') + '</button>' +
              '</div>' +
              '<div class="kx-msgbox-body">' +
                TNetEncoding.HTML.Encode(E.Message) +
              '</div>' +
              '<div class="kx-msgbox-footer">' +
                '<button class="kx-msgbox-btn-yes" onclick="this.closest(''.kx-msgbox-overlay'').remove()">OK</button>' +
              '</div>' +
            '</div>' +
          '</div>';
        TKXWebResponse.Current.SendFragment(LHtml);
      end;
    end;
  finally
    FreeAndNil(LStore);
  end;
end;

procedure TKXViewHandlerBase.HandleDetailData(const AViewName: string;
  const AIndex: Integer);
var
  LApp: TKWebApplication;
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LDetailTable: TKViewTable;
  LDetailViewName: string;
  LDetailView: TKView;
  LDetailDataView: TKDataView;
  LDetailViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LKeyStr: string;
  LFilterExpr: string;
  LDetailRef: TKModelDetailReference;
  LRefField: TKModelField;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldName, LFieldValue: string;
  LViewAlias: string;
  LHtml: string;
  LToolbar: string;
  LDisplayLabel: string;
  LDetailControllerNode: TEFNode;
  LPreventAdding, LPreventEditing, LPreventDeleting: Boolean;
  LSessionStore: TKViewTableStore;
  I: Integer;
  LViewBuilder: TKViewBuilder;
  LOwnsStore: Boolean;
begin
  LApp := TKWebApplication.Current;
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then Exit;
  if not LApp.RequireDataView(LView) then Exit;
  if not LApp.IsViewAccessGranted(LView, ACM_VIEW) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  if AIndex >= LViewTable.DetailTableCount then
    Exit;

  LDetailTable := LViewTable.DetailTables[AIndex];
  LKeyStr := TKWebRequest.Current.GetQueryField('key');

  // Get ViewName from detail table config; auto-build a View if not specified
  LDetailViewName := LDetailTable.GetString('ViewName');
  if LDetailViewName = '' then
  begin
    // Classic mode: auto-build a View for the detail model (like auto-built views)
    LDetailViewName := LDetailTable.ModelName;
    LDetailView := LApp.Config.Views.FindView(LDetailViewName);
    if not Assigned(LDetailView) or not (LDetailView is TKDataView) then
    begin
      LViewBuilder := TKViewBuilderFactory.Instance.CreateObject('AutoList');
      try
        LViewBuilder.SetString('Model', LDetailViewName);
        // Copy detail table Controller config (e.g., Form/Layout) to auto-built view
        var LSourceCtrlNode := LDetailTable.FindNode('Controller');
        if Assigned(LSourceCtrlNode) then
          LViewBuilder.AddChild(TEFNode.Create('MainTable')).AddChild(TEFNode.Clone(LSourceCtrlNode));
        LViewBuilder.BuildView(LApp.Config.Views, LDetailViewName, nil);
      finally
        FreeAndNil(LViewBuilder);
      end;
    end;
  end;

  // Load the referenced (or auto-built) view and render it as a detail grid
  LDetailView := LApp.Config.Views.FindView(LDetailViewName);
  if not Assigned(LDetailView) or not (LDetailView is TKDataView) then
    Exit;

  LDetailDataView := TKDataView(LDetailView);
  LDetailViewTable := LDetailDataView.MainTable;
  if not Assigned(LDetailViewTable) then
    Exit;

  // Build FK filter: find the reference from detail model to master model
  LFilterExpr := '';
  LRefField := nil;
  LDetailRef := LViewTable.Model.FindDetailReferenceByModelName(LDetailViewTable.ModelName);
  if Assigned(LDetailRef) then
  begin
    LRefField := LDetailRef.ReferenceField;
    if Assigned(LRefField) and LRefField.IsReference then
    begin
      // The reference field (e.g. PROJECT) has sub-fields (e.g. PROJECT_ID)
      // that are the actual FK columns. Match each master key field with the
      // corresponding sub-field by name.
      var LRefSubFields := LRefField.GetReferenceFields;
      LKeyParts := LKeyStr.Split(['&']);
      for I := 0 to Length(LKeyParts) - 1 do
      begin
        LPair := LKeyParts[I].Split(['=']);
        if Length(LPair) = 2 then
        begin
          LFieldName := TNetEncoding.URL.Decode(LPair[0]);
          LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
          // Find the FK sub-field matching this master key field name
          for var J := 0 to Length(LRefSubFields) - 1 do
          begin
            if SameText(LRefSubFields[J].FieldName, LFieldName) or
               SameText(LRefSubFields[J].DBColumnName, LFieldName) then
            begin
              if LFilterExpr <> '' then
                LFilterExpr := LFilterExpr + ' and ';
              LFilterExpr := LFilterExpr +
                LDetailViewTable.Model.DBTableName + '.' +
                LRefSubFields[J].DBColumnName + ' = ''' +
                ReplaceStr(LFieldValue, '''', '''''') + '''';
              Break;
            end;
          end;
        end;
      end;
    end;
  end;

  // Note: LFilterExpr may be empty for new records (Add). That's OK when
  // a session store is available — the detail store is already linked to the
  // master record. The filter is only needed for the DB fallback path.

  // Use an aliased view name to avoid HTML id conflicts with the main grid
  LViewAlias := 'dtl_' + AViewName + '_' + IntToStr(AIndex);

  // Read detail controller config (PreventAdding/Editing/Deleting)
  LDetailControllerNode := LDetailTable.FindNode('Controller');
  if Assigned(LDetailControllerNode) then
  begin
    LPreventAdding := LDetailControllerNode.GetBoolean('PreventAdding');
    LPreventEditing := LDetailControllerNode.GetBoolean('PreventEditing');
    LPreventDeleting := LDetailControllerNode.GetBoolean('PreventDeleting');
  end
  else
  begin
    LPreventAdding := False;
    LPreventEditing := False;
    LPreventDeleting := False;
  end;

  LDisplayLabel := _(LDetailViewTable.DisplayLabel);

  // Build detail toolbar with CRUD buttons.
  // Uses kxForm.openDetailForm / deleteDetailRecord which track detail context
  // for post-save refresh of the correct detail tab.
  LToolbar := '<div class="kx-list-toolbar" id="kx-list-toolbar-' + LViewAlias + '">';
  // openDetailForm(detailView, op, aliasView, tabIndex, masterView, masterKey, fkField)
  if not LPreventAdding then
  begin
    var LFKFieldName := '';
    if Assigned(LRefField) then
      LFKFieldName := LRefField.FieldName;
    LToolbar := LToolbar +
      '<button type="button" class="kx-toolbar-btn" title="' + TNetEncoding.HTML.Encode(Format(_('Add %s'), [LDisplayLabel])) + '"' +
      ' onclick="kxForm.openDetailForm(''' + LDetailViewName + ''',''add'',''' +
      LViewAlias + ''',' + IntToStr(AIndex) + ',''' +
      AViewName + ''',''' + LKeyStr + ''',''' +
      LFKFieldName + ''')">' +
      GetIconHTML('new_record') + '</button>';
  end;
  if not LPreventEditing then
    LToolbar := LToolbar +
      '<button type="button" class="kx-toolbar-btn kx-requires-selection" disabled' +
      ' title="' + TNetEncoding.HTML.Encode(Format(_('Edit %s'), [LDisplayLabel])) + '"' +
      ' onclick="kxForm.openDetailForm(''' + LDetailViewName + ''',''edit'',''' +
      LViewAlias + ''',' + IntToStr(AIndex) + ',''' +
      AViewName + ''',''' + LKeyStr + ''','''')">' +
      GetIconHTML('edit_record') + '</button>';
  if not LPreventDeleting then
    LToolbar := LToolbar +
      '<button type="button" class="kx-toolbar-btn kx-requires-selection" disabled' +
      ' title="' + TNetEncoding.HTML.Encode(Format(_('Delete %s'), [LDisplayLabel])) + '"' +
      ' onclick="kxForm.deleteDetailRecord(''' + LDetailViewName + ''',''' +
      LViewAlias + ''',' + IntToStr(AIndex) + ',''' +
      AViewName + ''',''' + LKeyStr + ''',''' +
      ReplaceStr(_('Confirm'), '''', '\''') + ''',''' +
      ReplaceStr(Format(_('Selected %s will be deleted. Are you sure?'), [LDisplayLabel]), '''', '\''') + ''',''' +
      ReplaceStr(_('Yes'), '''', '\''') + ''',''' +
      ReplaceStr(_('No'), '''', '\''') + ''')">' +
      GetIconHTML('delete_record') + '</button>';
  LToolbar := LToolbar +
    '<input type="hidden" id="kx-selected-key-' + LViewAlias + '" value="" />';
  LToolbar := LToolbar + '</div>';

  // Try to use the detail store from the session (master record's DetailStores).
  // If found, render from in-memory store (supports pending changes: rsNew/rsDirty/rsDeleted).
  // If not found, fall back to loading from DB (backward compatibility).
  LStore := nil;
  LSessionStore := TKWebSession.Current.FindStore(AViewName);
  LOwnsStore := True;
  if Assigned(LSessionStore) and (LSessionStore.RecordCount > 0) then
  begin
    var LMasterRecord := LSessionStore.Records[0];
    if LMasterRecord.DetailStoreCount > AIndex then
    begin
      LStore := TKViewTableStore(LMasterRecord.DetailStores[AIndex]);
      LOwnsStore := False; // Session owns this store
    end;
  end;

  // Read sort state (multi-column CSV: "Field1,Field2" + "asc,desc"),
  // matching the contract used by HandleData.
  var LSort := TKWebRequest.Current.GetField('sort');
  var LDir := TKWebRequest.Current.GetField('dir');
  var LSortExpr := LApp.BuildSortExpression(LDetailViewTable, LSort, LDir);

  if not Assigned(LStore) then
  begin
    // Fallback: load from DB (no session store available).
    LStore := LDetailViewTable.CreateStore;
    LOwnsStore := True;
    // With an FK filter, load the master's detail rows. Without it (master not
    // yet saved / empty key, e.g. an Add form) leave the store EMPTY and keep
    // going: we must still render the full grid (toolbar + headers + empty
    // body) so Add/Refresh stay available — matching Kitto1. Returning here
    // would leave an empty HTTP 200 whose default body ("200 OK") gets shown
    // in the detail panel.
    if LFilterExpr <> '' then
      LStore.Load(LFilterExpr, LSortExpr, 0, 0);
  end
  else if LSort <> '' then
  begin
    // In-memory sort of the session detail store: AliasedName-based compare
    // chain over the requested fields. Mutates record order in place — same
    // behavior as Kitto1's GridPanel sort, which acts on the live ServerStore.
    var LSortFields := LSort.Split([',']);
    var LSortDirs := LDir.Split([',']);
    LStore.Records.Sort(
      function (ALeft, ARight: TKRecord): Integer
      var K: Integer; LFL, LFR: TKField; LDesc: Boolean;
      begin
        Result := 0;
        for K := 0 to High(LSortFields) do
        begin
          LFL := ALeft.FindField(LSortFields[K].Trim);
          LFR := ARight.FindField(LSortFields[K].Trim);
          if not (Assigned(LFL) and Assigned(LFR)) then Continue;
          if LFL.IsNull and LFR.IsNull then Continue
          else if LFL.IsNull then Result := -1
          else if LFR.IsNull then Result := 1
          else Result := CompareText(LFL.AsString, LFR.AsString);
          LDesc := (K <= High(LSortDirs)) and SameText(LSortDirs[K].Trim, 'desc');
          if LDesc then Result := -Result;
          if Result <> 0 then Exit;
        end;
      end);
  end;

  try
    // Detail data endpoint contract — same as HandleData:
    //  - HX-driven request (column sort, filter, pager): tbody rows for the
    //    target swap, plus OOB-swap of the state div carrying updated
    //    sort/dir. No toolbar/headers in the response.
    //  - Direct fetch (initial load via loadDetailTab): full grid (toolbar +
    //    headers + tbody + state) so the panel can be filled in one go.
    // The state div carries the master `key` so hx-include keeps the master
    // filter on every refresh; without it, the LIST endpoint of the detail
    // model would return all detail rows of all masters.
    var LDetailUrlPath := AViewName + '/detail/' + IntToStr(AIndex);
    var LIsHxRequest := SameText(
      TKWebRequest.Current.GetHeaderField('HX-Request'), 'true');

    if LIsHxRequest then
    begin
      // Rows for tbody innerHTML swap + OOB state update.
      LHtml :=
        TKXListPanelController.BuildDataRows(
          LStore, LDetailViewTable, LViewAlias, LDetailViewName,
          LDetailViewTable.FindLayout('Grid')) +
        ReplaceStr(
          TKXListPanelController.BuildHiddenState(LViewAlias, 0, LSort, LDir, LDetailUrlPath),
          '</div>',
          '<input type="hidden" name="key" value="' +
            TNetEncoding.HTML.Encode(LKeyStr) + '" /></div>');
      LHtml := ReplaceStr(LHtml,
        'id="kx-list-state-' + LViewAlias + '"',
        'id="kx-list-state-' + LViewAlias + '" hx-swap-oob="true"');
    end
    else
    begin
      // Full grid: toolbar + column headers + tbody + rows + state.
      LHtml := LToolbar +
        '<div class="kx-list-grid"><table class="kx-grid-table">' +
        TKXListPanelController.BuildColumnHeaders(
          LDetailViewTable, LViewAlias, LSort, LDir, LDetailUrlPath,
          LDetailViewTable.FindLayout('Grid')) +
        '<tbody id="kx-list-body-' + LViewAlias + '"' +
        ' data-dblclick="' + IfThen(not LPreventEditing, 'edit', 'view') + '"' +
        ' data-detail-view="' + LDetailViewName + '"' +
        ' data-alias-view="' + LViewAlias + '"' +
        ' data-detail-index="' + IntToStr(AIndex) + '"' +
        ' data-master-view="' + AViewName + '"' +
        ' data-master-key="' + TNetEncoding.HTML.Encode(LKeyStr) + '"' +
        IfThen(Assigned(LRefField), ' data-fk-field="' + LRefField.FieldName + '"', '') +
        '>' +
        TKXListPanelController.BuildDataRows(
          LStore, LDetailViewTable, LViewAlias, LDetailViewName,
          LDetailViewTable.FindLayout('Grid')) +
        '</tbody></table></div>' +
        ReplaceStr(
          TKXListPanelController.BuildHiddenState(LViewAlias, 0, LSort, LDir, LDetailUrlPath),
          '</div>',
          '<input type="hidden" name="key" value="' +
            TNetEncoding.HTML.Encode(LKeyStr) + '" /></div>');
    end;

    TKXWebResponse.Current.SendFragment(LHtml);
  finally
    if LOwnsStore then
      FreeAndNil(LStore);
  end;
end;

procedure TKXViewHandlerBase.HandleDetailSave(const AViewName: string;
  const AIndex: Integer);
var
  LApp: TKWebApplication;
  LSessionStore: TKViewTableStore;
  LMasterRecord: TKViewTableRecord;
  LDetailStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LOperation: string;
  LView: TKView;
  LDataView: TKDataView;
  LViewTable, LDetailViewTable: TKViewTable;
  LDetailTable: TKViewTable;
  LDetailViewName: string;
  LKeyStr, LFieldName, LFieldValue: string;
  LKeyParts, LPair: TArray<string>;
  LHtml: string;
  I: Integer;
  LDefaults: TEFNode;
begin
  LApp := TKWebApplication.Current;

  // Find master store in session
  LSessionStore := TKWebSession.Current.FindStore(AViewName);
  if not Assigned(LSessionStore) or (LSessionStore.RecordCount = 0) then
    Exit;
  LMasterRecord := LSessionStore.Records[0];
  if LMasterRecord.DetailStoreCount <= AIndex then
    Exit;
  LDetailStore := TKViewTableStore(LMasterRecord.DetailStores[AIndex]);

  // Resolve detail view table
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then Exit;
  if not LApp.RequireDataView(LView) then Exit;
  if not LApp.IsViewAccessGranted(LView, ACM_MODIFY) then Exit;
  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) or (AIndex >= LViewTable.DetailTableCount) then Exit;
  LDetailTable := LViewTable.DetailTables[AIndex];

  // Get the detail view's ViewTable for field metadata
  LDetailViewName := LDetailTable.GetString('ViewName');
  if LDetailViewName = '' then
    LDetailViewName := LDetailTable.ModelName;
  var LDetailView := LApp.Config.Views.FindView(LDetailViewName);
  if Assigned(LDetailView) and (LDetailView is TKDataView) then
    LDetailViewTable := TKDataView(LDetailView).MainTable
  else
    LDetailViewTable := LDetailStore.ViewTable;

  LOperation := TKWebRequest.Current.GetField('_op');
  if LOperation = '' then
    LOperation := 'add';

  LRecord := nil;
  try
    if SameText(LOperation, 'add') then
    begin
      // Wire master-detail link before appending: AppendAndInitialize calls
      // SetDetailFieldValues (Kitto.Metadata.DataView.pas:3088) when
      // MasterRecord is set, propagating the master key onto the new detail
      // record's FK columns via GetNode (which creates the nodes if absent —
      // tolerating detail views that don't list the back-reference).
      LDetailStore.MasterRecord := LMasterRecord;

      LRecord := LDetailStore.Records.AppendAndInitialize;
      LDefaults := LDetailViewTable.GetDefaultValues;
      try
        LRecord.ReadFromNode(LDefaults);
      finally
        FreeAndNil(LDefaults);
      end;
      LRecord.MarkAsNew;

      // Populate fields from POST data
      LApp.PopulateRecordFromPost(LRecord, LDetailViewTable, True);
    end
    else if SameText(LOperation, 'edit') then
    begin
      // Find existing record by key
      LKeyStr := TKWebRequest.Current.GetField('_key');
      LRecord := nil;
      if LKeyStr <> '' then
      begin
        LKeyParts := LKeyStr.Split(['&']);
        for I := 0 to LDetailStore.RecordCount - 1 do
        begin
          var LCandidate := LDetailStore.Records[I];
          if LCandidate.State = rsDeleted then Continue;
          var LMatch := True;
          for var K := 0 to Length(LKeyParts) - 1 do
          begin
            LPair := LKeyParts[K].Split(['=']);
            if Length(LPair) = 2 then
            begin
              LFieldName := TNetEncoding.URL.Decode(LPair[0]);
              LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
              var LF := LCandidate.FindField(LFieldName);
              if not Assigned(LF) or (LF.AsString <> LFieldValue) then
              begin
                LMatch := False;
                Break;
              end;
            end;
          end;
          if LMatch then
          begin
            LRecord := LCandidate;
            Break;
          end;
        end;
      end;

      if not Assigned(LRecord) then
        raise Exception.Create(_('Detail record not found.'));

      // Update fields from POST data
      LApp.PopulateRecordFromPost(LRecord, LDetailViewTable, False);
      LRecord.MarkAsModified;
    end;

    // Apply each field's AfterFieldChange rules on the freshly-populated
    // record, so computed fields get set (e.g. Descrizione via CalcDescrizione).
    // In Kitto1 these ran during interactive editing; the save-cache flow
    // populates a fresh record with change notifications disabled, so without
    // this a NOT NULL computed column (e.g. DETTAGLI_PAGAMENTO.DX) stays null.
    if Assigned(LRecord) then
    begin
      for var LFI := 0 to LDetailViewTable.FieldCount - 1 do
      begin
        var LFVF := LDetailViewTable.Fields[LFI];
        var LFRF := LRecord.FindField(LFVF.AliasedName);
        if Assigned(LFRF) then
          LFVF.EnumRules(
            function (ARuleImpl: TKRuleImpl): Boolean
            begin
              ARuleImpl.AfterFieldChange(LFRF, LFRF.Value, LFRF.Value);
              Result := False; // continue with the next rule
            end);
      end;
    end;

    // Fire the detail record's Before rules now (at save-to-cache time), so
    // rules that update the master from the in-memory detail store run
    // immediately (e.g. recomputing the master's totals). Mirrors Kitto1,
    // where saving a detail row fired its BeforeAddOrUpdate against the
    // in-memory store; without this the master's computed fields stay stale
    // until (and unless) the master is reloaded from the database.
    if Assigned(LRecord) then
      LRecord.ApplyBeforeRules;

    // Success: close detail form and reload detail tab
    var LDetailViewParam := TKWebRequest.Current.GetField('_detailView');
    if LDetailViewParam = '' then
      LDetailViewParam := LDetailViewName;
    var LMasterKey := TKWebRequest.Current.GetField('_masterKey');
    LHtml := '<script>kxForm.onDetailSaveSuccess(''' +
      LDetailViewParam + ''',''' + AViewName + ''',' +
      IntToStr(AIndex) + ',''' + LMasterKey + ''');</script>';
    TKXWebResponse.Current.SendFragment(LHtml);
  except
    on E: Exception do
    begin
      LHtml :=
        '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
          '<div class="kx-msgbox-dialog kx-msgbox-error" onclick="event.stopPropagation()">' +
            '<div class="kx-msgbox-header kx-msgbox-error">' +
              '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
              '<span>' + TNetEncoding.HTML.Encode(_('Error')) + '</span>' +
              '<button class="kx-msgbox-close" onclick="this.closest(''.kx-msgbox-overlay'').remove()">' + GetIconHTML('close') + '</button>' +
            '</div>' +
            '<div class="kx-msgbox-body">' +
              TNetEncoding.HTML.Encode(E.Message) +
            '</div>' +
            '<div class="kx-msgbox-footer">' +
              '<button class="kx-msgbox-btn-yes" onclick="this.closest(''.kx-msgbox-overlay'').remove()">OK</button>' +
            '</div>' +
          '</div>' +
        '</div>';
      TKXWebResponse.Current.SendFragment(LHtml);
    end;
  end;
end;

procedure TKXViewHandlerBase.HandleDetailDelete(const AViewName: string;
  const AIndex: Integer);
var
  LApp: TKWebApplication;
  LSessionStore: TKViewTableStore;
  LMasterRecord: TKViewTableRecord;
  LDetailStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LView: TKView;
  LKeyStr, LFieldName, LFieldValue: string;
  LKeyParts, LPair: TArray<string>;
  I: Integer;
begin
  LApp := TKWebApplication.Current;

  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then
    Exit;
  if not LApp.IsViewAccessGranted(LView, ACM_DELETE) then
    Exit;

  // Find master store in session
  LSessionStore := TKWebSession.Current.FindStore(AViewName);
  if not Assigned(LSessionStore) or (LSessionStore.RecordCount = 0) then
    Exit;
  LMasterRecord := LSessionStore.Records[0];
  if LMasterRecord.DetailStoreCount <= AIndex then
    Exit;
  LDetailStore := TKViewTableStore(LMasterRecord.DetailStores[AIndex]);

  // Find record by key
  LKeyStr := TKWebRequest.Current.GetField('key');
  if LKeyStr = '' then
    LKeyStr := TKWebRequest.Current.GetQueryField('key');
  if LKeyStr = '' then
    Exit;

  LRecord := nil;
  LKeyParts := LKeyStr.Split(['&']);
  for I := 0 to LDetailStore.RecordCount - 1 do
  begin
    var LCandidate := LDetailStore.Records[I];
    if LCandidate.State = rsDeleted then Continue;
    var LMatch := True;
    for var K := 0 to Length(LKeyParts) - 1 do
    begin
      LPair := LKeyParts[K].Split(['=']);
      if Length(LPair) = 2 then
      begin
        LFieldName := TNetEncoding.URL.Decode(LPair[0]);
        LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
        var LF := LCandidate.FindField(LFieldName);
        if not Assigned(LF) or (LF.AsString <> LFieldValue) then
        begin
          LMatch := False;
          Break;
        end;
      end;
    end;
    if LMatch then
    begin
      LRecord := LCandidate;
      Break;
    end;
  end;

  if not Assigned(LRecord) then
    Exit;

  // Mark as deleted (or clean if was new — never needs DB DELETE)
  if LRecord.State = rsNew then
    LRecord.MarkAsClean
  else
    LRecord.MarkAsDeleted;

  // Return empty response — client will reload the detail tab
  TKXWebResponse.Current.SendFragment('');
end;

procedure TKXViewHandlerBase.HandleTool(const AViewName, AToolName: string);
var
  LApp: TKWebApplication;
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LToolViewsNode, LToolNode: TEFNode;
  LToolView: TKView;
  LToolController: IKXController;
  LStore: TKViewTableStore;
  LKeyStr, LKeyFilter, LFilterExpr: string;
  LFilterItemsNode: TEFNode;
  LFilterConnector: string;
  LControllerNode: TEFNode;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldName, LFieldValue: string;
  LViewField: TKViewField;
  I: Integer;
begin
  LApp := TKWebApplication.Current;
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then Exit;
  if not LApp.RequireDataView(LView) then Exit;
  if not LApp.IsViewAccessGranted(LView, ACM_RUN) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // Find the tool node: prefer Controller/ToolViews (list toolbar),
  // fall back to EditController/ToolViews (form toolbar) — Kitto1 parity.
  LToolNode := nil;
  LToolViewsNode := LViewTable.FindNode('Controller/ToolViews');
  if Assigned(LToolViewsNode) then
    LToolNode := LToolViewsNode.FindNode(AToolName);
  if not Assigned(LToolNode) then
  begin
    LToolViewsNode := LViewTable.FindNode('EditController/ToolViews');
    if Assigned(LToolViewsNode) then
      LToolNode := LToolViewsNode.FindNode(AToolName);
  end;
  if not Assigned(LToolNode) then
    Exit;

  // Create tool view from node and instantiate tool controller
  LToolView := LApp.Config.Views.ViewByNode(LToolNode);
  LToolController := TKXControllerFactory.Instance.CreateController(LToolView);

  // Load data store with current filters or specific record
  LStore := LViewTable.CreateStore;
  try
    LKeyStr := TKWebRequest.Current.GetField('key');
    if LKeyStr <> '' then
    begin
      // Load specific record by key (for RequireSelection tools)
      LKeyFilter := '';
      LKeyParts := LKeyStr.Split(['&']);
      for I := 0 to Length(LKeyParts) - 1 do
      begin
        LPair := LKeyParts[I].Split(['=']);
        if Length(LPair) = 2 then
        begin
          LFieldName := TNetEncoding.URL.Decode(LPair[0]);
          LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
          LViewField := LViewTable.FindField(LFieldName);
          if Assigned(LViewField) and LViewField.IsKey then
          begin
            if LKeyFilter <> '' then
              LKeyFilter := LKeyFilter + ' and ';
            LKeyFilter := LKeyFilter + LViewField.QualifiedDBNameOrExpression +
              ' = ''' + ReplaceStr(LFieldValue, '''', '''''') + '''';
          end;
        end;
      end;
      if LKeyFilter <> '' then
        LStore.Load(LKeyFilter, '', 0, 0);
    end
    else
    begin
      // Load all data with current filters (for export tools)
      LFilterExpr := '';
      LControllerNode := LView.FindNode('Controller');
      if Assigned(LControllerNode) then
      begin
        LFilterItemsNode := LControllerNode.FindNode('Filters/Items');
        if Assigned(LFilterItemsNode) then
        begin
          LFilterConnector := LControllerNode.GetString('Filters/Connector', 'and');
          LFilterExpr := BuildFilterExpression(
            LFilterItemsNode, LFilterConnector,
            function(AIndex: Integer): string
            begin
              Result := TKWebRequest.Current.GetField('f_' + IntToStr(AIndex));
            end);
        end;
      end;
      LStore.Load(LFilterExpr, '', 0, 0);
    end;

    // Set Sys objects on the tool controller's Config for tool execution
    LToolController.Config.SetObject('Sys/ServerStore', LStore);
    LToolController.Config.SetObject('Sys/ViewTable', LViewTable);
    if LStore.RecordCount > 0 then
      LToolController.Config.SetObject('Sys/Record', LStore.Records[0]);

    // Execute the tool (calls ExecuteTool + AfterExecuteTool)
    // For download tools: DownloadStream sets Content-Disposition and content stream.
    // For non-download tools: response may be empty or have a success indicator.
    LToolController.Display;
  finally
    // Clear Sys/ references before freeing store to avoid dangling pointers
    LToolController.Config.SetObject('Sys/ServerStore', nil);
    LToolController.Config.SetObject('Sys/ViewTable', nil);
    LToolController.Config.SetObject('Sys/Record', nil);
    FreeAndNil(LStore);
  end;
end;

procedure TKXViewHandlerBase.HandleTempUpload(const AViewName, AFieldName: string);
var
  LApp: TKWebApplication;
  LView: TKView;
  LViewTable: TKViewTable;
  LViewField: TKViewField;
  LFiles: TAbstractWebRequestFiles;
  LTempDir, LStoredName: string;
  LUploadStream: TFileStream;
  LJson: string;
begin
  LApp := TKWebApplication.Current;
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then Exit;
  if not LApp.RequireDataView(LView) then Exit;
  if not LApp.IsViewAccessGranted(LView, ACM_MODIFY) then Exit;
  LViewTable := TKDataView(LView).MainTable;
  if not Assigned(LViewTable) then Exit;
  LViewField := LViewTable.FindField(AFieldName);
  if not Assigned(LViewField) or not (LViewField.DataType is TKFileReferenceDataType) then Exit;

  LFiles := TKWebRequest.Current.Files;
  if LFiles.Count = 0 then Exit;

  // Per-session temp directory (isolated by session ID, cleaned up by age)
  LTempDir := TPath.Combine(TPath.Combine(TPath.GetTempPath, 'kxupload'),
    TKWebSession.Current.SessionId);
  ForceDirectories(LTempDir);

  LStoredName := CreateCompactGuidStr + ExtractFileExt(LFiles[0].FileName);
  LUploadStream := TFileStream.Create(TPath.Combine(LTempDir, LStoredName),
    fmCreate or fmShareExclusive);
  try
    LFiles[0].Stream.Position := 0;
    LUploadStream.CopyFrom(LFiles[0].Stream, 0);
  finally
    LUploadStream.Free;
  end;

  LJson := '{"ok":true,"temp":"' + LStoredName + '"}';
  TKWebResponse.Current.ReplaceContentStream(TStringStream.Create(LJson, TEncoding.UTF8));
  TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
end;

procedure TKXViewHandlerBase.HandleNotifyChange(const AViewName, AFieldName: string);
var
  LApp: TKWebApplication;
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LOperation: string;
  LFieldsCount: Integer;
  LPreNulls: TArray<Boolean>;
  LPreValues: TArray<string>;
  LPreFKValues: TArray<string>;
  I: Integer;
  LVF: TKViewField;
  LRF: TKViewTableField;
  LFKField: TKViewTableField;
  LJson: TStringBuilder;
  LFirst: Boolean;
  LCurNull: Boolean;
  LCurValue, LCurFK: string;
  LTriggerVF: TKViewField;
begin
  LApp := TKWebApplication.Current;
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then
    Exit;
  if not LApp.RequireDataView(LView) then Exit;
  if not LApp.IsViewAccessGranted(LView, ACM_READ) then Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then Exit;

  LOperation := TKWebRequest.Current.GetField('_op');
  if LOperation = '' then
    LOperation := 'edit';

  // The session store is registered by HandleForm when the form opens.
  // Without it there's no record to mutate (and no prior edits to preserve),
  // so simply return an empty diff.
  LStore := TKWebSession.Current.FindStore(AViewName);
  if not Assigned(LStore) or (LStore.RecordCount = 0) then
  begin
    TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
    TKWebResponse.Current.ReplaceContentStream(
      TStringStream.Create('{}', TEncoding.UTF8));
    Exit;
  end;
  LRecord := LStore.Records[0];

  LTriggerVF := LViewTable.FindField(AFieldName);
  if not Assigned(LTriggerVF) then
  begin
    TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
    TKWebResponse.Current.ReplaceContentStream(
      TStringStream.Create('{}', TEncoding.UTF8));
    Exit;
  end;

  LFieldsCount := LViewTable.FieldCount;

  // Snapshot all top-level field values BEFORE applying the trigger.
  SetLength(LPreNulls, LFieldsCount);
  SetLength(LPreValues, LFieldsCount);
  SetLength(LPreFKValues, LFieldsCount);
  for I := 0 to LFieldsCount - 1 do
  begin
    LVF := LViewTable.Fields[I];
    LRF := LRecord.FindField(LVF.AliasedName);
    if Assigned(LRF) then
    begin
      LPreNulls[I] := LRF.IsNull;
      if not LRF.IsNull then
        LPreValues[I] := LRF.AsString
      else
        LPreValues[I] := '';
    end
    else
    begin
      LPreNulls[I] := True;
      LPreValues[I] := '';
    end;
    LPreFKValues[I] := '';
    if LVF.IsReference then
    begin
      LFKField := LRecord.FindField(LVF.FieldNamesForUpdate);
      if Assigned(LFKField) and not LFKField.IsNull then
        LPreFKValues[I] := LFKField.AsString;
    end;
  end;

  // Wire the field-change handler that drives AfterFieldChange rules.
  // Mirrors Kitto1's TKExtFormPanelController.EnableFieldChangeHandler /
  // FieldChange (Kitto.Ext.Form.pas). Without this, the framework's
  // FieldChanged only refreshes derived reference fields — user rules
  // would not fire on field-change events.
  LRecord.OnFieldChange := NotifyFieldChangeHandler;
  try
    try
      LApp.PopulateRecordFieldFromPost(LRecord, LTriggerVF,
        SameText(LOperation, 'add') or SameText(LOperation, 'dup'));
    except
      // Any exception from an AfterFieldChange rule is surfaced as a dialog,
      // mirroring Kitto1 (TCustomWebSession.HandleRequest catches Exception
      // and routes to OnError → ExtMessageBox.Alert). Without this, debug
      // builds break in the IDE on benign rule failures (e.g. EConvertError
      // when a rule reads an out-of-range value from data).
      on E: Exception do
      begin
        TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
        TKWebResponse.Current.ReplaceContentStream(
          TStringStream.Create(
            '{"_error":' + QuoteJSONValue(E.Message) + '}',
            TEncoding.UTF8));
        Exit;
      end;
    end;
  finally
    LRecord.OnFieldChange := nil;
  end;

  // Diff and emit JSON of changed top-level fields
  LJson := TStringBuilder.Create;
  try
    LJson.Append('{');
    LFirst := True;
    for I := 0 to LFieldsCount - 1 do
    begin
      LVF := LViewTable.Fields[I];

      // Skip the trigger field itself: the client already has the value
      if SameText(LVF.AliasedName, AFieldName) then
        Continue;
      // Skip blob fields (binary not relevant for fan-out)
      if LVF.IsBlob and not (LVF.DataType is TEFMemoDataType) then
        Continue;

      LRF := LRecord.FindField(LVF.AliasedName);
      if not Assigned(LRF) then
        Continue;

      LCurNull := LRF.IsNull;
      if LCurNull then
        LCurValue := ''
      else
        LCurValue := LRF.AsString;

      if LVF.IsReference then
      begin
        // Reference: only emit when the FK actually changed
        LFKField := LRecord.FindField(LVF.FieldNamesForUpdate);
        if Assigned(LFKField) and not LFKField.IsNull then
          LCurFK := LFKField.AsString
        else
          LCurFK := '';
        if LCurFK = LPreFKValues[I] then
          Continue;
        if not LFirst then
          LJson.Append(',');
        LFirst := False;
        LJson.Append('"').Append(LVF.AliasedName)
          .Append('":{"_ref":true,"key":')
          .Append(QuoteJSONValue(LCurFK))
          .Append(',"display":')
          .Append(QuoteJSONValue(LCurValue))
          .Append('}');
      end
      else
      begin
        // Scalar: skip if unchanged
        if (LPreNulls[I] = LCurNull) and (LPreValues[I] = LCurValue) then
          Continue;
        if not LFirst then
          LJson.Append(',');
        LFirst := False;
        LJson.Append('"').Append(LVF.AliasedName).Append('":');
        if LCurNull then
          LJson.Append('null')
        else if LVF.DataType is TEFBooleanDataType then
          LJson.Append(IfThen(LRF.AsBoolean, 'true', 'false'))
        else if LVF.DataType is TEFNumericDataTypeBase then
          LJson.Append(LRF.GetAsJSONValue(False, False))
        else if LVF.DataType is TEFDateDataType then
          // ISO format expected by <input type="date"> on the client.
          LJson.Append(QuoteJSONValue(FormatDateTime('yyyy-mm-dd', LRF.AsDateTime)))
        else if LVF.DataType is TEFTimeDataType then
          LJson.Append(QuoteJSONValue(FormatDateTime('hh:nn', LRF.AsDateTime)))
        else if LVF.DataType is TEFDateTimeDataType then
          LJson.Append(QuoteJSONValue(FormatDateTime('yyyy-mm-dd', LRF.AsDateTime)))
        else
          LJson.Append(QuoteJSONValue(LRF.AsString));
      end;
    end;
    LJson.Append('}');

    TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
    TKWebResponse.Current.ReplaceContentStream(
      TStringStream.Create(LJson.ToString, TEncoding.UTF8));
  finally
    LJson.Free;
  end;
end;

procedure TKXViewHandlerBase.NotifyFieldChangeHandler(const AField: TKField;
  const AOldValue, ANewValue: Variant);
var
  LField: TKViewTableField;
  LOldVal, LNewVal: Variant;
begin
  // Mirrors Kitto1's TKExtFormPanelController.FieldChange: enumerates rules
  // of the changed field's ViewField and invokes AfterFieldChange. For a
  // reference FK sub-field set (e.g. NominativoId) the rule body's check on
  // AField.Name will not match the reference name (e.g. 'Nominativo');
  // however the framework's cascade applies derived values back on the
  // parent reference field via AssignValue, and that fires FieldChanged on
  // the parent reference — which is what triggers the rule.
  if not (AField is TKViewTableField) then Exit;
  LField := TKViewTableField(AField);
  if LField.IsPartOfCompositeField then Exit;
  LOldVal := AOldValue;
  LNewVal := ANewValue;
  LField.ViewField.EnumRules(
    function (ARuleImpl: TKRuleImpl): Boolean
    begin
      ARuleImpl.AfterFieldChange(AField, LOldVal, LNewVal);
      Result := False; // Continue with the next rule
    end);
end;

procedure TKXViewHandlerBase.HandleBlob(const AViewName, AFieldName: string);
var
  LApp: TKWebApplication;
  LView: TKView;
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LRecord: TKViewTableRecord;
  LViewField: TKViewField;
  LKeyStr, LKeyFilter: string;
  LKeyParts: TArray<string>;
  LPair: TArray<string>;
  LFieldNamePart, LFieldValue: string;
  LBytes: TBytes;
  LExt, LContentType, LFileName: string;
  LIsDownload: Boolean;
  LStream: TBytesStream;
  I: Integer;
begin
  LApp := TKWebApplication.Current;
  LView := LApp.FindViewOrSetNotFound(AViewName);
  if not Assigned(LView) then Exit;
  if not LApp.RequireDataView(LView) then Exit;
  if not LApp.IsViewAccessGranted(LView, ACM_READ) then
    Exit;

  LDataView := TKDataView(LView);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  LViewField := LViewTable.FindField(AFieldName);
  if not Assigned(LViewField) then Exit;
  if not LViewField.IsBlob and not (LViewField.DataType is TKFileReferenceDataType) then Exit;

  // Serve a temp file (uploaded via AJAX before form save) — no record needed
  if LViewField.DataType is TKFileReferenceDataType then
  begin
    var LTempParam := TKWebRequest.Current.GetQueryField('temp');
    if LTempParam <> '' then
    begin
      var LTempDir := TPath.Combine(TPath.Combine(TPath.GetTempPath, 'kxupload'),
        TKWebSession.Current.SessionId);
      var LTempFilePath := TPath.Combine(LTempDir, LTempParam);
      if not TFile.Exists(LTempFilePath) then
      begin
        TKWebResponse.Current.StatusCode := 404;
        TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
        TKWebResponse.Current.ReplaceContentStream(TStringStream.Create('{"error":"File not found"}', TEncoding.UTF8));
        Exit;
      end;
      var LDisplayName := TNetEncoding.URL.Decode(TKWebRequest.Current.GetQueryField('name'));
      if LDisplayName = '' then LDisplayName := LTempParam;
      LIsDownload := SameText(TKWebRequest.Current.GetQueryField('download'), '1');
      // Read into memory so the file handle is closed before transfer starts.
      // This avoids EIdSocketError #10053 when PDF viewers make range requests
      // and abort the initial connection mid-stream.
      var LFileBytes: TBytes;
      var LFStream := TFileStream.Create(LTempFilePath, fmOpenRead or fmShareDenyWrite);
      try
        SetLength(LFileBytes, LFStream.Size);
        if Length(LFileBytes) > 0 then
          LFStream.ReadBuffer(LFileBytes[0], Length(LFileBytes));
      finally
        LFStream.Free;
      end;
      var LTempStream := TBytesStream.Create(LFileBytes);
      if LIsDownload then
        LApp.DownloadStream(LTempStream, LDisplayName, '', False)
      else
        LApp.DownloadStream(LTempStream, LDisplayName, '', True);
      Exit;
    end;
  end;

  LStore := nil;

  // Try to get the record from the session store (registered when form was opened).
  // This avoids a full SELECT * query — the blob is lazy-loaded on AsBytes access.
  LStore := TKWebSession.Current.FindStore(AViewName);
  if Assigned(LStore) and (LStore.RecordCount > 0) then
    LRecord := LStore.Records[0]
  else
  begin
    // Fallback: load from DB (for cases where no session store exists).
    // Qualify key fields with table name to avoid ambiguity in JOINs.
    LKeyStr := TKWebRequest.Current.GetQueryField('key');
    if LKeyStr = '' then
      Exit;

    LKeyFilter := '';
    LKeyParts := LKeyStr.Split(['&']);
    for I := 0 to Length(LKeyParts) - 1 do
    begin
      LPair := LKeyParts[I].Split(['=']);
      if Length(LPair) = 2 then
      begin
        LFieldNamePart := TNetEncoding.URL.Decode(LPair[0]);
        LFieldValue := TNetEncoding.URL.Decode(LPair[1]);
        // Qualify field name with table name to avoid ambiguity
        LViewField := LViewTable.FindField(LFieldNamePart);
        if Assigned(LViewField) then
        begin
          if LKeyFilter <> '' then
            LKeyFilter := LKeyFilter + ' and ';
          LKeyFilter := LKeyFilter + LViewField.QualifiedDBNameOrExpression +
            ' = ''' + ReplaceStr(LFieldValue, '''', '''''') + '''';
        end;
      end;
    end;

    if LKeyFilter = '' then
      Exit;

    LStore := LViewTable.CreateStore;
    try
      LStore.Load(LKeyFilter, '', 0, 1);
      if LStore.RecordCount = 0 then
        Exit;
      LRecord := LStore.Records[0];
    except
      FreeAndNil(LStore);
      raise;
    end;
  end;

  if not Assigned(LRecord) then
    Exit;

  // Re-read the view field (it may have been overwritten by the key field lookup above)
  LViewField := LViewTable.FindField(AFieldName);

  // FileReference fields: file lives on disk; DB field holds the stored filename only.
  if LViewField.DataType is TKFileReferenceDataType then
  begin
    try
      var LStoredName := LRecord.FieldByName(LViewField.FieldNamesForUpdate).AsString;
      if LStoredName = '' then
      begin
        if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
          FreeAndNil(LStore);
        TKWebResponse.Current.StatusCode := 404;
        TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
        TKWebResponse.Current.ReplaceContentStream(TStringStream.Create('{"error":"File not found"}', TEncoding.UTF8));
        Exit;
      end;
      var LDirPath := LViewField.GetExpandedString('Path');
      if LDirPath = '' then
      begin
        if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
          FreeAndNil(LStore);
        Exit; // config error — leave as 404 "unknown request"
      end;
      var LFilePath := TPath.Combine(LDirPath, LStoredName);
      if not TFile.Exists(LFilePath) then
      begin
        if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
          FreeAndNil(LStore);
        TKWebResponse.Current.StatusCode := 404;
        TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
        TKWebResponse.Current.ReplaceContentStream(TStringStream.Create('{"error":"File not found"}', TEncoding.UTF8));
        Exit;
      end;
      // Prefer companion field value as display filename (original name)
      var LDisplayName := LStoredName;
      var LFNField := LViewField.FileNameField;
      if LFNField <> '' then
      begin
        var LCompField := LRecord.FindField(LFNField);
        if Assigned(LCompField) and not LCompField.IsNull and (LCompField.AsString <> '') then
          LDisplayName := LCompField.AsString;
      end;
      LIsDownload := SameText(TKWebRequest.Current.GetQueryField('download'), '1');
      // Read into memory before serving to avoid EIdSocketError #10053 when PDF
      // viewers make Range requests and abort the initial connection mid-stream.
      var LDiskBytes: TBytes;
      var LDiskFS := TFileStream.Create(LFilePath, fmOpenRead or fmShareDenyWrite);
      try
        SetLength(LDiskBytes, LDiskFS.Size);
        if Length(LDiskBytes) > 0 then
          LDiskFS.ReadBuffer(LDiskBytes[0], Length(LDiskBytes));
      finally
        LDiskFS.Free;
      end;
      var LFileStream := TBytesStream.Create(LDiskBytes);
      // Empty content type → DownloadStream calls GetFileMimeType(LDisplayName)
      if LIsDownload then
        LApp.DownloadStream(LFileStream, LDisplayName, '', False)
      else
        LApp.DownloadStream(LFileStream, LDisplayName, '', True);
    except
      if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
        FreeAndNil(LStore);
      raise;
    end;
    if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
      FreeAndNil(LStore);
    Exit;
  end;

  try
    LBytes := LRecord.FieldByName(LViewField.FieldNamesForUpdate).AsBytes;
  except
    // If the fallback store was created, free it
    if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
      FreeAndNil(LStore);
    raise;
  end;

  if Length(LBytes) = 0 then
  begin
    if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
      FreeAndNil(LStore);
    TKWebResponse.Current.StatusCode := 404;
    TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
    TKWebResponse.Current.ReplaceContentStream(TStringStream.Create('{"error":"File not found"}', TEncoding.UTF8));
    Exit;
  end;

  // Detect image format
  LExt := GetDataType(LBytes, 'dat');
  if SameText(LExt, 'jpg') then
    LContentType := 'image/jpeg'
  else if SameText(LExt, 'png') then
    LContentType := 'image/png'
  else if SameText(LExt, 'gif') then
    LContentType := 'image/gif'
  else if SameText(LExt, 'bmp') then
    LContentType := 'image/bmp'
  else if SameText(LExt, 'tif') then
    LContentType := 'image/tiff'
  else
    LContentType := 'application/octet-stream';

  LIsDownload := SameText(TKWebRequest.Current.GetQueryField('download'), '1');
  LFileName := AViewName + '_' + AFieldName + '.' + LExt;

  LStream := TBytesStream.Create(LBytes);
  if LIsDownload then
    LApp.DownloadStream(LStream, LFileName, LContentType, False)
  else
    LApp.DownloadStream(LStream, LFileName, LContentType, True);

  // Free fallback store (session store is owned by session, don't free it)
  if not Assigned(TKWebSession.Current.FindStore(AViewName)) then
    FreeAndNil(LStore);
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXViewHandlerBase);

finalization
  TKXResourceRegistry.Instance.UnregisterResource(TKXViewHandlerBase);

end.
