{*******************************************************************}
{                                                                   }
{   KIDEX: GUI for KittoX                                           }
{                                                                   }
{   Copyright (c) 2012-2026 Ethea S.r.l.                            }
{   ALL RIGHTS RESERVED / TUTTI I DIRITTI RISERVATI                 }
{                                                                   }
{*******************************************************************}

/// <summary>
///   Headless helper that creates or refreshes a `Type: Tree` View
///   (typically `MainMenu.yaml`) listing every Model of the open
///   project as an inline AutoList entry under a top-level `Folder`
///   node named `Menu`. Idempotent: when the View already exists, the
///   existing entries are preserved and only the missing Models are
///   appended.
///
///   The same logic is invoked by:
///     * KIDE<sup>x</sup>'s **New TreeView...** action on the Views
///       folder (`KIDE.FileTree.TViewsFolderNodeHandler.ExecuteNewAction`)
///     * the MCP tool `menu_generate_main_menu`
///
///   Output shape (matching the existing wizard before the merge fix):
///   ```yaml
///   Type: Tree
///   Folder: Menu
///     View: Build AutoList
///       Model: <ModelName1>
///     View: Build AutoList
///       Model: <ModelName2>
///     ...
///   Folder: User                  # only added when creating from scratch
///     IsInitiallyCollapsed: True
///     View:
///       Controller: ChangePassword
///     View:
///       Controller: Logout
///   ```
/// </summary>
unit KIDE.Core.MenuGenerator;

interface

uses
  System.SysUtils,
  System.Classes,
  EF.Tree,
  Kitto.Metadata.Models,
  Kitto.Metadata.Views,
  KIDE.Project;

type
  /// <summary>
  ///   Outcome of a generate-or-update run. Caller-friendly summary
  ///   plus counts for the MCP tool's JSON response.
  /// </summary>
  TKXMenuGenerationResult = record
    /// <summary>Persistent name (no extension) of the View written
    /// to disk, e.g. 'MainMenu'.</summary>
    PersistentName: string;
    /// <summary>Absolute path of the YAML file written
    /// (Views/&lt;PersistentName&gt;.yaml).</summary>
    FileName: string;
    /// <summary>True when the View did not exist on disk and was
    /// created from scratch (a new `Folder: Menu` + a `Folder: User`
    /// scaffold were added). False when an existing View was updated
    /// in place.</summary>
    Created: Boolean;
    /// <summary>Count of Model entries that were already present in
    /// the `Folder: Menu` and therefore left untouched.</summary>
    KeptCount: Integer;
    /// <summary>Count of Model entries newly appended to the
    /// `Folder: Menu`.</summary>
    AddedCount: Integer;
    /// <summary>Total Models inspected (the size of
    /// `Config.Models`).</summary>
    ModelCount: Integer;
  end;

  TKXMenuGenerator = class
  private
    /// <summary>
    ///   Locates the first direct child whose Name is 'Folder' and
    ///   whose value (AsString) is `AFolderName`, returning nil if
    ///   absent. Used to find the canonical `Folder: Menu` and
    ///   `Folder: User` nodes.
    /// </summary>
    class function FindFolderNode(const ATree: TEFTree;
      const AFolderName: string): TEFNode; static;

    /// <summary>
    ///   Adds `View: Build AutoList \n Model: &lt;ModelName&gt;` as a
    ///   child of `AMenuFolder`. Mirrors the structure produced by
    ///   the original KIDE<sup>x</sup> action.
    /// </summary>
    class procedure AppendAutoListView(const AMenuFolder: TEFNode;
      const AModelName: string); static;

    /// <summary>
    ///   Returns the set of Model names already referenced from
    ///   immediate `View` children of `AMenuFolder`. Detects both
    ///   styles:
    ///     * `View: Build AutoList` + `Model: &lt;name&gt;` child
    ///     * `View: &lt;name&gt;` (reference style)
    ///   So we never duplicate an entry the user has hand-customized
    ///   into the reference style.
    /// </summary>
    class procedure CollectExistingModelNames(const AMenuFolder: TEFNode;
      const AList: TStrings); static;

    /// <summary>
    ///   Populates the standard `Folder: User` block (Logout +
    ///   ChangePassword). Only called when creating a new View; for
    ///   the merge path we leave the existing User folder untouched.
    /// </summary>
    class procedure AddUserFolder(const AView: TKView); static;
  public
    /// <summary>
    ///   Creates the View `APersistentName` (e.g. 'MainMenu') under
    ///   the open project's `Views/` folder, or updates it in place
    ///   if it already exists. In both cases each Model that is not
    ///   yet referenced from the `Folder: Menu` block gets an inline
    ///   `View: Build AutoList / Model: &lt;Name&gt;` entry appended.
    ///   The `Folder: User` block (Logout + ChangePassword) is added
    ///   only when the View is created from scratch.
    ///
    ///   Returns a summary record with counts and the resolved
    ///   file path.
    /// </summary>
    class function GenerateOrUpdate(
      const APersistentName: string): TKXMenuGenerationResult; static;
  end;

