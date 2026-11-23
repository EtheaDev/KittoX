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
///  Tests for the SQL that the dialect classes assemble. No database is
///  involved: these check the statement text, which is where the defects that
///  break a whole back-end tend to live.
/// </summary>
unit EF.DBTests;

interface

uses
  DUnitX.TestFramework,
  Data.DB,
  EF.DB,
  EF.Tree,
  // TKModel: the fixture on the model side of a declared length hands one
  // back from its helper.
  Kitto.Metadata.Models;

type
  [TestFixture]
  TEFDBEngineTypeTests = class
  strict private
    const
      // Built the way TKSQLBuilder builds them: the where clause has a leading
      // space and no trailing one, the order by clause has neither.
      SELECT_CLAUSE = 'select ORDER_ID, ORDER_DATE';
      FROM_CLAUSE = 'from ORDERS';
      WHERE_CLAUSE = ' where (CUSTOMER_ID = :CUSTOMER_ID)';
      ORDER_BY_CLAUSE = 'order by ORDER_DATE';
  public
    /// <summary>
    ///  Regression. The where and the order by clauses used to be concatenated
    ///  with nothing between them, producing '...where (X)order by Y'. On
    ///  Oracle that is a syntax error on any view that has both a filter (a
    ///  DefaultFilter, a search, or just the foreign key of a detail table) and
    ///  an ordering; on the base dialect it happens as soon as the view is
    ///  paginated. It went unnoticed because with no filter the missing space
    ///  is supplied by the from clause.
    /// </summary>
    [Test]
    procedure BaseDialect_WithPaging_SeparatesWhereFromOrderBy;
    [Test]
    procedure BaseDialect_WithoutPaging_SeparatesWhereFromOrderBy;
    [Test]
    procedure OracleDialect_SeparatesWhereFromOrderBy;
    [Test]
    procedure OracleDialect_WithPaging_SeparatesWhereFromOrderBy;

    [Test]
    procedure BaseDialect_WithoutPaging_KeepsTheClausesInOrder;

    /// <summary>
    ///  The statement that draws a sequence value, per dialect. The base one is
    ///  the ANSI form, which SQL Server and MariaDB take as is.
    /// </summary>
    [Test]
    procedure SequenceSQL_PerDialect;
    /// <summary>
    ///  With DelimitedIdent on, every part of a schema-qualified name is
    ///  delimited; on PostgreSQL the delimited name goes inside the string
    ///  nextval() takes.
    /// </summary>
    [Test]
    procedure SequenceSQL_DelimitsEveryPartWhenAsked;
  end;

  /// <summary>
  ///  A DB adapter that counts how many times it is destroyed instead of
  ///  actually destroying itself. That is deliberate: the defect under test
  ///  frees the same adapter twice, and both the destructor body and the
  ///  release of the memory would then run on an instance that is already gone
  ///  -- the run above reported it as 'Invalid pointer operation', which aborts
  ///  the test instead of failing an assertion about how many times the adapter
  ///  was freed. Note that overriding Destroy without calling inherited is not
  ///  enough: the compiler-generated epilogue of the outermost destructor calls
  ///  FreeInstance regardless, so the memory has to be kept by overriding that.
  ///  The instance is leaked on purpose: a handful of bytes, a few per run.
  /// </summary>
  TCountingDBAdapter = class(TEFDBAdapter)
  strict private
    class var FDestroyCount: Integer;
  protected
    function InternalCreateDBConnection: TEFDBConnection; override;
  public
    destructor Destroy; override;
    procedure FreeInstance; override;
    /// <summary>Zeroes the counter, so each test starts from a known state.</summary>
    class procedure ResetDestroyCount;
    /// <summary>How many times an instance of this class has been destroyed
    /// since the last ResetDestroyCount.</summary>
    class property DestroyCount: Integer read FDestroyCount;
  end;

  /// <summary>
  ///  Tests for the ownership of the adapters the registry holds. The registry
  ///  is a process-wide singleton, but the class is a plain one: these tests
  ///  build their own instances and leave the singleton -- and the FireDAC
  ///  adapter registered in it -- alone.
  /// </summary>
  [TestFixture]
  TEFDBAdapterRegistryTests = class
  public
    /// <summary>
    ///  Regression. BeforeDestruction freed every registered adapter and then
    ///  called Clear on the dictionary, which owns them through its value
    ///  notification and freed each of them a second time. It stayed invisible
    ///  because every EF.DB.* unit unregisters its own adapter in its
    ///  finalization section, which runs first and leaves the dictionary empty;
    ///  an adapter registered by an application, with nothing requiring it to
    ///  unregister, reaches this point and is freed twice at shutdown.
    /// </summary>
    [Test]
    procedure Destruction_FreesEachRegisteredAdapterOnce;
    /// <summary>
    ///  The same with more than one adapter left registered: the loop covered
    ///  them all, so all of them were freed twice.
    /// </summary>
    [Test]
    procedure Destruction_WithSeveralAdapters_FreesEachOfThemOnce;
    /// <summary>
    ///  Unregistering must keep freeing the adapter -- it is the dictionary's
    ///  value notification that does it, and the fix above now relies on it
    ///  alone -- and must not free it again when the registry goes.
    /// </summary>
    [Test]
    procedure Unregister_FreesTheAdapterExactlyOnce;
  end;

  /// <summary>
  ///  A foreign key that counts how many times it is destroyed, kept alive the
  ///  same way TCountingDBAdapter is and for the same reason.
  /// </summary>
  TCountingForeignKeyInfo = class(TEFDBForeignKeyInfo)
  strict private
    class var FDestroyCount: Integer;
  public
    destructor Destroy; override;
    procedure FreeInstance; override;
    /// <summary>Zeroes the counter, so each test starts from a known state.</summary>
    class procedure ResetDestroyCount;
    /// <summary>How many times an instance of this class has been destroyed
    /// since the last ResetDestroyCount.</summary>
    class property DestroyCount: Integer read FDestroyCount;
  end;

  /// <summary>
  ///  Tests for who owns the sub-objects of a TEFDBTableInfo. What the metadata
  ///  fetchers in EF.DB.FD and EF.DB.ADO are allowed to do on their exception
  ///  paths follows from this, and getting it wrong there was finding 17.
  /// </summary>
  [TestFixture]
  TEFDBTableInfoTests = class
  public
    /// <summary>
    ///  AddForeignKey hands the foreign key over to the table: from that point
    ///  on the table frees it, exactly once.
    /// </summary>
    [Test]
    procedure AddForeignKey_TransfersOwnershipToTheTable;
    /// <summary>
    ///  FindForeignKey returns the very instance the table owns -- not a copy.
    ///  A caller that frees what it got back is freeing the table's object.
    /// </summary>
    [Test]
    procedure FindForeignKey_ReturnsTheInstanceTheTableOwns;
    /// <summary>
    ///  Regression, and the reason the exception handler in
    ///  FetchTableForeignKeys had to go rather than be narrowed. This
    ///  reproduces what that handler did -- free a foreign key that had already
    ///  been added -- and shows the table then freeing the same object again.
    ///  In the real code the second free happened inside the handler of
    ///  FetchTables, which frees the table: an access violation while cleaning
    ///  up after an unrelated error, surfacing as a model that fails to load.
    /// </summary>
    [Test]
    procedure FreeingAnAddedForeignKey_MakesTheTableFreeItTwice;
  end;

  /// <summary>
  ///  Tests for the Size/Scale contract of TEFDBColumnInfo, which its own
  ///  documentation has always stated: a size is what a string field has,
  ///  "for other data types, it's 0".
  ///
  ///  Regression. The rule used to live in one driver only -- two local
  ///  functions inside TEFDBDBXInfo.FetchTableColumns -- so the other
  ///  readers handed over what the engine reports, which for a LOB is its
  ///  capacity: a reverse-engineered model came out with Blob(2147483647),
  ///  Memo(1073741823) or Float(16), which the validator rejects. It now
  ///  sits in the class that owns both type and size, applied by all three
  ///  setters.
  /// </summary>
  [TestFixture]
  TEFDBColumnInfoTests = class
  public
    /// <summary>A type that admits no size drops one. The values are the
    /// ones SQL Server reports for those columns.</summary>
    [Test]
    [TestCase('Blob (image)', 'Blob,2147483647')]
    [TestCase('Memo (ntext)', 'Memo,1073741823')]
    [TestCase('Float (precision 16)', 'Float,16')]
    [TestCase('Boolean', 'Boolean,1')]
    [TestCase('Date', 'Date,3')]
    [TestCase('Integer', 'Integer,10')]
    [TestCase('Currency', 'Currency,19')]
    [TestCase('Time', 'Time,5')]
    [TestCase('DateTime', 'DateTime,23')]
    [TestCase('Object', 'Object,8')]
    procedure Size_OnATypeThatHasNone_IsDropped(const ATypeName: string;
      const ASize: Integer);
    /// <summary>...and one that does admit a size keeps it: without this the
    /// fix would be indistinguishable from zeroing everything.</summary>
    [Test]
    [TestCase('String', 'String,50')]
    [TestCase('Decimal', 'Decimal,12')]
    procedure Size_OnATypeThatHasOne_IsKept(const ATypeName: string;
      const ASize: Integer);
    /// <summary>A scale belongs to the types that declare one -- Decimal and
    /// Currency -- and is dropped everywhere else.</summary>
    [Test]
    [TestCase('String', 'String')]
    [TestCase('Memo', 'Memo')]
    [TestCase('Blob', 'Blob')]
    [TestCase('Date', 'Date')]
    [TestCase('Time', 'Time')]
    [TestCase('DateTime', 'DateTime')]
    [TestCase('Boolean', 'Boolean')]
    [TestCase('Integer', 'Integer')]
    [TestCase('Float', 'Float')]
    [TestCase('Object', 'Object')]
    procedure Scale_OnATypeThatHasNone_IsDropped(const ATypeName: string);
    [Test]
    procedure Scale_OnDecimal_IsKept;
    /// <summary>Currency is the one type that admits a scale and no size,
    /// so it is the only place where the two halves of the contract have to
    /// hold at once.</summary>
    [Test]
    procedure Scale_OnCurrency_IsKeptWhileTheSizeIsDropped;
    /// <summary>The drivers do not agree on an order -- FireDAC and ADO set
    /// the type first -- so the invariant cannot depend on one.</summary>
    [Test]
    procedure TheContract_HoldsWhicheverOrderTheDriverAssignsIn;
  end;


  /// <summary>
  ///  Introspection of column types, ON REAL SERVERS: the tests that say what
  ///  each backend answers when a Model is reverse-engineered from a table,
  ///  and which of those answers is a problem. They talk to the databases
  ///  declared in Data\TestDatabases.yaml; a backend turned off there, or not
  ///  answering, makes the test pass with a SKIPPED message rather than fail,
  ///  so the suite stays meaningful on a machine that has only some of them.
  ///  Read the SKIPPED lines of a run: a skip is counted as a pass.
  ///
  ///  ANALISI_R516.md, under "Che cosa resta aperto", lists what these tests
  ///  measure and why each reading is or is not a defect.
  /// </summary>
  [TestFixture]
  TEFDBIntrospectionTests = class
  strict private
    const LOB_TABLE_NAME = 'kx_test_lobs';
    MATRIX_TABLE_NAME = 'kx_test_matrix';
    /// <summary>Opens the connection, or calls Assert.Pass with a SKIPPED
    /// message and returns nil when the backend is not available.</summary>
    function OpenOrSkip(const ADatabaseName: string): TEFDBConnection;
    procedure Execute(const AConnection: TEFDBConnection; const ASQL: string);
    /// <summary>The statement that drops ATableName and leaves nothing behind.
    /// On Oracle a plain DROP TABLE moves the table into the recycle bin, where
    /// it stays, so that one needs PURGE.</summary>
    function DropStatement(const AConnection: TEFDBConnection;
      const ATableName: string): string;
    /// <summary>Drops the LOB table, leaving nothing behind.</summary>
    procedure DropLobTestTable(const AConnection: TEFDBConnection);
    /// <summary>Drops the type-matrix table, leaving nothing behind.</summary>
    procedure DropMatrixTestTable(const AConnection: TEFDBConnection);
    /// <summary>The create statement of the type-matrix table for this
    /// backend: one column per column shape the engine offers.</summary>
    function MatrixTableDDL(const AName: string): string;
    /// <summary>What each column of the matrix table has to be read back as,
    /// one entry per column as 'name|TypeName|size|scale'.</summary>
    function MatrixExpectations(const ADatabaseName: string): TArray<string>;
    /// <summary>One row for the matrix table with a value in each column whose
    /// reading is documented as wrong, spelled the way the engine wants it.</summary>
    function OddRowInsert(const ADatabaseName: string): string;
    /// <summary>What each of those values becomes once read through the EF
    /// type introspection assigned to its column, as 'column|Type|rendering'.
    /// Measured, one engine at a time.</summary>
    function OddRowExpectations(const ADatabaseName: string): TArray<string>;
    /// <summary>For some columns, a second EF type to read the same field
    /// through, as 'column>Type': what the value would be if introspection
    /// chose that type instead. Rendered as 'column>Type|rendering'.</summary>
    function AlternativeReadings(const ADatabaseName: string): TArray<string>;
    /// <summary>A locale-independent rendering of a node's value, by type.</summary>
    function RenderNode(const ADataType: TEFDataType; const ANode: TEFNode): string;
    /// <summary>Reads AField into a fresh node through ADataType and renders
    /// it; an exception becomes 'EXC ' plus its class.</summary>
    function ReadThrough(const ADataType: TEFDataType; const AField: TField): string;
    /// <summary>The columns of the matrix table whose read-back breaks one of
    /// the model-field rules on this backend, as measured. Each entry is
    /// 'column|whatTheReaderReturns|whichRule'.</summary>
    function KnownModelFieldViolations(const ADatabaseName: string): TArray<string>;
    /// <summary>The columns this connection reads back as DateTime or
    /// Currency, as measured. Empty on the FireDAC connections, which
    /// produce neither; ADO does. Each entry is 'column|reading'.</summary>
    function KnownDriverTypeSightings(const ADatabaseName: string): TArray<string>;
    /// <summary>Creates the LOB table: the same five column shapes on every
    /// backend, spelled the way each one spells them.</summary>
    procedure CreateLobTestTable(const AConnection: TEFDBConnection;
      const ADatabaseName: string);
    /// <summary>Asserts the EF data type name, size and scale of one column of
    /// the LOB table, naming the backend and the column in the message.</summary>
    procedure CheckColumn(const ATable: TEFDBTableInfo;
      const ADatabaseName, AColumnName, AExpectedTypeName: string;
      const AExpectedSize, AExpectedScale: Integer);
  public
    /// <summary>ADO is a COM library: without CoInitialize on the thread
    /// running the test its connection raises "CoInitialize has not been
    /// called". The other drivers do not care, and a redundant pair costs
    /// nothing.</summary>
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    /// <summary>
    ///  Reads a table of LOB and sizeless columns back through the same path
    ///  the model generators use, and checks the two things that used to be
    ///  wrong about it: a type that admits no size was handed the capacity
    ///  the engine reports (Blob(2147483647), Memo(1073741823), Float(16) --
    ///  all rejected by the validator), and a LOB was not recognised as one.
    ///
    ///  The second half is why this has to talk to a real server: on SQL
    ///  Server the LOB signal is the caBlobData attribute, not the type,
    ///  while on Oracle it is the type (dtHMemo, dtHBlob). No unit test on
    ///  the mapping function could find either -- the input it gets wrong is
    ///  what the driver actually sends, and only the driver knows that.
    ///
    ///  The last two columns are the controls: a sized string and a decimal
    ///  must keep their size and scale.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    procedure LobColumns_AreReadBackAsMemoOrBlob_AndCarryNoSize(
      const ADatabaseName: string);

    /// <summary>
    ///  Exhaustive: one column per column shape the backend offers, read
    ///  back in a single pass, with every mismatch collected and reported
    ///  together instead of stopping at the first. Reverse engineering is
    ///  the one place where a wrong answer is silent -- the model is written
    ///  to a file and nobody looks at it again -- so the mapping deserves a
    ///  test that names every type.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    // The same SQL Server through the ADO reader, which has its own type
    // mapping: what a column becomes is the driver's answer, not the
    // engine's. DBExpress would be the third, but a connection through it
    // stops on TDBXError: Unknown driver: MSSQL, so there is nothing to
    // measure and no case for it.
    [TestCase('ADO on MSSQL', 'ADO_MSSQL')]
    procedure EveryColumnType_IsReadBackAsExpected(const ADatabaseName: string);
    /// <summary>
    ///  The audit that says which column shapes cannot become a valid model
    ///  field. It reads the matrix table back and applies, to every column,
    ///  the two rules TModelValidator enforces on a model field
    ///  (KIDE.ModelValidator.pas:170 and :173):
    ///
    ///    a type that HAS a size must not carry 0  -- "cannot have zero size"
    ///    a type that has NO size must not carry one -- "cannot have a size"
    ///
    ///  A column that breaks either one produces a Model the project's own
    ///  validator rejects, which is why this is not a matter of taste. The
    ///  violations are asserted against the list measured on each backend, so
    ///  the list IS the documentation: if one disappears, or a new shape joins
    ///  it, this test fails and names it. ANALISI_R516.md explains each entry.
    ///
    ///  Four connections go through FireDAC and the fifth through ADO on the
    ///  same SQL Server: what a column becomes is the reader's answer, not the
    ///  engine's. Through ADO, datetime comes back as DateTime and money as
    ///  Currency -- two of the readings documented as defects -- while the
    ///  columns that cannot become a valid model field become thirteen
    ///  instead of two.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    [TestCase('ADO on MSSQL', 'ADO_MSSQL')]
    procedure EveryColumnType_IsCheckedAgainstTheModelFieldRules(const ADatabaseName: string);
    /// <summary>
    ///  The claim behind "every timestamp loses its time", in one test: the
    ///  column really does carry a time -- written and read back through the
    ///  same connection -- while introspection describes it as a Date, which
    ///  is what a generated Model writes down. Both halves are asserted here
    ///  so neither can be quoted without the other.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    procedure ATimestampColumn_CarriesATimeAndIsIntrospectedAsDate(const ADatabaseName: string);
    /// <summary>
    ///  What a model generated from the matrix table would actually SEE: one
    ///  row is written with a value in every column whose reading is
    ///  documented as wrong, then each value is read back through the EF type
    ///  introspection assigned to that column -- the same call the store
    ///  uses -- and rendered. The expectations are the measurement, so a
    ///  value that survives, is truncated, or raises is pinned here rather
    ///  than argued about.
    /// </summary>
    [Test]
    [TestCase('MSSQL', 'MSSQL')]
    [TestCase('Firebird', 'Firebird')]
    [TestCase('PostgreSQL', 'PostgreSQL')]
    [TestCase('Oracle', 'Oracle')]
    procedure AValueInEachOddColumn_ReadThroughTheIntrospectedType(const ADatabaseName: string);
  end;

  /// <summary>
  ///  Dove l'ora si perde per davvero. Dichiarare `Date` sopra una colonna
  ///  `datetime` non è solo un'etichetta imprecisa nel model: al momento della
  ///  lettura il tipo tronca il valore, perché TEFDateDataType assegna
  ///  ANode.AsDate (EF.Tree.pas, InternalFieldValueToNode). Qui si vede su un
  ///  campo vero, con TEFDateTimeDataType come controllo.
  /// </summary>
  [TestFixture]
  TEFDataTypeFieldReadingTests = class
  strict private
    /// <summary>Un dataset in memoria con un solo campo datetime che porta
    /// data e ora, cursore sul primo record.</summary>
    function DateTimeDataSet(const AValue: TDateTime): TDataSet;
    /// <summary>Un dataset in memoria con un solo campo a 64 bit, cursore sul
    /// primo record: la forma in cui arriva una colonna bigint.</summary>
    function LargeIntDataSet(const AValue: Int64): TDataSet;
    /// <summary>Un dataset in memoria con un solo campo numerico del tipo,
    /// precisione e scala dati, che porta il valore assegnato come TBcd.</summary>
    function DecimalDataSet(const AFieldType: TFieldType; const APrecision, AScale: Integer;
      const AValue: string): TDataSet;
    /// <summary>Rendering invariante del nodo, secondo il tipo EF con cui è
    /// stato letto.</summary>
    function Render(const ATypeName: string; const ANode: TEFNode): string;
  public
    [Test]
    procedure ADateType_ReadingADateTimeField_DropsTheTime;
    [Test]
    procedure ADateTimeType_ReadingTheSameField_KeepsIt;
    /// <summary>
    ///  The consequence of reading a bigint column back as Integer, which is
    ///  what the matrix records on SQL Server, Firebird and PostgreSQL: the
    ///  node is a 32-bit Integer (TEFNode.AsInteger), so the first value that
    ///  does not fit comes out as another number entirely. Silently, in every
    ///  build configuration: the narrowing is the explicit cast Integer(L) in
    ///  TLargeintField.GetAsInteger (Data.DB.pas), which no range check sees,
    ///  so the Debug $R+ of this project cannot turn it into an exception.
    /// </summary>
    [Test]
    procedure AnIntegerType_ReadingA64BitField_LosesWhatDoesNotFit;
    /// <summary>The same 64-bit field through the Decimal type: read as a
    /// BCD, the value survives. What a bigint column would keep if it were
    /// introspected as Decimal rather than Integer.</summary>
    [Test]
    procedure ADecimalType_ReadingTheSame64BitField_KeepsTheValue;
    /// <summary>
    ///  Where the digits go. A value is put in an in-memory field of the kind
    ///  a driver hands over -- exact BCD (ftFMTBcd, ftBCD) or Double-backed
    ///  (ftCurrency) -- and read through the EF Decimal or Currency type. The
    ///  expected rendering is the measurement of 8 September 2026: the EF
    ///  Decimal type keeps 15 significant digits whatever the field, because
    ///  TEFDataType.DecimalToValue stores a TBcd as a Double (EF.Tree.pas).
    /// </summary>
    [Test]
    [TestCase('numeric no precision, Decimal', 'ftFMTBcd,38,18,12345.678901234567890123,Decimal,12345.6789012346')]
    [TestCase('decimal(18;4), Decimal', 'ftFMTBcd,18,4,12345678901234.5678,Decimal,12345678901234.6')]
    [TestCase('decimal(18;4), Currency', 'ftFMTBcd,18,4,12345678901234.5678,Currency,12345678901234.5678')]
    [TestCase('bcd money, Decimal', 'ftBCD,0,4,123456789012345.6789,Decimal,123456789012346')]
    [TestCase('bcd money, Currency', 'ftBCD,0,4,123456789012345.6789,Currency,123456789012345.6789')]
    [TestCase('double money, Decimal', 'ftCurrency,0,0,123456789012345.6789,Decimal,123456789012346')]
    // The one rendering that depends on the compiler. The field holds a Double,
    // and the nearest Double to the written value is 123456789012345.671875:
    // the cents are gone before EF sees anything. What differs is the RTL's
    // Double-to-Currency conversion that TCurrencyField.GetAsCurrency runs. The
    // 32-bit one scales in extended precision and rounds that Double correctly,
    // to .6719; the 64-bit one multiplies by 10000 in a Double, past the 53
    // bits it has, and lands on .6768. Neither is the value written, and
    // neither is EF's doing - measured with a three-line program on both.
    {$IFDEF CPUX64}
    [TestCase('double money, Currency', 'ftCurrency,0,0,123456789012345.6789,Currency,123456789012345.6768')]
    {$ELSE}
    [TestCase('double money, Currency', 'ftCurrency,0,0,123456789012345.6789,Currency,123456789012345.6719')]
    {$ENDIF}
    [TestCase('15 digits, Decimal', 'ftFMTBcd,18,4,12345678901.2345,Decimal,12345678901.2345')]
    procedure ADecimalValue_ReadThroughDecimalOrCurrency(const AFieldType: string;
      const APrecision, AScale: Integer; const AWritten, ATypeName, AExpected: string);
  end;

  /// <summary>
  ///  Tests for the size a field spec declares. TKModelField.Size and
  ///  DecimalPrecision come from one parse of the node's value
  ///  (GetFieldSpec), which nothing covered: it reads the size from inside the
  ///  parentheses after stripping the ' not null' and ' primary key'
  ///  suffixes, and a reference field gets no size at all.
  /// </summary>
  [TestFixture]
  TKModelFieldSpecTests = class
  strict private
    function ModelFromYaml(const AName, AYaml: string): TKModel;
  public
    [Test]
    procedure ASizedString_CarriesItsSize;
    /// <summary>In a field spec the first number is the precision, which the
    /// model calls Size, and the second is the scale, which it calls
    /// DecimalPrecision.</summary>
    [Test]
    procedure ADecimal_PutsThePrecisionInSizeAndTheScaleInDecimalPrecision;
    [Test]
    procedure ATypeWithoutParentheses_HasNoSize;
    /// <summary>The suffixes are stripped before the size is read, so they
    /// cannot end up inside it.</summary>
    [Test]
    procedure TheSuffixes_LeaveTheSizeAlone;
    /// <summary>
    ///  Regression. GetFieldSpec sets -1 for a reference -- 'not applicable' --
    ///  and DecimalPrecision has to hand out a usable number anyway: the -1
    ///  used to reach TFormatSettings.CurrencyDecimals, a Byte, so rendering
    ///  any list or form with a reference in it raised a range error, and in
    ///  Release formatted with 255 decimals asked for.
    /// </summary>
    [Test]
    procedure AReference_HasNoSizeAndANonNegativeDecimalPrecision;
    /// <summary>
    ///  The boundary of the r516 fix: the contract lives on the DB side
    ///  (TEFDBColumnInfo), NOT here. A hand-written spec that puts a size on a
    ///  type that admits none keeps it, and only the validator objects. Pinned
    ///  so nobody assumes the two sides behave alike.
    /// </summary>
    [Test]
    procedure ASizeOnATypeThatAdmitsNone_IsKeptByTheModel;
    /// <summary>
    ///  PostgreSQL answers an unconstrained numeric with scale -5, so a
    ///  generated spec can carry a negative scale. It must not reach
    ///  TFormatSettings.CurrencyDecimals, a Byte, as one.
    /// </summary>
    [Test]
    procedure ANegativeScaleInTheSpec_DoesNotReachTheFormatSettings;
    /// <summary>A field the database assigns -- IsGenerated, the flag of an
    /// auto-increment -- is one the model does not write:
    /// CanActuallyModify is False. The shape a rowversion needs.</summary>
    [Test]
    procedure AGeneratedField_IsNotOneTheModelWrites;
    /// <summary>A spec with scale 0, the shape introspection writes for a
    /// Firebird decfloat(16): the field hands out 2 as its decimal
    /// precision, so a value with more decimals is shown with two.</summary>
    [Test]
    procedure ADecimalWithScaleZero_HandsOutTwoDecimals;
  end;

  /// <summary>
  ///  Tests for how the FireDAC metadata reader turns the rows a driver returns
  ///  for a key into an ordered list of column names. No database: the rows are
  ///  supplied by an in-memory dataset shaped like the metadata query, which is
  ///  the only way to present them out of order on purpose.
  /// </summary>
  [TestFixture]
  TEFDBFDKeyColumnsTests = class
  strict private
    /// <summary>An in-memory dataset with the fields the metadata queries have.
    /// Each row is a position, a column name and a referenced column name; the
    /// cursor is left on the first record.</summary>
    function MetaDataSet(const APositions: array of Integer;
      const ANames, AReferencedNames: array of string): TDataSet;
  public
    /// <summary>
    ///  Regression. The reader used to append each name as it arrived and
    ///  Assert that the position the driver reported matched the index the name
    ///  had landed on. A driver returning the rows in another order therefore
    ///  raised EAssertionFailed in Debug and -- with assertions off in Release
    ///  since EF.Defines.inc stopped forcing {$C+} -- built the list in the
    ///  driver's order without a word. Column order is what couples a master's
    ///  key to a detail's reference, so the quiet outcome reads another
    ///  master's rows.
    /// </summary>
    [Test]
    procedure AddKeyColumns_OrdersByPositionNotByArrival;
    /// <summary>
    ///  The two lists of a foreign key are filled in one pass, so they stay
    ///  coupled: the local column at index I references the foreign column at
    ///  index I, whatever order the rows arrived in.
    /// </summary>
    [Test]
    procedure AddKeyColumns_CouplesTheTwoListsByPosition;
    /// <summary>
    ///  Positions that are not 1..n each exactly once do not describe the key.
    ///  Failing to open the view is the visible, harmless outcome; a key built
    ///  out of that metadata is the invisible, harmful one.
    /// </summary>
    [Test]
    procedure AddKeyColumns_WithADuplicatePosition_Raises;
    [Test]
    procedure AddKeyColumns_WithAPositionAboveTheColumnCount_Raises;
    [Test]
    procedure AddKeyColumns_WithAZeroPosition_Raises;
    [Test]
    procedure AddKeyColumns_WithNoRows_AddsNothing;
    /// <summary>
    ///  A list that already has entries is appended to, and the appended block
    ///  is ordered on its own. The old code compared positions against the
    ///  whole list's length instead, so anything already in the list made every
    ///  comparison fail.
    /// </summary>
    [Test]
    procedure AddKeyColumns_AppendsAfterWhatIsAlreadyInTheList;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  System.Masks,
  Data.FmtBcd,
  FireDAC.Comp.Client,
  EF.DB.FD,
  // The connections the introspection tests run on, and the skip
  // mechanism when a backend is not there.
  Kitto.TestDB,
  {$IFDEF MSWINDOWS}Winapi.ActiveX,{$ENDIF}  // CoInitialize: ADO needs COM
  EF.YAML;

