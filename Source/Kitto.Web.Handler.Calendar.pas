{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   This file is part of KittoX Enterprise Edition.
   Licensed under the AGPL-3.0 or Ethea Commercial License.
   See LICENSE-ENTERPRISE for details.
-------------------------------------------------------------------------------}

unit Kitto.Web.Handler.Calendar;

{$I Kitto.Defines.inc}
{$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}

interface

uses
  Kitto.Web.Routing.Attributes,
  Kitto.Metadata.DataView;

type
  [TKXPath('/kx/view/{ViewName}')]
  TKXCalendarHandler = class
  public
    [TKXPath('/calendar-data')]
    [TKXGET]
    procedure HandleCalendarData(
      [TKXPathParam('ViewName')] const AViewName: string;
      [TKXQueryParam('start')] const AStartParam: string;
      [TKXQueryParam('end')] const AEndParam: string;
      [TKXContext] ADataView: TKDataView);
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  System.NetEncoding,
  Data.DB,
  EF.Tree,
  EF.DB,
  EF.SQL,
  Kitto.SQL,
  Kitto.Config,
  Kitto.Metadata.Views,
  Kitto.Store,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Html.CalendarPanel,
  Kitto.Web.Routing.Registry;

procedure TKXCalendarHandler.HandleCalendarData(const AViewName: string;
  const AStartParam, AEndParam: string; ADataView: TKDataView);
var
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LModelNode: TEFNode;
  LCalendarIdField, LStartDateField, LEndDateField: string;
  LTitleField, LEventTypeField, LEventNotesField: string;
  LHasDateRange: Boolean;
  LStartViewField, LEndViewField: TKViewField;
  LStartExpr, LEndExpr: string;
  LDBConnection: TEFDBConnection;
  LDBQuery: TEFDBQuery;
  LCommandText, LDateFilter: string;
  I, J: Integer;
  LRecord: TKViewTableRecord;
  LRecordField: TKViewTableField;
  LIdValue, LTitleValue, LStartValue, LEndValue, LTypeValue, LNotesValue: string;
  LKeyString: string;
  LKeyField: TKViewField;
  LFmt: TFormatSettings;
  LEventTypesMap: TDictionary<string, Integer>;
  LTypeIdx: Integer;
  LColor: string;
  SB, SBKey: TStringBuilder;
