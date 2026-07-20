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

///	<summary>
///	  Devart ODAC-based database access layer (Oracle only).
///	</summary>
///	<remarks>
///	  This unit provides an alternative Oracle back-end based on Devart's Oracle
///	  Data Access Components (ODAC), for sites that own an ODAC license and
///	  prefer it over the OCI/FireDAC path. It does NOT replace EF.DB.FD: Oracle
///	  via FireDAC (DriverID = Ora) keeps working exactly as before and remains
///	  the default option for sites without ODAC.
///
///	  Because ODAC is a third-party commercial library, this unit is NOT part of
///	  KittoXCore.dpk (which must compile with a plain Delphi install). To enable
///	  the 'ODAC' adapter in an application, add EF.DB.ODAC to the application's
///	  UseKitto.pas (or project uses clause) and add the ODAC library path to the
///	  project search path. Referencing the unit is enough: the adapter
///	  self-registers in the initialization section with the ClassId 'ODAC'.
///
///	  Config.yaml example:
///	  <code>
///	    ODAC_Oracle: ODAC
///	      Connection:
///	        # EZ Connect string: host:port/service_name (Oracle XE 21c PDB = xepdb1)
///	        Server: localhost:1521/xepdb1
///	        User_Name: HELLOKITTO
///	        Password: 12345
///	        # Direct mode connects over Oracle Net without an installed Oracle
///	        # client (requires ODAC Professional). Set to False to use OCI.
///	        Direct: True
///	        # Oracle has no native boolean: booleans map to NUMBER(1) (0/1).
///	        Charset: AL32UTF8
///	        # ConnectMode: Normal (default), SysDBA or SysOper.
///	        ConnectMode: Normal
///	        # Optional: ALTER SESSION SET CURRENT_SCHEMA on connect.
///	        Schema: HELLOKITTO
///	  </code>
///	</remarks>
unit EF.DB.ODAC;

{$I EF.Defines.inc}

interface

uses
  System.Classes,
  Data.DB,
  // ---------------------------------------------------------------------------
  // Devart ODAC units. If compilation stops here with "unit Ora/OraClasses/
  // DBAccess not found", Devart's Oracle Data Access Components (ODAC) are NOT
  // installed on this machine. This unit is optional: install ODAC and add its
  // library path to the project, or simply do NOT reference EF.DB.ODAC (use the
  // FireDAC Oracle path in EF.DB.FD instead, which ships with Delphi).
  // ODAC: https://www.devart.com/odac/
  // ---------------------------------------------------------------------------
  Ora,
  OraClasses,
  DBAccess,
  EF.Tree,
  EF.DB,
  EF.YAML.Attributes,
  Kitto.Metadata.SubNodes2;

