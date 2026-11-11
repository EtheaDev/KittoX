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
///  The default model implementation. Provides TKDefaultModel, which performs
///  record I/O against a database through SQL, plus class helpers that let code
///  build models dynamically (add/delete fields and detail references).
/// </summary>
unit Kitto.Metadata.ModelImplementation;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  EF.Tree,
  Kitto.Metadata.Models,
  Kitto.Metadata.DataView;

type
  /// <summary>Class helper exposing mutation operations on a model field (used to
  /// build models dynamically).</summary>
  TKModelFieldHelper = class helper for TKModelField
  private
  public
    /// <summary>Sets the field's YAML spec string from the individual attributes
    /// (data type, size, scale, required, key, referenced model).</summary>
    procedure SetFieldSpec(const ADataType: string; const ASize, AScale: Integer;
      const AIsRequired, AIsKey: Boolean; const AReferencedModel: string);

    /// <summary>Sets or clears the primary-key flag in the field's spec.</summary>
    procedure SetIsKey(const AValue: Boolean);
    /// <summary>Adds AField as a sub-field of this field.</summary>
    procedure AddField(const AField: TKModelField);
    /// <summary>Removes and frees the given sub-field of this field.</summary>
    procedure DeleteField(const AField: TKModelField);
  end;

  /// <summary>Class helper exposing add/delete operations on a model's detail
  /// references (used to build models dynamically).</summary>
  TKModelDetailReferencesHelper = class helper for TKModelDetailReferences
  public
    /// <summary>Adds a detail reference to the collection.</summary>
    procedure AddDetailReference(const ADetailReference: TKModelDetailReference);
    /// <summary>Removes and frees the given detail reference.</summary>
    procedure DeleteDetailReference(const ADetailReference: TKModelDetailReference);
  end;

  /// <summary>
  ///  The default model implementation. Performs data I/O from a database
  ///  through SQL.
  /// </summary>
  { TODO : Refactor: SQL management should be moved out of the store and into this class. }
  TKDefaultModel = class(TKModel)
  strict protected
    procedure AddDetailReference(const ADetailReference: TKModelDetailReference);
    procedure DeleteDetailReference(const ADetailReference: TKModelDetailReference);
    function AddField(const AField: TKModelField): TKModelField; overload;
    /// <summary>
    ///  Helper method to add a field. Useful for dynamic models.
    /// </summary>
    function AddField(const AFieldName, ADataType: string;
      const ASize: Integer = 0; const AScale: Integer = 0;
      const AIsRequired: Boolean = False; const AIsKey: Boolean = False;
      const AReferencedModel: string = ''): TKModelField; overload;
    procedure DeleteField(const AField: TKModelField);
  strict protected
    /// <summary>
    ///  Loads requested records into the store. Override this method to add
    ///  custom additional behaviour (by calling inherited and then do something
    ///  else) or populate the store in a custom way (by not calling inherited).
    /// </summary>
    function InternalLoadRecords(const AStore: TKViewTableStore;
      const AFilter, ASort: string; const AStart, ALimit: Integer;
      const AForEachRecord: TProc<TKViewTableRecord>): Integer; virtual;
    /// <summary>
    ///  Saves all modified records in the specified store. Override this method to add
    ///  custom additional behaviour (by calling inherited and then do something
    ///  else) or persist the store in a custom way (by not calling inherited).
    /// </summary>
    procedure InternalSaveRecords(const AStore: TKViewTableStore;
      const APersist: Boolean; const AUseTransaction: Boolean; const AAfterPersist: TProc); virtual;
    /// <summary>
    ///  Called by SaveRecord just before applying any Before rules to the record.
    ///  This is called regardless of the value of SaveRecord's APersist argument.
    ///  Set ADoIt to False to prevent applying the rules.
    ///  The default implementation does nothing.
    /// </summary>
    procedure BeforeApplyBeforeRulesToRecord(const ARecord: TKViewTableRecord; var ADoIt: Boolean); virtual;
    /// <summary>
    ///  Called by SaveRecord just after applying any of the record's Before
    ///  rules (only if BeforeApplyBeforeRulesToRecord didn't set ADoIt to False).
    ///  The default implementation does nothing.
    /// </summary>
    procedure AfterApplyBeforeRulesToRecord(const ARecord: TKViewTableRecord); virtual;
    /// <summary>
    ///  Called by SaveRecord just before persisting the record (only if
    ///  SaveRecord's APersist argument is True).
    ///  Set ADoIt to False to prevent persisting the record.
    ///  The default implementation does nothing.
    /// </summary>
    procedure BeforePersistRecord(const ARecord: TKViewTableRecord; var AUseTransactions: Boolean; var ADoIt: Boolean); virtual;
    /// <summary>
    ///  Called by SaveRecord to persist the record (only if BeforePersistRecord
    ///  didn't set ADoIt to False).
    ///  The default implementation just calls the record's Save method.
    /// </summary>
    procedure PersistRecord(const ARecord: TKViewTableRecord; const AUseTransactions: Boolean); virtual;
    /// <summary>
    ///  Called by SaveRecord just after persisting the record (only if
    ///  BeforePersistRecord didn't set ADoIt to False).
    ///  The default implementation does nothing.
    /// </summary>
    procedure AfterPersistRecord(const ARecord: TKViewTableRecord; const AUseTransactions: Boolean); virtual;
    /// <summary>
    ///  Called by SaveRecord just before applying any After rules to the record.
    ///  This is called regardless of the value of SaveRecord's APersist argument.
    ///  Set ADoIt to False to prevent applying the rules.
    ///  The default implementation does nothing.
    /// </summary>
    procedure BeforeApplyAfterRulesToRecord(const ARecord: TKViewTableRecord; var ADoIt: Boolean); virtual;
    /// <summary>
    ///  Called by SaveRecord just after applying any of the record's After
    ///  rules (only if BeforeApplyAfterRulesToRecord didn't set ADoIt to False).
    ///  The default implementation does nothing.
    /// </summary>
    procedure AfterApplyAfterRulesToRecord(const ARecord: TKViewTableRecord); virtual;
  public
    /// <summary>
    ///  Requires that AStore is a TKViewTableStore and calls InternalLoadRecords.
    /// </summary>
    function LoadRecords(const AStore: TEFTree; const AFilterExpression: string;
      const ASortExpression: string; const AStart: Integer = 0; const ALimit: Integer = 0;
      const AForEachRecord: TProc<TEFNode> = nil): Integer; override;

    /// <summary>
    ///  Requires that AStore is a TKViewTableStore and calls InternalSaveRecords.
    /// </summary>
    procedure SaveRecords(const AStore: TEFTree; const APersist: Boolean;
      const AAfterPersist: TProc; const AUseTransaction: Boolean = True); override;

    /// <summary>
    ///  Persists the specified record. Calls various protected virtual methods.
    /// </summary>
    procedure SaveRecord(const ARecord: TEFNode; const APersist: Boolean;
      const AAfterPersist: TProc; const AUseTransaction: Boolean = True); override;
  end;

