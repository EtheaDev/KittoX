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
///  Integration tests: these talk to the servers configured in
///  Data\TestDatabases.yaml. Each test creates its own table and drops it
///  again, so a run leaves nothing behind -- on Oracle that takes an explicit
///  PURGE, see DropStatement.
///
///  A backend turned off in that file, or not answering, makes the test pass
///  with a SKIPPED message instead of failing - see Kitto.TestDB.
/// </summary>
unit EF.DBIntegrationTests;

interface

uses
  DUnitX.TestFramework,
  EF.DB;

type
  [TestFixture]
  TEFDBIntegrationTests = class
  strict private
    const TABLE_NAME = 'kx_test_types';
    // A parent with a two-column primary key and a child referencing it, so
    // the foreign key read back is composite: a single-column one would not
    // exercise the column ordering at all.
    PARENT_TABLE_NAME = 'kx_test_parent';
    CHILD_TABLE_NAME = 'kx_test_child';
    FOREIGN_KEY_NAME = 'fk_kx_test_child';
    /// <summary>Opens the connection, or calls Assert.Pass with a SKIPPED
    /// message and returns nil when the backend is not available.</summary>
    function OpenOrSkip(const ADatabaseName: string): TEFDBConnection;
    procedure DropTestTable(const AConnection: TEFDBConnection);
    procedure CreateTestTable(const AConnection: TEFDBConnection;
      const ADatabaseName: string);
    procedure Execute(const AConnection: TEFDBConnection; const ASQL: string);
    /// <summary>The statement that drops ATableName and leaves nothing behind.
    /// On Oracle a plain DROP TABLE moves the table into the recycle bin, where
    /// it stays: without PURGE every run of the suite added a handful of BIN$
    /// entries to USER_RECYCLEBIN (measured: 102 to 110 in a single run).
    /// </summary>
    function DropStatement(const AConnection: TEFDBConnection;
      const ATableName: string): string;
    /// <summary>The from clause a bare 'select 1' needs on this backend, empty
    /// where a select without a from is allowed. Oracle and Firebird require
    /// one.</summary>
    function DummyFromClause(const AConnection: TEFDBConnection): string;
    /// <summary>Drops the child and then the parent table, in that order.</summary>
    procedure DropRelatedTestTables(const AConnection: TEFDBConnection);
    /// <summary>Creates the parent and child tables with a composite foreign
    /// key between them.</summary>
    procedure CreateRelatedTestTables(const AConnection: TEFDBConnection;
      const ADatabaseName: string);
  public
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    procedure Connection_Opens(const ADatabaseName: string);

    /// <summary>
    ///  KNOWN DEFECT on FireDAC (review 4.1, finding 3). A parameter left null
    ///  is written as 0 / '' / an empty blob, because only ftDateTime, ftDate
    ///  and ftUnknown check IsNull before reading the value. A Currency field
    ///  the user left empty lands as 0, a nullable string as '' - and '' is not
    ///  NULL, so IS NULL filters and required-field checks stop working.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    procedure NullValues_SurviveARoundTrip(const ADatabaseName: string);

    /// <summary>
    ///  The statement built by AddLimitClause has to be accepted by the server,
    ///  not just look right: this is the end-to-end counterpart of the tests in
    ///  EF.DBTests, and the one that would have caught ORA-00933.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    procedure SelectWithFilterAndOrderBy_Executes(const ADatabaseName: string);

    /// <summary>
    ///  A rollback asked for at a nested level must not be overridden by the
    ///  outer commit. Nesting is emulated by a counter - there are no
    ///  savepoints - and a nested rollback used to do exactly what a nested
    ///  commit did, decrement it: the outer commit then confirmed work an inner
    ///  level had rejected, with no error at all. The visible outcome was a
    ///  record refused by a business rule sitting in the table.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    procedure NestedRollback_PreventsOuterCommit(const ADatabaseName: string);

    /// <summary>
    ///  Reads the schema back through the same path the framework uses when it
    ///  builds models, and checks the composite foreign key: its name, the
    ///  table it references, and both column lists in the right order.
    ///
    ///  This is the successful path of FetchTableForeignKeys, and the reason to
    ///  run it on real drivers is finding 17: that method used to have an
    ///  exception handler which freed a foreign key already owned by its table,
    ///  leaving a dangling entry that the table freed a second time. The test
    ///  covers the removal of that handler from two sides -- the foreign keys
    ///  are still read correctly, and the whole schema is then destroyed, which
    ///  is where a dangling entry turns into an access violation.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    procedure ForeignKeys_AreFetchedWithTheirColumnsInOrder(const ADatabaseName: string);

    /// <summary>
    ///  Finding 17, on the failing path. FetchTableForeignKeys used to end with
    ///  'except FreeAndNil(LForeignKey); raise; end', but by then the foreign
    ///  key belongs to the table -- AddForeignKey is called right after the
    ///  Create -- so the handler left a dangling entry in the table's list and
    ///  the table freed the same object again.
    ///
    ///  The fault is injected by overriding FetchTableForeignKeysColumns, which
    ///  the fetch calls once per foreign key from inside its loop -- and the
    ///  loop is the only way into that handler. Nothing about the injection
    ///  depends on a consistency check or on assertions being on, so it means
    ///  the same thing in Debug and in Release.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    procedure ForeignKeyFetch_ThatFails_LeavesTheTableOwningItsForeignKeys(
      const ADatabaseName: string);

    /// <summary>
    ///  A query has to come out of CreateDBQuery already on its own physical
    ///  connection out of the pool, not on the one the parent wrapper shares.
    ///
    ///  CreateDBQuery assigned the connection and only then opened it, and the
    ///  query picks its physical connection at the moment it is given one: with
    ///  the wrapper still closed, PoolDefName was empty and the choice fell on
    ///  the shared TFDConnection. Every first query of every connection was
    ///  built that way. TEFDBFDQuery.Open decides again and repairs it before
    ///  anything executes -- that is the fix for finding 6 -- so nothing
    ///  reaches the server on the wrong connection today; but a query is not
    ///  supposed to spend part of its life bound to a connection its own class
    ///  spends effort keeping it off, and the repair is the only thing standing
    ///  between that state and the sibling-dataset problem the Microsoft ODBC
    ///  driver has.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    procedure CreateDBQuery_GivesTheQueryItsOwnConnection(const ADatabaseName: string);

    /// <summary>
    ///  FetchSequenceGeneratorValue draws from a real sequence, on every
    ///  backend: the statement comes from the dialect, and before it did the
    ///  FireDAC adapter returned 0 without asking the database at all. Two
    ///  draws must give two different, increasing values.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    procedure Sequence_GivesIncreasingValues(const ADatabaseName: string);

    /// <summary>
    ///  The sequence name is spliced into the statement, so anything that is
    ///  not a plain (dotted) identifier is refused before reaching the server.
    /// </summary>
    [Test]
    [TestCase('Oracle', 'Oracle')]
    procedure Sequence_WithMalformedName_IsRefused(const ADatabaseName: string);
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  FireDAC.Comp.Client,
  EF.Types,
  EF.DB.FD,
  // For TCountingForeignKeyInfo: a foreign key that counts how many times it is
  // destroyed without ever releasing its memory, so a second free is countable
  // instead of being undefined behaviour.
  EF.DBTests,
  Kitto.TestDB;

