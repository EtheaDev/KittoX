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
///  KittoX tree menu controller. Renders a navigation tree from TKTreeView
///  using HTML5 details/summary elements and HTMX links.
/// </summary>
unit Kitto.Html.TreePanel;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.Base,
  Kitto.Html.Controller,
  Kitto.Metadata.Views,
  EF.YAML.Attributes;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXTreePanelController = class(TKXComponent, IKXController)
  strict private
    function RenderTreeNodes(const ANodes: IKTreeViewNodes; const AViews: TKViews): string;
    function GetTreeView: string;
  public
    function Render: string; override;
    [YamlNode('TreeView', 'MainMenu', 'Name of the TreeView to render as tree panel')]
    property TreeView: string read GetTreeView;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.Rtti,
  EF.Tree,
  EF.Localization,
  Kitto.TemplatePro,
  Kitto.Config,
  Kitto.Html.TemplateEngine,
  Kitto.Html.Utils,
  Kitto.AccessControl,
  Kitto.Metadata.DataView;

{ TKXTreePanelController }

function TKXTreePanelController.RenderTreeNodes(const ANodes: IKTreeViewNodes; const AViews: TKViews): string;
var
  I: Integer;
  LNode: TKTreeViewNode;
  LView: TKView;
  LViewName: string;
  LDisplayLabel: string;
  LTabLabel: string;
  LImageName: string;
  LChildNodes: IKTreeViewNodes;
  LChildContent: string;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    for I := 0 to ANodes.TreeViewNodeCount - 1 do
    begin
      LNode := ANodes.TreeViewNodes[I];
      // LTabLabel: always the view's own DisplayLabel chain (no node-level override).
      // Used as the tab caption to match Kitto1 behaviour where the panel controller
      // set its own title independently from the menu item label.
      LTabLabel := GetDisplayLabelFromNode(LNode, AViews);
      // LDisplayLabel: honours a node-level DisplayLabel override (shorter menu text).
      LDisplayLabel := _(LNode.GetString('DisplayLabel', LTabLabel));
      if LNode is TKTreeViewFolder then
      begin
        if Supports(LNode, IKTreeViewNodes, LChildNodes) then
        begin
          LChildContent := RenderTreeNodes(LChildNodes, AViews);
          if LChildContent <> '' then
          begin
            LImageName := LNode.GetString('ImageName', 'folder');
            SB.Append('<details class="kx-tree-folder"');
            if not TKTreeViewFolder(LNode).IsInitiallyCollapsed then
              SB.Append(' open');
            SB.Append('><summary class="kx-tree-folder-label">');
            SB.Append('<span class="kx-toggle-icon">');
            SB.Append(GetIconHTML('chevron_right'));
            SB.Append('</span>');
            SB.Append(GetIconHTML(LImageName));
            SB.Append(LDisplayLabel);
            SB.Append('</summary><div class="kx-tree-children">');
            SB.Append(LChildContent);
            SB.Append('</div></details>');
          end;
        end;
      end
      else
      begin
        LView := LNode.FindView(AViews);
        if Assigned(LView) then
        begin
          if LView.IsAccessGranted(ACM_VIEW) then
          begin
            LImageName := GetTreeViewNodeImageName(LNode, LView);
            if LImageName = '' then
              LImageName := LView.ImageName;
            LViewName := LView.PersistentName;
            if (LViewName = '') and (LView is TKDataView)
              and Assigned(TKDataView(LView).MainTable) then
            begin
              LViewName := TKDataView(LView).MainTable.ModelName;
              LView.PersistentName := LViewName;
              if AViews.FindDynamicObject(LViewName) = nil then
                AViews.AddDynamicObject(LView, LViewName);
            end;
            if LViewName = '' then
              LViewName := LView.ControllerType;

            // DataViews (non-modal, non-wizard): delegate to kxApp.openView
            // which decides desktop TabPanel vs mobile fullscreen.
            if (LView is TKDataView)
              and not LView.GetBoolean('Controller/IsModal')
              and not MatchText(LView.GetString('Controller'), ['Wizard']) then
            begin
              SB.Append('<a class="kx-tree-leaf" href="#" ');
              SB.Append('data-view="').Append(LViewName).Append('" ');
              SB.Append('data-label="').Append(LDisplayLabel).Append('" ');
              SB.Append('data-tab-label="').Append(LTabLabel).Append('" ');
              SB.Append('onclick="kxApp.openView(this); return false;">');
              SB.Append(GetIconHTML(LImageName));
              SB.Append(LDisplayLabel).Append('</a>');
            end
            else
            begin
              // Modal, Wizard, non-DataView: always append to body as overlay
              SB.Append('<a class="kx-tree-leaf" ');
              SB.Append('hx-get="kx/view/').Append(LViewName).Append('" ');
              SB.Append('hx-target="body" hx-swap="beforeend">');
              SB.Append(GetIconHTML(LImageName));
              SB.Append(LDisplayLabel).Append('</a>');
            end;
          end;
        end;
      end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXTreePanelController.GetTreeView: string;
begin
  Result := Config.GetExpandedString('TreeView', '');
  if Result = '' then
    Result := 'MainMenu';
end;

function TKXTreePanelController.Render: string;
var
  LTemplatePath: string;
  LHtmlId: string;
  LTitle: string;
  LTreeContent: string;
  LTreeViewName: string;
  LTreeView: TKView;
  LChildNodes: IKTreeViewNodes;
begin
  LHtmlId := GetHtmlId;
  LTitle := Config.GetExpandedString('Title', '');

  // Get the tree view reference from Config
  LTreeViewName := Config.GetExpandedString('TreeView', '');
  if LTreeViewName = '' then
    LTreeViewName := 'MainMenu';

  LTreeView := TKConfig.Instance.Views.FindView(LTreeViewName);

  LTreeContent := '';
  if Assigned(LTreeView) and Supports(LTreeView, IKTreeViewNodes, LChildNodes) then
    LTreeContent := RenderTreeNodes(LChildNodes, TKConfig.Instance.Views);

  LTemplatePath := TKXTemplateEngine.Instance.FindTemplatePath('', 'TreePanel');
  if LTemplatePath <> '' then
  begin
    Result := TKXTemplateEngine.Instance.Render(LTemplatePath,
      procedure(ATemplate: ITProCompiledTemplate)
      begin
        ATemplate.SetData('htmlId', TValue.From<string>(LHtmlId));
        ATemplate.SetData('title', TValue.From<string>(LTitle));
        ATemplate.SetData('treeContent', TValue.From<string>(LTreeContent));
      end);
  end
  else
  begin
    Result := Format(
      '<nav id="%s" class="kx-tree-panel">' +
      '<div class="kx-tree-panel-title">%s</div>' +
      '<div class="kx-tree-panel-body">%s</div>' +
      '</nav>',
      [LHtmlId, LTitle, LTreeContent]);
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('TreePanel', TKXTreePanelController);

end.
