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
///  Base data panel controller for KittoX. Provides CRUD action visibility
///  and ACL logic (same as ExtJS TKExtDataPanelController.SetViewTable).
///  Subclasses: TKXListPanelController, TKXFormPanelController.
/// </summary>
unit Kitto.Html.DataPanel;

{$I Kitto.Defines.inc}

interface

uses
  System.Generics.Collections,
  EF.YAML.Attributes,
  Kitto.Html.Panel,
  Kitto.Metadata.DataView;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXDataPanelController = class abstract(TKXPanelControllerBase)
  strict private
    FVisibleActions: TDictionary<string, Boolean>;
    FAllowedActions: TDictionary<string, Boolean>;
    FViewTable: TKViewTable;
    function GetPreventAdding: Boolean;
    function GetPreventEditing: Boolean;
    function GetPreventDeleting: Boolean;
    function GetAllowDuplicating: Boolean;
    function GetAllowViewing: Boolean;
  strict protected
    /// <summary>
    ///  Returns the ViewTable for the current DataView.
    ///  Resolves on first call from the View property.
    /// </summary>
    function GetViewTable: TKViewTable;

    /// <summary>
    ///  Override in subclasses to declare which action names are supported
    ///  (e.g. 'Add', 'Edit', 'Delete', 'View', 'Dup').
    ///  Default returns True for all standard actions.
    /// </summary>
    function IsActionSupported(const AActionName: string): Boolean; virtual;

    /// <summary>
    ///  Reads YAML config flags and populates the visibility/allowed dictionaries.
    ///  Called from DoDisplay. Mirrors ExtJS TKExtDataPanelController.SetViewTable logic.
    ///  Checks Config (direct + CenterController path), ViewTable.Controller path,
    ///  View.IsReadOnly, ViewTable.IsReadOnly, and ACL (IsAccessGranted).
    /// </summary>
    procedure InitActions; virtual;

    procedure DoDisplay; override;

    /// <summary>
    ///  Reads a Boolean config value checking both the direct Config path
    ///  and the CenterController subpath (for KittoX YAML compatibility).
    ///  Example: GetConfigBoolean('AllowViewing') checks Config/AllowViewing
    ///  then Config/CenterController/AllowViewing.
    /// </summary>
    function GetConfigBoolean(const APath: string;
      ADefault: Boolean = False): Boolean;
    function GetConfigString(const APath: string;
      const ADefault: string = ''): string;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;

    property ViewTable: TKViewTable read GetViewTable;

    /// <summary>Returns True if the action button should be visible.</summary>
    function IsActionVisible(const AActionName: string): Boolean;

    /// <summary>Returns True if the action is visible AND the user has ACL permission.</summary>
    function IsActionAllowed(const AActionName: string): Boolean;

    [YamlNode('PreventAdding', 'False', 'Hide the Add button')]
    property PreventAdding: Boolean read GetPreventAdding;
    [YamlNode('PreventEditing', 'False', 'Hide the Edit button')]
    property PreventEditing: Boolean read GetPreventEditing;
    [YamlNode('PreventDeleting', 'False', 'Hide the Delete button')]
    property PreventDeleting: Boolean read GetPreventDeleting;
    [YamlNode('AllowDuplicating', 'False', 'Show the Duplicate button')]
    property AllowDuplicating: Boolean read GetAllowDuplicating;
    [YamlNode('AllowViewing', 'False', 'Show the View (read-only) button')]
    property AllowViewing: Boolean read GetAllowViewing;
  end;

implementation

uses
  System.SysUtils,
  Kitto.AccessControl,
  Kitto.Metadata.Views;

{ TKXDataPanelController }

procedure TKXDataPanelController.AfterConstruction;
begin
  inherited;
  FVisibleActions := TDictionary<string, Boolean>.Create;
  FAllowedActions := TDictionary<string, Boolean>.Create;
end;

destructor TKXDataPanelController.Destroy;
begin
  FreeAndNil(FAllowedActions);
  FreeAndNil(FVisibleActions);
  inherited;
end;

function TKXDataPanelController.GetViewTable: TKViewTable;
begin
  if not Assigned(FViewTable) then
  begin
    if Assigned(View) and (View is TKDataView) then
      FViewTable := TKDataView(View).MainTable;
  end;
  Result := FViewTable;
end;

function TKXDataPanelController.GetConfigBoolean(const APath: string;
  ADefault: Boolean): Boolean;
begin
  // Check direct Config path first, then CenterController subpath
  Result := Config.GetBoolean(APath,
    Config.GetBoolean('CenterController/' + APath, ADefault));
end;

