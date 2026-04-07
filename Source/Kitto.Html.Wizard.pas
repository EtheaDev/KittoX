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
///  KittoX Wizard controller — renders a multi-step wizard for data entry.
///  Each step defines fields from the Model (or custom HTML content).
///  Back/Next navigation with per-step validation, Finish saves to DB.
/// </summary>
unit Kitto.Html.Wizard;

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

type
  /// <summary>
  ///  YAML config descriptor for a single wizard step.
  ///  Used by KIDE to discover step-level properties.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXWizardStepConfig = class(TEFNode)
  private
    function GetLayout: string;
    function GetHtml: string;
  public
    [YamlNode('Layout', '', 'Layout file reference for this step')]
    property Layout: string read GetLayout;
    [YamlNode('Html', '', 'Static HTML content for informational/review steps')]
    property Html: string read GetHtml;
    // Fields subnode is a dynamic list of model field names — no typed property needed
  end;

  /// <summary>
  ///  YAML config descriptor for wizard rules.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXWizardRuleConfig = class(TEFNode)
  end;

  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXWizardController = class(TKXDataPanelController)
  strict private
  const
    DEFAULT_CHAR_WIDTH_FACTOR = 1.0;
    DEFAULT_CHAR_HEIGHT_FACTOR = 1.0;
    LAYOUT_MEMOWIDTH = 60;
    LAYOUT_MAXFIELDWIDTH = 60;
    LAYOUT_MINFIELDWIDTH = 5;
    FORM_LABELWIDTH = 120;
    DEFAULT_REQUIREDLABELTEMPLATE = '<b>{label}*</b>';
    DEFAULT_LABELSEPARATOR = ':';
    MULTILINE_EDIT_THRESHOLD = 200;
  strict private
    FViewName: string;
    FLabelWidth: Integer;
    FLabelAlign: string;
    FLabelSeparator: string;
    FRequiredLabelTemplate: string;
    FMemoWidth: Integer;
    FMaxFieldWidth: Integer;
    FMinFieldWidth: Integer;
    FCharWidthFactor: Double;
    FCharHeightFactor: Double;
    FRecord: TKViewTableRecord;
    FStore: TKViewTableStore;

    function GetFinishButton: string;
    function GetOnExecute: string;
    function GetSteps: TEFNode;
    function GetRules: TEFNode;

    function RenderEditor(AViewField: TKViewField;
      ALayoutNode: TEFNode): string;
    function RenderReferenceSelect(AViewField: TKViewField): string;
    function RenderLargeReferenceEditor(AViewField: TKViewField;
      AInputName, AInputId: string; AIsReadOnly: Boolean;
      AWidthStyle: string): string;
    function RenderLayoutNode(ANode: TEFNode;
      AViewTable: TKViewTable): string;
    function GetFieldValue(AField: TKViewTableField;
      AViewField: TKViewField): string;

    function RenderStepIndicators(AStepsNode: TEFNode): string;
    function RenderStepPages(AStepsNode: TEFNode): string;
    function RenderStepFields(AStepNode: TEFNode; AStepIndex: Integer): string;
    function RenderWizardButtons: string;
    function BuildFieldPagesJson(AStepsNode: TEFNode): string;
  strict protected
    function GetDefaultIsModal: Boolean; override;
    function GetPanelCssClass: string; override;
    function IsActionSupported(const AActionName: string): Boolean; override;
    procedure DoDisplay; override;
    function RenderContent: string; override;
  public
    destructor Destroy; override;
    [YamlContainer('Steps', TKXWizardStepConfig, 'Wizard steps (each Step node defines a page)')]
    property Steps: TEFNode read GetSteps;
    [YamlContainer('Rules', TKXWizardRuleConfig, 'Wizard business rules (BeforeNextStep, BeforeExecute, etc.)')]
    property Rules: TEFNode read GetRules;
    [YamlNode('FinishButton', 'Finish', 'Label for the Finish button')]
    property FinishButton: string read GetFinishButton;
    [YamlNode('OnExecute', '', 'Server-side rule to execute on Finish')]
    property OnExecute: string read GetOnExecute;
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
  Kitto.Html.Utils,
  Kitto.Web.Session;