type
  ///	<summary>
  ///	  Utility class used to adapt the standard TParams to ODAC's TDAParams.
  ///	</summary>
  TEFDBODACParams = class(TParams)
  public
    ///	<summary>
    ///	  Sets the value of every parameter in ADestination whose name matches
    ///	  the name of a parameter in the current object to that of the current
    ///	  object's parameter, applying Oracle-specific type coercions.
    ///	</summary>
    procedure AssignValuesTo(const ADestination: TDAParams; const AUseBooleanFields: Boolean);
  end;

  ///	<summary>
  ///	  Retrieves metadata from an Oracle database through ODAC. The Oracle data
  ///	  dictionary (USER_* views) is queried directly with SQL, so no dependency
  ///	  is placed on ODAC's own metadata provider.
  ///	</summary>
  TEFDBODACInfo = class(TEFDBInfo)
  private
    FConnection: TOraSession;
    function OracleDataTypeToEFDataType(const ADataType: string;
      const APrecision, AScale: Integer; const AScaleIsNull: Boolean): TEFDataType;
    procedure FetchTableColumnDescriptions(const ATable: TEFDBTableInfo);
    function CreateQuery: TOraQuery;
  protected
    procedure BeforeFetchInfo; override;
    procedure FetchTables(const ASchema: TEFDBSchemaInfo); override;
    procedure FetchTableColumns(const ATable: TEFDBTableInfo);
    procedure FetchTablePrimaryKey(const ATable: TEFDBTableInfo);
    procedure FetchTableForeignKeys(const ATable: TEFDBTableInfo);
  public
    constructor Create(const AConnection: TOraSession);
    property Connection: TOraSession read FConnection write FConnection;
  end;

  TEFDBODACQueryClass = class of TEFDBODACQuery;

  TEFDBODACConnection = class(TEFDBConnection)
  private
    FConnection: TOraSession;
    function GetServer: string;
    function GetConnectMode: TConnectMode;
  protected
    function GetQueryClass: TEFDBODACQueryClass; virtual;
    function CreateDBEngineType: TEFDBEngineType; override;
    procedure AfterConnectionOpen(Sender: TObject); override;
    procedure InternalOpen; override;
    procedure InternalClose; override;
    function InternalCreateDBInfo: TEFDBInfo; override;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  public
    function IsOpen: Boolean; override;
    function ExecuteImmediate(const AStatement: string): Integer; override;
    procedure InternalStartTransaction; override;
    procedure InternalCommitTransaction; override;
    procedure InternalRollbackTransaction; override;
    function IsInTransaction: Boolean; override;
    function FetchSequenceGeneratorValue(const ASequenceName: string): Int64; override;
    function GetLastAutoincValue(const ATableName: string = ''): Int64; override;
    function CreateDBCommand: TEFDBCommand; override;
    function CreateDBQuery: TEFDBQuery; override;
    function GetConnection: TObject; override;
  end;

  TEFDBODACCommand = class(TEFDBCommand)
  private
    FCommand: TOraSQL;
    FParams: TEFDBODACParams;
    FCommandText: string;
    // Copies the values in FParams to FCommand.Params.
    procedure UpdateInternalCommandParams;
    // Updates FCommand's command, if necessary.
    procedure UpdateInternalCommandCommandText;
  protected
    procedure ConnectionChanged; override;
    function GetCommandText: string; override;
    procedure SetCommandText(const AValue: string); override;
    function GetPrepared: Boolean; override;
    procedure SetPrepared(const AValue: Boolean); override;
    function GetParams: TParams; override;
    procedure SetParams(const AValue: TParams); override;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  public
    function Execute: Integer; override;
  end;

  TEFDBODACQuery = class(TEFDBQuery)
  private
    FQuery: TOraQuery;
    FParams: TEFDBODACParams;
    FCommandText: string;
    // Copies the values in FParams to FQuery.Params.
    procedure UpdateInternalQueryParams;
    // Updates FQuery's command, if necessary.
    procedure UpdateInternalQueryCommandText;
  protected
    procedure ConnectionChanged; override;
    function GetCommandText: string; override;
    procedure SetCommandText(const AValue: string); override;
    function GetPrepared: Boolean; override;
    procedure SetPrepared(const AValue: Boolean); override;
    function GetParams: TParams; override;
    procedure SetParams(const AValue: TParams); override;
    function GetDataSet: TDataSet; override;
    function GetMasterSource: TDataSource; override;
    procedure SetMasterSource(const AValue: TDataSource); override;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  public
    ///	<summary>Execute and Open are synonims in this class. Execute always
    ///	returns 0.</summary>
    function Execute: Integer; override;
    procedure Open; override;
    procedure Close; override;
    function IsOpen: Boolean; override;
  end;

  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TEFDBODACAdapter = class(TEFDBAdapter)
  private
    function GetConnectionConfig: TEFDBODACConnectionConfig;
  protected
    function InternalCreateDBConnection: TEFDBConnection; override;
    class function InternalGetClassId: string; override;
  public
    [YamlSubNode('Connection', TEFDBODACConnectionConfig, 'ODAC (Oracle) connection parameters')]
    property ConnectionConfig: TEFDBODACConnectionConfig read GetConnectionConfig;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  EF.StrUtils,
  EF.Localization,
  EF.Types;

{ TEFDBODACParams }

procedure TEFDBODACParams.AssignValuesTo(const ADestination: TDAParams;
  const AUseBooleanFields: Boolean);
