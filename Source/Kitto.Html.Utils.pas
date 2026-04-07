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
///  Utility functions for KittoX HTML controllers.
///  Same logic as Kitto.Ext.Utils, adapted for TKXControllerRegistry.
///  Includes SVG icon support with Material Design Icons mapping.
/// </summary>
unit Kitto.Html.Utils;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  EF.Tree,
  Kitto.Metadata.Views;

type
  /// <summary>
  ///  Icon sizes for GetIconHTML. Maps to CSS classes kx-icon-sm/md/lg.
  ///  isDefault uses the theme-configured default (set via SetDefaultIconSize).
  /// </summary>
  TKXIconSize = (isDefault, isSmall, isMedium, isLarge);

/// <summary>
///  Returns HTML for an icon. Looks for SVG in Resources/icons/ first
///  (using icon name mapping for legacy Kitto names), falls back to PNG.
///  SVG icons use CSS mask-image and adapt to light/dark themes automatically.
/// </summary>
function GetIconHTML(const AIconName: string;
  ASize: TKXIconSize = isDefault;
  const AExtraCssClass: string = ''): string;

function GetTreeViewNodeImageName(const ANode: TKTreeViewNode; const AView: TKView): string;

/// <summary>
///  Computes and returns a display label based on the underlying view,
///  if any, or the node itself (if no view is found).
/// </summary>
function GetDisplayLabelFromNode(const ANode: TKTreeViewNode; const AViews: TKViews): string;

/// <summary>
///  Invoke a method of a View's controller class that returns a string, using RTTI.
/// </summary>
function CallViewControllerStringMethod(const AView: TKView;
  const AMethodName: string; const ADefaultValue: string): string;

procedure DownloadThumbnailedStream(const AStream: TStream; const AFileName: string;
  const AThumbnailWidth, AThumbnailHeight: Integer);

/// <summary>
///  Sets the icon style subdirectory (filled, outlined, round, sharp, two-tone).
///  Called from TKWebApplication.ServeHomePage after reading Theme/IconStyle from Config.
/// </summary>
procedure SetIconStyle(const AStyle: string);

/// <summary>
///  Returns the current icon style subdirectory (filled, outlined, round, sharp, two-tone).
/// </summary>
function GetIconStyle: string;

/// <summary>
///  Sets the default icon size used when GetIconHTML is called with isDefault.
///  Called from TKWebApplication.ServeHomePage after reading Theme/IconSize from Config.
/// </summary>
procedure SetDefaultIconSize(const ASize: string);

implementation

uses
  System.Types,
  System.StrUtils,
  System.Rtti,
  System.Generics.Collections,
  {$IFDEF MSWINDOWS}
  Vcl.Graphics,
  Vcl.Imaging.jpeg,
  Vcl.Imaging.pngimage,
  {$ENDIF}
  EF.Localization,
  EF.Macros,
  Kitto.Html.Controller,
  Kitto.Web.Application;

var
  _IconMap: TDictionary<string, string>;
  _IconStyle: string;
  _DefaultIconSize: TKXIconSize;

function GetIconStyle: string;
begin
  if _IconStyle = '' then
    _IconStyle := 'filled';
  Result := _IconStyle;
end;

procedure SetIconStyle(const AStyle: string);
begin
  if AStyle <> '' then
    _IconStyle := LowerCase(AStyle)
  else
    _IconStyle := 'filled';
end;

procedure SetDefaultIconSize(const ASize: string);
var
  S: string;
begin
  S := LowerCase(ASize);
  if S = 'small' then
    _DefaultIconSize := isSmall
  else if S = 'large' then
    _DefaultIconSize := isLarge
  else
    _DefaultIconSize := isMedium; // default
end;

