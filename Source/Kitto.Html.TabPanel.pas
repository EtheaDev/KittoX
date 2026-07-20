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
///  KittoX tab panel controller. Renders a dynamic tab container with
///  vanilla JS state management (kxTabs module) and HTMX for lazy loading.
///  SubViews are rendered as closable tabs; menu clicks create/activate tabs.
///  The kxTabs JS module is loaded externally from Resources/js/kxtabs.js.
/// </summary>
unit Kitto.Html.TabPanel;

{$I Kitto.Defines.inc}

interface

uses
  System.Generics.Collections,
  EF.YAML.Attributes,
  Kitto.Html.Base,
  Kitto.Html.Controller,
  Kitto.Metadata.Views;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXTabPanelController = class(TKXComponent, IKXController, IKXContainer)
  strict private
    FChildren: TList<IKXController>;
    function GetTabIconsVisible: Boolean;
    function GetTabsVisible: Boolean;
    procedure BuildTabContent(const ATabIconsVisible: Boolean;
      out ATabHeaders, ATabBodies: string);
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
    // IKXContainer
    /// <summary>Adds a child controller, rendered as a tab.</summary>
    procedure AddController(const AController: IKXController);
    /// <summary>Renders the child controllers as the tab bodies.</summary>
    function RenderChildren: string;
    /// <summary>Renders the tab panel (tab headers + bodies).</summary>
    function Render: string; override;

    [YamlNode('TabIconsVisible', 'False', 'Show icons on tab buttons')]
    property TabIconsVisible: Boolean read GetTabIconsVisible;
    [YamlNode('TabsVisible', 'False', 'Show tab bar (False renders only the first tab)')]
    property TabsVisible: Boolean read GetTabsVisible;
  end;

implementation

uses
  System.SysUtils,
  System.Rtti,
  EF.Tree,
  Kitto.TemplatePro,
  Kitto.Config,
  Kitto.Metadata.DataView,
  Kitto.Html.TemplateEngine,
  Kitto.Html.Utils,
  Kitto.AccessControl;

{ TKXTabPanelController }

function TKXTabPanelController.GetTabIconsVisible: Boolean;
begin
  Result := Config.GetBoolean('TabIconsVisible', True);
end;

function TKXTabPanelController.GetTabsVisible: Boolean;
begin
  Result := Config.GetBoolean('TabsVisible', True);
end;

procedure TKXTabPanelController.AfterConstruction;
begin
  inherited;
  FChildren := TList<IKXController>.Create;
end;

destructor TKXTabPanelController.Destroy;
begin
  FreeAndNil(FChildren);
  inherited;
end;

procedure TKXTabPanelController.AddController(const AController: IKXController);
begin
  FChildren.Add(AController);
end;

function TKXTabPanelController.RenderChildren: string;
var
  LController: IKXController;
begin
  Result := '';
  for LController in FChildren do
    Result := Result + LController.Render;
end;

procedure TKXTabPanelController.BuildTabContent(const ATabIconsVisible: Boolean;
  out ATabHeaders, ATabBodies: string);
var
  I: Integer;
  LChildController: IKXController;
  LLabel: string;
  LViewName: string;
  LIconName: string;
  LIconHtml: string;
  LIsFirst: Boolean;
  LActiveClass: string;