type
  /// <summary>
  ///  Exposes the protected foreign-key fetch of TEFDBFDInfo, so that a test
  ///  can run it against one table of its own making instead of going through
  ///  a whole-schema fetch, and injects a failure in the middle of it by
  ///  overriding the per-column read that the fetch calls once per foreign key.
  ///  That read is the only place inside the loop a test can reach, and the
  ///  loop is the only way into the exception path under test.
  /// </summary>
  TEFDBFDInfoProbe = class(TEFDBFDInfo)
  protected
    procedure FetchTableForeignKeysColumns(const ATable: TEFDBTableInfo;
      const AForeignKeyName: string;
      const ColumnNames, ReferencedColumnNames: TStrings); override;
  public
    /// <summary>When set, FetchTableForeignKeysColumns raises instead of
    /// reading anything.</summary>
    FailOnColumns: Boolean;
    /// <summary>Reads the foreign keys of ATable, whose Name must be a table
    /// that exists on the connection.</summary>
    procedure FetchForeignKeysOf(const ATable: TEFDBTableInfo);
  end;

{ TEFDBFDInfoProbe }

procedure TEFDBFDInfoProbe.FetchForeignKeysOf(const ATable: TEFDBTableInfo);
begin
  FetchTableForeignKeys(ATable);
end;