{ TKXWizardController }

destructor TKXWizardController.Destroy;
begin
  FreeAndNil(FStore);
  inherited;
end;

function TKXWizardController.GetDefaultIsModal: Boolean;
begin
  Result := True;
end;

function TKXWizardController.GetPanelCssClass: string;
begin
  Result := 'kx-wizard-panel';
end;

function TKXWizardController.IsActionSupported(const AActionName: string): Boolean;
begin
  // Wizard only supports Add (creating new records)
  Result := SameText(AActionName, 'Add');
end;

function TKXWizardController.GetFinishButton: string;
begin
  Result := GetConfigString('FinishButton', _('Finish'));
end;

function TKXWizardController.GetOnExecute: string;
begin
  Result := GetConfigString('OnExecute', '');
end;

function TKXWizardController.GetSteps: TEFNode;
begin
  Result := Config.FindNode('Steps');
end;

function TKXWizardController.GetRules: TEFNode;
begin
  Result := Config.FindNode('Rules');
end;

{ TKXWizardStepConfig }

function TKXWizardStepConfig.GetLayout: string;
begin
  Result := GetString('Layout', '');
end;

function TKXWizardStepConfig.GetHtml: string;
begin
  Result := GetString('Html', '');
end;

procedure TKXWizardController.DoDisplay;
var
  LDefaultLayoutNode: TEFNode;
  LEditControllerNode: TEFNode;
begin
  // Read layout defaults from Config/Defaults/Layout
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

  FLabelWidth := TKConfig.Instance.Config.GetInteger('Defaults/FormPanel/LabelWidth', FORM_LABELWIDTH);

  if Assigned(ViewTable) then
  begin
    LEditControllerNode := ViewTable.FindNode('EditController');
    if Assigned(LEditControllerNode) then
    begin
      if Config.GetInteger('Width', 0) = 0 then
        Config.SetInteger('Width', LEditControllerNode.GetInteger('Width', 0));
      if Config.GetInteger('Height', 0) = 0 then
        Config.SetInteger('Height', LEditControllerNode.GetInteger('Height', 0));
      FLabelWidth := LEditControllerNode.GetInteger('LabelWidth', FLabelWidth);
    end;

    if TKWebSession.Current.IsMobileBrowser then
      FLabelAlign := 'top'
    else
      FLabelAlign := 'top';  // Wizard default: labels on top
  end
  else
    FLabelAlign := 'top';

  if Assigned(View) then
    FViewName := View.PersistentName;

  inherited;

  // Create store and an empty record for the wizard
  if Assigned(ViewTable) then
  begin
    FStore := ViewTable.CreateStore;
    FRecord := FStore.Records.AppendAndInitialize;
  end;
end;