{ TEFDBEngineTypeTests }

procedure TEFDBEngineTypeTests.BaseDialect_WithPaging_SeparatesWhereFromOrderBy;
var
  LEngine: TEFDBEngineType;
  LSQL: string;
begin
  LEngine := TEFDBEngineType.Create;
  try
    LSQL := LEngine.AddLimitClause(SELECT_CLAUSE, FROM_CLAUSE, WHERE_CLAUSE,
      ORDER_BY_CLAUSE, 0, 100);
    Assert.IsFalse(ContainsText(LSQL, ')order by'),
      'The where clause runs into the order by clause: ' + LSQL);
    Assert.IsTrue(ContainsText(LSQL, ') order by'), LSQL);
  finally
    LEngine.Free;
  end;
end;

procedure TEFDBEngineTypeTests.BaseDialect_WithoutPaging_SeparatesWhereFromOrderBy;
var
  LEngine: TEFDBEngineType;
  LSQL: string;
begin
  LEngine := TEFDBEngineType.Create;
  try
    LSQL := LEngine.AddLimitClause(SELECT_CLAUSE, FROM_CLAUSE, WHERE_CLAUSE,
      ORDER_BY_CLAUSE, 0, 0);
    Assert.IsFalse(ContainsText(LSQL, ')order by'),
      'The where clause runs into the order by clause: ' + LSQL);
  finally
    LEngine.Free;
  end;