implementation

uses
  System.TypInfo,
  EF.DB,
  EF.Localization,
  EF.Logger,
  Kitto.Config,
  // For EKValidationError: a refusal the user can act on, not a failure.
  Kitto.Rules,
  KItto.SQL,
  Kitto.Store,
  Kitto.Types;

{ TKModelFieldHelper }

procedure TKModelFieldHelper.SetIsKey(const AValue: Boolean);
var
  LDataType: string;
  LSize, LScale: Integer;
  LIsRequired: Boolean;
  LIsKey: Boolean;
  LReferencedModel: string;
begin
  GetFieldSpec(LDataType, LSize, LScale, LIsRequired, LIsKey, LReferencedModel);
  SetFieldSpec(LDataType, LSize, LScale, LIsRequired, AValue, LReferencedModel);
end;

procedure TKModelFieldHelper.AddField(const AField: TKModelField);
begin
  Assert(Assigned(AField), 'Assigned(AField)');

  GetFields.AddChild(AField);
end;

procedure TKModelFieldHelper.DeleteField(const AField: TKModelField);
begin
  Assert(Assigned(AField), 'Assigned(AField)');

  GetFields.RemoveChild(AField);
end;

procedure TKModelFieldHelper.SetFieldSpec(const ADataType: string;
  const ASize, AScale: Integer; const AIsRequired: Boolean; const AIsKey: Boolean;
  const AReferencedModel: string);