var
  LParamIndex: Integer;
  LSourceParam: TParam;
  LDestinationParameter: TDAParam;
begin
  // Causes for errors such as "parameter incomplete or undefined" are
  // column name and type mismatches.
  for LParamIndex := 0 to Count - 1 do
  begin
    LSourceParam := Items[LParamIndex];
    LDestinationParameter := ADestination.FindParam(LSourceParam.Name);
    if not Assigned(LDestinationParameter) then
      Continue;

    if LSourceParam.IsNull then
    begin
      // Preserve a concrete data type so ODAC binds a typed NULL instead of
      // raising "parameter has no value". Unknown types (typical of detail
      // queries with an empty master) are patched to ftString.
      if LSourceParam.DataType = ftUnknown then
        LDestinationParameter.DataType := ftString
      else
        LDestinationParameter.DataType := LSourceParam.DataType;
      LDestinationParameter.Clear;
      Continue;
    end;

    case LSourceParam.DataType of
      ftBoolean:
        // Oracle has no native boolean: map booleans to NUMBER(1) (0/1),
        // unless the caller explicitly opted into native boolean fields.
        if AUseBooleanFields then
          LDestinationParameter.AsBoolean := LSourceParam.AsBoolean
        else
          LDestinationParameter.AsInteger := Ord(LSourceParam.AsBoolean);
      ftBlob, ftGraphic, ftBytes, ftVarBytes, ftOraBlob:
        LDestinationParameter.AsBytes := LSourceParam.AsBlob;
      ftMemo, ftWideMemo, ftOraClob:
        LDestinationParameter.AsString := LSourceParam.AsString;
      ftDate, ftTime, ftDateTime, ftTimeStamp:
        LDestinationParameter.AsDateTime := LSourceParam.AsDateTime;
      ftCurrency:
        LDestinationParameter.AsCurrency := LSourceParam.AsCurrency;
      ftString, ftFixedChar, ftWideString, ftFixedWideChar:
        LDestinationParameter.AsWideString := LSourceParam.AsWideString;
    else
      LDestinationParameter.Value := LSourceParam.Value;
    end;
  end;
end;

{ TEFDBODACConnection }

procedure TEFDBODACConnection.AfterConstruction;
begin
  inherited;
  FConnection := TOraSession.Create(nil);
  FConnection.LoginPrompt := False;
  FConnection.AfterConnect := AfterConnectionOpen;
end;

destructor TEFDBODACConnection.Destroy;
begin
  FreeAndNil(FConnection);
  inherited;
end;

function TEFDBODACConnection.GetServer: string;
begin
  Result := Config.GetExpandedString('Connection/Server');
end;

function TEFDBODACConnection.GetConnectMode: TConnectMode;
var
  LMode: string;
begin
  LMode := Config.GetString('Connection/ConnectMode', 'Normal');
  if SameText(LMode, 'SysDBA') then
    Result := cmSysDBA
  else if SameText(LMode, 'SysOper') then
    Result := cmSysOper
  else
    Result := cmNormal;
end;

procedure TEFDBODACConnection.InternalOpen;
var
  LCharset: string;
begin
  inherited;
  if FConnection.Connected then
    Exit;

  FConnection.Server := GetServer;
  FConnection.Username := Config.GetExpandedString('Connection/User_Name');
  FConnection.Password := Config.GetExpandedString('Connection/Password');
  FConnection.ConnectMode := GetConnectMode;
  // Direct mode connects over Oracle Net without a locally installed Oracle
  // client (requires ODAC Professional). Defaults to True.
  FConnection.Options.Direct := Config.GetBoolean('Connection/Direct', True);
  LCharset := Config.GetExpandedString('Connection/Charset');
  if LCharset <> '' then
    FConnection.Options.Charset := LCharset;

  FConnection.Connect;
end;

procedure TEFDBODACConnection.AfterConnectionOpen(Sender: TObject);
var
  LSchema: string;