end;

procedure TEFDBEngineTypeTests.OracleDialect_SeparatesWhereFromOrderBy;
var
  LEngine: TEFOracleDBEngineType;
  LSQL: string;
begin
  LEngine := TEFOracleDBEngineType.Create;
  try
    LSQL := LEngine.AddLimitClause(SELECT_CLAUSE, FROM_CLAUSE, WHERE_CLAUSE,
      ORDER_BY_CLAUSE, 0, 0);
    Assert.IsFalse(ContainsText(LSQL, ')order by'),
      'ORA-00933 waiting to happen: ' + LSQL);
    Assert.IsTrue(ContainsText(LSQL, ') order by'), LSQL);
  finally
    LEngine.Free;
  end;
end;

procedure TEFDBEngineTypeTests.OracleDialect_WithPaging_SeparatesWhereFromOrderBy;
var
  LEngine: TEFOracleDBEngineType;
  LSQL: string;
begin
  LEngine := TEFOracleDBEngineType.Create;
  try
    LSQL := LEngine.AddLimitClause(SELECT_CLAUSE, FROM_CLAUSE, WHERE_CLAUSE,
      ORDER_BY_CLAUSE, 0, 1);
    Assert.IsFalse(ContainsText(LSQL, ')order by'),
      'ORA-00933 waiting to happen: ' + LSQL);
    // The single-record case: ROWNUM starts at 1, so the upper bound is
    // inclusive. 'ROWNUM < 1' would never be true and the edit form of a record
    // would come back empty.
    Assert.IsTrue(ContainsText(LSQL, 'ROWNUM <= 1'), LSQL);
  finally
    LEngine.Free;
  end;
end;

procedure TEFDBEngineTypeTests.SequenceSQL_PerDialect;

  procedure Check(const AEngine: TEFDBEngineType; const AExpected: string);
  begin
    try
      Assert.AreEqual(AExpected, AEngine.GetSequenceNextValueSQL('SEQ_PROMAN'),
        AEngine.ClassName);
    finally
      AEngine.Free;
    end;
  end;

begin
  Check(TEFDBEngineType.Create, 'select next value for SEQ_PROMAN');
  Check(TEFSQLServerDBEngineType.Create, 'select next value for SEQ_PROMAN');
  Check(TEFMySQLDBEngineType.Create, 'select next value for SEQ_PROMAN');
  Check(TEFOracleDBEngineType.Create, 'select SEQ_PROMAN.nextval from dual');
  Check(TEFFirebirdDBEngineType.Create,
    'select next value for SEQ_PROMAN from RDB$DATABASE');
  Check(TEFPostgreSQLDBEngineType.Create, 'select nextval(''SEQ_PROMAN'')');
end;

procedure TEFDBEngineTypeTests.SequenceSQL_DelimitsEveryPartWhenAsked;
var
  LEngine: TEFDBEngineType;
begin
  LEngine := TEFOracleDBEngineType.Create;
  try
    LEngine.DelimitIdentifiers := True;
    Assert.AreEqual('select "PROMAN"."SEQ_PROMAN".nextval from dual',
      LEngine.GetSequenceNextValueSQL('PROMAN.SEQ_PROMAN'));
  finally
    LEngine.Free;
  end;

  LEngine := TEFPostgreSQLDBEngineType.Create;
  try
    LEngine.DelimitIdentifiers := True;
    Assert.AreEqual('select nextval(''"public"."seq"'')',
      LEngine.GetSequenceNextValueSQL('public.seq'));
  finally
    LEngine.Free;
  end;

  LEngine := TEFSQLServerDBEngineType.Create;
  try
    LEngine.DelimitIdentifiers := True;
    Assert.AreEqual('select next value for [dbo].[seq]',
      LEngine.GetSequenceNextValueSQL('dbo.seq'));
  finally
    LEngine.Free;
  end;
end;

procedure TEFDBEngineTypeTests.BaseDialect_WithoutPaging_KeepsTheClausesInOrder;
var
  LEngine: TEFDBEngineType;
  LSQL: string;
begin
  LEngine := TEFDBEngineType.Create;
  try
    LSQL := LEngine.AddLimitClause(SELECT_CLAUSE, FROM_CLAUSE, WHERE_CLAUSE,
      ORDER_BY_CLAUSE, 0, 0);
    Assert.IsTrue(Pos(FROM_CLAUSE, LSQL) > Pos(SELECT_CLAUSE, LSQL), LSQL);
    Assert.IsTrue(Pos('where', LSQL) > Pos(FROM_CLAUSE, LSQL), LSQL);
    Assert.IsTrue(Pos(ORDER_BY_CLAUSE, LSQL) > Pos('where', LSQL), LSQL);
  finally
    LEngine.Free;
  end;
end;

{ TCountingDBAdapter }

destructor TCountingDBAdapter.Destroy;
begin
  Inc(FDestroyCount);
  // No inherited, and no released memory -- see the class comment.
end;

procedure TCountingDBAdapter.FreeInstance;
begin
  // Deliberately empty -- see the class comment.
end;

function TCountingDBAdapter.InternalCreateDBConnection: TEFDBConnection;
begin
  Result := nil;
end;

class procedure TCountingDBAdapter.ResetDestroyCount;
begin
  FDestroyCount := 0;
end;

{ TEFDBAdapterRegistryTests }

procedure TEFDBAdapterRegistryTests.Destruction_FreesEachRegisteredAdapterOnce;
var
  LRegistry: TEFDBAdapterRegistry;
begin
  TCountingDBAdapter.ResetDestroyCount;
  LRegistry := TEFDBAdapterRegistry.Create;
  try
    LRegistry.RegisterDBAdapter('COUNTING', TCountingDBAdapter.Create);
  finally
    LRegistry.Free;
  end;
  Assert.AreEqual(1, TCountingDBAdapter.DestroyCount,
    'The registered adapter was not freed exactly once.');
end;

procedure TEFDBAdapterRegistryTests.Destruction_WithSeveralAdapters_FreesEachOfThemOnce;
var
  LRegistry: TEFDBAdapterRegistry;
begin
  TCountingDBAdapter.ResetDestroyCount;
  LRegistry := TEFDBAdapterRegistry.Create;
  try
    LRegistry.RegisterDBAdapter('COUNTING1', TCountingDBAdapter.Create);
    LRegistry.RegisterDBAdapter('COUNTING2', TCountingDBAdapter.Create);
    LRegistry.RegisterDBAdapter('COUNTING3', TCountingDBAdapter.Create);
  finally
    LRegistry.Free;
  end;
  Assert.AreEqual(3, TCountingDBAdapter.DestroyCount,
    'The three registered adapters were not freed exactly once each.');
end;

procedure TEFDBAdapterRegistryTests.Unregister_FreesTheAdapterExactlyOnce;
var
  LRegistry: TEFDBAdapterRegistry;
begin
  TCountingDBAdapter.ResetDestroyCount;
  LRegistry := TEFDBAdapterRegistry.Create;
  try
    LRegistry.RegisterDBAdapter('COUNTING', TCountingDBAdapter.Create);
    LRegistry.UnregisterDBAdapter('COUNTING');
    Assert.AreEqual(1, TCountingDBAdapter.DestroyCount,
      'Unregistering did not free the adapter.');
    Assert.AreEqual(0, LRegistry.DBAdapterCount);
  finally
    LRegistry.Free;
  end;
  Assert.AreEqual(1, TCountingDBAdapter.DestroyCount,
    'The adapter was freed again when the registry was destroyed.');
end;

{ TCountingForeignKeyInfo }

destructor TCountingForeignKeyInfo.Destroy;
begin
  Inc(FDestroyCount);
  // No inherited, and no released memory -- see TCountingDBAdapter.
end;

procedure TCountingForeignKeyInfo.FreeInstance;
begin
  // Deliberately empty -- see TCountingDBAdapter.
end;

class procedure TCountingForeignKeyInfo.ResetDestroyCount;
begin
  FDestroyCount := 0;
end;

{ TEFDBTableInfoTests }

procedure TEFDBTableInfoTests.AddForeignKey_TransfersOwnershipToTheTable;
var
  LTable: TEFDBTableInfo;
  LForeignKey: TCountingForeignKeyInfo;
begin
  TCountingForeignKeyInfo.ResetDestroyCount;
  LTable := TEFDBTableInfo.Create;
  try
    LForeignKey := TCountingForeignKeyInfo.Create;
    LForeignKey.Name := 'FK_CHILD_PARENT';
    LTable.AddForeignKey(LForeignKey);
    Assert.AreEqual(1, LTable.ForeignKeyCount);
    Assert.AreSame(LTable, LForeignKey.TableInfo,
      'AddForeignKey did not record the table on the foreign key.');
    Assert.AreEqual(0, TCountingForeignKeyInfo.DestroyCount,
      'The foreign key was freed while the table was still alive.');
  finally
    LTable.Free;
  end;
  Assert.AreEqual(1, TCountingForeignKeyInfo.DestroyCount,
    'The table did not free its foreign key exactly once.');
end;

procedure TEFDBTableInfoTests.FindForeignKey_ReturnsTheInstanceTheTableOwns;
var
  LTable: TEFDBTableInfo;
  LForeignKey: TEFDBForeignKeyInfo;
begin
  LTable := TEFDBTableInfo.Create;
  try
    LForeignKey := TEFDBForeignKeyInfo.Create;
    LForeignKey.Name := 'FK_CHILD_PARENT';
    LTable.AddForeignKey(LForeignKey);
    Assert.AreSame(LForeignKey, LTable.FindForeignKey('FK_CHILD_PARENT'));
    // Case-insensitively, too: it is how the fetchers look one up again on the
    // second row of a composite key.
    Assert.AreSame(LForeignKey, LTable.FindForeignKey('fk_child_parent'));
    Assert.IsNull(LTable.FindForeignKey('FK_SOMETHING_ELSE'));
  finally
    LTable.Free;
  end;
end;

procedure TEFDBTableInfoTests.FreeingAnAddedForeignKey_MakesTheTableFreeItTwice;
var
  LTable: TEFDBTableInfo;
  LForeignKey: TCountingForeignKeyInfo;
begin
  TCountingForeignKeyInfo.ResetDestroyCount;
  LTable := TEFDBTableInfo.Create;
  try
    LForeignKey := TCountingForeignKeyInfo.Create;
    LForeignKey.Name := 'FK_CHILD_PARENT';
    LTable.AddForeignKey(LForeignKey);
    // What the removed handler did.
    FreeAndNil(LForeignKey);
    Assert.AreEqual(1, TCountingForeignKeyInfo.DestroyCount);
  finally
    LTable.Free;
  end;
  Assert.AreEqual(2, TCountingForeignKeyInfo.DestroyCount,
    'Freeing a foreign key already added to a table is expected to leave the ' +
    'table freeing it again -- if this ever stops being true, the comment in ' +
    'FetchTableForeignKeys explaining why it has no handler is out of date.');
end;

{ TEFDBColumnInfoTests }

procedure TEFDBColumnInfoTests.Size_OnATypeThatHasNone_IsDropped(
  const ATypeName: string; const ASize: Integer);
var
  LColumn: TEFDBColumnInfo;
  LDataType: TEFDataType;
begin
  LDataType := TEFDataTypeFactory.Instance.GetDataType(ATypeName);
  Assert.IsFalse(LDataType.HasSize, ATypeName +
    ' declares HasSize: this test case is about the types that do not.');
  LColumn := TEFDBColumnInfo.Create;
  try
    LColumn.DataType := LDataType;
    LColumn.Size := ASize;
    Assert.AreEqual(0, LColumn.Size, Format(
      '%s kept the size %d the engine reported. That is what ends up in the ' +
      'field spec as %s(%d).', [ATypeName, ASize, ATypeName, ASize]));
  finally
    LColumn.Free;
  end;
end;

procedure TEFDBColumnInfoTests.Size_OnATypeThatHasOne_IsKept(
  const ATypeName: string; const ASize: Integer);
var
  LColumn: TEFDBColumnInfo;
