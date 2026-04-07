{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   This file is part of KittoX Enterprise Edition.
   Licensed under the AGPL-3.0 or Ethea Commercial License.
   See LICENSE-ENTERPRISE for details.
-------------------------------------------------------------------------------}

/// <summary>
///  KittoX CalendarPanel controller � renders an EventCalendar interactive
///  calendar with month/week/day views and CRUD integration.
///  Supports color-coded event types and date-range auto-fetching.
/// </summary>
unit Kitto.Html.CalendarPanel;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.DataPanel,
  Kitto.Html.Controller,
  Kitto.Metadata.DataView,
  EF.YAML.Attributes;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXCalendarPanelController = class(TKXDataPanelController)
  strict private
    FViewName: string;
    function GetCalendarFieldName(const AMapping, ADefault: string): string;
    function GetDefaultView: string;
    function GetSlotMinTime: string;
    function GetSlotMaxTime: string;
    function GetEventTemplate: string;
    function BuildEventTypesJson: string;
    function BuildCalendarToolbar: string;
  strict protected
    function GetDefaultIsModal: Boolean; override;
    function GetPanelCssClass: string; override;
    function IsActionSupported(const AActionName: string): Boolean; override;
    procedure DoDisplay; override;
    function RenderContent: string; override;
  public
    const CALENDAR_COLORS: array[0..9] of string = (
      '#1a73e8', '#e67c73', '#33b679', '#f4511e', '#7986cb',
      '#8e24aa', '#039be5', '#616161', '#d50000', '#f09300'
    );
    /// <summary>
    ///  Escapes a string value for JSON output (adds surrounding double quotes).
    /// </summary>
    class function JSONStr(const AValue: string): string;

    [YamlNode('DefaultView', 'timeGridWeek', 'Initial calendar view: dayGridMonth, timeGridWeek, timeGridDay')]
    property DefaultView: string read GetDefaultView;
    [YamlNode('SlotMinTime', '00:00', 'Earliest time displayed in week/day views')]
    property SlotMinTime: string read GetSlotMinTime;
    [YamlNode('SlotMaxTime', '24:00', 'Latest time displayed in week/day views')]
    property SlotMaxTime: string read GetSlotMaxTime;
    [YamlNode('EventTemplate', '', 'HTML template file for custom event rendering')]
    property EventTemplate: string read GetEventTemplate;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.NetEncoding,
  EF.Tree,
  EF.Localization,
  Kitto.Config,
  Kitto.Html.Base,
  Kitto.Html.Utils,
  Kitto.Web.Routing.Scripts;

{ TKXCalendarPanelController }

function TKXCalendarPanelController.GetDefaultIsModal: Boolean;
begin
  Result := False;
end;

function TKXCalendarPanelController.GetPanelCssClass: string;
begin
  Result := 'kx-calendar-panel';
end;

function TKXCalendarPanelController.IsActionSupported(const AActionName: string): Boolean;
begin
  Result := MatchText(AActionName, ['Add', 'Edit', 'Delete', 'View']);
end;

procedure TKXCalendarPanelController.DoDisplay;
begin
  inherited;
  if Assigned(View) then
    FViewName := View.PersistentName
  else
    FViewName := '';
end;