var
  LSpec: string;
begin
  LSpec := ADataType;
  if AReferencedModel <> '' then
    LSpec := LSpec + '(' + AReferencedModel + ')'
  else if ASize <> 0 then
  begin
    LSpec := LSpec + '(' + IntToStr(ASize);
    if AScale > 0 then
      LSpec := LSpec + ', ' + IntToStr(AScale);
    LSpec := LSpec + ')';
  end;
  if AIsRequired then
    LSpec := LSpec + ' not null';
  if AIsKey then
    LSpec := LSpec + ' primary key';
  AsString := LSpec;
end;

{ TKModelDetailReferencesHelper }

procedure TKModelDetailReferencesHelper.AddDetailReference(
  const ADetailReference: TKModelDetailReference);
begin
  Assert(Assigned(ADetailReference), 'Assigned(ADetailReference)');

  AddChild(ADetailReference);
end;

procedure TKModelDetailReferencesHelper.DeleteDetailReference(
  const ADetailReference: TKModelDetailReference);
begin
  Assert(Assigned(ADetailReference), 'Assigned(ADetailReference)');

  RemoveChild(ADetailReference);
end;

{ TKDefaultModel }

procedure TKDefaultModel.AddDetailReference(
  const ADetailReference: TKModelDetailReference);
begin
  Assert(Assigned(ADetailReference), 'Assigned(ADetailReference)');

  GetDetailReferences.AddDetailReference(ADetailReference);
end;

function TKDefaultModel.AddField(const AFieldName, ADataType: string;
  const ASize, AScale: Integer; const AIsRequired, AIsKey: Boolean;
  const AReferencedModel: string): TKModelField;
begin
  Result := AddField(TKModelField.Create(AFieldName));
  Result.SetFieldSpec(ADataType, ASize, AScale, AIsRequired, AIsKey, AReferencedModel);
end;

function TKDefaultModel.AddField(const AField: TKModelField): TKModelField;
begin
  Assert(Assigned(AField), 'Assigned(AField)');

  Result := GetFields.AddChild(AField) as TKModelField;
end;

procedure TKDefaultModel.DeleteDetailReference(
  const ADetailReference: TKModelDetailReference);
begin
  Assert(Assigned(ADetailReference), 'Assigned(ADetailReference)');

  GetDetailReferences.DeleteDetailReference(ADetailReference);
end;

procedure TKDefaultModel.DeleteField(const AField: TKModelField);
begin
  Assert(Assigned(AField), 'Assigned(AField)');

  GetFields.RemoveChild(AField);
end;

function TKDefaultModel.LoadRecords(const AStore: TEFTree;
  const AFilterExpression, ASortExpression: string; const AStart, ALimit: Integer;
  const AForEachRecord: TProc<TEFNode>): Integer;
begin
  Assert(Assigned(AStore), 'Assigned(AStore)');
  Assert(AStore is TKViewTableStore, 'AStore is TKViewTableStore');

  Result := InternalLoadRecords(TKViewTableStore(AStore), AFilterExpression, ASortExpression, AStart, ALimit,
    procedure (ARecord: TKViewTableRecord)
    begin
      if Assigned(AForEachRecord) then
        AForEachRecord(ARecord);
      ARecord.MarkAsClean;
    end);
end;

function TKDefaultModel.InternalLoadRecords(const AStore: TKViewTableStore;
  const AFilter, ASort: string; const AStart, ALimit: Integer;
  const AForEachRecord: TProc<TKViewTableRecord>): Integer;
begin
  Assert(Assigned(AStore), 'Assigned(AStore)');

  Result := AStore.Load(AFilter, ASort, AStart, ALimit, AForEachRecord);
end;

procedure TKDefaultModel.AfterApplyAfterRulesToRecord(const ARecord: TKViewTableRecord);
begin
end;

procedure TKDefaultModel.AfterApplyBeforeRulesToRecord(const ARecord: TKViewTableRecord);
begin
end;

procedure TKDefaultModel.AfterPersistRecord(const ARecord: TKViewTableRecord;
  const AUseTransactions: Boolean);
begin
end;

procedure TKDefaultModel.BeforeApplyAfterRulesToRecord(
  const ARecord: TKViewTableRecord; var ADoIt: Boolean);