begin
  LColumn := TEFDBColumnInfo.Create;
  try
    LColumn.DataType := TEFDataTypeFactory.Instance.GetDataType(ATypeName);
    LColumn.Size := ASize;
    Assert.AreEqual(ASize, LColumn.Size,
      ATypeName + ' lost the size it is entitled to.');
  finally
    LColumn.Free;
  end;
end;

procedure TEFDBColumnInfoTests.Scale_OnATypeThatHasNone_IsDropped(
  const ATypeName: string);
var
  LColumn: TEFDBColumnInfo;
begin
  LColumn := TEFDBColumnInfo.Create;
  try
    LColumn.DataType := TEFDataTypeFactory.Instance.GetDataType(ATypeName);
    LColumn.Scale := 4;
    Assert.AreEqual(0, LColumn.Scale, ATypeName + ' kept a scale.');
  finally
    LColumn.Free;
  end;
end;

procedure TEFDBColumnInfoTests.Scale_OnDecimal_IsKept;
var
  LColumn: TEFDBColumnInfo;
begin
  LColumn := TEFDBColumnInfo.Create;
  try
    LColumn.DataType := TEFDataTypeFactory.Instance.GetDataType('Decimal');
    LColumn.Size := 12;
    LColumn.Scale := 3;
    Assert.AreEqual(12, LColumn.Size, 'Decimal lost its precision.');
    Assert.AreEqual(3, LColumn.Scale, 'Decimal lost its scale.');
  finally
    LColumn.Free;
  end;
end;

procedure TEFDBColumnInfoTests.Scale_OnCurrency_IsKeptWhileTheSizeIsDropped;
var
  LColumn: TEFDBColumnInfo;
begin
  LColumn := TEFDBColumnInfo.Create;
  try
    LColumn.DataType := TEFDataTypeFactory.Instance.GetDataType('Currency');
    // What SQL Server reports for a money column: precision 19, scale 4.
    LColumn.Size := 19;
    LColumn.Scale := 4;
    Assert.AreEqual(4, LColumn.Scale, 'Currency lost the scale it is entitled to.');
    Assert.AreEqual(0, LColumn.Size, 'Currency kept a size it does not admit.');
  finally
    LColumn.Free;
  end;
end;

procedure TEFDBColumnInfoTests.TheContract_HoldsWhicheverOrderTheDriverAssignsIn;
var
  LColumn: TEFDBColumnInfo;
begin
  // Size first, then the type: the type arriving last has to clear what is
  // already there.
  LColumn := TEFDBColumnInfo.Create;
  try
    LColumn.Size := 2147483647;
    LColumn.Scale := 4;
    LColumn.DataType := TEFDataTypeFactory.Instance.GetDataType('Blob');
    Assert.AreEqual(0, LColumn.Size,
      'A size assigned before the data type survived it.');
    Assert.AreEqual(0, LColumn.Scale,
      'A scale assigned before the data type survived it.');
  finally
    LColumn.Free;
  end;

  // Type first, then the size: the size arriving last must not get in.
  LColumn := TEFDBColumnInfo.Create;
  try
    LColumn.DataType := TEFDataTypeFactory.Instance.GetDataType('Memo');
    LColumn.Size := 1073741823;
    Assert.AreEqual(0, LColumn.Size,
      'A size assigned after the data type got through.');
  finally
    LColumn.Free;
  end;
end;

{ TEFDBFDKeyColumnsTests }

function TEFDBFDKeyColumnsTests.MetaDataSet(const APositions: array of Integer;
  const ANames, AReferencedNames: array of string): TDataSet;
var
  LTable: TFDMemTable;
  I: Integer;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LTable.FieldDefs.Add('COLUMN_POSITION', ftInteger);
    LTable.FieldDefs.Add('COLUMN_NAME', ftString, 50);
    LTable.FieldDefs.Add('PKEY_COLUMN_NAME', ftString, 50);
    LTable.CreateDataSet;
    for I := Low(APositions) to High(APositions) do
      LTable.AppendRecord([APositions[I], ANames[I], AReferencedNames[I]]);
    LTable.First;
  except
    LTable.Free;
    raise;
  end;
  Result := LTable;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_OrdersByPositionNotByArrival;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  // The driver hands them over as C, A, B.
  LDataSet := MetaDataSet([3, 1, 2], ['C', 'A', 'B'], ['', '', '']);
  try
    LNames := TStringList.Create;
    try
      TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
        LNames, nil, 'the key under test');
      Assert.AreEqual('A,B,C', LNames.CommaText);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_CouplesTheTwoListsByPosition;
var
  LDataSet: TDataSet;
  LNames, LReferenced: TStrings;
begin
  LDataSet := MetaDataSet([2, 1], ['LOCAL_B', 'LOCAL_A'], ['FOREIGN_B', 'FOREIGN_A']);
  try
    LNames := TStringList.Create;
    LReferenced := TStringList.Create;
    try
      TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME',
        'PKEY_COLUMN_NAME', LNames, LReferenced, 'the foreign key under test');
      Assert.AreEqual('LOCAL_A,LOCAL_B', LNames.CommaText);
      Assert.AreEqual('FOREIGN_A,FOREIGN_B', LReferenced.CommaText);
    finally
      LReferenced.Free;
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_WithADuplicatePosition_Raises;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  LDataSet := MetaDataSet([1, 1], ['A', 'B'], ['', '']);
  try
    LNames := TStringList.Create;
    try
      Assert.WillRaise(
        procedure
        begin
          TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
            LNames, nil, 'the key under test');
        end,
        EEFDBError);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_WithAPositionAboveTheColumnCount_Raises;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  // Two columns, so 3 is not a position this key can have.
  LDataSet := MetaDataSet([1, 3], ['A', 'B'], ['', '']);
  try
    LNames := TStringList.Create;
    try
      Assert.WillRaise(
        procedure
        begin
          TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
            LNames, nil, 'the key under test');
        end,
        EEFDBError);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_WithAZeroPosition_Raises;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  // Positions are 1-based: a 0 means the driver is counting differently, and
  // the list built from it would be off by one all the way through.
  LDataSet := MetaDataSet([0, 1], ['A', 'B'], ['', '']);
  try
    LNames := TStringList.Create;
    try
      Assert.WillRaise(
        procedure
        begin
          TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
            LNames, nil, 'the key under test');
        end,
        EEFDBError);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_WithNoRows_AddsNothing;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  LDataSet := MetaDataSet([], [], []);
  try
    LNames := TStringList.Create;
    try
      TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
        LNames, nil, 'the key under test');
      Assert.AreEqual(0, LNames.Count);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDBFDKeyColumnsTests.AddKeyColumns_AppendsAfterWhatIsAlreadyInTheList;
var
  LDataSet: TDataSet;
  LNames: TStrings;
begin
  LDataSet := MetaDataSet([2, 1], ['B', 'A'], ['', '']);
  try
    LNames := TStringList.Create;
    try
      LNames.Add('ALREADY_THERE');
      TEFDBFDInfo.AddKeyColumnsInPositionOrder(LDataSet, 'COLUMN_NAME', '',
        LNames, nil, 'the key under test');
      Assert.AreEqual('ALREADY_THERE,A,B', LNames.CommaText);
    finally
      LNames.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

{ TEFDBIntrospectionTests }

procedure TEFDBIntrospectionTests.Setup;
begin
  {$IFDEF MSWINDOWS}CoInitialize(nil);{$ENDIF}
end;

procedure TEFDBIntrospectionTests.TearDown;
begin
  {$IFDEF MSWINDOWS}CoUninitialize;{$ENDIF}
end;

function TEFDBIntrospectionTests.OpenOrSkip(const ADatabaseName: string): TEFDBConnection;
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