procedure TEFDBFDInfoProbe.FetchTableForeignKeysColumns(
  const ATable: TEFDBTableInfo; const AForeignKeyName: string;
  const ColumnNames, ReferencedColumnNames: TStrings);
begin
  if FailOnColumns then
    raise EEFDBError.Create('Injected failure while reading the columns of ' +
      AForeignKeyName + '.');
  inherited;
end;

{ TEFDBIntegrationTests }

function TEFDBIntegrationTests.OpenOrSkip(const ADatabaseName: string): TEFDBConnection;
var
  LWhyNot: string;
begin
  Result := TKTestDB.TryOpenConnection(ADatabaseName, LWhyNot);
  if Result = nil then
  begin
    if LWhyNot = '' then
      LWhyNot := Format('%s is not declared in TestDatabases.yaml.', [ADatabaseName]);
    Assert.Pass('SKIPPED: ' + LWhyNot);
  end;
end;

procedure TEFDBIntegrationTests.Execute(const AConnection: TEFDBConnection;
  const ASQL: string);
var
  LCommand: TEFDBCommand;
begin
  LCommand := AConnection.CreateDBCommand;
  try
    LCommand.CommandText := ASQL;
    LCommand.Execute;
  finally
    LCommand.Free;
  end;
end;

function TEFDBIntegrationTests.DummyFromClause(const AConnection: TEFDBConnection): string;
begin
  if AConnection.DBEngineType is TEFOracleDBEngineType then
    Result := 'from dual'
  else if AConnection.DBEngineType is TEFFirebirdDBEngineType then
    Result := 'from rdb$database'
  else
    Result := '';
end;

function TEFDBIntegrationTests.DropStatement(const AConnection: TEFDBConnection;
  const ATableName: string): string;
begin
  Result := 'drop table ' + ATableName;
  if AConnection.DBEngineType is TEFOracleDBEngineType then
    Result := Result + ' purge';
end;

procedure TEFDBIntegrationTests.DropTestTable(const AConnection: TEFDBConnection);
begin
  // The table may well not be there: a failed run is not a reason to fail the
  // next one.
  try
    AConnection.StartTransaction;
    try
      Execute(AConnection, DropStatement(AConnection, TABLE_NAME));
      AConnection.CommitTransaction;
    except
      AConnection.RollbackTransaction;
      raise;
    end;
  except
    // Swallowing the error is not enough. On PostgreSQL and Firebird a failed
    // statement leaves the transaction unusable, so every statement after it
    // fails too - which is how a missing table turned into "relation
    // kx_test_types does not exist" on the CREATE that followed. Reopening the
    // connection is the one recovery that behaves the same on every backend.
    try
      AConnection.Close;
      AConnection.Open;
    except
      // Nothing else to try: the test that follows will report the real state.
    end;
  end;
end;

procedure TEFDBIntegrationTests.CreateTestTable(const AConnection: TEFDBConnection;
  const ADatabaseName: string);
var
  LSQL: string;
begin
  // Unquoted lowercase identifiers: PostgreSQL keeps them as they are, the
  // others fold them to their own case, so the same statements work everywhere.
  if SameText(ADatabaseName, 'MSSQL') then
    LSQL := 'create table ' + TABLE_NAME + ' (' +
      'id int not null primary key, str_value varchar(50) null, ' +
      'cur_value money null, int_value int null)'
  else if SameText(ADatabaseName, 'Oracle') then
    LSQL := 'create table ' + TABLE_NAME + ' (' +
      'id number(10) not null primary key, str_value varchar2(50), ' +
      'cur_value number(18,4), int_value number(10))'
  else // Firebird, PostgreSQL: standard enough to share
    LSQL := 'create table ' + TABLE_NAME + ' (' +
      'id integer not null primary key, str_value varchar(50), ' +
      'cur_value numeric(18,4), int_value integer)';

  // PostgreSQL and Firebird run DDL inside a transaction: without an explicit
  // commit the table exists only for the transaction that created it, and
  // every statement that follows reports it as missing.
  AConnection.StartTransaction;
  try
    Execute(AConnection, LSQL);
    AConnection.CommitTransaction;
  except
    AConnection.RollbackTransaction;
    raise;
  end;
end;

procedure TEFDBIntegrationTests.DropRelatedTestTables(const AConnection: TEFDBConnection);
var
  LTableName: string;
