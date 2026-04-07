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
///  KittoX toolbar menu controller. Renders a TreeView as a horizontal
///  button bar, replacing Kitto.Ext.ToolBar (ExtJS toolbar with buttons).
/// </summary>
unit Kitto.Html.ToolBar;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.Base,
  Kitto.Html.Controller,
  Kitto.Metadata.Views,
  EF.YAML.Attributes;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXToolBarController = class(TKXComponent, IKXController)
  strict private
    function RenderToolBarItems(const ANodes: IKTreeViewNodes;
      const AViews: TKViews): string;
    function GetTreeView: string;
  public
    function Render: string; override;
    [YamlNode('TreeView', 'MainMenu', 'Name of the TreeView to render as toolbar')]
    property TreeView: string read GetTreeView;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  EF.Tree,
  EF.Localization,
  Kitto.Config,
  Kitto.Html.Utils,
  Kitto.AccessControl,
  Kitto.Metadata.DataView;

{ TKXToolBarController }

function TKXToolBarController.RenderToolBarItems(
  const ANodes: IKTreeViewNodes; const AViews: TKViews): string;
var
  I: Integer;
  LNode: TKTreeViewNode;
  LView: TKView;
  LViewName: string;
  LDisplayLabel: string;
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
      LDisplayLabel := _(LNode.GetString('DisplayLabel',
        GetDisplayLabelFromNode(LNode, AViews)));

      if LNode is TKTreeViewFolder then
      begin
        // Folder -> dropdown menu
        if Supports(LNode, IKTreeViewNodes, LChildNodes) then
        begin
          LChildContent := RenderToolBarItems(LChildNodes, AViews);
          if LChildContent <> '' then
          begin
            LImageName := LNode.GetString('ImageName', 'folder');
            SB.Append('<div class="kx-menubar-dropdown">');
            SB.Append('<button class="kx-menubar-btn">');
            SB.Append(GetIconHTML(LImageName));
            SB.Append(' <span>').Append(LDisplayLabel).Append('</span>');
            SB.Append(' <svg width="10" height="10" viewBox="0 0 10 10"><path d="M2 4l3 3 3-3" stroke="currentColor" stroke-width="1.5" fill="none"/></svg>');
            SB.Append('</button>');
            SB.Append('<div class="kx-menubar-dropdown-content">').Append(LChildContent).Append('</div>');
            SB.Append('</div>');
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

            if LView is TKDataView then
            begin
              SB.Append('<a class="kx-menubar-item" href="#" ');
              SB.Append('data-view="').Append(LViewName).Append('" ');
              SB.Append('data-label="').Append(LDisplayLabel).Append('" ');
              SB.Append('onclick="kxTabs.openFromMenu(this); return false;">');
              SB.Append(GetIconHTML(LImageName));
              SB.Append(' <span>').Append(LDisplayLabel).Append('</span></a>');
            end
            else
            begin
              SB.Append('<a class="kx-menubar-item" ');
              SB.Append('hx-get="kx/view/').Append(LViewName).Append('" ');
              SB.Append('hx-target="body" hx-swap="beforeend">');
              SB.Append(GetIconHTML(LImageName));
              SB.Append(' <span>').Append(LDisplayLabel).Append('</span></a>');
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

function TKXToolBarController.GetTreeView: string;
begin
  Result := Config.GetExpandedString('TreeView', '');
  if Result = '' then
    Result := 'MainMenu';
end;

function TKXToolBarController.Render: string;
var
  LHtmlId: string;
  LTreeViewName: string;
  LTreeView: TKView;
  LChildNodes: IKTreeViewNodes;
  LContent: string;
begin
  LHtmlId := GetHtmlId;

  LTreeViewName := Config.GetExpandedString('TreeView', '');
  if LTreeViewName = '' then
    LTreeViewName := 'MainMenu';

  LTreeView := TKConfig.Instance.Views.FindView(LTreeViewName);

  LContent := '';
  if Assigned(LTreeView) and Supports(LTreeView, IKTreeViewNodes, LChildNodes) then
    LContent := RenderToolBarItems(LChildNodes, TKConfig.Instance.Views);

  Result := Format(
    '<nav id="%s" class="kx-menubar">%s</nav>',
    [LHtmlId, LContent]);
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('ToolBar', TKXToolBarController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('ToolBar');

end.