begin
end;

procedure TKDefaultModel.BeforeApplyBeforeRulesToRecord(
  const ARecord: TKViewTableRecord; var ADoIt: Boolean);
begin
end;

procedure TKDefaultModel.BeforePersistRecord(const ARecord: TKViewTableRecord;
  var AUseTransactions, ADoIt: Boolean);
begin
end;

procedure TKDefaultModel.PersistRecord(const ARecord: TKViewTableRecord;
  const AUseTransactions: Boolean);
var
  LDBCommand: TEFDBCommand;
  LRowsAffected: Integer;
  LDBConnection: TEFDBConnection;

  procedure PersistDetailStores;
  var
    I: Integer;
  begin
    for I := 0 to ARecord.DetailStoreCount - 1 do
      ARecord.DetailStores[I].ViewTable.Model.SaveRecords(ARecord.DetailStores[I], True, nil);
  end;

  /// <summary>
  ///  The detail stores of this record whose relation declares CascadeDelete,
  ///  loaded from the database. Empty when none does.
  /// </summary>
  function LoadCascadingDetailStores: TArray<TKViewTableStore>;
  var
    I: Integer;
    LStore: TKViewTableStore;
    LDetailReference: TKModelDetailReference;
  begin
    Result := [];
    // The detail stores follow the VIEW's detail tables (see
    // TKViewTableRecord.EnsureDetailStores), so a relation the view does not
    // mention is not cascaded and the database refuses the delete instead.
    ARecord.EnsureDetailStores;
    for I := 0 to ARecord.DetailStoreCount - 1 do
    begin
      LStore := TKViewTableStore(ARecord.DetailStores[I]);
      if not LStore.ViewTable.IsDetail then
        Continue;
      LDetailReference := LStore.ViewTable.ModelDetailReference;
      if not Assigned(LDetailReference) or not LDetailReference.CascadeDelete then
        Continue;
      // Deleting a row needs the row: the delete path never loaded the details,
      // it only ever had the master.
      LStore.Load;
      Result := Result + [LStore];
    end;
  end;

  /// <summary>
  ///  Deletes the rows of every detail that declares CascadeDelete, before the
  ///  master's own delete, so the foreign keys are satisfied when it runs.
  ///  Each of those deletes goes through SaveRecords and lands back here, so a
  ///  detail's own details cascade too, deepest first.
  /// </summary>
  procedure CascadeDeleteDetails;
  var
    LStore: TKViewTableStore;
    LStores: TArray<TKViewTableStore>;
    J: Integer;
  begin
    LStores := LoadCascadingDetailStores;
    for LStore in LStores do
    begin
      for J := 0 to LStore.RecordCount - 1 do
        if LStore.Records[J].State <> rsDeleted then
        begin
          LStore.Records[J].ApplyBeforeRules;
          LStore.Records[J].MarkAsDeleted;
        end;
      // Inside the master's transaction: InternalSaveRecords starts one only
      // when not in one already, so a failure anywhere rolls the whole back.
      LStore.ViewTable.Model.SaveRecords(LStore, True, nil);
    end;
  end;

  /// <summary>
  ///  Turns a refused delete into something the person in front of the screen
  ///  can understand: which record, and what still refers to it.
  /// </summary>
  /// <remarks>
  ///  Deliberately silent on how to change that: whether a master takes its
  ///  details with it is a data-model decision, not something to ask an end
  ///  user. The engine's own words name the constraint that refused, which
  ///  diagnosis needs and a user does not, so they go to the log instead.
  /// </remarks>
  function DeleteRefusedMessage(const AOriginal: string): string;
  var
    I: Integer;
    LStore: TKViewTableStore;
    LWhat, LWho: string;
    LTotal: Integer;
    LCaptionField: TKModelField;
    LCaption: TKViewTableField;
  begin
    TEFLogger.Instance.LogFmt('Delete refused on %s: %s',
      [ARecord.Store.ViewTable.ModelName, AOriginal], TEFLogger.LOG_LOW);

    LWhat := '';
    LTotal := 0;
    try
      ARecord.EnsureDetailStores;
      for I := 0 to ARecord.DetailStoreCount - 1 do
      begin
        LStore := TKViewTableStore(ARecord.DetailStores[I]);
        if not LStore.ViewTable.IsDetail then
          Continue;
        LStore.Load;
        if LStore.RecordCount > 0 then
        begin
          Inc(LTotal, LStore.RecordCount);
          if LWhat <> '' then
            LWhat := LWhat + ', ';
          // One row is not "1 Invitations".
          if LStore.RecordCount = 1 then
            LWhat := LWhat + Format('%d %s', [1, LStore.ViewTable.DisplayLabel])
          else
            LWhat := LWhat + Format('%d %s', [LStore.RecordCount,
              LStore.ViewTable.PluralDisplayLabel]);
        end;
      end;
    except
      // Counting is a courtesy: if it fails, the original message still goes
      // out.
      on E: Exception do
        LWhat := '';
    end;

    if LWhat = '' then
      Exit(AOriginal);

    // Name the record the user was looking at, not just its kind.
    LWho := ARecord.Store.ViewTable.DisplayLabel;
    LCaptionField := ARecord.Store.ViewTable.Model.FindCaptionField;
    if Assigned(LCaptionField) then
    begin
      LCaption := ARecord.FindField(
        ARecord.Store.ViewTable.ApplyFieldAliasedName(LCaptionField.FieldName));
      if Assigned(LCaption) and not LCaption.IsNull and (LCaption.AsString <> '') then
        LWho := LWho + ' "' + LCaption.AsString + '"';
    end;

    // Two whole sentences rather than one with a spliced-in verb, which a
    // translator could not inflect.
    if LTotal = 1 then
      Result := Format(_('%s cannot be deleted: %s still refers to it.'),
        [LWho, LWhat])
    else
      Result := Format(_('%s cannot be deleted: %s still refer to it.'),
        [LWho, LWhat]);
  end;

  /// <summary>
  ///  Gives a field drawn from a sequence its value, if it is still empty at
  ///  INSERT time. The value is normally drawn when the record is created,
  ///  through the default values (TKViewField.AppendDefaultValues): this
  ///  covers the paths that create a record without them.
  /// </summary>
  procedure AssignMissingSequenceValues;
  var
    I: Integer;
    LViewField: TKViewField;
    LField: TKViewTableField;
  begin
    for I := 0 to ARecord.ViewTable.FieldCount - 1 do
    begin
      LViewField := ARecord.ViewTable.Fields[I];
      if not LViewField.IsSequenced then
        Continue;
      LField := ARecord.FindField(LViewField.AliasedName);
      if Assigned(LField) and LField.IsNull then
        LField.Value := LDBConnection.FetchSequenceGeneratorValue(
          LViewField.ModelField.Sequence);
    end;
  end;

