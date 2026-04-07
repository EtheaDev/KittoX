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
///  KittoX TemplateDataPanel controller � renders database records using a
///  custom HTML template file. The template file defines the HTML for a
///  single card/row; it is repeated for each record with {FieldName}
///  placeholders substituted with record values.
///  Special placeholders: {_KEY} = URL-encoded record key string,
///  {_VIEW} = view name.  These allow HTMX attributes inside templates.
///  Legacy <tpl for=".">...</tpl> markers are still supported for
///  backward compatibility (prefix/suffix around the repeating section).
///  Inherits toolbar and filter support from TKXListPanelController.
///  No paging (all records loaded at once).
///  Replaces TKExtTemplateDataPanel from Kitto.Ext.TemplateDataPanel.
/// </summary>
unit Kitto.Html.TemplateDataPanel;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Html.List,
  Kitto.Html.Controller,
  Kitto.Metadata.DataView,
  Kitto.Store;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXTemplateDataPanelController = class(TKXListPanelController)
  strict private
    function GetTemplateFileName: string;
    function GetTemplate: string;
  strict protected
    function IsActionSupported(const AActionName: string): Boolean; override;
    function GetPanelCssClass: string; override;
    function RenderContent: string; override;
  public
    [YamlNode('TemplateFileName', 'Resource file name containing the HTML template')]
    property TemplateFileName: string read GetTemplateFileName;
    [YamlNode('Template', 'Inline HTML template string')]
    property Template: string read GetTemplate;
    /// <summary>
    ///  Loads the HTML template, expands macros, loads all records from
    ///  the store, and renders the template with field substitution.
    ///  Class function so it can be called from HandleKXDataRequest.
    /// </summary>
    class function BuildTemplateContent(AStore: TKViewTableStore;
      AViewTable: TKViewTable; AConfig: TEFTree;
      const AViewName: string; const AImageName: string = ''): string;
    /// <summary>
    ///  Like BuildTemplateContent but wraps each record in a selectable
    ///  card div with data-key, onclick/ondblclick handlers (for use as
    ///  CenterController inside a List controller).
    /// </summary>
    class function BuildSelectableCards(AStore: TKViewTableStore;
      AViewTable: TKViewTable; AConfig: TEFTree;
      const AViewName: string; const AImageName: string = ''): string;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.NetEncoding,
  EF.Macros,
  EF.StrUtils,
  EF.Sys,
  EF.Localization,
  Kitto.Config,
  Kitto.Html.Base,
  Kitto.Html.Utils,
  Kitto.Metadata.Models,
  Kitto.Web.Application,
  Kitto.Web.Request;

{ TKXTemplateDataPanelController }

function TKXTemplateDataPanelController.GetTemplateFileName: string;
begin
  Result := Config.GetExpandedString('TemplateFileName', '');
end;

function TKXTemplateDataPanelController.GetTemplate: string;
begin
  Result := Config.GetString('Template', '');
end;

function TKXTemplateDataPanelController.IsActionSupported(
  const AActionName: string): Boolean;
begin
  // TemplateDataPanel is display-only: no CRUD actions, only ToolViews.
  Result := False;
end;

function TKXTemplateDataPanelController.GetPanelCssClass: string;
begin
  Result := 'kx-list-panel kx-template-panel';
end;

/// <summary>
///  Loads the template from TemplateFileName (resource file) or inline
///  Template config node. Expands Kitto macros (%IMAGE(...)%, etc.).
/// </summary>
function LoadTemplate(AConfig: TEFTree;
  const AImageName: string = ''): string;
var
  LFileName, LFilePath: string;