implementation

uses
  System.IOUtils,
  EF.StrUtils,
  Kitto.Config;

const
  FOLDER_NAME_MENU = 'Menu';
  FOLDER_NAME_USER = 'User';
  CONTROLLER_LOGOUT = 'Logout';
  CONTROLLER_CHANGEPWD = 'ChangePassword';
  BUILDER_AUTOLIST = 'Build AutoList';

{ TKXMenuGenerator }

class function TKXMenuGenerator.FindFolderNode(const ATree: TEFTree;
  const AFolderName: string): TEFNode;
var
  I: Integer;
  LChild: TEFNode;
begin
  Result := nil;
  // Iterate top-level children — the YAML structure flattens multiple
  // sibling Folder nodes into the root, distinguished by their value.
  for I := 0 to ATree.ChildCount - 1 do
  begin
    LChild := ATree.Children[I];
    if SameText(LChild.Name, 'Folder') and SameText(LChild.AsString, AFolderName) then
      Exit(LChild);
  end;
end;

class procedure TKXMenuGenerator.AppendAutoListView(const AMenuFolder: TEFNode;
  const AModelName: string);
var
  LViewNode, LModelNode: TEFNode;
begin
  Assert(Assigned(AMenuFolder));
  Assert(AModelName <> '');

  LViewNode := AMenuFolder.AddChild('View');
  LViewNode.AsString := BUILDER_AUTOLIST;
  LModelNode := LViewNode.AddChild('Model');
  LModelNode.AsString := AModelName;
end;

class procedure TKXMenuGenerator.CollectExistingModelNames(
  const AMenuFolder: TEFNode; const AList: TStrings);
var
  I: Integer;
  LChild, LModelNode: TEFNode;
  LRefName: string;
begin
  Assert(Assigned(AMenuFolder));
  Assert(Assigned(AList));

  for I := 0 to AMenuFolder.ChildCount - 1 do
  begin
    LChild := AMenuFolder.Children[I];
    if not SameText(LChild.Name, 'View') then
      Continue;

    // Style 1: `View: Build AutoList` + `Model: <name>` child
    if SameText(LChild.AsString, BUILDER_AUTOLIST) then
    begin
      LModelNode := LChild.FindNode('Model');
      if Assigned(LModelNode) and (LModelNode.AsString <> '') then
        AList.Add(LModelNode.AsString);
      Continue;
    end;

    // Style 2: `View: <ModelName>` (reference style — bare value).
    // Skip controller-only views (`View: \n Controller: Logout`)
    // which have an empty value but a Controller sub-node.
    LRefName := LChild.AsString;
    if (LRefName <> '') and not Assigned(LChild.FindNode('Controller')) then
      AList.Add(LRefName);
  end;
end;

class procedure TKXMenuGenerator.AddUserFolder(const AView: TKView);
var
  LFolderNode, LViewNode: TEFNode;
begin
  LFolderNode := AView.AddChild('Folder');
  LFolderNode.AsString := FOLDER_NAME_USER;
  LFolderNode.SetBoolean('IsInitiallyCollapsed', True);

  LViewNode := LFolderNode.AddChild('View');
  LViewNode.SetString('Controller', CONTROLLER_CHANGEPWD);

  LViewNode := LFolderNode.AddChild('View');
  LViewNode.SetString('Controller', CONTROLLER_LOGOUT);