class function TKXCalendarPanelController.JSONStr(const AValue: string): string;
begin
  Result := StringReplace(AValue, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13#10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\n', [rfReplaceAll]);
  Result := '"' + Result + '"';
end;

function TKXCalendarPanelController.GetCalendarFieldName(
  const AMapping, ADefault: string): string;
var
  LModelNode: TEFNode;
begin
  // Read mapping from MainTable/Model node (e.g. CalendarId: EventId)
  if Assigned(View) then
  begin
    LModelNode := View.FindNode('MainTable/Model');
    if Assigned(LModelNode) then
    begin
      Result := LModelNode.GetString(AMapping, '');
      if Result <> '' then
        Exit;
    end;
  end;
  // Fall back to default field name
  Result := ADefault;
end;

function TKXCalendarPanelController.GetDefaultView: string;
begin
  Result := GetConfigString('DefaultView', 'timeGridWeek');
end;

function TKXCalendarPanelController.GetSlotMinTime: string;
begin
  Result := GetConfigString('SlotMinTime', '00:00');
end;

function TKXCalendarPanelController.GetSlotMaxTime: string;
begin
  Result := GetConfigString('SlotMaxTime', '24:00');
end;

function TKXCalendarPanelController.GetEventTemplate: string;
begin
  Result := GetConfigString('EventTemplate', '');
end;

function TKXCalendarPanelController.BuildEventTypesJson: string;
var
  LEventTypeFieldName: string;
  LStore: TKViewTableStore;
  I, LColorIdx: Integer;
  LRecord: TKViewTableRecord;
  LRecordField: TKViewTableField;
  LValue: string;
  LDistinct: TStringList;
  SB: TStringBuilder;
begin
  Result := '{}';
  LEventTypeFieldName := GetCalendarFieldName('CalendarEventType', 'EventType');

  if not Assigned(ViewTable) then
    Exit;
  if ViewTable.FindFieldByAliasedName(LEventTypeFieldName) = nil then
    Exit;

  // Load all records to find distinct event types
  LStore := ViewTable.CreateStore;
  try
    LStore.Load('', '', 0, 0);
    LDistinct := TStringList.Create;
    try
      LDistinct.Sorted := True;
      LDistinct.Duplicates := dupIgnore;
      for I := 0 to LStore.RecordCount - 1 do
      begin
        LRecord := LStore.Records[I];
        LRecordField := LRecord.FindField(LEventTypeFieldName);
        if Assigned(LRecordField) and not LRecordField.IsNull then
        begin
          LValue := LRecordField.AsString;
          if LValue <> '' then
            LDistinct.Add(LValue);
        end;
      end;

      if LDistinct.Count = 0 then
        Exit;

      SB := TStringBuilder.Create;
      try
        SB.Append('{');
        for I := 0 to LDistinct.Count - 1 do
        begin
          if I > 0 then
            SB.Append(', ');
          LColorIdx := I mod Length(CALENDAR_COLORS);
          SB.Append(JSONStr(LDistinct[I])).Append(': ')
            .Append(JSONStr(CALENDAR_COLORS[LColorIdx]));
        end;
        SB.Append('}');
        Result := SB.ToString;
      finally
        SB.Free;
      end;
    finally
      LDistinct.Free;
    end;
  finally
    FreeAndNil(LStore);
  end;
end;

function TKXCalendarPanelController.BuildCalendarToolbar: string;
var
  LDisplayLabel: string;
  LConfirmTitle, LConfirmMsg, LYesLabel, LNoLabel: string;
  LShowLabels: Boolean;
  SB: TStringBuilder;

  procedure AppendToolbarButton(const AAction, ATooltip, AIconName, AOnClick: string;
    ARequiresSelection: Boolean);
  begin
    if not IsActionVisible(AAction) then
      Exit;
    SB.Append('<button class="kx-toolbar-btn');
    if ARequiresSelection then
      SB.Append(' kx-cal-requires-selection');
    SB.Append('"');
    if not IsActionAllowed(AAction) then
      SB.Append(' disabled');
    SB.Append(' title="').Append(TNetEncoding.HTML.Encode(ATooltip)).Append('"');
    SB.Append(' onclick="').Append(AOnClick).Append('"');
    SB.Append('>').Append(GetIconHTML(AIconName));
    if LShowLabels then
      SB.Append(' <span class="kx-btn-label">').Append(TNetEncoding.HTML.Encode(_(AAction))).Append('</span>');
    SB.Append('</button>');
  end;

begin
  Result := '';
  if not Assigned(ViewTable) then
    Exit;

  LDisplayLabel := _(ViewTable.DisplayLabel);
  LShowLabels := not SameText(GetConfigString('ToolButtonScale', 'small'), 'small');

  LConfirmTitle := ReplaceStr(_('Confirm'), '''', '\''');
  LConfirmMsg := Format(_('Selected %s will be deleted. Are you sure?'), [LDisplayLabel]);
  LConfirmMsg := ReplaceStr(LConfirmMsg, '''', '\''');
  LYesLabel := ReplaceStr(_('Yes'), '''', '\''');
  LNoLabel := ReplaceStr(_('No'), '''', '\''');

  SB := TStringBuilder.Create;
  try
    SB.Append('<div class="kx-list-toolbar" id="kx-cal-toolbar-').Append(FViewName).Append('">');

    // Add (no selection required)
    AppendToolbarButton('Add',
      ViewTable.GetString('Controller/Add/Tooltip', Format(_('Add %s'), [LDisplayLabel])),
      'new_record',
      'kxCalendar.openAddForm(''' + FViewName + ''')',
      False);

    // Edit (requires selection from calendar)
    AppendToolbarButton('Edit',
      ViewTable.GetString('Controller/Edit/Tooltip', Format(_('Edit %s'), [LDisplayLabel])),
      'edit_record',
      'kxCalendar.openEditForm(''' + FViewName + ''')',
      True);

    // Delete (requires selection, with confirmation)
    AppendToolbarButton('Delete',
      ViewTable.GetString('Controller/Delete/Tooltip', Format(_('Delete %s'), [LDisplayLabel])),
      'delete_record',
      'kxCalendar.deleteEvent(''' + FViewName + ''',''' +
        LConfirmTitle + ''',''' + LConfirmMsg + ''',''' +
        LYesLabel + ''',''' + LNoLabel + ''')',
      True);

    // View (requires selection)
    AppendToolbarButton('View',
      ViewTable.GetString('Controller/View/Tooltip', Format(_('View %s'), [LDisplayLabel])),
      'view_record',
      'kxCalendar.openViewForm(''' + FViewName + ''')',
      True);

    SB.Append('</div>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXCalendarPanelController.RenderContent: string;
var
  LDefaultView, LSlotMinTime, LSlotMaxTime: string;
  LEventTypesJson: string;
  SB: TStringBuilder;
begin
  Result := '';
  if not Assigned(View) or not (View is TKDataView) then
    Exit;
  if not Assigned(ViewTable) then
    Exit;

  // Read calendar options from Config (CenterController node)
  LDefaultView := GetConfigString('DefaultView', 'timeGridWeek');
  LSlotMinTime := GetConfigString('SlotMinTime', '00:00');
  LSlotMaxTime := GetConfigString('SlotMaxTime', '24:00');

  // Build event type color map
  LEventTypesJson := BuildEventTypesJson;

  SB := TStringBuilder.Create;
  try
    // Toolbar with CRUD buttons
    SB.Append(BuildCalendarToolbar);

    // Calendar container
    SB.Append('<div id="kx-calendar-').Append(FViewName)
      .Append('" class="kx-calendar-container"></div>');

    // Initialization script
    SB.Append('<script>kxCalendar.init(').Append(JSONStr(FViewName)).Append(', {');
    SB.Append('view: ').Append(JSONStr(LDefaultView));
    SB.Append(', dataUrl: ''kx/view/').Append(FViewName).Append('/calendar-data''');
    SB.Append(', slotMinTime: ').Append(JSONStr(LSlotMinTime));
    SB.Append(', slotMaxTime: ').Append(JSONStr(LSlotMaxTime));
    SB.Append(', allowAdd: ').Append(IfThen(IsActionAllowed('Add'), 'true', 'false'));
    SB.Append(', allowEdit: ').Append(IfThen(IsActionAllowed('Edit'), 'true', 'false'));
    SB.Append(', allowView: ').Append(IfThen(IsActionAllowed('View'), 'true', 'false'));
    SB.Append(', eventTypes: ').Append(LEventTypesJson);
    SB.Append('});</script>');

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('CalendarPanel', TKXCalendarPanelController);
  TKXScriptRegistry.Instance.RegisterStylesheet('/css/event-calendar.min.css');
  TKXScriptRegistry.Instance.RegisterScript('/js/event-calendar.min.js');

finalization
  TKXControllerRegistry.Instance.UnregisterClass('CalendarPanel');

end.
