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
///  KittoX flex panel and dashboard controllers.
///  FlexPanel renders child views in a CSS Flexbox container (rows/columns
///  with wrap). Dashboard extends FlexPanel with a header and optional
///  auto-refresh via HTMX polling.
/// </summary>
unit Kitto.Html.FlexPanel;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Html.Base,
  Kitto.Html.Panel,
  Kitto.Html.Controller;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  /// <summary>
  ///  Configuration for a single flex item inside a FlexPanel/Dashboard.
  ///  YAML path: Items/View
  /// </summary>
  TKXFlexItemConfig = class(TEFNode)
  private
    function GetView: string;
    function GetFlex: Integer;
    function GetMinWidth: Integer;
    function GetMaxWidth: Integer;
    function GetItemHeight: Integer;
  public
    [YamlRequiredNode('View', 'View name or inline view definition')]
    property View: string read GetView;
    [YamlNode('Flex', '1', 'CSS flex grow factor')]
    property Flex: Integer read GetFlex;
    [YamlNode('MinWidth', 'Minimum width in pixels')]
    property MinWidth: Integer read GetMinWidth;
    [YamlNode('MaxWidth', 'Maximum width in pixels')]
    property MaxWidth: Integer read GetMaxWidth;
    [YamlNode('Height', 'Fixed height in pixels')]
    property ItemHeight: Integer read GetItemHeight;
  end;

  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  /// <summary>
  ///  Renders child views in a CSS Flexbox container.
  ///  Config properties: Direction, Wrap, Gap, JustifyContent, AlignItems.
  ///  Each child Item can specify Flex, MinWidth, MaxWidth, Height.
  /// </summary>
  TKXFlexPanelController = class(TKXPanelControllerBase, IKXController)
  strict private
    FDirection: string;
    FWrap: Boolean;
    FGap: Integer;
    FMaxColumns: Integer;
    FJustifyContent: string;
    FAlignItems: string;
    function GetItems: TEFNode;
  strict protected
    function GetPanelCssClass: string; override;
    procedure DoDisplay; override;
    function RenderContent: string; override;
    function RenderItems: string; virtual;
  public
    [YamlNode('Direction', 'Row', 'Flex direction: Row, Column, RowReverse, ColumnReverse')]
    property Direction: string read FDirection write FDirection;
    [YamlNode('Wrap', 'True', 'Enable flex wrapping')]
    property Wrap: Boolean read FWrap write FWrap;
    [YamlNode('Gap', 'Flex gap in pixels')]
    property Gap: Integer read FGap write FGap;
    [YamlNode('MaxColumns', 'Maximum items per row (0 = no limit, items wrap by MinWidth only)')]
    property MaxColumns: Integer read FMaxColumns write FMaxColumns;
    [YamlNode('JustifyContent', 'flex-start', 'CSS justify-content value')]
    property JustifyContent: string read FJustifyContent write FJustifyContent;
    [YamlNode('AlignItems', 'stretch', 'CSS align-items value')]
    property AlignItems: string read FAlignItems write FAlignItems;
    [YamlContainer('Items', TKXFlexItemConfig, 'Child views displayed in the flex container')]
    property Items: TEFNode read GetItems;
  end;

implementation

uses
  System.SysUtils,
  System.NetEncoding,
  EF.Localization,
  Kitto.Metadata.Views,
  Kitto.Config,
  Kitto.Metadata.DataView,
  Kitto.AccessControl;

{ TKXFlexItemConfig }

function TKXFlexItemConfig.GetView: string;
begin
  Result := AsString;
end;

function TKXFlexItemConfig.GetFlex: Integer;
begin
  Result := GetInteger('Flex', 1);
end;

function TKXFlexItemConfig.GetMinWidth: Integer;
begin
  Result := GetInteger('MinWidth', 0);
end;

function TKXFlexItemConfig.GetMaxWidth: Integer;
begin
  Result := GetInteger('MaxWidth', 0);
end;

function TKXFlexItemConfig.GetItemHeight: Integer;
begin
  Result := GetInteger('Height', 0);
end;

{ TKXFlexPanelController }

function TKXFlexPanelController.GetItems: TEFNode;
begin
  Result := Config.FindNode('Items');
end;

procedure TKXFlexPanelController.DoDisplay;
begin
  inherited;
  FDirection := Config.GetString('Direction', 'Row');
  FWrap := Config.GetBoolean('Wrap', True);
  FGap := Config.GetInteger('Gap', 0);
  FMaxColumns := Config.GetInteger('MaxColumns', 0);
  FJustifyContent := Config.GetString('JustifyContent', 'flex-start');
  FAlignItems := Config.GetString('AlignItems', 'stretch');
end;

function TKXFlexPanelController.GetPanelCssClass: string;
begin
  Result := 'kx-flex-panel';
end;

function TKXFlexPanelController.RenderContent: string;
var
  LFlexDirection: string;
  LFlexWrap: string;
  LGapStyle: string;
  LStyle: string;