function TKXWizardController.GetFieldValue(AField: TKViewTableField;
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
      Result := FormatDateTime('yyyy-mm-dd', AField.AsDateTime)
    else if AViewField.DataType is TEFBooleanDataType then
      Result := IfThen(AField.AsBoolean, 'true', 'false')
    else
      Result := AField.AsString;
  except
    Result := '';
  end;
end;

function TKXWizardController.RenderReferenceSelect(
  AViewField: TKViewField): string;
var
  LDBConnection: TEFDBConnection;
  LDBQuery: TEFDBQuery;
  LSQLBuilder: TKSQLBuilder;
  LKeyValue, LCaptionValue: string;
  LEmptyRecord: TKViewTableRecord;
  LStore: TKViewTableStore;
  SB: TStringBuilder;
begin
  if not Assigned(AViewField.ModelField) or not AViewField.ModelField.IsReference then
  begin
    Result := '<option value="">--</option>';
    Exit;
  end;

  LStore := ViewTable.CreateStore;
  try
    LEmptyRecord := LStore.Records.AppendAndInitialize;

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
            while not LDBQuery.DataSet.Eof do
            begin
              LKeyValue := LDBQuery.DataSet.Fields[0].AsString;
              if LDBQuery.DataSet.FieldCount > 1 then
                LCaptionValue := LDBQuery.DataSet.Fields[LDBQuery.DataSet.FieldCount - 1].AsString
              else
                LCaptionValue := LKeyValue;

              SB.Append('<option value="').Append(TNetEncoding.HTML.Encode(LKeyValue)).Append('"');
              SB.Append('>').Append(TNetEncoding.HTML.Encode(LCaptionValue)).Append('</option>');

              LDBQuery.DataSet.Next;
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
    FreeAndNil(LStore);
  end;
end;

function TKXWizardController.RenderLargeReferenceEditor(
  AViewField: TKViewField; AInputName, AInputId: string;
  AIsReadOnly: Boolean; AWidthStyle: string): string;
var
  LDBConnection: TEFDBConnection;
  LDBQuery: TEFDBQuery;
  LSQLBuilder: TKSQLBuilder;
  LKeyValue, LCaptionValue: string;
  LOptionsJSON: string;
  LSearchIcon, LClearIcon: string;
  LFieldName: string;
  LLookupViewName: string;
  LRefModel: TKModel;
  LCaptionField: TKModelField;
  LCaptionFieldName: string;
  LHiddenAttrs: string;
  LEmptyRecord: TKViewTableRecord;
  LStore: TKViewTableStore;
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

  // Check for a dedicated lookup view
  LLookupViewName := '';
  if Assigned(AViewField.ModelField) then
  begin
    LRefModel := AViewField.ModelField.ReferencedModel;
    if Assigned(LRefModel) then
    begin
      var LView := AViewField.Table.View.Catalog.FindObjectByPredicate(
        function(const AObject: TKMetadata): Boolean
        begin
          Result := (AObject is TKDataView) and AObject.GetBoolean('IsLookup')
            and (TKDataView(AObject).MainTable.Model = LRefModel);
        end) as TKView;
      if Assigned(LView) then
        LLookupViewName := LView.PersistentName;
    end;
  end;

  if LLookupViewName <> '' then
  begin
    LRefModel := AViewField.ModelField.ReferencedModel;
    LCaptionField := LRefModel.FindCaptionField;
    if Assigned(LCaptionField) then
      LCaptionFieldName := LCaptionField.FieldName
    else
      LCaptionFieldName := '';

    LHiddenAttrs :=
      ' data-lookup-view="' + TNetEncoding.HTML.Encode(LLookupViewName) + '"' +
      ' data-caption-field="' + TNetEncoding.HTML.Encode(LCaptionFieldName) + '"';
  end
  else
  begin
    LStore := ViewTable.CreateStore;
    try
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

  LSearchIcon := GetIconHTML('search');
  LClearIcon := GetIconHTML('cancel');

  var LCtx: TKXEditorContext;
  LCtx.InputId := AInputId;
  LCtx.InputName := AInputName;
  LCtx.IsReadOnly := AIsReadOnly;
  LCtx.CssInputClass := 'kx-form-input';
  LCtx.TriggerWidthStyle := AWidthStyle;

  Result := TKXEditorFactory.RenderLargeReferenceEditor(LCtx,
    '', '', LHiddenAttrs,
    LSearchIcon, LClearIcon,
    'kxForm', FViewName, LFieldName);
end;

function TKXWizardController.RenderEditor(AViewField: TKViewField;
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

  // Get display label
  LLabel := '';
  if Assigned(ALayoutNode) then
    LLabel := ALayoutNode.GetString('DisplayLabel');
  if LLabel = '' then
  begin
    LLabel := AViewField.DisplayLabel_Form;
    if LLabel = '' then
      LLabel := AViewField.DisplayLabel;
  end;

  // Get field value from record (empty for new wizard)
  LRecordField := nil;
  if Assigned(FRecord) then
    LRecordField := FRecord.FindField(LFieldName);
  LValue := GetFieldValue(LRecordField, AViewField);

  LIsRequired := AViewField.IsRequired;
  LIsReadOnly := AViewField.IsReadOnly;

  // CharWidth calculation
  LCharWidth := AViewField.DisplayWidth;
  if Assigned(ALayoutNode) then
    LCharWidth := ALayoutNode.GetInteger('CharWidth', LCharWidth);
  if LCharWidth = 0 then
    LCharWidth := Min(IfThen(AViewField.Size = 0, FMemoWidth, AViewField.Size),
      FMaxFieldWidth);
  LCharWidth := Max(LCharWidth, FMinFieldWidth);
  LEffWidth := Round(LCharWidth * FCharWidthFactor);

  LWidthStyle := 'width:' + IntToStr(LEffWidth + INPUT_EXTRA_CHS) + 'ch';
  LTriggerWidthStyle := 'width:calc(' + IntToStr(LEffWidth + INPUT_EXTRA_CHS) + 'ch + '
    + IntToStr(TRIGGER_PX) + 'px)';

  LFieldCss := 'kx-form-field';
  if SameText(FLabelAlign, 'top') then
    LFieldCss := LFieldCss + ' kx-form-field-top';
  if LIsReadOnly then
    LFieldCss := LFieldCss + ' kx-form-readonly';

  if SameText(FLabelAlign, 'left') then
    LLabelStyle := 'min-width:' + IntToStr(FLabelWidth) + 'px'
  else if SameText(FLabelAlign, 'right') then
    LLabelStyle := 'min-width:' + IntToStr(FLabelWidth) + 'px;text-align:right'
  else
    LLabelStyle := '';

  LCtx.InputId := LInputId;
  LCtx.InputName := LInputName;
  LCtx.Value := LValue;
  LCtx.WidthStyle := LWidthStyle;
  LCtx.TriggerWidthStyle := LTriggerWidthStyle;
  LCtx.IsReadOnly := LIsReadOnly;
  LCtx.IsRequired := LIsRequired;
  LCtx.IsKey := AViewField.IsKey;
  LCtx.ExtraAttrs := '';
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

    // AllowedValues dropdown
    LAllowedValues := AViewField.AllowedValues;
    if Length(LAllowedValues) > 0 then
    begin
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
        SB.Append(RenderLargeReferenceEditor(AViewField, LInputName, LInputId,
          LIsReadOnly, LTriggerWidthStyle))
      else
        SB.Append(TKXEditorFactory.RenderSmallReferenceSelect(LCtx,
          RenderReferenceSelect(AViewField)));
    end
    // Memo threshold
    else if not (AViewField.DataType is TEFMemoDataType)
      and not (AViewField.DataType is TKHTMLMemoDataType)
      and (AViewField.Size div SizeOf(Char) >= MULTILINE_EDIT_THRESHOLD) then
    begin
      LLines := AViewField.GetInteger('Lines', 5);
      if Assigned(ALayoutNode) then
        LLines := ALayoutNode.GetInteger('Lines', LLines);
      SB.Append(TKXEditorFactory.RenderMemoInput(LCtx, LLines));
    end
    // All other types
    else
    begin
      if AViewField.DataType is TEFDateTimeDataType then
      begin
        LTimeValue := '';
        LCtx.TimeValue := LTimeValue;
      end;

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

function TKXWizardController.RenderLayoutNode(ANode: TEFNode;
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

  if SameText(LNodeName, 'Field') then
  begin
    LFieldName := ANode.AsString;
    LViewField := AViewTable.FindField(LFieldName);
    if Assigned(LViewField) and LViewField.IsVisible then
      Result := RenderEditor(LViewField, ANode);
  end
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
  else if SameText(LNodeName, 'Spacer') then
    Result := '<div style="height:8px"></div>';
end;

function TKXWizardController.RenderStepIndicators(AStepsNode: TEFNode): string;
var
  I: Integer;
  LStepNode: TEFNode;
  LStepTitle: string;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('<div class="kx-wizard-steps">');
    for I := 0 to AStepsNode.ChildCount - 1 do
    begin
      LStepNode := AStepsNode.Children[I];
      if not SameText(LStepNode.Name, 'Step') then
        Continue;

      if I > 0 then
        SB.Append('<div class="kx-wizard-step-separator"></div>');

      LStepTitle := _(LStepNode.AsString);
      if LStepTitle = '' then
        LStepTitle := Format(_('Step %d'), [I + 1]);

      SB.Append('<div class="kx-wizard-step');
      if I = 0 then
        SB.Append(' kx-wizard-step-active');
      SB.Append('" data-step="').Append(IntToStr(I)).Append('">');
      SB.Append('<span class="kx-wizard-step-num">').Append(IntToStr(I + 1)).Append('</span>');
      SB.Append('<span class="kx-wizard-step-title">').Append(TNetEncoding.HTML.Encode(LStepTitle)).Append('</span>');
      SB.Append('</div>');
    end;
    SB.Append('</div>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXWizardController.RenderStepFields(AStepNode: TEFNode;
  AStepIndex: Integer): string;
var
  LFieldsNode: TEFNode;
  LLayoutName: string;
  LLayout: TKLayout;
  I: Integer;
  LFieldName: string;
  LViewField: TKViewField;
  SB: TStringBuilder;
begin
  Result := '';
  if not Assigned(ViewTable) then
    Exit;

  // Check for Layout reference first
  LLayoutName := AStepNode.GetString('Layout', '');
  if LLayoutName <> '' then
  begin
    LLayout := ViewTable.FindLayout(LLayoutName);
    if Assigned(LLayout) then
    begin
      SB := TStringBuilder.Create;
      try
        for I := 0 to LLayout.ChildCount - 1 do
          SB.Append(RenderLayoutNode(LLayout.Children[I], ViewTable));
        Result := SB.ToString;
      finally
        SB.Free;
      end;
      Exit;
    end;
  end;

  // Check for Html content
  if AStepNode.GetString('Html', '') <> '' then
  begin
    Result := '<div class="kx-wizard-html">' + AStepNode.GetString('Html') + '</div>';
    Exit;
  end;

  // Render inline Fields
  LFieldsNode := AStepNode.FindNode('Fields');
  if not Assigned(LFieldsNode) then
    Exit;

  SB := TStringBuilder.Create;
  try
    for I := 0 to LFieldsNode.ChildCount - 1 do
    begin
      LFieldName := LFieldsNode.Children[I].Name;
      LViewField := ViewTable.FindField(LFieldName);
      if Assigned(LViewField) and LViewField.IsVisible then
        SB.Append(RenderEditor(LViewField, LFieldsNode.Children[I]));
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXWizardController.RenderStepPages(AStepsNode: TEFNode): string;
var
  I, LStepIdx: Integer;
  LStepNode: TEFNode;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('<div class="kx-wizard-body">');
    LStepIdx := 0;
    for I := 0 to AStepsNode.ChildCount - 1 do
    begin
      LStepNode := AStepsNode.Children[I];
      if not SameText(LStepNode.Name, 'Step') then
        Continue;

      SB.Append('<div class="kx-wizard-page" id="kx-wizard-page-');
      SB.Append(FViewName).Append('-').Append(IntToStr(LStepIdx)).Append('"');
      if LStepIdx > 0 then
        SB.Append(' style="display:none"');
      SB.Append('>');
      SB.Append(RenderStepFields(LStepNode, LStepIdx));
      SB.Append('</div>');
      Inc(LStepIdx);
    end;
    SB.Append('</div>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXWizardController.BuildFieldPagesJson(AStepsNode: TEFNode): string;
var
  I, J: Integer;
  LStepNode, LFieldsNode: TEFNode;
  SB: TStringBuilder;
  LFirst, LFirstField: Boolean;
begin
  // Build JSON array of arrays: [["FIELD1","FIELD2"],["FIELD3"],...]
  SB := TStringBuilder.Create;
  try
    SB.Append('[');
    LFirst := True;
    for I := 0 to AStepsNode.ChildCount - 1 do
    begin
      LStepNode := AStepsNode.Children[I];
      if not SameText(LStepNode.Name, 'Step') then
        Continue;

      if not LFirst then
        SB.Append(',');
      LFirst := False;

      SB.Append('[');
      LFieldsNode := LStepNode.FindNode('Fields');
      if Assigned(LFieldsNode) then
      begin
        LFirstField := True;
        for J := 0 to LFieldsNode.ChildCount - 1 do
        begin
          if not LFirstField then
            SB.Append(',');
          LFirstField := False;
          SB.Append('"').Append(LFieldsNode.Children[J].Name).Append('"');
        end;
      end;
      SB.Append(']');
    end;
    SB.Append(']');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXWizardController.RenderWizardButtons: string;
var
  LBackIcon, LNextIcon, LFinishIcon, LCancelIcon: string;
  LFinishLabel: string;
begin
  LBackIcon := GetIconHTML('navigate_before', isMedium);
  LNextIcon := GetIconHTML('navigate_next', isMedium);
  LFinishIcon := GetIconHTML('check_circle', isMedium);
  LCancelIcon := GetIconHTML('cancel', isMedium);

  LFinishLabel := GetConfigString('FinishButton', _('Finish'));

  Result := '<div class="kx-wizard-toolbar">';

  // Back button (disabled initially)
  Result := Result +
    '<button type="button" class="kx-form-btn" id="kx-wizard-back-' + FViewName + '"' +
    ' onclick="kxWizard.back(''' + FViewName + ''')" disabled>' +
    LBackIcon + ' ' + TNetEncoding.HTML.Encode(_('Back')) +
    '</button>';

  // Next button
  Result := Result +
    '<button type="button" class="kx-form-btn kx-form-btn-save" id="kx-wizard-next-' + FViewName + '"' +
    ' onclick="kxWizard.next(''' + FViewName + ''')">' +
    LNextIcon + ' ' + TNetEncoding.HTML.Encode(_('Next')) +
    '</button>';

  // Finish button (hidden initially)
  Result := Result +
    '<button type="button" class="kx-form-btn kx-form-btn-save" id="kx-wizard-finish-' + FViewName + '"' +
    ' onclick="kxWizard.finish(''' + FViewName + ''')" style="display:none">' +
    LFinishIcon + ' ' + TNetEncoding.HTML.Encode(_(LFinishLabel)) +
    '</button>';

  // Cancel button
  Result := Result +
    '<button type="button" class="kx-form-btn kx-form-btn-cancel"' +
    ' onclick="kxWizard.cancel(''' + FViewName + ''')">' +
    LCancelIcon + ' ' + TNetEncoding.HTML.Encode(_('Cancel')) +
    '</button>';

  Result := Result + '</div>';
end;

function TKXWizardController.RenderContent: string;
var
  LStepsNode: TEFNode;
  LStepCount: Integer;
  I: Integer;
  SB: TStringBuilder;
begin
  Result := '';
  if not Assigned(View) or not (View is TKDataView) then
    Exit;
  if not Assigned(ViewTable) then
    Exit;

  // Read Steps node from Config (Controller node)
  LStepsNode := Config.FindNode('Steps');
  if not Assigned(LStepsNode) or (LStepsNode.ChildCount = 0) then
    Exit;

  // Count actual Step children
  LStepCount := 0;
  for I := 0 to LStepsNode.ChildCount - 1 do
    if SameText(LStepsNode.Children[I].Name, 'Step') then
      Inc(LStepCount);
  if LStepCount = 0 then
    Exit;

  SB := TStringBuilder.Create;
  try
    SB.Append('<form class="kx-wizard-panel" id="kx-wizard-').Append(FViewName).Append('"');
    SB.Append(' onsubmit="return false;"');
    SB.Append(' onkeydown="if(event.key===''Escape''){event.preventDefault();kxWizard.cancel(''').Append(FViewName).Append(''');}">');

    // Step indicators
    SB.Append(RenderStepIndicators(LStepsNode));

    // Step pages
    SB.Append(RenderStepPages(LStepsNode));

    // Navigation buttons
    SB.Append(RenderWizardButtons);

    // Hidden fields
    SB.Append('<input type="hidden" name="_op" value="add" />');
    SB.Append('<input type="hidden" name="_step" value="0" />');

    // Init script
    SB.Append('<script>kxWizard.init(''').Append(FViewName).Append(''',');
    SB.Append(IntToStr(LStepCount)).Append(',');
    SB.Append(BuildFieldPagesJson(LStepsNode));
    SB.Append(');</script>');

    SB.Append('</form>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('Wizard', TKXWizardController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('Wizard');

end.
