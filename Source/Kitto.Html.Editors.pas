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
///  Unified editor factory for KittoX è produces the HTML for input elements
///  shared by both form editors (Kitto.Html.Form) and filter inputs
///  (Kitto.Html.List). Each method returns ONLY the <input>/<select>/<textarea>
///  markup (no wrapper div, no label). Callers supply context via TKXEditorContext.
///  No dependencies on Metadata, Store, Config, or SQL.
/// </summary>
unit Kitto.Html.Editors;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  EF.Tree,
  EF.Types;

const
  /// Extra chars to compensate for input padding+border
  INPUT_EXTRA_CHS = 2;
  /// Fixed pixel offset for browser-native trigger icons (date picker, select arrow)
  TRIGGER_PX = 20;
  /// Extra px for date inputs è Firefox renders date segments (dd/mm/yyyy) with
  /// internal spacing that cannot be removed via CSS, so we widen date fields.
  DATE_EXTRA_PX = 6;
  /// Extra chars for spacer between date and time in DateTime editors
  SPACER_WIDTH = 1;

type
  TKXEditorContext = record
    InputId: string;
    InputName: string;
    Value: string;
    TimeValue: string;           // For DateTime: time part
    WidthStyle: string;          // e.g. 'width:20ch'
    TriggerWidthStyle: string;   // e.g. 'width:calc(20ch + 20px)'
    IsReadOnly: Boolean;
    IsIntrinsicallyReadOnly: Boolean; // Read-only regardless of form view/edit mode toggle.
    IsRequired: Boolean;
    IsKey: Boolean;
    ExtraAttrs: string;          // Additional attributes (hx-*, data-*, etc.)
    CssInputClass: string;       // 'kx-form-input' for forms, 'kx-filter-input' for filters
    EffWidth: Integer;           // Effective width in ch units (for DateTime time portion calc)
  end;

  TKXEditorFactory = class
  public
    /// <summary>Dispatches to the correct Render* method based on ADataType.</summary>
    class function RenderInput(ADataType: TEFDataType; const ACtx: TKXEditorContext;
      AMaxLength: Integer = 0; AIsPassword: Boolean = False;
      AUseSpeedButtons: Boolean = False;
      ACurrDecimals: Integer = 2; ADecSep: Char = '.'; const ACurrSymbol: string = '';
      ALines: Integer = 5; AEditorNode: TEFNode = nil;
      const ACurrencyPrefix: string = 'kxForm';
      ACharHeightFactor: Double = 1.0): string;

    /// <summary>Renders a text &lt;input&gt; (optionally password), with the given max length.</summary>
    class function RenderTextInput(const ACtx: TKXEditorContext;
      AMaxLength: Integer; AIsPassword: Boolean = False): string;
    /// <summary>Renders a search text &lt;input&gt; with the given placeholder (filter panels).</summary>
    class function RenderSearchInput(const ACtx: TKXEditorContext;
      const APlaceholder: string): string;
    /// <summary>Renders a &lt;select&gt; from the given value/label pairs (optionally with an empty item).</summary>
    class function RenderSelectInput(const ACtx: TKXEditorContext;
      const AItems: TEFPairs; AAllowEmpty: Boolean): string;
    /// <summary>Renders a boolean checkbox input.</summary>
    class function RenderCheckboxInput(const ACtx: TKXEditorContext): string;
    /// <summary>Renders a date input (&lt;input type="date"&gt;).</summary>
    class function RenderDateInput(const ACtx: TKXEditorContext): string;
    /// <summary>Renders a time input (&lt;input type="time"&gt;).</summary>
    class function RenderTimeInput(const ACtx: TKXEditorContext): string;
    /// <summary>Renders a combined date + time input pair.</summary>
    class function RenderDateTimeInput(const ACtx: TKXEditorContext): string;
    /// <summary>Renders an integer input (optionally with spin/speed buttons).</summary>
    class function RenderIntegerInput(const ACtx: TKXEditorContext;
      AUseSpeedButtons: Boolean): string;
    /// <summary>Renders a currency input with the given decimals/separator/symbol and JS callbacks.</summary>
    class function RenderCurrencyInput(const ACtx: TKXEditorContext;
      ADecimals: Integer; ADecSep: Char; const ACurrSymbol: string;
      const ACallbackPrefix: string = 'kxForm'): string;
    /// <summary>Renders a decimal (floating-point) input.</summary>
    class function RenderDecimalInput(const ACtx: TKXEditorContext): string;
    /// <summary>Renders a multi-line memo (&lt;textarea&gt;) with the given number of rows.</summary>
    class function RenderMemoInput(const ACtx: TKXEditorContext;
      ARows: Integer): string;
    /// <summary>Renders a rich-text (HTML) memo editor (SunEditor) with the given rows/config.</summary>
    class function RenderHtmlMemoInput(const ACtx: TKXEditorContext;
      ARows: Integer; AEditorNode: TEFNode;
      ACharHeightFactor: Double = 1.0): string;
    /// <summary>Renders a generic numeric input.</summary>
    class function RenderNumberInput(const ACtx: TKXEditorContext): string;
    /// <summary>Renders a <select> from pre-built options HTML (for FK small references).</summary>
    class function RenderSmallReferenceSelect(const ACtx: TKXEditorContext;
      const AOptionsHtml: string): string;
    /// <summary>Renders the lookup wrapper with hidden key input + display input + buttons.</summary>
    class function RenderLargeReferenceEditor(const ACtx: TKXEditorContext;
      const ACurrentKeyValue, ACurrentCaption: string;
      const AHiddenAttrs: string;
      const ASearchIcon, AClearIcon: string;
      const ACallbackPrefix: string;
      const ACallbackViewName, ACallbackFieldName: string): string;

    /// <summary>Builds the standard id/name/required/disabled attribute string.</summary>
    class function BuildInputAttrs(const ACtx: TKXEditorContext): string;
  end;