begin
  // Child first: the foreign key keeps the parent from being dropped. Each drop
  // gets its own transaction and its own recovery, for the reason spelled out
  // in DropTestTable.
  for LTableName in [CHILD_TABLE_NAME, PARENT_TABLE_NAME] do
  begin
    try
      AConnection.StartTransaction;
      try
        Execute(AConnection, DropStatement(AConnection, LTableName));
        AConnection.CommitTransaction;
      except
        AConnection.RollbackTransaction;
        raise;
      end;
    except
      try
        AConnection.Close;
        AConnection.Open;
      except
        // Nothing else to try: the test that follows will report the real state.
      end;
    end;
  end;
end;

procedure TEFDBIntegrationTests.CreateRelatedTestTables(
  const AConnection: TEFDBConnection; const ADatabaseName: string);
var
  LIntType: string;
begin
  // Unquoted lowercase identifiers, as in CreateTestTable: every backend folds
  // them to its own case, and the assertions below compare case-insensitively.
  if SameText(ADatabaseName, 'MSSQL') then
    LIntType := 'int'
  else if SameText(ADatabaseName, 'Oracle') then
    LIntType := 'number(10)'
  else
    LIntType := 'integer';

  AConnection.StartTransaction;
  try
    Execute(AConnection,
      'create table ' + PARENT_TABLE_NAME + ' (' +
      'k1 ' + LIntType + ' not null, k2 ' + LIntType + ' not null, ' +
      'constraint pk_' + PARENT_TABLE_NAME + ' primary key (k1, k2))');
    Execute(AConnection,
      'create table ' + CHILD_TABLE_NAME + ' (' +
      'id ' + LIntType + ' not null primary key, ' +
      'p_k1 ' + LIntType + ', p_k2 ' + LIntType + ', ' +
      'constraint ' + FOREIGN_KEY_NAME + ' foreign key (p_k1, p_k2) ' +
      'references ' + PARENT_TABLE_NAME + ' (k1, k2))');
    AConnection.CommitTransaction;
  except
    AConnection.RollbackTransaction;
    raise;
  end;
end;

