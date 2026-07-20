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
///  KittoX border layout controller. The main application layout that
///  arranges regions (North, West, Center, East, South) using CSS grid.
///  Supports Width, Header, Collapsible and DisplayLabel config properties.
/// </summary>
unit Kitto.Html.BorderPanel;

{$I Kitto.Defines.inc}

interface

uses
  System.Generics.Collections,
  EF.Classes,
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Html.Base,
  Kitto.Html.Controller,
  Kitto.Metadata.Views;

/// <summary>
///  Creates a region controller from Config nodes like {Region}View or
///  {Region}Controller. Standalone function usable by any controller.
/// </summary>
function CreateRegionController(AConfig: TEFComponentConfig; AView: TKView;
  const ARegionNodeName: string): IKXController;

/// <summary>
///  Creates the controller and renders the full region HTML including
///  width, header, collapsible support based on config properties.
///  Standalone function usable by any controller.
/// </summary>
function RenderNamedRegion(AConfig: TEFComponentConfig; AView: TKView;
  const ARegionName, ARegionClass: string;
  const AIsRequired: Boolean = False): string;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXBorderPanelController = class(TKXComponent, IKXController, IKXContainer)
  strict private
    FChildren: TList<IKXController>;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
    // IKXContainer
    /// <summary>Adds a child controller, placed in a region (North/South/West/East/Center).</summary>
    procedure AddController(const AController: IKXController);
    /// <summary>Renders the child controllers into their border regions.</summary>
    function RenderChildren: string;
    /// <summary>Renders the border-layout panel with its regions.</summary>
    function Render: string; override;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Rtti,
  EF.Intf,
  EF.Localization,
  Kitto.TemplatePro,
  Kitto.Config,
  Kitto.Html.TemplateEngine,
  Kitto.Html.Utils;

{ TKXBorderPanelController }

procedure TKXBorderPanelController.AfterConstruction;
begin
  inherited;
  FChildren := TList<IKXController>.Create;
end;

destructor TKXBorderPanelController.Destroy;
begin
  FreeAndNil(FChildren);
  inherited;
end;

procedure TKXBorderPanelController.AddController(const AController: IKXController);
begin
  FChildren.Add(AController);
end;

function TKXBorderPanelController.RenderChildren: string;
var
  LController: IKXController;
begin
  Result := '';
  for LController in FChildren do
    Result := Result + LController.Render;
end;

procedure PropagateRegionProperties(const ARegionNode: TEFNode;
  const AController: IKXController);
var
  I: Integer;
  LChild: TEFNode;
begin
  // Copy non-Controller properties from the region node to the controller's
  // Config so that properties like ImageName declared at the region level
  // are accessible to the controller.
  for I := 0 to ARegionNode.ChildCount - 1 do
  begin
    LChild := ARegionNode.Children[I];
    if not SameText(LChild.Name, 'Controller') then
      if not Assigned(AController.Config.FindChild(LChild.Name)) then
        AController.Config.FindChild(LChild.Name, True).Assign(LChild);
  end;
end;

function CreateRegionController(AConfig: TEFComponentConfig; AView: TKView;
  const ARegionNodeName: string): IKXController;
var
  LNode: TEFNode;
  LControllerNode: TEFNode;
  LViewName: string;
  LView: TKView;
begin
  Result := nil;

  // Try "{Region}View" node
  LNode := AConfig.FindNode(ARegionNodeName + 'View');
  if Assigned(LNode) then
  begin
    LViewName := LNode.AsExpandedString;
    if LViewName <> '' then
    begin
      // Named view reference (e.g. WestView: SomeViewName)
      LView := TKConfig.Instance.Views.FindView(LViewName);
      if Assigned(LView) then
      begin
        Result := TKXControllerFactory.Instance.CreateController(LView);
        Exit;
      end;
    end
    else
    begin
      // Inline view definition (e.g. WestView: \n Controller: BorderPanel)
      LControllerNode := LNode.FindNode('Controller');
      if Assigned(LControllerNode) then
      begin
        Result := TKXControllerFactory.Instance.CreateController(AView, nil, LControllerNode);
        PropagateRegionProperties(LNode, Result);
        Exit;
      end;
    end;
  end;

  // Try "{Region}Controller" node (inline controller, e.g. CenterController: TabPanel)
  LNode := AConfig.FindNode(ARegionNodeName + 'Controller');
  if Assigned(LNode) then
    Result := TKXControllerFactory.Instance.CreateController(AView, nil, LNode);
