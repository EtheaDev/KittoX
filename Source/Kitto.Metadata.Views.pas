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

unit Kitto.Metadata.Views;

{$I Kitto.Defines.inc}

interface

uses
  System.Types,
  System.Classes,
  System.Generics.Collections,
  EF.Classes,
  EF.Types,
  EF.Tree,
  EF.Intf,
  EF.YAML.Attributes,
  Kitto.Metadata,
  Kitto.Metadata.Models,
  Kitto.Metadata.Types,
  Kitto.Store,
  Kitto.Rules;

type
  TKViews = class;

  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKView = class(TKMetadata)
  strict private
    function GetControllerType: string;
    function GetCatalog: TKViews;
  strict protected
    const DEFAULT_IMAGE_NAME = 'default_view';
    function GetDisplayLabel: string; virtual;
    function GetImageName: string; virtual;
    function GetDefaultImageName: string; virtual;
    class function GetClassNameForResourceURI: string; override;
  public
    /// <summary>The views catalog this view belongs to.</summary>
    property Catalog: TKViews read GetCatalog;

    [YamlNode('DisplayLabel', '', 'Label shown in navigation and titles', True)]
    property DisplayLabel: string read GetDisplayLabel;
    /// <summary>The default icon name when ImageName is not set.</summary>
    property DefaultImageName: string read GetDefaultImageName;
    [YamlNode('ImageName', 'Icon name for navigation and titles')]
    property ImageName: string read GetImageName;

    [YamlNode('Controller', 'Controller type name')]
    property ControllerType: string read GetControllerType;
  end;

  TKViewClass = class of TKView;

  TKViewList = class(TList<TKView>)
  public
    /// <summary>Adds the name of each view in the list to AStrings.</summary>
    procedure AddViewNamesToStrings(const AStrings: TStrings);
  end;

  TKLayouts = class;

  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  [YamlChildType('Field', '', 'Form field')]
  [YamlChildType('FieldSet', '', 'Grouped fieldset')]
  [YamlChildType('Row', '', 'Horizontal row of fields')]
  [YamlChildType('Pagebreak', '', 'Page break in layout')]
  TKLayout = class(TKMetadata)
  private
    FLayouts: TKLayouts;
    function GetLabelAlign: string;
    function GetLabelWidth: Integer;
    function GetMsgTarget: string;
    function GetLabelPad: Integer;
    function GetMemoWidth: Integer;
    function GetMaxFieldWidth: Integer;
    function GetMinFieldWidth: Integer;
    function GetRequiredLabelTemplate: string;
    function GetLabelSeparator: string;
  public
    /// <summary>True if the layout is a grid layout (its name ends with '_Grid').</summary>
    function IsGridLayout: Boolean;
    /// <summary>True if the layout is a form layout (its name ends with '_Form').</summary>
    function IsFormLayout: Boolean;

    [YamlNode('LabelAlign', 'Top', 'Label position relative to form fields (Top/Left/Right)')]
    property LabelAlign: string read GetLabelAlign;
    [YamlNode('LabelWidth', '120', 'Width in pixels for field labels')]
    property LabelWidth: Integer read GetLabelWidth;
    [YamlNode('MsgTarget', 'Title', 'Where validation messages are displayed (Title/Under)')]
    property MsgTarget: string read GetMsgTarget;
    [YamlNode('LabelPad', '0', 'Padding in pixels between label and field')]
    property LabelPad: Integer read GetLabelPad;
    [YamlNode('MemoWidth', '60', 'Default width in characters for memo fields')]
    property MemoWidth: Integer read GetMemoWidth;
    [YamlNode('MaxFieldWidth', '60', 'Maximum field width in characters')]
    property MaxFieldWidth: Integer read GetMaxFieldWidth;
    [YamlNode('MinFieldWidth', '5', 'Minimum field width in characters')]
    property MinFieldWidth: Integer read GetMinFieldWidth;
    [YamlNode('RequiredLabelTemplate', '<b>{label}*</b>', 'HTML template for required field labels')]
    property RequiredLabelTemplate: string read GetRequiredLabelTemplate;
    [YamlNode('LabelSeparator', ':', 'String appended after field labels')]
    property LabelSeparator: string read GetLabelSeparator;
  end;

  TKLayoutClass = class of TKLayout;

  /// <summary>
  ///  A catalog of views.
  /// </summary>
  TKViews = class(TKMetadataCatalog)
  strict private
    FLayouts: TKLayouts;
    FModels: TKModels;
    function GetLayouts: TKLayouts;
    function BuildView(const ANode: TEFNode;
      const AViewBuilderName: string): TKView;
    function GetView(I: Integer): TKView;
    function GetViewCount: Integer;
  strict protected
    function GetObjectClassType: TKMetadataClass; override;
    procedure SetPath(const AValue: string); override;
    function GetMetadataRegistry: TKMetadataRegistry; override;
  public
    /// <summary>Creates the views catalog bound to the given models catalog.</summary>
    constructor Create(const AModels: TKModels);
    destructor Destroy; override;
  public
    /// <summary>Number of views in the catalog.</summary>
    property ViewCount: Integer read GetViewCount;
    /// <summary>The views, by index (default property).</summary>
    property Views[I: Integer]: TKView read GetView; default;
    /// <summary>Returns the view with the given name; raises if absent.</summary>
    function ViewByName(const AName: string): TKView; overload;
    /// <summary>Returns the first existing view among the given names; raises if none.</summary>
    function ViewByName(const ANames: TStringDynArray): TKView; overload;
    /// <summary>Returns the view with the given name, or nil.</summary>
    function FindView(const AName: string): TKView;

    /// <summary>Returns the view referenced/built from the given node; raises if absent.</summary>
    function ViewByNode(const ANode: TEFNode): TKView;
    /// <summary>Returns the view referenced/built from the given node, or nil.</summary>
    function FindViewByNode(const ANode: TEFNode): TKView;

    /// <summary>
    ///  Reads the Views/ directory from disk and fills AList with all
    ///  views found. AList is cleared first. If the catalog is not yet
    ///  open it calls Open; if already open it calls Refresh, so each
    ///  call reflects the current on-disk state.
    /// </summary>
    procedure GetViewList(const AList: TKViewList);

    /// <summary>The models catalog the views refer to.</summary>
    property Models: TKModels read FModels;
    /// <summary>The layouts catalog associated with these views.</summary>
    property Layouts: TKLayouts read GetLayouts;
    /// <summary>Opens the catalog (loads views from the Views/ directory).</summary>
    procedure Open; override;
    /// <summary>Re-reads the catalog from disk.</summary>
    procedure Refresh; override;
    /// <summary>Closes the catalog and releases loaded views.</summary>
    procedure Close; override;
  end;

  TKLayoutList = class(TList<TKLayout>)
  end;

  /// <summary>
  ///  A catalog of layouts. Internally used by the catalog of views.
  /// </summary>
  TKLayouts = class(TKMetadataCatalog)
  strict private
    function GetLayout(I: Integer): TKLayout;
    function GetLayoutCount: Integer;
  strict protected
    procedure AfterCreateObject(const AObject: TKMetadata); override;
    function GetObjectClassType: TKMetadataClass; override;
    function GetMetadataRegistry: TKMetadataRegistry; override;
  public
    /// <summary>Number of layouts in the catalog.</summary>
    property LayoutCount: Integer read GetLayoutCount;
    /// <summary>The layouts, by index (default property).</summary>
    property Layouts[I: Integer]: TKLayout read GetLayout; default;
    /// <summary>Returns the layout with the given name; raises if absent.</summary>
    function LayoutByName(const AName: string): TKLayout;
    /// <summary>Returns the layout with the given name, or nil.</summary>
    function FindLayout(const AName: string): TKLayout;

    /// <summary>Returns the layout referenced by the given node; raises if absent.</summary>
    function LayoutByNode(const ANode: TEFNode): TKLayout;
    /// <summary>Returns the layout referenced by the given node, or nil.</summary>
    function FindLayoutByNode(const ANode: TEFNode): TKLayout;

    /// <summary>
    ///  Reads the Layouts/ directory from disk and fills AList with all
    ///  layouts found. AList is cleared first. If the catalog is not yet
    ///  open it calls Open; if already open it calls Refresh, so each
    ///  call reflects the current on-disk state.
    /// </summary>
    procedure GetLayoutList(const AList: TKLayoutList);
  end;

  /// <summary>
  ///  A view that executes an action.
  /// </summary>
  TKActionView = class(TKView)

  end;

  TKTreeViewNode = class;

  IKTreeViewNodes = interface
    ['{5A14D9B3-6363-4B29-888B-EAF70857094E}']
    function GetTreeViewNodeCount: Integer;
    function GetTreeViewNode(I: Integer): TKTreeViewNode;

    /// <summary>Number of child tree nodes.</summary>
    property TreeViewNodeCount: Integer read GetTreeViewNodeCount;
    /// <summary>The child tree nodes, by index.</summary>
    property TreeViewNodes[I: Integer]: TKTreeViewNode read GetTreeViewNode;
  end;

  /// <summary>
  ///  The type of nodes in a tree view.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  [YamlChildType('Controller', '', 'Embedded controller')]
  [YamlChildType('Model', '', 'Auto-generated view for model')]
  TKTreeViewNode = class(TEFNode, IKTreeViewNodes)
  private
    function GetTreeViewNodeCount: Integer;
    function GetTreeViewNode(I: Integer): TKTreeViewNode;
  protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
  public
    /// <summary>Number of child tree nodes.</summary>
    property TreeViewNodeCount: Integer read GetTreeViewNodeCount;
    /// <summary>The child tree nodes, by index.</summary>
    property TreeViewNodes[I: Integer]: TKTreeViewNode read GetTreeViewNode;

    /// <summary>Resolves the view this node points to within AViews, or nil.</summary>
    function FindView(const AViews: TKViews): TKView; virtual;

    /// <summary>Returns the access-control URI for the given view (for ACL checks).</summary>
    function GetACURI(const AView: TKView): string;
  end;

  /// <summary>
  ///  A node in a tree view that is a folder (i.e. contains other
  ///  nodes and doesn't represent a view).
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  [YamlChildType('Folder', '', 'Nested sub-folder')]
  [YamlChildType('View', '', 'View reference')]
  TKTreeViewFolder = class(TKTreeViewNode)
  private
    function GetIsInitiallyCollapsed: Boolean;
  public
    [YamlNode('IsInitiallyCollapsed', 'True', 'Folder starts collapsed in tree view')]
    property IsInitiallyCollapsed: Boolean read GetIsInitiallyCollapsed;
    /// <summary>A folder has no own view; returns nil.</summary>
    function FindView(const AViews: TKViews): TKView; override;
  end;

  /// <summary>
  ///   A view that is a tree of views. Contains views and folders, which
  ///  in turn contain views.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  [YamlChildType('Folder', '', 'Menu folder')]
  [YamlChildType('View', '', 'View reference')]
  TKTreeView = class(TKView, IKTreeViewNodes)
  private
    function GetTreeViewNode(I: Integer): TKTreeViewNode;
    function GetTreeViewNodeCount: Integer;
  protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
  public
    /// <summary>Number of child tree nodes.</summary>
    property TreeViewNodeCount: Integer read GetTreeViewNodeCount;
    /// <summary>The child tree nodes, by index.</summary>
    property TreeViewNodes[I: Integer]: TKTreeViewNode read GetTreeViewNode;
  end;

  TKViewRegistry = class(TKMetadataRegistry)
  strict private
    class var FInstance: TKViewRegistry;
    class function GetInstance: TKViewRegistry; static;
  strict protected
    procedure BeforeRegisterClass(const AId: string; const AClass: TClass); override;
    class destructor Destroy;
  public
    /// <summary>The singleton view-class registry (created on first access).</summary>
    class property Instance: TKViewRegistry read GetInstance;
    /// <summary>True if the singleton instance already exists.</summary>
    class function HasInstance: Boolean;
    /// <summary>Returns the registered view class for the given id(s).</summary>
    function GetClass(const AId1, AId2: string): TKViewClass;
  end;

  TKViewBuilder = class(TKMetadata)
  strict private
    FViews: TKViews;
  private
    FPersistentName: string;
    FNode: TEFNode;
  strict protected
    property Views: TKViews read FViews;
    property PersistentName: string read FPersistentName;
  public
    /// <summary>Builds a view into AViews (optionally persistent/named), returning it.
    /// Override in a descendant to auto-generate a view from configuration.</summary>
    function BuildView(const AViews: TKViews;
      const APersistentName: string = '';
      const ANode: TEFNode = nil): TKView; virtual;
  end;

  TKViewBuilderClass = class of TKViewBuilder;

  TKViewBuilderRegistry = class(TEFRegistry)
  private
    class var FInstance: TKViewBuilderRegistry;
    class function GetInstance: TKViewBuilderRegistry; static;
  protected
    class destructor Destroy;
  public
    /// <summary>The singleton view-builder registry.</summary>
    class property Instance: TKViewBuilderRegistry read GetInstance;
    /// <summary>Returns the registered view-builder class for the given id.</summary>
    function GetClass(const AId: string): TKViewBuilderClass;
  end;

  TKViewBuilderFactory = class(TEFFactory)
  private
    class var FInstance: TKViewBuilderFactory;
    class function GetInstance: TKViewBuilderFactory; static;
  protected
    function DoCreateObject(const AClass: TClass): TObject; override;
  public
    class destructor Destroy;
  public
    /// <summary>The singleton view-builder factory.</summary>
    class property Instance: TKViewBuilderFactory read GetInstance;

    /// <summary>Creates a view-builder instance for the given registered id.</summary>
    function CreateObject(const AId: string): TKViewBuilder; reintroduce;
  end;

  TKLayoutRegistry = class(TKMetadataRegistry)
  strict private
    class var FInstance: TKLayoutRegistry;
    class function GetInstance: TKLayoutRegistry; static;
  strict protected
    procedure BeforeRegisterClass(const AId: string; const AClass: TClass); override;
    class destructor Destroy;
  public
    /// <summary>The singleton layout-class registry.</summary>
    class property Instance: TKLayoutRegistry read GetInstance;
    /// <summary>Returns the registered layout class for the given id(s).</summary>
    function GetClass(const AId1, AId2: string): TKLayoutClass;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Variants,
  System.TypInfo,
  EF.DB,
  EF.StrUtils,
  EF.Localization,
  Kitto.Types,
  Kitto.Config,
  Kitto.SQL;

