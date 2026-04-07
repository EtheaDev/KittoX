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
///  Base tool controller classes for the KittoX HTML pipeline.
///  Tools are server-side controllers that execute operations (export, SQL, email, etc.)
///  without producing HTML output.
///  Replaces TKExtToolController, TKExtDataToolController and TKExtDataCmdToolController
///  from Kitto.Ext.Base and Kitto.Ext.DataTool.
/// </summary>
unit Kitto.Html.Tools;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  EF.Intf,
  EF.Tree,
  EF.ObserverIntf,
  EF.Classes,
  EF.StrUtils,
  EF.YAML.Attributes,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView,
  Kitto.Html.Base;

type
  /// <summary>
  ///  Base class for tool controllers in KittoX.
  ///  Tools execute server-side operations and produce no HTML output.
  ///  Equivalent to TKExtToolController.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXToolController = class(TKXComponent)
  strict protected
    function GetDisplayLabel: string;
    procedure ExecuteTool; virtual;
    procedure DoAfterExecuteTool; virtual;
    procedure AfterExecuteTool; virtual;
  public
    class function GetDefaultImageName: string; virtual;
    function IsSynchronous: Boolean; override;
    [YamlNode('DisplayLabel', 'Tool display label (defaults to View DisplayLabel)')]
    property DisplayLabel: string read GetDisplayLabel;
    procedure Display; override;
    function Render: string; override;
  end;

  TKXToolControllerClass = class of TKXToolController;

  /// <summary>
  ///  Data-aware tool controller with access to ServerStore/ServerRecord.
  ///  Equivalent to TKExtDataToolController.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXDataToolController = class(TKXToolController)
  strict private
    function GetServerRecord: TKViewTableRecord;
    function GetServerStore: TKViewTableStore;
    function GetViewTable: TKViewTable;
  strict protected
    procedure AfterExecuteTool; override;
    procedure ExecuteTool; override;
    property ServerStore: TKViewTableStore read GetServerStore;
    property ServerRecord: TKViewTableRecord read GetServerRecord;
    property ViewTable: TKViewTable read GetViewTable;

    procedure RefreshData(const AAllRecords: Boolean = False);
    procedure ExecuteInTransaction(const AProc: TProc);
    procedure EnumSelectedRecords(const AProc: TProc<TKViewTableRecord>);
    function ExpandServerRecordValues(const AString: string): string;
  end;

  /// <summary>
  ///  Executes a command or executable file and waits for its completion.
  ///  Equivalent to TKExtDataCmdToolController.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXDataCmdToolController = class(TKXDataToolController)
  strict private
    function GetBatchFileName: string;
    function GetParameters: string;
  strict protected
    procedure ExecuteTool; override;
    procedure AfterExecuteTool; override;
  public
    class function GetDefaultImageName: string; override;
  //published
    [YamlNode('BatchFileName', 'Path to the batch file or executable to run')]
    property BatchFileName: string read GetBatchFileName;
    [YamlNode('Parameters', 'Command-line parameters for the batch file')]
    property Parameters: string read GetParameters;
  end;

implementation

uses
  System.StrUtils,
  EF.DB,
  EF.Sys,
  EF.Localization,
  Kitto.Config,
  Kitto.Web.Application,
  Kitto.Web.Request,
  Kitto.Html.Controller;

{ TKXToolController }

procedure TKXToolController.ExecuteTool;
begin
end;

function TKXToolController.GetDisplayLabel: string;
begin
  if Assigned(View) then
    Result := Config.GetExpandedString('Title', View.DisplayLabel)
  else
    Result := '';
end;

function TKXToolController.IsSynchronous: Boolean;
begin
  Result := True;
end;

class function TKXToolController.GetDefaultImageName: string;
begin
  Result := 'tool_exec';
end;

procedure TKXToolController.AfterExecuteTool;
begin
end;

procedure TKXToolController.DoAfterExecuteTool;
begin
  AfterExecuteTool;
end;

procedure TKXToolController.Display;
begin
  inherited;
  ExecuteTool;
  DoAfterExecuteTool;
end;

function TKXToolController.Render: string;
begin
  Result := '';
end;

{ TKXDataToolController }

procedure TKXDataToolController.AfterExecuteTool;
var
  LAutoRefresh: string;