begin
  Result := '';
  LFileName := AConfig.GetExpandedString('TemplateFileName');
  if LFileName = '' then
    LFileName := AConfig.GetExpandedString('CenterController/TemplateFileName');
  if LFileName <> '' then
  begin
    LFilePath := TKWebApplication.Current.FindResourcePathName(LFileName);
    if LFilePath <> '' then
      Result := TextFileToString(LFilePath, TEncoding.UTF8);
  end;
  if Result = '' then
    Result := AConfig.GetString('Template');
  if Result = '' then
  begin
    Result := '<div class="kx-template-error">' +
      TNetEncoding.HTML.Encode(_('TemplateFileName or Template not specified.')) +
      '</div>';
    Exit;
  end;
  // Expand Kitto macros (%IMAGE(...)%, %HOME_PATH%, etc.)
  TEFMacroExpansionEngine.Instance.Expand(Result);
  // Replace {_ICON} with the view's monochrome icon (CSS mask-image, theme-adaptive)
  if Pos('{_ICON}', Result) > 0 then
    Result := ReplaceStr(Result, '{_ICON}', GetIconHTML(AImageName));
  // Replace {_IMAGE} with the view's image as <img> (preserves original colors)
  if (Pos('{_IMAGE}', Result) > 0) and (AImageName <> '') then
  begin
    var LImageURL := TKWebApplication.Current.FindImageURL(AImageName);
    if LImageURL <> '' then
      Result := ReplaceStr(Result, '{_IMAGE}',
        '<img src="' + LImageURL + '" alt="' + TNetEncoding.HTML.Encode(AImageName) + '">')
    else
      Result := ReplaceStr(Result, '{_IMAGE}', '');
  end;
end;

/// <summary>
///  Builds a URL-encoded key string for a record (field=value&field2=value2).
///  Used for data-key attributes and blob URL construction.
/// </summary>
function BuildRecordKeyString(ARecord: TKViewTableRecord;
  AViewTable: TKViewTable): string;
var
  I: Integer;
  LField: TKViewField;
  LRecordField: TKViewTableField;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    for I := 0 to AViewTable.FieldCount - 1 do
    begin
      LField := AViewTable.Fields[I];
      if LField.IsKey then
      begin
        LRecordField := ARecord.FindField(LField.AliasedName);
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

/// <summary>
///  Substitutes {FieldName} placeholders in a row template with actual
///  record values. Handles :date format specifier.
///  IsPicture blob fields are rendered as base64 data URIs.
///  Special placeholders: {_KEY} = URL-encoded record key string,
///  {_VIEW} = view name (for HTMX URLs in templates).
/// </summary>
function SubstituteFields(const ARowTemplate: string;
  ARecord: TKViewTableRecord; AViewTable: TKViewTable;
  const AViewName: string; const AKeyString: string): string;
var
  I: Integer;
  LField: TKViewField;
  LRecordField: TKViewTableField;
  LValue: string;
  LUserFmt: TFormatSettings;
  LPlaceholder, LPlaceholderDate: string;
  LBytes: TBytes;
  LExt, LMime: string;
begin
  Result := ARowTemplate;
  LUserFmt := TKConfig.Instance.UserFormatSettings;

  // Replace special placeholders
  Result := ReplaceStr(Result, '{_KEY}', TNetEncoding.HTML.Encode(AKeyString));
  Result := ReplaceStr(Result, '{_VIEW}', TNetEncoding.HTML.Encode(AViewName));

  for I := 0 to AViewTable.FieldCount - 1 do
  begin
    LField := AViewTable.Fields[I];
    LPlaceholder := '{' + LField.AliasedName + '}';
    LPlaceholderDate := '{' + LField.AliasedName + ':date}';

    // Skip if this field's placeholder doesn't appear in the template
    if (Pos(LPlaceholder, Result) = 0) and (Pos(LPlaceholderDate, Result) = 0) then
      Continue;

    // IsPicture blob fields: render as base64 data URI
    if LField.IsBlob and LField.IsPicture then
    begin
      LValue := '';
      LRecordField := ARecord.FindField(LField.AliasedName);
      if Assigned(LRecordField) and not LRecordField.IsNull then
      begin
        LBytes := LRecordField.AsBytes;
        if Length(LBytes) > 0 then
        begin
          LExt := GetDataType(LBytes, 'dat');
          if SameText(LExt, 'jpg') then
            LMime := 'image/jpeg'
          else if SameText(LExt, 'png') then
            LMime := 'image/png'
          else if SameText(LExt, 'gif') then
            LMime := 'image/gif'
          else if SameText(LExt, 'bmp') then
            LMime := 'image/bmp'
          else
            LMime := 'image/png';
          LValue := 'data:' + LMime + ';base64,' +
            TNetEncoding.Base64.EncodeBytesToString(LBytes);
        end;
      end;
      // Data URIs are attribute-safe (no HTML special chars in base64)
      Result := ReplaceStr(Result, LPlaceholderDate, LValue);
      Result := ReplaceStr(Result, LPlaceholder, LValue);
      Continue;
    end;

    LRecordField := ARecord.FindField(LField.AliasedName);
    if Assigned(LRecordField) and not LRecordField.IsNull then
    begin
      if LField.DataType is TEFDateTimeDataTypeBase then
        LValue := LField.DataType.NodeToJSONValue(True, LRecordField, LUserFmt, False)
      else
        LValue := LRecordField.GetAsJSONValue(True, False);
      if SameText(LValue, 'null') then
        LValue := '';
    end
    else
      LValue := '';

    // Replace both {FIELD:date} and {FIELD} variants
    Result := ReplaceStr(Result, LPlaceholderDate, TNetEncoding.HTML.Encode(LValue));
    Result := ReplaceStr(Result, LPlaceholder, TNetEncoding.HTML.Encode(LValue));
  end;