{ TKViews }

procedure TKViews.Close;
begin
  Synchronize(
    procedure
    begin
      inherited;
      if Assigned(FLayouts) then
        FLayouts.Close;
    end
  );
end;

constructor TKViews.Create(const AModels: TKModels);
begin
  inherited Create;
  FModels := AModels;
end;

destructor TKViews.Destroy;
begin
  FreeAndNil(FLayouts);
  inherited;
end;

function TKViews.FindView(const AName: string): TKView;
begin
  Result := FindObject(AName) as TKView;
end;

function TKViews.FindViewByNode(const ANode: TEFNode): TKView;
var
  LResult: TKView;
begin
  Synchronize(
    procedure
    var
      LWords: TStringDynArray;
    begin
      if Assigned(ANode) then
      begin
        LResult := FindNonpersistentObject(ANode) as TKView;
        if not Assigned(LResult) then
        begin
          LWords := Split(ANode.AsExpandedString);
          if Length(LWords) >= 2 then
          begin
            // Two words: the first one is the verb.
            if SameText(LWords[0], 'Build') then
            begin
              LResult := BuildView(ANode, LWords[1]);
              Exit;
            end;
          end;
        end;
      end;
      LResult := FindObjectByNode(ANode) as TKView;
    end
  );
  Result := LResult;
