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
///  KittoX Form controller — renders a modal form dialog for CRUD operations.
///  Processes layout YAML to build form fields (text, number, date, checkbox,
///  reference selects), grouped in rows and fieldsets.
///  Phase 2a: All simple editors + reference <select> for all FK fields.
/// </summary>
unit Kitto.Html.Form;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Html.DataPanel,
  Kitto.Html.Controller,
  Kitto.Metadata.DataView,
  Kitto.Metadata.Views,
  Kitto.Store;

const
  DEFAULT_DETAIL_PANEL_HEIGHT = 200;
  DEFAULT_DETAIL_STYLE = 'Tabs';

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXFormPanelController = class(TKXDataPanelController)
  strict private
  const
    // Default scale factors (configurable via Config/Defaults/Layout/Char_Width_Factor|Char_Height_Factor).
    // Kitto1 used narrower glyphs and tighter line heights; override < 1.0 to match Kitto1 look.
    DEFAULT_CHAR_WIDTH_FACTOR = 1.0;
    DEFAULT_CHAR_HEIGHT_FACTOR = 1.0;
    // Default layout width limits (configurable via Config/Defaults/Layout)
    LAYOUT_MEMOWIDTH = 60;
    LAYOUT_MAXFIELDWIDTH = 60;
    LAYOUT_MINFIELDWIDTH = 5;
    // Default label width in pixels (configurable via Config/Defaults/FormPanel/LabelWidth)
    FORM_LABELWIDTH = 120;
    // Default required label template and label separator
    DEFAULT_REQUIREDLABELTEMPLATE = '<b>{label}*</b>';
    DEFAULT_LABELSEPARATOR = ':';
    // Threshold for rendering a string field as textarea (same as Kitto1)
    MULTILINE_EDIT_THRESHOLD = 200;
  strict private
    FOperation: string;
    FLabelWidth: Integer;
    FLabelAlign: string;
    FLabelSeparator: string;
    FRequiredLabelTemplate: string;
    FViewName: string;
    FRecord: TKViewTableRecord;
    FIsViewMode: Boolean;
    FMemoWidth: Integer;
    FMaxFieldWidth: Integer;
    FMinFieldWidth: Integer;
    FCharWidthFactor: Double;
    FCharHeightFactor: Double;
    FFKFieldName: string;

    function RenderEditor(AViewField: TKViewField;
      ALayoutNode: TEFNode): string;
    procedure RenderPictureEditor(SB: TStringBuilder;
      AViewField: TKViewField; const AFieldName: string);
    function GetRecordKeyString: string;
    function RenderReferenceSelect(AViewField: TKViewField): string;
    function RenderLargeReferenceEditor(AViewField: TKViewField;
      AInputName, AInputId: string; AIsReadOnly: Boolean;
      AWidthStyle: string): string;
    function RenderLayoutNode(ANode: TEFNode;
      AViewTable: TKViewTable): string;
    function RenderTabbedLayout(ALayout: TKLayout;
      AViewTable: TKViewTable; AIncludeDetails: Boolean): string;
    function RenderFormButtons: string;
    function RenderFormToolViews: string;
    function GetFieldValue(AField: TKViewTableField;
      AViewField: TKViewField): string;
  strict protected
    function GetDefaultIsModal: Boolean; override;
    function GetPanelCssClass: string; override;
    procedure DoDisplay; override;
    function RenderContent: string; override;
  public
    [YamlNode('Operation', 'edit', 'Form operation mode (add/edit/view/dup)')]
    property Operation: string read FOperation write FOperation;
    property FormRecord: TKViewTableRecord read FRecord write FRecord;
    property FKFieldName: string read FFKFieldName write FFKFieldName;
  end;

implementation

uses
  System.Classes,
  System.StrUtils,
  System.Variants,
  System.Math,
  System.NetEncoding,
  Data.DB,
  EF.Types,
  EF.DB,
  EF.Localization,
  EF.Macros,
  Kitto.Metadata,
  Kitto.Config,
  Kitto.SQL,
  Kitto.Metadata.Models,
  Kitto.Html.Base,
  Kitto.Html.Editors,
  Kitto.Html.Tools,
  Kitto.Html.Utils,
  Kitto.Web.Session;

/// <summary>Returns HTML attributes for client-side field rules
/// (ForceUpperCase, ForceLowerCase, ForceCamelCaps, MinValue, MaxValue, MaxLength).
/// These are applied as oninput/pattern/min/max attributes on the input element.</summary>
function GetFieldRuleAttrs(AViewField: TKViewField): string;
var
  LRules: TKRules;
  I: Integer;
  LRule: TKRule;
begin
  Result := '';
  // ViewField rules take priority; fall back to ModelField rules
  LRules := AViewField.Rules;
  if (LRules.RuleCount = 0) and Assigned(AViewField.ModelField) then
    LRules := AViewField.ModelField.Rules;
  for I := 0 to LRules.RuleCount - 1 do
  begin
    LRule := LRules[I];
    if SameText(LRule.Name, 'ForceUpperCase') then
      Result := Result + ' oninput="this.value=this.value.toUpperCase()" data-case="upper"'
    else if SameText(LRule.Name, 'ForceLowerCase') then
      Result := Result + ' oninput="this.value=this.value.toLowerCase()" data-case="lower"'
    else if SameText(LRule.Name, 'ForceCamelCaps') then
      Result := Result + ' oninput="this.value=this.value.replace(/\b\w/g,function(c){return c.toUpperCase()})" data-case="capitalize"'
    else if SameText(LRule.Name, 'MinValue') and (LRule.AsString <> '') then
      Result := Result + ' min="' + LRule.AsString + '"'
    else if SameText(LRule.Name, 'MaxValue') and (LRule.AsString <> '') then
      Result := Result + ' max="' + LRule.AsString + '"';
    // MaxLength is already handled by RenderTextInput via AMaxLength parameter
  end;
end;

{ TKXFormPanelController }

function TKXFormPanelController.GetDefaultIsModal: Boolean;
begin
  Result := True;
end;

function TKXFormPanelController.GetPanelCssClass: string;
begin
  Result := 'kx-form-panel';
end;

procedure TKXFormPanelController.DoDisplay;
var
  LEditControllerNode: TEFNode;
  LDefaultLayoutNode: TEFNode;
  LFormLayout: TKLayout;