begin
  Assert(Assigned(ADataView), 'ADataView Assigned');
  Assert(Assigned(ADataView.MainTable), 'ADataView.MainTable Assigned');

  LViewTable := ADataView.MainTable;

  // Read calendar field mappings
  LModelNode := ADataView.FindNode('MainTable/Model');
  if Assigned(LModelNode) then
  begin
    LCalendarIdField := LModelNode.GetString('CalendarId', '');
    LStartDateField := LModelNode.GetString('CalendarStartDate', 'StartDate');
    LEndDateField := LModelNode.GetString('CalendarEndDate', 'EndDate');
    LTitleField := LModelNode.GetString('CalendarTitle', 'Title');
    LEventTypeField := LModelNode.GetString('CalendarEventType', 'EventType');
    LEventNotesField := LModelNode.GetString('CalendarEventNotes', 'EventNotes');
  end
  else
  begin
    LStartDateField := 'StartDate';
    LEndDateField := 'EndDate';
    LTitleField := 'Title';
    LEventTypeField := 'EventType';
    LEventNotesField := 'EventNotes';
    LCalendarIdField := '';
  end;

  if LViewTable.FindFieldByAliasedName(LEventNotesField) = nil then
    LEventNotesField := '';

  if LCalendarIdField = '' then
    for I := 0 to LViewTable.FieldCount - 1 do
      if LViewTable.Fields[I].IsKey then
      begin
        LCalendarIdField := LViewTable.Fields[I].AliasedName;
        Break;
      end;

  LHasDateRange := (AStartParam <> '') and (AEndParam <> '');

  if LHasDateRange then
  begin
    LStartViewField := LViewTable.FindFieldByAliasedName(LStartDateField);
    LEndViewField := LViewTable.FindFieldByAliasedName(LEndDateField);
    if Assigned(LStartViewField) then
      LStartExpr := LStartViewField.ModelField.DBColumnNameOrExpression
    else
      LStartExpr := LStartDateField;
    if Assigned(LEndViewField) then
      LEndExpr := LEndViewField.ModelField.DBColumnNameOrExpression
    else
      LEndExpr := LEndDateField;
    LStartExpr := StringReplace(LStartExpr, '{Q}',
      LViewTable.Model.DBTableName + '.', [rfReplaceAll]);
    LEndExpr := StringReplace(LEndExpr, '{Q}',
      LViewTable.Model.DBTableName + '.', [rfReplaceAll]);
  end;

  LFmt := TFormatSettings.Create;
  LFmt.DateSeparator := '-';
  LFmt.TimeSeparator := ':';
  LFmt.ShortDateFormat := 'yyyy-mm-dd';
  LFmt.LongTimeFormat := 'hh:nn:ss';

  LEventTypesMap := TDictionary<string, Integer>.Create;
  LStore := LViewTable.CreateStore;
  SB := TStringBuilder.Create;
  SBKey := TStringBuilder.Create;
  try
    LDBConnection := TKConfig.Instance.CreateDBConnection(LViewTable.DatabaseName);
    try
      LDBQuery := LDBConnection.CreateDBQuery;
      try
        TKSQLBuilder.CreateAndExecute(
          procedure (ASQLBuilder: TKSQLBuilder)
          begin
            ASQLBuilder.BuildSelectQuery(LViewTable, '', '', LDBQuery, nil);
          end);

        if LHasDateRange then
        begin
          LCommandText := LDBQuery.CommandText;
          if LEndDateField <> LStartDateField then
            LDateFilter := '(' + LStartExpr + ' < :cal_end) and ' +
              '((' + LEndExpr + ' >= :cal_start) or (' + LEndExpr + ' is null))'
          else
            LDateFilter := '(' + LStartExpr + ' < :cal_end) and ' +
              '(' + LStartExpr + ' >= :cal_start)';
          LCommandText := AddToSQLWhereClause(LCommandText, LDateFilter);
          LDBQuery.CommandText := LCommandText;
          LDBQuery.Params.CreateParam(ftDateTime, 'cal_start', ptInput);
          LDBQuery.Params.CreateParam(ftDateTime, 'cal_end', ptInput);
          LDBQuery.Params.ParamByName('cal_start').AsDateTime :=
            StrToDateTime(StringReplace(Copy(AStartParam, 1, 19), 'T', ' ', []), LFmt);
          LDBQuery.Params.ParamByName('cal_end').AsDateTime :=
            StrToDateTime(StringReplace(Copy(AEndParam, 1, 19), 'T', ' ', []), LFmt);
        end;

        LStore.Load(LDBQuery, False, False, nil);
      finally
        FreeAndNil(LDBQuery);
      end;
    finally
      FreeAndNil(LDBConnection);
    end;

    SB.Append('[');
    for I := 0 to LStore.RecordCount - 1 do
    begin
      LRecord := LStore.Records[I];
      if I > 0 then
        SB.Append(',');

      LRecordField := LRecord.FindField(LCalendarIdField);
      if Assigned(LRecordField) and not LRecordField.IsNull then
        LIdValue := LRecordField.AsString
      else
        LIdValue := IntToStr(I);

      LRecordField := LRecord.FindField(LTitleField);
      if Assigned(LRecordField) and not LRecordField.IsNull then
        LTitleValue := LRecordField.AsString
      else
        LTitleValue := '';

      LRecordField := LRecord.FindField(LStartDateField);
      if Assigned(LRecordField) and not LRecordField.IsNull then
        LStartValue := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', LRecordField.AsDateTime, LFmt)
      else
        LStartValue := '';

      LRecordField := LRecord.FindField(LEndDateField);
      if Assigned(LRecordField) and not LRecordField.IsNull then
        LEndValue := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', LRecordField.AsDateTime, LFmt)
      else
        LEndValue := '';

      LNotesValue := '';
      if LEventNotesField <> '' then
      begin
        LRecordField := LRecord.FindField(LEventNotesField);
        if Assigned(LRecordField) and not LRecordField.IsNull then
          LNotesValue := LRecordField.AsString;
      end;

      LColor := '#1a73e8';
      LRecordField := LRecord.FindField(LEventTypeField);
      if Assigned(LRecordField) and not LRecordField.IsNull then
      begin
        LTypeValue := LRecordField.AsString;
        if not LEventTypesMap.TryGetValue(LTypeValue, LTypeIdx) then
        begin
          LTypeIdx := LEventTypesMap.Count;
          LEventTypesMap.Add(LTypeValue, LTypeIdx);
        end;
        LColor := TKXCalendarPanelController.CALENDAR_COLORS[
          LTypeIdx mod Length(TKXCalendarPanelController.CALENDAR_COLORS)];
      end;

      SBKey.Clear;
      for J := 0 to LViewTable.FieldCount - 1 do
      begin
        LKeyField := LViewTable.Fields[J];
        if LKeyField.IsKey then
        begin
          LRecordField := LRecord.FindField(LKeyField.AliasedName);
          if Assigned(LRecordField) then
          begin
            if SBKey.Length > 0 then
              SBKey.Append('&');
            SBKey.Append(TNetEncoding.URL.Encode(LKeyField.AliasedName));
            SBKey.Append('=');
            SBKey.Append(TNetEncoding.URL.Encode(LRecordField.AsString));
          end;
        end;
      end;
      LKeyString := SBKey.ToString;

      SB.Append('{');
      SB.Append('"id":').Append(TKXCalendarPanelController.JSONStr(LIdValue));
      SB.Append(',"title":').Append(TKXCalendarPanelController.JSONStr(LTitleValue));
      if LStartValue <> '' then
        SB.Append(',"start":').Append(TKXCalendarPanelController.JSONStr(LStartValue));
      if LEndValue <> '' then
        SB.Append(',"end":').Append(TKXCalendarPanelController.JSONStr(LEndValue));
      SB.Append(',"backgroundColor":').Append(TKXCalendarPanelController.JSONStr(LColor));
      SB.Append(',"extendedProps":{"key":').Append(TKXCalendarPanelController.JSONStr(LKeyString));
      if LNotesValue <> '' then
        SB.Append(',"notes":').Append(TKXCalendarPanelController.JSONStr(LNotesValue));
      SB.Append('}');
      SB.Append('}');
    end;
    SB.Append(']');

    TKWebResponse.Current.Items.Clear;
    TKWebResponse.Current.Items.AddHTML(SB.ToString);
    TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
  finally
    SBKey.Free;
    SB.Free;
    FreeAndNil(LStore);
    LEventTypesMap.Free;
  end;
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXCalendarHandler);

finalization
  TKXResourceRegistry.Instance.UnregisterResource(TKXCalendarHandler);

end.