end;

function TKViews.BuildView(const ANode: TEFNode; const AViewBuilderName: string): TKView;
var
  LViewBuilder: TKViewBuilder;
begin
  Assert(Assigned(ANode));
  Assert(AViewBuilderName <> '');

  LViewBuilder := TKViewBuilderFactory.Instance.CreateObject(AViewBuilderName);
  try
    LViewBuilder.Assign(ANode);
    Result := LViewBuilder.BuildView(Self, '', ANode);
    AfterCreateObject(Result);
  finally
    FreeAndNil(LViewBuilder);
  end;
end;

function TKViews.GetLayouts: TKLayouts;
begin
  Synchronize(
    procedure
    begin
      if not Assigned(FLayouts) then
        FLayouts := TKLayouts.Create;
    end
  );
  Result := FLayouts;
end;

function TKViews.GetMetadataRegistry: TKMetadataRegistry;
begin
  Result := TKViewRegistry.Instance;
end;

function TKViews.GetObjectClassType: TKMetadataClass;
begin
  Result := TKView;
end;

function TKViews.GetView(I: Integer): TKView;
begin
  Result := Objects[I] as TKView;
end;

function TKViews.GetViewCount: Integer;
begin
  Result := ObjectCount;
end;

procedure TKViews.GetViewList(const AList: TKViewList);
var
  I: Integer;