function TKXDataPanelController.GetConfigString(const APath: string;
  const ADefault: string): string;
begin
  Result := Config.GetString(APath,
    Config.GetString('CenterController/' + APath, ADefault));
end;

function TKXDataPanelController.IsActionSupported(const AActionName: string): Boolean;
begin
  // All standard CRUD actions are supported by default.
  // Subclasses can override to restrict (e.g. InplaceEditing hides Edit).
  Result := True;
end;

procedure TKXDataPanelController.InitActions;
var
  LIsReadOnly: Boolean;
  LVT: TKViewTable;
begin
  FVisibleActions.Clear;
  FAllowedActions.Clear;

  LVT := GetViewTable;
  if not Assigned(LVT) then
    Exit;

  LIsReadOnly := View.GetBoolean('IsReadOnly') or LVT.IsReadOnly;

  // Add � visible unless PreventAdding or read-only
  FVisibleActions.AddOrSetValue('Add',
    IsActionSupported('Add')
    and not LVT.GetBoolean('Controller/PreventAdding')
    and not GetConfigBoolean('PreventAdding')
    and not LIsReadOnly);
  FAllowedActions.AddOrSetValue('Add',
    FVisibleActions['Add'] and LVT.IsAccessGranted(ACM_ADD));

  // Dup � visible only if AllowDuplicating and not read-only
  FVisibleActions.AddOrSetValue('Dup',
    IsActionSupported('Dup')
    and (LVT.GetBoolean('Controller/AllowDuplicating')
      or GetConfigBoolean('AllowDuplicating'))
    and not LIsReadOnly);
  FAllowedActions.AddOrSetValue('Dup',
    FVisibleActions['Dup'] and LVT.IsAccessGranted(ACM_ADD));

  // Edit � visible unless PreventEditing or read-only
  FVisibleActions.AddOrSetValue('Edit',
    IsActionSupported('Edit')
    and not LVT.GetBoolean('Controller/PreventEditing')
    and not GetConfigBoolean('PreventEditing')
    and not LIsReadOnly);
  FAllowedActions.AddOrSetValue('Edit',
    FVisibleActions['Edit'] and LVT.IsAccessGranted(ACM_MODIFY));

  // Delete � visible unless PreventDeleting or read-only
  FVisibleActions.AddOrSetValue('Delete',
    IsActionSupported('Delete')
    and not LVT.GetBoolean('Controller/PreventDeleting')
    and not GetConfigBoolean('PreventDeleting')
    and not LIsReadOnly);
  FAllowedActions.AddOrSetValue('Delete',
    FVisibleActions['Delete'] and LVT.IsAccessGranted(ACM_DELETE));

  // View � visible only if AllowViewing
  FVisibleActions.AddOrSetValue('View',
    IsActionSupported('View')
    and (LVT.GetBoolean('Controller/AllowViewing')
      or GetConfigBoolean('AllowViewing')));
  FAllowedActions.AddOrSetValue('View',
    FVisibleActions['View'] and LVT.IsAccessGranted(ACM_VIEW));

  // Refresh — visible by default if actions are supported, hidden with PreventRefreshing
  FVisibleActions.AddOrSetValue('Refresh',
    IsActionSupported('Refresh')
    and not LVT.GetBoolean('Controller/PreventRefreshing')
    and not GetConfigBoolean('PreventRefreshing'));
  FAllowedActions.AddOrSetValue('Refresh', FVisibleActions['Refresh']);
end;

procedure TKXDataPanelController.DoDisplay;
begin
  InitActions;
  inherited;
end;

function TKXDataPanelController.GetPreventAdding: Boolean;
begin
  Result := GetConfigBoolean('PreventAdding');
end;

function TKXDataPanelController.GetPreventEditing: Boolean;
begin
  Result := GetConfigBoolean('PreventEditing');
end;

function TKXDataPanelController.GetPreventDeleting: Boolean;
begin
  Result := GetConfigBoolean('PreventDeleting');
end;

function TKXDataPanelController.GetAllowDuplicating: Boolean;
begin
  Result := GetConfigBoolean('AllowDuplicating');
end;

function TKXDataPanelController.GetAllowViewing: Boolean;
begin
  Result := GetConfigBoolean('AllowViewing');
end;

function TKXDataPanelController.IsActionVisible(const AActionName: string): Boolean;
begin
  if not FVisibleActions.TryGetValue(AActionName, Result) then
    Result := False;
end;

function TKXDataPanelController.IsActionAllowed(const AActionName: string): Boolean;
begin
  if not FAllowedActions.TryGetValue(AActionName, Result) then
    Result := False;
end;

end.