begin
  inherited;
  // Optional: change the default (current) schema used to resolve unqualified
  // object names. Metadata reads still use the connecting user's USER_* views.
  LSchema := Config.GetExpandedString('Connection/Schema');
  if LSchema <> '' then
    FConnection.ExecSQL('ALTER SESSION SET CURRENT_SCHEMA = ' + LSchema, []);
end;

procedure TEFDBODACConnection.InternalClose;
begin
  if FConnection.Connected then
    FConnection.Disconnect;
end;

function TEFDBODACConnection.InternalCreateDBInfo: TEFDBInfo;
begin
  Result := TEFDBODACInfo.Create(FConnection);
end;

procedure TEFDBODACConnection.InternalStartTransaction;
begin
  if not FConnection.InTransaction then
    FConnection.StartTransaction;
end;

procedure TEFDBODACConnection.InternalCommitTransaction;
begin
  if FConnection.InTransaction then
    FConnection.Commit;
end;

procedure TEFDBODACConnection.InternalRollbackTransaction;
begin
  if FConnection.InTransaction then
    FConnection.Rollback;
end;

function TEFDBODACConnection.IsInTransaction: Boolean;
begin
  Result := FConnection.InTransaction;
end;

function TEFDBODACConnection.CreateDBEngineType: TEFDBEngineType;
begin
  // ODAC is an Oracle-only adapter.
  Result := TEFOracleDBEngineType.Create;
end;

function TEFDBODACConnection.CreateDBCommand: TEFDBCommand;
begin
  Result := TEFDBODACCommand.Create;
  try
    Result.Connection := Self;
    Open;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TEFDBODACConnection.CreateDBQuery: TEFDBQuery;
begin
  Result := GetQueryClass.Create;
  try
    Result.Connection := Self;
    Open;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TEFDBODACConnection.ExecuteImmediate(const AStatement: string): Integer;
begin
  Assert(Assigned(FConnection));

  if AStatement = '' then
    raise EEFError.Create(_('Unspecified Statement text.'));
  try
    Result := FConnection.ExecSQL(AStatement, []);
  except
    on E: Exception do
      raise EEFDBError.CreateForQuery(E.Message, AStatement);
  end;
end;

function TEFDBODACConnection.FetchSequenceGeneratorValue(
  const ASequenceName: string): Int64;
var
  LQuery: TOraQuery;
begin
  if ASequenceName = '' then
    raise EEFError.Create(_('Unspecified Sequence name.'));
  Open;
  LQuery := TOraQuery.Create(nil);
  try
    LQuery.Session := FConnection;
    LQuery.SQL.Text := 'select ' + ASequenceName + '.NEXTVAL from DUAL';
    LQuery.Open;
    Result := LQuery.Fields[0].AsLargeInt;
  finally
    LQuery.Free;
  end;
end;

function TEFDBODACConnection.GetQueryClass: TEFDBODACQueryClass;
begin
  Result := TEFDBODACQuery;
end;

function TEFDBODACConnection.GetConnection: TObject;
begin
  Result := FConnection;
end;

function TEFDBODACConnection.GetLastAutoincValue(
  const ATableName: string = ''): Int64;
begin
  // Identity/auto-inc semantics are not surfaced by this adapter; Oracle
  // applications should use sequences (see FetchSequenceGeneratorValue).
  Result := 0;
end;

function TEFDBODACConnection.IsOpen: Boolean;
begin
  if FConnection = nil then
    Result := False
  else
    Result := FConnection.Connected;
end;

{ TEFDBODACCommand }

procedure TEFDBODACCommand.AfterConstruction;
begin
  inherited;
  FCommand := TOraSQL.Create(nil);
  FParams := TEFDBODACParams.Create(nil);
end;

destructor TEFDBODACCommand.Destroy;
begin
  FreeAndNil(FCommand);
  FreeAndNil(FParams);
  inherited;
end;

procedure TEFDBODACCommand.ConnectionChanged;
begin
  inherited;
  FCommand.Session := (Connection.AsObject as TEFDBODACConnection).FConnection;
end;

