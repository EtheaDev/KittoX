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
///  Download and upload file controllers for KittoX HTML pipeline.
///  Replaces TKExtDownloadFileController and TKExtUploadFileController
///  from Kitto.Ext.Files.
/// </summary>
unit Kitto.Html.Files;

{$I Kitto.Defines.inc}

interface

uses
  System.Classes,
  EF.StrUtils,
  EF.YAML.Attributes,
  Web.HTTPApp,
  Kitto.Html.Tools;

type
  /// <summary>Downloads a file that exists on disk or (by inheriting from it)
  /// is prepared on demand as a file or stream.</summary>
  /// <remarks>
  ///   <para>This class can be used as-is to serve existing files, or
  ///   inherited to serve on-demand files and streams.</para>
  ///   <para>Params for the as-is version:</para>
  ///   <list type="table">
  ///     <listheader>
  ///       <term>Term</term>
  ///       <description>Description</description>
  ///     </listheader>
  ///     <item>
  ///       <term>FileName</term>
  ///       <description>Name of the file to serve (complete with full path).
  ///       May contain macros.</description>
  ///     </item>
  ///     <item>
  ///       <term>ClientFileName</term>
  ///       <description>File name as passed to the client; if not specified,
  ///       the name portion of FileName is used.</description>
  ///     </item>
  ///     <item>
  ///       <term>ContentType</term>
  ///       <description>Content type passed to the client; if not specified,
  ///       it is derived from the file name's extension.</description>
  ///     </item>
  ///     <item>
  ///       <term>PersistentFileName</term>
  ///       <description>Name of the file optionally persisted on the server
  ///        before download. No files are left on the server if this parameter
  ///        is not specified.</description>
  ///     </item>
  ///   </list>
  /// </remarks>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXDownloadFileController = class(TKXDataToolController)
  strict private
    FTempFileNames: TStrings;
    FFileName: string;
    FStream: TStream;
    function GetContentType: string;
    function GetFileName: string;
    procedure DoDownloadStream(const AStream: TStream;
      const AFileName: string; const AContentType: string);
    procedure PersistFile(const AStream: TStream);
  strict protected
    function GetClientFileName: string; virtual;
    function GetPersistentFileName: string; virtual;
    procedure ExecuteTool; override;
    function GetFileExtension: string; virtual;
    function GetDefaultFileExtension: string; virtual;
    procedure AddTempFilename(const AFileName: string);
    procedure Cleanup;
    procedure DoAfterExecuteTool; override;
  protected
    function GetDefaultFileName: string; virtual;
    procedure PrepareFile(const AFileName: string); virtual;
    function CreateStream: TStream; virtual;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
    class function GetDefaultImageName: string; override;
  //published
    [YamlNode('FileName', 'Server file path to download')]
    property FileName: string read GetFileName;
    [YamlNode('ClientFileName', 'File name sent to client browser')]
    property ClientFileName: string read GetClientFileName;
    [YamlNode('ContentType', 'MIME content type for download')]
    property ContentType: string read GetContentType;
    [YamlNode('PersistentFileName', 'Server path to persist a copy of the file before download')]
    property PersistentFileName: string read GetPersistentFileName;
  end;

  /// <summary>Uploads a file provided via HTTP upload.</summary>
  /// <remarks>
  ///   <para>This class can be used as-is to upload a file to the server, or
  ///   inherited to serve on-demand import.</para>
  ///   <para>Params for the as-is version:</para>
  ///   <list type="table">
  ///     <listheader>
  ///       <term>Term</term>
  ///       <description>Description</description>
  ///     </listheader>
  ///     <item>
  ///       <term>Path</term>
  ///       <description>Full path in which to save the uploaded file.
  ///       May contain macros.</description>
  ///     </item>
  ///     <item>
  ///       <term>ContentType</term>
  ///       <description>Content type passed from the client; if not specified,
  ///       it is derived from the file name's extension.</description>
  ///     </item>
  ///     <item>
  ///       <term>MaxUploadSize</term>
  ///       <description>Maximum allowed size for the uploaded file.</description>
  ///     </item>
  ///   </list>
  /// </remarks>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXUploadFileController = class(TKXDataToolController)
  strict private
    FTempFileNames: TStrings;
    function GetContentType: string;
    function GetPath: string;
    function GetMaxUploadSize: Integer;
  strict protected
    procedure ExecuteTool; override;
    function GetAcceptedWildcards: string; virtual;
    function GetDefaultPath: string; virtual;
    procedure AddTempFilename(const AFileName: string);
    procedure Cleanup;
    procedure DoAfterExecuteTool; override;
  protected
    procedure ProcessUploadedFile(const AFile: TAbstractWebRequestFile); virtual;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
    class function GetDefaultImageName: string; override;
  //published
    [YamlNode('Path', 'Upload directory path')]
    property Path: string read GetPath;
    [YamlNode('AcceptedWildcards', 'Accepted file patterns (space-separated wildcards)')]
    property AcceptedWildcards: string read GetAcceptedWildcards;
    [YamlNode('ContentType', 'Expected content type')]
    property ContentType: string read GetContentType;
    [YamlNode('MaxUploadSize', 'Maximum file size in bytes')]
    property MaxUploadSize: Integer read GetMaxUploadSize;
  end;

