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
///  KittoX tile panel controller. Renders a Metro-style tile grid from
///  TKTreeView with folder names as section titles and an integrated
///  tab system for opening data views.
/// </summary>
unit Kitto.Html.TilePanel;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  EF.YAML.Attributes,
  Kitto.Html.Base,
  Kitto.Html.Controller,
  Kitto.Metadata.Views;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXTilePanelController = class(TKXComponent, IKXController)
  strict private
    FTileWidth: string;
    FTileHeight: string;
    FShowImage: Boolean;
    FImagePosition: string;
    FBorderColor: string;
    FColorSet: array of string;
    FColorIndex: Integer;
    function GetTileWidth: string;
    function GetTileHeight: string;
    function GetShowImage: Boolean;
    function GetColorSet: string;
    function GetTreeView: string;
    function GetBorderVisible: Boolean;
    function GetBorderColor: string;
    function NextColor: string;
    procedure InitColorSet(const AColorSetName: string);
    procedure RenderSections(const ANodes: IKTreeViewNodes;
      const AViews: TKViews; const ASB: TStringBuilder);
    procedure RenderViewTile(const ANode: TKTreeViewNode;
      const AView: TKView; const AViews: TKViews;
      const ASB: TStringBuilder);
    function HasVisibleChildren(const ANodes: IKTreeViewNodes;
      const AViews: TKViews): Boolean;
    class function EnsurePxSuffix(const AValue: string): string; static;
  public
    /// <summary>Renders the Metro-style colored tile menu from the referenced TreeView.</summary>
    function Render: string; override;

    [YamlNode('TileWidth', '100', 'Tile width in pixels or CSS units')]
    property TileWidth: string read GetTileWidth;
    [YamlNode('TileHeight', '50', 'Tile height in pixels or CSS units')]
    property TileHeight: string read GetTileHeight;
    [YamlNode('ShowImage', 'True', 'Show icon images on tiles')]
    property ShowImage: Boolean read GetShowImage;
    [YamlNode('ColorSet', 'Color set name (Blue/Red/Gold/Violet/Green/Metro/Theme)')]
    property ColorSet: string read GetColorSet;
    [YamlNode('TreeView', 'MainMenu', 'Name of the tree view to render as tiles')]
    property TreeViewName: string read GetTreeView;
    [YamlNode('Border', 'True', 'Show border around tiles')]
    property BorderVisible: Boolean read GetBorderVisible;
    [YamlNode('BorderColor', '', 'Border color for individual tiles (e.g. #e18325)')]
    property BorderColor: string read GetBorderColor;
  end;

implementation

uses
  System.Classes,
  System.StrUtils,
  EF.Tree,
  EF.Localization,
  Kitto.Config,
  Kitto.Html.Utils,
  Kitto.AccessControl,
  Kitto.Metadata.DataView;

{ TKXTilePanelController - YAML property getters }

function TKXTilePanelController.GetTileWidth: string;
begin
  Result := Config.GetString('TileWidth', '100');
end;

function TKXTilePanelController.GetTileHeight: string;
begin
  Result := Config.GetString('TileHeight', '50');
end;

function TKXTilePanelController.GetShowImage: Boolean;
begin
  Result := Config.GetBoolean('ShowImage', False);
end;

function TKXTilePanelController.GetColorSet: string;
begin
  Result := Config.GetString('ColorSet', '');
end;

function TKXTilePanelController.GetTreeView: string;
begin
  Result := Config.GetExpandedString('TreeView', 'MainMenu');
end;

function TKXTilePanelController.GetBorderVisible: Boolean;
begin
  Result := Config.GetBoolean('Border', False);
end;

function TKXTilePanelController.GetBorderColor: string;
begin
  Result := Config.GetString('BorderColor', '');
end;