begin
  Assert(Assigned(AList));
  AList.Clear;
  if not IsOpen then
    Open
  else
    Refresh;
  for I := 0 to ViewCount - 1 do
    AList.Add(Views[I]);
end;

procedure TKViews.Open;
begin
  Synchronize(
    procedure
    begin
      inherited;
      Layouts.Open;
    end
  );
end;

procedure TKViews.Refresh;
begin
  Synchronize(
    procedure
    begin
      inherited;
      Layouts.Refresh;
    end
  );
end;

procedure TKViews.SetPath(const AValue: string);
begin
  inherited;
  Layouts.Path := IncludeTrailingPathDelimiter(AValue) + 'Layouts';
end;

function TKViews.ViewByName(const AName: string): TKView;
begin
  Result := ObjectByName(AName) as TKView;
end;

function TKViews.ViewByName(const ANames: TStringDynArray): TKView;
begin
  Result := ObjectByName(ANames) as TKView;
end;

function TKViews.ViewByNode(const ANode: TEFNode): TKView;
begin
  Result := FindViewByNode(ANode);
  if not Assigned(Result) then
    if Assigned(ANode) then
      ObjectNotFound(ANode.Name + ':' + ANode.AsString)
    else
      ObjectNotFound('<nil>');
end;

{ TKLayouts }

