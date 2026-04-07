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
///  Base panel controller for the KittoX HTML pipeline.
///  Handles Width, Height, Title, AllowClose, Autoscroll, Border, Header,
///  Collapsible and dialog overlay rendering.
///  Subclasses only need to implement RenderContent.
///  Replaces TKExtPanelControllerBase from Kitto.Ext.Panel.
/// </summary>
unit Kitto.Html.Panel;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.Base,
  Kitto.Html.Controller,
  EF.YAML.Attributes;

const
  DEFAULT_WINDOW_WIDTH = 800;
  DEFAULT_WINDOW_HEIGHT = 600;

type
  /// <summary>
  ///  Abstract base panel controller. Reads panel-level Config properties
  ///  (Width, Height, Title, AllowClose, Autoscroll, Border, Header,
  ///  Collapsible, Collapsed) in DoDisplay.
  ///  When AllowClose is True, renders as a dialog overlay with title bar
  ///  and close button. When Header is True, renders with a panel header
  ///  bar (and optional collapse support). Otherwise renders as an inline
  ///  panel div. Width and Height are applied as CSS dimensions in both modes.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXPanelControllerBase = class abstract(TKXComponent, IKXController)
  strict private
    FTitle: string;
    FWidth: Integer;
    FHeight: Integer;
    FIsModal: Boolean;
    FMaximized: Boolean;
    FAllowClose: Boolean;
    FAutoscroll: Boolean;
    FResizable: Boolean;
    FBorder: Boolean;
    FHeader: Boolean;
    FCollapsible: Boolean;
    FCollapsed: Boolean;
    function GetIsModal: Boolean;
    function GetMaximized: Boolean;
    function GetWidth: Integer;
    function GetHeight: Integer;
    function BuildStyleAttr: string;
  strict protected
    function GetDefaultIsModal: Boolean; virtual;
    function GetDefaultWidth: Integer; virtual;
    function GetDefaultHeight: Integer; virtual;

    /// <summary>
    ///  Returns the CSS class for the inline panel div.
    ///  Default returns empty string. Subclasses can override
    ///  (e.g. HtmlPanel returns 'kx-html-panel').
    /// </summary>
    function GetPanelCssClass: string; virtual;

    /// <summary>
    ///  Reads panel-level Config properties. Called from Display.
    ///  Subclasses can override to read additional properties (call inherited first).
    /// </summary>
    procedure DoDisplay; virtual;

    /// <summary>
    ///  Returns the inner HTML content of the panel.
    ///  Subclasses must implement this.
    /// </summary>
    function RenderContent: string; virtual; abstract;

    /// <summary>
    ///  Wraps the center content with region views (North, West, East, South)
    ///  if any are defined in Config. If no regions are found, returns the
    ///  center content unchanged. Uses the same CSS grid layout as BorderPanel.
    /// </summary>
    function RenderWithRegions(const ACenterHtml: string): string; virtual;
  public
    procedure Display; override;
    function Render: string; override;
    [YamlNode('Title', 'Panel title text')]
    property Title: string read FTitle write FTitle;
    [YamlNode('Width', 'Panel width in pixels (0 = auto)')]
    property Width: Integer read GetWidth write FWidth;
    [YamlNode('Height', 'Panel height in pixels (0 = auto)')]
    property Height: Integer read GetHeight write FHeight;
    [YamlNode('IsModal', 'False', 'Show as dialog overlay (True for forms, False for lists)')]
    property IsModal: Boolean read GetIsModal write FIsModal;
    [YamlNode('Maximized', 'False', 'Dialog fills the entire viewport (default True on mobile)')]
    property Maximized: Boolean read GetMaximized write FMaximized;
    [YamlNode('AllowClose', 'True', 'Show close button in dialog and Close button in forms')]
    property AllowClose: Boolean read FAllowClose write FAllowClose;
    [YamlNode('Autoscroll', 'False', 'Enable scrollbars when content overflows')]
    property Autoscroll: Boolean read FAutoscroll write FAutoscroll;
    [YamlNode('Resizable', 'True', 'Allow dialog resizing (when IsModal is True)')]
    property Resizable: Boolean read FResizable write FResizable;
    [YamlNode('Border', 'False', 'Show panel border')]
    property Border: Boolean read FBorder write FBorder;
    [YamlNode('Header', 'False', 'Show panel header bar')]
    property Header: Boolean read FHeader write FHeader;
    [YamlNode('Collapsible', 'False', 'Allow panel to be collapsed')]
    property Collapsible: Boolean read FCollapsible write FCollapsible;
    [YamlNode('Collapsed', 'False', 'Panel starts in collapsed state')]
    property Collapsed: Boolean read FCollapsed write FCollapsed;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.NetEncoding,
  EF.Localization,
  Kitto.Web.Session,
  Kitto.Web.Application,
  Kitto.Html.BorderPanel,
  Kitto.Html.Utils;