end;

/// <summary>
///  Removes a named child node from the controller's config if present,
///  so the region wrapper consumes properties that the inner panel should ignore.
/// </summary>
procedure ConsumeConfigNode(const AController: IKXController; const AName: string);
var
  LNode: TEFNode;
begin
  LNode := AController.Config.FindChild(AName);
  if Assigned(LNode) then
    AController.Config.RemoveChild(LNode);
end;

function RenderNamedRegion(AConfig: TEFComponentConfig; AView: TKView;
  const ARegionName, ARegionClass: string; const AIsRequired: Boolean): string;
var
  LController: IKXController;
  LRegionNode, LControllerNode: TEFNode;
  LDisplayLabel: string;
  LWidth, LHeight: Integer;
  LCollapsible, LHeader, LSplit: Boolean;
  LContent: string;
  LStyleStr: string;
  LChevronIcon: string;
  LIsSideRegion: Boolean;
  LCssClass: string;
  LSplitterHtml: string;
begin
  Result := '';
  LController := CreateRegionController(AConfig, AView, ARegionName);

  if not Assigned(LController) then
  begin
    if AIsRequired then
      Result := Format('<div class="%s"></div>', [ARegionClass]);
    Exit;
  end;

  // Extract region properties from config nodes.
  // DisplayLabel is on the {Region}View node itself;
  // Width/Collapsible/Header are on the Controller child node.
  LDisplayLabel := '';
  LWidth := 0;
  LHeight := 0;
  LCollapsible := False;
  LHeader := False;
  LSplit := False;

  LRegionNode := AConfig.FindNode(ARegionName + 'View');
  if Assigned(LRegionNode) then
  begin
    LDisplayLabel := _(LRegionNode.GetExpandedString('DisplayLabel', ''));
    LControllerNode := LRegionNode.FindNode('Controller');
    if Assigned(LControllerNode) then
    begin
      LWidth := LControllerNode.GetInteger('Width', 0);
      LHeight := LControllerNode.GetInteger('Height', 0);
      LCollapsible := LControllerNode.GetBoolean('Collapsible', False);
      LHeader := LControllerNode.GetBoolean('Header', False);
      LSplit := LControllerNode.GetBoolean('Split', False);
    end;
  end;

  if not Assigned(LRegionNode) then
  begin
    LRegionNode := AConfig.FindNode(ARegionName + 'Controller');
    if Assigned(LRegionNode) then
    begin
      LWidth := LRegionNode.GetInteger('Width', 0);
      LHeight := LRegionNode.GetInteger('Height', 0);
      LCollapsible := LRegionNode.GetBoolean('Collapsible', False);
      LHeader := LRegionNode.GetBoolean('Header', False);
      LSplit := LRegionNode.GetBoolean('Split', False);
    end;
  end;

  // Use controller's Title as DisplayLabel fallback
  if LDisplayLabel = '' then
    LDisplayLabel := _(LController.Config.GetExpandedString('Title', ''));

  // Consume region-level properties from the controller config so that
  // the inner panel (TKXPanelControllerBase) does not double-render them.
  if LCollapsible or LHeader then
  begin
    ConsumeConfigNode(LController, 'Collapsible');
    ConsumeConfigNode(LController, 'Collapsed');
    ConsumeConfigNode(LController, 'Header');
    ConsumeConfigNode(LController, 'Border');
    ConsumeConfigNode(LController, 'Title');
  end;
  ConsumeConfigNode(LController, 'Split');

  // Now Display + Render the inner controller (without consumed properties)
  LController.Display;
  LContent := LController.Render;

  LIsSideRegion := SameText(ARegionName, 'East') or SameText(ARegionName, 'West');

  // In CSS grid border layout, side regions (West/East) fill the full height
  // between North and South è only Width is meaningful. Top/bottom regions
  // (North/South) span the full width è only Height is meaningful.
  // This matches the original ExtJS border layout semantics.
  LStyleStr := '';
  if LIsSideRegion then
  begin
    if LWidth > 0 then
      LStyleStr := Format(' style="width: %dpx;"', [LWidth]);
  end
  else
  begin
    if LHeight > 0 then
      LStyleStr := Format(' style="height: %dpx;"', [LHeight]);
  end;

  // Build splitter element if Split is enabled.
  // Center region never gets a splitter (it fills remaining space by definition,
  // matching ExtJS border layout semantics).
  // West/North: splitter on the end edge (data-side="end")
  // East/South: splitter on the start edge (data-side="start")
  LSplitterHtml := '';
  if LSplit and not SameText(ARegionName, 'Center') then
  begin
    if LIsSideRegion then
      LSplitterHtml := Format(
        '<div class="kx-splitter kx-splitter-h" data-direction="horizontal" data-side="%s"></div>',
        [IfThen(SameText(ARegionName, 'West'), 'end', 'start')])
    else
      LSplitterHtml := Format(
        '<div class="kx-splitter kx-splitter-v" data-direction="vertical" data-side="%s"></div>',
        [IfThen(SameText(ARegionName, 'North'), 'end', 'start')]);
  end;

  if LCollapsible then
  begin
    // Collapsible region with header and rotating chevron icon.
    // Side regions (East/West) collapse horizontally; top/bottom vertically.
    if SameText(ARegionName, 'East') then
      LChevronIcon := 'chevron_right'
    else if SameText(ARegionName, 'West') then
      LChevronIcon := 'chevron_left'
    else
      LChevronIcon := 'expand_less';

    LCssClass := ARegionClass + ' kx-region-collapsible';
    if LIsSideRegion then
      LCssClass := LCssClass + ' kx-region-side';

    Result := Format(
      '<div class="%s"%s>' +
        '<div class="kx-region-header" ' +
          'onclick="this.parentElement.classList.toggle(''kx-region-collapsed'')">' +
          '<span class="kx-region-title">%s</span>' +
          '<span class="kx-region-toggle">' +
            GetIconHTML(LChevronIcon) + '</span>' +
        '</div>' +
        '<div class="kx-region-body">%s</div>' +
        '%s' +
      '</div>',
      [LCssClass, LStyleStr, LDisplayLabel, LContent, LSplitterHtml]);
  end
  else if LHeader and (LDisplayLabel <> '') then
  begin
    // Non-collapsible region with header.
    Result := Format(
      '<div class="%s"%s>' +
        '<div class="kx-region-header">' +
          '<span class="kx-region-title">%s</span>' +
        '</div>' +
        '<div class="kx-region-body">%s</div>' +
        '%s' +
      '</div>',
      [ARegionClass, LStyleStr, LDisplayLabel, LContent, LSplitterHtml]);
  end
  else
  begin
    // Simple region (no header).
    Result := Format('<div class="%s"%s>%s%s</div>',
      [ARegionClass, LStyleStr, LContent, LSplitterHtml]);
  end;