end;

class function TKXTemplateDataPanelController.BuildTemplateContent(
  AStore: TKViewTableStore; AViewTable: TKViewTable;
  AConfig: TEFTree; const AViewName: string;
  const AImageName: string): string;
var
  LTemplate: string;
  LPrefix, LSuffix, LRowTemplate: string;
  LTplStart, LTplEnd: Integer;
  I: Integer;
  LKeyString: string;
  SB: TStringBuilder;
begin
  LTemplate := LoadTemplate(AConfig, AImageName);

  // Find <tpl for=".">...</tpl> markers (legacy backward compat)
  LTplStart := Pos('<tpl for=".">', LTemplate);
  LTplEnd := Pos('</tpl>', LTemplate);

  if (LTplStart > 0) and (LTplEnd > LTplStart) then
  begin
    // Legacy mode: prefix + repeating row + suffix
    LPrefix := Copy(LTemplate, 1, LTplStart - 1);
    LRowTemplate := Copy(LTemplate, LTplStart + Length('<tpl for=".">'),
      LTplEnd - LTplStart - Length('<tpl for=".">'));
    LSuffix := Copy(LTemplate, LTplEnd + Length('</tpl>'), MaxInt);
  end
  else
  begin
    // HTMX-native mode: entire template IS the card/row template
    LPrefix := '';
    LRowTemplate := LTemplate;
    LSuffix := '';
  end;

  SB := TStringBuilder.Create;
  try
    SB.Append(LPrefix);

    if AStore.RecordCount = 0 then
    begin
      if LRowTemplate <> '' then
        SB.Append('<div class="kx-card-empty">')
          .Append(TNetEncoding.HTML.Encode(_('No data to display.')))
          .Append('</div>');
    end
    else
    begin
      for I := 0 to AStore.RecordCount - 1 do
      begin
        LKeyString := BuildRecordKeyString(AStore.Records[I], AViewTable);
        SB.Append(SubstituteFields(LRowTemplate, AStore.Records[I],
          AViewTable, AViewName, LKeyString));
      end;
    end;

    SB.Append(LSuffix);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TKXTemplateDataPanelController.BuildSelectableCards(
  AStore: TKViewTableStore; AViewTable: TKViewTable;
  AConfig: TEFTree; const AViewName: string;
  const AImageName: string): string;
var
  LTemplate: string;
  LPrefix, LSuffix, LRowTemplate: string;
  LTplStart, LTplEnd: Integer;
  I: Integer;
  LKeyString: string;
  LCaptionField: TKModelField;
  LCaptionValue: string;
  LRecordField: TKViewTableField;
  SB: TStringBuilder;
