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
///  KittoX HtmlPanel controller: renders inline HTML or loads from file.
///  Inherits dialog overlay support from TKXPanelControllerBase.
/// </summary>
unit Kitto.Html.HtmlPanel;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.Panel,
  Kitto.Html.Controller,
  EF.YAML.Attributes;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXHtmlPanelController = class(TKXPanelControllerBase)
  strict private
    function GetHtml: string;
    function GetFileName: string;
  strict protected
    function GetPanelCssClass: string; override;
    function RenderContent: string; override;
  public
    [YamlNode('Html', 'Inline HTML content to display')]
    property Html: string read GetHtml;
    [YamlNode('FileName', 'Resource file name containing HTML to display')]
    property FileName: string read GetFileName;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  System.NetEncoding,
  EF.Localization,
  EF.Macros,
  Kitto.Web.Application;

{ TKXHtmlPanelController }

function TKXHtmlPanelController.GetHtml: string;
begin
  Result := Config.GetExpandedString('Html', '');
end;

function TKXHtmlPanelController.GetFileName: string;
begin
  Result := Config.GetExpandedString('FileName', '');
end;

function TKXHtmlPanelController.GetPanelCssClass: string;
begin
  Result := 'kx-html-panel';
end;

function TKXHtmlPanelController.RenderContent: string;
var
  LFileName: string;
  LFullFileName: string;
  LFileContent: string;
  LResourceURL: string;
begin
  // Load content from FileName or Html config
  LFileName := Config.GetExpandedString('FileName', '');
  if LFileName <> '' then
  begin
    LFullFileName := TKWebApplication.Current.FindResourcePathName(LFileName);
    if (LFullFileName <> '') and TFile.Exists(LFullFileName) then
    begin
      LFileContent := TFile.ReadAllText(LFullFileName, TEncoding.UTF8);
      // Complete HTML documents go in an iframe via src to isolate their CSS.
      // Using src instead of srcdoc avoids encoding issues with large documents.
      if ContainsText(Copy(LFileContent, 1, 200), '<html') or
         ContainsText(Copy(LFileContent, 1, 200), '<!DOCTYPE') then
      begin
        LResourceURL := TKWebApplication.Current.FindResourceURL(LFileName);
        Result := '<iframe src="' + LResourceURL +
          '" style="display:block; width:100%; height:100%; border:none;"></iframe>';
      end
      else
      begin
        // HTML fragment: expand macros and inject directly
        TEFMacroExpansionEngine.Instance.Expand(LFileContent);
        Result := LFileContent;
      end;
    end
    else
      Result := 'File not found: ' + TNetEncoding.HTML.Encode(LFileName);
  end
  else
  begin
    Result := Config.GetExpandedString('Html', '');
    if Result = '' then
      Result := Config.GetExpandedString('Html/Value', '');
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('HtmlPanel', TKXHtmlPanelController);

end.