begin
  // Map Direction config to CSS flex-direction
  if SameText(FDirection, 'Column') then
    LFlexDirection := 'column'
  else if SameText(FDirection, 'RowReverse') then
    LFlexDirection := 'row-reverse'
  else if SameText(FDirection, 'ColumnReverse') then
    LFlexDirection := 'column-reverse'
  else
    LFlexDirection := 'row';

  if FWrap then
    LFlexWrap := 'wrap'
  else
    LFlexWrap := 'nowrap';

  LGapStyle := '';
  if FGap > 0 then
    LGapStyle := Format(' gap:%dpx;', [FGap]);

  LStyle := Format('display:flex; flex-direction:%s; flex-wrap:%s;%s justify-content:%s; align-items:%s;',
    [LFlexDirection, LFlexWrap, LGapStyle, FJustifyContent, FAlignItems]);

  Result := Format(
    '<div class="kx-flex-container" style="%s">' +
    '%s' +
    '</div>',
    [LStyle, RenderItems]);
end;

function TKXFlexPanelController.RenderItems: string;
var
  LItems: TEFNode;
  I: Integer;
  LChild: TEFNode;
  LView: TKView;
  LViewName: string;
  LFlex: Integer;
  LMinWidth: Integer;
  LMaxWidth: Integer;
  LItemHeight: Integer;
  LItemStyle: string;
  LController: IKXController;
  LControllerNode, LCenterNode: TEFNode;
  LItemHtml: string;
  LTitle, LTitleHtml: string;
  LFooter, LFooterHtml: string;
begin
  Result := '';
  LItems := Config.FindNode('Items');
  if not Assigned(LItems) then
    Exit;

  for I := 0 to LItems.ChildCount - 1 do
  begin
    LChild := LItems.Children[I];
    if not SameText(LChild.Name, 'View') then
      Continue;

    LView := TKConfig.Instance.Views.ViewByNode(LChild);
    if not LView.IsAccessGranted(ACM_VIEW) then
      Continue;

    // Resolve view name (same pattern as TabPanel)
    LViewName := LView.PersistentName;
    if (LViewName = '') and (LView is TKDataView)
      and Assigned(TKDataView(LView).MainTable) then
    begin
      LViewName := TKDataView(LView).MainTable.ModelName;
      LView.PersistentName := LViewName;
      if TKConfig.Instance.Views.FindDynamicObject(LViewName) = nil then
        TKConfig.Instance.Views.AddDynamicObject(LView, LViewName);
    end;
    if LViewName = '' then
      LViewName := LView.ControllerType;
    if LViewName = '' then
      Continue;

    // Read item-level flex properties
    LFlex := LChild.GetInteger('Flex', 1);
    LMinWidth := LChild.GetInteger('MinWidth', 0);
    LMaxWidth := LChild.GetInteger('MaxWidth', 0);
    LItemHeight := LChild.GetInteger('Height', 0);

    // Build inline style for flex item
    // When MaxColumns is set, use flex-basis to ensure at most N items per row.
    // flex-grow still allows items to expand within their row.
    if FMaxColumns > 0 then
      LItemStyle := Format('flex:%d 1 calc((100%% - %dpx) / %d);',
        [LFlex, (FMaxColumns - 1) * FGap, FMaxColumns])
    else
      LItemStyle := Format('flex:%d;', [LFlex]);
    if LMinWidth > 0 then
      LItemStyle := LItemStyle + Format(' min-width:%dpx;', [LMinWidth]);
    if LMaxWidth > 0 then
      LItemStyle := LItemStyle + Format(' max-width:%dpx;', [LMaxWidth]);
    if LItemHeight > 0 then
      LItemStyle := LItemStyle + Format(' height:%dpx;', [LItemHeight]);

    // Render child view server-side (avoids concurrent HTMX requests
    // that can hit thread-safety issues in the macro expansion engine).
    LItemHtml := '';
    try
      // Check for CenterController interception (same logic as HandleKXViewRequest)
      LCenterNode := nil;
      LControllerNode := LView.FindNode('Controller');
      if Assigned(LControllerNode) then
      begin
        LCenterNode := LControllerNode.FindNode('CenterController');
        if Assigned(LCenterNode) and (LCenterNode.AsString = '') then
          LCenterNode := nil;
      end;

      if Assigned(LCenterNode) then
        LController := TKXControllerFactory.Instance.CreateController(LView, nil, LCenterNode)
      else
        LController := TKXControllerFactory.Instance.CreateController(LView);

      // Suppress dialog chrome and own header for embedded views
      // (the flex-item-title provides the title)
      if LController.AsObject is TKXPanelControllerBase then
      begin
        TKXPanelControllerBase(LController.AsObject).IsModal := False;
        TKXPanelControllerBase(LController.AsObject).AllowClose := False;
        TKXPanelControllerBase(LController.AsObject).Header := False;
      end;

      LController.Display;
      LItemHtml := LController.Render;
    except
      on E: Exception do
        LItemHtml := Format('<div class="kx-template-error">%s</div>',
          [TNetEncoding.HTML.Encode(E.Message)]);
    end;

    // Add a title bar from the view's DisplayLabel
    LTitle := LView.DisplayLabel;
    if LTitle <> '' then
      LTitleHtml := Format('<div class="kx-flex-item-title">%s</div>',
        [TNetEncoding.HTML.Encode(LTitle)])
    else
      LTitleHtml := '';

    // Optional footer from item config
    LFooter := LChild.GetString('Footer', '');
    if LFooter <> '' then
      LFooterHtml := Format('<div class="kx-flex-item-footer">%s</div>',
        [TNetEncoding.HTML.Encode(LFooter)])
    else
      LFooterHtml := '';

    Result := Result + Format(
      '<div class="kx-flex-item" style="%s">%s%s%s</div>',
      [LItemStyle, LTitleHtml, LItemHtml, LFooterHtml]);
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('FlexPanel', TKXFlexPanelController);

end.