end;

class function TKXMenuGenerator.GenerateOrUpdate(
  const APersistentName: string): TKXMenuGenerationResult;
var
  LProject: TProject;
  LViews: TKViews;
  LModels: TKModels;
  LExistingView, LNewView: TKView;
  LView: TKView;
  LMenuFolder: TEFNode;
  LExistingModelNames: TStringList;
  I: Integer;
  LModelName: string;
begin
  if APersistentName.Trim = '' then
    raise Exception.Create('menu_generate_main_menu: persistent_name is required');

  LProject := TProject.CurrentProject;
  if not Assigned(LProject) then
    raise Exception.Create('menu_generate_main_menu: no project is open');

  LViews := LProject.Config.Views;
  LModels := LProject.Config.Models;

  Result.PersistentName := APersistentName;
  Result.ModelCount := LModels.ModelCount;
  Result.KeptCount := 0;
  Result.AddedCount := 0;
  Result.Created := False;

  // Existing in-memory view? FindView matches by PersistentName
  // (case-insensitive). If the YAML is on disk and the project has
  // been refreshed since, the catalog already holds it.
  LExistingView := LViews.FindView(APersistentName);

  if Assigned(LExistingView) then
  begin
    // ---------- MERGE path ----------
    // Reuse the loaded TKView; modify in place; SaveObject rewrites
    // the YAML on disk. No AddObject (which would raise the "Oggetto
    // duplicato" error the user hit on overwrite from the dialog).
    LView := LExistingView;
    LMenuFolder := FindFolderNode(LView, FOLDER_NAME_MENU);
    if not Assigned(LMenuFolder) then
    begin
      // No "Menu" folder yet (e.g. the template-shipped MainMenu.yaml
      // has only the `Folder: User` block). Create it. It will be
      // appended after any existing folders — cosmetic ordering can
      // be fixed by hand in the YAML editor.
      LMenuFolder := LView.AddChild('Folder');
      LMenuFolder.AsString := FOLDER_NAME_MENU;
    end;
  end
  else
  begin
    // ---------- CREATE path ----------
    // Build from scratch: Type: Tree, then Folder: Menu (empty for
    // now — Models loop below fills it), then Folder: User. After
    // populating we AddObject + SaveObject. Wrap in try/except so a
    // mid-construction failure doesn't leak the partial TKView.
    LNewView := TKView.Create;
    try
      LNewView.PersistentName := APersistentName;
      LNewView.SetString('Type', 'Tree');
      LMenuFolder := LNewView.AddChild('Folder');
      LMenuFolder.AsString := FOLDER_NAME_MENU;
      AddUserFolder(LNewView);
      LViews.AddObject(LNewView);
    except
      LNewView.Free;
      raise;
    end;
    LView := LNewView;
    Result.Created := True;
  end;

  // Common: figure out which Models are already referenced under
  // Folder: Menu and append the missing ones.
  LExistingModelNames := TStringList.Create;
  try
    LExistingModelNames.CaseSensitive := False;
    LExistingModelNames.Duplicates := dupIgnore;
    LExistingModelNames.Sorted := True;  // enables fast IndexOf

    CollectExistingModelNames(LMenuFolder, LExistingModelNames);
    Result.KeptCount := LExistingModelNames.Count;

    for I := 0 to LModels.ModelCount - 1 do
    begin
      LModelName := LModels[I].ModelName;
      if LExistingModelNames.IndexOf(LModelName) < 0 then
      begin
        AppendAutoListView(LMenuFolder, LModelName);
        LExistingModelNames.Add(LModelName);
        Inc(Result.AddedCount);
      end;
    end;
  finally
    LExistingModelNames.Free;
  end;

  // Persist: overwrites the .yaml file on disk regardless of whether
  // we took the create or merge path.
  LViews.SaveObject(LView);
  Result.FileName := LView.PersistentFileName;
end;

end.