function TEFDBODACCommand.Execute: Integer;
begin
  UpdateInternalCommandCommandText;
  try
    Connection.DBEngineType.BeforeExecute(FCommandText, FParams);
    UpdateInternalCommandParams;
    inherited;
    FCommand.Execute;
    Result := FCommand.RowsAffected;
  except
    on E: Exception do
      raise EEFDBError.CreateForQuery(E.Message, FCommandText);
  end;
end;

function TEFDBODACCommand.GetCommandText: string;
begin
  Result := FCommandText;
end;

function TEFDBODACCommand.GetParams: TParams;
begin
  Result := FParams;
end;

function TEFDBODACCommand.GetPrepared: Boolean;
begin
  Result := FCommand.Prepared;
end;

procedure TEFDBODACCommand.SetCommandText(const AValue: string);
var
  LThrowaway: string;
begin
  FCommandText := AValue;
  LThrowaway := FCommandText;
  UniqueString(LThrowaway);
  // Note: ParseSQL incorrectly behaves as if its first parameter was passed
  // by reference and modifies it. So we must pass a disposable string to it.
  FParams.ParseSQL(LThrowaway, True);
end;

procedure TEFDBODACCommand.SetParams(const AValue: TParams);
begin
  FParams.Assign(AValue);
end;

procedure TEFDBODACCommand.SetPrepared(const AValue: Boolean);
begin
  FCommand.Prepared := AValue;
end;

procedure TEFDBODACCommand.UpdateInternalCommandCommandText;
begin
  if FCommand.SQL.Text <> FCommandText then
    FCommand.SQL.Text := ExpandCommandText(FCommandText);
end;

procedure TEFDBODACCommand.UpdateInternalCommandParams;
begin
  // Oracle has no native boolean type; booleans are bound as NUMBER(1).
  FParams.AssignValuesTo(FCommand.Params, False);
end;

{ TEFDBODACQuery }

procedure TEFDBODACQuery.AfterConstruction;
begin
  inherited;
  FQuery := TOraQuery.Create(nil);
  FParams := TEFDBODACParams.Create(nil);
end;

destructor TEFDBODACQuery.Destroy;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FParams);
  inherited;
end;

procedure TEFDBODACQuery.ConnectionChanged;
begin
  inherited;
  FQuery.Session := (Connection.AsObject as TEFDBODACConnection).FConnection;
end;

function TEFDBODACQuery.Execute: Integer;
begin
  inherited;
  Open;
  Result := 0;
end;

procedure TEFDBODACQuery.Open;
begin
  try
    UpdateInternalQueryCommandText;
    Connection.DBEngineType.BeforeExecute(FCommandText, FParams);
    UpdateInternalQueryParams;
    InternalBeforeExecute;
    FQuery.Open;
  except
    on E: Exception do
      raise EEFDBError.CreateForQuery(E.Message, FCommandText);
  end;
end;

procedure TEFDBODACQuery.Close;
begin
  FQuery.Close;
end;

function TEFDBODACQuery.GetCommandText: string;
begin
  Result := FCommandText;
end;

function TEFDBODACQuery.GetDataSet: TDataSet;
begin
  Result := FQuery;
end;

function TEFDBODACQuery.GetMasterSource: TDataSource;
begin
  Result := FQuery.MasterSource;
end;

function TEFDBODACQuery.GetParams: TParams;
begin
  Result := FParams;
end;

function TEFDBODACQuery.GetPrepared: Boolean;
begin
  Result := FQuery.Prepared;
end;

function TEFDBODACQuery.IsOpen: Boolean;
begin
  Result := FQuery.Active;
end;

procedure TEFDBODACQuery.SetCommandText(const AValue: string);
var
  LThrowaway: string;
begin
  FCommandText := AValue;
  LThrowaway := FCommandText;
  UniqueString(LThrowaway);
  // Note: ParseSQL incorrectly behaves as if its first parameter was passed
  // by reference and modifies it. So we pass a disposable string to it.
  FParams.ParseSQL(LThrowaway, True);
end;

procedure TEFDBODACQuery.SetMasterSource(const AValue: TDataSource);
begin
  FQuery.MasterSource := AValue;
end;