implementation

uses
  System.NetEncoding,
  System.StrUtils,
  EF.Localization,
  Kitto.Metadata.DataView,
  Kitto.Html.Utils;

{ TKXEditorFactory }

class function TKXEditorFactory.BuildInputAttrs(const ACtx: TKXEditorContext): string;
begin
  Result := 'id="' + ACtx.InputId + '" name="' + TNetEncoding.HTML.Encode(ACtx.InputName) + '"';
  if ACtx.IsKey then
    Result := Result + ' data-iskey="true"';
  if ACtx.IsRequired and not ACtx.IsReadOnly then
    Result := Result + ' required';
  if ACtx.IsReadOnly then
    Result := Result + ' disabled';
  if ACtx.ExtraAttrs <> '' then
    Result := Result + ' ' + ACtx.ExtraAttrs;
end;

class function TKXEditorFactory.RenderInput(ADataType: TEFDataType;
  const ACtx: TKXEditorContext; AMaxLength: Integer; AIsPassword: Boolean;
  AUseSpeedButtons: Boolean; ACurrDecimals: Integer; ADecSep: Char;
  const ACurrSymbol: string; ALines: Integer; AEditorNode: TEFNode;
  const ACurrencyPrefix: string; ACharHeightFactor: Double): string;
begin
  if ADataType is TEFBooleanDataType then
    Result := RenderCheckboxInput(ACtx)
  else if ADataType is TEFDateDataType then
    Result := RenderDateInput(ACtx)
  else if ADataType is TEFTimeDataType then
    Result := RenderTimeInput(ACtx)
  else if ADataType is TEFDateTimeDataType then
    Result := RenderDateTimeInput(ACtx)
  else if ADataType is TEFIntegerDataType then
    Result := RenderIntegerInput(ACtx, AUseSpeedButtons)
  else if ADataType is TEFCurrencyDataType then
    Result := RenderCurrencyInput(ACtx, ACurrDecimals, ADecSep, ACurrSymbol, ACurrencyPrefix)
  else if ADataType is TEFDecimalNumericDataTypeBase then
    Result := RenderDecimalInput(ACtx)
  else if ADataType is TKHTMLMemoDataType then
    Result := RenderHtmlMemoInput(ACtx, ALines, AEditorNode, ACharHeightFactor)
  else if ADataType is TEFMemoDataType then
    Result := RenderMemoInput(ACtx, ALines)
  else
    Result := RenderTextInput(ACtx, AMaxLength, AIsPassword);