procedure InitIconMap;
begin
  _IconMap := TDictionary<string, string>.Create;
  // Actions
  _IconMap.Add('accept', 'check_circle');
  _IconMap.Add('accept_clone', 'save_as');
  _IconMap.Add('cancel', 'cancel');
  _IconMap.Add('clear', 'clear');
  _IconMap.Add('close', 'close');
  _IconMap.Add('delete_record', 'delete');
  _IconMap.Add('dup_record', 'content_copy');
  _IconMap.Add('edit_record', 'edit');
  _IconMap.Add('new_record', 'add_circle');
  _IconMap.Add('view_record', 'visibility');
  _IconMap.Add('save', 'save');
  _IconMap.Add('save_all', 'save_as');
  _IconMap.Add('refresh', 'refresh');
  _IconMap.Add('find', 'search');
  _IconMap.Add('preview', 'visibility');
  // Navigation
  _IconMap.Add('back', 'arrow_back');
  _IconMap.Add('next', 'chevron_right');
  _IconMap.Add('previous', 'chevron_left');
  // Auth
  _IconMap.Add('login', 'login');
  _IconMap.Add('logout', 'logout');
  _IconMap.Add('password', 'vpn_key');
  _IconMap.Add('user', 'person');
  // Documents
  _IconMap.Add('excel_document', 'table_chart');
  _IconMap.Add('html_document', 'code');
  _IconMap.Add('pdf_document', 'picture_as_pdf');
  _IconMap.Add('text_document', 'description');
  _IconMap.Add('xml_document', 'integration_instructions');
  _IconMap.Add('image_jpg', 'image');
  _IconMap.Add('image_png', 'image');
  _IconMap.Add('picture', 'image');
  // Communication
  _IconMap.Add('email_go', 'email');
  // Tools & commands
  _IconMap.Add('tool_exec', 'build');
  _IconMap.Add('tool', 'handyman');
  _IconMap.Add('execute_command', 'play_circle');
  _IconMap.Add('exec_sqlcommand', 'terminal');
  _IconMap.Add('exec_storedproc', 'settings');
  // Misc
  _IconMap.Add('help', 'help');
  _IconMap.Add('www_page', 'public');
  _IconMap.Add('default_model', 'storage');
  _IconMap.Add('default_view', 'window');
  _IconMap.Add('text_signature', 'draw');
  _IconMap.Add('home', 'home');
  _IconMap.Add('settings', 'settings');
  _IconMap.Add('print', 'print');
  _IconMap.Add('project', 'view_kanban');
  _IconMap.Add('operator', 'badge');
  _IconMap.Add('people', 'group');
  _IconMap.Add('folder-open', 'folder_open');
  // Business
  _IconMap.Add('basket_put', 'shopping_bag');
  _IconMap.Add('building_edit', 'business');
  _IconMap.Add('chart_bar', 'bar_chart');
  _IconMap.Add('chart_column_bar', 'bar_chart');
  _IconMap.Add('chart_pie', 'pie_chart');
  _IconMap.Add('creditcard', 'credit_card');

  // Bootstrap Icons → MDI compatibility aliases
  // (for YAML files that already used BSI names; resolution first
  // converts hyphen→underscore, then looks up in the map)
  _IconMap.Add('check-circle', 'check_circle');
  _IconMap.Add('x-circle', 'cancel');
  _IconMap.Add('x-lg', 'close');
  _IconMap.Add('pencil-square', 'edit');
  _IconMap.Add('plus-circle', 'add_circle');
  _IconMap.Add('arrow-clockwise', 'refresh');
  _IconMap.Add('arrow-left', 'arrow_back');
  _IconMap.Add('chevron-right', 'chevron_right');
  _IconMap.Add('chevron-left', 'chevron_left');
  _IconMap.Add('chevron-up', 'expand_less');
  _IconMap.Add('chevron-down', 'expand_more');
  _IconMap.Add('chevron-double-left', 'first_page');
  _IconMap.Add('chevron-double-right', 'last_page');
  _IconMap.Add('box-arrow-in-right', 'login');
  _IconMap.Add('box-arrow-right', 'logout');
  _IconMap.Add('play-circle', 'play_circle');
  _IconMap.Add('question-circle', 'help');
  _IconMap.Add('bar-chart-line', 'bar_chart');
  _IconMap.Add('pie-chart', 'pie_chart');
  _IconMap.Add('person-badge', 'badge');
  _IconMap.Add('folder2-open', 'folder_open');
  _IconMap.Add('file-earmark-spreadsheet', 'table_chart');
  _IconMap.Add('file-earmark-code', 'code');
  _IconMap.Add('file-earmark-pdf', 'picture_as_pdf');
  _IconMap.Add('file-earmark-text', 'description');
  _IconMap.Add('file-earmark-image', 'image');
  _IconMap.Add('bag-plus', 'shopping_bag');
  _IconMap.Add('credit-card', 'credit_card');
end;

function GetIconSizeClass(ASize: TKXIconSize): string;
var
  LEffective: TKXIconSize;