procedure TEFDBODACQuery.SetParams(const AValue: TParams);
begin
  FParams.Assign(AValue);
end;

procedure TEFDBODACQuery.SetPrepared(const AValue: Boolean);
begin
  FQuery.Prepared := AValue;
end;

procedure TEFDBODACQuery.UpdateInternalQueryCommandText;
begin
  FQuery.SQL.Text := ExpandCommandText(FCommandText);
end;

procedure TEFDBODACQuery.UpdateInternalQueryParams;
begin
  // Oracle has no native boolean type; booleans are bound as NUMBER(1).
  FParams.AssignValuesTo(FQuery.Params, False);
end;

{ TEFDBODACInfo }

constructor TEFDBODACInfo.Create(const AConnection: TOraSession);
begin
  inherited Create;
  FConnection := AConnection;
end;

procedure TEFDBODACInfo.BeforeFetchInfo;
begin
  inherited;
  Assert(Assigned(FConnection));
end;

function TEFDBODACInfo.CreateQuery: TOraQuery;
begin
  Result := TOraQuery.Create(nil);
  Result.Session := FConnection;
end;

function TEFDBODACInfo.OracleDataTypeToEFDataType(const ADataType: string;
  const APrecision, AScale: Integer; const AScaleIsNull: Boolean): TEFDataType;
var
  LClass: TEFDataTypeClass;
  LType: string;
begin
  LType := UpperCase(Trim(ADataType));
  if (LType = 'VARCHAR2') or (LType = 'NVARCHAR2') or (LType = 'VARCHAR') or
     (LType = 'CHAR') or (LType = 'NCHAR') or (LType = 'ROWID') or
     (LType = 'UROWID') then
    LClass := TEFStringDataType
  else if LType = 'NUMBER' then
  begin
    // NUMBER without a scale (plain NUMBER / FLOAT-like) → float; scale 0 →
    // integer; scale > 0 → decimal. Mirrors the mapping produced by the
    // FireDAC Oracle path so generated models are consistent across drivers.
    if AScaleIsNull then
      LClass := TEFFloatDataType
    else if AScale <= 0 then
      LClass := TEFIntegerDataType
    else
      LClass := TEFDecimalDataType;
  end
  else if (LType = 'FLOAT') or (LType = 'BINARY_FLOAT') or (LType = 'BINARY_DOUBLE') then
    LClass := TEFFloatDataType
  else if (LType = 'DATE') or StartsText('TIMESTAMP', LType) then
    // Faithful to the FireDAC Oracle mapping (date/timestamp → Date).
    LClass := TEFDateDataType
  else if (LType = 'CLOB') or (LType = 'NCLOB') or (LType = 'LONG') then
    LClass := TEFMemoDataType
  else if (LType = 'BLOB') or (LType = 'BFILE') or (LType = 'RAW') or
          (LType = 'LONG RAW') then
    LClass := TEFBlobDataType
  else
    LClass := TEFStringDataType;
  Result := TEFDataTypeFactory.Instance.GetDataType(LClass);
end;

procedure TEFDBODACInfo.FetchTables(const ASchema: TEFDBSchemaInfo);
var
  LQuery: TOraQuery;
  LTable: TEFDBTableInfo;
  LIsTable: Boolean;
  LSQL: string;
begin
  LSQL :=
    'SELECT OBJECT_NAME, OBJECT_TYPE FROM USER_OBJECTS ' +
    'WHERE OBJECT_TYPE = ''TABLE''';
  if ViewsAsTables then
    LSQL := LSQL + ' OR OBJECT_TYPE = ''VIEW''';
  LSQL := LSQL + ' AND OBJECT_NAME NOT LIKE ''BIN$%'' ORDER BY OBJECT_TYPE, OBJECT_NAME';

  LQuery := CreateQuery;
  try
    LQuery.SQL.Text := LSQL;
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LIsTable := SameText(LQuery.FieldByName('OBJECT_TYPE').AsString, 'TABLE');
      LTable := TEFDBTableInfo.Create;
      try
        LTable.Name := LQuery.FieldByName('OBJECT_NAME').AsString;
        FetchTableColumns(LTable);
        if LIsTable then
        begin
          FetchTablePrimaryKey(LTable);
          FetchTableForeignKeys(LTable);
        end;
        ASchema.AddTable(LTable);
      except
        FreeAndNil(LTable);
      end;
      LQuery.Next;
    end;
    LQuery.Close;
  finally
    LQuery.Free;
  end;