begin
  FOperation := Config.GetExpandedString('Operation', 'edit');
  FIsViewMode := SameText(FOperation, 'view');

  // Read layout defaults from Config/Defaults/Layout (same as Kitto1 TKExtLayoutDefaults.Init)
  LDefaultLayoutNode := TKConfig.Instance.Config.FindNode('Defaults/Layout');
  if Assigned(LDefaultLayoutNode) then
  begin
    FMemoWidth := LDefaultLayoutNode.GetInteger('MemoWidth', LAYOUT_MEMOWIDTH);
    FMaxFieldWidth := LDefaultLayoutNode.GetInteger('MaxFieldWidth', LAYOUT_MAXFIELDWIDTH);
    FMinFieldWidth := LDefaultLayoutNode.GetInteger('MinFieldWidth', LAYOUT_MINFIELDWIDTH);
    FRequiredLabelTemplate := LDefaultLayoutNode.GetString('RequiredLabelTemplate', DEFAULT_REQUIREDLABELTEMPLATE);
    FLabelSeparator := LDefaultLayoutNode.GetString('LabelSeparator', DEFAULT_LABELSEPARATOR);
    FCharWidthFactor := LDefaultLayoutNode.GetFloat('Char_Width_Factor', DEFAULT_CHAR_WIDTH_FACTOR);
    FCharHeightFactor := LDefaultLayoutNode.GetFloat('Char_Height_Factor', DEFAULT_CHAR_HEIGHT_FACTOR);
  end
  else
  begin
    FMemoWidth := LAYOUT_MEMOWIDTH;
    FMaxFieldWidth := LAYOUT_MAXFIELDWIDTH;
    FMinFieldWidth := LAYOUT_MINFIELDWIDTH;
    FRequiredLabelTemplate := DEFAULT_REQUIREDLABELTEMPLATE;
    FLabelSeparator := DEFAULT_LABELSEPARATOR;
    FCharWidthFactor := DEFAULT_CHAR_WIDTH_FACTOR;
    FCharHeightFactor := DEFAULT_CHAR_HEIGHT_FACTOR;
  end;

  // LabelWidth: global default from Config.yaml, overridable per-view via EditController/LabelWidth
  // (same as Kitto1: Session.Config.Config.GetInteger('Defaults/FormPanel/LabelWidth', FORM_LABELWIDTH))
  FLabelWidth := TKConfig.Instance.Config.GetInteger('Defaults/FormPanel/LabelWidth', FORM_LABELWIDTH);

  // Read EditController config from ViewTable
  if Assigned(ViewTable) then
  begin
    LEditControllerNode := ViewTable.FindNode('EditController');
    if Assigned(LEditControllerNode) then
    begin
      // Override width/height from EditController if not already set in Config
      if Config.GetInteger('Width', 0) = 0 then
        Config.SetInteger('Width', LEditControllerNode.GetInteger('Width', 0));
      if Config.GetInteger('Height', 0) = 0 then
        Config.SetInteger('Height', LEditControllerNode.GetInteger('Height', 0));
      FLabelWidth := LEditControllerNode.GetInteger('LabelWidth', FLabelWidth);
      // Copy CloneButton / KeepOpenAfterOperation from EditController to Config.
      // In Kitto YAML, a node present with empty value (e.g. "CloneButton:") means True.
      if not Config.HasChild('CloneButton') and Assigned(LEditControllerNode.FindNode('CloneButton')) then
        Config.SetBoolean('CloneButton', LEditControllerNode.GetString('CloneButton', 'True') <> 'False');
      if not Config.HasChild('KeepOpenAfterOperation') and Assigned(LEditControllerNode.FindNode('KeepOpenAfterOperation')) then
        Config.SetBoolean('KeepOpenAfterOperation', LEditControllerNode.GetString('KeepOpenAfterOperation', 'True') <> 'False');
    end;
    // LabelAlign/LabelWidth logic matching Kitto1:
    // Kitto.Ext.Form.pas InitFlags sets FLabelAlign default,
    // then Kitto.Ext.Editors.pas InitLabelAlignAndWidth overrides from layout file.
    // Priority: Layout file > EditController > mobile detection > default ('right')
    LFormLayout := ViewTable.FindLayout('Form');
    if Assigned(LFormLayout) then
    begin
      FLabelAlign := LFormLayout.GetString('LabelAlign', 'top');
      FLabelWidth := LFormLayout.GetInteger('LabelWidth', FLabelWidth);
    end
    else if Assigned(LEditControllerNode) and Assigned(LEditControllerNode.FindNode('LabelAlign')) then
      FLabelAlign := LEditControllerNode.GetString('LabelAlign')
    else if TKWebSession.Current.IsMobileBrowser then
      FLabelAlign := 'top'
    else
      FLabelAlign := 'right';
  end
  else
  begin
    FLabelAlign := 'right';
  end;

  if Assigned(View) then
    FViewName := View.PersistentName;

  inherited;

  // Set title based on operation (must be after inherited to override
  // TKXPanelControllerBase.DoDisplay which sets Title from View.DisplayLabel)
  if Assigned(ViewTable) then
  begin
    if SameText(FOperation, 'add') then
      Title := Format(_('Add %s'), [_(ViewTable.DisplayLabel)])
    else if SameText(FOperation, 'edit') then
      Title := Format(_('Edit %s'), [_(ViewTable.DisplayLabel)])
    else if SameText(FOperation, 'view') then
      Title := Format(_('View %s'), [_(ViewTable.DisplayLabel)])
    else if SameText(FOperation, 'dup') then
      Title := Format(_('Duplicate %s'), [_(ViewTable.DisplayLabel)]);
  end;
end;

function TKXFormPanelController.GetFieldValue(AField: TKViewTableField;
  AViewField: TKViewField): string;
begin
  Result := '';
  if not Assigned(AField) then
    Exit;

  try
    if AField.IsNull then
      Exit;
    if AViewField.DataType is TEFDateDataType then
      Result := FormatDateTime('yyyy-mm-dd', AField.AsDateTime)
    else if AViewField.DataType is TEFTimeDataType then
      Result := FormatDateTime('hh:nn', AField.AsDateTime)
    else if AViewField.DataType is TEFDateTimeDataType then
      Result := FormatDateTime('yyyy-mm-dd', AField.AsDateTime) // date part
    else if AViewField.DataType is TEFBooleanDataType then
      Result := IfThen(AField.AsBoolean, 'true', 'false')
    else if AViewField.DataType is TEFCurrencyDataType then
    begin
      // Format with user decimal separator, no thousand separator, with symbol
      var LEditFmt := TKConfig.Instance.UserFormatSettings;
      LEditFmt.ThousandSeparator := #0;
      Result := FormatFloat('0.' + DupeString('0',
        LEditFmt.CurrencyDecimals), AField.AsCurrency, LEditFmt);
      if LEditFmt.CurrencyString <> '' then
        Result := LEditFmt.CurrencyString + ' ' + Result;
    end
    else
      Result := AField.AsString;
  except
    Result := '';
  end;
end;

function TKXFormPanelController.GetRecordKeyString: string;
var
  I: Integer;
  LField: TKViewField;
  LRecordField: TKViewTableField;
  SB: TStringBuilder;
begin
  Result := '';
  if not Assigned(FRecord) or not Assigned(View) or not (View is TKDataView) then
    Exit;
  SB := TStringBuilder.Create;
  try
    for I := 0 to TKDataView(View).MainTable.FieldCount - 1 do
    begin
      LField := TKDataView(View).MainTable.Fields[I];
      if LField.IsKey then
      begin
        LRecordField := FRecord.FindField(LField.AliasedName);
        if Assigned(LRecordField) then
        begin
          if SB.Length > 0 then
            SB.Append('&');
          SB.Append(TNetEncoding.URL.Encode(LField.AliasedName));
          SB.Append('=');
          SB.Append(TNetEncoding.URL.Encode(LRecordField.AsString));
        end;
      end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure TKXFormPanelController.RenderPictureEditor(SB: TStringBuilder;
  AViewField: TKViewField; const AFieldName: string);
var
  LThumbW, LThumbH: Integer;
  LHasImage: Boolean;
  LRecordField: TKViewTableField;
  LUploadIcon, LDownloadIcon, LClearIcon: string;