procedure TKLayouts.AfterCreateObject(const AObject: TKMetadata);
begin
  inherited;
  if AObject is TKLayout then
    TKLayout(AObject).FLayouts := Self;
end;

function TKLayouts.FindLayout(const AName: string): TKLayout;
begin
  Result := FindObject(AName) as TKLayout;
end;

function TKLayouts.FindLayoutByNode(const ANode: TEFNode): TKLayout;
begin
  Result := FindObjectByNode(ANode) as TKLayout;
end;

function TKLayouts.GetLayout(I: Integer): TKLayout;
begin
  Result := Objects[I] as TKLayout;
end;

function TKLayouts.GetLayoutCount: Integer;
begin
  Result := ObjectCount;
end;

procedure TKLayouts.GetLayoutList(const AList: TKLayoutList);
var
  I: Integer;
begin
  Assert(Assigned(AList));
  AList.Clear;
  if not IsOpen then
    Open
  else
    Refresh;
  for I := 0 to LayoutCount - 1 do
    AList.Add(Layouts[I]);
end;

function TKLayouts.GetMetadataRegistry: TKMetadataRegistry;
begin
  Result := TKLayoutRegistry.Instance;
end;

function TKLayouts.GetObjectClassType: TKMetadataClass;
begin
  Result := TKLayout;
end;

function TKLayouts.LayoutByName(const AName: string): TKLayout;
begin
  Result := ObjectByName(AName) as TKLayout;
end;

function TKLayouts.LayoutByNode(const ANode: TEFNode): TKLayout;
begin
  Result := ObjectByNode(ANode) as TKLayout;
end;

{ TKView }

class function TKView.GetClassNameForResourceURI: string;
begin
  // We want all derived classes to be identified as views.
  Result := 'View';
end;