procedure TEFDBIntrospectionTests.Execute(const AConnection: TEFDBConnection;
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

function TEFDBIntrospectionTests.DropStatement(const AConnection: TEFDBConnection;
  const ATableName: string): string;
begin
  Result := 'drop table ' + ATableName;
  if AConnection.DBEngineType is TEFOracleDBEngineType then
    Result := Result + ' purge';
end;

procedure TEFDBIntrospectionTests.DropLobTestTable(const AConnection: TEFDBConnection);
begin
  // Same reasoning as DropTestTable: the table may not be there, and on
  // PostgreSQL and Firebird a failed statement poisons the transaction, so the
  // recovery is to reopen the connection.
  try
    AConnection.StartTransaction;
    try
      Execute(AConnection, DropStatement(AConnection, LOB_TABLE_NAME));
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

procedure TEFDBIntrospectionTests.CreateLobTestTable(const AConnection: TEFDBConnection;
  const ADatabaseName: string);
var
  LSQL: string;
begin
  if SameText(ADatabaseName, 'MSSQL') then
    // The MAX flavours on purpose: they are the ones FireDAC reports as plain
    // string and byte-string types, with caBlobData as the only clue.
    LSQL := 'create table ' + LOB_TABLE_NAME + ' (' +
      'id int not null primary key, c_str nvarchar(40) null, ' +
      'c_clob nvarchar(max) null, c_blob varbinary(max) null, ' +
      'c_num decimal(12,3) null, c_float float null)'
  else if SameText(ADatabaseName, 'Oracle') then
    LSQL := 'create table ' + LOB_TABLE_NAME + ' (' +
      'id number(10) not null primary key, c_str varchar2(40), ' +
      'c_clob clob, c_blob blob, ' +
      'c_num number(12,3), c_float binary_double)'
  else if SameText(ADatabaseName, 'Firebird') then
    LSQL := 'create table ' + LOB_TABLE_NAME + ' (' +
      'id integer not null primary key, c_str varchar(40), ' +
      'c_clob blob sub_type text, c_blob blob sub_type binary, ' +
      'c_num numeric(12,3), c_float double precision)'
  else // PostgreSQL
    LSQL := 'create table ' + LOB_TABLE_NAME + ' (' +
      'id integer not null primary key, c_str varchar(40), ' +
      'c_clob text, c_blob bytea, ' +
      'c_num numeric(12,3), c_float double precision)';

  AConnection.StartTransaction;
  try
    Execute(AConnection, LSQL);
    AConnection.CommitTransaction;
  except
    AConnection.RollbackTransaction;
    raise;
  end;
end;

procedure TEFDBIntrospectionTests.CheckColumn(const ATable: TEFDBTableInfo;
  const ADatabaseName, AColumnName, AExpectedTypeName: string;
  const AExpectedSize, AExpectedScale: Integer);
var
  LColumn: TEFDBColumnInfo;
  LWhere: string;
begin
  LWhere := Format('%s, column %s', [ADatabaseName, AColumnName]);
  LColumn := ATable.FindColumn(AColumnName);
  Assert.IsNotNull(LColumn, LWhere + ': not read back from the schema.');
  Assert.AreEqual(AExpectedTypeName, LColumn.DataType.GetTypeName,
    LWhere + ': unexpected EF data type.');
  Assert.AreEqual(AExpectedSize, LColumn.Size, Format(
    '%s: expected size %d, got %d. A size on a type that admits none is what ' +
    'ends up in a generated model as %s(%d).',
    [LWhere, AExpectedSize, LColumn.Size, AExpectedTypeName, LColumn.Size]));
  Assert.AreEqual(AExpectedScale, LColumn.Scale,
    LWhere + ': unexpected scale.');
end;

procedure TEFDBIntrospectionTests.LobColumns_AreReadBackAsMemoOrBlob_AndCarryNoSize(
  const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
  LDBInfo: TEFDBInfo;
  LTable: TEFDBTableInfo;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    DropLobTestTable(LConnection);
    CreateLobTestTable(LConnection, ADatabaseName);
    try
      LDBInfo := LConnection.CreateDBInfo;
      try
        LTable := LDBInfo.Schema.FindTable(LOB_TABLE_NAME);
        Assert.IsNotNull(LTable,
          ADatabaseName + ': the LOB table was not read back from the schema.');

        // The two LOBs: a type, and no size.
        CheckColumn(LTable, ADatabaseName, 'c_clob', 'Memo', 0, 0);
        CheckColumn(LTable, ADatabaseName, 'c_blob', 'Blob', 0, 0);
        // Floating point: the engines report a precision for it (16 on SQL
        // Server), and Float admits no size.
        CheckColumn(LTable, ADatabaseName, 'c_float', 'Float', 0, 0);
        // Controls: these two keep what they are entitled to.
        CheckColumn(LTable, ADatabaseName, 'c_str', 'String', 40, 0);
        CheckColumn(LTable, ADatabaseName, 'c_num', 'Decimal', 12, 3);
      finally
        LDBInfo.Free;
      end;
    finally
      DropLobTestTable(LConnection);
    end;
  finally
    LConnection.Free;
  end;
end;

procedure TEFDBIntrospectionTests.DropMatrixTestTable(const AConnection: TEFDBConnection);
begin
  try
    AConnection.StartTransaction;
    try
      Execute(AConnection, DropStatement(AConnection, MATRIX_TABLE_NAME));
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

/// <summary>The engine family behind a connection name, so the same DDL
/// serves every driver that talks to that engine.</summary>
function MatrixFamily(const ADatabaseName: string): string;
begin
  if ContainsText(ADatabaseName, 'MSSQL') then
    Result := 'MSSQL'
  else if ContainsText(ADatabaseName, 'Oracle') then
    Result := 'Oracle'
  else if ContainsText(ADatabaseName, 'Firebird') then
    Result := 'Firebird'
  else
    Result := 'PostgreSQL';
end;

function TEFDBIntrospectionTests.MatrixTableDDL(const AName: string): string;
var
  ADatabaseName: string;
begin
  ADatabaseName := MatrixFamily(AName);
  if SameText(ADatabaseName, 'MSSQL') then
    Result :=
      'create table ' + MATRIX_TABLE_NAME + ' (' +
      'id int not null primary key, ' +
      'c_tinyint tinyint, c_smallint smallint, c_int int, c_bigint bigint, ' +
      'c_decimal decimal(12,3), c_numeric numeric(18,4), ' +
      'c_money money, c_smallmoney smallmoney, ' +
      'c_real real, c_float float, c_bool bit, ' +
      'c_char char(10), c_varchar varchar(60), ' +
      'c_nchar nchar(10), c_nvarchar nvarchar(40), ' +
      'c_clob varchar(max), c_nclob nvarchar(max), ' +
      'c_text text, c_ntext ntext, ' +
      'c_binary binary(16), c_varbinary varbinary(50), ' +
      'c_blob varbinary(max), c_image image, ' +
      'c_date date, c_time time, ' +
      'c_datetime datetime, c_datetime2 datetime2, ' +
      'c_smalldatetime smalldatetime, c_datetimeoffset datetimeoffset, ' +
      'c_guid uniqueidentifier, c_xml xml, ' +
      // Shapes a real schema has and the matrix did not cover: a decimal
      // without a scale, an unconstrained numeric, the two extremes of a
      // sized string, a float with an explicit mantissa, the fractional
      // second precisions, and the two types that have no SQL length at all.
      'c_decimal_nos decimal(18), c_numeric_def numeric, '+
      'c_varchar1 varchar(1), c_nvarchar4000 nvarchar(4000), '+
      'c_float24 float(24), c_time7 time(7), c_datetime2_3 datetime2(3), '+
      'c_sqlvariant sql_variant, c_rowversion rowversion)'
  else if SameText(ADatabaseName, 'Oracle') then
    // No boolean before 23c, and no time-only type: Oracle's DATE carries a time.
    Result :=
      'create table ' + MATRIX_TABLE_NAME + ' (' +
      'id number(10) not null primary key, ' +
      'c_int number(10), c_decimal number(12,3), ' +
      'c_real binary_float, c_float binary_double, ' +
      'c_char char(10), c_varchar varchar2(40), ' +
      'c_clob clob, c_blob blob, c_raw raw(50), ' +
      'c_date date, c_datetime timestamp, ' +
      // NUMBER without precision, the maximum precision, a NEGATIVE scale
      // (legal on Oracle), the ANSI FLOAT that is a NUMBER underneath, the
      // national types, the three time-zone/interval shapes and ROWID.
      'c_number_nop number, c_number38 number(38), '+
      'c_number_neg number(5,-2), c_float_ansi float(10), '+
      'c_nvarchar2 nvarchar2(20), c_nchar nchar(5), c_nclob nclob, '+
      'c_ts_tz timestamp with time zone, '+
      'c_ts_ltz timestamp with local time zone, '+
      'c_interval_ds interval day to second, '+
      'c_interval_ym interval year to month, c_rowid rowid, '+
      'c_number18 number(18), c_numeric18 number(18,4))'
  else if SameText(ADatabaseName, 'Firebird') then
    Result :=
      'create table ' + MATRIX_TABLE_NAME + ' (' +
      'id integer not null primary key, ' +
      'c_smallint smallint, c_int integer, c_bigint bigint, ' +
      'c_decimal numeric(12,3), ' +
      'c_real float, c_float double precision, c_bool boolean, ' +
      'c_char char(10), c_varchar varchar(60), ' +
      'c_clob blob sub_type text, c_blob blob sub_type binary, ' +
      'c_date date, c_time time, c_datetime timestamp, ' +
      // Firebird 4 added the 128-bit integer, DECFLOAT, the time-zone
      // variants and the BINARY/VARBINARY aliases; plus a numeric without a
      // scale and a string in a multi-byte character set, where a length in
      // characters and one in bytes differ.
      'c_numeric18 numeric(18,4), c_decimal_nos decimal(9), '+
      'c_varchar1 varchar(1), '+
      'c_char_utf8 varchar(10) character set utf8, '+
      'c_int128 int128, c_decfloat decfloat(16), '+
      'c_time_tz time with time zone, '+
      'c_ts_tz timestamp with time zone, '+
      'c_binary binary(16), c_varbinary varbinary(50))'
  else // PostgreSQL
    Result :=
      'create table ' + MATRIX_TABLE_NAME + ' (' +
      'id integer not null primary key, ' +
      'c_smallint smallint, c_int integer, c_bigint bigint, ' +
      'c_decimal numeric(12,3), c_money money, ' +
      'c_real real, c_float double precision, c_bool boolean, ' +
      'c_char char(10), c_varchar varchar(60), ' +
      'c_clob text, c_blob bytea, ' +
      'c_date date, c_time time, ' +
      'c_datetime timestamp, c_datetimeoffset timestamptz, ' +
      'c_guid uuid, c_xml xml, ' +
      // The two unconstrained shapes PostgreSQL allows and the others do
      // not -- numeric with no precision and varchar with no length -- plus
      // json, an array, an interval and a time with time zone.
      'c_numeric_nop numeric, c_decimal_nos numeric(18), '+
      'c_char1 char(1), c_varchar_nolimit varchar, '+
      'c_json json, c_jsonb jsonb, c_int_arr integer[], '+
      'c_interval interval, c_timetz timetz, '+
      'c_numeric18 numeric(18,4))';
end;

function TEFDBIntrospectionTests.MatrixExpectations(
  const ADatabaseName: string): TArray<string>;
begin
  // Filled in from the measurement, one driver at a time.
  // ADO on the same SQL Server, MEASURED: another reader, another answer.
  // Where it differs from FireDAC is in ANALISI_R516.md, under
  // "Due cose da sapere prima di correggere".
  if SameText(ADatabaseName, 'ADO_MSSQL') then
  begin
    Result := [
      'id|Integer|0|0', 'c_tinyint|Integer|0|0',
      'c_smallint|Integer|0|0', 'c_int|Integer|0|0',
      'c_bigint|Integer|0|0', 'c_decimal|Decimal|0|0',
      'c_numeric|Decimal|0|0', 'c_money|Currency|0|0',
      'c_smallmoney|Currency|0|0', 'c_real|Float|0|0',
      'c_float|Float|0|0', 'c_bool|Boolean|0|0',
      'c_char|String|10|0', 'c_varchar|String|60|0',
      'c_nchar|String|10|0', 'c_nvarchar|String|40|0',
      'c_clob|String|0|0', 'c_nclob|String|0|0',
      'c_text|String|2147483647|0', 'c_ntext|String|1073741823|0',
      'c_binary|String|16|0', 'c_varbinary|String|50|0',
      'c_blob|String|0|0', 'c_image|String|2147483647|0',
      'c_date|Date|0|0', 'c_time|String|0|0',
      'c_datetime|DateTime|0|0', 'c_datetime2|DateTime|0|0',
      'c_smalldatetime|DateTime|0|0', 'c_datetimeoffset|String|0|0',
      'c_guid|String|0|0', 'c_xml|String|0|0',
      'c_decimal_nos|Decimal|0|0', 'c_numeric_def|Decimal|0|0',
      'c_varchar1|String|1|0', 'c_nvarchar4000|String|4000|0',
      'c_float24|Float|0|0', 'c_time7|String|0|0',
      'c_datetime2_3|DateTime|0|0', 'c_sqlvariant|String|0|0',
      'c_rowversion|String|8|0'];
    Exit;
  end;
  // 'column|TypeName|size|scale', one per column: what the reader returns for
  // every shape the backend offers, so a change shows up here.
  if SameText(ADatabaseName, 'MSSQL') then
    Result := [
      'c_tinyint|Integer|0|0', 'c_smallint|Integer|0|0',
      'c_int|Integer|0|0', 'c_bigint|Integer|0|0',
      'c_decimal|Decimal|12|3', 'c_numeric|Decimal|18|4',
      'c_money|Decimal|19|4', 'c_smallmoney|Decimal|10|4',
      'c_real|Float|0|0', 'c_float|Float|0|0', 'c_bool|Boolean|0|0',
      'c_char|String|10|0', 'c_varchar|String|60|0',
      'c_nchar|String|10|0', 'c_nvarchar|String|40|0',
      'c_clob|Memo|0|0', 'c_nclob|Memo|0|0',
      'c_text|Memo|0|0', 'c_ntext|Memo|0|0',
      'c_binary|String|16|0', 'c_varbinary|String|50|0',
      'c_blob|Blob|0|0', 'c_image|Blob|0|0',
      'c_date|Date|0|0', 'c_time|Time|0|0',
      'c_datetime|Date|0|0', 'c_datetime2|Date|0|0',
      'c_smalldatetime|Date|0|0',
      'c_datetimeoffset|String|0|0', 'c_guid|String|0|0',
      'c_xml|Memo|0|0',
      // The shapes added to the matrix on 8 September 2026, all measured.
      'c_decimal_nos|Decimal|18|0', 'c_numeric_def|Decimal|18|0',
      'c_varchar1|String|1|0', 'c_nvarchar4000|String|4000|0',
      'c_float24|Float|0|0', 'c_time7|Time|0|0', 'c_datetime2_3|Date|0|0',
      'c_sqlvariant|Memo|0|0', 'c_rowversion|String|8|0']
  else if SameText(ADatabaseName, 'Oracle') then
    Result := [
      // NUMBER(10) exceeds an Int32, so FireDAC reports a BCD and Decimal(10,0)
      // is the faithful reading.
      'c_int|Decimal|10|0', 'c_decimal|Decimal|12|3',
      'c_real|Float|0|0', 'c_float|Float|0|0',
      'c_char|String|10|0', 'c_varchar|String|40|0',
      'c_clob|Memo|0|0', 'c_blob|Blob|0|0', 'c_raw|String|50|0',
      'c_date|Date|0|0', 'c_datetime|Date|0|0',
      'c_number_nop|Decimal|0|0', 'c_number38|Decimal|38|0',
      // number(5,-2): the negative scale is dropped, not carried.
      'c_number_neg|Decimal|5|0', 'c_float_ansi|Float|0|0',
      'c_nvarchar2|String|20|0', 'c_nchar|String|5|0', 'c_nclob|Memo|0|0',
      'c_ts_tz|String|0|0', 'c_ts_ltz|String|0|0',
      // An interval becomes a two-character string.
      'c_interval_ds|String|2|0', 'c_interval_ym|String|2|0',
      'c_rowid|Memo|0|0',
      'c_number18|Decimal|18|0', 'c_numeric18|Decimal|18|4']
  else if SameText(ADatabaseName, 'Firebird') then
    Result := [
      'c_smallint|Integer|0|0', 'c_int|Integer|0|0', 'c_bigint|Integer|0|0',
      'c_decimal|Decimal|12|3',
      'c_real|Float|0|0', 'c_float|Float|0|0', 'c_bool|Boolean|0|0',
      'c_char|String|10|0', 'c_varchar|String|60|0',
      'c_clob|Memo|0|0', 'c_blob|Blob|0|0',
      'c_date|Date|0|0', 'c_time|Time|0|0', 'c_datetime|Date|0|0',
      'c_numeric18|Decimal|18|4',
      // decimal(9) comes back as an Integer: the decimal-ness is lost.
      'c_decimal_nos|Integer|0|0',
      'c_varchar1|String|1|0',
      // A length in a multi-byte character set is in CHARACTERS, not bytes.
      'c_char_utf8|String|10|0',
      'c_int128|Decimal|0|0', 'c_decfloat|Decimal|16|0',
      'c_time_tz|Time|0|0', 'c_ts_tz|String|0|0',
      'c_binary|String|16|0', 'c_varbinary|String|50|0']
  else
    Result := [
      'c_smallint|Integer|0|0', 'c_int|Integer|0|0', 'c_bigint|Integer|0|0',
      'c_decimal|Decimal|12|3', 'c_money|Decimal|19|4',
      'c_real|Float|0|0', 'c_float|Float|0|0', 'c_bool|Boolean|0|0',
      'c_char|String|10|0', 'c_varchar|String|60|0',
      'c_clob|Memo|0|0', 'c_blob|Blob|0|0',
      'c_date|Date|0|0', 'c_time|Time|0|0',
      'c_datetime|Date|0|0',
      'c_datetimeoffset|String|0|0', 'c_guid|String|0|0',
      'c_xml|Memo|0|0',
      // An unconstrained numeric: precision 0 and a NEGATIVE scale.
      'c_numeric_nop|Decimal|0|-5', 'c_decimal_nos|Decimal|18|0',
      'c_char1|String|1|0',
      // varchar with no length is read as a Memo, which is faithful.
      'c_varchar_nolimit|Memo|0|0',
      'c_json|Memo|0|0', 'c_jsonb|Memo|0|0',
      // An ARRAY column is read back as its scalar element type.
      'c_int_arr|Integer|0|0',
      'c_interval|Time|0|0', 'c_timetz|Time|0|0',
      'c_numeric18|Decimal|18|4'];
end;

procedure TEFDBIntrospectionTests.EveryColumnType_IsReadBackAsExpected(
  const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
  LDBInfo: TEFDBInfo;
  LTable: TEFDBTableInfo;
  LColumn: TEFDBColumnInfo;
  LProblems: string;
  LExpectation, LName, LType: string;
  LParts: TArray<string>;
  LSize, LScale: Integer;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    DropMatrixTestTable(LConnection);
    LConnection.StartTransaction;
    try
      Execute(LConnection, MatrixTableDDL(ADatabaseName));
      LConnection.CommitTransaction;
    except
      LConnection.RollbackTransaction;
      raise;
    end;
    try
      LDBInfo := LConnection.CreateDBInfo;
      try
        LTable := LDBInfo.Schema.FindTable(MATRIX_TABLE_NAME);
        Assert.IsNotNull(LTable,
          ADatabaseName + ': the type-matrix table was not read back.');
        // Every mismatch is collected and reported together: stopping at the
        // first would turn an audit of thirty columns into thirty runs.
        LProblems := '';
        for LExpectation in MatrixExpectations(ADatabaseName) do
        begin
          LParts := LExpectation.Split(['|']);
          LName := LParts[0];
          LType := LParts[1];
          LSize := StrToInt(LParts[2]);
          LScale := StrToInt(LParts[3]);
          LColumn := LTable.FindColumn(LName);
          if not Assigned(LColumn) then
            LProblems := LProblems + Format('%-18s not read back', [LName]) + sLineBreak
          else if (LColumn.DataType.GetTypeName <> LType)
              or (LColumn.Size <> LSize) or (LColumn.Scale <> LScale) then
            LProblems := LProblems +
              Format('%-18s expected %s(%d,%d) got %s(%d,%d)',
                [LName, LType, LSize, LScale, LColumn.DataType.GetTypeName,
                 LColumn.Size, LColumn.Scale]) + sLineBreak;
        end;
        Assert.IsTrue(LProblems = '', sLineBreak + ADatabaseName +
          ' reads these columns back differently than they must be:' +
          sLineBreak + LProblems);
      finally
        LDBInfo.Free;
      end;
    finally
      DropMatrixTestTable(LConnection);
    end;
  finally
    LConnection.Free;
  end;
end;

function TEFDBIntrospectionTests.KnownModelFieldViolations(
  const ADatabaseName: string): TArray<string>;
begin
  // MEASURED on the engines installed on the test machine (8 September 2026),
  // one entry per column whose read-back breaks a model-field rule. The names
  // are the ones the reader returns, uppercased by Firebird and Oracle.
  //
  // Two shapes recur on every backend that has them: a type carrying a UTC
  // offset and a GUID/UUID, neither of which has an EF data type, so both land
  // in String with no size. The third kind is a decimal with no declared
  // precision, which no backend can answer with a number.
  // ADO produces THIRTEEN of them on the same table where FireDAC produces
  // two: every decimal loses its precision and scale, and the LOB and
  // sizeless shapes come back as a String with no size.
  if SameText(ADatabaseName, 'ADO_MSSQL') then
  begin
    Result := [
      'c_decimal|Decimal(0,0)|cannot have zero size',
      'c_numeric|Decimal(0,0)|cannot have zero size',
      'c_clob|String(0,0)|cannot have zero size',
      'c_nclob|String(0,0)|cannot have zero size',
      'c_blob|String(0,0)|cannot have zero size',
      'c_time|String(0,0)|cannot have zero size',
      'c_datetimeoffset|String(0,0)|cannot have zero size',
      'c_guid|String(0,0)|cannot have zero size',
      'c_xml|String(0,0)|cannot have zero size',
      'c_decimal_nos|Decimal(0,0)|cannot have zero size',
      'c_numeric_def|Decimal(0,0)|cannot have zero size',
      'c_time7|String(0,0)|cannot have zero size',
      'c_sqlvariant|String(0,0)|cannot have zero size'];
    Exit;
  end;
  if SameText(ADatabaseName, 'MSSQL') then
    Result := [
      'c_datetimeoffset|String(0,0)|cannot have zero size',
      'c_guid|String(0,0)|cannot have zero size']
  else if SameText(ADatabaseName, 'Oracle') then
    Result := [
      'C_NUMBER_NOP|Decimal(0,0)|cannot have zero size',
      'C_TS_TZ|String(0,0)|cannot have zero size',
      'C_TS_LTZ|String(0,0)|cannot have zero size']
  else if SameText(ADatabaseName, 'Firebird') then
    Result := [
      'C_INT128|Decimal(0,0)|cannot have zero size',
      'C_TS_TZ|String(0,0)|cannot have zero size']
  else
    Result := [
      'c_datetimeoffset|String(0,0)|cannot have zero size',
      'c_guid|String(0,0)|cannot have zero size',
      // The only NEGATIVE scale measured anywhere: PostgreSQL answers an
      // unconstrained numeric with precision 0 and scale -5.
      'c_numeric_nop|Decimal(0,-5)|cannot have zero size'];
end;

function TEFDBIntrospectionTests.KnownDriverTypeSightings(
  const ADatabaseName: string): TArray<string>;
begin
  // MEASURED. The FireDAC connections produce neither type, so their list
  // is empty; ADO maps a timestamp to DateTime and money to Currency, and
  // that is a driver difference, not an engine one.
  if SameText(ADatabaseName, 'ADO_MSSQL') then
    Result := [
'c_money|Currency(0,0)',
      'c_smallmoney|Currency(0,0)',
      'c_datetime|DateTime(0,0)',
      'c_datetime2|DateTime(0,0)',
      'c_smalldatetime|DateTime(0,0)',
      'c_datetime2_3|DateTime(0,0)']
  else
    SetLength(Result, 0);
end;

procedure TEFDBIntrospectionTests.EveryColumnType_IsCheckedAgainstTheModelFieldRules(
  const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
  LDBInfo: TEFDBInfo;
  LTable: TEFDBTableInfo;
  LColumn: TEFDBColumnInfo;
  LFound, LExpected: TStringList;
  LSightings, LSightingsExpected: TStringList;
  LScales: TStringList;
  LInventory, LRead: string;
  LEntry: string;
  I: Integer;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    DropMatrixTestTable(LConnection);
    LConnection.StartTransaction;
    try
      Execute(LConnection, MatrixTableDDL(ADatabaseName));
      LConnection.CommitTransaction;
    except
      LConnection.RollbackTransaction;
      raise;
    end;
    try
      LDBInfo := LConnection.CreateDBInfo;
      try
        LTable := LDBInfo.Schema.FindTable(MATRIX_TABLE_NAME);
        Assert.IsNotNull(LTable,
          ADatabaseName + ': the type-matrix table was not read back.');
        LFound := TStringList.Create;
        LExpected := TStringList.Create;
        LSightings := TStringList.Create;
        LSightingsExpected := TStringList.Create;
        LScales := TStringList.Create;
        try
          LInventory := '';
          for I := 0 to LTable.ColumnCount - 1 do
          begin
            LColumn := LTable.Columns[I];
            LRead := Format('%s(%d,%d)', [LColumn.DataType.GetTypeName,
              LColumn.Size, LColumn.Scale]);
            LInventory := LInventory +
              Format('  %-22s %s', [LColumn.Name, LRead]) + sLineBreak;
            // The two rules of TModelValidator.ValidateModelField, applied to
            // what the reader hands the model generators.
            if LColumn.DataType.HasSize and (LColumn.Size = 0) then
              LFound.Add(Format('%s|%s|cannot have zero size',
                [LColumn.Name, LRead]))
            else if not LColumn.DataType.HasSize and (LColumn.Size <> 0) then
              LFound.Add(Format('%s|%s|cannot have a size',
                [LColumn.Name, LRead]));
            // DateTime and Currency are the two EF types the FireDAC reader
            // never produces -- which is why a timestamp becomes a Date and a
            // money column a Decimal. Whether they appear at all depends on
            // the DRIVER, so the sightings are collected and compared with
            // what was measured for this connection, per driver.
            if (LColumn.DataType.GetTypeName = 'DateTime')
                or (LColumn.DataType.GetTypeName = 'Currency') then
              LSightings.Add(Format('%s|%s', [LColumn.Name, LRead]));
            // Il contratto della classe, sul fronte della scala: nessun tipo che
            // non l'ammette deve portarne una. Non è una regola del validatore,
            // è l'invariante introdotta da r516, qui verificata su dati veri:
            // prima un smalldatetime tornava con scala 60000.
            if not LColumn.DataType.HasScale and (LColumn.Scale <> 0) then
              LScales.Add(Format('%s|%s', [LColumn.Name, LRead]));
          end;
          for LEntry in KnownModelFieldViolations(ADatabaseName) do
            LExpected.Add(LEntry);
          for LEntry in KnownDriverTypeSightings(ADatabaseName) do
            LSightingsExpected.Add(LEntry);
          LFound.Sort;
          LExpected.Sort;
          LSightings.Sort;
          LSightingsExpected.Sort;
          Assert.AreEqual('', LScales.Text, sLineBreak + ADatabaseName +
            ': queste colonne portano una scala su un tipo che non l''ammette,' +
            ' cioè il contratto di TEFDBColumnInfo non tiene:' + sLineBreak +
            LScales.Text);
          Assert.AreEqual(LSightingsExpected.Text, LSightings.Text, sLineBreak +
            ADatabaseName + ': the columns read back as DateTime or Currency ' +
            'are not the ones measured for this driver. Read back:' + sLineBreak +
            LInventory);
          Assert.AreEqual(LExpected.Text, LFound.Text, sLineBreak +
            ADatabaseName + ': the columns that cannot become a valid model ' +
            'field are not the ones measured. Read back:' + sLineBreak +
            LInventory);
        finally
          LScales.Free;
          LSightingsExpected.Free;
          LSightings.Free;
          LExpected.Free;
          LFound.Free;
        end;
      finally
        LDBInfo.Free;
      end;
    finally
      DropMatrixTestTable(LConnection);
    end;
  finally
    LConnection.Free;
  end;
end;

procedure TEFDBIntrospectionTests.ATimestampColumn_CarriesATimeAndIsIntrospectedAsDate(
  const ADatabaseName: string);
const
  // A time no rounding can turn into midnight.
  A_TIME = 13 / 24 + 45 / 1440 + 59 / 86400;
var
  LConnection: TEFDBConnection;
  LCommand: TEFDBCommand;
  LQuery: TEFDBQuery;
  LDBInfo: TEFDBInfo;
  LColumn: TEFDBColumnInfo;
  LWritten, LReadBack: TDateTime;
begin
  LConnection := OpenOrSkip(ADatabaseName);
  try
    DropMatrixTestTable(LConnection);
    LConnection.StartTransaction;
    try
      Execute(LConnection, MatrixTableDDL(ADatabaseName));
      LConnection.CommitTransaction;
    except
      LConnection.RollbackTransaction;
      raise;
    end;
    try
      LWritten := EncodeDate(2026, 9, 8) + A_TIME;
      LConnection.StartTransaction;
      try
        LCommand := LConnection.CreateDBCommand;
        try
          LCommand.CommandText := 'insert into ' + MATRIX_TABLE_NAME +
            ' (id, c_datetime) values (:id, :ts)';
          LCommand.Params.ParamByName('id').AsInteger := 1;
          LCommand.Params.ParamByName('ts').AsDateTime := LWritten;
          LCommand.Execute;
        finally
          LCommand.Free;
        end;
        LConnection.CommitTransaction;
      except
        LConnection.RollbackTransaction;
        raise;
      end;

      LQuery := LConnection.CreateDBQuery;
      try
        LQuery.CommandText := 'select c_datetime from ' + MATRIX_TABLE_NAME +
          ' where id = 1';
        LConnection.StartTransaction;
        try
          LQuery.Open;
          LConnection.CommitTransaction;
        except
          LConnection.RollbackTransaction;
          raise;
        end;
        Assert.IsFalse(LQuery.DataSet.Eof, ADatabaseName + ': no row came back.');
        LReadBack := LQuery.DataSet.Fields[0].AsDateTime;
      finally
        LQuery.Free;
      end;

      // Half one: the column carries a time. Whole seconds, so a backend that
      // keeps fewer fractional digits than another still matches.
      Assert.AreEqual(Round(LWritten * 86400), Round(LReadBack * 86400),
        Format('%s: the column did not keep the time that was written ' +
          '(wrote %s, read %s).', [ADatabaseName,
          FormatDateTime('yyyy-mm-dd hh:nn:ss', LWritten),
          FormatDateTime('yyyy-mm-dd hh:nn:ss', LReadBack)]));

      // Half two: introspection calls it a Date, so that is what a generated
      // Model declares over a column holding the time above.
      LDBInfo := LConnection.CreateDBInfo;
      try
        LColumn := LDBInfo.Schema.FindTable(MATRIX_TABLE_NAME).FindColumn('c_datetime');
        Assert.IsNotNull(LColumn, ADatabaseName + ': c_datetime was not read back.');
        Assert.AreEqual('Date', LColumn.DataType.GetTypeName, Format(
          '%s: introspection no longer calls a timestamp a Date. If it says ' +
          'DateTime now, the reading documented in ANALISI_R516.md has ' +
          'changed and the diff of every model that declares Date over such ' +
          'a column changes with it.', [ADatabaseName]));
      finally
        LDBInfo.Free;
      end;
    finally
      DropMatrixTestTable(LConnection);
    end;
  finally
    LConnection.Free;
  end;
end;

function TEFDBIntrospectionTests.OddRowInsert(const ADatabaseName: string): string;
var
  LFamily: string;
begin
  LFamily := MatrixFamily(ADatabaseName);
  if SameText(LFamily, 'MSSQL') then
    Result := 'insert into ' + MATRIX_TABLE_NAME +
      ' (id, c_bigint, c_money, c_smallmoney, c_binary, c_varbinary, c_datetime, ' +
      'c_smalldatetime, c_datetimeoffset, c_guid, c_sqlvariant, c_time7, c_xml) values (1, ' +
      '2147483648, 123456789012345.6789, 1234.5678, ' +
      '0x0102030405060708090A0B0C0D0E0F10, 0x00FF1020, ' +
      // Unseparated ymd and the ISO T form: the only spellings SQL Server reads
      // the same way whatever the session language.
      '''20260908 13:45:59'', ''20260908 13:45:00'', ''2026-09-08T13:45:59+02:00'', ' +
      '''0E984725-C51C-4BF4-9960-E1C80E27ABA0'', cast(42 as int), ''13:45:59.1234567'', ''<a/>'')'
  else if SameText(LFamily, 'Oracle') then
    Result := 'insert into ' + MATRIX_TABLE_NAME +
      ' (id, c_int, c_number_neg, c_number_nop, c_interval_ds, c_interval_ym, c_date, ' +
      'c_datetime, c_ts_tz, c_raw, c_rowid) values (1, ' +
      '1234567890, 12345, 12345.678901234567890123, ' +
      'INTERVAL ''1 02:03:04'' DAY TO SECOND, INTERVAL ''1-2'' YEAR TO MONTH, ' +
      'TO_DATE(''2026-09-08 13:45:59'', ''YYYY-MM-DD HH24:MI:SS''), ' +
      'TIMESTAMP ''2026-09-08 13:45:59'', TIMESTAMP ''2026-09-08 13:45:59 +02:00'', ' +
      'HEXTORAW(''00FF1020''), (select rowid from dual))'
  else if SameText(LFamily, 'Firebird') then
    Result := 'insert into ' + MATRIX_TABLE_NAME +
      ' (id, c_bigint, c_decfloat, c_decimal_nos, c_int128, c_binary, c_varbinary, ' +
      'c_datetime, c_time_tz, c_ts_tz) values (1, ' +
      '2147483648, 1234567890.123456, 123456789, 170141183460469231731687303715884105727, ' +
      'x''0102030405060708090A0B0C0D0E0F10'', x''00FF1020'', ' +
      '''2026-09-08 13:45:59'', ''13:45:59 +02:00'', ''2026-09-08 13:45:59 +02:00'')'
  else // PostgreSQL
    Result := 'insert into ' + MATRIX_TABLE_NAME +
      ' (id, c_bigint, c_money, c_interval, c_timetz, c_int_arr, c_datetime, ' +
      'c_datetimeoffset, c_guid, c_numeric_nop, c_json) values (1, ' +
      '2147483648, 123456789012345.6789::numeric::money, interval ''1 day 02:03:04'', ' +
      '''13:45:59+02'', ''{1,2,3}'', ''2026-09-08 13:45:59'', ''2026-09-08 13:45:59+02'', ' +
      '''0e984725-c51c-4bf4-9960-e1c80e27aba0'', 12345.678901234567890123, ''{"a":1}'')';
end;

function TEFDBIntrospectionTests.OddRowExpectations(const ADatabaseName: string): TArray<string>;
begin
  // 'column|Type|TField class|rendering' for the type introspection assigned,
  // 'column>Type|rendering' for the alternative type; measured on 8 September
  // 2026. A '*' stands for text that depends on the session -- the locale
  // FireDAC formats a time-zone value with, the counter inside a rowversion,
  // the address inside a ROWID.
  if SameText(ADatabaseName, 'MSSQL') then
    Result := [
      // A 64-bit value wraps through Integer and survives through Decimal.
      'c_bigint|Integer|TLargeintField|-2147483648',
      'c_bigint>Decimal|2147483648',
      // money arrives in a Double-backed field: 15 significant digits through
      // Decimal, and not the written cents through Currency either.
      'c_money|Decimal|TCurrencyField|123456789012346',
      // Which wrong cents depends on the compiler: see the 'double money,
      // Currency' case of ADecimalValue_ReadThroughDecimalOrCurrency.
      {$IFDEF CPUX64}
      'c_money>Currency|123456789012345.6768',
      {$ELSE}
      'c_money>Currency|123456789012345.6719',
      {$ENDIF}
      'c_smallmoney|Decimal|TCurrencyField|1234.5678',
      'c_smallmoney>Currency|1234.5678',
      // 16 bytes become 8 arbitrary UTF-16 characters.
      'c_binary|String|TBytesField|len=8:\u0201\u0403\u0605\u0807\u0A09\u0C0B\u0E0D\u100F',
      'c_varbinary|String|TVarBytesField|len=2:\uFF00\u2010',
      'c_datetime|Date|TSQLTimeStampField|2026-09-08 00:00:00',
      'c_datetime>DateTime|2026-09-08 13:45:59',
      'c_smalldatetime|Date|TSQLTimeStampField|2026-09-08 00:00:00',
      'c_smalldatetime>DateTime|2026-09-08 13:45:00',
      'c_datetimeoffset|String|TSQLTimeStampOffsetField|len=26:*13:45:59 +02:00',
      'c_guid|String|TGuidField|len=38:{0E984725-C51C-4BF4-9960-E1C80E27ABA0}',
      'c_xml|Memo|TFDXMLField|len=4:<a/>',
      'c_time7|Time|TTimeField|1899-12-30 13:45:59',
      'c_sqlvariant|Memo|TWideStringField|len=2:42',
      'c_rowversion|String|TBytesField|len=4:*']
  else if SameText(ADatabaseName, 'Firebird') then
    Result := [
      'c_bigint|Integer|TLargeintField|-2147483648',
      'c_bigint>Decimal|2147483648',
      'c_datetime|Date|TSQLTimeStampField|2026-09-08 00:00:00',
      'c_datetime>DateTime|2026-09-08 13:45:59',
      'c_decimal_nos|Integer|TIntegerField|123456789',
      // Exact BCD fields from the driver, 15 significant digits after EF: the
      // largest int128 (39 digits) and a 16-digit decfloat.
      'c_int128|Decimal|TFMTBCDField|170141183460469000000000000000000000000',
      'c_int128>Float|1.70141183460469E38',
      'c_decfloat|Decimal|TFMTBCDField|1234567890.12346',
      // Written 13:45:59 +02:00: the server hands back UTC and the zone is gone.
      'c_time_tz|Time|TTimeField|1899-12-30 11:45:59',
      'c_ts_tz|String|TSQLTimeStampOffsetField|len=26:*13:45:59 +02:00',
      'c_binary|String|TBytesField|len=8:\u0201\u0403\u0605\u0807\u0A09\u0C0B\u0E0D\u100F',
      'c_varbinary|String|TVarBytesField|len=2:\uFF00\u2010']
  else if SameText(ADatabaseName, 'Oracle') then
    Result := [
      'c_int|Decimal|TBCDField|1234567890',
      'c_raw|String|TVarBytesField|len=2:\uFF00\u2010',
      // Oracle DATE carries a time: written 13:45:59, read midnight through
      // Date and intact through DateTime.
      'c_date|Date|TDateTimeField|2026-09-08 00:00:00',
      'c_date>DateTime|2026-09-08 13:45:59',
      'c_datetime|Date|TSQLTimeStampField|2026-09-08 00:00:00',
      'c_datetime>DateTime|2026-09-08 13:45:59',
      'c_number_nop|Decimal|TFMTBCDField|12345.6789012346',
      // number(5,-2): the driver cannot even open the column.
      'c_number_neg|Decimal|OPEN FAILS EEFDBError',
      'c_ts_tz|String|TSQLTimeStampOffsetField|len=26:*13:45:59 +02:00',
      // 10 and 4 characters of text in columns introspected as String(2).
      'c_interval_ds|String|TFDSQLTimeIntervalField|len=10:1 02:03:04',
      'c_interval_ym|String|TFDSQLTimeIntervalField|len=4:1-02',
      'c_rowid|Memo|TStringField|len=18:*']
  else // PostgreSQL
    Result := [
      'c_bigint|Integer|TLargeintField|-2147483648',
      'c_bigint>Decimal|2147483648',
      // money is handed over as locale text with thousands separators, which
      // the driver cannot turn into a number: the column does not open.
      'c_money|Decimal|OPEN FAILS EEFDBError',
      'c_datetime|Date|TSQLTimeStampField|2026-09-08 00:00:00',
      'c_datetime>DateTime|2026-09-08 13:45:59',
      'c_datetimeoffset|String|TSQLTimeStampOffsetField|len=26:*',
      // Written 0e984725-c51c-4bf4-...: the first three groups come back with
      // their bytes reversed. Not the GUID that is in the table.
      'c_guid|String|TGuidField|len=38:{2547980E-1CC5-F44B-9960-E1C80E27ABA0}',
      'c_numeric_nop|Decimal|TFMTBCDField|12345.6789012346',
      'c_json|Memo|TWideMemoField|len=7:{"a":1}',
      'c_int_arr|Integer|TWideStringField|EXC EConvertError',
      'c_interval|Time|TFDSQLTimeIntervalField|EXC EDatabaseError',
      // Written 13:45:59+02: the zone is dropped, the clock time kept.
      'c_timetz|Time|TTimeField|1899-12-30 13:45:59'];
end;

function TEFDBIntrospectionTests.AlternativeReadings(const ADatabaseName: string): TArray<string>;
var
  LFamily: string;
begin
  LFamily := MatrixFamily(ADatabaseName);
  if SameText(LFamily, 'MSSQL') then
    Result := ['c_datetime>DateTime', 'c_smalldatetime>DateTime', 'c_bigint>Decimal',
      'c_money>Currency', 'c_smallmoney>Currency']
  else if SameText(LFamily, 'Oracle') then
    Result := ['c_date>DateTime', 'c_datetime>DateTime']
  else if SameText(LFamily, 'Firebird') then
    Result := ['c_datetime>DateTime', 'c_bigint>Decimal', 'c_int128>Float']
  else
    Result := ['c_datetime>DateTime', 'c_bigint>Decimal'];
end;

function TEFDBIntrospectionTests.RenderNode(const ADataType: TEFDataType;
  const ANode: TEFNode): string;
var
  LInv: TFormatSettings;
  LText: string;
  I: Integer;
begin
  LInv := TFormatSettings.Invariant;
  if ADataType is TEFIntegerDataType then
    Result := IntToStr(ANode.AsInteger)
  else if ADataType is TEFCurrencyDataType then
    Result := CurrToStr(ANode.AsCurrency, LInv)
  else if ADataType is TEFDecimalDataType then
    Result := BcdToStr(ANode.AsDecimal, LInv)
  else if ADataType is TEFFloatDataType then
    Result := FloatToStr(ANode.AsFloat, LInv)
  else if ADataType is TEFDateTimeDataTypeBase then
    Result := FormatDateTime('yyyy-mm-dd hh:nn:ss', ANode.AsDateTime, LInv)
  else if ADataType is TEFBooleanDataType then
    Result := BoolToStr(ANode.AsBoolean, True)
  else if ADataType is TEFBlobDataType then
    Result := Format('%d bytes', [Length(ANode.AsBytes)])
  else
  begin
    // String and Memo: the length, then the text with anything outside the
    // printable ASCII range escaped, so bytes read as text show for what they are.
    LText := ANode.AsString;
    Result := Format('len=%d:', [Length(LText)]);
    for I := 1 to Length(LText) do
      if (LText[I] < ' ') or (LText[I] > '~') then
        Result := Result + Format('\u%.4x', [Ord(LText[I])])
      else
        Result := Result + LText[I];
  end;
end;

/// <summary>True when some line of AList matches the mask (System.Masks: '*'
/// and '?').</summary>
function AnyMatches(const AList: TStrings; const AMask: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to AList.Count - 1 do
    if MatchesMask(AList[I], AMask) then
      Exit(True);
  Result := False;
end;

/// <summary>True when the line matches some mask in AMasks.</summary>
function AnyMaskMatches(const AMasks: TStrings; const ALine: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to AMasks.Count - 1 do
    if MatchesMask(ALine, AMasks[I]) then
      Exit(True);
  Result := False;
end;

function TEFDBIntrospectionTests.ReadThrough(const ADataType: TEFDataType;
  const AField: TField): string;
var
  LNode: TEFNode;
begin
  LNode := TEFNode.Create('v');
  try
    try
      ADataType.FieldValueToNode(AField, LNode);
      Result := RenderNode(ADataType, LNode);
    except
      on E: Exception do
        Result := 'EXC ' + E.ClassName;
    end;
  finally
    LNode.Free;
  end;
end;

procedure TEFDBIntrospectionTests.AValueInEachOddColumn_ReadThroughTheIntrospectedType(
  const ADatabaseName: string);
var
  LConnection: TEFDBConnection;
  LDBInfo: TEFDBInfo;
  LTable: TEFDBTableInfo;
  LQuery: TEFDBQuery;
  LField: TField;
  LColumn: TEFDBColumnInfo;
  LRead, LExpected, LDiff: TStringList;
  I: Integer;
  LOpenErrors, LAlternative: string;
  LAlternatives: TArray<string>;
  LAltType: TEFDataType;
begin
  LOpenErrors := '';
  LConnection := OpenOrSkip(ADatabaseName);
  try
    DropMatrixTestTable(LConnection);
    LConnection.StartTransaction;
    try
      Execute(LConnection, MatrixTableDDL(ADatabaseName));
      LConnection.CommitTransaction;
    except
      LConnection.RollbackTransaction;
      raise;
    end;
    try
      LConnection.StartTransaction;
      try
        Execute(LConnection, OddRowInsert(ADatabaseName));
        LConnection.CommitTransaction;
      except
        LConnection.RollbackTransaction;
        raise;
      end;

      LRead := TStringList.Create;
      LExpected := TStringList.Create;
      LDiff := TStringList.Create;
      LDBInfo := LConnection.CreateDBInfo;
      try
        LTable := LDBInfo.Schema.FindTable(MATRIX_TABLE_NAME);
        Assert.IsNotNull(LTable, ADatabaseName + ': the matrix table was not read back.');

        // One query per column: a column the driver cannot even open -- and
        // there are some -- is then a line of the measurement, not a wall in
        // front of all the others.
        for I := 0 to LTable.ColumnCount - 1 do
        begin
          LColumn := LTable.Columns[I];
          if SameText(LColumn.Name, 'id') then
            Continue;
          LQuery := LConnection.CreateDBQuery;
          try
            LQuery.CommandText := Format('select %s from %s where id = 1',
              [LColumn.Name, MATRIX_TABLE_NAME]);
            LConnection.StartTransaction;
            try
              try
                LQuery.Open;
              except
                on E: Exception do
                begin
                  LRead.Add(Format('%s|%s|OPEN FAILS %s', [LowerCase(LColumn.Name),
                    LColumn.DataType.GetTypeName, E.ClassName]));
                  LOpenErrors := LOpenErrors + Format('  %s: %s', [LColumn.Name,
                    E.Message]) + sLineBreak;
                  LConnection.RollbackTransaction;
                  Continue;
                end;
              end;
              LConnection.CommitTransaction;
            except
              LConnection.RollbackTransaction;
              raise;
            end;
            LField := LQuery.DataSet.Fields[0];
            if LField.IsNull then
              Continue;
            // The same call the store uses to fill a record from a dataset,
            // with the TField class the driver chose, since that is where a
            // value can lose digits before EF ever sees it.
            LRead.Add(Format('%s|%s|%s|%s', [LowerCase(LColumn.Name),
              LColumn.DataType.GetTypeName, LField.ClassName,
              ReadThrough(LColumn.DataType, LField)]));
            // And the same field through the alternative types, where one is listed.
            LAlternatives := AlternativeReadings(ADatabaseName);
            for LAlternative in LAlternatives do
              if StartsText(LowerCase(LColumn.Name) + '>', LAlternative) then
              begin
                LAltType := TEFDataTypeFactory.Instance.GetDataType(
                  Copy(LAlternative, Pos('>', LAlternative) + 1, MaxInt));
                LRead.Add(Format('%s|%s', [LAlternative, ReadThrough(LAltType, LField)]));
              end;
          finally
            LQuery.Free;
          end;
        end;

        LExpected.AddStrings(OddRowExpectations(ADatabaseName));
        for I := 0 to LExpected.Count - 1 do
          if not AnyMatches(LRead, LExpected[I]) then
            LDiff.Add('atteso, non letto:  ' + LExpected[I]);
        for I := 0 to LRead.Count - 1 do
          if not AnyMaskMatches(LExpected, LRead[I]) then
            LDiff.Add('letto, non atteso:  ' + LRead[I]);
        Assert.AreEqual('', LDiff.Text, sLineBreak + ADatabaseName +
          ': what the model sees has changed. Letto per intero:' + sLineBreak + LRead.Text +
          'Errori di apertura:' + sLineBreak + LOpenErrors +
          'Differenze:' + sLineBreak + LDiff.Text);
      finally
        LDBInfo.Free;
        LDiff.Free;
        LExpected.Free;
        LRead.Free;
      end;
    finally
      DropMatrixTestTable(LConnection);
    end;
  finally
    LConnection.Free;
  end;
end;

{ TEFDataTypeFieldReadingTests }

function TEFDataTypeFieldReadingTests.DateTimeDataSet(const AValue: TDateTime): TDataSet;
var
  LTable: TFDMemTable;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LTable.FieldDefs.Add('D', ftDateTime);
    LTable.CreateDataSet;
    LTable.Append;
    LTable.FieldByName('D').AsDateTime := AValue;
    LTable.Post;
    LTable.First;
    Result := LTable;
  except
    LTable.Free;
    raise;
  end;
end;

function TEFDataTypeFieldReadingTests.LargeIntDataSet(const AValue: Int64): TDataSet;
var
  LTable: TFDMemTable;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LTable.FieldDefs.Add('N', ftLargeint);
    LTable.CreateDataSet;
    LTable.Append;
    LTable.FieldByName('N').AsLargeInt := AValue;
    LTable.Post;
    LTable.First;
    Result := LTable;
  except
    LTable.Free;
    raise;
  end;
end;

function TEFDataTypeFieldReadingTests.DecimalDataSet(const AFieldType: TFieldType;
  const APrecision, AScale: Integer; const AValue: string): TDataSet;
var
  LTable: TFDMemTable;
  LDef: TFieldDef;
begin
  LTable := TFDMemTable.Create(nil);
  try
    LDef := LTable.FieldDefs.AddFieldDef;
    LDef.Name := 'M';
    LDef.DataType := AFieldType;
    if APrecision > 0 then
      LDef.Precision := APrecision;
    if AScale > 0 then
      LDef.Size := AScale;
    LTable.CreateDataSet;
    LTable.Append;
    // As a TBcd, so the field gets every digit of the literal and the only
    // conversions are the field's own and EF's.
    LTable.FieldByName('M').AsBCD := StrToBcd(AValue, TFormatSettings.Invariant);
    LTable.Post;
    LTable.First;
    Result := LTable;
  except
    LTable.Free;
    raise;
  end;
end;

function TEFDataTypeFieldReadingTests.Render(const ATypeName: string;
  const ANode: TEFNode): string;
var
  LInv: TFormatSettings;
begin
  LInv := TFormatSettings.Invariant;
  if SameText(ATypeName, 'Currency') then
    Result := CurrToStr(ANode.AsCurrency, LInv)
  else if SameText(ATypeName, 'Decimal') then
    Result := BcdToStr(ANode.AsDecimal, LInv)
  else
    Result := ANode.AsString;
end;

procedure TEFDataTypeFieldReadingTests.ADecimalType_ReadingTheSame64BitField_KeepsTheValue;
var
  LDataSet: TDataSet;
  LNode: TEFNode;
begin
  LDataSet := LargeIntDataSet(Int64(High(Integer)) + 1);
  try
    LNode := TEFNode.Create('v');
    try
      TEFDataTypeFactory.Instance.GetDataType('Decimal').FieldValueToNode(
        LDataSet.Fields[0], LNode);
      Assert.AreEqual('2147483648', BcdToStr(LNode.AsDecimal, TFormatSettings.Invariant),
        'Il tipo Decimal non conserva piu un valore a 64 bit.');
    finally
      LNode.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDataTypeFieldReadingTests.ADecimalValue_ReadThroughDecimalOrCurrency(
  const AFieldType: string; const APrecision, AScale: Integer;
  const AWritten, ATypeName, AExpected: string);
var
  LFieldType: TFieldType;
  LDataSet: TDataSet;
  LNode: TEFNode;
begin
  if SameText(AFieldType, 'ftFMTBcd') then
    LFieldType := ftFMTBcd
  else if SameText(AFieldType, 'ftBCD') then
    LFieldType := ftBCD
  else
    LFieldType := ftCurrency;
  LDataSet := DecimalDataSet(LFieldType, APrecision, AScale, AWritten);
  try
    LNode := TEFNode.Create('v');
    try
      TEFDataTypeFactory.Instance.GetDataType(ATypeName).FieldValueToNode(
        LDataSet.Fields[0], LNode);
      Assert.AreEqual(AExpected, Render(ATypeName, LNode), Format(
        '%s written to a %s, read through %s: not what was measured. If the ' +
        'value is now intact, ANALISI_R516.md must change.',
        [AWritten, LDataSet.Fields[0].ClassName, ATypeName]));
    finally
      LNode.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDataTypeFieldReadingTests.AnIntegerType_ReadingA64BitField_LosesWhatDoesNotFit;
var
  LDataSet: TDataSet;
  LNode: TEFNode;
  LScritto: Int64;
begin
  // Il primo valore che non entra in un Integer a 32 bit.
  LScritto := Int64(High(Integer)) + 1;
  LDataSet := LargeIntDataSet(LScritto);
  try
    LNode := TEFNode.Create('v');
    try
      TEFDataTypeFactory.Instance.GetDataType('Integer').FieldValueToNode(
        LDataSet.Fields[0], LNode);
      Assert.AreEqual(Low(Integer), LNode.AsInteger, Format(
        'Il tipo Integer non tronca piu un valore a 64 bit: ha letto %d da ' +
        '%d. Se ora lo conserva, la riga sul bigint di ANALISI_R516.md non ' +
        'vale piu.', [LNode.AsInteger, LScritto]));
    finally
      LNode.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDataTypeFieldReadingTests.ADateType_ReadingADateTimeField_DropsTheTime;
var
  LDataSet: TDataSet;
  LNode: TEFNode;
  LScritto: TDateTime;
begin
  LScritto := EncodeDate(2026, 9, 8) + 13 / 24 + 45 / 1440 + 59 / 86400;
  LDataSet := DateTimeDataSet(LScritto);
  try
    LNode := TEFNode.Create('v');
    try
      TEFDataTypeFactory.Instance.GetDataType('Date').FieldValueToNode(
        LDataSet.Fields[0], LNode);
      Assert.AreEqual(Round(EncodeDate(2026, 9, 8) * 86400),
        Round(LNode.AsDateTime * 86400), Format(
        'Il tipo Date non tronca più l''ora: ha letto %s. Se ora la conserva, ' +
        'la riga «l''ora si perde» di ANALISI_R516.md non vale più.',
        [FormatDateTime('yyyy-mm-dd hh:nn:ss', LNode.AsDateTime)]));
    finally
      LNode.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

procedure TEFDataTypeFieldReadingTests.ADateTimeType_ReadingTheSameField_KeepsIt;
var
  LDataSet: TDataSet;
  LNode: TEFNode;
  LScritto: TDateTime;
begin
  // Il controllo: sullo stesso campo il tipo DateTime porta via anche l'ora,
  // quindi la perdita è del tipo scelto e non della lettura del campo.
  LScritto := EncodeDate(2026, 9, 8) + 13 / 24 + 45 / 1440 + 59 / 86400;
  LDataSet := DateTimeDataSet(LScritto);
  try
    LNode := TEFNode.Create('v');
    try
      TEFDataTypeFactory.Instance.GetDataType('DateTime').FieldValueToNode(
        LDataSet.Fields[0], LNode);
      Assert.AreEqual(Round(LScritto * 86400), Round(LNode.AsDateTime * 86400),
        'Il tipo DateTime ha perso l''ora: allora il problema non è la scelta ' +
        'del tipo ma la lettura del campo.');
    finally
      LNode.Free;
    end;
  finally
    LDataSet.Free;
  end;
end;

{ TKModelFieldSpecTests }

function TKModelFieldSpecTests.ModelFromYaml(const AName, AYaml: string): TKModel;
begin
  Result := TKModel.Create;
  try
    Result.PersistentName := AName;
    TEFYAMLReader.ReadTree(Result, AYaml);
  except
    Result.Free;
    raise;
  end;
end;

procedure TKModelFieldSpecTests.ANegativeScaleInTheSpec_DoesNotReachTheFormatSettings;
var
  LModel: TKModel;
  LPrecision: Integer;
begin
  // The shape EveryColumnType_IsCheckedAgainstTheModelFieldRules measures on
  // PostgreSQL for a numeric with no precision: Decimal(0,-5).
  LModel := ModelFromYaml('Unconstrained',
    'ModelName: Unconstrained'#13#10 +
    'Fields:'#13#10 +
    '  Amount: Decimal(0, -5)'#13#10);
  try
    LPrecision := LModel.FieldByName('Amount').DecimalPrecision;
    Assert.IsTrue((LPrecision >= 0) and (LPrecision <= High(Byte)), Format(
      'A spec with a negative scale handed out %d, which is assigned to '+
      'TFormatSettings.CurrencyDecimals, a Byte.', [LPrecision]));
  finally
    LModel.Free;
  end;
end;

procedure TKModelFieldSpecTests.AGeneratedField_IsNotOneTheModelWrites;
var
  LModel: TKModel;
begin
  LModel := ModelFromYaml('Versioned',
    'ModelName: Versioned'#13#10 +
    'Fields:'#13#10 +
    '  Id: Integer not null primary key'#13#10 +
    '  Rv: String(8)'#13#10 +
    '    IsGenerated: True'#13#10);
  try
    Assert.IsTrue(LModel.FieldByName('Id').CanActuallyModify, 'The plain field is not writable.');
    Assert.IsFalse(LModel.FieldByName('Rv').CanActuallyModify,
      'A field marked IsGenerated is still one the model would write.');
  finally
    LModel.Free;
  end;
end;

procedure TKModelFieldSpecTests.ADecimalWithScaleZero_HandsOutTwoDecimals;
var
  LModel: TKModel;
begin
  LModel := ModelFromYaml('Scaleless',
    'ModelName: Scaleless'#13#10 +
    'Fields:'#13#10 +
    '  Amount: Decimal(16, 0)'#13#10);
  try
    Assert.AreEqual(2, LModel.FieldByName('Amount').DecimalPrecision,
      'A Decimal(16,0) no longer hands out 2 decimals; ANALISI_R516.md quotes this.');
  finally
    LModel.Free;
  end;
end;

procedure TKModelFieldSpecTests.ASizeOnATypeThatAdmitsNone_IsKeptByTheModel;
var
  LModel: TKModel;
  LField: TKModelField;
begin
  LModel := ModelFromYaml('Odd',
    'ModelName: Odd'#13#10 +
    'Fields:'#13#10 +
    '  Flag: Boolean(10)'#13#10);
  try
    // The premise is about the TYPE, taken from the factory: a field of a
    // catalogue-less model does not resolve its type from the spec (see
    // TKModelField.GetDataType), so asking the field would prove nothing.
    Assert.IsFalse(TEFDataTypeFactory.Instance.GetDataType('Boolean').HasSize,
      'Boolean declares a size: this case is about a type that does not.');
    LField := LModel.FieldByName('Flag');
    // È esattamente il caso che la regola del validatore intercetta:
    // un tipo senza dimensione che ne porta una.
    Assert.IsTrue((not TEFDataTypeFactory.Instance.GetDataType('Boolean').HasSize)
      and (LField.Size <> 0), 'Questo non è più il caso che il validatore ' +
      'segnala come «cannot have a size».');
    Assert.AreEqual(10, LField.Size, 'The model side stopped keeping the ' +
      'size a spec declares. If it now drops it, the contract has moved here ' +
      'too and ANALISI_R516.md needs updating.');
  finally
    LModel.Free;
  end;
end;

procedure TKModelFieldSpecTests.ASizedString_CarriesItsSize;
var
  LModel: TKModel;
begin
  LModel := ModelFromYaml('Sized',
    'ModelName: Sized'#13#10 +
    'Fields:'#13#10 +
    '  Name: String(50)'#13#10);
  try
    Assert.AreEqual(50, LModel.FieldByName('Name').Size,
      'The size in the field spec did not reach the field.');
  finally
    LModel.Free;
  end;
end;

procedure TKModelFieldSpecTests.ADecimal_PutsThePrecisionInSizeAndTheScaleInDecimalPrecision;
var
  LModel: TKModel;
begin
  LModel := ModelFromYaml('Money',
    'ModelName: Money'#13#10 +
    'Fields:'#13#10 +
    '  Amount: Decimal(12, 3)'#13#10);
  try
    Assert.AreEqual(12, LModel.FieldByName('Amount').Size, 'Lost the precision.');
    Assert.AreEqual(3, LModel.FieldByName('Amount').DecimalPrecision, 'Lost the scale.');
  finally
    LModel.Free;
  end;
end;

procedure TKModelFieldSpecTests.ATypeWithoutParentheses_HasNoSize;
var
  LModel: TKModel;
begin
  LModel := ModelFromYaml('Plain',
    'ModelName: Plain'#13#10 +
    'Fields:'#13#10 +
    '  Id: Integer'#13#10);
  try
    Assert.AreEqual(0, LModel.FieldByName('Id').Size,
      'A spec that declares no size produced one.');
  finally
    LModel.Free;
  end;
end;

procedure TKModelFieldSpecTests.TheSuffixes_LeaveTheSizeAlone;
var
  LModel: TKModel;
  LField: TKModelField;
begin
  LModel := ModelFromYaml('Suffixed',
    'ModelName: Suffixed'#13#10 +
    'Fields:'#13#10 +
    '  Code: String(8) not null primary key'#13#10);
  try
    LField := LModel.FieldByName('Code');
    Assert.AreEqual(8, LField.Size, 'The suffixes disturbed the size.');
    Assert.IsTrue(LField.IsRequired, 'not null was not read.');
    Assert.IsTrue(LField.IsKey, 'primary key was not read.');
  finally
    LModel.Free;
  end;
end;

procedure TKModelFieldSpecTests.AReference_HasNoSizeAndANonNegativeDecimalPrecision;
var
  LModel: TKModel;
  LField: TKModelField;
begin
  LModel := ModelFromYaml('Detail',
    'ModelName: Detail'#13#10 +
    'Fields:'#13#10 +
    '  Master: Reference(Master)'#13#10 +
    '    Fields:'#13#10 +
    '      MASTER_ID: Integer'#13#10);
  try
    LField := LModel.FieldByName('Master');
    Assert.AreEqual(0, LField.Size, 'A reference field was given a size.');
    Assert.IsTrue(LField.DecimalPrecision >= 0, Format(
      'A reference field handed out %d as its decimal precision. Anything ' +
      'negative reaches TFormatSettings.CurrencyDecimals, a Byte.',
      [LField.DecimalPrecision]));
  finally
    LModel.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TEFDBEngineTypeTests);
  TDUnitX.RegisterTestFixture(TEFDBAdapterRegistryTests);
  TDUnitX.RegisterTestFixture(TEFDBTableInfoTests);
  TDUnitX.RegisterTestFixture(TEFDBColumnInfoTests);
  TDUnitX.RegisterTestFixture(TEFDBFDKeyColumnsTests);
  TDUnitX.RegisterTestFixture(TEFDBIntrospectionTests);
  TDUnitX.RegisterTestFixture(TEFDataTypeFieldReadingTests);
  TDUnitX.RegisterTestFixture(TKModelFieldSpecTests);

end.