{ TKXPanelControllerBase }

function TKXPanelControllerBase.GetDefaultIsModal: Boolean;
begin
  Result := False;
end;

function TKXPanelControllerBase.GetIsModal: Boolean;
begin
  Result := FIsModal;
end;

function TKXPanelControllerBase.GetMaximized: Boolean;
begin
  Result := FMaximized;
end;

function TKXPanelControllerBase.GetWidth: Integer;
begin
  if Maximized then
    Result := 0
  else
    Result := FWidth;
end;

function TKXPanelControllerBase.GetHeight: Integer;
begin
  if Maximized then
    Result := 0
  else
    Result := FHeight;
end;

function TKXPanelControllerBase.GetDefaultWidth: Integer;
begin
  Result := TKWebApplication.Current.Config.Config.GetInteger(
    'Defaults/Window/Width', 0);
end;

function TKXPanelControllerBase.GetDefaultHeight: Integer;
begin
  Result := TKWebApplication.Current.Config.Config.GetInteger(
    'Defaults/Window/Height', 0);
end;

function TKXPanelControllerBase.GetPanelCssClass: string;
begin
  Result := '';
end;

procedure TKXPanelControllerBase.Display;
begin
  DoDisplay;
end;

procedure TKXPanelControllerBase.DoDisplay;
begin
  // IsModal: show as dialog overlay. Default depends on subclass.
  FIsModal := Config.GetBoolean('IsModal', GetDefaultIsModal);
  // Maximized: dialog fills the viewport (no Width/Height, no resize, no border).
  // Default False on desktop, can be set True in YAML for fullscreen dialogs.
  FMaximized := Config.GetBoolean('Maximized', False);
  // AllowClose: show close button (X in dialog, Close in form). Default True.
  FAllowClose := Config.GetBoolean('AllowClose', True);
  FWidth := Config.GetInteger('Width', 0);
  FHeight := Config.GetInteger('Height', 0);
  FAutoscroll := Config.GetBoolean('Autoscroll', False);
  FResizable := Config.GetBoolean('Resizable', True);
  FBorder := Config.GetBoolean('Border', False);
  FHeader := Config.GetBoolean('Header', False);
  FCollapsible := Config.GetBoolean('Collapsible', False);
  FCollapsed := Config.GetBoolean('Collapsed', False);

  // Default window dimensions only apply to dialog overlays
  if IsModal then
  begin
    if FWidth = 0 then
      FWidth := GetDefaultWidth;
    if FHeight = 0 then
      FHeight := GetDefaultHeight;
  end;

  // Resolve title: View.DisplayLabel takes precedence, then Config/Title
  FTitle := '';
  if Assigned(View) then
    FTitle := _(View.DisplayLabel);
  if FTitle = '' then
    FTitle := Config.GetExpandedString('Title', '');
end;

function TKXPanelControllerBase.BuildStyleAttr: string;
begin
  Result := '';
  if FWidth > 0 then
    Result := Result + Format('width: %dpx; ', [FWidth]);
  if FHeight > 0 then
    Result := Result + Format('height: %dpx; ', [FHeight]);
  if FAutoscroll then
    Result := Result + 'overflow: auto; ';
  if Result <> '' then
    Result := ' style="' + Result + '"';
end;

function TKXPanelControllerBase.RenderWithRegions(const ACenterHtml: string): string;
var
  LNorthHtml, LWestHtml, LEastHtml, LSouthHtml: string;
  LHasRegions: Boolean;
begin
  // Dialog panels (Form, etc.) never render regions � the Config may contain
  // region nodes inherited from the parent List view which are not relevant.
  if IsModal then
    Exit(ACenterHtml);

  // Check if any region views are defined in Config
  LHasRegions :=
    Assigned(Config.FindNode('NorthView')) or Assigned(Config.FindNode('NorthController')) or
    Assigned(Config.FindNode('WestView')) or Assigned(Config.FindNode('WestController')) or
    Assigned(Config.FindNode('EastView')) or Assigned(Config.FindNode('EastController')) or
    Assigned(Config.FindNode('SouthView')) or Assigned(Config.FindNode('SouthController'));

  if not LHasRegions then
    Exit(ACenterHtml);

  // Render each region using the standalone functions from Kitto.Html.BorderPanel
  LNorthHtml := RenderNamedRegion(Config, View, 'North', 'kx-region-north');
  LWestHtml := RenderNamedRegion(Config, View, 'West', 'kx-region-west');
  LEastHtml := RenderNamedRegion(Config, View, 'East', 'kx-region-east');
  LSouthHtml := RenderNamedRegion(Config, View, 'South', 'kx-region-south');

  // Wrap with border panel layout: the center content is the panel's own content
  Result := Format(
    '<div class="kx-border-panel">' +
    '%s%s<div class="kx-region-center">%s</div>%s%s' +
    '</div>',
    [LNorthHtml, LWestHtml, ACenterHtml, LEastHtml, LSouthHtml]);