end;

class function TKXEditorFactory.RenderTextInput(const ACtx: TKXEditorContext;
  AMaxLength: Integer; AIsPassword: Boolean): string;
var
  LAttrs: string;
begin
  LAttrs := BuildInputAttrs(ACtx);
  if AIsPassword then
    Result := '<input type="password" class="' + ACtx.CssInputClass + ' kx-input-password" ' + LAttrs
  else
    Result := '<input type="text" class="' + ACtx.CssInputClass + ' kx-input-text" ' + LAttrs;
  if AMaxLength > 0 then
    Result := Result + ' maxlength="' + IntToStr(AMaxLength) + '"';
  Result := Result + ' value="' + TNetEncoding.HTML.Encode(ACtx.Value) + '"';
  Result := Result + ' style="' + ACtx.WidthStyle + '" />';
end;

class function TKXEditorFactory.RenderSearchInput(const ACtx: TKXEditorContext;
  const APlaceholder: string): string;
var
  LAttrs: string;
begin
  LAttrs := BuildInputAttrs(ACtx);
  Result := '<input type="search" class="' + ACtx.CssInputClass + '" ' + LAttrs;
  Result := Result + ' placeholder="' + TNetEncoding.HTML.Encode(APlaceholder) + '"';
  if ACtx.Value <> '' then
    Result := Result + ' value="' + TNetEncoding.HTML.Encode(ACtx.Value) + '"';
  Result := Result + ' />';
end;

class function TKXEditorFactory.RenderSelectInput(const ACtx: TKXEditorContext;
  const AItems: TEFPairs; AAllowEmpty: Boolean): string;
var
  LAttrs: string;
  I: Integer;
begin
  LAttrs := BuildInputAttrs(ACtx);
  Result := '<select class="' + ACtx.CssInputClass + ' kx-input-select" ' + LAttrs;
  Result := Result + ' style="' + ACtx.TriggerWidthStyle + '">';
  if AAllowEmpty then
    Result := Result + '<option value="">--</option>';
  for I := 0 to Length(AItems) - 1 do
  begin
    Result := Result + '<option value="' + TNetEncoding.HTML.Encode(AItems[I].Key) + '"';
    if SameText(ACtx.Value, AItems[I].Key) then
      Result := Result + ' selected';
    Result := Result + '>' + TNetEncoding.HTML.Encode(AItems[I].Value) + '</option>';
  end;
  Result := Result + '</select>';
end;

class function TKXEditorFactory.RenderCheckboxInput(const ACtx: TKXEditorContext): string;
var
  LAttrs: string;
begin
  LAttrs := BuildInputAttrs(ACtx);
  Result := '<input type="checkbox" class="' + ACtx.CssInputClass + ' kx-input-checkbox" ' + LAttrs;
  if SameText(ACtx.Value, 'true') or SameText(ACtx.Value, '1') or SameText(ACtx.Value, 'True') then
    Result := Result + ' checked';
  Result := Result + ' />';
end;

class function TKXEditorFactory.RenderDateInput(const ACtx: TKXEditorContext): string;
var
  LAttrs, LDateWidthStyle: string;
begin
  LAttrs := BuildInputAttrs(ACtx);
  // Date fields need extra px for Firefox segment spacing
  if ACtx.TriggerWidthStyle <> '' then
    LDateWidthStyle := ACtx.TriggerWidthStyle.Replace(
      IntToStr(TRIGGER_PX) + 'px)',
      IntToStr(TRIGGER_PX + DATE_EXTRA_PX) + 'px)')
  else
    LDateWidthStyle := '';
  Result := '<input type="date" class="' + ACtx.CssInputClass + ' kx-input-date';
  if ACtx.Value <> '' then Result := Result + ' has-value';
  Result := Result + '" ' + LAttrs;
  Result := Result + ' value="' + TNetEncoding.HTML.Encode(ACtx.Value) + '"';
  if LDateWidthStyle <> '' then
    Result := Result + ' style="' + LDateWidthStyle + '"';
  Result := Result + ' onchange="this.classList.toggle(''has-value'',!!this.value)"';
  Result := Result + ' />';