const
  DEFAULT_TILE_WIDTH = '100';
  DEFAULT_TILE_HEIGHT = '50';

  COLOR_METRO: array[0..9] of string = (
    '#00904A', '#FF0097', '#00ABA9', '#8CBF26', '#A05000',
    '#E671B8', '#F09609', '#1BA1E2', '#E51400', '#339933');
  COLOR_BLUE: array[0..4] of string = (
    '#1240AB', '#365BB0', '#5777C0', '#0D3184', '#082568');
  COLOR_RED: array[0..4] of string = (
    '#FF0000', '#FF3939', '#FF6363', '#C50000', '#9B0000');
  COLOR_GOLD: array[0..4] of string = (
    '#FFD300', '#FFDD39', '#FFE463', '#C5A300', '#9B8000');
  COLOR_VIOLET: array[0..4] of string = (
    '#3914AF', '#5538B4', '#735AC3', '#2B0E88', '#20096A');
  COLOR_GREEN: array[0..4] of string = (
    '#97C93C', '#93DB70', '#00CD00', '#008000', '#003300');
  // Theme-aware fallback: uses KittoX CSS custom properties so tiles
  // automatically adapt to the configured theme colors.
  COLOR_THEME: array[0..4] of string = (
    'var(--kx-chrome-dark)', 'var(--kx-chrome)', 'var(--kx-accent)',
    'var(--kx-chrome-hover)', 'var(--kx-chrome-light)');

{ TKXTilePanelController }

procedure TKXTilePanelController.InitColorSet(const AColorSetName: string);
var
  I: Integer;
  LName: string;
begin
  LName := UpperCase(AColorSetName);
  if LName = 'BLUE' then
  begin
    SetLength(FColorSet, Length(COLOR_BLUE));
    for I := 0 to High(COLOR_BLUE) do
      FColorSet[I] := COLOR_BLUE[I];
  end
  else if LName = 'RED' then
  begin
    SetLength(FColorSet, Length(COLOR_RED));
    for I := 0 to High(COLOR_RED) do
      FColorSet[I] := COLOR_RED[I];
  end
  else if LName = 'GOLD' then
  begin
    SetLength(FColorSet, Length(COLOR_GOLD));
    for I := 0 to High(COLOR_GOLD) do
      FColorSet[I] := COLOR_GOLD[I];
  end
  else if LName = 'VIOLET' then
  begin
    SetLength(FColorSet, Length(COLOR_VIOLET));
    for I := 0 to High(COLOR_VIOLET) do
      FColorSet[I] := COLOR_VIOLET[I];
  end
  else if LName = 'GREEN' then
  begin
    SetLength(FColorSet, Length(COLOR_GREEN));
    for I := 0 to High(COLOR_GREEN) do
      FColorSet[I] := COLOR_GREEN[I];
  end
  else if LName = 'METRO' then
  begin
    SetLength(FColorSet, Length(COLOR_METRO));
    for I := 0 to High(COLOR_METRO) do
      FColorSet[I] := COLOR_METRO[I];
  end
  else
  begin
    // Unknown color set: fallback to theme colors (CSS variables)
    SetLength(FColorSet, Length(COLOR_THEME));
    for I := 0 to High(COLOR_THEME) do
      FColorSet[I] := COLOR_THEME[I];
  end;
  FColorIndex := 0;
end;

function TKXTilePanelController.NextColor: string;
begin
  Result := FColorSet[FColorIndex mod Length(FColorSet)];
  Inc(FColorIndex);
end;

class function TKXTilePanelController.EnsurePxSuffix(const AValue: string): string;
begin
  Result := AValue;
  if (Result <> '') and CharInSet(Result[Length(Result)], ['0'..'9']) then
    Result := Result + 'px';
end;

function TKXTilePanelController.HasVisibleChildren(const ANodes: IKTreeViewNodes;
  const AViews: TKViews): Boolean;
var
  I: Integer;
  LNode: TKTreeViewNode;
  LView: TKView;
  LChildNodes: IKTreeViewNodes;
begin
  Result := False;
  for I := 0 to ANodes.TreeViewNodeCount - 1 do
  begin
    LNode := ANodes.TreeViewNodes[I];
    if LNode is TKTreeViewFolder then
    begin
      if Supports(LNode, IKTreeViewNodes, LChildNodes) then
        if HasVisibleChildren(LChildNodes, AViews) then
          Exit(True);
    end
    else
    begin
      LView := LNode.FindView(AViews);
      if Assigned(LView) and LView.IsAccessGranted(ACM_VIEW) then
        Exit(True);
    end;
  end;
end;

