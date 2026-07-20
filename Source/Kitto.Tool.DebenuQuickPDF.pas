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
///  PDF merge tool controller using Debenu Quick PDF Library for KittoX.
///  Replaces Kitto.Ext.DebenuQuickPDFTools.
/// </summary>
unit Kitto.Tool.DebenuQuickPDF;

interface

uses
  System.SysUtils,
  System.Classes,
  System.UITypes,
  Data.DB,
  DebenuPDFLibraryLite1114_TLB,
  Kitto.DebenuQuickPDF,
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Html.Files,
  Kitto.Html.Tools,
  Kitto.Metadata.DataView;

type
  TPDFMergeProgressEvent = procedure (const FileName: string; NewStartPage, PageCount: Integer) of Object;
  TPDFAcceptFileEvent = procedure (const FileName: string; var Accept: boolean) of Object;

  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TMergePDFToolController = class(TKXDownloadFileController)
  strict private
    FMergePDFEngine: TKMergePDFEngine;
    function GetLayoutFileName: string;
    function GetBaseFileName: string;
  protected
    function GetDefaultFileName: string; override;
    procedure PrepareFile(const AFileName: string); override;
    function GetDefaultFileExtension: string; override;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
    /// <summary>Returns the default toolbar icon name for this tool.</summary>
    class function GetDefaultImageName: string; override;
    [YamlNode('LayoutFileName', 'Path to the PDF layout template file')]
    property LayoutFileName: string read GetLayoutFileName;
    [YamlNode('BaseFileName', 'Base file name pattern for PDF merge input files')]
    property BaseFileName: string read GetBaseFileName;
  end;

implementation

uses
  Winapi.Windows,
  System.Math,
  System.TypInfo,
  System.UIConsts,
  EF.Sys,
  EF.Classes,
  EF.StrUtils,
  EF.Localization,
  EF.DB,
  EF.Macros,
  Kitto.Metadata.Models,
  Kitto.Config,
  Kitto.Html.Controller;

{ TMergePDFToolController }

procedure TMergePDFToolController.AfterConstruction;
begin
  inherited;
  FMergePDFEngine := TKMergePDFEngine.Create(nil);
end;

destructor TMergePDFToolController.Destroy;
begin
  FreeAndNil(FMergePDFEngine);
  inherited;
end;

function TMergePDFToolController.GetBaseFileName: string;
begin
  Result := Config.GetExpandedString('BaseFileName');
  ServerRecord.ExpandExpression(Result);
end;

function TMergePDFToolController.GetDefaultFileExtension: string;
begin
  Result := '.pdf';
end;

function TMergePDFToolController.GetDefaultFileName: string;
var
  LFileExtension: string;
begin
  LFileExtension := ExtractFileExt(ClientFileName);
  if LFileExtension = '' then
    LFileExtension := GetDefaultFileExtension;
  Result := GetTempFileName(LFileExtension);
  AddTempFilename(Result);
end;

class function TMergePDFToolController.GetDefaultImageName: string;
begin
  Result := 'pdf_document';
end;

function TMergePDFToolController.GetLayoutFileName: string;
begin
  Result := Config.GetExpandedString('LayoutFileName');
end;

procedure TMergePDFToolController.PrepareFile(const AFileName: string);
var
  LRecord: TKViewTableRecord;
  LBaseFileName, LLayoutFileName: string;
begin
  LRecord := ServerRecord;
  Assert(Assigned(LRecord), '"MergePDFTool controller works only on single record');
  LBaseFileName := BaseFileName;
  LLayoutFileName := LayoutFileName;
  FMergePDFEngine.MergePDF(AFileName, LLayoutFileName, LBaseFileName, LRecord);
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('MergePDFTool', TMergePDFToolController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('MergePDFTool');

end.