end;

class function TKXEditorFactory.RenderTimeInput(const ACtx: TKXEditorContext): string;
var
  LAttrs: string;
begin
  LAttrs := BuildInputAttrs(ACtx);
  Result := '<input type="time" class="' + ACtx.CssInputClass + ' kx-input-time';
  if ACtx.Value <> '' then Result := Result + ' has-value';
  Result := Result + '" ' + LAttrs;
  Result := Result + ' value="' + TNetEncoding.HTML.Encode(ACtx.Value) + '"';
  Result := Result + ' style="' + ACtx.TriggerWidthStyle + '"';
  Result := Result + ' onchange="this.classList.toggle(''has-value'',!!this.value)"';
  Result := Result + ' />';
end;

class function TKXEditorFactory.RenderDateTimeInput(const ACtx: TKXEditorContext): string;
var
  LDateWidthStyle, LTimeWidthStyle: string;
begin
  // Date part è extra px for Firefox segment spacing
  if ACtx.TriggerWidthStyle <> '' then
    LDateWidthStyle := ACtx.TriggerWidthStyle.Replace(
      IntToStr(TRIGGER_PX) + 'px)',
      IntToStr(TRIGGER_PX + DATE_EXTRA_PX) + 'px)')
  else
    LDateWidthStyle := '';
  Result := '<input type="date" class="' + ACtx.CssInputClass + ' kx-input-date';
  if ACtx.Value <> '' then Result := Result + ' has-value';
  Result := Result + '" ';
  Result := Result + 'id="' + ACtx.InputId + '-date" name="' + TNetEncoding.HTML.Encode(ACtx.InputName) + '__date"';
  if ACtx.IsReadOnly then Result := Result + ' disabled';
  // For a mandatory DateTime only the date part is required; an empty time part
  // defaults to 00:00 server-side (see TKWebApplication.PopulateRecordFieldFromPost).
  if ACtx.IsRequired and not ACtx.IsReadOnly then Result := Result + ' required';
  if ACtx.ExtraAttrs <> '' then Result := Result + ' ' + ACtx.ExtraAttrs;
  Result := Result + ' value="' + TNetEncoding.HTML.Encode(ACtx.Value) + '"';
  if LDateWidthStyle <> '' then
    Result := Result + ' style="' + LDateWidthStyle + '"';
  Result := Result + ' onchange="this.classList.toggle(''has-value'',!!this.value)"';
  Result := Result + ' />';

  // Time part
  LTimeWidthStyle := 'width:calc(' + IntToStr(ACtx.EffWidth + SPACER_WIDTH + INPUT_EXTRA_CHS)
    + 'ch + ' + IntToStr(TRIGGER_PX) + 'px)';
  Result := Result + '<input type="time" class="' + ACtx.CssInputClass + ' kx-input-time';
  if ACtx.TimeValue <> '' then Result := Result + ' has-value';
  Result := Result + '" ';
  Result := Result + 'id="' + ACtx.InputId + '-time" name="' + TNetEncoding.HTML.Encode(ACtx.InputName) + '__time"';
  if ACtx.IsReadOnly then Result := Result + ' disabled';
  if ACtx.ExtraAttrs <> '' then Result := Result + ' ' + ACtx.ExtraAttrs;
  Result := Result + ' value="' + TNetEncoding.HTML.Encode(ACtx.TimeValue) + '"';
  Result := Result + ' style="' + LTimeWidthStyle + '"';
  Result := Result + ' onchange="this.classList.toggle(''has-value'',!!this.value)"';
  Result := Result + ' />';
end;

class function TKXEditorFactory.RenderIntegerInput(const ACtx: TKXEditorContext;
  AUseSpeedButtons: Boolean): string;
var
  LAttrs: string;