procedure TKXTilePanelController.RenderViewTile(const ANode: TKTreeViewNode;
  const AView: TKView; const AViews: TKViews;
  const ASB: TStringBuilder);
var
  LViewName: string;
  LDisplayLabel: string;
  LTabLabel: string;
  LImageName: string;
  LTileColor: string;
  LTileWidth: string;
  LTileHeight: string;
  LStyle: string;
  LCssClass: string;
  LHideLabel: Boolean;
  LShowImage: Boolean;
  LImagePosition: string;
begin
  LTabLabel := GetDisplayLabelFromNode(ANode, AViews);
  LDisplayLabel := _(ANode.GetString('DisplayLabel', LTabLabel));
  LViewName := AView.PersistentName;
  if (LViewName = '') and (AView is TKDataView)
    and Assigned(TKDataView(AView).MainTable) then
  begin
    LViewName := TKDataView(AView).MainTable.ModelName;
    AView.PersistentName := LViewName;
    if AViews.FindDynamicObject(LViewName) = nil then
      AViews.AddDynamicObject(AView, LViewName);
  end;
  if LViewName = '' then
    LViewName := AView.ControllerType;

  // Always advance the color counter (like Kitto1), then allow per-tile override
  LTileColor := NextColor;
  LTileColor := ANode.GetString('BackgroundColor', LTileColor);

  // Per-tile size overrides (string values, px suffix added if needed)
  LTileWidth := EnsurePxSuffix(ANode.GetString('Width', FTileWidth));
  LTileHeight := EnsurePxSuffix(ANode.GetString('Height', FTileHeight));

  // Per-tile extra inline style and CSS class
  LStyle := ANode.GetString('Style', '');
  LCssClass := ANode.GetString('CSS', '');
  LHideLabel := ANode.GetBoolean('HideLabel', False);

  // Image: check for explicit ImageName on the node first (like Kitto1).
  // Only resolve view/controller default when ShowImage is enabled.
  LImageName := ANode.GetString('ImageName', '');
  LShowImage := FShowImage or (LImageName <> '');
  LImagePosition := ANode.GetString('ImagePosition', FImagePosition);

  // Resolve view default image only if we're showing images
  if LShowImage and (LImageName = '') then
    LImageName := CallViewControllerStringMethod(AView, 'GetDefaultImageName', AView.ImageName);

  // ImagePosition: translate "center" to a CSS class for the tile
  if (LImagePosition <> '') and (Pos('center', LowerCase(LImagePosition)) > 0) then
  begin
    if LCssClass <> '' then
      LCssClass := LCssClass + ' kx-tile-icon-center'
    else
      LCssClass := 'kx-tile-icon-center';
  end;

  // Build tile div
  if LCssClass <> '' then
    ASB.Append('<div class="kx-tile ').Append(LCssClass).Append('"')
  else
    ASB.Append('<div class="kx-tile"');
  ASB.Append(' style="width:').Append(LTileWidth)
    .Append(';height:').Append(LTileHeight)
    .Append(';background-color:').Append(LTileColor).Append(';');
  if FBorderColor <> '' then
    ASB.Append('border:2px solid ').Append(FBorderColor).Append(';');
  if LStyle <> '' then
    ASB.Append(LStyle).Append(';');
  ASB.Append('"');

  // DataViews (non-modal, non-wizard): delegate to kxApp.openView
  // which decides desktop TabPanel vs mobile fullscreen.
  if (AView is TKDataView) and not AView.GetBoolean('Controller/IsModal')
    and not MatchText(AView.GetString('Controller'), ['Wizard']) then
  begin
    ASB.Append(' role="button" tabindex="0"')
      .Append(' data-view="').Append(LViewName)
      .Append('" data-label="').Append(LDisplayLabel)
      .Append('" data-tab-label="').Append(LTabLabel)
      .Append('" onclick="kxApp.openView(this)"');
  end
  else
  begin
    // Modal, Wizard, non-DataView: always append to body as overlay
    ASB.Append(' role="button" tabindex="0"')
      .Append(' hx-get="kx/view/').Append(LViewName)
      .Append('" hx-target="body" hx-swap="beforeend"');
  end;
  ASB.Append('>');

  // Icon
  if LShowImage and (LImageName <> '') then
    ASB.Append(GetIconHTML(LImageName, isLarge));

  // Label
  if not LHideLabel then
    ASB.Append('<span class="kx-tile-label">').Append(LDisplayLabel).Append('</span>');

  ASB.Append('</div>');