begin
  Assert(Assigned(ARecord), 'Assigned(ARecord)');

  if ARecord.State = rsClean then
  begin
    // If the record is not dirty, we don't need to persist it - still we may
    // have dirty detail records.
    PersistDetailStores;
    Exit;
  end;

  // Take care of any instructions to clear fields.
  ARecord.HandleSetToNullInstructions;

  // BEFORE rules are applied before calling this method.
  LDBConnection := TKConfig.DatabaseFor(ARecord.Store.ViewTable.DatabaseName);
  if AUseTransactions then
    LDBConnection.StartTransaction;
  try
    // Before the master's own delete, and inside its transaction.
    if ARecord.State = rsDeleted then
      CascadeDeleteDetails;

    if ARecord.State = rsNew then
      AssignMissingSequenceValues;

    LDBCommand := LDBConnection.CreateDBCommand;
    try
      TKSQLBuilder.CreateAndExecute(
        procedure (ASQLBuilder: TKSQLBuilder)
        begin
          case ARecord.State of
            rsNew: ASQLBuilder.BuildInsertCommand(LDBCommand, ARecord);
            rsDirty: ASQLBuilder.BuildUpdateCommand(LDBCommand, ARecord);
            rsDeleted: ASQLBuilder.BuildDeleteCommand(LDBCommand, ARecord);
          else
            raise EKError.CreateFmt('Unexpected record state %s.', [GetEnumName(TypeInfo(TKRecordState), Ord(ARecord.State))]);
          end;
        end);
      if LDBCommand.CommandText <> '' then
      begin
        if ARecord.State = rsDeleted then
        begin
          // A refused delete is almost always a foreign key, reported by
          // constraint name. Say which record and what still holds it.
          try
            LRowsAffected := LDBCommand.Execute;
          except
            on E: Exception do
              // EKValidationError, not EKError: the request filter renders
              // a rule error as a warning and anything else as an error, and
              // the REST layer answers 422 for it.
              raise EKValidationError.Create(DeleteRefusedMessage(E.Message));
          end;
        end
        else
          LRowsAffected := LDBCommand.Execute;
        if LRowsAffected <> 1 then
          raise EKError.CreateFmt('Update error. Rows affected: %d.', [LRowsAffected]);
      end;
      PersistDetailStores;
      ARecord.ApplyAfterRules;
      if AUseTransactions then
        LDBConnection.CommitTransaction;
      // Take care of any cleared external files.
      ARecord.HandleDeleteFileInstructions;
      ARecord.MarkAsClean;
    finally
      FreeAndNil(LDBCommand);
    end;
  except
    if AUseTransactions then
      LDBConnection.RollbackTransaction;
    raise;
  end;