begin
  LAttrs := BuildInputAttrs(ACtx);
  if AUseSpeedButtons then
    Result := '<input type="number" class="' + ACtx.CssInputClass + ' kx-input-integer kx-spin-buttons" ' + LAttrs
  else
    Result := '<input type="number" class="' + ACtx.CssInputClass + ' kx-input-integer" ' + LAttrs;
  Result := Result + ' step="1" value="' + TNetEncoding.HTML.Encode(ACtx.Value) + '"';
  if AUseSpeedButtons then
    Result := Result + ' style="' + ACtx.TriggerWidthStyle + '" />'
  else
    Result := Result + ' style="' + ACtx.WidthStyle + '" />';
end;

class function TKXEditorFactory.RenderCurrencyInput(const ACtx: TKXEditorContext;
  ADecimals: Integer; ADecSep: Char; const ACurrSymbol: string;
  const ACallbackPrefix: string): string;
var
  LAttrs: string;
begin
  LAttrs := BuildInputAttrs(ACtx);
  Result := '<input type="text" inputmode="decimal" class="' + ACtx.CssInputClass + ' kx-input-currency" ' + LAttrs;
  Result := Result + ' value="' + TNetEncoding.HTML.Encode(ACtx.Value) + '"';
  Result := Result + ' style="' + ACtx.WidthStyle + '"';
  Result := Result + ' onfocus="' + ACallbackPrefix + '.focusCurrency(this,''' + ACurrSymbol + ''')"';
  Result := Result + ' onblur="' + ACallbackPrefix + '.formatCurrency(this,''' + ADecSep + ''',' + IntToStr(ADecimals);
  Result := Result + ',''' + ACurrSymbol + ''')" />';
end;

class function TKXEditorFactory.RenderDecimalInput(const ACtx: TKXEditorContext): string;
var
  LAttrs: string;
begin
  LAttrs := BuildInputAttrs(ACtx);
  Result := '<input type="text" inputmode="decimal" class="' + ACtx.CssInputClass + ' kx-input-decimal" ' + LAttrs;
  Result := Result + ' value="' + TNetEncoding.HTML.Encode(ACtx.Value) + '"';
  Result := Result + ' style="' + ACtx.WidthStyle + '" />';
end;

class function TKXEditorFactory.RenderMemoInput(const ACtx: TKXEditorContext;
  ARows: Integer): string;
var
  LAttrs: string;
begin
  LAttrs := BuildInputAttrs(ACtx);
  Result := '<textarea class="' + ACtx.CssInputClass + ' kx-input-memo" ' + LAttrs;
  Result := Result + ' rows="' + IntToStr(ARows) + '"';
  Result := Result + ' style="' + ACtx.WidthStyle + '">';
  Result := Result + TNetEncoding.HTML.Encode(ACtx.Value) + '</textarea>';
end;

class function TKXEditorFactory.RenderHtmlMemoInput(const ACtx: TKXEditorContext;
  ARows: Integer; AEditorNode: TEFNode; ACharHeightFactor: Double): string;
var
  LAttrs: string;
  LInvariant: TFormatSettings;
begin
  LAttrs := BuildInputAttrs(ACtx);
  LInvariant := TFormatSettings.Invariant;
  Result := '<textarea class="' + ACtx.CssInputClass + ' kx-html-editor" ' + LAttrs;
  Result := Result + ' rows="' + IntToStr(ARows) + '"';
  Result := Result + ' data-editor-width="' + IntToStr(ACtx.EffWidth + INPUT_EXTRA_CHS) + '"';
  Result := Result + ' data-height-factor="' + FormatFloat('0.##', ACharHeightFactor, LInvariant) + '"';
  Result := Result + ' style="' + ACtx.WidthStyle + '"';
  if Assigned(AEditorNode) then
  begin
    if not AEditorNode.GetBoolean('EnableFont', True) then
      Result := Result + ' data-no-font="1"';
    if not AEditorNode.GetBoolean('EnableFontSize', True) then
      Result := Result + ' data-no-fontsize="1"';
    if not AEditorNode.GetBoolean('EnableColors', True) then
      Result := Result + ' data-no-colors="1"';
    if not AEditorNode.GetBoolean('EnableAlignments', True) then
      Result := Result + ' data-no-align="1"';
    if not AEditorNode.GetBoolean('EnableLinks', True) then
      Result := Result + ' data-no-links="1"';
    if not AEditorNode.GetBoolean('EnableLists', True) then
      Result := Result + ' data-no-lists="1"';
    if not AEditorNode.GetBoolean('EnableSourceEdit', True) then
      Result := Result + ' data-no-source="1"';
    if not AEditorNode.GetBoolean('EnableFormat', True) then
      Result := Result + ' data-no-format="1"';
  end;
  Result := Result + '>';
  Result := Result + TNetEncoding.HTML.Encode(ACtx.Value) + '</textarea>';
end;

class function TKXEditorFactory.RenderNumberInput(const ACtx: TKXEditorContext): string;
var
  LAttrs: string;
begin
  LAttrs := BuildInputAttrs(ACtx);
  Result := '<input type="number" class="' + ACtx.CssInputClass + '" ' + LAttrs;
  if ACtx.Value <> '' then
    Result := Result + ' value="' + TNetEncoding.HTML.Encode(ACtx.Value) + '"';
  Result := Result + ' />';
end;

class function TKXEditorFactory.RenderSmallReferenceSelect(
  const ACtx: TKXEditorContext; const AOptionsHtml: string): string;
var
  LAttrs: string;
begin
  LAttrs := BuildInputAttrs(ACtx);
  Result := '<select class="' + ACtx.CssInputClass + ' kx-input-select" ' + LAttrs;
  Result := Result + ' style="' + ACtx.TriggerWidthStyle + '">';
  Result := Result + AOptionsHtml;
  Result := Result + '</select>';
end;

class function TKXEditorFactory.RenderLargeReferenceEditor(
  const ACtx: TKXEditorContext;
  const ACurrentKeyValue, ACurrentCaption: string;
  const AHiddenAttrs: string;
  const ASearchIcon, AClearIcon: string;
  const ACallbackPrefix: string;
  const ACallbackViewName, ACallbackFieldName: string): string;
begin
  Result :=
    '<div class="kx-form-lookup-wrapper">' +
      '<input type="hidden"' +
      ' name="' + TNetEncoding.HTML.Encode(ACtx.InputName) + '"' +
      ' id="' + ACtx.InputId + '-key"' +
      ' value="' + TNetEncoding.HTML.Encode(ACurrentKeyValue) + '"' +
      // Emit the HTML5 required attribute on the (hidden) value input for a
      // mandatory reference, so the client-side validator blocks submission when
      // it is left empty. A hidden input can't receive focus or show a validity
      // bubble, so the validator surfaces the message on the visible display.
      IfThen(ACtx.IsRequired and not ACtx.IsReadOnly, ' required', '') +
      AHiddenAttrs +
      ' />' +
      '<input type="text" class="' + ACtx.CssInputClass + ' kx-form-lookup-display" readonly' +
      ' id="' + ACtx.InputId + '-display"' +
      ' value="' + TNetEncoding.HTML.Encode(ACurrentCaption) + '"' +
      ' style="' + ACtx.TriggerWidthStyle + '"' +
      ' />';

  // Search / Clear: emit with kx-btn-editmode so setMode toggles visibility
  // on view<->edit switch; suppress entirely if intrinsically read-only.
  if not ACtx.IsIntrinsicallyReadOnly then
    Result := Result +
      '<button type="button" class="kx-form-lookup-btn kx-btn-editmode" title="' + _('Search') + '"' +
      IfThen(ACtx.IsReadOnly, ' style="display:none"', '') +
      ' onclick="' + ACallbackPrefix + '.openLookup(''' + ACallbackViewName + ''',''' + ACallbackFieldName + ''')">' +
      ASearchIcon + '</button>' +
      '<button type="button" class="kx-form-lookup-btn kx-btn-editmode" title="' + _('Clear') + '"' +
      IfThen(ACtx.IsReadOnly, ' style="display:none"', '') +
      ' onclick="' + ACallbackPrefix + '.clearLookup(''' + ACallbackViewName + ''',''' + ACallbackFieldName + ''')">' +
      AClearIcon + '</button>';

  Result := Result + '</div>';
end;

end.