end;

procedure TEFDBODACInfo.FetchTableColumns(const ATable: TEFDBTableInfo);
var
  LQuery: TOraQuery;
  LColumn: TEFDBColumnInfo;
  LScaleField: TField;
  LDataType: string;
  LPrecision, LScale: Integer;
begin
  LQuery := CreateQuery;
  try
    LQuery.SQL.Text :=
      'SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH, DATA_PRECISION, ' +
      '       DATA_SCALE, NULLABLE, CHAR_LENGTH ' +
      'FROM USER_TAB_COLUMNS ' +
      'WHERE TABLE_NAME = ' + QuotedStr(ATable.Name) + ' ' +
      'ORDER BY COLUMN_ID';
    LQuery.Open;
    while not LQuery.Eof do
    begin
      LColumn := TEFDBColumnInfo.Create;
      try
        LDataType := LQuery.FieldByName('DATA_TYPE').AsString;
        LPrecision := LQuery.FieldByName('DATA_PRECISION').AsInteger;
        LScaleField := LQuery.FieldByName('DATA_SCALE');
        LScale := LScaleField.AsInteger;
        LColumn.Name := LQuery.FieldByName('COLUMN_NAME').AsString;
        LColumn.DataType := OracleDataTypeToEFDataType(LDataType, LPrecision,
          LScale, LScaleField.IsNull);
        // Size: character length for string types, precision for NUMBER.
        if SameText(Trim(LDataType), 'NUMBER') then
          LColumn.Size := LPrecision
        else
        begin
          LColumn.Size := LQuery.FieldByName('CHAR_LENGTH').AsInteger;
          if LColumn.Size = 0 then
            LColumn.Size := LQuery.FieldByName('DATA_LENGTH').AsInteger;
        end;
        LColumn.Scale := LScale;
        LColumn.IsRequired := SameText(LQuery.FieldByName('NULLABLE').AsString, 'N');
        ATable.AddColumn(LColumn);
      except
        FreeAndNil(LColumn);
      end;
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
  // Column comments (USER_COL_COMMENTS) → TEFDBColumnInfo.Description, so they
  // propagate to Metadata.DisplayLabel when a model is generated by the KIDEX
  // wizard or by the MCP tool models_create_from_db.
  FetchTableColumnDescriptions(ATable);
end;

procedure TEFDBODACInfo.FetchTableColumnDescriptions(const ATable: TEFDBTableInfo);
var
  LQuery: TOraQuery;
  LColumn: TEFDBColumnInfo;
  LColumnName, LDescription: string;
begin
  LQuery := CreateQuery;
  try
    LQuery.SQL.Text :=
      'SELECT COLUMN_NAME, COMMENTS FROM USER_COL_COMMENTS ' +
      'WHERE TABLE_NAME = ' + QuotedStr(ATable.Name) + ' ' +
      '  AND COMMENTS IS NOT NULL';
    try
      LQuery.Open;
    except
      // A failing comment query must not break model creation.
      Exit;
    end;
    while not LQuery.Eof do
    begin
      LColumnName := LQuery.FieldByName('COLUMN_NAME').AsString.Trim;
      LDescription := LQuery.FieldByName('COMMENTS').AsString;
      if (LColumnName <> '') and (LDescription <> '') then
      begin
        LColumn := ATable.FindColumn(LColumnName);
        if Assigned(LColumn) then
          LColumn.Description := LDescription;
      end;
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TEFDBODACInfo.FetchTablePrimaryKey(const ATable: TEFDBTableInfo);
var
  LQuery: TOraQuery;