end;

procedure TKDefaultModel.SaveRecord(const ARecord: TEFNode;
  const APersist: Boolean; const AAfterPersist: TProc;
  const AUseTransaction: Boolean = True);
var
  LRecord: TKViewTableRecord;
  LUseTransactions: Boolean;
  LDoIt: Boolean;
begin
  inherited;
  Assert(Assigned(ARecord), 'Assigned(ARecord)');
  Assert(ARecord is TKViewTableRecord, 'ARecord is TKViewTableRecord');

  LRecord := TKViewTableRecord(ARecord);

  LDoIt := True;
  BeforeApplyBeforeRulesToRecord(LRecord, LDoIt);
  if LDoIt then
  begin
    LRecord.ApplyBeforeRules;
    AfterApplyBeforeRulesToRecord(LRecord);
  end;

  if APersist then
  begin
    LUseTransactions := AUseTransaction;
    LDoIt := True;
    BeforePersistRecord(LRecord, LUseTransactions, LDoIt);
    if LDoIt then
    begin
      PersistRecord(LRecord, LUseTransactions);
      AfterPersistRecord(LRecord, LUseTransactions);
      if Assigned(AAfterPersist) then
        AAfterPersist;
    end;
  end;

  LDoIt := True;
  BeforeApplyAfterRulesToRecord(LRecord, LDoIt);
  if LDoIt then
  begin
    LRecord.ApplyAfterRules;
    AfterApplyAfterRulesToRecord(LRecord);
  end;
end;

procedure TKDefaultModel.SaveRecords(const AStore: TEFTree;
  const APersist: Boolean; const AAfterPersist: TProc;
  const AUseTransaction: Boolean = True);
begin
  Assert(Assigned(AStore), 'Assigned(AStore)');
  Assert(AStore is TKViewTableStore, 'AStore is TKViewTableStore');

  InternalSaveRecords(TKViewTableStore(AStore), APersist, AUseTransaction, AAfterPersist);
end;

procedure TKDefaultModel.InternalSaveRecords(const AStore: TKViewTableStore;
  const APersist: Boolean; const AUseTransaction: Boolean; const AAfterPersist: TProc);
var
  I: Integer;
  LDBConnection: TEFDBConnection;
  LUseTransaction: Boolean;
begin
  LDBConnection := TKConfig.DatabaseFor(AStore.ViewTable.DatabaseName);
  if AUseTransaction then
    LDBConnection.StartTransaction;
  try
    //Save any record in a single transaction only if the connection is not is transaction
    LUseTransaction := not LDBConnection.IsInTransaction;
    for I := 0 to AStore.RecordCount - 1 do
      SaveRecord(AStore.Records[I], APersist, AAfterPersist, LUseTransaction);
    if AUseTransaction then
      LDBConnection.CommitTransaction;
  except
    if AUseTransaction then
      LDBConnection.RollbackTransaction;
    raise;
  end;
end;

initialization
  TKModels.DefaultModelClassType := TKDefaultModel;
  //TKModelRegistry.Instance.RegisterClass('Model', TKDefaultModel);

finalization
  //TKModelRegistry.Instance.UnregisterClass('Model');
  TKModels.ResetDefaultModelClassType;

end.