end;

function TKXPanelControllerBase.Render: string;
var
  LContentHtml: string;
  LStyleAttr: string;
  LBodyStyle: string;
  LCssClass: string;
  LClassAttr: string;
  LSizeStyle: string;
begin
  LContentHtml := RenderWithRegions(RenderContent);

  // Dialog overlay mode: when IsModal is True.
  if IsModal then
  begin
    if Maximized then
    begin
      // Maximized: fullscreen dialog, no fixed dimensions, no resize
      LSizeStyle := '';
      LCssClass := 'kx-dialog kx-dialog-maximized';
    end
    else
    begin
      // Normal dialog: apply Width/Height
      LSizeStyle := '';
      if FWidth > 0 then
        LSizeStyle := LSizeStyle + Format('width: %dpx; ', [FWidth]);
      if FHeight > 0 then
        LSizeStyle := LSizeStyle + Format('height: %dpx; ', [FHeight]);
      if not FResizable then
        LSizeStyle := LSizeStyle + 'resize: none; ';
      LCssClass := 'kx-dialog';
    end;
    if LSizeStyle <> '' then
      LSizeStyle := ' style="' + LSizeStyle + '"';

    LBodyStyle := '';
    if FAutoscroll then
      LBodyStyle := ' style="overflow: auto;"';

    Result :=
      '<div id="' + GetHtmlId + '" class="kx-dialog-overlay">' +
        '<div class="' + LCssClass + '"' + LSizeStyle + '>';

    // Dialog header with title and optional close button
    Result := Result +
          '<div class="kx-dialog-header">' +
            '<span class="kx-dialog-title">' +
              TNetEncoding.HTML.Encode(FTitle) + '</span>';
    if FAllowClose then
      Result := Result +
            '<button class="kx-dialog-close-btn" ' +
              'onclick="this.closest(''.kx-dialog-overlay'').remove();">' +
              GetIconHTML('close') + '</button>';
    Result := Result +
          '</div>' +
          '<div class="kx-dialog-body"' + LBodyStyle + '>' +
            LContentHtml +
          '</div>' +
        '</div>' +
      '</div>';
  end
  else
  begin
    // Inline panel mode
    LStyleAttr := BuildStyleAttr;
    LCssClass := GetPanelCssClass;

    // Header/Collapsible/Border support
    if FHeader or FCollapsible then
    begin
      // Panel with header bar (and optional collapse/border)
      if LCssClass <> '' then
        LCssClass := 'kx-panel ' + LCssClass
      else
        LCssClass := 'kx-panel';
      if FBorder then
        LCssClass := LCssClass + ' kx-panel-bordered';
      if FCollapsible then
        LCssClass := LCssClass + ' kx-panel-collapsible';
      if FCollapsed then
        LCssClass := LCssClass + ' kx-panel-collapsed';

      Result :=
        '<div id="' + GetHtmlId + '" class="' + LCssClass + '"' + LStyleAttr + '>' +
          '<div class="kx-panel-header" ' +
            IfThen(FCollapsible,
              'onclick="this.parentElement.classList.toggle(''kx-panel-collapsed'')"', '') + '>' +
            '<span class="kx-panel-title">' +
              TNetEncoding.HTML.Encode(FTitle) + '</span>' +
            IfThen(FCollapsible,
              '<span class="kx-panel-toggle">' +
                GetIconHTML('expand_less') + '</span>', '') +
          '</div>' +
          '<div class="kx-panel-body">' +
            LContentHtml +
          '</div>' +
        '</div>';
    end
    else
    begin
      // Simple panel div (original behavior)
      if FBorder and (LCssClass <> '') then
        LCssClass := LCssClass + ' kx-panel-bordered'
      else if FBorder then
        LCssClass := 'kx-panel-bordered';

      if LCssClass <> '' then
        LClassAttr := ' class="' + LCssClass + '"'
      else
        LClassAttr := '';
      Result := '<div id="' + GetHtmlId + '"' + LClassAttr + LStyleAttr + '>' +
        LContentHtml + '</div>';
    end;
  end;
end;

end.