end;

procedure TKXTilePanelController.RenderSections(const ANodes: IKTreeViewNodes;
  const AViews: TKViews; const ASB: TStringBuilder);
var
  I: Integer;
  LNode: TKTreeViewNode;
  LView: TKView;
  LChildNodes: IKTreeViewNodes;
  LFolderLabel: string;
  LGridOpen: Boolean;
begin
  LGridOpen := False;
  for I := 0 to ANodes.TreeViewNodeCount - 1 do
  begin
    LNode := ANodes.TreeViewNodes[I];

    if LNode is TKTreeViewFolder then
    begin
      // Close any open grid from preceding root-level views
      if LGridOpen then
      begin
        ASB.Append('</div>');
        LGridOpen := False;
      end;

      if Supports(LNode, IKTreeViewNodes, LChildNodes) then
      begin
        if HasVisibleChildren(LChildNodes, AViews) then
        begin
          // Folder title (only if the folder has a display label)
          LFolderLabel := _(LNode.GetString('DisplayLabel',
            GetDisplayLabelFromNode(LNode, AViews)));
          if LFolderLabel <> '' then
            ASB.Append('<div class="kx-tile-section-title">').Append(LFolderLabel).Append('</div>');

          // Render folder children: recurse to handle nested folders
          RenderSections(LChildNodes, AViews, ASB);
        end;
      end;
    end
    else
    begin
      LView := LNode.FindView(AViews);
      if Assigned(LView) and LView.IsAccessGranted(ACM_VIEW) then
      begin
        // Open a grid row if not already open
        if not LGridOpen then
        begin
          ASB.Append('<div class="kx-tile-row">');
          LGridOpen := True;
        end;
        RenderViewTile(LNode, LView, AViews, ASB);
      end;
    end;
  end;

  // Close any trailing open grid
  if LGridOpen then
    ASB.Append('</div>');
end;

function TKXTilePanelController.Render: string;
var
  LHtmlId: string;
  LTitle: string;
  LTreeViewName: string;
  LTreeView: TKView;
  LChildNodes: IKTreeViewNodes;
  LBorder: Boolean;
  LBorderClass: string;
  SB: TStringBuilder;
begin
  LHtmlId := GetHtmlId;
  LTitle := Config.GetExpandedString('Title', '');
  FTileWidth := Config.GetString('TileWidth', DEFAULT_TILE_WIDTH);
  FTileHeight := Config.GetString('TileHeight', DEFAULT_TILE_HEIGHT);
  FShowImage := Config.GetBoolean('ShowImage', False);
  FImagePosition := Config.GetString('ShowImage/Position', '');
  FBorderColor := Config.GetString('BorderColor', '');
  LBorder := Config.GetBoolean('Border', False);

  InitColorSet(Config.GetString('ColorSet', ''));

  LTreeViewName := Config.GetExpandedString('TreeView', '');
  if LTreeViewName = '' then
    LTreeViewName := 'MainMenu';

  LTreeView := TKConfig.Instance.Views.FindView(LTreeViewName);

  if LBorder then
    LBorderClass := ' kx-panel-bordered'
  else
    LBorderClass := '';

  SB := TStringBuilder.Create;
  try
    SB.Append('<div id="').Append(LHtmlId).Append('" class="kx-tile-panel').Append(LBorderClass).Append('">');

    // Title
    if LTitle <> '' then
      SB.Append('<div class="kx-tile-panel-title">').Append(LTitle).Append('</div>');

    // Tile box: desktop views open in the central TabPanel,
    // mobile views open as fullscreen overlays. No embedded tabs needed.
    SB.Append('<div class="kx-tile-box" id="kx-tile-pages">');

    if Assigned(LTreeView) and Supports(LTreeView, IKTreeViewNodes, LChildNodes) then
      RenderSections(LChildNodes, TKConfig.Instance.Views, SB);

    SB.Append('</div>');

    SB.Append('</div>');

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('TilePanel', TKXTilePanelController);

end.