procedure TEFDBIntegrationTests.Connection_Opens(const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    Assert.IsTrue(LConnection.IsOpen, ADatabaseName + ': the connection is not open.');
  finally
    LConnection.Free;
  end;
end;

procedure TEFDBIntegrationTests.NullValues_SurviveARoundTrip(const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
  LCommand: TEFDBCommand;
  LQuery: TEFDBQuery;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    DropTestTable(LConnection);
    CreateTestTable(LConnection, ADatabaseName);
    try
      LCommand := LConnection.CreateDBCommand;
      try
        LCommand.CommandText := 'insert into ' + TABLE_NAME +
          ' (id, str_value, cur_value, int_value) values (:id, :str_value, :cur_value, :int_value)';
        LCommand.Params.ParamByName('id').AsInteger := 1;
        // Null of a definite type, which is what TEFDataType.NodeToParam does
        // for a node with no value.
        LCommand.Params.ParamByName('str_value').DataType := ftString;
        LCommand.Params.ParamByName('str_value').Clear;
        LCommand.Params.ParamByName('cur_value').DataType := ftCurrency;
        LCommand.Params.ParamByName('cur_value').Clear;
        LCommand.Params.ParamByName('int_value').DataType := ftInteger;
        LCommand.Params.ParamByName('int_value').Clear;
        LCommand.Execute;
      finally
        LCommand.Free;
      end;

      LQuery := LConnection.CreateDBQuery;
      try
        LQuery.CommandText := 'select str_value, cur_value, int_value from ' +
          TABLE_NAME + ' where id = 1';
        // Read inside a transaction: on the MVCC backends a pooled connection
        // can be sitting on an older snapshot and would not see a table created
        // a moment ago. In a transaction the query runs on the connection that
        // created it.
        LConnection.StartTransaction;
        try
          LQuery.Open;
          LConnection.CommitTransaction;
        except
          LConnection.RollbackTransaction;
          raise;
        end;
        Assert.IsFalse(LQuery.DataSet.Eof, ADatabaseName + ': the row was not inserted.');
        Assert.IsTrue(LQuery.DataSet.FieldByName('str_value').IsNull,
          ADatabaseName + ': a null string was stored as '''' instead of NULL.');
        Assert.IsTrue(LQuery.DataSet.FieldByName('cur_value').IsNull,
          ADatabaseName + ': a null currency was stored as 0 instead of NULL.');
        Assert.IsTrue(LQuery.DataSet.FieldByName('int_value').IsNull,
          ADatabaseName + ': a null integer was stored as 0 instead of NULL.');
        LQuery.Close;
      finally
        LQuery.Free;
      end;
    finally
      DropTestTable(LConnection);
    end;
  finally
    LConnection.Free;
  end;
end;

procedure TEFDBIntegrationTests.SelectWithFilterAndOrderBy_Executes(
  const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
  LQuery: TEFDBQuery;
  LSQL: string;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    DropTestTable(LConnection);
    CreateTestTable(LConnection, ADatabaseName);
    try
      Execute(LConnection, 'insert into ' + TABLE_NAME +
        ' (id, str_value, int_value) values (1, ''a'', 10)');
      Execute(LConnection, 'insert into ' + TABLE_NAME +
        ' (id, str_value, int_value) values (2, ''b'', 20)');

      // Assembled the way TKSQLBuilder does it: where clause with a leading
      // space, order by clause without one.
      LSQL := LConnection.DBEngineType.AddLimitClause(
        'select id, str_value',
        'from ' + TABLE_NAME,
        ' where (int_value > 5)',
        'order by id',
        0, 0);

      LQuery := LConnection.CreateDBQuery;
      try
        LQuery.CommandText := LSQL;
        // In a transaction, for the same reason as in the test above.
        LConnection.StartTransaction;
        try
          LQuery.Open;   // the server is the judge here
          LConnection.CommitTransaction;
        except
          LConnection.RollbackTransaction;
          raise;
        end;
        Assert.AreEqual(1, LQuery.DataSet.FieldByName('id').AsInteger,
          ADatabaseName + ': wrong first row, the ordering did not apply.');
        LQuery.Close;
      finally
        LQuery.Free;
      end;
    finally
      DropTestTable(LConnection);
    end;
  finally
    LConnection.Free;
  end;
end;

procedure TEFDBIntegrationTests.NestedRollback_PreventsOuterCommit(
  const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
  LQuery: TEFDBQuery;
  LCommitRaised: Boolean;
  LRowCount: Integer;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    DropTestTable(LConnection);
    CreateTestTable(LConnection, ADatabaseName);
    try
      LCommitRaised := False;

      LConnection.StartTransaction;          // outer, as a tool would open it
      try
        Execute(LConnection, 'insert into ' + TABLE_NAME +
          ' (id, str_value) values (1, ''rejected'')');

        LConnection.StartTransaction;        // inner, as TKRecord.Save does
        // ...the inner level rejects its work.
        LConnection.RollbackTransaction;

        // The caller catches the failure and carries on - Kitto.DbUtils does
        // exactly this - and commits. That must not confirm the insert.
        try
          LConnection.CommitTransaction;
        except
          on E: Exception do
            LCommitRaised := True;
        end;
      except
        // Any other failure: make sure nothing is left open.
        if LConnection.IsInTransaction then
          LConnection.RollbackTransaction;
        raise;
      end;

      Assert.IsTrue(LCommitRaised,
        ADatabaseName + ': committing after a nested rollback should not be ' +
        'allowed to pass silently.');

      LQuery := LConnection.CreateDBQuery;
      try
        LQuery.CommandText := 'select count(*) as N from ' + TABLE_NAME;
        LConnection.StartTransaction;
        try
          LQuery.Open;
          LRowCount := LQuery.DataSet.Fields[0].AsInteger;
          LConnection.CommitTransaction;
        except
          LConnection.RollbackTransaction;
          raise;
        end;
        Assert.AreEqual(0, LRowCount,
          ADatabaseName + ': the row rejected at the inner level was committed anyway.');
      finally
        LQuery.Free;
      end;
    finally
      DropTestTable(LConnection);
    end;
  finally
    LConnection.Free;
  end;
end;

procedure TEFDBIntegrationTests.ForeignKeys_AreFetchedWithTheirColumnsInOrder(
  const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
  LDBInfo: TEFDBInfo;
  LChildTable: TEFDBTableInfo;
  LForeignKey: TEFDBForeignKeyInfo;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    DropRelatedTestTables(LConnection);
    CreateRelatedTestTables(LConnection, ADatabaseName);
    try
      LDBInfo := LConnection.CreateDBInfo;
      try
        // Reading Schema fetches the whole thing, foreign keys included -- the
        // same call the metadata catalog makes.
        LChildTable := LDBInfo.Schema.FindTable(CHILD_TABLE_NAME);
        Assert.IsNotNull(LChildTable,
          ADatabaseName + ': the child table was not read back from the schema.');
        Assert.AreEqual(1, LChildTable.ForeignKeyCount,
          ADatabaseName + ': the child table should have exactly one foreign key.');

        LForeignKey := LChildTable.ForeignKeys[0];
        Assert.IsTrue(SameText(FOREIGN_KEY_NAME, LForeignKey.Name),
          ADatabaseName + ': unexpected foreign key name ' + LForeignKey.Name);
        Assert.IsTrue(SameText(PARENT_TABLE_NAME, LForeignKey.ForeignTableName),
          ADatabaseName + ': unexpected referenced table ' + LForeignKey.ForeignTableName);

        Assert.AreEqual(2, LForeignKey.ColumnCount,
          ADatabaseName + ': the foreign key should have two columns.');
        // Order matters: master and detail are coupled by position, so a
        // reversed pair would read another master's rows.
        Assert.IsTrue(SameText('p_k1', LForeignKey.ColumnNames[0]),
          ADatabaseName + ': first column is ' + LForeignKey.ColumnNames[0]);
        Assert.IsTrue(SameText('p_k2', LForeignKey.ColumnNames[1]),
          ADatabaseName + ': second column is ' + LForeignKey.ColumnNames[1]);
        Assert.AreEqual(2, LForeignKey.ForeignColumnNames.Count,
          ADatabaseName + ': the foreign key should reference two columns.');
        Assert.IsTrue(SameText('k1', LForeignKey.ForeignColumnNames[0]),
          ADatabaseName + ': first referenced column is ' + LForeignKey.ForeignColumnNames[0]);
        Assert.IsTrue(SameText('k2', LForeignKey.ForeignColumnNames[1]),
          ADatabaseName + ': second referenced column is ' + LForeignKey.ForeignColumnNames[1]);
      finally
        // Destroying the schema frees every foreign key it holds: this is the
        // half of the test that a dangling entry would fail.
        LDBInfo.Free;
      end;
    finally
      DropRelatedTestTables(LConnection);
    end;
  finally
    LConnection.Free;
  end;
end;

procedure TEFDBIntegrationTests.ForeignKeyFetch_ThatFails_LeavesTheTableOwningItsForeignKeys(
  const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
  LProbe: TEFDBFDInfoProbe;
  LChildTable: TEFDBTableInfo;
  LForeignKey: TCountingForeignKeyInfo;
  LRaised: Boolean;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    DropRelatedTestTables(LConnection);
    CreateRelatedTestTables(LConnection, ADatabaseName);
    try
      TCountingForeignKeyInfo.ResetDestroyCount;
      LChildTable := TEFDBTableInfo.Create;
      try
        LChildTable.Name := CHILD_TABLE_NAME;
        // Already the table's, exactly as it is when FindForeignKey hands it
        // back on a foreign key read in an earlier round.
        LForeignKey := TCountingForeignKeyInfo.Create;
        LForeignKey.Name := FOREIGN_KEY_NAME;
        LChildTable.AddForeignKey(LForeignKey);

        LProbe := TEFDBFDInfoProbe.Create(TFDConnection(LConnection.GetConnection));
        try
          LProbe.FailOnColumns := True;
          LRaised := False;
          try
            LProbe.FetchForeignKeysOf(LChildTable);
          except
            LRaised := True;
          end;
          Assert.IsTrue(LRaised, ADatabaseName +
            ': the injected failure did not come out of the fetch. Was the ' +
            'foreign key found at all?');
        finally
          LProbe.Free;
        end;

        Assert.AreEqual(0, TCountingForeignKeyInfo.DestroyCount, ADatabaseName +
          ': the failed fetch freed a foreign key that belongs to the table.');
        Assert.AreEqual(1, LChildTable.ForeignKeyCount, ADatabaseName +
          ': the foreign key is no longer in the table''s list.');
      finally
        // The second free, if the first one happened, lands here.
        LChildTable.Free;
      end;
      Assert.AreEqual(1, TCountingForeignKeyInfo.DestroyCount, ADatabaseName +
        ': the foreign key was not freed exactly once, by its table.');
    finally
      DropRelatedTestTables(LConnection);
    end;
  finally
    LConnection.Free;
  end;
end;

procedure TEFDBIntegrationTests.CreateDBQuery_GivesTheQueryItsOwnConnection(
  const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
  LQuery: TEFDBQuery;
  LWhyNot: string;
begin
  // Reachability first, with the usual skip: the connection built below is
  // deliberately left closed, so it cannot report a server that is not there.
  LConnection := OpenOrSkip(ADatabaseName);
  LConnection.Free;

  LConnection := TKTestDB.CreateConnection(ADatabaseName, LWhyNot);
  Assert.IsNotNull(LConnection, LWhyNot);
  try
    Assert.IsFalse(LConnection.IsOpen,
      'The connection was expected to be closed at this point.');
    LQuery := LConnection.CreateDBQuery;
    try
      Assert.AreNotSame(LConnection.GetConnection,
        TObject(TFDQuery(LQuery.DataSet).Connection), ADatabaseName +
        ': the query was built on the connection its parent wrapper shares, ' +
        'instead of one of its own out of the pool.');
      // And it works: a private connection acquired at construction time is a
      // usable one.
      LQuery.CommandText := LConnection.DBEngineType.AddLimitClause(
        'select 1 as one', DummyFromClause(LConnection), '', '', 0, 0);
      LQuery.Open;
      Assert.IsFalse(LQuery.DataSet.IsEmpty, ADatabaseName +
        ': the query returned nothing on its own connection.');
    finally
      LQuery.Free;
    end;
  finally
    LConnection.Free;
  end;
end;

procedure TEFDBIntegrationTests.Sequence_GivesIncreasingValues(
  const ADatabaseName: string);
const
  SEQUENCE_NAME = 'kx_test_seq';

  procedure DropSequence(const AConnection: TEFDBConnection);
  begin
    // It may well not be there: a failed run is not a reason to fail the next.
    try
      AConnection.StartTransaction;
      try
        Execute(AConnection, 'drop sequence ' + SEQUENCE_NAME);
        AConnection.CommitTransaction;
      except
        AConnection.RollbackTransaction;
        raise;
      end;
    except
      // As in DropTestTable: on PostgreSQL and Firebird the failed statement
      // leaves the connection unusable, so reopen it.
      try
        AConnection.Close;
        AConnection.Open;
      except
        // The test that follows will report the real state.
      end;
    end;
  end;

var
  LConnection: TEFDBConnection;
  LFirst, LSecond: Int64;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    DropSequence(LConnection);
    LConnection.StartTransaction;
    try
      // START WITH 1 spelled out: on SQL Server a bare CREATE SEQUENCE starts
      // from the type's minimum, a large negative number.
      Execute(LConnection, 'create sequence ' + SEQUENCE_NAME +
        ' start with 1 increment by 1');
      LConnection.CommitTransaction;
    except
      LConnection.RollbackTransaction;
      raise;
    end;
    try
      LFirst := LConnection.FetchSequenceGeneratorValue(SEQUENCE_NAME);
      LSecond := LConnection.FetchSequenceGeneratorValue(SEQUENCE_NAME);
      Assert.IsTrue(LFirst > 0, Format('%s: first value %d, expected > 0 ' +
        '(0 is what the adapter returned when it did not ask).',
        [ADatabaseName, LFirst]));
      Assert.IsTrue(LSecond > LFirst, Format('%s: second value %d not greater ' +
        'than the first %d.', [ADatabaseName, LSecond, LFirst]));
    finally
      DropSequence(LConnection);
    end;
  finally
    LConnection.Free;
  end;
end;

procedure TEFDBIntegrationTests.Sequence_WithMalformedName_IsRefused(
  const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    Assert.WillRaise(
      procedure
      begin
        LConnection.FetchSequenceGeneratorValue('seq from dual; drop table x --');
      end, EEFError, 'A malformed name went through.');
    Assert.WillRaise(
      procedure
      begin
        LConnection.FetchSequenceGeneratorValue('schema..seq');
      end, EEFError, 'An empty name part went through.');
    Assert.WillRaise(
      procedure
      begin
        LConnection.FetchSequenceGeneratorValue('');
      end, EEFError, 'An empty name went through.');
  finally
    LConnection.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TEFDBIntegrationTests);

end.