implementation

uses
  System.Types,
  System.SysUtils,
  System.StrUtils,
  System.IOUtils,
  System.JSON,
  System.Masks,
  EF.Localization,
  Kitto.Types,
  Kitto.Web.Application,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Html.Controller;

{ TKXDownloadFileController }

procedure TKXDownloadFileController.AddTempFilename(const AFileName: string);
begin
  FTempFileNames.Add(AFileName);
end;

procedure TKXDownloadFileController.AfterConstruction;
begin
  inherited;
  FTempFileNames := TStringList.Create;
end;

procedure TKXDownloadFileController.Cleanup;
var
  I: Integer;
begin
  for I := 0 to FTempFileNames.Count - 1 do
    TFile.Delete(FTempFileNames[I]);
  FTempFileNames.Clear;
end;

function TKXDownloadFileController.CreateStream: TStream;
begin
  Result := nil;
end;

procedure TKXDownloadFileController.ExecuteTool;
var
  LFileStream: TFileStream;
  LMemStream: TMemoryStream;
begin
  inherited;
  try
    FFileName := GetFileName;
    if FFileName <> '' then
    begin
      PrepareFile(FFileName);
      // Read file into memory so the file handle is released immediately.
      // This allows Cleanup to delete the temp file while the in-memory
      // stream is still owned by the HTTP response.
      LFileStream := TFileStream.Create(FFileName, fmOpenRead);
      try
        PersistFile(LFileStream);
        LMemStream := TMemoryStream.Create;
        LFileStream.Position := 0;
        LMemStream.CopyFrom(LFileStream, 0);
        LMemStream.Position := 0;
      finally
        FreeAndNil(LFileStream);
      end;
      // Memory stream ownership transfers to the HTTP response.
      DoDownloadStream(LMemStream, ClientFileName, ContentType);
    end
    else
    begin
      FStream := CreateStream;
      PersistFile(FStream);
      // Stream ownership transfers to the HTTP response.
      DoDownloadStream(FStream, ClientFileName, ContentType);
      FStream := nil; // Ownership transferred; prevent double-free in destructor.
    end;
  except
    Cleanup;
    raise;
  end;
end;

destructor TKXDownloadFileController.Destroy;
begin
  Cleanup;
  FTempFileNames.Free;
  FreeAndNil(FStream);
  inherited;
end;

procedure TKXDownloadFileController.DoAfterExecuteTool;
begin
  // AfterExecuteTool is called in DoDownloadStream after the download completes.
end;

procedure TKXDownloadFileController.DoDownloadStream(const AStream: TStream;
  const AFileName, AContentType: string);
begin
  TKWebApplication.Current.DownloadStream(AStream, AFileName, AContentType, False);
  AfterExecuteTool;
end;

function TKXDownloadFileController.GetPersistentFileName: string;
begin
  Result := ExpandServerRecordValues(Config.GetExpandedString('PersistentFileName'));
end;

procedure TKXDownloadFileController.PersistFile(const AStream: TStream);
var
  LPersistentFileName: string;
  LFileStream: TFileStream;
begin
  Assert(Assigned(AStream));

  LPersistentFileName := GetPersistentFileName;
  if LPersistentFileName <> '' then
  begin
    if FileExists(LPersistentFileName) then
      TFile.Delete(LPersistentFileName);
    LFileStream := TFileStream.Create(LPersistentFileName, fmCreate or fmShareExclusive);
    try
      AStream.Position := 0;
      LFileStream.CopyFrom(AStream, 0);
    finally
      FreeAndNil(LFileStream);
      AStream.Position := 0;
    end;
  end;
end;