function TKView.GetCatalog: TKViews;
begin
  Result := inherited Catalog as TKViews;
end;

function TKView.GetControllerType: string;
begin
  Result := GetExpandedString('Controller');
end;

function TKView.GetDefaultImageName: string;
begin
  Result := DEFAULT_IMAGE_NAME;
end;

function TKView.GetDisplayLabel: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('DisplayLabel2')
  else
    Result := GetString('DisplayLabel');
end;

function TKView.GetImageName: string;
begin
  Result := GetString('ImageName');
  if Result = '' then
    Result := GetDefaultImageName;
end;

{ TKTreeViewNode }

function TKTreeViewNode.FindView(const AViews: TKViews): TKView;
begin
  Assert(Assigned(AViews));

  Result := AViews.ViewByNode(Self);
end;

function TKTreeViewNode.GetACURI(const AView: TKView): string;
var
  LName: string;
begin
  Assert(Assigned(AView));

  LName := GetString('ACName');
  if LName = '' then
    LName := GetString('ResourceName');
  if LName = '' then
    Result := ''
  else
    Result := AView.GetACURI + '/' + LName;
end;

function TKTreeViewNode.GetChildClass(const AName: string): TEFNodeClass;
begin
  if SameText(AName, 'Folder') then
    Result := TKTreeViewFolder
  else if SameText(AName, 'View') then
    Result := TKTreeViewNode
  else
    Result := inherited GetChildClass(AName);
end;

function TKTreeViewNode.GetTreeViewNode(I: Integer): TKTreeViewNode;
begin
  Result := GetChild<TKTreeViewNode>(I);
end;

function TKTreeViewNode.GetTreeViewNodeCount: Integer;
begin
  Result := GetChildCount<TKTreeViewNode>;
end;

{ TKTreeView }

function TKTreeView.GetChildClass(const AName: string): TEFNodeClass;
begin
  if SameText(AName, 'Folder') then
    Result := TKTreeViewFolder
  else if SameText(AName, 'View') then
    Result := TKTreeViewNode
  else
    Result := inherited GetChildClass(AName);
end;

function TKTreeView.GetTreeViewNode(I: Integer): TKTreeViewNode;
begin
  Result := GetChild<TKTreeViewNode>(I);
end;

function TKTreeView.GetTreeViewNodeCount: Integer;
begin
  Result := GetChildCount<TKTreeViewNode>;
end;

{ TKViewBuilderRegistry }

class destructor TKViewBuilderRegistry.Destroy;
begin
  FreeAndNil(FInstance);
end;

function TKViewBuilderRegistry.GetClass(const AId: string): TKViewBuilderClass;
begin
  Result := TKViewBuilderClass(inherited GetClass(AId));
end;

class function TKViewBuilderRegistry.GetInstance: TKViewBuilderRegistry;
begin
  if FInstance = nil then
    FInstance := TKViewBuilderRegistry.Create;
  Result := FInstance;
end;

{ TKViewBuilderFactory }

function TKViewBuilderFactory.CreateObject(const AId: string): TKViewBuilder;
begin
  Result := inherited CreateObject(AId) as TKViewBuilder;
end;

class destructor TKViewBuilderFactory.Destroy;
begin
  FreeAndNil(FInstance);
end;

function TKViewBuilderFactory.DoCreateObject(const AClass: TClass): TObject;
begin
  // Must use the virtual constructor in TEFTree.
  Result := TKViewBuilderClass(AClass).Create;
end;

class function TKViewBuilderFactory.GetInstance: TKViewBuilderFactory;
begin
  if FInstance = nil then
    FInstance := TKViewBuilderFactory.Create(TKViewBuilderRegistry.Instance);
  Result := FInstance;
end;

{ TKViewBuilder }

function TKViewBuilder.BuildView(const AViews: TKViews;
  const APersistentName: string; const ANode: TEFNode): TKView;
begin
  Assert(Assigned(AViews));
  Assert(Assigned(AViews.Models));

  FViews := AViews;
  FPersistentName := APersistentName;
  FNode := ANode;
  Result := nil;
end;

{ TKViewList }