end;

function TKXBorderPanelController.Render: string;
var
  LTemplatePath: string;
  LHtmlId: string;
  LNorthHtml, LWestHtml, LCenterHtml, LEastHtml, LSouthHtml: string;
begin
  LHtmlId := GetHtmlId;

  // Render each region with full config support
  LNorthHtml := RenderNamedRegion(Config, View, 'North', 'kx-region-north');
  LWestHtml := RenderNamedRegion(Config, View, 'West', 'kx-region-west');
  LCenterHtml := RenderNamedRegion(Config, View, 'Center', 'kx-region-center', True);
  LEastHtml := RenderNamedRegion(Config, View, 'East', 'kx-region-east');
  LSouthHtml := RenderNamedRegion(Config, View, 'South', 'kx-region-south');

  LTemplatePath := TKXTemplateEngine.Instance.FindTemplatePath('', 'BorderPanel');
  if LTemplatePath <> '' then
  begin
    Result := TKXTemplateEngine.Instance.Render(LTemplatePath,
      procedure(ATemplate: ITProCompiledTemplate)
      begin
        ATemplate.SetData('htmlId', TValue.From<string>(LHtmlId));
        ATemplate.SetData('northContent', TValue.From<string>(LNorthHtml));
        ATemplate.SetData('westContent', TValue.From<string>(LWestHtml));
        ATemplate.SetData('centerContent', TValue.From<string>(LCenterHtml));
        ATemplate.SetData('eastContent', TValue.From<string>(LEastHtml));
        ATemplate.SetData('southContent', TValue.From<string>(LSouthHtml));
      end);
  end
  else
  begin
    Result := Format(
      '<div id="%s" class="kx-border-panel">' +
      '%s%s%s%s%s' +
      '</div>',
      [LHtmlId, LNorthHtml, LWestHtml, LCenterHtml, LEastHtml, LSouthHtml]);
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('BorderPanel', TKXBorderPanelController);

end.