begin
  inherited;
  LAutoRefresh := Config.GetString('AutoRefresh');
  if MatchText(LAutoRefresh, ['Current', 'All']) then
    RefreshData(SameText(LAutoRefresh, 'All'));
end;

procedure TKXDataToolController.EnumSelectedRecords(
  const AProc: TProc<TKViewTableRecord>);
var
  LKey: TEFNode;
  LRecordCount: Integer;
  I: Integer;
begin
  Assert(Assigned(AProc));

  LKey := TEFNode.Create;
  try
    LKey.Assign(ServerStore.Key);
    Assert(LKey.ChildCount > 0);
    LRecordCount := Length(Split(TKWebRequest.Current.GetQueryField(LKey[0].Name), ','));
    for I := 0 to LRecordCount - 1 do
      AProc(ServerStore.GetRecord(TKWebRequest.Current.QueryTree, TKWebApplication.Current.Config.JSFormatSettings, I));
  finally
    FreeAndNil(LKey);
  end;
end;

procedure TKXDataToolController.ExecuteInTransaction(const AProc: TProc);
var
  LDBConnection: TEFDBConnection;
begin
  Assert(Assigned(AProc));

  LDBConnection := TKConfig.Instance.CreateDBConnection(ViewTable.DatabaseName);
  try
    LDBConnection.StartTransaction;
    try
      AProc;
      LDBConnection.CommitTransaction;
    except
      LDBConnection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LDBConnection);
  end;
end;

function TKXDataToolController.ExpandServerRecordValues(const AString: string): string;
var
  LRecord: TKViewTableRecord;
begin
  Result := AString;
  LRecord := ServerRecord;
  if (LRecord = nil) and (ServerStore <> nil) and (ServerStore.RecordCount > 0) then
    LRecord := ServerStore.Records[0];
  if LRecord <> nil then
    LRecord.ExpandExpression(Result);
end;

procedure TKXDataToolController.ExecuteTool;
begin
  inherited;
  if Config.GetBoolean('RequireDetails') and Assigned(ServerRecord) then
    ServerRecord.LoadDetailStores;
end;

function TKXDataToolController.GetServerRecord: TKViewTableRecord;
begin
  Result := Config.GetObject('Sys/Record') as TKViewTableRecord;
end;

function TKXDataToolController.GetServerStore: TKViewTableStore;
begin
  Result := Config.GetObject('Sys/ServerStore') as TKViewTableStore;
end;

function TKXDataToolController.GetViewTable: TKViewTable;
begin
  Result := Config.GetObject('Sys/ViewTable') as TKViewTable;
end;

procedure TKXDataToolController.RefreshData(const AAllRecords: Boolean);
begin
  if AAllRecords then
    NotifyObservers('RefreshAllRecords')
  else
    ServerRecord.Refresh;
end;

{ TKXDataCmdToolController }

procedure TKXDataCmdToolController.AfterExecuteTool;
begin
  inherited;
  TKWebApplication.Current.Toast(_('Command executed succesfully.'));
end;

procedure TKXDataCmdToolController.ExecuteTool;
var
  LBatchFileName, LBatchCommand, LParameters: string;
begin
  inherited;
  LBatchFileName := ExpandServerRecordValues(BatchFileName);
  Assert(LBatchFileName <> '','BatchFileName is mandatory');
  if not FileExists(LBatchFileName) then
    raise Exception.CreateFmt('File not found %s', [LBatchFileName]);

  LParameters := ExpandServerRecordValues(Parameters);
  if LParameters <> '' then
    LBatchCommand := LBatchFileName + ' ' + LParameters
  else
    LBatchCommand := LBatchFileName;

  if EFSys.ExecuteCommand(LBatchCommand) <> 0 then
    raise Exception.CreateFmt('Error executing %s', [ExtractFileName(LBatchFileName)]);
end;

function TKXDataCmdToolController.GetBatchFileName: string;
begin
  Result := Config.GetExpandedString('BatchFileName');
end;

class function TKXDataCmdToolController.GetDefaultImageName: string;
begin
  Result := 'execute_command';
end;

function TKXDataCmdToolController.GetParameters: string;
begin
  Result := Config.GetExpandedString('Parameters');
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('ExecuteCmdTool', TKXDataCmdToolController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('ExecuteCmdTool');

end.