procedure TKViewList.AddViewNamesToStrings(const AStrings: TStrings);
var
  LView: TKView;
begin
  for LView in Self do
    AStrings.Add(LView.PersistentName);
end;

{ TKTreeViewFolder }

function TKTreeViewFolder.FindView(const AViews: TKViews): TKView;
begin
  Result := nil; // No view available for folders.
end;

function TKTreeViewFolder.GetIsInitiallyCollapsed: Boolean;
begin
  Result := GetBoolean('IsInitiallyCollapsed', False);
end;

{ TKViewRegistry }

procedure TKViewRegistry.BeforeRegisterClass(const AId: string;
  const AClass: TClass);
begin
  inherited;
  if not AClass.InheritsFrom(TKView) then
    raise EKError.CreateFmt('Cannot register class %s (Id %s). Class is not a %s subclass.', [AClass.ClassName, AId, TKView.ClassName]);
end;

class destructor TKViewRegistry.Destroy;
begin
  FreeAndNil(FInstance);
end;

function TKViewRegistry.GetClass(const AId1, AId2: string): TKViewClass;
begin
  Result := TKViewClass(inherited GetClass(AId1, AId2));
end;

class function TKViewRegistry.GetInstance: TKViewRegistry;
begin
  if FInstance = nil then
    FInstance := TKViewRegistry.Create;
  Result := FInstance;
end;

class function TKViewRegistry.HasInstance: Boolean;
begin
  Result := Assigned(FInstance);
end;

{ TKLayoutRegistry }

procedure TKLayoutRegistry.BeforeRegisterClass(const AId: string;
  const AClass: TClass);
begin
  inherited;
  if not AClass.InheritsFrom(TKLayout) then
    raise EKError.CreateFmt('Cannot register class %s (Id %s). Class is not a %s subclass.', [AClass.ClassName, AId, TKLayout.ClassName]);
end;

class destructor TKLayoutRegistry.Destroy;
begin
  FreeAndNil(FInstance);
end;

function TKLayoutRegistry.GetClass(const AId1, AId2: string): TKLayoutClass;
begin
  Result := TKLayoutClass(inherited GetClass(AId1, AId2));
end;

class function TKLayoutRegistry.GetInstance: TKLayoutRegistry;
begin
  if FInstance = nil then
    FInstance := TKLayoutRegistry.Create;
  Result := FInstance;
end;

{ TKLayout }

function TKLayout.IsFormLayout: Boolean;
begin
  Result := SameText(Copy(PersistentName, Length(PersistentName)-4,5), '_Form');
end;

function TKLayout.IsGridLayout: Boolean;
begin
  Result := SameText(Copy(PersistentName, Length(PersistentName)-4,5), '_Grid');
end;

function TKLayout.GetLabelAlign: string;
begin
  Result := GetString('LabelAlign', 'Top');
end;

function TKLayout.GetLabelWidth: Integer;
begin
  Result := GetInteger('LabelWidth', 120);
end;

function TKLayout.GetMsgTarget: string;
begin
  Result := GetString('MsgTarget', 'Title');
end;

function TKLayout.GetLabelPad: Integer;
begin
  Result := GetInteger('LabelPad', 0);
end;

function TKLayout.GetMemoWidth: Integer;
begin
  Result := GetInteger('MemoWidth', 60);
end;

function TKLayout.GetMaxFieldWidth: Integer;
begin
  Result := GetInteger('MaxFieldWidth', 60);
end;

function TKLayout.GetMinFieldWidth: Integer;
begin
  Result := GetInteger('MinFieldWidth', 5);
end;

function TKLayout.GetRequiredLabelTemplate: string;
begin
  Result := GetString('RequiredLabelTemplate', '<b>{label}*</b>');
end;

function TKLayout.GetLabelSeparator: string;
begin
  Result := GetString('LabelSeparator', ':');
end;

initialization
  TKViewRegistry.Instance.RegisterClass(TKMetadata.SYS_PREFIX + 'Tree', TKTreeView);

finalization
  TKViewRegistry.Instance.UnregisterClass(TKMetadata.SYS_PREFIX + 'Tree');

end.