begin
  LTemplate := LoadTemplate(AConfig, AImageName);

  // Find <tpl for=".">...</tpl> markers (legacy backward compat)
  LTplStart := Pos('<tpl for=".">', LTemplate);
  LTplEnd := Pos('</tpl>', LTemplate);

  if (LTplStart > 0) and (LTplEnd > LTplStart) then
  begin
    // Legacy mode: prefix + repeating row + suffix
    LPrefix := Copy(LTemplate, 1, LTplStart - 1);
    LRowTemplate := Copy(LTemplate, LTplStart + Length('<tpl for=".">'),
      LTplEnd - LTplStart - Length('<tpl for=".">'));
    LSuffix := Copy(LTemplate, LTplEnd + Length('</tpl>'), MaxInt);
  end
  else
  begin
    // HTMX-native mode: entire template IS the card template
    LPrefix := '';
    LRowTemplate := LTemplate;
    LSuffix := '';
  end;

  // Find caption field for data-caption attribute
  LCaptionField := nil;
  if Assigned(AViewTable.Model) then
    LCaptionField := AViewTable.Model.FindCaptionField;

  SB := TStringBuilder.Create;
  try
    SB.Append(LPrefix);

    if AStore.RecordCount = 0 then
    begin
      if LRowTemplate <> '' then
        SB.Append('<div class="kx-card-empty">')
          .Append(TNetEncoding.HTML.Encode(_('No data to display.')))
          .Append('</div>');
    end
    else
    begin
      for I := 0 to AStore.RecordCount - 1 do
      begin
        // Build key string (raw URL-encoded)
        LKeyString := BuildRecordKeyString(AStore.Records[I], AViewTable);

        // Extract caption value
        LCaptionValue := '';
        if Assigned(LCaptionField) then
        begin
          LRecordField := AStore.Records[I].FindField(LCaptionField.FieldName);
          if Assigned(LRecordField) and not LRecordField.IsNull then
            LCaptionValue := LRecordField.AsString;
        end;

        // Selectable card wrapper
        SB.Append('<div class="kx-card-item" data-key="')
          .Append(TNetEncoding.HTML.Encode(LKeyString)).Append('"');
        SB.Append(' data-caption="')
          .Append(TNetEncoding.HTML.Encode(LCaptionValue)).Append('"');
        SB.Append(' onclick="kxGrid.select(this,''')
          .Append(AViewName).Append(''')"');
        SB.Append(' ondblclick="kxGrid.rowDblClick(this,''')
          .Append(AViewName).Append(''')">');
        SB.Append(SubstituteFields(LRowTemplate, AStore.Records[I],
          AViewTable, AViewName, LKeyString));
        SB.Append('</div>');
      end;
    end;

    SB.Append(LSuffix);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXTemplateDataPanelController.RenderContent: string;
var
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LViewName: string;
  LFilterPanelHtml: string;
  LDefaultFilterExpr: string;
  LSortExpr: string;
  LControllerNode: TEFNode;
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
  LControllerNode := LViewTable.FindNode('Controller');

  // Build filter panel (if Filters/Items defined)
  LFilterPanelHtml := BuildFilterPanel(LViewName, LViewTable,
    LDefaultFilterExpr);

  // Build sort expression from SortFieldNames if specified
  LSortExpr := '';
  if Assigned(LControllerNode) then
  begin
    var LSortFieldNames := LViewTable.GetStringArray('Controller/SortFieldNames');
    if Length(LSortFieldNames) > 0 then
    begin
      var LFields: TArray<string>;
      SetLength(LFields, Length(LSortFieldNames));
      var J: Integer;
      for J := Low(LSortFieldNames) to High(LSortFieldNames) do
        LFields[J] := LViewTable.FieldByName(LSortFieldNames[J]).QualifiedDBNameOrExpression;
      LSortExpr := string.Join(', ', LFields);
    end;
  end;

  // Load ALL records (no paging)
  LStore := LViewTable.CreateStore;
  try
    LStore.Load(LDefaultFilterExpr, LSortExpr, 0, 0);

    SB := TStringBuilder.Create;
    try
      // Filter panel
      SB.Append(LFilterPanelHtml);

      // Toolbar (ToolViews buttons)
      SB.Append(BuildToolbar(LViewName));

      // Template content in a scrollable container
      SB.Append('<div class="kx-template-content" id="kx-list-body-')
        .Append(LViewName).Append('">');
      SB.Append(BuildTemplateContent(LStore, LViewTable, Config, LViewName, View.ImageName));
      SB.Append('</div>');

      // Hidden state (for filter state, no paging)
      SB.Append(BuildHiddenState(LViewName, 0, '', ''));

      Result := SB.ToString;
    finally
      SB.Free;
    end;
  finally
    FreeAndNil(LStore);
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('TemplateDataPanel', TKXTemplateDataPanelController);

end.