begin
  LThumbW := AViewField.GetInteger('IsPicture/Thumbnail/Width', 150);
  LThumbH := AViewField.GetInteger('IsPicture/Thumbnail/Height', 150);

  LRecordField := nil;
  if Assigned(FRecord) then
    LRecordField := FRecord.FindField(AFieldName);
  LHasImage := Assigned(LRecordField) and not LRecordField.IsNull;

  LUploadIcon := GetIconHTML('upload');
  LDownloadIcon := GetIconHTML('download');
  LClearIcon := GetIconHTML('clear');

  SB.Append('<div class="kx-picture-editor" id="kx-pic-')
    .Append(FViewName).Append('-').Append(AFieldName).Append('">');

  // Preview area
  SB.Append('<div class="kx-picture-preview" style="width:')
    .Append(IntToStr(LThumbW)).Append('px;height:')
    .Append(IntToStr(LThumbH)).Append('px">');
  SB.Append('<img id="kx-pic-img-').Append(FViewName).Append('-').Append(AFieldName).Append('"');
  if LHasImage then
    SB.Append(' src="kx/view/').Append(FViewName).Append('/blob/')
      .Append(AFieldName).Append('?key=')
      .Append(TNetEncoding.URL.Encode(GetRecordKeyString)).Append('"')
  else
    SB.Append(' style="display:none"');
  SB.Append(' />');
  SB.Append('</div>');

  // Buttons (hidden in view mode)
  if not FIsViewMode then
  begin
    SB.Append('<div class="kx-picture-buttons">');
    // Upload button
    SB.Append('<button type="button" class="kx-toolbar-btn" title="')
      .Append(TNetEncoding.HTML.Encode(_('Upload')))
      .Append('" onclick="kxForm.uploadPicture(''')
      .Append(FViewName).Append(''',''').Append(AFieldName).Append(''')">');
    SB.Append(LUploadIcon).Append('</button>');
    // Download button
    SB.Append('<button type="button" class="kx-toolbar-btn" title="')
      .Append(TNetEncoding.HTML.Encode(_('Download')))
      .Append('" onclick="kxForm.downloadPicture(''')
      .Append(FViewName).Append(''',''').Append(AFieldName).Append(''')"');
    if not LHasImage then SB.Append(' disabled');
    SB.Append('>');
    SB.Append(LDownloadIcon).Append('</button>');
    // Clear button
    SB.Append('<button type="button" class="kx-toolbar-btn" title="')
      .Append(TNetEncoding.HTML.Encode(_('Clear')))
      .Append('" onclick="kxForm.clearPicture(''')
      .Append(FViewName).Append(''',''').Append(AFieldName).Append(''')"');
    if not LHasImage then SB.Append(' disabled');
    SB.Append('>');
    SB.Append(LClearIcon).Append('</button>');
    SB.Append('</div>');
  end
  else if LHasImage then
  begin
    // View mode: only Download button if there's an image
    SB.Append('<div class="kx-picture-buttons">');
    SB.Append('<button type="button" class="kx-toolbar-btn" title="')
      .Append(TNetEncoding.HTML.Encode(_('Download')))
      .Append('" onclick="kxForm.downloadPicture(''')
      .Append(FViewName).Append(''',''').Append(AFieldName).Append(''')">');
    SB.Append(LDownloadIcon).Append('</button>');
    SB.Append('</div>');
  end;

  // Hidden file input + clear flag
  SB.Append('<input type="file" id="kx-pic-file-').Append(FViewName).Append('-').Append(AFieldName)
    .Append('" name="').Append(TNetEncoding.HTML.Encode(AFieldName))
    .Append('" accept="image/*" style="display:none"')
    .Append(' onchange="kxForm.onPictureSelected(''').Append(FViewName).Append(''',''')
    .Append(AFieldName).Append(''')" />');
  SB.Append('<input type="hidden" name="').Append(TNetEncoding.HTML.Encode(AFieldName))
    .Append('__clear" id="kx-pic-clear-').Append(FViewName).Append('-').Append(AFieldName)
    .Append('" value="" />');

  SB.Append('</div>');
end;

function TKXFormPanelController.RenderReferenceSelect(
  AViewField: TKViewField): string;
var
  LDBConnection: TEFDBConnection;
  LDBQuery: TEFDBQuery;
  LSQLBuilder: TKSQLBuilder;
  LKeyValue, LCaptionValue, LCurrentKeyValue: string;
  LRecordField: TKViewTableField;
  LModelField: TKModelField;
  LEmptyRecord: TKViewTableRecord;
  LStore: TKViewTableStore;
  SB: TStringBuilder;
begin
  LModelField := AViewField.ModelField;
  if not Assigned(LModelField) or not LModelField.IsReference then
  begin
    Result := '<option value="">--</option>';
    Exit;
  end;

  // Get current FK value to pre-select
  // For reference fields, the FK value is stored under the sub-field name
  // (e.g. PHASE_ID), not the reference name (PHASE).
  LCurrentKeyValue := '';
  if Assigned(FRecord) then
  begin
    LRecordField := FRecord.FindField(AViewField.FieldNamesForUpdate);
    if Assigned(LRecordField) and not LRecordField.IsNull then
      LCurrentKeyValue := LRecordField.AsString;
  end;

  // Create a temporary store+record for BuildLookupSelectStatement
  // (it needs a record for expression expansion)
  LStore := ViewTable.CreateStore;
  try
    if Assigned(FRecord) then
      LEmptyRecord := FRecord
    else if LStore.RecordCount > 0 then
      LEmptyRecord := LStore.Records[0]
    else
    begin
      LEmptyRecord := LStore.Records.AppendAndInitialize;
    end;

    LDBConnection := TKConfig.Instance.CreateDBConnection(
      ViewTable.DatabaseName);
    try
      LDBQuery := LDBConnection.CreateDBQuery;
      try
        LSQLBuilder := TKSQLBuilder.Create;
        try
          LSQLBuilder.BuildLookupSelectStatement(AViewField, LDBQuery, '', LEmptyRecord);
        finally
          FreeAndNil(LSQLBuilder);
        end;

        LDBQuery.Open;
        try
          SB := TStringBuilder.Create;
          try
            SB.Append('<option value="">--</option>');
            var LFound := False;
            while not LDBQuery.DataSet.Eof do
            begin
              // First field(s) = key, last field = caption (if distinct from key)
              LKeyValue := LDBQuery.DataSet.Fields[0].AsString;
              if LDBQuery.DataSet.FieldCount > 1 then
                LCaptionValue := LDBQuery.DataSet.Fields[LDBQuery.DataSet.FieldCount - 1].AsString
              else
                LCaptionValue := LKeyValue;

              SB.Append('<option value="').Append(TNetEncoding.HTML.Encode(LKeyValue)).Append('"');
              if SameText(LKeyValue, LCurrentKeyValue) then
              begin
                SB.Append(' selected');
                LFound := True;
              end;
              SB.Append('>').Append(TNetEncoding.HTML.Encode(LCaptionValue)).Append('</option>');

              LDBQuery.DataSet.Next;
            end;
            // If the current value was not found in DB options (e.g. new master
            // record not yet persisted), add a synthetic selected option.
            // Try to find a display caption from the session store.
            if (LCurrentKeyValue <> '') and not LFound then
            begin
              LCaptionValue := LCurrentKeyValue; // fallback: show key
              // Search session stores for a record whose key matches
              var LRefModel := LModelField.ReferencedModel;
              if Assigned(LRefModel) then
              begin
                var LCaptionField := LRefModel.FindCaptionField;
                // Try to find the master record in any session store
                var LSessionStore := TKWebSession.Current.FindStore(FViewName);
                // The FK points to the master, which might be in a different view's store
                // Search all session stores would be expensive; use the master form's store
                // by looking at the caption field on the referenced model
                if Assigned(LCaptionField) and Assigned(LSessionStore) and (LSessionStore.RecordCount > 0) then
                begin
                  // This is a detail form; check if the FK value matches the master's key
                  var LMasterRec := LSessionStore.Records[0];
                  var LMasterKeyField := LMasterRec.FindField(AViewField.FieldNamesForUpdate);
                  if Assigned(LMasterKeyField) and SameText(LMasterKeyField.AsString, LCurrentKeyValue) then
                  begin
                    var LCapField := LMasterRec.FindField(LCaptionField.FieldName);
                    if Assigned(LCapField) and not LCapField.IsNull then
                      LCaptionValue := LCapField.AsString;
                  end;
                end;
              end;
              SB.Append('<option value="').Append(TNetEncoding.HTML.Encode(LCurrentKeyValue))
                .Append('" selected>').Append(TNetEncoding.HTML.Encode(LCaptionValue))
                .Append('</option>');
            end;
            Result := SB.ToString;
          finally
            SB.Free;
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
  finally
    // Always free the temp lookup store (FRecord belongs to a different store)
    FreeAndNil(LStore);
  end;
end;

/// <summary>
///  Finds the lookup view name for a large reference field, mirroring
///  TKExtLookupField.FindLookupView logic: searches the catalog for a
///  TKDataView with IsLookup=True whose MainTable.Model matches the
///  referenced model. Returns '' if not found.
/// </summary>
function FindLookupViewName(AViewField: TKViewField): string;
var
  LRefModel: TKModel;
  LView: TKView;
begin
  Result := '';
  if not Assigned(AViewField.ModelField) then
    Exit;
  LRefModel := AViewField.ModelField.ReferencedModel;
  if not Assigned(LRefModel) then
    Exit;
  LView := AViewField.Table.View.Catalog.FindObjectByPredicate(
    function(const AObject: TKMetadata): Boolean
    begin
      Result := (AObject is TKDataView) and AObject.GetBoolean('IsLookup')
        and (TKDataView(AObject).MainTable.Model = LRefModel);
    end) as TKView;
  if Assigned(LView) then
    Result := LView.PersistentName;
end;

function TKXFormPanelController.RenderLargeReferenceEditor(
  AViewField: TKViewField; AInputName, AInputId: string;
  AIsReadOnly: Boolean; AWidthStyle: string): string;
var
  LDBConnection: TEFDBConnection;
  LDBQuery: TEFDBQuery;
  LSQLBuilder: TKSQLBuilder;
  LKeyValue, LCaptionValue, LCurrentKeyValue, LCurrentCaption: string;
  LRecordField: TKViewTableField;
  LStore: TKViewTableStore;
  LEmptyRecord: TKViewTableRecord;
  LOptionsJSON: string;
  LSearchIcon, LClearIcon: string;
  LFieldName: string;
  LLookupViewName: string;
  LRefModel: TKModel;
  LCaptionField: TKModelField;
  LCaptionFieldName: string;
  LHiddenAttrs: string;
  SB: TStringBuilder;

  function JSONEncodeStr(const S: string): string;
  begin
    Result := StringReplace(S, '\', '\\', [rfReplaceAll]);
    Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
    Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
    Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  end;
begin
  LFieldName := AViewField.AliasedName;

  // Get current FK value
  LCurrentKeyValue := '';
  LCurrentCaption := '';
  if Assigned(FRecord) then
  begin
    LRecordField := FRecord.FindField(AViewField.FieldNamesForUpdate);
    if Assigned(LRecordField) and not LRecordField.IsNull then
      LCurrentKeyValue := LRecordField.AsString;
  end;

  // Check for a dedicated lookup view (IsLookup: True) for the referenced model
  LLookupViewName := FindLookupViewName(AViewField);

  if LLookupViewName <> '' then
  begin
    // Lookup view exists: emit data-lookup-view + data-caption-field on hidden input.
    // Only load the current record's caption (not all records).
    LRefModel := AViewField.ModelField.ReferencedModel;
    LCaptionField := LRefModel.FindCaptionField;
    if Assigned(LCaptionField) then
      LCaptionFieldName := LCaptionField.FieldName
    else
      LCaptionFieldName := '';

    // Load caption for the current FK value (single record lookup)
    if (LCurrentKeyValue <> '') and (LCaptionFieldName <> '') then
    begin
      LDBConnection := TKConfig.Instance.CreateDBConnection(
        LRefModel.DatabaseName);
      try
        LDBQuery := LDBConnection.CreateDBQuery;
        try
          LDBQuery.CommandText :=
            'SELECT ' + LCaptionField.DBColumnNameOrExpression +
            ' FROM ' + LRefModel.DBTableName +
            ' WHERE ' + LRefModel.KeyFields[0].DBColumnNameOrExpression +
            ' = ''' + ReplaceStr(LCurrentKeyValue, '''', '''''') + '''';
          LDBQuery.Open;
          try
            if not LDBQuery.DataSet.Eof then
              LCurrentCaption := LDBQuery.DataSet.Fields[0].AsString;
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

    LHiddenAttrs :=
      ' data-lookup-view="' + TNetEncoding.HTML.Encode(LLookupViewName) + '"' +
      ' data-caption-field="' + TNetEncoding.HTML.Encode(LCaptionFieldName) + '"';
  end
  else
  begin
    // No lookup view: fall back to loading all records into data-options JSON
    LStore := ViewTable.CreateStore;
    try
      if Assigned(FRecord) then
        LEmptyRecord := FRecord
      else if LStore.RecordCount > 0 then
        LEmptyRecord := LStore.Records[0]
      else
        LEmptyRecord := LStore.Records.AppendAndInitialize;

      LDBConnection := TKConfig.Instance.CreateDBConnection(
        ViewTable.DatabaseName);
      try
        LDBQuery := LDBConnection.CreateDBQuery;
        try
          LSQLBuilder := TKSQLBuilder.Create;
          try
            LSQLBuilder.BuildLookupSelectStatement(AViewField, LDBQuery, '',
              LEmptyRecord);
          finally
            FreeAndNil(LSQLBuilder);
          end;

          LDBQuery.Open;
          try
            SB := TStringBuilder.Create;
            try
              SB.Append('[');
              while not LDBQuery.DataSet.Eof do
              begin
                LKeyValue := LDBQuery.DataSet.Fields[0].AsString;
                if LDBQuery.DataSet.FieldCount > 1 then
                  LCaptionValue := LDBQuery.DataSet.Fields[
                    LDBQuery.DataSet.FieldCount - 1].AsString
                else
                  LCaptionValue := LKeyValue;

                // Match current FK value to get display caption
                if SameText(LKeyValue, LCurrentKeyValue) then
                  LCurrentCaption := LCaptionValue;

                // Build JSON option entry
                if SB.Length > 1 then
                  SB.Append(',');
                SB.Append('{"k":"').Append(JSONEncodeStr(LKeyValue));
                SB.Append('","c":"').Append(JSONEncodeStr(LCaptionValue)).Append('"}');

                LDBQuery.DataSet.Next;
              end;
              SB.Append(']');
              LOptionsJSON := SB.ToString;
            finally
              SB.Free;
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
    finally
      FreeAndNil(LStore);
    end;

    LHiddenAttrs :=
      ' data-options="' + TNetEncoding.HTML.Encode(LOptionsJSON) + '"';
  end;

  // Build icons
  LSearchIcon := GetIconHTML('search');
  LClearIcon := GetIconHTML('cancel');

  // Build HTML via factory
  var LCtx: TKXEditorContext;
  LCtx.InputId := AInputId;
  LCtx.InputName := AInputName;
  LCtx.IsReadOnly := AIsReadOnly;
  LCtx.CssInputClass := 'kx-form-input';
  LCtx.TriggerWidthStyle := AWidthStyle;

  Result := TKXEditorFactory.RenderLargeReferenceEditor(LCtx,
    LCurrentKeyValue, LCurrentCaption, LHiddenAttrs,
    LSearchIcon, LClearIcon,
    'kxForm', FViewName, LFieldName);
end;

function TKXFormPanelController.RenderEditor(AViewField: TKViewField;
  ALayoutNode: TEFNode): string;
var
  LFieldName, LInputName, LInputId: string;
  LValue, LLabel: string;
  LCharWidth, LEffWidth, LLines: Integer;
  LIsRequired, LIsReadOnly: Boolean;
  LRecordField: TKViewTableField;
  LAllowedValues: TEFPairs;
  LFieldCss, LWidthStyle, LTriggerWidthStyle: string;
  LLabelStyle: string;
  LTimeValue: string;
  LCtx: TKXEditorContext;
  SB: TStringBuilder;
begin
  LFieldName := AViewField.AliasedName;
  LInputName := AViewField.FieldNamesForUpdate;
  LInputId := 'kx-field-' + FViewName + '-' + LFieldName;

  // Get display label (layout can override)
  LLabel := '';
  if Assigned(ALayoutNode) then
    LLabel := ALayoutNode.GetString('DisplayLabel');
  if LLabel = '' then
  begin
    LLabel := AViewField.DisplayLabel_Form;
    if LLabel = '' then
      LLabel := AViewField.DisplayLabel;
  end;

  // Get field value from record
  LRecordField := nil;
  if Assigned(FRecord) then
    LRecordField := FRecord.FindField(LFieldName);
  LValue := GetFieldValue(LRecordField, AViewField);

  // For dup operation, clear key fields
  if SameText(FOperation, 'dup') and AViewField.IsKey then
    LValue := '';

  // Determine required/readonly
  LIsRequired := AViewField.IsRequired;
  LIsReadOnly := FIsViewMode or AViewField.IsReadOnly
    or ((FFKFieldName <> '') and SameText(AViewField.FieldName, FFKFieldName));

  // CharWidth calculation (aligned with ExtJS TKExtLayoutProcessor logic)
  LCharWidth := AViewField.DisplayWidth;
  if Assigned(ALayoutNode) then
    LCharWidth := ALayoutNode.GetInteger('CharWidth', LCharWidth);
  if LCharWidth = 0 then
    LCharWidth := Min(IfThen(AViewField.Size = 0, FMemoWidth, AViewField.Size),
      FMaxFieldWidth);
  LCharWidth := Max(LCharWidth, FMinFieldWidth);
  // Scale width by configurable factor (Defaults/Layout/Char_Width_Factor, default 1.0)
  LEffWidth := Round(LCharWidth * FCharWidthFactor);

  LWidthStyle := 'width:' + IntToStr(LEffWidth + INPUT_EXTRA_CHS) + 'ch';
  LTriggerWidthStyle := 'width:calc(' + IntToStr(LEffWidth + INPUT_EXTRA_CHS) + 'ch + '
    + IntToStr(TRIGGER_PX) + 'px)';

  // Build CSS class
  LFieldCss := 'kx-form-field';
  if SameText(FLabelAlign, 'top') then
    LFieldCss := LFieldCss + ' kx-form-field-top';
  if LIsReadOnly then
    LFieldCss := LFieldCss + ' kx-form-readonly';

  // Build label style for side-aligned labels (left or right)
  if SameText(FLabelAlign, 'left') then
    LLabelStyle := 'min-width:' + IntToStr(FLabelWidth) + 'px'
  else if SameText(FLabelAlign, 'right') then
    LLabelStyle := 'min-width:' + IntToStr(FLabelWidth) + 'px;text-align:right'
  else
    LLabelStyle := '';

  // Build editor context for the factory
  LCtx.InputId := LInputId;
  LCtx.InputName := LInputName;
  LCtx.Value := LValue;
  LCtx.WidthStyle := LWidthStyle;
  LCtx.TriggerWidthStyle := LTriggerWidthStyle;
  LCtx.IsReadOnly := LIsReadOnly;
  LCtx.IsRequired := LIsRequired;
  LCtx.IsKey := AViewField.IsKey;
  LCtx.ExtraAttrs := GetFieldRuleAttrs(AViewField);
  LCtx.CssInputClass := 'kx-form-input';
  LCtx.EffWidth := LEffWidth;

  SB := TStringBuilder.Create;
  try
    SB.Append('<div class="').Append(LFieldCss).Append('">');
    SB.Append('<label class="kx-form-label"');
    if LLabelStyle <> '' then
      SB.Append(' style="').Append(LLabelStyle).Append('"');
    SB.Append(' for="').Append(LInputId).Append('">');
    if LIsRequired and not LIsReadOnly then
      SB.Append(ReplaceStr(FRequiredLabelTemplate, '{label}', TNetEncoding.HTML.Encode(_(LLabel))))
    else
      SB.Append(TNetEncoding.HTML.Encode(_(LLabel)));
    if FLabelSeparator <> '' then
      SB.Append(TNetEncoding.HTML.Encode(FLabelSeparator));
    SB.Append('</label>');

    // Check for AllowedValues first (static dropdown)
    LAllowedValues := AViewField.AllowedValues;
    if Length(LAllowedValues) > 0 then
    begin
      // Translate display values
      var LTranslated: TEFPairs;
      SetLength(LTranslated, Length(LAllowedValues));
      var I: Integer;
      for I := 0 to Length(LAllowedValues) - 1 do
      begin
        LTranslated[I].Key := LAllowedValues[I].Key;
        LTranslated[I].Value := _(LAllowedValues[I].Value);
      end;
      SB.Append(TKXEditorFactory.RenderSelectInput(LCtx, LTranslated, not LIsRequired));
    end
    // Reference field
    else if AViewField.IsReference then
    begin
      if Assigned(AViewField.ModelField) and Assigned(AViewField.ModelField.ReferencedModel)
        and AViewField.ModelField.ReferencedModel.IsLarge then
      begin
        SB.Append(RenderLargeReferenceEditor(AViewField, LInputName, LInputId,
          LIsReadOnly, LTriggerWidthStyle));
      end
      else
      begin
        SB.Append(TKXEditorFactory.RenderSmallReferenceSelect(LCtx,
          RenderReferenceSelect(AViewField)));
      end;
    end
    // IsPicture blob → picture editor widget (stays in Form.pas)
    else if AViewField.IsBlob and AViewField.IsPicture then
    begin
      RenderPictureEditor(SB, AViewField, LFieldName);
    end
    // Memo threshold check for large text fields
    else if not (AViewField.DataType is TEFMemoDataType)
      and not (AViewField.DataType is TKHTMLMemoDataType)
      and (AViewField.Size div SizeOf(Char) >= MULTILINE_EDIT_THRESHOLD) then
    begin
      LLines := AViewField.GetInteger('Lines', 5);
      if Assigned(ALayoutNode) then
        LLines := ALayoutNode.GetInteger('Lines', LLines);
      SB.Append(TKXEditorFactory.RenderMemoInput(LCtx, LLines));
    end
    // All other types: delegate to factory
    else
    begin
      // DateTime needs time value
      if AViewField.DataType is TEFDateTimeDataType then
      begin
        LTimeValue := '';
        if Assigned(LRecordField) and not LRecordField.IsNull then
        begin
          try
            LTimeValue := FormatDateTime('hh:nn', LRecordField.AsDateTime);
          except
            LTimeValue := '';
          end;
        end;
        LCtx.TimeValue := LTimeValue;
      end;

      // Lines for memo/html editors
      LLines := AViewField.GetInteger('Lines', 5);
      if Assigned(ALayoutNode) then
        LLines := ALayoutNode.GetInteger('Lines', LLines);

      SB.Append(TKXEditorFactory.RenderInput(AViewField.DataType, LCtx,
        AViewField.Size,
        AViewField.IsPassword,
        AViewField.UseSpeedButtons,
        TKConfig.Instance.UserFormatSettings.CurrencyDecimals,
        TKConfig.Instance.UserFormatSettings.DecimalSeparator,
        TKConfig.Instance.UserFormatSettings.CurrencyString,
        LLines,
        AViewField.FindNode('HTMLEditor'),
        'kxForm',
        FCharHeightFactor));
    end;

    SB.Append('</div>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXFormPanelController.RenderLayoutNode(ANode: TEFNode;
  AViewTable: TKViewTable): string;
var
  LNodeName, LFieldName: string;
  LViewField: TKViewField;
  I: Integer;
  LChild: TEFNode;
  LTitle: string;
  LCollapsible, LCollapsed: Boolean;
  SB: TStringBuilder;
begin
  Result := '';
  LNodeName := ANode.Name;

  // --- Field ---
  if SameText(LNodeName, 'Field') then
  begin
    LFieldName := ANode.AsString;
    LViewField := AViewTable.FindField(LFieldName);
    if Assigned(LViewField) and LViewField.IsVisible then
      Result := RenderEditor(LViewField, ANode);
  end
  // --- Row ---
  else if SameText(LNodeName, 'Row') then
  begin
    SB := TStringBuilder.Create;
    try
      SB.Append('<div class="kx-form-row">');
      for I := 0 to ANode.ChildCount - 1 do
        SB.Append(RenderLayoutNode(ANode.Children[I], AViewTable));
      SB.Append('</div>');
      Result := SB.ToString;
    finally
      SB.Free;
    end;
  end
  // --- FieldSet ---
  else if SameText(LNodeName, 'FieldSet') then
  begin
    LTitle := _(ANode.GetString('Title', ''));
    LCollapsible := ANode.GetBoolean('Collapsible', False);
    LCollapsed := ANode.GetBoolean('Collapsed', False);

    SB := TStringBuilder.Create;
    try
      SB.Append('<fieldset class="kx-form-fieldset');
      if LCollapsible then
        SB.Append(' kx-form-fieldset-collapsible');
      if LCollapsed then
        SB.Append(' kx-collapsed');
      SB.Append('">');
      if LCollapsible then
      begin
        SB.Append('<legend onclick="this.parentElement.classList.toggle(''kx-collapsed'')">');
        SB.Append('<span class="kx-toggle-icon">');
        SB.Append(GetIconHTML('expand_less'));
        SB.Append('</span>');
        if LTitle <> '' then
          SB.Append(TNetEncoding.HTML.Encode(LTitle))
        else
          SB.Append('&nbsp;');
        SB.Append('</legend>');
      end
      else if LTitle <> '' then
        SB.Append('<legend>').Append(TNetEncoding.HTML.Encode(LTitle)).Append('</legend>');
      SB.Append('<div class="kx-form-fieldset-body">');
      for I := 0 to ANode.ChildCount - 1 do
      begin
        LChild := ANode.Children[I];
        if SameText(LChild.Name, 'Title') or
           SameText(LChild.Name, 'Collapsible') or
           SameText(LChild.Name, 'Collapsed') then
          Continue;
        SB.Append(RenderLayoutNode(LChild, AViewTable));
      end;
      SB.Append('</div></fieldset>');
      Result := SB.ToString;
    finally
      SB.Free;
    end;
  end
  // --- Spacer ---
  else if SameText(LNodeName, 'Spacer') then
  begin
    Result := '<div style="height:8px"></div>';
  end
  // --- PageBreak (handled in RenderTabbedLayout) ---
  else if SameText(LNodeName, 'PageBreak') then
  begin
    // PageBreak nodes are processed by RenderTabbedLayout;
    // if we reach here in single-page mode, skip.
  end;
end;

function TKXFormPanelController.RenderTabbedLayout(ALayout: TKLayout;
  AViewTable: TKViewTable; AIncludeDetails: Boolean): string;
var
  LPageTitles: TStringList;
  LPageContents: TStringList;
  I, LPageIndex, LFieldPageCount: Integer;
  LChild: TEFNode;
  LFirstTitle: string;
  LDetailTable: TKViewTable;
  LDetailViewName, LDisplayLabel: string;
  LDetailView: TKView;
  SB, SBPage: TStringBuilder;
begin
  LPageTitles := TStringList.Create;
  LPageContents := TStringList.Create;
  SBPage := TStringBuilder.Create;
  try
    // Page 0 title: model DisplayLabel or 'General'
    if Assigned(AViewTable) and (AViewTable.DisplayLabel <> '') then
      LFirstTitle := _(AViewTable.DisplayLabel)
    else
      LFirstTitle := _('General');
    LPageTitles.Add(LFirstTitle);

    if Assigned(ALayout) then
    begin
      // Iterate layout children, splitting on PageBreak nodes
      for I := 0 to ALayout.ChildCount - 1 do
      begin
        LChild := ALayout.Children[I];
        if SameText(LChild.Name, 'PageBreak') then
        begin
          // Close current page, start a new one
          LPageContents.Add(SBPage.ToString);
          SBPage.Clear;
          LPageTitles.Add(_(LChild.AsString));
        end
        else
          SBPage.Append(RenderLayoutNode(LChild, AViewTable));
      end;
    end
    else
    begin
      // No layout file: render all visible fields as page 0
      for I := 0 to AViewTable.FieldCount - 1 do
        if AViewTable.Fields[I].IsVisible and
           (not AViewTable.Fields[I].IsBlob or AViewTable.Fields[I].IsPicture) then
          SBPage.Append(RenderEditor(AViewTable.Fields[I], nil));
    end;
    // Add the last form page
    LPageContents.Add(SBPage.ToString);

    // Save field page count before adding detail tabs
    LFieldPageCount := LPageTitles.Count;

    // Append detail tabs (empty content, lazy loaded)
    if AIncludeDetails and Assigned(AViewTable) then
    begin
      for I := 0 to AViewTable.DetailTableCount - 1 do
      begin
        LDetailTable := AViewTable.DetailTables[I];
        LDetailViewName := LDetailTable.GetString('ViewName');
        if LDetailViewName <> '' then
        begin
          LDetailView := TKConfig.Instance.Views.FindView(LDetailViewName);
          if Assigned(LDetailView) then
            LDisplayLabel := _(LDetailView.DisplayLabel)
          else
            LDisplayLabel := _(LDetailTable.DisplayLabel);
        end
        else
          LDisplayLabel := _(LDetailTable.DisplayLabel);
        LPageTitles.Add(LDisplayLabel);
        LPageContents.Add('');
      end;
    end;

    // Build tab strip + page panes
    SB := TStringBuilder.Create;
    try
      SB.Append('<div class="kx-form-tabs">');
      for LPageIndex := 0 to LPageTitles.Count - 1 do
      begin
        SB.Append('<button type="button" class="kx-form-tab');
        if LPageIndex = 0 then
          SB.Append(' kx-form-tab-active');
        SB.Append('" onclick="kxForm.switchTab(''').Append(FViewName).Append(''',');
        SB.Append(IntToStr(LPageIndex)).Append(',');
        SB.Append(IntToStr(LFieldPageCount)).Append(')">');
        SB.Append(TNetEncoding.HTML.Encode(LPageTitles[LPageIndex]));
        SB.Append('</button>');
      end;
      SB.Append('</div>');

      // Build page panes inside a paged form body
      SB.Append('<div class="kx-form-body kx-form-body-paged">');
      for LPageIndex := 0 to LPageContents.Count - 1 do
      begin
        if LPageIndex >= LFieldPageCount then
        begin
          // Detail page pane
          SB.Append('<div class="kx-form-page kx-detail-page" id="kx-detail-');
          SB.Append(FViewName).Append('-').Append(IntToStr(LPageIndex - LFieldPageCount)).Append('"');
        end
        else
        begin
          // Form field page pane
          SB.Append('<div class="kx-form-page" id="kx-form-page-');
          SB.Append(FViewName).Append('-').Append(IntToStr(LPageIndex)).Append('"');
        end;
        if LPageIndex > 0 then
          SB.Append(' style="display:none"');
        SB.Append('>').Append(LPageContents[LPageIndex]).Append('</div>');
      end;
      SB.Append('</div>');
      Result := SB.ToString;
    finally
      SB.Free;
    end;
  finally
    SBPage.Free;
    FreeAndNil(LPageContents);
    FreeAndNil(LPageTitles);
  end;
end;

function TKXFormPanelController.RenderFormToolViews: string;
var
  LToolViewsNode, LToolNode: TEFNode;
  I: Integer;
  LToolName, LToolLabel, LToolImageName, LControllerType: string;
  LToolConfirmMsg, LToolAutoRefresh, LAcceptWildcards, LAcceptAttr: string;
  LParts: TArray<string>;
  J: Integer;
  LControllerClass: TKXComponentClass;
  SB: TStringBuilder;
begin
  Result := '';
  if not Assigned(ViewTable) then Exit;

  LToolViewsNode := ViewTable.FindNode('EditController/ToolViews');
  if not Assigned(LToolViewsNode) or (LToolViewsNode.ChildCount = 0) then Exit;

  SB := TStringBuilder.Create;
  try
    SB.Append('<div class="kx-form-toolviews">');
    for I := 0 to LToolViewsNode.ChildCount - 1 do
    begin
      LToolNode := LToolViewsNode.Children[I];
      LToolName := LToolNode.Name;
      LToolLabel := _(LToolNode.GetString('DisplayLabel', LToolName));
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

      SB.Append('<button type="button" class="kx-form-btn"');
      SB.Append(' title="').Append(TNetEncoding.HTML.Encode(LToolLabel)).Append('"');
      // Data attributes for JS executeTool handler (same as List toolbar)
      SB.Append(' data-view="').Append(FViewName).Append('"');
      SB.Append(' data-tool="').Append(TNetEncoding.HTML.Encode(LToolName)).Append('"');
      if LToolConfirmMsg <> '' then
        SB.Append(' data-confirm="').Append(
          TNetEncoding.HTML.Encode(ReplaceStr(_(Trim(LToolConfirmMsg)), #13#10, ' '))).Append('"');
      if LToolAutoRefresh <> '' then
        SB.Append(' data-autorefresh="').Append(TNetEncoding.HTML.Encode(LToolAutoRefresh)).Append('"');

      // Upload tool detection
      if ContainsText(LControllerType, 'Upload') then
      begin
        SB.Append(' data-upload="true"');
        LAcceptWildcards := LToolNode.GetString('Controller/AcceptedWildcards',
          LToolNode.GetString('Controller/WildCard', ''));
        if LAcceptWildcards <> '' then
        begin
          LAcceptAttr := '';
          LParts := LAcceptWildcards.Split([' ']);
          for J := 0 to Length(LParts) - 1 do
          begin
            if LParts[J] = '*.*' then Continue;
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
      SB.Append(' ').Append(TNetEncoding.HTML.Encode(LToolLabel));
      SB.Append('</button>');
    end;
    SB.Append('</div>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXFormPanelController.RenderFormButtons: string;
var
  LSaveIcon, LCancelIcon, LCloseIcon, LEditIcon: string;
  LAddIcon, LDeleteIcon, LCloneIcon: string;
  LDisplayLabel: string;
  LConfirmTitle, LConfirmMsg, LYesLabel, LNoLabel: string;
  LHasDetails: Boolean;
  LViewHide, LEditHide: string;
begin
  LSaveIcon := GetIconHTML('save', isMedium);
  LCancelIcon := GetIconHTML('cancel', isMedium);
  LCloseIcon := GetIconHTML('close', isMedium);
  LEditIcon := GetIconHTML('edit_record', isMedium);

  LHasDetails := Assigned(ViewTable) and (ViewTable.DetailTableCount > 0);
  LDisplayLabel := '';
  if Assigned(ViewTable) then
    LDisplayLabel := _(ViewTable.DisplayLabel);

  // Initial visibility: hide the group that doesn't match the current operation
  if FIsViewMode then
  begin
    LViewHide := '';          // ViewMode buttons visible
    LEditHide := ' style="display:none"'; // EditMode buttons hidden
  end
  else
  begin
    LViewHide := ' style="display:none"'; // ViewMode buttons hidden
    LEditHide := '';          // EditMode buttons visible
  end;

  Result := '<div class="kx-form-toolbar">';

  // Help button (always visible if configured, before all other buttons)
  var LShowHelp: Boolean;
  var LHelpHRef, LHelpHRefStyle, LHelpShort, LHelpLong: string;
  TKConfig.Instance.GetHelpSupport(LShowHelp, LHelpHRef, LHelpHRefStyle, LHelpShort, LHelpLong);
  if LShowHelp then
  begin
    var LHelpUrl: string;
    if Assigned(View) and (View.PersistentName <> '') then
      LHelpUrl := Format(LHelpHRef, [View.PersistentName])
    else if Assigned(ViewTable) then
      LHelpUrl := Format(LHelpHRef, [ViewTable.ModelName]);
    // Append table model name after colon (for detail context)
    if Assigned(ViewTable) and (ViewTable.ModelName <> '') then
      LHelpUrl := LHelpUrl + ':' + ViewTable.ModelName;
    LHelpLong := Format(LHelpLong, [LDisplayLabel]);
    Result := Result +
      '<button type="button" class="kx-form-btn kx-form-btn-help"' +
      ' title="' + TNetEncoding.HTML.Encode(LHelpLong) + '"' +
      ' onclick="window.open(''' + TNetEncoding.HTML.Encode(LHelpUrl) + ''',''_blank'')">' +
      GetIconHTML('help', isMedium) + ' ' + TNetEncoding.HTML.Encode(LHelpShort) +
      '</button>';
  end;

  // ===== ViewMode buttons =====

  // Edit button (ViewMode) — switches to EditMode client-side
  if LHasDetails or IsActionAllowed('Edit') then
    Result := Result +
      '<button type="button" class="kx-form-btn kx-form-btn-save kx-btn-viewmode"' + LViewHide +
      ' onclick="kxForm.setMode(''' + FViewName + ''',''edit'')">' +
      LEditIcon + ' ' + TNetEncoding.HTML.Encode(_('Edit')) +
      '</button>';

  // Add button (ViewMode, simple forms only)
  if not LHasDetails and IsActionAllowed('Add') then
  begin
    LAddIcon := GetIconHTML('new_record', isMedium);
    Result := Result +
      '<button type="button" class="kx-form-btn kx-btn-viewmode"' + LViewHide +
      ' onclick="kxForm.cancel(''' + FViewName + ''');' +
      'kxGrid.openForm(''' + FViewName + ''',''add'')">' +
      LAddIcon + ' ' + TNetEncoding.HTML.Encode(_('Add')) +
      '</button>';
  end;

  // Delete button (ViewMode, simple forms only)
  if not LHasDetails and IsActionAllowed('Delete') then
  begin
    LDeleteIcon := GetIconHTML('delete_record', isMedium);
    LConfirmTitle := ReplaceStr(_('Confirm'), '''', '\''');
    LConfirmMsg := ReplaceStr(
      Format(_('Selected %s will be deleted. Are you sure?'), [LDisplayLabel]),
      '''', '\''');
    LYesLabel := ReplaceStr(_('Yes'), '''', '\''');
    LNoLabel := ReplaceStr(_('No'), '''', '\''');
    Result := Result +
      '<button type="button" class="kx-form-btn kx-form-btn-delete kx-btn-viewmode"' + LViewHide +
      ' onclick="kxForm.deleteAndClose(''' + FViewName + ''',''' +
      LConfirmTitle + ''',''' + LConfirmMsg + ''',''' +
      LYesLabel + ''',''' + LNoLabel + ''')">' +
      LDeleteIcon + ' ' + TNetEncoding.HTML.Encode(_('Delete')) +
      '</button>';
  end;

  // Save All button (detail forms only, initially hidden, enabled when pending changes exist)
  // Visible in BOTH ViewMode and EditMode — not tied to a mode group.
  if LHasDetails then
    Result := Result +
      '<button type="button" class="kx-form-btn kx-form-btn-saveall kx-btn-pending"' +
      ' style="display:none" disabled' +
      ' onclick="kxForm.saveAll(''' + FViewName + ''',''edit'')">' +
      GetIconHTML('save_as', isMedium) + ' ' + TNetEncoding.HTML.Encode(_('Save All')) +
      '</button>';

  // Close button (ViewMode) — only if AllowClose
  if AllowClose then
    Result := Result +
      '<button type="button" class="kx-form-btn kx-form-btn-cancel kx-btn-viewmode"' + LViewHide +
      ' onclick="kxForm.cancel(''' + FViewName + ''')">' +
      LCloseIcon + ' ' + TNetEncoding.HTML.Encode(_('Close')) +
      '</button>';

  // ===== EditMode buttons =====

  // Clone button (EditMode, optional)
  if GetConfigBoolean('CloneButton') then
  begin
    LCloneIcon := GetIconHTML('dup_record', isMedium);
    Result := Result +
      '<button type="button" class="kx-form-btn kx-form-btn-clone kx-btn-editmode"' + LEditHide +
      ' onclick="kxForm.saveAndClone(''' + FViewName + ''',''' + FOperation + ''')">' +
      LCloneIcon + ' ' + TNetEncoding.HTML.Encode(_('Save & Clone')) +
      '</button>';
  end;

  // Save button (EditMode, type=submit for Enter key)
  Result := Result +
    '<button type="submit" class="kx-form-btn kx-form-btn-save kx-btn-editmode"' + LEditHide + '>' +
    LSaveIcon + ' ' + TNetEncoding.HTML.Encode(_('Save')) +
    '</button>';

  // Cancel button (EditMode)
  Result := Result +
    '<button type="button" class="kx-form-btn kx-form-btn-cancel kx-btn-editmode"' + LEditHide +
    ' onclick="kxForm.cancelEdit(''' + FViewName + ''')">' +
    LCancelIcon + ' ' + TNetEncoding.HTML.Encode(_('Cancel')) +
    '</button>';

  Result := Result + '</div>';
end;

function TKXFormPanelController.RenderContent: string;
var
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LLayout: TKLayout;
  I: Integer;
  LFormBodyHtml: string;
  LField: TKViewField;
  LRecordField: TKViewTableField;
  J: Integer;
  LHasPageBreaks, LHasDetails, LNeedsTabs: Boolean;
  SB, SBBody, SBKey: TStringBuilder;
begin
  Result := '';
  if not Assigned(View) or not (View is TKDataView) then
    Exit;

  LDataView := TKDataView(View);
  LViewTable := LDataView.MainTable;
  if not Assigned(LViewTable) then
    Exit;

  // Determine if we need tabs
  LHasPageBreaks := False;
  LLayout := LViewTable.FindLayout('Form');
  if Assigned(LLayout) then
    for I := 0 to LLayout.ChildCount - 1 do
      if SameText(LLayout.Children[I].Name, 'PageBreak') then
      begin
        LHasPageBreaks := True;
        Break;
      end;

  LHasDetails := (LViewTable.DetailTableCount > 0);
  LNeedsTabs := LHasPageBreaks or LHasDetails;

  // Build form body from layout
  if LNeedsTabs then
    // Tabbed layout: form pages (with optional PageBreaks) + optional detail tabs
    LFormBodyHtml := RenderTabbedLayout(LLayout, LViewTable, LHasDetails)
  else if Assigned(LLayout) then
  begin
    // Single-page form with layout: process layout nodes
    SBBody := TStringBuilder.Create;
    try
      for I := 0 to LLayout.ChildCount - 1 do
        SBBody.Append(RenderLayoutNode(LLayout.Children[I], LViewTable));
      LFormBodyHtml := SBBody.ToString;
    finally
      SBBody.Free;
    end;
  end
  else
  begin
    // No layout, no tabs: render all visible fields sequentially
    SBBody := TStringBuilder.Create;
    try
      for I := 0 to LViewTable.FieldCount - 1 do
      begin
        LField := LViewTable.Fields[I];
        if LField.IsVisible and (not LField.IsBlob or LField.IsPicture) then
          SBBody.Append(RenderEditor(LField, nil));
      end;
      LFormBodyHtml := SBBody.ToString;
    finally
      SBBody.Free;
    end;
  end;

  // Build key string for hidden field
  SBKey := TStringBuilder.Create;
  try
    if Assigned(FRecord) then
    begin
      for J := 0 to LViewTable.FieldCount - 1 do
      begin
        LField := LViewTable.Fields[J];
        if LField.IsKey then
        begin
          LRecordField := FRecord.FindField(LField.AliasedName);
          if Assigned(LRecordField) then
          begin
            if SBKey.Length > 0 then
              SBKey.Append('&');
            SBKey.Append(TNetEncoding.URL.Encode(LField.AliasedName));
            SBKey.Append('=');
            SBKey.Append(TNetEncoding.URL.Encode(LRecordField.AsString));
          end;
        end;
      end;
    end;

    // Assemble form panel
    SB := TStringBuilder.Create;
    try
      SB.Append('<form class="kx-form-panel" id="kx-form-').Append(FViewName).Append('"');
      SB.Append(' data-mode="').Append(IfThen(FIsViewMode, 'view', 'edit')).Append('"');
      if Assigned(ViewTable) and (ViewTable.DetailTableCount > 0) then
        SB.Append(' data-has-details="true"');
      SB.Append(' onsubmit="kxForm.save(''').Append(FViewName).Append(''',''').Append(FOperation).Append(''');return false;"');
      SB.Append(' onkeydown="if(event.key===''Escape''){event.preventDefault();kxForm.cancelEdit(''').Append(FViewName).Append(''');}">');
      SB.Append(RenderFormToolViews);
      if LNeedsTabs then
        SB.Append(LFormBodyHtml)
      else
        SB.Append('<div class="kx-form-body">').Append(LFormBodyHtml).Append('</div>');
      SB.Append(RenderFormButtons);
      SB.Append('<input type="hidden" name="_op" value="').Append(TNetEncoding.HTML.Encode(FOperation)).Append('" />');
      SB.Append('<input type="hidden" name="_key" value="').Append(TNetEncoding.HTML.Encode(SBKey.ToString)).Append('" />');
      if GetConfigBoolean('KeepOpenAfterOperation') then
        SB.Append('<input type="hidden" name="_keepopen" value="true" />');
      SB.Append('</form>');
      Result := SB.ToString;
    finally
      SB.Free;
    end;
  finally
    SBKey.Free;
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('Form', TKXFormPanelController);

end.
