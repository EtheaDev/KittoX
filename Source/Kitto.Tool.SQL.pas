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
///  SQL command execution tool controller for KittoX.
///  Replaces Kitto.Ext.SQLTool.
/// </summary>
unit Kitto.Tool.SQL;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  EF.YAML.Attributes,
  Kitto.Metadata.DataView,
  Kitto.Html.Tools;

type
  /// <summary>
  ///  Base class to execute a SQL Command.
  ///  Equivalent to TKExtDataExecSQLCmdToolController.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXDataExecSQLCmdToolController = class(TKXDataToolController)
  strict private
    function GetSQLCommandText: string;
    function GetDatabaseName: string;
  strict protected
    procedure ExecuteTool; override;
    procedure AssignParamValue(const AParam: TParam; var AValue: Variant);
  public
    /// <summary>Returns the default toolbar icon name for this tool.</summary>
    class function GetDefaultImageName: string; override;
  //published
    [YamlNode('SQLCommandText', 'SQL command text to execute')]
    property SQLCommandText: string read GetSQLCommandText;
    [YamlNode('DatabaseName', 'Database connection name (defaults to ViewTable database)')]
    property DatabaseName: string read GetDatabaseName;
  end;

implementation

uses
  System.StrUtils,
  EF.Tree,
  EF.DB,
  EF.StrUtils,
  EF.Sys,
  EF.Localization,
  EF.Macros,
  Kitto.DatabaseRouter,
  Kitto.Config,
  Kitto.Web.Application,
  Kitto.Html.Controller;

{ TKXDataExecSQLCmdToolController }

procedure TKXDataExecSQLCmdToolController.AssignParamValue(const AParam: TParam; var AValue: Variant);
var
  LNode: TEFNode;
  LRecord: TKViewTableRecord;
  LStringValue: string;

  procedure ExpandExpression(var AExpression: string);
  begin
    if Assigned(LRecord) then
    begin
      LRecord.ExpandFieldJSONValues(AExpression, True);
      TEFMacroExpansionEngine.Instance.Expand(AExpression);
    end
    else
      TEFMacroExpansionEngine.Instance.Expand(AExpression);
  end;

begin
  LRecord := ServerRecord;

  //By default Param Values are assigned by the Parameters node values:
  LNode := Config.FindNode('Parameters/'+AParam.Name);
  if Assigned(LNode) then
  begin
    LStringValue := LNode.AsString;
    ExpandExpression(LStringValue);
    AValue := LStringValue;
  end;
end;

procedure TKXDataExecSQLCmdToolController.ExecuteTool;
var
  LCommandText: string;
  LDBCommand: TEFDBCommand;
  LDBConnection: TEFDBConnection;
  I: Integer;
  LParam: TParam;
  LParamNode: TEFNode;
  LSuccessNode: TEFNode;
  LFailureNode: TEFNode;
  LSuccess: Boolean;
  LSuccessMessage, LErrorMessage: string;
  LExpandedValue: string;

  procedure ExpandExpression(var AExpression: string);
  begin
    if Assigned(ServerRecord) then
      ServerRecord.ExpandFieldJSONValues(AExpression, True);
    TEFMacroExpansionEngine.Instance.Expand(AExpression);
  end;

  function ExpandParamNode(const AExpression: string): string;
  var
    I: Integer;
    LParam: TParam;
  begin
    Result := AExpression;
    for I := 0 to LDBCommand.Params.Count - 1 do
    begin
      LParam := LDBCommand.Params[I];
      Result := ReplaceText(Result, '{' + LParam.Name + '}', LParam.AsString);
    end;
  end;

begin
  inherited;
  LDBConnection := TKConfig.DatabaseFor(DatabaseName);
  LDBConnection.StartTransaction;
  try
    LCommandText := Config.GetString('SQLCommandText');
    Assert(LCommandText <> '','SQLCommandText is mandatory');

    LDBCommand := LDBConnection.CreateDBCommand;
    try
      LDBCommand.CommandText := LCommandText;
      // Assign input param values
      for I := 0 to LDBCommand.Params.Count - 1 do
      begin
        LParam := LDBCommand.Params[I];
        LParamNode := Config.FindNode('InputParams/' + LParam.Name);
        if Assigned(LParamNode) then
        begin
          LExpandedValue := LParamNode.GetString('Value');
          ExpandExpression(LExpandedValue);
          if not SameText(LExpandedValue, LParamNode.AsString) then
            LParam.AsString := LExpandedValue
          else
            LParamNode.AssignToParam(LParam);
        end;
      end;

      LDBCommand.Execute;

      // Read output parameters
      LSuccess := True;
      for I := 0 to LDBCommand.Params.Count - 1 do
      begin
        LParam := LDBCommand.Params[I];
        LParamNode := Config.FindNode('OutputParams/' + LParam.Name);
        if Assigned(LParamNode) then
        begin
          LParamNode.Value := LParam.Value;
          LSuccessNode := LParamNode.FindNode('SuccessValue');
          LFailureNode := LParamNode.FindNode('FailureValue');
          if Assigned(LFailureNode) then
            LSuccess := LFailureNode.Value <> LParam.Value
          else if Assigned(LSuccessNode) then
            LSuccess := LSuccessNode.Value = LParam.Value;
        end;
      end;

      if LSuccess then
      begin
        LSuccessMessage := ExpandParamNode(Config.GetString('SuccessMessageTemplate',
          Format(_('Command %s executed succesfully!'), [DisplayLabel])));
        TKWebApplication.Current.Toast(LSuccessMessage);
      end
      else
      begin
        LErrorMessage := ExpandParamNode(Config.GetString('ErrorMessageTemplate',
          Format(_('Error executing command %s!'), [DisplayLabel])));
        raise Exception.Create(LErrorMessage);
      end;
      LDBConnection.CommitTransaction;
    finally
      FreeAndNil(LDBCommand);
    end;
  except
    LDBConnection.RollbackTransaction;
    raise;
  end;
end;

function TKXDataExecSQLCmdToolController.GetSQLCommandText: string;
begin
  Result := Config.GetExpandedString('SQLCommandText');
end;

function TKXDataExecSQLCmdToolController.GetDatabaseName: string;
begin
  Result := Config.GetString('DatabaseName', ViewTable.DatabaseName);
end;

class function TKXDataExecSQLCmdToolController.GetDefaultImageName: string;
begin
  Result := 'exec_sqlcommand';
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('ExecuteSQLCommand', TKXDataExecSQLCmdToolController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('ExecuteSQLCommand');

end.