begin
  LQuery := CreateQuery;
  try
    LQuery.SQL.Text :=
      'SELECT c.CONSTRAINT_NAME, cc.COLUMN_NAME ' +
      'FROM USER_CONSTRAINTS c ' +
      '  JOIN USER_CONS_COLUMNS cc ON cc.CONSTRAINT_NAME = c.CONSTRAINT_NAME ' +
      'WHERE c.CONSTRAINT_TYPE = ''P'' ' +
      '  AND c.TABLE_NAME = ' + QuotedStr(ATable.Name) + ' ' +
      'ORDER BY cc.POSITION';
    LQuery.Open;
    while not LQuery.Eof do
    begin
      if ATable.PrimaryKey.Name = '' then
        ATable.PrimaryKey.Name := LQuery.FieldByName('CONSTRAINT_NAME').AsString;
      ATable.PrimaryKey.ColumnNames.Add(LQuery.FieldByName('COLUMN_NAME').AsString);
      LQuery.Next;
    end;
  finally
    LQuery.Free;
  end;
end;

procedure TEFDBODACInfo.FetchTableForeignKeys(const ATable: TEFDBTableInfo);
var
  LQuery: TOraQuery;
  LForeignKey: TEFDBForeignKeyInfo;
  LForeignKeyName: string;
begin
  LQuery := CreateQuery;
  try
    LQuery.SQL.Text :=
      'SELECT c.CONSTRAINT_NAME AS FK_NAME, ' +
      '       cc.COLUMN_NAME AS FK_COLUMN, ' +
      '       rc.TABLE_NAME AS REF_TABLE, ' +
      '       rcc.COLUMN_NAME AS REF_COLUMN ' +
      'FROM USER_CONSTRAINTS c ' +
      '  JOIN USER_CONS_COLUMNS cc ON cc.CONSTRAINT_NAME = c.CONSTRAINT_NAME ' +
      '  JOIN USER_CONSTRAINTS rc ON rc.CONSTRAINT_NAME = c.R_CONSTRAINT_NAME ' +
      '  JOIN USER_CONS_COLUMNS rcc ON rcc.CONSTRAINT_NAME = rc.CONSTRAINT_NAME ' +
      '    AND rcc.POSITION = cc.POSITION ' +
      'WHERE c.CONSTRAINT_TYPE = ''R'' ' +
      '  AND c.TABLE_NAME = ' + QuotedStr(ATable.Name) + ' ' +
      'ORDER BY c.CONSTRAINT_NAME, cc.POSITION';
    LQuery.Open;
    try
      while not LQuery.Eof do
      begin
        LForeignKeyName := LQuery.FieldByName('FK_NAME').AsString;
        LForeignKey := ATable.FindForeignKey(LForeignKeyName);
        if not Assigned(LForeignKey) then
        begin
          LForeignKey := TEFDBForeignKeyInfo.Create;
          LForeignKey.Name := LForeignKeyName;
          ATable.AddForeignKey(LForeignKey);
        end;
        LForeignKey.ForeignTableName := LQuery.FieldByName('REF_TABLE').AsString;
        LForeignKey.ColumnNames.Add(LQuery.FieldByName('FK_COLUMN').AsString);
        LForeignKey.ForeignColumnNames.Add(LQuery.FieldByName('REF_COLUMN').AsString);
        LQuery.Next;
      end;
    except
      // Leave whatever was collected; a metadata read must not be fatal.
    end;
  finally
    LQuery.Free;
  end;
end;

{ TEFDBODACAdapter }

function TEFDBODACAdapter.InternalCreateDBConnection: TEFDBConnection;
begin
  Result := TEFDBODACConnection.Create;
end;

class function TEFDBODACAdapter.InternalGetClassId: string;
begin
  Result := 'ODAC';
end;

function TEFDBODACAdapter.GetConnectionConfig: TEFDBODACConnectionConfig;
begin
  Result := nil; // RTTI discovery only
end;

initialization
  TEFDBAdapterRegistry.Instance.RegisterDBAdapter(TEFDBODACAdapter.GetClassId, TEFDBODACAdapter.Create);

finalization
  TEFDBAdapterRegistry.Instance.UnregisterDBAdapter(TEFDBODACAdapter.GetClassId);

end.