begin
  if ASize = isDefault then
    LEffective := _DefaultIconSize
  else
    LEffective := ASize;
  case LEffective of
    isSmall:  Result := 'kx-icon-sm';
    isMedium: Result := 'kx-icon-md';
    isLarge:  Result := 'kx-icon-lg';
  else
    Result := 'kx-icon-md';
  end;
end;

function GetIconHTML(const AIconName: string;
  ASize: TKXIconSize = isDefault;
  const AExtraCssClass: string = ''): string;
var
  LSvgURL, LMappedName, LPngURL, LSizeClass, LClassList, LIconStyle: string;
begin
  Result := '';
  if AIconName = '' then
    Exit;

  LSizeClass := GetIconSizeClass(ASize);
  LSvgURL := '';
  LIconStyle := GetIconStyle;

  // 1. Try mapped name (Kitto legacy → MDI name)
  if _IconMap.TryGetValue(LowerCase(AIconName), LMappedName) then
    LSvgURL := TKWebApplication.Current.FindResourceURL(
      'icons/' + LIconStyle + '/' + LMappedName + '.svg');

  // 2. Try direct name with underscores (MDI native name)
  if LSvgURL = '' then
    LSvgURL := TKWebApplication.Current.FindResourceURL(
      'icons/' + LIconStyle + '/' + AIconName + '.svg');

  // 3. Try with hyphen→underscore conversion
  if (LSvgURL = '') and (Pos('-', AIconName) > 0) then
    LSvgURL := TKWebApplication.Current.FindResourceURL(
      'icons/' + LIconStyle + '/' + StringReplace(AIconName, '-', '_', [rfReplaceAll]) + '.svg');

  // 4. Try filled as universal fallback (icon may not exist in all styles)
  if (LSvgURL = '') and not SameText(LIconStyle, 'filled') then
  begin
    if _IconMap.TryGetValue(LowerCase(AIconName), LMappedName) then
      LSvgURL := TKWebApplication.Current.FindResourceURL(
        'icons/filled/' + LMappedName + '.svg');
    if LSvgURL = '' then
      LSvgURL := TKWebApplication.Current.FindResourceURL(
        'icons/filled/' + AIconName + '.svg');
    if (LSvgURL = '') and (Pos('-', AIconName) > 0) then
      LSvgURL := TKWebApplication.Current.FindResourceURL(
        'icons/filled/' + StringReplace(AIconName, '-', '_', [rfReplaceAll]) + '.svg');
  end;

  if LSvgURL <> '' then
  begin
    // SVG icon: render as span with CSS mask-image (theme-adaptive)
    LClassList := 'kx-icon ' + LSizeClass;
    if AExtraCssClass <> '' then
      LClassList := LClassList + ' ' + AExtraCssClass;
    Result := '<span class="' + LClassList +
      '" style="-webkit-mask-image: url(''' + LSvgURL +
      '''); mask-image: url(''' + LSvgURL + ''')"></span>';
  end
  else
  begin
    // 5. Fall back to PNG
    LPngURL := TKWebApplication.Current.FindImageURL(AIconName);
    if LPngURL <> '' then
    begin
      LClassList := 'kx-icon-img ' + LSizeClass;
      if AExtraCssClass <> '' then
        LClassList := LClassList + ' ' + AExtraCssClass;
      Result := '<img src="' + LPngURL + '" class="' + LClassList + '" alt="">';
    end;
  end;
end;

function CallViewControllerStringMethod(const AView: TKView;
  const AMethodName: string; const ADefaultValue: string): string;
var
  LControllerClass: TClass;
  LContext: TRttiContext;
  LMethod: TRttiMethod;
  LType: string;
begin
  Assert(Assigned(AView));
  Assert(AMethodName <> '');

  Result := ADefaultValue;

  LType := AView.ControllerType;
  if LType <> '' then
  begin
    LControllerClass := TKXControllerRegistry.Instance.FindClass(LType);
    if Assigned(LControllerClass) then
    begin
      LMethod := LContext.GetType(LControllerClass).GetMethod(AMethodName);
      if Assigned(LMethod) then
        Result := LMethod.Invoke(LControllerClass, []).AsString;
    end;
  end;
end;

function GetDisplayLabelFromNode(const ANode: TKTreeViewNode; const AViews: TKViews): string;
var
  LView: TKView;
begin
  Assert(Assigned(ANode));

  LView := ANode.FindView(AViews);
  if Assigned(LView) then
  begin
    Result := _(LView.DisplayLabel);
    if Result = '' then
      Result := CallViewControllerStringMethod(LView, 'GetDefaultDisplayLabel', Result);
    if Result = '' then
      Result := _(LView.ControllerType);
  end
  else
  begin
    Result := _(ANode.AsString);
    TEFMacroExpansionEngine.Instance.Expand(Result);
  end;
end;

function GetTreeViewNodeImageName(const ANode: TKTreeViewNode; const AView: TKView): string;
begin
  Assert(Assigned(ANode));
  Assert(Assigned(AView));

  Result := ANode.GetString('ImageName');
  if Result = '' then
    Result := CallViewControllerStringMethod(AView, 'GetDefaultImageName', '');
end;

procedure DownloadThumbnailedStream(const AStream: TStream; const AFileName: string;
  const AThumbnailWidth, AThumbnailHeight: Integer);
{$IFDEF MSWINDOWS}
{ Paradox graphic BLOB header }

type
  TPDoxGraphicHeader = record
    Count: Word;                { Fixed at 1 }
    HType: Word;                { Fixed at $0100 }
    Size: Integer              { Size not including header }
  end;

var
  LFileExt: string;
  LBytes: TBytes;
  Size: Longint;
  Header: TBytes;
  GraphicHeader: TPDoxGraphicHeader;

  function CreateThumbnail(const AMaxWidth, AMaxHeight: Integer;
    const AImageClass: TGraphicClass): TBytes;
  var
    LImage: TGraphic;
    LScale: Extended;
    LBitmap: TBitmap;

    function GetImageBytes: TBytes;
    var
      LStream: TBytesStream;
    begin
      LStream := TBytesStream.Create;
      try
        LImage.SaveToStream(LStream);
        Result := Copy(LStream.Bytes, 0, LStream.Size);
      finally
        FreeAndNil(LStream);
      end;
    end;

  begin
    LImage := AImageClass.Create;
    try
      Size := AStream.Size;
      if Size >= SizeOf(TPDoxGraphicHeader) then
      begin
        SetLength(Header, SizeOf(TPDoxGraphicHeader));
        AStream.Read(Header, 0, Length(Header));
        Move(Header[0], GraphicHeader, SizeOf(TPDoxGraphicHeader));
        if (GraphicHeader.Count <> 1) or (GraphicHeader.HType <> $0100) or
          (GraphicHeader.Size <> Size - SizeOf(GraphicHeader)) then
          AStream.Position := 0;
      end;
      LImage.LoadFromStream(AStream);
      if (LImage.Height <= AMaxHeight) and (LImage.Width <= AMaxWidth) then
        Exit(GetImageBytes);

      if LImage.Height > LImage.Width then
        LScale := AMaxHeight / LImage.Height
      else
        LScale := AMaxWidth / LImage.Width;
      LBitmap := TBitmap.Create;
      try
        LBitmap.Width := Round(LImage.Width * LScale);
        LBitmap.Height := Round(LImage.Height * LScale);
        LBitmap.Canvas.StretchDraw(LBitmap.Canvas.ClipRect, LImage);

        LImage.Assign(LBitmap);

        Exit(GetImageBytes);
      finally
        LBitmap.Free;
      end;
    finally
      LImage.Free;
    end;
  end;
{$ENDIF}

begin
  Assert(Assigned(AStream));

  {$IFDEF MSWINDOWS}
  LFileExt := ExtractFileExt(AFileName);
  if MatchText(LFileExt, ['.jpg', '.jpeg', '.png']) then
  begin
    try
      if MatchText(LFileExt, ['.jpg', '.jpeg']) then
        LBytes := CreateThumbnail(AThumbnailWidth, AThumbnailHeight, TJPEGImage)
      else
        LBytes := CreateThumbnail(AThumbnailWidth, AThumbnailHeight, TPngImage);
    finally
      AStream.Free;
    end;
    TKWebApplication.Current.DownloadBytes(LBytes, AFileName);
  end
  else if MatchText(LFileExt, ['.bmp']) then
  begin
    try
      LBytes := CreateThumbnail(AThumbnailWidth, AThumbnailHeight, TBitmap);
    finally
      AStream.Free;
    end;
    TKWebApplication.Current.DownloadBytes(LBytes, AFileName);
  end
  else
  {$ENDIF}
    TKWebApplication.Current.DownloadStream(AStream, AFileName);
end;

initialization
  _DefaultIconSize := isMedium;
  InitIconMap;

finalization
  FreeAndNil(_IconMap);

end.
