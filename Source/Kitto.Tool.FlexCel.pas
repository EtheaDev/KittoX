{-------------------------------------------------------------------------------
   Copyright 2019-2026 Ethea S.r.l.

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
///  FlexCel Excel export tool controller for KittoX.
///  Replaces Kitto.Ext.FlexCelTools.
/// </summary>
unit Kitto.Tool.FlexCel;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Data.Win.ADODB,
  Data.DB,
  Web.HTTPApp,
  EF.Tree,
  Kitto.FlexCel,
  Kitto.Metadata.DataView,
  Kitto.Html.Files;

type
  /// <summary>Download-file tool controller that exports the view table to Excel using FlexCel.</summary>
  TExportFlexCelToolController = class(TKXDownloadFileController)
  strict private
    FExportExcelEngine: TKFlexCelExportEngine;
    function GetExcelRangeName: string;
    function GetTemplateFileName: string;
    function GetUseDisplayLabels: boolean;
  strict protected
    function GetDefaultFileName: string; override;
    function GetDefaultFileExtension: string; override;
    procedure PrepareFile(const AFileName: string); override;
    procedure AcceptRecord(ARecord: TKViewTableRecord; var AAccept: boolean); virtual;
    procedure AcceptField(AViewField: TKViewField; var AAccept: boolean); virtual;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
    /// <summary>Returns the default toolbar icon name for this tool.</summary>
    class function GetDefaultImageName: string; override;
    /// <summary>The FlexCel engine that performs the Excel export.</summary>
    property ExportEngine: TKFlexCelExportEngine read FExportExcelEngine;
  //published
    /// <summary>Named range in the Excel workbook to fill.</summary>
    property ExcelRangeName: string read GetExcelRangeName;
    /// <summary>Path to the Excel template workbook, if any.</summary>
    property TemplateFileName: string read GetTemplateFileName;
    /// <summary>Use display labels instead of field names for column headers.</summary>
    property UseDisplayLabels: boolean read GetUseDisplayLabels;
  end;

/// <summary>Returns the default file-mask wildcards accepted for Excel files (e.g. *.xls;*.xlsx).</summary>
function DefaultExcelWildcards: string;

implementation

uses
  System.Math,
  EF.DB,
  EF.StrUtils,
  EF.Sys,
  Kitto.Metadata.Models,
  Kitto.Config,
  Kitto.Html.Controller;

function DefaultExcelWildcards: string;
begin
  Result := Format('*%s *%s', [EXCEL_NEW_FILE_EXT, EXCEL_FILE_EXT]);
end;

{ TExportFlexCelToolController }

procedure TExportFlexCelToolController.AfterConstruction;
begin
  inherited;
  FExportExcelEngine := TKFlexCelExportEngine.Create;
end;

destructor TExportFlexCelToolController.Destroy;
begin
  FreeAndNil(FExportExcelEngine);
  inherited;
end;

function TExportFlexCelToolController.GetDefaultFileExtension: string;
begin
  Result := EXCEL_NEW_FILE_EXT;
end;

class function TExportFlexCelToolController.GetDefaultImageName: string;
begin
  Result := 'excel_document';
end;

function TExportFlexCelToolController.GetExcelRangeName: string;
begin
  Result := Config.GetString('ExcelRangeName', EXCEL_DEFAULT_RANGE);
end;

function TExportFlexCelToolController.GetTemplateFileName: string;
begin
  Result := Config.GetExpandedString('TemplateFileName');
end;

function TExportFlexCelToolController.GetUseDisplayLabels: Boolean;
begin
  Result := Config.GetBoolean('UseDisplayLabels');
end;

procedure TExportFlexCelToolController.AcceptRecord(ARecord: TKViewTableRecord; var AAccept: boolean);
begin
  // Accept all records in the store; the store is already filtered at load time.
end;

procedure TExportFlexCelToolController.AcceptField(AViewField: TKViewField; var AAccept: boolean);
begin
  AAccept := AViewField.IsVisible;
end;

procedure TExportFlexCelToolController.PrepareFile(const AFileName: string);
var
  LStore: TKViewTableStore;
begin
  inherited;
  LStore := ServerStore;
  //if not using a template file we must built the structure of a new excel file using FlexCel
  if (TemplateFileName = '') then
  begin
    FExportExcelEngine.CreateFileByTable(AFileName, LStore, ExcelRangeName,
      AcceptRecord, AcceptField, UseDisplayLabels);
  end
  else
  begin
    FExportExcelEngine.CreateFileByTableWithTemplate(AFileName, TemplateFileName,
      ExcelRangeName, LStore, AcceptRecord, AcceptField, UseDisplayLabels);
  end;
end;

function TExportFlexCelToolController.GetDefaultFileName: string;
var
  LFileExtension: string;
begin
  LFileExtension := ExtractFileExt(ClientFileName);
  if LFileExtension = '' then
    LFileExtension := GetDefaultFileExtension;
  Result := GetTempFileName(LFileExtension);
  AddTempFilename(Result);
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('ExportFlexCelTool', TExportFlexCelToolController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('ExportFlexCelTool');

end.