begin
  ATabHeaders := '';
  ATabBodies := '';
  LIsFirst := True;
  for I := 0 to FChildren.Count - 1 do
  begin
    LChildController := FChildren[I];

    // Determine view name: PersistentName > ControllerType > tab-N
    if Assigned(LChildController.View) then
    begin
      LViewName := LChildController.View.PersistentName;
      if LViewName = '' then
        LViewName := LChildController.View.ControllerType;
    end
    else
      LViewName := '';
    if LViewName = '' then
      LViewName := Format('tab-%d', [I]);

    // Determine display label
    if Assigned(LChildController.View) then
      LLabel := LChildController.View.DisplayLabel
    else
      LLabel := '';
    if LLabel = '' then
      LLabel := Format('Tab %d', [I + 1]);

    // Build icon HTML (View.ImageName follows the full resolution chain:
    // explicit YAML ImageName ? MainTable.ImageName ? Model.ImageName)
    LIconHtml := '';
    if ATabIconsVisible and Assigned(LChildController.View) then
    begin
      LIconName := LChildController.View.ImageName;
      if LIconName <> '' then
        LIconHtml := GetIconHTML(LIconName, isDefault, 'kx-tab-icon');
    end;

    // Active state
    if LIsFirst then
      LActiveClass := ' kx-tab-active'
    else
      LActiveClass := '';

    // Tab button with close control
    ATabHeaders := ATabHeaders +
      '<button class="kx-tab-button' + LActiveClass + '"' +
      ' data-view="' + LViewName + '"' +
      ' onclick="kxTabs.activate(''' + LViewName + ''')">' +
      LIconHtml + LLabel +
      '<span class="kx-tab-close"' +
      ' onclick="event.stopPropagation(); kxTabs.close(''' + LViewName + ''')">' +
      GetIconHTML('close') + '</span></button>';

    // Tab pane
    if LIsFirst then
      ATabBodies := ATabBodies + Format(
        '<div class="kx-tab-pane" id="kx-tab-pane-%s">%s</div>',
        [LViewName, LChildController.Render])
    else
      ATabBodies := ATabBodies + Format(
        '<div class="kx-tab-pane" id="kx-tab-pane-%s" style="display:none">%s</div>',
        [LViewName, LChildController.Render]);

    LIsFirst := False;
  end;
end;

function TKXTabPanelController.Render: string;
var
  LTemplatePath: string;
  LHtmlId: string;
  LSubViews: TEFNode;
  I: Integer;
  LView: TKView;
  LViewName: string;
  LLabel: string;
  LIconName: string;
  LIconHtml: string;
  LTabHeaders: string;
  LTabBodies: string;
  LTabIconsVisible: Boolean;
  LTabsVisible: Boolean;
  LTabHeaderHtml: string;
  LIsFirst: Boolean;
  LActiveClass: string;
begin
  LHtmlId := GetHtmlId;
  LTabIconsVisible := Config.GetBoolean('TabIconsVisible', True);
  LTabsVisible := Config.GetBoolean('TabsVisible', True);

  LTabHeaders := '';
  LTabBodies := '';
  LIsFirst := True;

  // Build SubViews as lazy-loaded tabs (no controller creation, no DB queries).
  // Content is fetched via HTMX when the tab is displayed.
  LSubViews := Config.FindNode('SubViews');
  if Assigned(LSubViews) then
  begin
    for I := 0 to LSubViews.ChildCount - 1 do
    begin
      if not SameText(LSubViews.Children[I].Name, 'View') then
        Continue;

      LView := TKConfig.Instance.Views.ViewByNode(LSubViews.Children[I]);
      if not LView.IsAccessGranted(ACM_VIEW) then
        Continue;

      // Resolve view name (same logic as TreePanel for auto-built views)
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

      // Display label
      LLabel := LView.DisplayLabel;
      if LLabel = '' then
        LLabel := LViewName;

      // Icon (View.ImageName follows the full resolution chain:
      // explicit YAML ImageName ? MainTable.ImageName ? Model.ImageName)
      LIconHtml := '';
      if LTabIconsVisible then
      begin
        LIconName := LView.ImageName;
        if LIconName <> '' then
          LIconHtml := GetIconHTML(LIconName, isDefault, 'kx-tab-icon');
      end;

      // Active state
      if LIsFirst then
        LActiveClass := ' kx-tab-active'
      else
        LActiveClass := '';

      // Tab button
      LTabHeaders := LTabHeaders +
        '<button class="kx-tab-button' + LActiveClass + '"' +
        ' data-view="' + LViewName + '"' +
        ' onclick="kxTabs.activate(''' + LViewName + ''')">' +
        LIconHtml + LLabel +
        '<span class="kx-tab-close"' +
        ' onclick="event.stopPropagation(); kxTabs.close(''' + LViewName + ''')">' +
        GetIconHTML('close') + '</span></button>';

      // Tab pane è lazy loaded via HTMX (global overlay provides loading feedback)
      if LIsFirst then
        // First tab: visible, auto-load on page render
        LTabBodies := LTabBodies + Format(
          '<div class="kx-tab-pane" id="kx-tab-pane-%s" ' +
          'hx-get="kx/view/%s" hx-trigger="load" hx-swap="innerHTML">' +
          '</div>',
          [LViewName, LViewName])
      else
        // Other tabs: hidden, loaded on activation
        LTabBodies := LTabBodies + Format(
          '<div class="kx-tab-pane" id="kx-tab-pane-%s" style="display:none" data-kx-lazy>' +
          '</div>',
          [LViewName, LViewName]);

      LIsFirst := False;
    end;
  end;

  // Render explicitly-added children (added via AddController by parent containers)
  if FChildren.Count > 0 then
    BuildTabContent(LTabIconsVisible, LTabHeaders, LTabBodies);

  if LTabsVisible then
    LTabHeaderHtml :=
      '<div class="kx-tab-header" id="kx-tab-header-bar">' +
      '<button class="kx-tab-scroll-btn" id="kx-tab-scroll-left" onclick="kxTabs.scrollLeft()">&#9666;</button>' +
      '<div class="kx-tab-strip" id="kx-tab-strip">' + LTabHeaders + '</div>' +
      '<button class="kx-tab-scroll-btn" id="kx-tab-scroll-right" onclick="kxTabs.scrollRight()">&#9656;</button>' +
      '</div>'
  else
    LTabHeaderHtml := '';

  // Inject KX_CLOSE_ICON so kxTabs.open() uses the same icon as server-rendered tabs
  LTabBodies := LTabBodies +
    '<script>var KX_CLOSE_ICON = ''' +
    StringReplace(GetIconHTML('close'), '''', '\''', [rfReplaceAll]) +
    ''';</script>';

  LTemplatePath := TKXTemplateEngine.Instance.FindTemplatePath('', 'TabPanel');
  if LTemplatePath <> '' then
  begin
    Result := TKXTemplateEngine.Instance.Render(LTemplatePath,
      procedure(ATemplate: ITProCompiledTemplate)
      begin
        ATemplate.SetData('htmlId', TValue.From<string>(LHtmlId));
        ATemplate.SetData('tabHeaderHtml', TValue.From<string>(LTabHeaderHtml));
        ATemplate.SetData('tabBodies', TValue.From<string>(LTabBodies));
      end);
  end
  else
  begin
    Result := Format(
      '<div id="%s" class="kx-tab-panel">' +
      '%s' +
      '<div class="kx-tab-content" id="kx-center-tabs">%s</div>' +
      '</div>',
      [LHtmlId, LTabHeaderHtml, LTabBodies]);
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('TabPanel', TKXTabPanelController);

end.