function TKXDownloadFileController.GetClientFileName: string;
begin
  Result := ExpandServerRecordValues(Config.GetExpandedString('ClientFileName'));
  if (Result = '') then
  begin
    if Assigned(ViewTable) then
      Result := ViewTable.PluralDisplayLabel + GetDefaultFileExtension
    else
      Result := ExtractFileName(FileName);
  end;
  Result := ValidFileName(Result);
end;

function TKXDownloadFileController.GetContentType: string;
begin
  Result := Config.GetExpandedString('ContentType');
end;

function TKXDownloadFileController.GetDefaultFileExtension: string;
begin
  Result := '';
end;

function TKXDownloadFileController.GetDefaultFileName: string;
begin
  Result := '';
end;

class function TKXDownloadFileController.GetDefaultImageName: string;
begin
  Result := 'download';
end;

function TKXDownloadFileController.GetFileExtension: string;
begin
  if ClientFileName <> '' then
    Result := ExtractFileExt(ClientFileName)
  else
    Result := GetDefaultFileExtension;
end;

function TKXDownloadFileController.GetFileName: string;
begin
  Result := ExpandServerRecordValues(Config.GetExpandedString('FileName', GetDefaultFileName));
end;

procedure TKXDownloadFileController.PrepareFile(const AFileName: string);
begin
end;

{ TKXUploadFileController }

procedure TKXUploadFileController.AddTempFilename(const AFileName: string);
begin
  FTempFileNames.Add(AFileName);
end;

procedure TKXUploadFileController.AfterConstruction;
begin
  inherited;
  FTempFileNames := TStringList.Create;
end;

procedure TKXUploadFileController.Cleanup;
var
  I: Integer;
begin
  for I := 0 to FTempFileNames.Count - 1 do
    TFile.Delete(FTempFileNames[I]);
  FTempFileNames.Clear;
end;

destructor TKXUploadFileController.Destroy;
begin
  Cleanup;
  FTempFileNames.Free;
  inherited;
end;

procedure TKXUploadFileController.DoAfterExecuteTool;
begin
  // AfterExecuteTool is called after processing the uploaded file.
end;

procedure TKXUploadFileController.ExecuteTool;
var
  LFileName, LAcceptedWildcards, LWildcard: string;
  LWildcards: TStringDynArray;
  I: Integer;
  LAccepted: Boolean;
begin
  inherited;

  if TKWebRequest.Current.Files.Count = 0 then
    raise EKError.Create(_('No file uploaded'));

  LFileName := TKWebRequest.Current.Files[0].FileName;
  LAcceptedWildcards := AcceptedWildcards;
  if LAcceptedWildcards <> '' then
  begin
    LWildcards := SplitString(LAcceptedWildcards, ' ');
    LAccepted := False;
    for I := 0 to High(LWildcards) do
    begin
      LWildcard := LWildcards[I];
      if (LWildcard <> '') and MatchesMask(LFileName, LWildcard) then
      begin
        LAccepted := True;
        Break;
      end;
    end;
    if not LAccepted then
      raise EKError.CreateFmt(_('Error: uploaded file name doesn''t match wildcards (%s)'), [LAcceptedWildcards]);
  end;

  ProcessUploadedFile(TKWebRequest.Current.Files[0]);
  AfterExecuteTool;
end;

function TKXUploadFileController.GetContentType: string;
begin
  Result := Config.GetExpandedString('ContentType');
end;

function TKXUploadFileController.GetDefaultPath: string;
begin
  Result := '';
end;

function TKXUploadFileController.GetMaxUploadSize: Integer;
begin
  Result := Config.GetInteger('MaxUploadSize', MaxInt);
end;

class function TKXUploadFileController.GetDefaultImageName: string;
begin
  Result := 'upload';
end;

function TKXUploadFileController.GetPath: string;
begin
  Result := Config.GetExpandedString('Path', GetDefaultPath);
end;

function TKXUploadFileController.GetAcceptedWildcards: string;
begin
  Result := Config.GetString('AcceptedWildcards');
end;

procedure TKXUploadFileController.ProcessUploadedFile(const AFile: TAbstractWebRequestFile);
var
  LFileStream: TFileStream;
begin
  LFileStream := TFileStream.Create(TPath.Combine(Path, AFile.FileName), fmCreate or fmShareExclusive);
  try
    LFileStream.CopyFrom(AFile.Stream, 0);
  finally
    FreeAndNil(LFileStream);
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('DownloadFile', TKXDownloadFileController);
  TKXControllerRegistry.Instance.RegisterClass('UploadFile', TKXUploadFileController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('DownloadFile');
  TKXControllerRegistry.Instance.UnregisterClass('UploadFile');

end.
