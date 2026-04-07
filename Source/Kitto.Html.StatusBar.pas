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
///  KittoX status bar controller. Renders a footer element with status text.
/// </summary>
unit Kitto.Html.StatusBar;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.Base,
  Kitto.Html.Controller,
  EF.YAML.Attributes;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXStatusBarController = class(TKXComponent, IKXController)
  strict private
    function GetText: string;
  public
    function Render: string; override;
    [YamlNode('Text', 'Ready', 'Status bar text')]
    property Text: string read GetText;
  end;

implementation

uses
  System.SysUtils,
  System.Rtti,
  Kitto.TemplatePro,
  Kitto.Html.TemplateEngine,
  Kitto.Html.Utils;

{ TKXStatusBarController }

function TKXStatusBarController.GetText: string;
begin
  Result := Config.GetExpandedString('Text', 'Ready');
end;

function TKXStatusBarController.Render: string;
var
  LTemplatePath: string;
  LText: string;
  LHtmlId: string;
  LImageName: string;
  LIconHtml: string;
begin
  LText := Config.GetExpandedString('Text', 'Ready');
  LImageName := Config.GetString('ImageName', '');
  if (LImageName = '') and Assigned(View) then
    LImageName := View.GetString('ImageName', '');
  LIconHtml := GetIconHTML(LImageName, isDefault, 'kx-status-icon');
  LHtmlId := GetHtmlId;

  LTemplatePath := TKXTemplateEngine.Instance.FindTemplatePath('', 'StatusBar');
  if LTemplatePath <> '' then
  begin
    Result := TKXTemplateEngine.Instance.Render(LTemplatePath,
      procedure(ATemplate: ITProCompiledTemplate)
      begin
        ATemplate.SetData('htmlId', TValue.From<string>(LHtmlId));
        ATemplate.SetData('text', TValue.From<string>(LText));
        ATemplate.SetData('iconHtml', TValue.From<string>(LIconHtml));
      end);
  end
  else
    Result := Format('<footer id="%s" class="kx-status-bar">%s<span class="kx-status-text">%s</span></footer>',
      [LHtmlId, LIconHtml, LText]);
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('StatusBar', TKXStatusBarController);

end.
