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
///  FOP (PDF generation via Apache FOP) tool controller for KittoX.
///  Replaces Kitto.Ext.FOPTools.
/// </summary>
unit Kitto.Tool.FOP;

interface

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Metadata.DataView,
  Kitto.Html.Files;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TFOPToolController = class(TKXDownloadFileController)
  strict private
    function GetTransformFileName: string;
  protected
    function GetDefaultFileName: string; override;
    procedure PrepareFile(const AFileName: string); override;
    function GetDefaultFileExtension: string; override;
  strict protected
    function GetRecordAsXML: string; virtual;
    function GetStoreAsXML: string; virtual;
  public
    /// <summary>Returns the default toolbar icon name for this tool.</summary>
    class function GetDefaultImageName: string; override;
  //published
    [YamlNode('TransformFileName', 'Path to the XSL-FO transform file')]
    property TransformFileName: string read GetTransformFileName;
  end;

implementation

uses
  System.Math,
  System.TypInfo,
  System.UIConsts,
  System.UITypes,
  EF.Classes,
  EF.StrUtils,
  EF.Localization,
  EF.DB,
  EF.Sys,
  EF.Macros,
  EF.XML,
  EF.FOP,
  Kitto.Metadata.Models,
  Kitto.Config,
  Kitto.Web.Application,
  Kitto.Html.Controller;

{ TFOPToolController }

function TFOPToolController.GetRecordAsXML: string;
begin
  Result := XMLHeader + ServerRecord.GetAsXML(True);
end;

function TFOPToolController.GetStoreAsXML: string;
begin
  Result := XMLHeader + ServerStore.GetAsXML(True);
end;

function TFOPToolController.GetDefaultFileExtension: string;
begin
  Result := '.pdf';
end;

function TFOPToolController.GetDefaultFileName: string;
var
  LFileExtension: string;
begin
  LFileExtension := ExtractFileExt(ClientFileName);
  if LFileExtension = '' then
    LFileExtension := GetDefaultFileExtension;
  Result := GetTempFileName(LFileExtension);
  AddTempFilename(Result);
end;

class function TFOPToolController.GetDefaultImageName: string;
begin
  Result := 'pdf_document';
end;

function TFOPToolController.GetTransformFileName: string;
begin
  Result := Config.GetExpandedString('TransformFileName');
end;

procedure TFOPToolController.PrepareFile(const AFileName: string);
var
  LXSLFileName, LXMLFileName: string;
  LXMLContent, LXSLContent: string;
  LFileStream: TStringStream;
  LFOPReport: TEFFopReport;
begin
  Assert(TransformFileName <> '','FOP TransformFileName is mandatory');

  LXMLFileName := ChangeFileExt(AFileName, '.xml');

  //Build XML data file
  if Assigned(ServerRecord) then
    LXMLContent := GetRecordAsXML
  else if Assigned(ServerStore) then
    LXMLContent := GetStoreAsXML
  else
    LXMLContent := XMLHeader;

  LFileStream := TStringStream.Create(LXMLContent, TEncoding.UTF8);
  try
    //Save XML file
    LFileStream.SaveToFile(LXMLFileName);
    //Add to temporary files so it will cleaned up
    AddTempFilename(LXMLFileName);

    //Load XSL file and macro-substitute some elements
    LXSLFileName := TransformFileName;
    LFileStream.LoadFromFile(LXSLFileName);
    LXSLContent := LFileStream.DataString;

    //Expand macros contained into xsl file like:
    // %FILENAME_TO_URL(%APP_PATH%ReportTemplates/logo.jpg)%
    // or %DATE% or %TIME%
    TEFMacroExpansionEngine.Instance.Expand(LXSLContent);

    //Save XSL to a temporary file
    LFileStream.Position := 0;
    LFileStream.WriteString(LXSLContent);
    LXSLFileName := ChangeFileExt(AFileName, '.xsl');
    LFileStream.SaveToFile(LXSLFileName);
    //Add to temporary files so it will cleaned up
    AddTempFilename(LXSLFileName);
  finally
    LFileStream.Free;
  end;

  //Transform XSL + XML via FOP
  LFOPReport := TEFFopReport.Create(nil);
  try
    if SameText(GetFileExtension,'.rtf') then
      LFOPReport.FOPOutputType := otRtf
    else
      LFOPReport.FOPOutputType := otPdf;
    LFOPReport.FOPPath := TKWebApplication.Current.Config.Config.GetExpandedString('FOPEnginePath');
    LFOPReport.XSLReportFile := LXSLFileName;
    LFOPReport.XMLDataFile := LXMLFileName;
    LFOPReport.OutputFile := AFileName;
    //Run FOP engine
    LFOPReport.Build;
  finally
    LFOPReport.Free;
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('FOPTool', TFOPToolController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('FOPTool');

end.
