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
///  The data-view metadata layer. Defines data views (TKDataView) and their
///  view tables (TKViewTable) with view fields (TKViewField) that overlay model
///  metadata, plus the view-aware in-memory store (TKViewTableStore) with its
///  header, records and fields used to load, edit and persist data.
/// </summary>
unit Kitto.Metadata.DataView;

{$I Kitto.Defines.inc}

interface

uses
  System.Types,
  System.SysUtils,
  System.Generics.Collections,
  Data.DB,
  EF.Types,
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Metadata.Types,
  Kitto.Metadata,
  Kitto.Metadata.Models,
  Kitto.Metadata.Views,
  Kitto.Store,
  Kitto.Rules;

type
  TKDataView = class;

  TKViewTable = class;

  /// <summary>The collection of detail (child) tables of a view table.</summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  [YamlChildType('Table', '', 'Detail table')]
  TKViewTables = class(TKMetadataItem)
  private
    function GetTable: TKViewTable;
    function GetView: TKView;
  protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
  public
    /// <summary>The owning view table.</summary>
    property Table: TKViewTable read GetTable;
    /// <summary>The data view this collection belongs to.</summary>
    property View: TKView read GetView;
  end;

  TKViewField = class;

  /// <summary>An array of view fields.</summary>
  TKViewFieldArray = TArray<TKViewField>;

  /// <summary>Describes a reference-field lookup constrained by another field:
  /// the destination (reference) field, the source field supplying the value,
  /// and the foreign field name it matches in the referenced model.</summary>
  TKFilterByViewField = record
    DestinationField: TKViewField;
    SourceField: TKViewField;
    ForeignFieldName: string;
  end;

  /// <summary>
  ///  A field of a view table. Overlays the underlying model field with
  ///  view-specific metadata (labels, visibility, editability, formatting,
  ///  rules) and adds reference/lookup helpers. May also be an expression-only
  ///  field with no model field behind it.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKViewField = class(TKMetadataItem)
  private
    function GetAliasedName: string;
    function GetTable: TKViewTable;
    function GetIsVisible: Boolean;
    function GetModelField: TKModelField;
    function GetDisplayLabel: string;
    function GetDisplayLabel_Form: string;
    function GetDisplayLabel_Grid: string;
    function GetDisplayWidth: Integer;
    function GetIsRequired: Boolean;
    function GetIsReadOnly: Boolean;
    function GetQualifiedDBName: string;
    // Wraps a bare/dotted identifier in the dialect-specific delimiters when the
    // field's database has DelimitedIdent enabled. Best-effort: if no runtime
    // connection is available (design-time/KIDE) the identifier is returned
    // unchanged. Never pass expressions/free SQL here.
    function DelimitDBId(const AId: string): string;
    function GetModelName: string;
    function GetFieldName: string;
    function GetDefaultValue: Variant;
    function GetModel: TKModel;
    function GetExpression: string;
    function GetAlias: string;
    function GetQualifiedAliasedDBNameOrExpression: string;
    function GetIsKey: Boolean;
    function GetSize: Integer;
    function GetIsBlob: Boolean;
    function GetAllowedValues: TEFPairs;
    function GetRules: TKRules;
    function GetDecimalPrecision: Integer;
    function GetFieldNamesForUpdate: string;
    function GetCanInsert: Boolean;
    function GetCanUpdate: Boolean;
    function GetIsReference: Boolean;
    function GetIsDetailReference: Boolean;
    function GetHint: string;
    function GetEditFormat: string;
    function GetDisplayFormat: string;
    function GetQualifiedDBNameOrExpression: string;
    function GetReferenceField: TKModelField;
    function GetBlankValue: Boolean;
    function GetAutoCompleteMinChars: Integer;
    function GetReferenceName: string;
    function GetDisplayTemplate: string;
    function GetFileNameField: string;
    function GetDefaultFilter: string;
    function GetDefaultFilterConnector: string;
    function GetIsPassword: Boolean;
    function GetDBName: string;
    function GetAliasedDBName: string;
    function GetQualifiedAliasedDBName: string;
    function GetLookupFilter: string;
    function GetFieldsNode: string;
    function GetViewPhysicalName: string;
    function GetDBNameOrExpression: string;
    function GetFieldType: TFieldType;
    function GetIsPicture: Boolean;
    function GetIsAutoAddField: Boolean;
    function GetUseSpeedButtons: Boolean;
    const URL_PREFIX = '_URL_';
  strict protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
    function GetDataType: TEFDataType; override;
  public
    /// <summary>True if the view field maps to a model field (not expression-only).</summary>
    function HasModelField: boolean;
    /// <summary>Returns the effective EmptyAsNull setting (delegates to the model field).</summary>
    function GetEmptyAsNull: Boolean; override;
    /// <summary>Finds a child node, transparently resolving nodes inherited from the model field.</summary>
    function FindNode(const APath: string; const ACreateMissingNodes: Boolean = False): TEFNode; override;
    /// <summary>Returns True if access is granted to this field in the given mode.</summary>
    function IsAccessGranted(const AMode: string): Boolean; override;
    /// <summary>The access-control resource URI identifying this field.</summary>
    function GetResourceURI: string; override;
    /// <summary>True if the field is editable in the given operation (insert vs update), per ACL and Can* flags.</summary>
    function CanEditField(const AInsertOperation: Boolean): Boolean;
    /// <summary>The view table this field belongs to.</summary>
    property Table: TKViewTable read GetTable;
    /// <summary>The model the field ultimately maps to.</summary>
    property Model: TKModel read GetModel;

    /// <summary>
    ///  Returns a reference to the model field, or raises an exception
    ///  if the model field is not found.
    /// </summary>
    property ModelField: TKModelField read GetModelField;

    /// <summary>
    ///  Returns a reference to the model field, or nil.
    /// </summary>
    function FindModelField: TKModelField;
    /// <summary>Optional SQL alias for the field (the part after a space in the Name).</summary>
    property Alias: string read GetAlias;
    /// <summary>The field's name as used to key it in the store (alias, or field name).</summary>
    property AliasedName: string read GetAliasedName;
    /// <summary>Table-qualified aliased DB name, or the expression for a computed field.</summary>
    property QualifiedAliasedDBNameOrExpression: string read GetQualifiedAliasedDBNameOrExpression;
    /// <summary>The physical DB column name.</summary>
    property DBName: string read GetDBName;
    /// <summary>DB column name plus, if different from the logical name, the alias.</summary>
    property AliasedDBName: string read GetAliasedDBName;
    /// <summary>Table-qualified AliasedDBName.</summary>
    property QualifiedAliasedDBName: string read GetQualifiedAliasedDBName;
    /// <summary>DB column name prefixed with the table name (table.column).</summary>
    property QualifiedDBName: string read GetQualifiedDBName;
    /// <summary>QualifiedDBName, or the SQL expression for a computed field.</summary>
    property QualifiedDBNameOrExpression: string read GetQualifiedDBNameOrExpression;
    /// <summary>DBName, or the SQL expression for a computed field.</summary>
    property DBNameOrExpression: string read GetDBNameOrExpression;
    /// <summary>Fixed list of allowed value/label pairs, if any.</summary>
    property AllowedValues: TEFPairs read GetAllowedValues;

    [YamlNode('CanInsert', 'True', 'Field is editable when inserting a new record')]
    property CanInsert: Boolean read GetCanInsert;
    [YamlNode('CanUpdate', 'True', 'Field is editable when updating an existing record')]
    property CanUpdate: Boolean read GetCanUpdate;

    /// <summary>
    ///  If the field is referenced, returns the names of the key fields
    ///  in the reference, separated by TKConfig.Instance.MultiFieldSeparator.
    ///  Otherwise, returns the FieldName.
    /// </summary>
    property FieldNamesForUpdate: string read GetFieldNamesForUpdate;

    /// <summary>
    ///  Returns True if the field is a reference field, that is if the
    ///  field is part of the containing view table's model and the underlying
    ///  model field is a reference field.
    /// </summary>
    property IsReference: Boolean read GetIsReference;

    /// <summary>
    ///  Returns True if the field is a auto-add field, that is if into
    ///  field name there is a dot that separate Master Table e Referenced Table.
    /// </summary>
    property IsAutoAddField: Boolean read GetIsAutoAddField;

    /// <summary>
    ///  Optional filter to use when creating select lists. Only applies to
    ///  reference fields.
    /// </summary>
    [YamlNode('DefaultFilter', 'SQL filter for reference lookup lists')]
    property DefaultFilter: string read GetDefaultFilter;

    /// <summary>
    ///  Optional filter to use when creating lookup lists. Only applies to
    ///  reference fields.
    /// </summary>
    [YamlNode('LookupFilter', 'SQL filter for lookup combo queries')]
    property LookupFilter: string read GetLookupFilter;

    /// <summary>RTTI carrier for the Fields node: the constituent sub-fields shown
    /// for a reference field. Read node by node at render time.</summary>
    [YamlNode('Fields', 'Sub-fields shown for a reference field (each child is a field name)')]
    property FieldsNode: string read GetFieldsNode;

    [YamlNode('PhysicalName', 'Physical DB column name override for this view field')]
    property ViewPhysicalName: string read GetViewPhysicalName;

    /// <summary>
    ///  Specifies the logical connector to use when appending the
    ///  DefaultFilter to an existing WHERE clause (for example, a referenced
    ///  model's own DefaultFilter). Defaults to 'and'; another common value
    ///  is 'or'.
    /// </summary>
    [YamlNode('DefaultFilterConnector', 'and', 'Logical connector (and/or) for DefaultFilter')]
    [YamlEnumType(TypeInfo(TKFilterConnector))]
    property DefaultFilterConnector: string read GetDefaultFilterConnector;

    /// <summary>
    ///  Returns the field's DataType, unless it's a reference field,
    ///  in which case returns the data type of the referenced model's
    ///  CaptionField.
    /// </summary>
    function GetActualDataType: TEFDataType;

    /// <summary>
    ///  If the field is from a different model than the table's model,
    ///  returns the model field that references its model, otherwise returns
    ///  nil.
    /// </summary>
    property ReferenceField: TKModelField read GetReferenceField;

    /// <summary>
    ///  <para>
    ///   Returns True if the field is the reference field of
    ///   MasterTable's model's detail reference to this vie wtable's
    ///   model.
    ///  </para>
    ///  <para>
    ///   IOW, returns True if the view table is a detail table and the
    ///   field is (part of) the link to its master table.
    ///  </para>
    /// </summary>
    property IsDetailReference: Boolean read GetIsDetailReference;

    /// <summary>
    ///  Creates a store with the current field, all key fields of
    ///  the referenced model and a concatenation of all key fields (if > 1)
    ///  stored as a single field (used by lookups).
    ///  If the field is not a reference field, an exception is raised.
    /// </summary>
    function CreateReferenceStore: TKStore;

    /// <summary>
    ///  Creates a store with all fields from the referenced model and fetches
    ///  the record specified by the key values.
    /// </summary>
    function CreateReferencedModelStore(const AKeyValues: Variant): TKStore;

    /// <summary>
    ///  Extract and returns the model name from the Name. If no model name is
    ///  specified (because the field is part of the main model), returns the
    ///  main model name.
    /// </summary>
    property ModelName: string read GetModelName;

    /// <summary>
    ///  Extract and returns the reference name from the Name, or '' if the
    ///  field is not a reference field.
    /// </summary>
    property ReferenceName: string read GetReferenceName;

    /// <summary>
    ///  Extract and returns the field name without the model name qualifier.
    ///  If the field is part of the main model, this is equal to Name.
    /// </summary>
    property FieldName: string read GetFieldName;

    /// <summary>True if the field is part of the model's primary key.</summary>
    property IsKey: Boolean read GetIsKey;
    [YamlNode('IsVisible', 'True', 'Field visibility in views')]
    property IsVisible: Boolean read GetIsVisible;
    [YamlNode('IsRequired', 'Field is mandatory')]
    property IsRequired: Boolean read GetIsRequired;
    [YamlNode('IsReadOnly', 'False', 'Field is not editable')]
    property IsReadOnly: Boolean read GetIsReadOnly;
    [YamlNode('IsPassword', 'False', 'Mask input for password fields')]
    property IsPassword: Boolean read GetIsPassword;
    [YamlNode('EmptyAsNull', 'Convert empty input to NULL in the database')]
    property EmptyAsNull: Boolean read GetEmptyAsNull;
    [YamlNode('DefaultValue', 'Value assigned when creating a new record')]
    property DefaultValue: Variant read GetDefaultValue;

    /// <summary>
    ///  Appends to ANode one child node for each default value. Regular fields
    ///  have at most one default value (returned by the DefaultValue property),
    ///  while reference fields can have more (one for each physical constituent
    ///  field). Model fields are queries for default values automatically.
    /// </summary>
    procedure AppendDefaultValues(const ANode: TEFNode);

    [YamlNode('Expression', 'SQL expression for computed fields')]
    property Expression: string read GetExpression;

    [YamlNode('DisplayLabel', '', 'Label shown in forms and grids', True)]
    property DisplayLabel: string read GetDisplayLabel;
    [YamlNode('DisplayLabel_Grid', '', 'Label override for grid columns', True)]
    property DisplayLabel_Grid: string read GetDisplayLabel_Grid;
    [YamlNode('DisplayLabel_Form', '', 'Label override for form fields', True)]
    property DisplayLabel_Form: string read GetDisplayLabel_Form;

    [YamlNode('Hint', '', 'Placeholder text shown when field is empty', True)]
    property Hint: string read GetHint;
    [YamlNode('DisplayWidth', 'Display width in characters')]
    property DisplayWidth: Integer read GetDisplayWidth;
    [YamlNode('DecimalPrecision', 'Number of decimal digits')]
    property DecimalPrecision: Integer read GetDecimalPrecision;
    /// <summary>The field's data type.</summary>
    property DataType: TEFDataType read GetDataType;
    /// <summary>The corresponding VCL TFieldType.</summary>
    property FieldType: TFieldType read GetFieldType;
    /// <summary>The data type, resolved to the referenced caption field's type for references.</summary>
    property ActualDataType: TEFDataType read GetActualDataType;
    /// <summary>The field size (e.g. string length); 0 when not applicable.</summary>
    property Size: Integer read GetSize;
    /// <summary>True if the field holds binary (blob) data.</summary>
    property IsBlob: Boolean read GetIsBlob;
    [YamlNode('EditFormat', 'Input format mask for editing')]
    property EditFormat: string read GetEditFormat;
    [YamlNode('DisplayFormat', 'Display format for rendering values')]
    property DisplayFormat: string read GetDisplayFormat;
    [YamlNode('BlankValue', 'False', 'Hide field value when an image is displayed')]
    property BlankValue: Boolean read GetBlankValue;
    [YamlNode('AutoCompleteMinChars', '4', 'Minimum characters before autocomplete starts')]
    property AutoCompleteMinChars: Integer read GetAutoCompleteMinChars;
    [YamlNode('DisplayTemplate', 'Rendering template with {value} and {FieldName} placeholders')]
    property DisplayTemplate: string read GetDisplayTemplate;

    [YamlContainer('Rules', TKRule, 'Business rules applied to this field')]
    property Rules: TKRules read GetRules;
    /// <summary>
    ///  Calls the specified function once for each view-level and then each
    ///  model-level rule that is not overridden at the view level.
    ///  The function should do something with the rule implementation object
    ///  it receives (most commonly apply the rule) and return True as long as
    ///  the call chain should proceed, or False to stop the rule enumeration.
    ///  Generally the function will return True in the most common cases.
    /// </summary>
    procedure EnumRules(const AEnumFunc: TFunc<TKRuleImpl, Boolean>);
    /// <summary>
    ///  True if the either the view or the model field has at least one
    ///  server-side rule. Used to decide whether to make an async call
    ///  or not when the field changes on the client.
    /// </summary>
    function HasServerSideRules: Boolean;

    /// <summary>
    ///  If the field is a reference field, creates and returns an array
    ///  of view fields in the current view table from the same referenced
    ///  model (including itself).
    /// </summary>
    /// <exception cref="Assert">
    ///  Violation if IsReference is False.
    /// </exception>
    /// <example>
    ///  If the field is a reference field called City, then all fields
    ///  called City.* are added to the returned array, plus itself (City).
    /// </example>
    function GetDerivedFields: TArray<TKViewField>;

    /// <summary>
    ///  Creates and loads a store with a record containing all derived
    ///  values for a reference field. The caller is responsible for freeing the
    ///  store object.
    /// </summary>
    /// <param name="AKeyValues">
    ///  Key values for the record to fetch.
    /// </param>
    /// <exception cref="Assert">
    ///  If the field is not a reference field, an
    ///  assertion violation is raised.
    /// </exception>
    function CreateDerivedFieldsStore(const AKeyValues: string): TKStore;

    /// <summary>
    ///  For blob or file reference fields, optionally specifies the
    ///  name of another field in the same view table that will store the
    ///  original file name upon upload.
    /// </summary>
    [YamlNode('FileNameField', 'Name of companion field storing the uploaded file name')]
    property FileNameField: string read GetFileNameField;

    /// <summary>
    ///  Returns True if any view fields exist in the view table that
    ///  have this field's model field as reference field. Used to discover
    ///  if there are any fields that need to be refreshed when the current
    ///  field's value changes.
    /// </summary>
    function DerivedFieldsExist: Boolean;

    /// <summary>Returns the field's value→color rules as value/color pairs (for conditional coloring).</summary>
    function GetColorsAsPairs: TEFPairs;

    /// <summary>For a reference field with FilterBy nodes, returns the (destination, source, foreign-field)
    /// tuples that constrain the lookup by another field's value.</summary>
    function GetFilterByFields: TArray<TKFilterByViewField>;

    /// <summary>
    ///  Translate and returns a sort clause suitable for ordering a set of
    ///  records on this field.
    /// </summary>
    function BuildSortClause(const AIsDescending: Boolean): string;

    [YamlNode('IsPicture', 'False', 'Field contains image data')]
    property IsPicture: Boolean read GetIsPicture;

    [YamlNode('UseSpeedButtons', 'False', 'Show spin buttons on integer input fields')]
    property UseSpeedButtons: Boolean read GetUseSpeedButtons;

    /// <summary>Returns the companion field name that holds a URL for this field (URL_PREFIX + name).</summary>
    function GetURLFieldName: string;
    /// <summary>True if AFieldName is a URL companion field name (starts with URL_PREFIX).</summary>
    class function IsURLFieldName(const AFieldName: string): Boolean;
  end;

  /// <summary>The collection of fields of a view table.</summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  [YamlChildType('Field', '', 'View field referencing a model field')]
  TKViewFields = class(TKMetadataItem)
  private
    function GetTable: TKViewTable;
  protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
    function GetField(I: Integer): TKViewField;
    function GetFieldCount: Integer;
  public
    /// <summary>The view table owning these fields.</summary>
    property Table: TKViewTable read GetTable;
    /// <summary>Number of view fields.</summary>
    property FieldCount: Integer read GetFieldCount;
    /// <summary>The view fields, by index (default property).</summary>
    property Fields[I: Integer]: TKViewField read GetField; default;
  end;

  TKViewTableRecord = class;
  TKViewTableRecords = class;

  TKViewTableHeader = class;

  /// <summary>
  ///  A view-aware in-memory store for a view table: loads a set or page of
  ///  records from the database (with count), appends and locates records by
  ///  key, and carries the master record when it is a detail store.
  /// </summary>
  TKViewTableStore = class(TKStore)
  strict private
    FMasterRecord: TKViewTableRecord;
    FViewTable: TKViewTable;
    procedure SetupFields;
    function GetRecords: TKViewTableRecords;
    function GetHeader: TKViewTableHeader;
  strict protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
  public
    /// <summary>Creates a store bound to the given view table (builds its header).</summary>
    constructor Create(const AViewTable: TKViewTable); reintroduce;
    /// <summary>The master record when this is a detail store (else nil); drives {MasterRecord.*}.</summary>
    property MasterRecord: TKViewTableRecord read FMasterRecord write FMasterRecord;
    /// <summary>The view table this store holds data for.</summary>
    property ViewTable: TKViewTable read FViewTable;
    /// <summary>The store header (view-aware fields).</summary>
    property Header: TKViewTableHeader read GetHeader;
    /// <summary>The records (typed as TKViewTableRecords).</summary>
    property Records: TKViewTableRecords read GetRecords;

    /// <summary>
    ///  Loads a page of data according to AFrom and AFor arguments,
    ///  and returns the total number of records in all pages.
    /// </summary>
    /// <param name="AFilter">Additional SQL filter.</param>
    /// <param name="AFrom">Number of the first record to retrieve (0-based).</param>
    /// <param name="ATo">Maximum count of records to retrieve.</param>
    /// <remarks>
    ///  <para>
    ///   This method will perform two database queries, one to get the
    ///   total count and one to get the requested data page.
    ///  </para>
    ///  <para>
    ///   If AFrom or ATo are 0, the method calls <see cref="Load" />.
    ///  </para>
    /// </remarks>
    function Load(const AFilter: string = ''; const ASort: string = '';
      const AFrom: Integer = 0; const AFor: Integer = 0;
      const AForEachRecord: TProc<TKVIewTableRecord> = nil): Integer; overload;

    /// <summary>
    ///  Appends a record and fills it with the specified values.
    /// </summary>
    function AppendRecord(const AValues: TEFNode): TKViewTableRecord;

    /// <summary>
    ///  Locates and returns a record from the key values stored in AKey.
    ///  Raises an exception if the record is not found.
    /// </summary>
    /// <param name="AKey">
    ///  Object containing at least one top-level pair for each key value.
    /// </param>
    /// <param name="AFormatSettings">
    ///  Used to interpret string values (all pair values are read as string and
    ///  then converted according to this settings object).
    /// </param>
    /// <param name="AValueIndex">
    ///  If each pair in AKey contains more than one value, set this param to
    ///  an index >=0 to consider that value. Normally each pair contains a
    ///  single value, so you just don't pass this param.
    /// </param>
    function GetRecord(const AKey: TEFTree; const AFormatSettings: TFormatSettings;
      const AValueIndex: Integer = -1): TKViewTableRecord;
    /// <summary>Like GetRecord, but returns nil instead of raising when the record is not found.</summary>
    function FindRecord(const AKey: TEFTree; const AFormatSettings: TFormatSettings;
      const AValueIndex: Integer = -1): TKViewTableRecord;
  end;

  TKViewTableHeaderField = class;

  /// <summary>The header (field descriptors) of a view-table store.</summary>
  TKViewTableHeader = class(TKHeader)
  private
    function GetField(I: Integer): TKViewTableHeaderField;
  protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
  public
    /// <summary>Adds a header field with the given name and returns it.</summary>
    function AddField(const AFieldName: string): TKViewTableHeaderField;
    /// <summary>The header fields, by index.</summary>
    property Fields[I: Integer]: TKViewTableHeaderField read GetField;
    /// <summary>Returns the header field with the given name, or nil.</summary>
    function FindField(const AFieldName: string): TKViewTableHeaderField;
    /// <summary>Returns the header field with the given name; raises if absent.</summary>
    function FieldByName(const AFieldName: string): TKViewTableHeaderField;
  end;

  /// <summary>A header field of a view-table store, bound to a view field (and
  /// the underlying model field), caching a few view-level display flags.</summary>
  TKViewTableHeaderField = class(TKHeaderField)
  strict private
    FViewField: TKViewField;
    // Cached value from FViewField.
    FViewFieldIsPassword: Boolean;
    // Cached value from FViewField.
    FViewFieldDisplayTemplate: string;
    FModelField: TKModelField;
  public
    /// <summary>Binds the header field to a view field (optionally overriding the data type). Returns Self.</summary>
    function SetViewField(const AValue: TKViewField; const AOverrideDataType: TEFDataType = nil): TKViewTableHeaderField;
    /// <summary>Binds the header field to a model field. Returns Self.</summary>
    function SetModelField(const AValue: TKModelField): TKViewTableHeaderField;

    /// <summary>The bound view field.</summary>
    property ViewField: TKViewField read FViewField;
    /// <summary>Cached ViewField.IsPassword (masking flag).</summary>
    property ViewFieldIsPassword: Boolean read FViewFieldIsPassword;
    /// <summary>Cached ViewField.DisplayTemplate.</summary>
    property ViewFieldDisplayTemplate: string read FViewFieldDisplayTemplate;
    /// <summary>
    /// If the ViewField is a reference field, this property stores either:
    /// - ViewField.ModelField (if it's the reference field itself, e.g. Customer), or
    /// - The actual model field (if it's a physical field that was expanded
    /// as part of the reference, e.g. Customer_Id).
    /// If ViewField is not a reference field, this property always stores ViewField.ModelField.
    /// </summary>
    property ModelField: TKModelField read FModelField;
  end;

  /// <summary>A field of a record in a view-table store, aware of its view field
  /// and applying view-level rendering (password masking, display template).</summary>
  TKViewTableField = class(TKField)
  strict private
    function GetParentRecord: TKViewTableRecord;
    function GetHeaderField: TKViewTableHeaderField;
    function GetViewField: TKViewField;
  private
    function GetModelField: TKModelField;
  strict protected
    function GetDecimalPrecision: Integer; override;
  public
    /// <summary>Returns the effective EmptyAsNull setting (delegates to the view field).</summary>
    function GetEmptyAsNull: Boolean; override;
    /// <summary>View-aware JSON value: applies password masking and DisplayTemplate expansion.</summary>
    function GetAsJSONValue(const AForDisplay: Boolean; const AQuote: Boolean = True;
      const AEmptyNulls: Boolean = False): string; override;
    /// <summary>The record that owns this field (typed).</summary>
    property ParentRecord: TKViewTableRecord read GetParentRecord;
    /// <summary>The view-table header field describing this field.</summary>
    property HeaderField: TKViewTableHeaderField read GetHeaderField;
    /// <summary>The view field this store field maps to.</summary>
    property ViewField: TKViewField read GetViewField;
    /// <summary>
    /// <seealso>TKViewTableHeaderField.ModelField</seealso>
    /// </summary>
    property ModelField: TKModelField read GetModelField;
    /// <summary>
    ///  True if ViewField.IsReference and (ModelField <> ViewField.ModelField).
    /// </summary>
    function IsPhysicalPartOfReference: Boolean;
  end;

  /// <summary>
  ///  A record in a view-table store. Adds view-aware behavior on top of
  ///  TKRecord: detail stores, reference/derived-value refresh, rule application
  ///  (new/edit/duplicate/before/after), field-value expansion and typed field
  ///  access.
  /// </summary>
  TKViewTableRecord = class(TKRecord)
  strict private
    function GetRecords: TKViewTableRecords;
    function GetDetailsStore(I: Integer): TKViewTableStore;
    function GetStore: TKViewTableStore;
    function GetViewTable: TKViewTable;
    function GetField(I: Integer): TKViewTableField;
    /// <summary>OnFieldChange handler that runs the AfterFieldChange rules of
    /// the changed field. Installed by ApplyNewRecordRules for the duration of
    /// the new-record rules.</summary>
    procedure FieldChangeRulesHandler(const AField: TKField;
      const AOldValue, ANewValue: Variant);
  private
    FReferenceViewFieldBeingChanged: TKViewField;
  strict protected
    procedure InternalAfterReadFromNode; override;
    function GetChildClass(const AName: string): TEFNodeClass; override;
    function GetXMLTagName: string; override;
    function TranslateFieldName(const AFieldName: string): string; override;
  public
    /// <summary>Called before a field's value changes; can veto the change via ADoIt.</summary>
    procedure FieldChanging(const AField: TKField; const AOldValue: Variant;
      var ANewValue: Variant; var ADoIt: Boolean); override;
    /// <summary>Called after a field's value changed; refreshes derived reference values.</summary>
    procedure FieldChanged(const AField: TKField; const AOldValue, ANewValue: Variant); override;
    /// <summary>The record collection this record belongs to (typed).</summary>
    property Records: TKViewTableRecords read GetRecords;
    /// <summary>The store owning this record (typed).</summary>
    property Store: TKViewTableStore read GetStore;
    /// <summary>The view table this record belongs to.</summary>
    property ViewTable: TKViewTable read GetViewTable;
    /// <summary>Creates the detail stores (one per detail table) if not already present.</summary>
    procedure EnsureDetailStores;
    /// <summary>Loads the detail stores' rows from the database for this master record.</summary>
    procedure LoadDetailStores;
    /// <summary>The detail (child) stores, by index (typed).</summary>
    property DetailStores[I: Integer]: TKViewTableStore read GetDetailsStore;
    /// <summary>Attaches a detail store to this record and returns it.</summary>
    function AddDetailStore(const AStore: TKViewTableStore): TKViewTableStore;
    /// <summary>Reloads this record's values from the database (AStrict raises if it vanished).</summary>
    procedure Refresh(const AStrict: Boolean = False);
    /// <summary>Propagates the master record's key onto this (detail) record's FK fields.</summary>
    procedure SetDetailFieldValues(const AMasterRecord: TKViewTableRecord);
    /// <summary>
    ///  Refreshes the derived values (caption + AutoAddFields) of the reference
    ///  fields whose foreign key is set but whose caption is still empty, by
    ///  querying the referenced model. Mirrors what FieldChanged does per-field,
    ///  but can be invoked explicitly after a bulk populate (where change
    ///  notifications are disabled), so reference captions appear immediately
    ///  for freshly-added in-memory records.
    /// </summary>
    procedure RefreshDerivedReferenceValues;
    /// <summary>
    ///  Fills the values this record shows through its reference to its own
    ///  master -- the caption and the reference's derived (AutoAddFields)
    ///  fields -- from the master record in memory, instead of querying the
    ///  referenced model.
    /// </summary>
    /// <remarks>
    ///  RefreshDerivedReferenceValues resolves those with a select, which
    ///  cannot work while the master has no row yet, and the master record is
    ///  right there in the store. None of these values is a column of the
    ///  detail's own table -- they are what its join brings in -- so filling
    ///  them changes what is shown, never what is written.
    ///  Idempotent, and meant to be called again on every render: the master
    ///  may have been edited after the detail row was added.
    /// </remarks>
    procedure RefreshMasterReferenceValues;
    /// <summary>Returns the detail store for the given model name, or nil (AForceLoad loads its rows).</summary>
    function FindDetailStoreByModelName(const AModelName: string; const AForceLoad: Boolean = False): TKViewTableStore;
    /// <summary>Like FindDetailStoreByModelName but raises if not found.</summary>
    function GetDetailStoreByModelName(const AModelName: string; const AForceLoad: Boolean = False): TKViewTableStore;
    /// <summary>Executes the deferred file-deletion instructions for FileReference fields.</summary>
    procedure HandleDeleteFileInstructions;

    /// <summary>Applies the model/view new-record rules (defaults, computed
    /// values). AFireFieldChangeRules keeps the AfterFieldChange cascade alive
    /// while they run, so that a value a NewRecord rule assigns triggers the
    /// rules that depend on it; pass False for batch paths that must not run
    /// them (see the remarks).</summary>
    /// <remarks>In Kitto1 the cascade was on for a record being prepared for a
    /// form, because the form controller installed its field-change handler
    /// before applying these rules (Kitto.Ext.Form.pas, EnableFieldChangeHandler
    /// then ApplyNewRecordRules) and kept it for the whole life of the form,
    /// and off for the Excel import, which applied the rules on a record with
    /// no handler attached (Kitto.Excel.pas). The default preserves the first,
    /// far more common case.</remarks>
    procedure ApplyNewRecordRules(const AFireFieldChangeRules: Boolean = True);
    /// <summary>Same as ApplyNewRecordRules but also fires the model's Before/AfterNewRecord events.</summary>
    procedure ApplyNewRecordRulesAndFireEvents(const AViewTable: TKViewTable;
      const AIsCloned: Boolean; const AFireFieldChangeRules: Boolean = True);
    /// <summary>Applies the edit-record rules (on transition to edit mode).</summary>
    procedure ApplyEditRecordRules;
    /// <summary>Applies the rules to run after the edit window is shown.</summary>
    procedure ApplyAfterShowEditWindowRules;
    /// <summary>Applies the duplicate-record rules (on a clone/duplicate operation).</summary>
    procedure ApplyDuplicateRecordRules;
    /// <summary>
    ///  Initializes this (freshly appended) record as a clone of ASource: copies
    ///  all values except the key fields, whose default values are re-applied so
    ///  that generated keys (%COMPACT_GUID% and the like) get a fresh value, then
    ///  fires the new-record rules and events with AIsCloned=True. The record is
    ///  left in the rsNew state, so persisting it issues an INSERT.
    ///  Mirrors Kitto1's TKExtFormPanelController.StartOperation (clone branch).
    /// </summary>
    procedure InitAsCloneOf(const ASource: TKViewTableRecord);
    /// <summary>Applies the BeforeAddOrUpdate rules (e.g. updating the master from details).</summary>
    procedure ApplyBeforeRules;
    /// <summary>Applies the AfterAddOrUpdate rules (post-persist side effects).</summary>
    procedure ApplyAfterRules;
    /// <summary>
    ///  Applies the AfterConfirm rules: the master of a master-detail form has
    ///  been confirmed into the session cache, nothing written yet. On error
    ///  the master values are restored; the detail stores are not.
    /// </summary>
    procedure ApplyConfirmRules;
    /// <summary>
    ///  Gives this row a temporary key, if it is a new row of an in-memory
    ///  detail store whose integer key is generated by the database
    ///  (IsGenerated) and still null.
    /// </summary>
    /// <remarks>
    ///  <para>
    ///   Rows of a detail store are told apart by their key: the grid writes
    ///   it in each row, and opening, saving and deleting a pending row look
    ///   the row up by it. Before the row is written, a database-generated key
    ///   is null, so every unsaved row had the same empty key and every lookup
    ///   found the first one: opening a row showed another row's values,
    ///   saving it overwrote that other row, deleting it removed that one.
    ///  </para>
    ///  <para>
    ///   The value is negative and unique within the process, so it can never
    ///   match a key the database generated. It never reaches the database: a
    ///   generated field is left out of the INSERT (CanInsert is False). Only
    ///   integer keys are handled; other generated keys are left alone.
    ///  </para>
    /// </remarks>
    procedure EnsureTemporaryKey;

    /// <summary>The record's fields, by index (typed; default property).</summary>
    property Fields[I: Integer]: TKViewTableField read GetField; default;
    /// <summary>Returns the field with the given name, or nil (typed).</summary>
    function FindField(const AFieldName: string): TKViewTableField;
    /// <summary>Returns the field with the given name; raises if absent (typed).</summary>
    function FieldByName(const AFieldName: string): TKViewTableField;
    /// <summary>
    ///  Finds the scalar field that maps to the given physical DB column,
    ///  looking through the scalar sub-fields expanded from reference fields.
    ///  Returns the scalar (sub-)field, never the reference field itself, so
    ///  its value can be bound as a parameter. Returns nil if not found.
    /// </summary>
    function FindFieldByDBColumnName(const ADBColumnName: string): TKViewTableField;
    /// <summary>
    ///  Like FindFieldByDBColumnName but raises if no field is found.
    /// </summary>
    function FieldByDBColumnName(const ADBColumnName: string): TKViewTableField;

    /// <summary>
    ///  Replaces all field name markers in AText with the current field values
    ///  in JSON format.
    ///  A field name marker is in the form {FieldName}.
    ///  Pass True in AEmptyNulls to expand null fields to empty strings,
    ///  otherwise they are expanded as 'null'.
    ///  If ASender is specified, then the value of the corresponding field
    ///  is not expanded (useful to avoid infinite recursion when this method
    ///  is called by TKViewTableField.GetAsJSONValue).
    /// </summary>
    procedure ExpandFieldJSONValues(var AText: string;
      const AEmptyNulls: Boolean; const ASender: TKViewField = nil);

    /// <summary>
    ///  Replaces occurrencess of {FieldName} tags in the specified string
    ///  with actual field values, formatted as strings.
    ///  If the record's store has a master record, this method also replaces
    ///  occurrences of {MasterRecord.FieldName} with string representations of
    ///  master record field values.
    /// </summary>
    procedure ExpandExpression(var AExpression: string); override;
  end;

  /// <summary>The collection of records of a view-table store (typed).</summary>
  TKViewTableRecords = class(TKRecords)
  strict private
    function GetStore: TKViewTableStore;
    function GetRecord(I: Integer): TKViewTableRecord; overload;
  strict protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
    function GetXMLTagName: string; override;
  public
    /// <summary>The store owning this collection (typed).</summary>
    property Store: TKViewTableStore read GetStore;
    /// <summary>Appends a new (empty) record and returns it (typed).</summary>
    function Append: TKViewTableRecord;
    /// <summary>Appends a new record and initializes its fields from the header (typed).</summary>
    function AppendAndInitialize: TKViewTableRecord;
    /// <summary>The records, by index (typed; default property).</summary>
    property Records[I: Integer]: TKViewTableRecord read GetRecord; default;

    /// <summary>Returns the record matching the key values in AValues, or nil (typed).</summary>
    function FindRecord(const AValues: TEFNode): TKViewTableRecord;
    /// <summary>Returns the record matching the key values in AValues; raises if absent (typed).</summary>
    function GetRecord(const AValues: TEFNode): TKViewTableRecord; overload;
  end;

  { ---------- Grouping sub-nodes ---------- }

  /// <summary>
  ///  ShowCount sub-node inside Grouping.
  ///  YAML path: Controller/Grouping/ShowCount
  /// </summary>
  TKGroupingShowCountConfig = class(TEFNode)
  private
    function GetItemName: string;
    function GetPluralItemName: string;
    function GetTemplate: string;
  public
    [YamlNode('ItemName', 'Singular item name displayed in count')]
    property ItemName: string read GetItemName;

    [YamlNode('PluralItemName', 'Plural item name displayed in count')]
    property PluralItemName: string read GetPluralItemName;

    [YamlNode('Template', 'Custom template for count display')]
    property Template: string read GetTemplate;
  end;

  /// <summary>
  ///  Grouping configuration for list controllers.
  ///  YAML path: Controller/Grouping
  /// </summary>
  TKGroupingConfig = class(TEFNode)
  private
    function GetFieldName: string;
    function GetSortFieldNames: string;
    function GetEnableMenu: Boolean;
    function GetStartCollapsed: Boolean;
    function GetShowName: Boolean;
    function GetAggregates: string;
    function GetShowCount: TKGroupingShowCountConfig;
  public
    [YamlRequiredNode('FieldName', 'Field used for grouping rows')]
    property FieldName: string read GetFieldName;

    [YamlNode('SortFieldNames', 'Comma-separated fields to sort within groups')]
    property SortFieldNames: string read GetSortFieldNames;

    [YamlNode('EnableMenu', 'False', 'Show grouping context menu')]
    property EnableMenu: Boolean read GetEnableMenu;

    [YamlNode('StartCollapsed', 'False', 'Initially collapse all groups')]
    property StartCollapsed: Boolean read GetStartCollapsed;

    [YamlNode('ShowName', 'False', 'Display group field name in header')]
    property ShowName: Boolean read GetShowName;

    /// <summary>RTTI carrier for the Aggregates node: per-column aggregate
    /// functions (sum/count/...) shown in each group header. Read by path.</summary>
    [YamlNode('Aggregates', 'Per-column aggregate functions shown in group headers (sum, count, ...)')]
    property Aggregates: string read GetAggregates;

    [YamlSubNode('ShowCount', TKGroupingShowCountConfig, 'Show count display options')]
    property ShowCount: TKGroupingShowCountConfig read GetShowCount;
  end;

  { ---------- Popup window ---------- }

  /// <summary>
  ///  Popup window dimensions for form controllers.
  ///  YAML path: Controller/PopupWindow
  /// </summary>
  TKPopupWindowConfig = class(TEFNode)
  private
    function GetWidth: Integer;
    function GetHeight: Integer;
  public
    [YamlNode('Width', '800', 'Popup window width in pixels')]
    property Width: Integer read GetWidth;

    [YamlNode('Height', '600', 'Popup window height in pixels')]
    property Height: Integer read GetHeight;
  end;

  { ---------- Form controller button ---------- }

  /// <summary>
  ///  Custom button inside a FormController.
  ///  YAML path: Controller/FormController/Button
  /// </summary>
  TKFormControllerButtonConfig = class(TEFNode)
  private
    function GetCaption: string;
    function GetToolTip: string;
  public
    [YamlNode('Caption', 'Button caption text')]
    property Caption: string read GetCaption;

    [YamlNode('ToolTip', 'Button tooltip text')]
    property ToolTip: string read GetToolTip;
  end;

  { ---------- Form controller ---------- }

  /// <summary>
  ///  Form controller behaviour settings.
  ///  YAML path: Controller/FormController
  /// </summary>
  TKFormControllerConfig = class(TEFNode)
  private
    function GetKeepOpenAfterOperation: Boolean;
    function GetButtonScale: string;
    function GetCloneButton: TKFormControllerButtonConfig;
    function GetConfirmButton: TKFormControllerButtonConfig;
    function GetCancelButton: TKFormControllerButtonConfig;
    function GetCloseButton: TKFormControllerButtonConfig;
  public
    [YamlNode('KeepOpenAfterOperation', 'False', 'Keep form open after save/delete')]
    property KeepOpenAfterOperation: Boolean read GetKeepOpenAfterOperation;

    [YamlNode('ButtonScale', 'CSS scale class for form buttons')]
    property ButtonScale: string read GetButtonScale;

    [YamlSubNode('CloneButton', TKFormControllerButtonConfig, 'Clone/duplicate button')]
    property CloneButton: TKFormControllerButtonConfig read GetCloneButton;

    [YamlSubNode('ConfirmButton', TKFormControllerButtonConfig, 'Save/confirm button')]
    property ConfirmButton: TKFormControllerButtonConfig read GetConfirmButton;

    [YamlSubNode('CancelButton', TKFormControllerButtonConfig, 'Cancel button')]
    property CancelButton: TKFormControllerButtonConfig read GetCancelButton;

    [YamlSubNode('CloseButton', TKFormControllerButtonConfig, 'Close button')]
    property CloseButton: TKFormControllerButtonConfig read GetCloseButton;
  end;

  { ---------- ToolViews ---------- }

  /// <summary>
  ///  Single tool view item inside a ToolViews container.
  ///  YAML path: Controller/ToolViews/{ToolName}
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKToolViewItem = class(TEFNode)
  private
    function GetDisplayLabel: string;
    function GetImageName: string;
    function GetControllerType: string;
    function GetRequireSelection: Boolean;
    function GetAutoRefresh: string;
    function GetConfirmationMessage: string;
    function GetHint: string;
  public
    [YamlNode('DisplayLabel', 'Label shown on the tool button', True)]
    property DisplayLabel: string read GetDisplayLabel;

    [YamlNode('Hint', 'Tooltip shown on hover over the tool button', True)]
    property Hint: string read GetHint;

    [YamlNode('ImageName', 'Icon name for the tool button')]
    property ImageName: string read GetImageName;

    [YamlNode('Controller', 'Controller type for this tool')]
    property ControllerType: string read GetControllerType;

    [YamlNode('RequireSelection', 'False', 'Require a selected record before executing')]
    property RequireSelection: Boolean read GetRequireSelection;

    [YamlNode('AutoRefresh', 'All', 'Refresh mode after execution: All, Current, None')]
    [YamlEnumValue('All', 'Refresh all records')]
    [YamlEnumValue('Current', 'Refresh the current record only')]
    [YamlEnumValue('None', 'Do not refresh')]
    property AutoRefresh: string read GetAutoRefresh;

    [YamlNode('ConfirmationMessage', 'User confirmation prompt before executing', True)]
    property ConfirmationMessage: string read GetConfirmationMessage;
  end;

  /// <summary>
  ///  Container for tool view items.
  ///  YAML path: Controller/ToolViews
  /// </summary>
  [YamlChildType('DownloadText', '', 'Download as text file')]
  [YamlChildType('DownloadCSV', '', 'Download as CSV file')]
  [YamlChildType('DownloadExcel', '', 'Download as Excel file')]
  [YamlChildType('DownloadMergedPDF', '', 'Download as merged PDF')]
  [YamlChildType('DownloadFOPReport', '', 'Download PDF via FOP')]
  [YamlChildType('DownloadHTMLReport', '', 'Download HTML report via XSL')]
  [YamlChildType('DownloadFile', '', 'Download a server file')]
  [YamlChildType('UploadFile', '', 'Upload a file')]
  [YamlChildType('UploadExcel', '', 'Upload and import Excel file')]
  [YamlChildType('ExecuteSQLCommand', '', 'Execute SQL command')]
  [YamlChildType('SendEmail', '', 'Send email')]
  [YamlChildType('DisplayView', '', 'Display a view')]
  [YamlChildType('URL', '', 'Open a URL')]
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKToolViewsConfig = class(TEFNode)
  end;

  { ---------- Filter item types ---------- }

  /// <summary>
  ///  Free-text search filter.
  ///  YAML path: Filters/Items/FreeSearch
  /// </summary>
  TKFilterItemFreeSearch = class(TEFNode)
  private
    function GetDefaultValue: string;
    function GetExpressionTemplate: string;
    function GetWidth: Integer;
    function GetAutoSearchAfterChars: Integer;
    function GetIsRequired: Boolean;
  public
    [YamlNode('DefaultValue', 'Initial search text')]
    property DefaultValue: string read GetDefaultValue;

    [YamlRequiredNode('ExpressionTemplate', 'SQL WHERE template with {value} placeholder')]
    property ExpressionTemplate: string read GetExpressionTemplate;

    [YamlNode('Width', '10', 'Input width in characters')]
    property Width: Integer read GetWidth;

    [YamlNode('AutoSearchAfterChars', '0', 'Trigger the search automatically after this many typed characters (0 = manual)')]
    property AutoSearchAfterChars: Integer read GetAutoSearchAfterChars;

    [YamlNode('IsRequired', 'False', 'The filter must have a value before the grid loads')]
    property IsRequired: Boolean read GetIsRequired;
  end;

  /// <summary>
  ///  Dynamic list filter populated by a SQL query.
  ///  YAML path: Filters/Items/DynaList
  /// </summary>
  TKFilterItemDynaList = class(TEFNode)
  private
    function GetExpressionTemplate: string;
    function GetCommandText: string;
    function GetWidth: Integer;
    function GetListWidth: Integer;
    function GetAutoCompleteMinChars: Integer;
    function GetQueryTemplate: string;
    function GetDefaultValueExpression: string;
  public
    [YamlRequiredNode('ExpressionTemplate', 'SQL WHERE template with {value} placeholder')]
    property ExpressionTemplate: string read GetExpressionTemplate;

    [YamlRequiredNode('CommandText', 'SQL query returning key/display pairs')]
    property CommandText: string read GetCommandText;

    [YamlNode('QueryTemplate', 'Optional SQL WHERE fragment filtering the dropdown query by typed text ({queryValue} placeholder)')]
    property QueryTemplate: string read GetQueryTemplate;

    [YamlNode('DefaultValueExpression', 'SQL expression computing the initial selected value')]
    property DefaultValueExpression: string read GetDefaultValueExpression;

    [YamlNode('Width', '20', 'Input width in characters')]
    property Width: Integer read GetWidth;

    [YamlNode('ListWidth', '20', 'Dropdown list width in characters')]
    property ListWidth: Integer read GetListWidth;

    [YamlNode('AutoCompleteMinChars', '0', 'Min chars before autocomplete triggers')]
    property AutoCompleteMinChars: Integer read GetAutoCompleteMinChars;
  end;

  /// <summary>
  ///  Date-range search filter.
  ///  YAML path: Filters/Items/DateSearch
  /// </summary>
  TKFilterItemDateSearch = class(TEFNode)
  private
    function GetDefaultValue: string;
    function GetExpressionTemplate: string;
    function GetWidth: Integer;
    function GetLabelWidth: Integer;
  public
    [YamlNode('DefaultValue', 'Initial date value')]
    property DefaultValue: string read GetDefaultValue;

    [YamlRequiredNode('ExpressionTemplate', 'SQL WHERE template with {value} placeholder')]
    property ExpressionTemplate: string read GetExpressionTemplate;

    [YamlNode('Width', '10', 'Input width in characters')]
    property Width: Integer read GetWidth;

    [YamlNode('LabelWidth', 'Label width in pixels for this filter')]
    property LabelWidth: Integer read GetLabelWidth;
  end;

  /// <summary>
  ///  Static list filter with predefined items.
  ///  YAML path: Filters/Items/List
  /// </summary>
  TKFilterItemList = class(TEFNode)
  private
    function GetWidth: Integer;
    function GetListWidth: Integer;
    function GetAutoCompleteMinChars: Integer;
    function GetItems: string;
  public
    [YamlNode('Width', '20', 'Input width in characters')]
    property Width: Integer read GetWidth;

    [YamlNode('ListWidth', '20', 'Dropdown list width in characters')]
    property ListWidth: Integer read GetListWidth;

    [YamlNode('AutoCompleteMinChars', '0', 'Min chars before autocomplete triggers')]
    property AutoCompleteMinChars: Integer read GetAutoCompleteMinChars;

    /// <summary>RTTI carrier for the Items node: the predefined options, each a
    /// named entry (label as value) carrying an Expression. Read node by node at
    /// filter-build time; the getter is unused.</summary>
    [YamlNode('Items', 'Predefined list options (each a named entry with an Expression)')]
    property Items: string read GetItems;
  end;

  /// <summary>
  ///  Apply/Search button in a filter panel.
  ///  YAML path: Filters/Items/ApplyButton
  /// </summary>
  TKFilterItemApplyButton = class(TEFNode)
  private
    function GetImageName: string;
  public
    [YamlNode('ImageName', 'Find', 'Icon name for the apply button')]
    property ImageName: string read GetImageName;
  end;

  /// <summary>
  ///  Column break in filter panel layout.
  ///  YAML path: Filters/Items/ColumnBreak
  /// </summary>
  TKFilterItemColumnBreak = class(TEFNode)
  private
    function GetLabelWidth: Integer;
  public
    [YamlNode('LabelWidth', '50', 'Label width in pixels for the next column')]
    property LabelWidth: Integer read GetLabelWidth;
  end;

  /// <summary>
  ///  Spacer element in a filter panel.
  ///  YAML path: Filters/Items/Spacer
  /// </summary>
  TKFilterItemSpacer = class(TEFNode)
  private
    function GetWidth: Integer;
  public
    [YamlNode('Width', '1', 'Spacer width in characters')]
    property Width: Integer read GetWidth;
  end;

  // NB: TEFDB{FD,DBX,ADO,ODAC}ConnectionConfig moved to their adapter units
  // EF.DB.{FD,DBX,ADO,ODAC} (descriptor next to consumer).

  /// <summary>
  ///  Container of the filter items under a List controller's Filters panel.
  ///  Each child is one filter item of the type named by its node; the node is
  ///  resolved to its descriptor class (below) so KIDE renders the per-type editor.
  ///  YAML path: Controller/Filters/Items
  /// </summary>
  [YamlChildType('FreeSearch', TKFilterItemFreeSearch, '', 'Free-text search field')]
  [YamlChildType('DynaList', TKFilterItemDynaList, '', 'Dynamic (SQL-backed) dropdown filter')]
  [YamlChildType('DateSearch', TKFilterItemDateSearch, '', 'Date search field')]
  [YamlChildType('NumericSearch', TKFilterItemFreeSearch, '', 'Numeric search field')]
  [YamlChildType('BooleanSearch', '', 'Boolean (yes/no) search field')]
  [YamlChildType('List', TKFilterItemList, '', 'Static/lookup list filter')]
  [YamlChildType('ButtonList', TKFilterItemList, '', 'Static list filter rendered as buttons')]
  [YamlChildType('Lookup', '', 'Lookup (reference) filter')]
  [YamlChildType('ApplyButton', TKFilterItemApplyButton, '', 'Apply-filter button')]
  [YamlChildType('ColumnBreak', TKFilterItemColumnBreak, '', 'Start a new filter column')]
  [YamlChildType('Spacer', TKFilterItemSpacer, '', 'Horizontal spacer')]
  TKFilterItemsConfig = class(TEFNode)
  end;

  /// <summary>
  ///  Filter panel configuration for List controllers.
  ///  YAML path: Controller/Filters
  /// </summary>
  /// <example>
  ///  Filters:
  ///    DisplayLabel: Search
  ///    LabelWidth: 80
  ///    Connector: and
  ///    Collapsed: False
  ///    Items:
  ///      FreeSearch: ...
  /// </example>
  TKFilterPanelConfig = class(TEFNode)
  private
    function GetDisplayLabel: string;
    function GetLabelWidth: Integer;
    function GetConnector: string;
    function GetCollapsed: Boolean;
    function GetCollapsible: Boolean;
    function GetColumnWidth: Integer;
    function GetLabelAlign: string;
    function GetItems: TKFilterItemsConfig;
  public
    [YamlNode('DisplayLabel', 'Filters', 'Title shown on the filter panel', True)]
    property DisplayLabel: string read GetDisplayLabel;

    [YamlNode('LabelWidth', '80', 'Width in pixels for filter field labels')]
    property LabelWidth: Integer read GetLabelWidth;

    [YamlNode('Connector', 'and', 'Logical connector: and/or')]
    [YamlEnumType(TypeInfo(TKFilterConnector))]
    property Connector: string read GetConnector;

    [YamlNode('Collapsed', 'False', 'Show filter panel initially collapsed')]
    property Collapsed: Boolean read GetCollapsed;

    [YamlNode('Collapsible', 'True', 'Allow the filter panel to be collapsed/expanded')]
    property Collapsible: Boolean read GetCollapsible;

    [YamlNode('ColumnWidth', '50', 'Column width for filter layout')]
    property ColumnWidth: Integer read GetColumnWidth;

    [YamlNode('LabelAlign', 'Top', 'Label alignment: Top, Left, Right')]
    [YamlEnumType(TypeInfo(TKLabelAlign))]
    property LabelAlign: string read GetLabelAlign;

    [YamlSubNode('Items', TKFilterItemsConfig, 'Filter items (search fields, buttons, layout breaks)')]
    property Items: TKFilterItemsConfig read GetItems;
  end;

  { ---------- Edit controller ---------- }

  /// <summary>
  ///  Settings of the embedded edit form of a ViewTable (the form opened to
  ///  add/edit a record). YAML path: EditController.
  /// </summary>
  TKEditControllerConfig = class(TEFNode)
  private
    function GetWidth: Integer;
    function GetHeight: Integer;
    function GetLabelWidth: Integer;
    function GetLabelAlign: string;
    function GetCloneButton: Boolean;
    function GetKeepOpenAfterOperation: Boolean;
    function GetToolViews: TKToolViewsConfig;
    function GetShowNavigationButtons: Boolean;
    function GetApplyButton: string;
  public
    [YamlNode('Width', 'Edit form width in pixels (0 = auto)')]
    property Width: Integer read GetWidth;
    [YamlNode('Height', 'Edit form height in pixels (0 = auto)')]
    property Height: Integer read GetHeight;
    [YamlNode('LabelWidth', 'Field label width in pixels (overrides Defaults/FormPanel/LabelWidth)')]
    property LabelWidth: Integer read GetLabelWidth;
    [YamlNode('LabelAlign', 'Field label alignment: top / left / right')]
    [YamlEnumType(TypeInfo(TKLabelAlign))]
    property LabelAlign: string read GetLabelAlign;
    [YamlNode('CloneButton', 'False', 'Show a Clone button on the edit form')]
    property CloneButton: Boolean read GetCloneButton;
    [YamlNode('KeepOpenAfterOperation', 'False', 'Keep the edit form open after Save')]
    property KeepOpenAfterOperation: Boolean read GetKeepOpenAfterOperation;
    [YamlNode('ShowNavigationButtons', 'False', 'Show previous/next record navigation buttons on the edit form')]
    property ShowNavigationButtons: Boolean read GetShowNavigationButtons;
    /// <summary>RTTI carrier for the ApplyButton node (an Apply button that saves
    /// without closing the form). Read node by node at render time.</summary>
    [YamlNode('ApplyButton', 'Show an Apply button that saves without closing the edit form')]
    property ApplyButton: string read GetApplyButton;
    [YamlContainer('ToolViews', TKToolViewItem, 'Tool buttons shown on the edit form toolbar (each a freely-named item whose Controller names the tool)')]
    property ToolViews: TKToolViewsConfig read GetToolViews;
  end;

  { ---------- ViewTable Controller ---------- }

  /// <summary>
  ///  Controller-level settings for a ViewTable list controller.
  ///  YAML path: Controller
  /// </summary>
  TKViewTableControllerConfig = class(TEFNode)
  private
    function GetAutoOpen: Boolean;
    function GetPageRecordCount: Integer;
    function GetPagingTools: Boolean;
    function GetRowClassProvider: string;
    function GetAllowViewing: Boolean;
    function GetPreventEditing: Boolean;
    function GetPreventAdding: Boolean;
    function GetPreventDeleting: Boolean;
    function GetAllowDuplicating: Boolean;
    function GetToolViews: TKToolViewsConfig;
    function GetPopupWindow: TKPopupWindowConfig;
    function GetGrouping: TKGroupingConfig;
    function GetFormController: TKFormControllerConfig;
    function GetFilters: TKFilterPanelConfig;
    function GetForm: string;
    function GetGrid: string;
    function GetWidth: Integer;
    function GetHeight: Integer;
    function GetIsMultiSelect: Boolean;
    function GetAllowInsert: Boolean;
    function GetAllowEdit: Boolean;
    function GetAllowDelete: Boolean;
    function GetDefaultAction: string;
    function GetAdd: string;
  public
    /// <summary>RTTI carrier for the Grid node: selects the grid layout (its
    /// Layout child names it; see TKViewTable.FindLayout('Grid')).</summary>
    [YamlNode('Grid', 'Grid layout selector (its Layout child names the grid layout)')]
    property Grid: string read GetGrid;

    [YamlNode('DefaultAction', 'Action on grid row double-click (e.g. Edit, View)')]
    property DefaultAction: string read GetDefaultAction;

    [YamlNode('AllowInsert', 'True', 'Allow inserting new records (legacy inverse of PreventAdding)')]
    property AllowInsert: Boolean read GetAllowInsert;

    [YamlNode('AllowEdit', 'True', 'Allow editing records (legacy inverse of PreventEditing)')]
    property AllowEdit: Boolean read GetAllowEdit;

    [YamlNode('AllowDelete', 'True', 'Allow deleting records (legacy inverse of PreventDeleting)')]
    property AllowDelete: Boolean read GetAllowDelete;

    /// <summary>RTTI carrier for the Add toolbar-action options node (e.g.
    /// Controller/Add/Tooltip).</summary>
    [YamlNode('Add', 'Options for the Add toolbar action (e.g. Tooltip)')]
    property Add: string read GetAdd;

    [YamlNode('Width', 'Grid panel width in pixels (0 = auto)')]
    property Width: Integer read GetWidth;

    [YamlNode('Height', 'Grid panel height in pixels (0 = auto)')]
    property Height: Integer read GetHeight;

    [YamlNode('IsMultiSelect', 'False', 'Allow selecting multiple rows in the grid')]
    property IsMultiSelect: Boolean read GetIsMultiSelect;

    [YamlNode('AutoOpen', 'False', 'Auto-load grid data when view opens (default: not IsLarge)')]
    property AutoOpen: Boolean read GetAutoOpen;

    [YamlNode('PageRecordCount', 'Number of records per page')]
    property PageRecordCount: Integer read GetPageRecordCount;

    [YamlNode('PagingTools', 'True', 'Show paging toolbar (default: IsLarge)')]
    property PagingTools: Boolean read GetPagingTools;

    [YamlNode('RowClassProvider', 'Server-side function returning CSS class per row')]
    property RowClassProvider: string read GetRowClassProvider;

    [YamlNode('AllowViewing', 'False', 'Show a read-only View button')]
    property AllowViewing: Boolean read GetAllowViewing;

    [YamlNode('PreventEditing', 'False', 'Hide the Edit button')]
    property PreventEditing: Boolean read GetPreventEditing;

    [YamlNode('PreventAdding', 'False', 'Hide the Add button')]
    property PreventAdding: Boolean read GetPreventAdding;

    [YamlNode('PreventDeleting', 'False', 'Hide the Delete button')]
    property PreventDeleting: Boolean read GetPreventDeleting;

    [YamlNode('AllowDuplicating', 'False', 'Show a Duplicate button')]
    property AllowDuplicating: Boolean read GetAllowDuplicating;

    [YamlContainer('ToolViews', TKToolViewItem, 'Tool buttons and actions (each a freely-named item whose Controller names the tool)')]
    property ToolViews: TKToolViewsConfig read GetToolViews;

    [YamlSubNode('PopupWindow', TKPopupWindowConfig, 'Modal window size for add/edit')]
    property PopupWindow: TKPopupWindowConfig read GetPopupWindow;

    [YamlSubNode('Grouping', TKGroupingConfig, 'Row grouping configuration')]
    property Grouping: TKGroupingConfig read GetGrouping;

    [YamlSubNode('FormController', TKFormControllerConfig, 'Form controller options')]
    property FormController: TKFormControllerConfig read GetFormController;

    [YamlSubNode('Filters', TKFilterPanelConfig, 'Search/filter panel (List views)')]
    property Filters: TKFilterPanelConfig read GetFilters;

    /// <summary>RTTI carrier for the Form node: selects the edit-form layout
    /// (child Layout names it; see TKViewTable.FindLayout('Form')). The getter is
    /// unused; the node is read directly at render time.</summary>
    [YamlNode('Form', 'Edit-form layout selector (its Layout child names the form layout)')]
    property Form: string read GetForm;
  end;

  /// <summary>
  ///  A table within a data view: selects a model, its fields (as view fields),
  ///  detail tables, filtering/sorting and controller configuration. The main
  ///  table drives the view; detail tables form master-detail relationships.
  ///  Creates the stores used to load and persist its data.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKViewTable = class(TKMetadataItem)
  strict private
    FFindingNode: Boolean;
    function GetIsDetail: Boolean;
    function GetField(I: Integer): TKViewField;
    function GetFieldCount: Integer;
    function GetModelName: string;
    function GetModel: TKModel;
    function GetDetailTableCount: Integer;
    function GetDetailTable(I: Integer): TKViewTable;
    function GetDisplayLabel: string;
    function GetPluralDisplayLabel: string;
    function GetIsReadOnly: Boolean;
    function GetPreventAdding: Boolean;
    function GetPreventEditing: Boolean;
    function GetPreventDeleting: Boolean;
    function GetMasterTable: TKViewTable;
    function GetDefaultSorting: string;
    function GetDefaultFilter: string;
    function GetStyle: string;
    function GetViewPluralModelName: string;
    function GetViewHeight: Integer;
    function GetView: TKDataView;
    function GetRules: TKRules;
    function GetImageName: string;
    function GetModelDetailReferenceName: string;
    function GetModelDetailReference: TKModelDetailReference;
    function GetDatabaseName: string;
  strict
  private
    function GetIsLarge: Boolean;
    function GetControllerConfig: TKViewTableControllerConfig;
    function GetEditControllerConfig: TKEditControllerConfig;
  protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
    function GetFields: TKViewFields;
    function GetDetailTables: TKViewTables;
  public
    /// <summary>The default display label (the model's, beautified).</summary>
    function GetDefaultDisplayLabel: string;

    /// <summary>Finds a child node, transparently resolving values inherited from the model.</summary>
    function FindNode(const APath: string;
      const ACreateMissingNodes: Boolean = False): TEFNode; override;

    [YamlNode('Model', 'Name of the data model for this table')]
    property ModelName: string read GetModelName;

    [YamlNode('ImageName', 'Icon name for this table')]
    property ImageName: string read GetImageName;

    /// <summary>True if this view table is a detail of another (master) view table.</summary>
    property IsDetail: Boolean read GetIsDetail;
    /// <summary>The master view table when IsDetail, otherwise nil.</summary>
    property MasterTable: TKViewTable read GetMasterTable;

    /// <summary>True if a Model name is specified for this table.</summary>
    function HasModelName: Boolean;

    /// <summary>
    ///   If the view table is a detail, this property contains the name
    ///   of the detail reference in the master view table's model. Otherwise
    ///   it's empty.
    /// </summary>
    [YamlNode('DetailReference', 'Name of the detail reference in the master table''s model')]
    property ModelDetailReferenceName: string read GetModelDetailReferenceName;

    /// <summary>If the view table is a detail, this property returns the model
    /// detail reference in the master view table's model. Otherwise raises an
    /// exception.</summary>
    /// <remarks>Check IsDetail before calling this method, if you want to
    /// avoid exceptions.</remarks>
    property ModelDetailReference: TKModelDetailReference read GetModelDetailReference;

    [YamlNode('DisplayLabel', '', 'Label shown for this table', True)]
    property DisplayLabel: string read GetDisplayLabel;
    [YamlNode('PluralDisplayLabel', '', 'Plural label shown for lists', True)]
    property PluralDisplayLabel: string read GetPluralDisplayLabel;

    /// <summary>
    ///  The model this view table is based on. Raises, naming the table and the
    ///  view, when there is none: a caller that reaches this without checking
    ///  has assumed a table that the metadata does not declare. Use FindModel
    ///  where having no model is a legitimate outcome.
    /// </summary>
    property Model: TKModel read GetModel;
    /// <summary>
    ///  The model this view table is based on, or nil when it declares none.
    ///
    ///  A data view without a Model is a normal shape, not a broken one:
    ///  'Type: Data' picks the metadata class, so that the node tree has
    ///  MainTable/Fields semantics and the controller is a data controller, but
    ///  it promises no table. A Dashboard, a ChartPanel or a tool panel draws
    ///  its own content -- for the dashboard, the views listed under Items --
    ///  and never has one. Anything that only DECORATES a table (its label, its
    ///  image) must therefore degrade quietly instead of raising, which is what
    ///  GetImageName, GetPluralDisplayLabel and GetDefaultDisplayLabel now do.
    /// </summary>
    function FindModel: TKModel;

    /// <summary>Number of view fields.</summary>
    property FieldCount: Integer read GetFieldCount;
    /// <summary>The view fields, by index.</summary>
    property Fields[I: Integer]: TKViewField read GetField;
    /// <summary>The view fields collection. Exposed (in addition to the indexed
    /// accessor) so the YAML 'Fields' container is discoverable via RTTI by the
    /// tree validator and the KIDE/MCP metadata tooling.</summary>
    [YamlContainer('Fields', TKViewField, 'The fields shown by this view table')]
    property FieldList: TKViewFields read GetFields;
    /// <summary>Returns all view field names (aliased), in order.</summary>
    function GetFieldNames: TStringDynArray;
    /// <summary>Returns the field with the given name, or nil.</summary>
    function FindField(const AName: string): TKViewField;
    /// <summary>Returns the field with the given name; raises if absent.</summary>
    function FieldByName(const AName: string): TKViewField;
    /// <summary>Returns the field with the given aliased name; raises if absent.</summary>
    function FieldByAliasedName(const AAliasedName: string): TKViewField;
    /// <summary>Returns the field with the given aliased name, or nil.</summary>
    function FindFieldByAliasedName(const AAliasedName: string): TKViewField;
    /// <summary>Returns the field mapping the given DB column, or nil.</summary>
    function FindFieldByDBColumnName(const ADBColumnName: string): TKViewField;
    /// <summary>Returns the field mapping the given DB column; raises if absent.</summary>
    function FieldByDBColumnName(const ADBColumnName: string): TKViewField;
    /// <summary>
    ///  Returns the view field matching the specified model field, or nil.
    /// </summary>
    function FindFieldByModelField(const AModelField: TKModelField): TKViewField;
    /// <summary>
    ///  Returns the view field matching the specified model field, or raises
    ///  an exception.
    /// </summary>
    function FieldByModelField(const AModelField: TKModelField): TKViewField;


    /// <summary>Returns the view fields matching the given model fields.</summary>
    function FieldsByModelFields(const AModelFields: TKModelFieldArray): TKViewFieldArray;

    /// <summary>
    ///  If a field with the specified name is contained in a parent field (at the model level),
    ///  returns a reference to the parent field, otherwise nil.
    /// </summary>
    function FindParentField(const AFieldName: string): TKViewField;
    /// <summary>Returns the aliased names of the key fields.</summary>
    function GetKeyFieldAliasedNames: TStringDynArray;
    /// <summary>Returns the view fields satisfying AFilter.</summary>
    function GetFieldArray(AFilter: TFunc<TKViewField, Boolean>): TArray<TKViewField>;

    /// <summary>True if the field is visible in this view table.</summary>
    function IsFieldVisible(const AField: TKViewField): Boolean;

    [YamlNode('IsReadOnly', 'False', 'Table data is not editable')]
    property IsReadOnly: Boolean read GetIsReadOnly;

    /// <summary>Effective PreventAdding: the view's Controller/PreventAdding if
    /// specified, else the Model's PreventAdding (fallback). Used by the GUI to
    /// hide the Add button. The REST API enforces the Model-level flag directly.</summary>
    property PreventAdding: Boolean read GetPreventAdding;
    /// <summary>Effective PreventEditing (view Controller if specified, else Model).</summary>
    property PreventEditing: Boolean read GetPreventEditing;
    /// <summary>Effective PreventDeleting (view Controller if specified, else Model).</summary>
    property PreventDeleting: Boolean read GetPreventDeleting;

    /// <summary>
    ///  Optional fixed filter expression to apply when building the select
    ///  SQL statement to display data. Should refer to fields through
    ///  qualified names. Defaults to ''.
    /// </summary>
    [YamlNode('DefaultFilter', 'SQL WHERE clause filter for this table')]
    property DefaultFilter: string read GetDefaultFilter;

    /// <summary>
    ///  Optional fixed ORDER BY expression to apply when building the select
    ///  SQL statement to display data. Should refer to fields through
    ///  qualified names (or ordinal numbers for expression-based fields).
    ///  Defaults to Model.DefaultSorting.
    /// </summary>
    [YamlNode('DefaultSorting', 'Default ORDER BY clause for sorting')]
    property DefaultSorting: string read GetDefaultSorting;

    [YamlNode('Style', 'Extra inline CSS applied to this table''s grid')]
    property Style: string read GetStyle;

    [YamlNode('PluralModelName', 'Plural model name override for this table (labels/titles)')]
    property PluralModelName: string read GetViewPluralModelName;

    [YamlNode('Height', 'Grid height in pixels for this table (0 = auto)')]
    property Height: Integer read GetViewHeight;

    /// <summary>Number of detail (child) tables.</summary>
    property DetailTableCount: Integer read GetDetailTableCount;
    /// <summary>The detail (child) tables, by index.</summary>
    property DetailTables[I: Integer]: TKViewTable read GetDetailTable;
    /// <summary>The detail tables collection. Exposed (in addition to the indexed
    /// accessor) so the YAML 'DetailTables' container is discoverable via RTTI by
    /// the tree validator and the KIDE/MCP metadata tooling.</summary>
    [YamlContainer('DetailTables', TKViewTable, 'Detail (child) tables shown under this table')]
    property DetailTableList: TKViewTables read GetDetailTables;
    /// <summary>Returns the detail table with the given name; raises if absent.</summary>
    function DetailTableByName(const AName: string): TKViewTable;
    /// <summary>Returns the index of the given detail table, or -1.</summary>
    function GetDetailTableIndex(const AViewTable: TKViewTable): Integer;
    /// <summary>Adds a detail table to this view table.</summary>
    procedure AddDetailTable(const AViewTable: TKViewTable);

    /// <summary>The data view that owns this view table.</summary>
    property View: TKDataView read GetView;

    /// <summary>
    ///  Returns an array with any view table's model name
    ///  (except the view's MainTable, which is assumed
    ///  implicit) downto and including the current view table's name.
    /// </summary>
    /// <example>
    ///  <para>Called on the Parties view's MainTable yields an empty array</para>
    ///  <para>Called on its only detail table yields 'Invitation'</para>
    /// </example>
    function GetNamePath: TStringDynArray;

    /// <summary>
    ///   Finds and returns a reference to a layout named after the view's
    ///   PersistentName plus an underscore ('_') and the specified kind. If no
    ///   layout exists under that name, returns nil.
    /// </summary>
    /// <param name="AKind">
    ///   Kind of layout to look for. Common kinds are 'List' and 'Form'.
    /// </param>
    function FindLayout(const AKind: string): TKLayout;

    /// <summary>
    ///  Creates and returns a store with the view's metadata.
    /// </summary>
    function CreateStore: TKViewTableStore;

    /// <summary>
    ///  Creates and returns a node with one child for each default
    ///  value as specified in the view table or model. Any default expression
    ///  is evaluated at this time.
    /// </summary>
    /// <remarks>
    ///  The caller is responsible for freeing the returned node object.
    /// </remarks>
    function GetDefaultValues(const AKeyOnly: Boolean = False): TEFNode;

    /// <summary>The access-control resource URI identifying this view table.</summary>
    function GetResourceURI: string; override;

    /// <summary>Returns True if access is granted to this view table in the given mode.</summary>
    function IsAccessGranted(const AMode: string): Boolean; override;

    [YamlContainer('Rules', TKRule, 'Business rules applied to this table')]
    property Rules: TKRules read GetRules;
    /// <summary>Calls AApplyProc for each rule implementation of this view table (view + model).</summary>
    procedure ApplyRules(const AApplyProc: TProc<TKRuleImpl>);

    /// <summary>
    ///  If the specified field exists in the view table, the method
    ///  returns its AliasedName, otherwise the specified field name is
    ///  returned.
    /// </summary>
    function ApplyFieldAliasedName(const AFieldName: string): string;

    [YamlNode('DatabaseName', 'Database connection name override')]
    property DatabaseName: string read GetDatabaseName;

    /// <summary>Returns the table's FilterBy tuples (reference fields filtered by another field) matching APredicate.</summary>
    function GetFilterByFields(APredicate: TFunc<TKFilterByViewField, Boolean>): TArray<TKFilterByViewField>;

    /// <summary>
    ///  True if the underlying data store is a large one. Set this to True at the
    ///  view table level to override the setting in the model (for example if
    ///  the view table is filtered).
    /// </summary>
    [YamlNode('IsLarge', 'False', 'Optimize for large datasets')]
    property IsLarge: Boolean read GetIsLarge;

    [YamlSubNode('Controller', TKViewTableControllerConfig, 'List/form controller settings')]
    property ControllerConfig: TKViewTableControllerConfig read GetControllerConfig;

    [YamlSubNode('EditController', TKEditControllerConfig, 'Settings of the embedded edit form (Width/Height/LabelWidth/LabelAlign/CloneButton/KeepOpenAfterOperation/ToolViews)')]
    property EditControllerConfig: TKEditControllerConfig read GetEditControllerConfig;
  end;

  /// <summary>
  ///  A data view: a view whose controller works on a main data table (and its
  ///  detail tables). The most common view kind, used by list and form
  ///  controllers.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKDataView = class(TKView)
  private
    function GetMainTable: TKViewTable;
    function GetDatabaseName: string;
    function GetIsLookup: Boolean;
  protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
    function GetDisplayLabel: string; override;
    function GetDefaultImageName: string; override;
    function GetImageName: string; override;
    /// <summary>Builds the containers the accessors would otherwise create on
    /// first read, while the catalogue's load still holds its lock.</summary>
    procedure InternalAfterLoad; override;
  public
    [YamlSubNode('MainTable', TKViewTable, 'Primary data table for this view')]
    property MainTable: TKViewTable read GetMainTable;
    /// <summary>The database connection name for this view (from the model/config).</summary>
    property DatabaseName: string read GetDatabaseName;

    [YamlNode('IsLookup', 'False', 'View is used as a lookup/selection dialog for a referenced model')]
    property IsLookup: Boolean read GetIsLookup;
    /// <summary>Returns True if access is granted to this view in the given mode.</summary>
    function IsAccessGranted(const AMode: string): Boolean; override;
  end;

  /// <summary>Data type for a file-reference field: stores a reference to an external file.</summary>
  TKFileReferenceDataType = class(TEFStringDataType)
  public
    /// <summary>Returns the type name under which this data type is registered.</summary>
    class function GetTypeName: string; override;
  end;

  /// <summary>Data type for a memo field whose content is HTML (rich text).</summary>
  TKHTMLMemoDataType = class(TEFMemoDataType)
  public
    /// <summary>Returns the type name under which this data type is registered.</summary>
    class function GetTypeName: string; override;
  end;

implementation

uses
  System.StrUtils,
  System.Variants,
  System.TypInfo,
  System.SyncObjs,
  System.IOUtils,
  System.Math,
  EF.Localization,
  EF.DB,
  EF.StrUtils,
  EF.VariantUtils,
  EF.Macros,
  EF.JSON,
  Kitto.SQL,
  Kitto.Types,
  Kitto.Config,
  KItto.Auth,
  Kitto.AccessControl,
  Kitto.DatabaseRouter;

{ TKDataView }

function TKDataView.GetChildClass(const AName: string): TEFNodeClass;
begin
  if SameText(AName, 'MainTable') then
    Result := TKViewTable
  else
    Result := inherited GetChildClass(AName);
end;

function TKDataView.GetDatabaseName: string;
var
  LDatabaseRouterNode: TEFNode;
begin
  LDatabaseRouterNode := FindNode('DatabaseRouter');
  if Assigned(LDatabaseRouterNode) then
    Result := TKDatabaseRouterFactory.Instance.GetDatabaseName(
      LDatabaseRouterNode.AsString, Self, LDatabaseRouterNode)
  else
    Result := '';
end;

function TKDataView.GetDisplayLabel: string;
begin
  Result := inherited GetDisplayLabel;
  if Result = '' then
    Result := MainTable.PluralDisplayLabel;
end;

function TKDataView.GetDefaultImageName: string;
begin
  Result := MainTable.ImageName;
end;

function TKDataView.GetImageName: string;
begin
  Result := inherited GetImageName;
  if Result = DEFAULT_IMAGE_NAME then
    Result := DefaultImageName;
end;

function TKDataView.GetMainTable: TKViewTable;
begin
  Result := GetNode('MainTable', True) as TKViewTable;
end;

function TKDataView.GetIsLookup: Boolean;
begin
  Result := GetBoolean('IsLookup');
end;

procedure TKDataView.InternalAfterLoad;

  // See the same helper in TKModel.InternalAfterLoad: evaluating the accessor
  // is what matters, not what it returns.
  procedure Touch(const AContainer: TObject);
  begin
    Assert(Assigned(AContainer), 'Assigned(AContainer)');
  end;

  procedure PrepareViewTable(const AViewTable: TKViewTable);
  var
    LFields: TKViewFields;
    I: Integer;
  begin
    Touch(AViewTable.Rules);

    // Build the fields now, under the catalogue lock, through the Fields
    // accessor. For a model-backed table that declares none, the accessor runs
    // CreateDefaultFields -- exactly the build that otherwise happened lazily on
    // the first request, and raced two request threads mutating this shared
    // tree: the outcome was duplicate columns left in the tree for every later
    // request, or an access violation during the list realloc. Doing it here,
    // while the catalogue lock is held, leaves the request threads only reading.
    //
    // Calling the accessor here used to be unsafe -- with no model it went on to
    // CreateDefaultFields, which read Model.FieldCount, asked the catalogue for
    // the object named '' and raised 'Object  not found', taking the whole
    // catalogue down (KIDE could not open a project). GetFields now guards that
    // build with HasModelName, so a modelless table (a dashboard's MainTable)
    // gets its empty container and nothing more.
    LFields := AViewTable.FieldList;
    for I := 0 to LFields.FieldCount - 1 do
      Touch(LFields[I].Rules);

    for I := 0 to AViewTable.DetailTableCount - 1 do
      PrepareViewTable(AViewTable.DetailTables[I]);
  end;

begin
  inherited;

  // As in TKModel.InternalAfterLoad: this view is cached and shared from here
  // on, so every container is built now, inside the catalogue's lock, and the
  // request threads only read.
  PrepareViewTable(MainTable);
end;

function TKDataView.IsAccessGranted(const AMode: string): Boolean;
var
  LMainTable: TEFNode;
begin
  // The view's own resource URI gate (PersistentName/ResourceName based).
  Result := inherited IsAccessGranted(AMode);
  // Also honour the main table's model: a deny on metadata://Model/<Name>
  // must hide the view (and its menu entry) even when the view has no
  // resource URI of its own - e.g. AutoList views built on the fly from a
  // Model. Mirrors TKViewTable.IsAccessGranted, which already ANDs the model.
  // FindNode (not the MainTable property) avoids creating an empty node here.
  if Result then
  begin
    LMainTable := FindNode('MainTable');
    if LMainTable is TKViewTable then
      Result := TKViewTable(LMainTable).IsAccessGranted(AMode);
  end;
end;

{ TKViewTable }

procedure TKViewTable.AddDetailTable(const AViewTable: TKViewTable);
begin
  Assert(Assigned(AViewTable), 'Assigned(AViewTable)');

  GetDetailTables.AddChild(AViewTable);
end;

function TKViewTable.ApplyFieldAliasedName(const AFieldName: string): string;
var
  LViewField: TKViewField;
begin
  LViewField := FindField(AFieldName);
  if Assigned(LViewField) then
    Result := LViewField.AliasedName
  else
    Result := AFieldName;
end;

procedure TKViewTable.ApplyRules(const AApplyProc: TProc<TKRuleImpl>);
var
  I: Integer;
  LRuleImpl: TKRuleImpl;
  LRule: TKRule;
begin
  Assert(Assigned(AApplyProc), 'Assigned(AApplyProc)');

  // Apply rules at the View level.
  for I := 0 to Rules.RuleCount - 1 do
  begin
    LRule := Rules[I];
{$IFDEF KITTOX_PREVIEW_MODE}
    // Preview (KIDEX): a rule implemented by application Delphi code (registered
    // in the app's own Rules.pas, which KIDEX does not link) cannot be created
    // here; skip it so the view still renders -- the custom rule simply does not
    // run in the design-time preview. Compiled out in an application build.
    if not TKRuleImplFactory.Instance.HasClass(LRule.Name) then
      Continue;
{$ENDIF}
    LRuleImpl := TKRuleImplFactory.Instance.CreateObject(LRule.Name);
    try
      LRuleImpl.Rule := LRule;
      AApplyProc(LRuleImpl);
    finally
      FreeAndNil(LRuleImpl);
    end;
  end;
  // Always apply rules at the model level as well. View-level record rules
  // augment model-level rules but cannot overwrite or disable them.
  // Same rule as everywhere else in this class: no model, no model rules.
  if not HasModelName then
    Exit;
  for I := 0 to Model.Rules.RuleCount - 1 do
  begin
    LRule := Model.Rules[I];
    if not Rules.HasRule(LRule) then
    begin
{$IFDEF KITTOX_PREVIEW_MODE}
      // Preview (KIDEX): skip an app-provided rule class not linked into KIDEX
      // (see the view-level loop above). Compiled out in an application build.
      if not TKRuleImplFactory.Instance.HasClass(LRule.Name) then
        Continue;
{$ENDIF}
      LRuleImpl := TKRuleImplFactory.Instance.CreateObject(LRule.Name);
      try
        LRuleImpl.Rule := LRule;
        AApplyProc(LRuleImpl);
      finally
        FreeAndNil(LRuleImpl);
      end;
    end;
  end;
end;

function TKViewTable.CreateStore: TKViewTableStore;
begin
  Result := TKViewTableStore.Create(Self);
end;

function TKViewTable.DetailTableByName(const AName: string): TKViewTable;
begin
  Result := GetDetailTables.ChildByName(AName) as TKViewTable;
end;

function TKViewTable.FieldByAliasedName(const AAliasedName: string): TKViewField;
begin
  Result := FindFieldByAliasedName(AAliasedName);
  if not Assigned(Result) then
    raise EKError.CreateFmt('ViewField %s not found.', [AAliasedName]);
end;

function TKViewTable.FieldByName(const AName: string): TKViewField;
begin
  Result := GetFields.ChildByName(AName) as TKViewField;
end;

function TKViewTable.FieldsByModelFields(const AModelFields: TKModelFieldArray): TKViewFieldArray;
var
  I: Integer;
begin
  SetLength(Result, Length(AModelFields));
  for I := Low(Result) to High(Result) do
    Result[I] := FieldByModelField(AModelFields[I]);
end;

function TKViewTable.FieldByDBColumnName(const ADBColumnName: string): TKViewField;
begin
  Result := FindFieldByDBColumnName(ADBColumnName);
  if not Assigned(Result) then
    raise EKError.CreateFmt('Couldn''t find a field with DB column name %s.',
      [ADBColumnName]);
end;

function TKViewTable.FindFieldByDBColumnName(const ADBColumnName: string): TKViewField;
begin
  Result := GetFields.FindChildByPredicate(
    function(const ANode: TEFNode): Boolean
    begin
      // Skip expression-only fields: they have no model field (and so no DB
      // column) to match, and dereferencing ModelField would raise.
      Result := TKViewField(ANode).HasModelField
        and SameText(TKViewField(ANode).ModelField.DBColumnName, ADBColumnName);
    end) as TKViewField;
end;

function TKViewTable.FindFieldByModelField(const AModelField: TKModelField): TKViewField;
begin
  Result := GetFields.FindChildByPredicate(
    function(const ANode: TEFNode): Boolean
    begin
      // Skip expression-only fields (no model field to compare, and
      // dereferencing ModelField would raise).
      Result := TKViewField(ANode).HasModelField
        and (TKViewField(ANode).ModelField = AModelField);
    end) as TKViewField;
end;

function TKViewTable.FieldByModelField(const AModelField: TKModelField): TKViewField;
begin
  Result := FindFieldByModelField(AModelField);
  if not Assigned(Result) then
    raise EKError.CreateFmt('ViewField not found for model field %s.', [AModelField.Name]);
end;

function TKViewTable.FindField(const AName: string): TKViewField;
begin
  Result := GetFields.FindChild(AName) as TKViewField;
end;

function TKViewTable.FindFieldByAliasedName(const AAliasedName: string): TKViewField;
begin
  Result := GetFields.FindChildByPredicate(
    function(const ANode: TEFNode): Boolean
    begin
      Result := SameText(TKViewField(ANode).AliasedName, AAliasedName);
    end) as TKViewField;
end;

function TKViewTable.GetChildClass(const AName: string): TEFNodeClass;
begin
  if SameText(AName, 'Fields') then
    Result := TKViewFields
  else if SameText(AName, 'DetailTables') then
    Result := TKViewTables
  else if SameText(AName, 'Rules') then
    Result := TKRules
  else
    Result := inherited GetChildClass(AName);
end;

function TKViewTable.GetModelName: string;
var
  LModelNameNode: TEFNode;
begin
  LModelNameNode := FindNode('Model');
  if Assigned(LModelNameNode) and (LModelNameNode.AsString <> '') then
    Result := LModelNameNode.AsExpandedString
  else if Assigned(MasterTable) and (ModelDetailReferenceName <> '') then
    Result := MasterTable.Model.DetailReferenceByName(ModelDetailReferenceName).DetailModelName
  else
    Result := '';
end;

function TKViewTable.HasModelName: Boolean;
begin
  Result := ModelName <> '';
end;

function TKViewTable.FindModel: TKModel;
begin
  if ModelName = '' then
    Result := nil
  else
    Result := View.Catalog.Models.FindModel(ModelName);
end;

function TKViewTable.GetModel: TKModel;
begin
  // Say WHICH view table has no Model, rather than asking the catalogue for
  // the object named '': that raised 'Object  not found.', with an empty name
  // and nothing to act on. The Assert that used to follow ModelByName was
  // unreachable in either case -- ModelByName raises when the name does not
  // resolve, it never returns nil.
  if ModelName = '' then
    raise EKError.CreateFmt(_('View table %s of view %s declares no Model.'),
      [Name, View.PersistentName]);
  Result := View.Catalog.Models.ModelByName(ModelName);
end;

function TKViewTable.GetModelDetailReference: TKModelDetailReference;
begin
  Result := nil;
  // A table with no master is not a detail, so it has no detail reference and
  // nil is the answer -- not an error. The raise below used to be reached in
  // that case too, and formatting its own message dereferenced the master that
  // is not there: an access violation instead of a diagnosis, on a MainTable,
  // which is the commonest shape there is.
  if not Assigned(MasterTable) then
    Exit;
  Result := MasterTable.Model.FindDetailReferenceByModel(Model);
  if not Assigned(Result) and (ModelDetailReferenceName <> '') then
    Result := MasterTable.Model.FindDetailReference(ModelDetailReferenceName);
  if not Assigned(Result) then
    raise EKError.CreateFmt('Couldn''t find detail reference from %s to %s.',
      [MasterTable.ModelName, ModelName]);
end;

function TKViewTable.GetModelDetailReferenceName: string;
begin
  Result := GetString('DetailReference');
end;

function TKViewTable.GetDefaultSorting: string;
begin
  Result := GetString('DefaultSorting');
  if (Result = '') and HasModelName then
    Result := Model.DefaultSorting;
end;

function TKViewTable.GetStyle: string;
begin
  Result := GetString('Style');
end;

function TKViewTable.GetViewPluralModelName: string;
begin
  Result := GetString('PluralModelName');
end;

function TKViewTable.GetViewHeight: Integer;
begin
  Result := GetInteger('Height', 0);
end;

function TKViewTable.GetDefaultValues(const AKeyOnly: Boolean): TEFNode;
var
  I: Integer;
begin
  Result := TEFNode.Create;
  try
    for I := 0 to FieldCount - 1 do
      if not AKeyOnly or Fields[I].IsKey then
        Fields[I].AppendDefaultValues(Result);
  except
    FreeAndNil(Result);
    raise;
  end;
end;

function TKViewTable.GetDatabaseName: string;
var
  LDatabaseRouterNode: TEFNode;
begin
  LDatabaseRouterNode := FindNode('DatabaseRouter');
  if Assigned(LDatabaseRouterNode) then
    Result := TKDatabaseRouterFactory.Instance.GetDatabaseName(
      LDatabaseRouterNode.AsString, Self, LDatabaseRouterNode)
  else
  begin
    Result := View.DatabaseName;
    if (Result = '') and HasModelName then
      Result := Model.DatabaseName;
  end;
end;

function TKViewTable.GetDefaultFilter: string;
begin
  Result := GetString('DefaultFilter');
  if Result <> '' then
    Result := '(' + Result + ')';
end;

function TKViewTable.GetDefaultDisplayLabel: string;
begin
  if IsDetail then
    Result := ModelDetailReference.DisplayLabel
  else if HasModelName then
    Result := Model.DisplayLabel
  else
    // No model, no label to derive: the view's own DisplayLabel is all there
    // is, and for a dashboard or a chart that is exactly right.
    Result := '';
end;

function TKViewTable.GetDetailTableCount: Integer;
begin
  Result := GetDetailTables.GetChildCount<TKViewTable>;
end;

function TKViewTable.GetDetailTableIndex(const AViewTable: TKViewTable): Integer;
begin
  Result := GetDetailTables.GetChildIndex(AViewTable);
end;

function TKViewTable.GetDetailTables: TKViewTables;
begin
  Result := GetNode('DetailTables', True) as TKViewTables;
end;

function TKViewTable.GetDisplayLabel: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('DisplayLabel2')
  else
    Result := GetString('DisplayLabel');
  if Result = '' then
    Result := GetDefaultDisplayLabel;
end;

function TKViewTable.GetField(I: Integer): TKViewField;
begin
  Result := GetFields[I];
end;

function TKViewTable.GetFieldArray(AFilter: TFunc<TKViewField, Boolean>): TArray<TKViewField>;
var
  LItems: Integer;
  I: Integer;
begin
  Setlength(Result, FieldCount);
  LItems := 0;
  for I := 0 to FieldCount - 1 do
  begin
    if AFilter(Fields[I]) then
    begin
      Result[LItems] := Fields[I];
      Inc(LItems);
    end;
  end;
  SetLength(Result, LItems);
end;

function TKViewTable.GetFieldCount: Integer;
begin
  Result := GetFields.FieldCount;
end;

function TKViewTable.GetFieldNames: TStringDynArray;
var
  I: Integer;
begin
  SetLength(Result, FieldCount);
  for I := 0 to High(Result) do
    Result[I] := Fields[I].FieldName;

  if Length(Result) = 0 then
  begin
    SetLength(Result, Model.FieldCount);
    for I := 0 to High(Result) do
      Result[I] := Model.Fields[I].FieldName;
  end;
end;

function TKViewTable.GetFields: TKViewFields;
var
  LFields: TKViewFields;

  procedure CreateDefaultFields;
  var
    I, J, K: Integer;
    LModelField: TKModelField;
    LAutoAddFields: TEFNode;
    LViewField: TKViewField;
    LAutoAddField: TEFNode;
  begin
    for I := 0 to Model.FieldCount - 1 do
    begin
      LModelField := Model.Fields[I];
      LViewField := TKViewField.Create(LModelField.FieldName);
      LFields.AddChild(LViewField);
      LAutoAddFields := LModelField.FindNode('AutoAddFields');
      if Assigned(LAutoAddFields) then
      begin
        for J := 0 to LAutoAddFields.ChildCount - 1 do
        begin
          LAutoAddField := LAutoAddFields.Children[J];
          LViewField := TKViewField.Create(LModelField.FieldName + AUTO_ADD_FIELD_SEPARATOR + 
            LAutoAddField.Name, LAutoAddField.AsExpandedString);
          for K := 0 to LAutoAddField.ChildCount - 1 do
            LViewField.AddChild(TEFNode.Clone(LAutoAddField.Children[K]));
          LFields.AddChild(LViewField);
        end;
      end;
    end;
  end;

begin
  LFields := GetNode('Fields', True) as TKViewFields;
  // No Model, no default fields: there is nothing to derive them from. A view
  // table without one is not a broken table -- a dashboard, a chart, a tool
  // panel declares Type: Data for the controller's sake and never a MainTable
  // -- and it legitimately has no fields at all.
  //
  // Without this guard CreateDefaultFields went on to read Model.FieldCount,
  // which asked the catalogue for the object named '' and raised
  // 'Object  not found.' -- a message that names nothing and points nowhere,
  // from a place nothing in the stack relates to the view being rendered. It
  // is what a TasKitto login landed on: the Dashboard is among the SubViews
  // the home TabPanel opens, and rendering it asks its MainTable for fields.
  // TKDataView.InternalAfterLoad already avoids this path for the same reason,
  // and said so in a comment; the render path had no such guard.
  if (LFields.FieldCount = 0) and HasModelName then
    CreateDefaultFields;
  Result := LFields;
end;

function TKViewTable.GetFilterByFields(APredicate: TFunc<TKFilterByViewField, Boolean>): TArray<TKFilterByViewField>;
var
  I: Integer;
  LFilterByFields: TArray<TKFilterByViewField>;
  LFieldIdx: Integer;
begin
  if not Assigned(APredicate) then
    APredicate :=
      function (AFilterByViewField: TKFilterByViewField): Boolean
      begin
        Result := True;
      end;

  SetLength(Result, 0);
  for I := 0 to FieldCount - 1 do
  begin
    LFilterByFields := Fields[I].GetFilterByFields;
    for LFieldIdx := Low(LFilterByFields) to High(LFilterByFields) do
    begin
      if APredicate(LFilterByFields[LFieldIdx]) then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := LFilterByFields[LFieldIdx];
      end;
    end;
  end;
end;

function TKViewTable.GetImageName: string;
begin
  Result := GetString('ImageName');
  // Only fall back to the model when there IS one. See FindModel: a view table
  // with no Model is legitimate, and a property getter must not raise on it.
  if (Result = '') and HasModelName then
    Result := Model.ImageName;
end;

function TKViewTable.GetIsDetail: Boolean;
begin
  // MainTable has the view as parent, other tables have the collection.
  Result := Parent is TKViewTables;
end;

function TKViewTable.GetIsLarge: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('IsLarge');
  if Assigned(LNode) then
    Result := LNode.AsBoolean
  else if not HasModelName then
    Result := False // no table, so no amount of rows to be careful about
  else
    Result := Model.IsLarge;
end;

function TKViewTable.GetControllerConfig: TKViewTableControllerConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKViewTable.GetEditControllerConfig: TKEditControllerConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKViewTable.GetIsReadOnly: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('IsReadOnly');
  if Assigned(LNode) then
    Result := LNode.AsBoolean
  // No model: see FindModel. There is no table to write to, so read-only is
  // the only truthful answer.
  else if not HasModelName then
    Result := True
  else
    Result := Model.IsReadOnly;
end;

function TKViewTable.GetPreventAdding: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('Controller/PreventAdding');
  if Assigned(LNode) then
    Result := LNode.AsBoolean
  else if not HasModelName then
    Result := True // no table, nothing to add to
  else
    Result := Model.PreventAdding;
end;

function TKViewTable.GetPreventEditing: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('Controller/PreventEditing');
  if Assigned(LNode) then
    Result := LNode.AsBoolean
  else if not HasModelName then
    Result := True // no table, nothing to edit
  else
    Result := Model.PreventEditing;
end;

function TKViewTable.GetPreventDeleting: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('Controller/PreventDeleting');
  if Assigned(LNode) then
    Result := LNode.AsBoolean
  else if not HasModelName then
    Result := True // no table, nothing to delete
  else
    Result := Model.PreventDeleting;
end;

function TKViewTable.GetMasterTable: TKViewTable;
begin
  if Parent is TKViewTables then
    Result := TKViewTables(Parent).Table
  else
    Result := nil;
end;

function TKViewTable.GetPluralDisplayLabel: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('PluralDisplayLabel2')
  else
    Result := GetString('PluralDisplayLabel');
  if (Result = '') and HasModelName then
    Result := Model.PluralDisplayLabel;
end;

function TKViewTable.GetResourceURI: string;
begin
  Result := View.GetResourceURI;
  if Result <> '' then
    Result := Result + '/' + Join(GetNamePath, '/');
end;

function TKViewTable.GetRules: TKRules;
begin
  Result := GetNode('Rules', True) as TKRules;
end;

function TKViewTable.GetKeyFieldAliasedNames: TStringDynArray;
var
  I: Integer;
  LViewField: TKViewField;
begin
  Result := Model.GetKeyFieldNames;
  // Apply aliasing.
  for I := Low(Result) to High(Result) do
  begin
    LViewField := FindField(Result[I]);
    if Assigned(LViewField) then
      Result[I] := LViewField.AliasedName;
  end;
end;

function TKViewTable.FindLayout(const AKind: string): TKLayout;
var
  LExplicitName, LDefaultLayoutName: string;
begin
  // Check for explicit layout name in Controller/{AKind}/Layout
  LExplicitName := GetString('Controller/' + AKind + '/Layout');
  if LExplicitName <> '' then
  begin
    Result := View.Catalog.Layouts.FindLayout(LExplicitName);
    if Assigned(Result) then
      Exit;
  end;
  // Fall back to convention: ViewName_Kind
  LDefaultLayoutName := SmartConcat(View.PersistentName, '.', Join(GetNamePath, '.')) + '_' + AKind;
  Result := View.Catalog.Layouts.FindLayout(LDefaultLayoutName);
end;

function TKViewTable.FindNode(const APath: string;
  const ACreateMissingNodes: Boolean): TEFNode;
begin
  Result := inherited FindNode(APath, ACreateMissingNodes);
  if not Assigned(Result) and not FFindingNode then
  begin
    // Prevent Stack-overflow when testing HasModelName
    FFindingNode := True;
    try
      if HasModelName then
        Result := Model.FindNode(APath, False);
    finally
      FFindingNode := False;
    end;
  end;
end;

function TKViewTable.FindParentField(const AFieldName: string): TKViewField;
var
  LModelField: TKModelField;
  LFieldName: string;
begin
  LFieldName := AFieldName;
  if LFieldName.Contains(TKConfig.Instance.MultiFieldSeparator) then
    LFieldName := LFieldName.Split([TKConfig.Instance.MultiFieldSeparator], TStringSplitOptions.None)[0];
  // We can safely assume that all fields in a composite field share the same parent field.
  LModelField := Model.FindField(LFieldName);
  if Assigned(LModelField) and Assigned(LModelField.ParentField) then
    Result := FindFieldByModelField(LModelField.ParentField)
  else
    Result := nil;
end;

function TKViewTable.GetDetailTable(I: Integer): TKViewTable;
begin
  Result := GetDetailTables.GetChild<TKViewTable>(I);
end;

function TKViewTable.GetNamePath: TStringDynArray;
begin
  if MasterTable <> nil then
  begin
    Result := MasterTable.GetNamePath;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := MasterTable.GetModelDetailReferenceName;
    if Result[High(Result)] = '' then
      Result[High(Result)] := ModelName;
  end
  else
    SetLength(Result, 0);
end;

function TKViewTable.GetView: TKDataView;
begin
  if Parent is TKDataView then
    Result := TKDataView(Parent)
  else if MasterTable <> nil then
    Result := MasterTable.View
  else if Parent is TKViewTables then
    Result := TKViewTables(Parent).View as TKDataView
  else
    raise EKError.Create('Structure error. View not found for TKViewTable.');
end;

function TKViewTable.IsAccessGranted(const AMode: string): Boolean;
begin
  // A dataview and its main table currently share the same resource URI, so
  // testing the view's too would be useless:
  //   and TKConfig.Instance.IsAccessGranted(View.GetACURI, AMode)
  Result := TKAccessController.Current.IsAccessGranted(
    TKAuthenticator.Current.UserName, GetACURI, AMode);
  // The model's URI is a SECOND gate, and there is one to check only when the
  // table declares a model. A dashboard's does not (see FindModel), and asking
  // for it raised in the middle of rendering the home page: this is the call
  // that put 'declares no Model' on screen at every login, because the home
  // checks access on every view it opens.
  if Result and HasModelName then
    Result := TKAccessController.Current.IsAccessGranted(
      TKAuthenticator.Current.UserName, Model.GetACURI, AMode);
end;

function TKViewTable.IsFieldVisible(const AField: TKViewField): Boolean;
begin
  Assert(Assigned(AField), 'Assigned(AField)');

  Result := AField.IsVisible
    or MatchText(AField.AliasedName, GetStringArray('Controller/VisibleFields'));
end;

{ TKViewTables }

function TKViewTables.GetChildClass(const AName: string): TEFNodeClass;
begin
  if SameText(AName, 'Table') then
    Result := TKViewTable
  else
    Result := inherited GetChildClass(AName);
end;

function TKViewTables.GetTable: TKViewTable;
begin
  Result := Parent as TKViewTable;
end;

function TKViewTables.GetView: TKView;
begin
  if Parent is TKViewTable then
    Result := TKViewTable(Parent).View
  else if Parent is TKView then
    Result := TKView(Parent)
  else
    raise EKError.Create('Structure error. View not found for TKViewTables.');
end;

{ TKViewFields }

function TKViewFields.GetChildClass(const AName: string): TEFNodeClass;
begin
  Result := TKViewField;
end;

function TKViewFields.GetField(I: Integer): TKViewField;
begin
  Result := Children[I] as TKViewField;
end;

function TKViewFields.GetFieldCount: Integer;
begin
  Result := ChildCount;
end;

function TKViewFields.GetTable: TKViewTable;
begin
  Result := Parent as TKViewTable;
end;

{ TKViewField }

procedure TKViewField.AppendDefaultValues(const ANode: TEFNode);
var
  LValue: Variant;
  LDefaultValueNode: TEFNode;
  I: Integer;
  LConcatenation: string;
  LStrValue: string;
begin
  Assert(Assigned(ANode), 'Assigned(ANode)');

  // Get regular default value.
  LValue := DefaultValue;
  if not VarIsNull(LValue) and (EFVarToStr(LValue) <> '') then
    ANode.AddChild(FieldName, LValue)
  else if IsReference then
  begin
    // Get model-level multi-column default values.
    for I := 0 to ModelField.FieldCount - 1 do
    begin
      LValue := ModelField.Fields[I].DefaultValue;
      if not VarIsNull(LValue) and (EFVarToStr(LValue) <> '') then
        ANode.AddChild(ModelField.Fields[I].FieldName, LValue);
    end;
    // Get view-level multi-column default values (override).
    LDefaultValueNode := FindNode('DefaultValue');
    if Assigned(LDefaultValueNode) then
    begin
      for I := 0 to LDefaultValueNode.ChildCount - 1 do
        ANode.SetValue(LDefaultValueNode.Children[I].Name, LDefaultValueNode.Children[I].Value);
    end;
    // Store values in concatenated form as well in case of multi-valued references.
    if ModelField.FieldCount > 1 then
    begin
      LConcatenation := '';
      for I := 0 to ModelField.FieldCount - 1 do
      begin
        LStrValue := ANode.GetString(ModelField.Fields[I].FieldName);
        // Note: we need to keep the concatenated value and wipe the single values
        // in order for their change handler to be triggered later when the compound value
        // is expanded back to the single fields.
        ANode.DeleteNode(ModelField.Fields[I].FieldName);
        if I = 0 then
          LConcatenation := LStrValue
        else
          LConcatenation := LConcatenation + TKConfig.Instance.MultiFieldSeparator + LStrValue;
      end;
      ANode.SetString(Join(ModelField.GetFieldNames, TKConfig.Instance.MultiFieldSeparator), LConcatenation);
    end;
  end;
end;

procedure TKViewField.EnumRules(const AEnumFunc: TFunc<TKRuleImpl, Boolean>);
var
  I: Integer;
  LRuleImpl: TKRuleImpl;
  LRule: TKRule;
  LInterrupted: Boolean;
begin
  Assert(Assigned(AEnumFunc), 'Assigned(AEnumFunc)');

  LInterrupted := False;
  // Apply rules at the View level.
  for I := 0 to Rules.RuleCount - 1 do
  begin
    LRule := Rules[I];
    // Skip rules whose implementation class is not registered (e.g.
    // client-side-only ExtJS rules like SubType when running in KittoX).
    if not TKRuleImplFactory.Instance.HasClass(LRule.Name) then
      Continue;
    LRuleImpl := TKRuleImplFactory.Instance.CreateObject(LRule.Name);
    try
      LRuleImpl.Rule := LRule;
      LInterrupted := AEnumFunc(LRuleImpl);
      if LInterrupted then
        Break;
    finally
      FreeAndNil(LRuleImpl);
    end;
  end;

  if not LInterrupted then
  begin
    // Apply rules at the model level that are not overwritten in the view.
    // A field-level rule of given type (such as Maxlength) generally cannot
    // be applied twice, and we don't have a way yet to avoid setting config
    // options twice on a rule-by-rule basis.
    for I := 0 to ModelField.Rules.RuleCount - 1 do
    begin
      LRule := ModelField.Rules[I];
      if not Rules.HasRule(LRule) then
      begin
        if not TKRuleImplFactory.Instance.HasClass(LRule.Name) then
          Continue;
        LRuleImpl := TKRuleImplFactory.Instance.CreateObject(LRule.Name);
        try
          LRuleImpl.Rule := LRule;
          LInterrupted := AEnumFunc(LRuleImpl);
          if LInterrupted then
            Break;
        finally
          FreeAndNil(LRuleImpl);
        end;
      end;
    end;
  end;
end;

function TKViewField.BuildSortClause(const AIsDescending: Boolean): string;
var
  LResult: string;
begin
  TKSQLBuilder.CreateAndExecute(
    procedure (ASQLBuilder: TKSQLBuilder)
    begin
      LResult := ASQLBuilder.GetSortClause(Self, AIsDescending);
    end);
  Result := LResult;
end;

function TKViewField.CanEditField(const AInsertOperation: Boolean): Boolean;
var
  LReadOnly: Boolean;

  function CanEdit: Boolean;
  begin
    if AInsertOperation then
      Result := CanInsert
    else
      Result := CanUpdate
  end;

begin
  LReadOnly :=
    IsReadOnly
    or not IsAccessGranted(ACM_MODIFY)
    or not CanEdit
    or Table.IsReadOnly
    or (Model <> Table.Model);
  Result := not LReadOnly;
end;

function TKViewField.CreateDerivedFieldsStore(const AKeyValues: string): TKStore;
var
  LDerivedFields: TArray<TKViewField>;
  LStore: TKStore;
begin
  Assert(IsReference, 'IsReference');

  LStore := TKStore.Create;
  try
    // Set header.
    LDerivedFields := GetDerivedFields;
    Assert(Length(LDerivedFields) > 0, 'Length(LDerivedFields) > 0');

    LStore.DoWithChangeNotificationsDisabled(
      procedure
      var
        LDerivedField: TKViewField;
        LDBConnection: TEFDBConnection;
        LDBQuery: TEFDBQuery;
        LHasDerivedFields: Boolean;
      begin
        for LDerivedField in LDerivedFields do
          LStore.Header.AddField(LDerivedField.AliasedName).DataType := LDerivedField.DataType;
        // Get data.
        LDBConnection := TKConfig.DatabaseFor(Table.DatabaseName);
        LDBQuery := LDBConnection.CreateDBQuery;
        try
          TKSQLBuilder.CreateAndExecute(
            procedure (ASQLBuilder: TKSQLBuilder)
            begin
              LHasDerivedFields := ASQLBuilder.BuildDerivedSelectQuery(Self, LDBQuery, AKeyValues);
            end);
          if LHasDerivedFields then
            LStore.Load(LDBQuery, False, True);
        finally
          FreeAndNil(LDBQuery);
        end;
      end);
    Result := LStore;
  except
    // Free the local, not Result: Result is a class-typed function result and
    // is NOT zero-initialised, so on a raise before the assignment above (the
    // derived-fields query failing, say) FreeAndNil(Result) would free a garbage
    // pointer and leak LStore. Mirrors CreateReferencedModelStore.
    FreeAndNil(LStore);
    raise;
  end;
end;

function TKViewField.CreateReferenceStore: TKStore;
var
  I: Integer;
  LField: TKModelField;
  LCaptionField: TKModelField;
  LKeyFieldNames: string;
begin
  Assert(IsReference, 'IsReference');

  Result := TKStore.Create;
  try
    for I := 0 to ModelField.ReferencedModel.KeyFieldCount - 1 do
    begin
      LField := ModelField.ReferencedModel.KeyFields[I];
      Result.Key.AddChild(LField.FieldName).DataType := LField.DataType;
      Result.Header.AddField(LField.FieldName).DataType := LField.DataType;
    end;
    LCaptionField := ModelField.ReferencedModel.CaptionField;
    if Result.Header.FindChild(LCaptionField.FieldName) = nil then
      Result.Header.AddField(LCaptionField.FieldName).DataType := LCaptionField.DataType;

    if ModelField.ReferencedModel.KeyFieldCount > 1 then
    begin
      // Let's assume a concatenation is a string.
      LKeyFieldNames := Join(ModelField.ReferencedModel.GetKeyFieldNames, TKConfig.Instance.MultiFieldSeparator);
      Result.Header.AddField(LKeyFieldNames).DataType := TEFDataTypeFactory.Instance.GetDataType('String');
    end;
  except
    FreeAndNil(Result);
    raise;
  end;
end;


function TKViewField.CreateReferencedModelStore(const AKeyValues: Variant): TKStore;
var
  LDBConnection: TEFDBConnection;
  LDBQuery: TEFDBQuery;
  LStore: TKStore;
begin
  Assert(IsReference, 'IsReference');

  LStore := TKStore.Create;
  try
    // Metadata.
    ModelField.ReferencedModel.EnumPhysicalFields(
      procedure (AField: TKModelField)
      begin
        if AField.IsKey then
          LStore.Key.AddChild(AField.FieldName).DataType := AField.DataType;
        LStore.Header.AddField(AField.FieldName).DataType := AField.DataType;
      end);

    // Get data.
    LDBConnection := TKConfig.DatabaseFor(Table.DatabaseName);
    LDBQuery := LDBConnection.CreateDBQuery;
    try
      with TKSQLBuilder.Create do
        try
          BuildSingletonSelectQuery(ModelField.ReferencedModel, LDBQuery, AKeyValues);
        finally
          Free;
        end;
      LStore.Load(LDBQuery, False, True);
    finally
      FreeAndNil(LDBQuery);
    end;
    Result := LStore;
  except
    FreeAndNil(LStore);
    raise;
  end;
end;

function TKViewField.DerivedFieldsExist: Boolean;
var
  LViewTable: TKViewTable;
  LModelField: TKModelField;
  I: Integer;
begin
  Result := False;
  LViewTable := Table;
  LModelField := ModelField;
  for I := 0 to LViewTable.FieldCount - 1 do
  begin
    if LViewTable.Fields[I].ReferenceField = LModelField then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TKViewField.FindModelField: TKModelField;
begin
  Result := Model.FindField(FieldName);
end;

function TKViewField.HasModelField: boolean;
var
  LCatalog: TKModels;
  LModelName: string;
  LModel: TKModel;
begin
  Result := False;
  if not Assigned(Table) or not Assigned(Table.View) or
     not Assigned(Table.View.Catalog) then
    Exit;
  LCatalog := Table.View.Catalog.Models;
  LModelName := Table.ModelName;
  if LModelName = '' then
    Exit;
  LModel := LCatalog.FindModel(LModelName);
  if not Assigned(LModel) then
    Exit;
  Result := Assigned(LModel.FindField(FieldName));
end;

function TKViewField.HasServerSideRules: Boolean;
var
  LServerSideRuleFound: Boolean;
begin
  Result := (Rules.RuleCount > 0) or (ModelField.Rules.RuleCount > 0);
  if Result then
  begin
    LServerSideRuleFound := False;
    EnumRules(
      function (ARuleImpl: TKRuleImpl): Boolean
      begin
        LServerSideRuleFound := not ARuleImpl.IsClientSide;
        Result := not LServerSideRuleFound;
      end);
    Result := LServerSideRuleFound;
  end;
end;

function TKViewField.FindNode(const APath: string;
  const ACreateMissingNodes: Boolean): TEFNode;
begin
  Result := inherited FindNode(APath, ACreateMissingNodes);
  if not Assigned(Result) and HasModelField then
    // ACreateMissingNodes is False here.
    Result := ModelField.FindNode(APath, False);
end;

function TKViewField.GetActualDataType: TEFDataType;
begin
  Result := DataType;
  if Result is TKReferenceDataType then
    Result := ModelField.ReferencedModel.CaptionField.DataType;
end;

function TKViewField.GetAlias: string;
begin
  Result := AsString;
end;

function TKViewField.GetAliasedDBName: string;
begin
  Result := Alias;
  if Result = '' then
    Result := ReplaceStr(DBName, '.', '_');
  if Result = '' then
    raise EKError.CreateFmt('ViewField %s must have an alias.', [Name]);
end;

function TKViewField.GetAliasedName: string;
begin
  Result := Alias;
  if Result = '' then
    Result := ReplaceStr(Name, '.', '_');
  if Result = '' then
    raise EKError.CreateFmt('ViewField %s must have an alias.', [Name]);
end;

function TKViewField.GetAllowedValues: TEFPairs;
begin
  Result := GetChildrenAsPairs('AllowedValues');
  if Result = nil then
    Result := ModelField.AllowedValues;
end;

function TKViewField.GetBlankValue: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('BlankValue');
  if LNode = nil then
    Result := ModelField.BlankValue
  else
    Result := LNode.AsBoolean;
end;

function TKViewField.GetAutoCompleteMinChars: Integer;
var
  LNode: TEFNode;
begin
  LNode := FindNode('AutoCompleteMinChars');
  if LNode = nil then
    Result := ModelField.AutoCompleteMinChars
  else
    Result := LNode.AsInteger;
end;

function TKViewField.GetCanInsert: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('CanInsert');
  if LNode = nil then
  begin
    if pos('.',Name) > 0 then
      Result := False
    else
      Result := ModelField.CanInsert;
  end
  else
    Result := LNode.AsBoolean and ModelField.CanActuallyModify;
end;

function TKViewField.GetCanUpdate: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('CanUpdate');
  if LNode = nil then
  begin
    if pos('.',Name) > 0 then
      Result := False
    else
      Result := ModelField.CanUpdate;
  end
  else
    Result := LNode.AsBoolean and ModelField.CanActuallyModify;
end;

function TKViewField.GetChildClass(const AName: string): TEFNodeClass;
begin
  if SameText(AName, 'Rules') then
    Result := TKRules
  else
    Result := inherited GetChildClass(AName);
end;

function TKViewField.GetColorsAsPairs: TEFPairs;
begin
  Result := GetChildrenAsPairs('Colors', True);
end;

function TKViewField.GetQualifiedAliasedDBName: string;
begin
  Result := Alias;
  if Result = '' then
    Result := ReplaceStr(QualifiedDBName, '.', '_');
  if Result = '' then
    raise EKError.CreateFmt('ViewField %s must have an alias.', [Name]);
end;

function TKViewField.GetQualifiedAliasedDBNameOrExpression: string;
var
  LExpression: string;
begin
  if Name = '' then
    raise EKError.Create('Missing field name.');
  LExpression := Expression;
  if LExpression <> '' then
    Result := LExpression + ' ' + FieldName
  else
  begin
    Result := QualifiedDBName;
    if Alias <> '' then
      Result := Result + ' ' + Alias;
  end;
end;

function TKViewField.GetQualifiedDBNameOrExpression: string;
var
  LCaptionField: TKModelField;
begin
  if IsReference then
  begin
    // Reference: qualify the referenced caption by the FK-column alias. Delimit
    // the alias and the caption column (unless the caption is a free expression).
    LCaptionField := ModelField.ReferencedModel.CaptionField;
    if LCaptionField.Expression <> '' then
      Result := DelimitDBId(DBName) + '.' + LCaptionField.Expression
    else
      Result := DelimitDBId(DBName) + '.' + DelimitDBId(LCaptionField.DBColumnName);
  end
  else if Expression <> '' then
    Result := Expression
  else
    Result := QualifiedDBName;
end;

function TKViewField.GetFieldType: TFieldType;
begin
  if IsReference then
    Result := ModelField.ReferencedModel.CaptionField.DataType.GetFieldType
  else
    Result := GetDataType.GetFieldType;
end;

function TKViewField.GetDataType: TEFDataType;
var
  LDataTypeName: string;
begin
  LDataTypeName := GetString('DataType');
  if LDataTypeName <> '' then
    Result := TEFDataTypeFactory.Instance.GetDataType(LDataTypeName)
  else if HasModelField then
    Result := ModelField.DataType
  else
    Result := TEFDataTypeFactory.Instance.GetDataType('String');
end;

function TKViewField.GetDBName: string;
var
  LNameParts: TArray<string>;
begin
  if Name.Contains('.') then
  begin
    LNameParts := Name.Split(['.']);
    Result := LNameParts[High(LNameParts)];
  end
  else
    Result := ModelField.DBColumnName;
end;

function TKViewField.GetDBNameOrExpression: string;
begin
  if IsReference then
    Result := ModelField.ReferencedModel.CaptionField.DBColumnNameOrExpression
  else if Expression <> '' then
    Result := Expression
  else
    Result := DBName;
end;

function TKViewField.GetModelField: TKModelField;
begin
  Result := Model.FieldByName(FieldName);
end;

function TKViewField.GetModel: TKModel;
begin
  Result := Table.Model.Catalog.ModelByName(ModelName);
end;

function TKViewField.GetDecimalPrecision: Integer;
begin
  // '<= 0' for the same reason as in TKModelField.GetDecimalPrecision: a
  // number of decimal digits is never negative, and one that is has to fall
  // back rather than travel on to a Byte.
  Result := GetInteger('DecimalPrecision');
  if Result <= 0 then
    Result := ModelField.DecimalPrecision;
end;

function TKViewField.GetDefaultFilter: string;
begin
  Result := GetString('DefaultFilter');
  if Result = '' then
    Result := ModelField.DefaultFilter;
end;

function TKViewField.GetDefaultFilterConnector: string;
begin
  Result := GetString('DefaultFilterConnector');
  if Result = '' then
    Result := ModelField.DefaultFilterConnector;
end;

function TKViewField.GetDefaultValue: Variant;
var
  LStringValue: string;
begin
  Result := EvalExpression(GetValue('DefaultValue'));
  if VarIsNull(Result) then
    Result := ModelField.DefaultValue;
  if DataType is TEFStringDataType then
  begin
    // Result may be Null here (a String field with no default value, or whose
    // default expression evaluated to Null). Assigning a Null variant straight
    // to a string raises "Could not convert variant of type (Null) into type
    // (OleStr)", which aborted opening ANY Add form containing such a field.
    // EFVarToStr maps Null/Empty to '' (same helper used for defaults above).
    LStringValue := EFVarToStr(Result);
    TEFMacroExpansionEngine.Instance.Expand(LStringValue);
    Result := LStringValue;
  end;
end;

function TKViewField.GetDerivedFields: TArray<TKViewField>;
begin
  Assert(IsReference, 'IsReference');

  Result := Table.GetFieldArray(
    function (AField: TKViewField): Boolean
    begin
      Result := (AField = Self) or (AField.ReferenceName = FieldName);
    end
  );
end;

function TKViewField.GetDisplayFormat: string;
begin
  Result := GetString('DisplayFormat');
  if Result = '' then
    Result := ModelField.DisplayFormat;
  if Result = '' then
    Result := EditFormat;
end;

function TKViewField.GetDisplayLabel: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('DisplayLabel2')
  else
    Result := GetString('DisplayLabel');
  if Result = '' then
    Result := ModelField.DisplayLabel;
end;

function TKViewField.GetDisplayLabel_Form: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('DisplayLabel_Form2')
  else
    Result := GetString('DisplayLabel_Form');
  if Result = '' then
    Result := ModelField.DisplayLabel_Form;
end;

function TKViewField.GetDisplayLabel_Grid: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('DisplayLabel_Grid2')
  else
    Result := GetString('DisplayLabel_Grid');
  if Result = '' then
    Result := ModelField.DisplayLabel_Grid;
end;

function TKViewField.GetDisplayTemplate: string;
var
  LNode: TEFNode;
begin
  LNode := FindNode('DisplayTemplate');
  if LNode = nil then
    Result := ModelField.DisplayTemplate
  else
    Result := LNode.AsString;
end;

function TKViewField.GetDisplayWidth: Integer;
begin
  Result := GetInteger('DisplayWidth');
  if Result = 0 then
    Result := ModelField.DisplayWidth;
end;

function TKViewField.GetEditFormat: string;
begin
  Result := GetString('EditFormat');
  if Result = '' then
    Result := ModelField.EditFormat;
end;

function TKViewField.GetEmptyAsNull: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('EmptyAsNull');
  if LNode = nil then
    Result := ModelField.EmptyAsNull
  else
    Result := LNode.AsBoolean;
end;

function TKViewField.GetExpression: string;
begin
  Result := GetString('Expression');
end;

function TKViewField.GetFieldName: string;
var
  LNameParts: TArray<string>;
begin
  LNameParts := Name.Split(['.']);
  if Length(LNameParts) = 1 then
    Result := Name
  else if Length(LNameParts) = 2 then
    Result := LNameParts[1]
  else
    raise EKError.CreateFmt('Couldn''t determine field name for field %s.', [Name]);
end;

function TKViewField.GetFieldNamesForUpdate: string;
begin
  if IsReference then
    Result := Join(ModelField.GetFieldNames, TKConfig.Instance.MultiFieldSeparator)
  else
    Result := FieldName;
end;

function TKViewField.GetFileNameField: string;
begin
  Result := GetString('FileNameField');
  if Result = '' then
    Result := ModelField.FileNameField;
end;

function TKViewField.GetFilterByFields: TArray<TKFilterByViewField>;
var
  I: Integer;
  LNode: TEFNode;
  LModelFieldPairs: TArray<TKFilterByField>;
  LModelFields: TKModelFieldArray;
  LViewFields: TKViewFieldArray;
begin
  SetLength(Result, 0);
  LNode := FindNode('FilterBy');
  if Assigned(LNode) then
  begin
    SetLength(Result, LNode.ChildCount);
    for I := Low(Result) to High(Result) do
    begin
      Result[I].DestinationField := Self;
      Result[I].SourceField := Table.FieldByName(LNode[I].Name);
      Result[I].ForeignFieldName := LNode[I].AsString;
    end;
  end
  else
  begin
    // Convert modelfield-level definition to viewfield-level.
    LModelFieldPairs := ModelField.GetFilterByFields;
    SetLength(LModelFields, Length(LModelFieldPairs));
    for I := Low(LModelFields) to High(LModelFields) do
      LModelFields[I] := LModelFieldPairs[I].Key;
    LViewFields := Table.FieldsByModelFields(LModelFields);
    SetLength(Result, Length(LViewFields));
    for I := Low(Result) to High(Result) do
    begin
      Result[I].DestinationField := Self;
      Result[I].SourceField := LViewFields[I];
      Result[I].ForeignFieldName := LModelFieldPairs[I].Value;
    end;
  end;
end;

function TKViewField.GetHint: string;
begin
  Result := GetString('Hint');
  if Result = '' then
    Result := ModelField.Hint;
end;

function TKViewField.GetIsVisible: Boolean;
begin
  Result := GetBoolean('IsVisible', True);
end;

function TKViewField.GetFieldsNode: string;
begin
  // RTTI carrier only: the sub-field list is walked node by node at render time.
  Result := '';
end;

function TKViewField.GetViewPhysicalName: string;
begin
  Result := GetString('PhysicalName');
end;

function TKViewField.GetLookupFilter: string;
begin
  Result := GetString('LookupFilter');
  if Result = '' then
    Result := ModelField.LookupFilter;
end;

function TKViewField.DelimitDBId(const AId: string): string;
var
  LEngineType: TEFDBEngineType;
begin
  Result := AId;
  // Best-effort delimiting via the field's database dialect. When DelimitedIdent
  // is off (the default) DelimitIdentifier is a no-op, so this only changes the
  // output for opted-in databases. If no runtime connection is available
  // (design-time / KIDE) we fall back to the raw identifier.
  try
    LEngineType := TKConfig.Instance.DatabaseFor(Model.DatabaseName).DBEngineType;
    if Assigned(LEngineType) then
      Result := LEngineType.DelimitIdentifier(AId);
  except
    // leave Result as the raw identifier
  end;
end;

function TKViewField.GetQualifiedDBName: string;
var
  LReferencedModelName: string;
  LReferenceField: TKViewField;
  LNameParts: TArray<string>;
begin
  LNameParts := Name.Split(['.']);
  if Length(LNameParts) > 1 then
  begin
    LReferencedModelName := LNameParts[0];
    LReferenceField := Table.FieldByName(LReferencedModelName);
    if LReferenceField.IsReference then
      // DelimitDBId splits on '.' and delimits each part: [alias].[column].
      Result := DelimitDBId(LReferenceField.ModelField.DBColumnName + '.' + ModelField.DBColumnName)
    else
      Result := Name;
  end
  else
    Result := DelimitDBId(Model.DBTableName + '.' + ModelField.DBColumnName);
end;

function TKViewField.GetSize: Integer;
begin
  Result := GetInteger('Size');
  if Result = 0 then
    Result := ModelField.Size;
end;

function TKViewField.GetIsAutoAddField: Boolean;
begin
  Result := pos(AUTO_ADD_FIELD_SEPARATOR, Name) > 0;
end;

function TKViewField.GetIsBlob: Boolean;
begin
  Result := DataType.IsBlob(Size);
end;

function TKViewField.GetIsDetailReference: Boolean;
begin
  Result := Table.IsDetail and (Table.ModelDetailReference.ReferenceField = ModelField);
end;

function TKViewField.GetIsKey: Boolean;
begin
  Result := (ModelName = Table.ModelName) and HasModelField and ModelField.IsKey;
end;

function TKViewField.GetIsPassword: Boolean;
begin
  Result := GetBoolean('IsPassword');
end;

function TKViewField.GetIsPicture: Boolean;
begin
  Result := GetBoolean('IsPicture');
end;

function TKViewField.GetUseSpeedButtons: Boolean;
begin
  Result := GetBoolean('UseSpeedButtons', False);
end;

function TKViewField.GetIsReadOnly: Boolean;
begin
  Result := GetBoolean('IsReadOnly');
end;

function TKViewField.GetIsReference: Boolean;
begin
  // HasModelField first: an expression-only view field has no backing model
  // field, and is never a reference. Without the guard ModelField would raise
  // 'Field not found'.
  Result := HasModelField and (Table.Model = Model) and ModelField.IsReference;
end;

function TKViewField.GetIsRequired: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('IsRequired');
  if LNode = nil then
    Result := ModelField.IsRequired
  else
    Result := LNode.AsBoolean or ModelField.IsRequired;
end;

function TKViewField.GetTable: TKViewTable;
begin
  Result := (Parent as TKViewFields).Table;
end;

function TKViewField.GetURLFieldName: string;
begin
  Result := URL_PREFIX + AliasedName;
end;

function TKViewField.IsAccessGranted(const AMode: string): Boolean;
begin
  Result := TKAccessController.Current.IsAccessGranted(TKAuthenticator.Current.UserName, GetACURI, AMode)
    and TKAccessController.Current.IsAccessGranted(TKAuthenticator.Current.UserName, ModelField.GetACURI, AMode);
end;

class function TKViewField.IsURLFieldName(const AFieldName: string): Boolean;
begin
  Result := AFieldName.StartsWith(URL_PREFIX);
end;

function TKViewField.GetReferenceName: string;
var
  LNameParts: TArray<string>;
begin
  LNameParts := Name.Split(['.']);
  if Length(LNameParts) = 1 then
    // <field name>
    Result := ''
  else if Length(LNameParts) = 2 then
    // <reference name>.<field name>
    Result := LNameParts[0]
  else
    raise EKError.CreateFmt('Couldn''t determine referenced model name for field %s.', [Name]);
end;

function TKViewField.GetResourceURI: string;
begin
  Result := Table.GetResourceURI;
  if Result <> '' then
    Result := Result + '/' + AliasedName;
end;

function TKViewField.GetModelName: string;
var
  LNameParts: TArray<string>;
  LReferencedModel: TKModel;
begin
  LNameParts := Name.Split(['.']);
  if Length(LNameParts) = 1 then
    // <field name>
    Result := Table.ModelName
  else if Length(LNameParts) = 2 then
  begin
    // <reference name>.<field name>
    LReferencedModel := Table.Model.FieldByName(LNameParts[0]).ReferencedModel;
    if Assigned(LReferencedModel) then
      Result := LReferencedModel.ModelName
    else
      Result := '';
  end;
  if Result = '' then
    raise EKError.CreateFmt('Couldn''t determine model name for field %s.', [Name]);
end;

function TKViewField.GetReferenceField: TKModelField;
begin
  if Model <> Table.Model then
    Result := Table.Model.FindReferenceField(Model)
  else
    Result := nil;
end;

function TKViewField.GetRules: TKRules;
begin
  Result := GetNode('Rules', True) as TKRules;
end;

{ TKViewTableStore }

function TKViewTableStore.AppendRecord(const AValues: TEFNode): TKViewTableRecord;
begin
  Result := inherited AppendRecord(AValues) as TKViewTableRecord;
  // The above will cause InternalAfterReadFromNode to be called, which
  // in turn will call SetDetailFieldValues itself, but only if there are
  // actual values. Otherwise we must set default values explicitly.
  if Assigned(FMasterRecord) and not Assigned(AValues) then
    Result.SetDetailFieldValues(FMasterRecord);
end;

constructor TKViewTableStore.Create(const AViewTable: TKViewTable);
begin
  Assert(Assigned(AViewTable), 'Assigned(AViewTable)');

  inherited Create;
  FViewTable := AViewTable;
  SetupFields;
end;

function TKViewTableStore.FindRecord(const AKey: TEFTree;
  const AFormatSettings: TFormatSettings;
  const AValueIndex: Integer): TKViewTableRecord;
begin
  Result := inherited FindRecord(AKey, AFormatSettings,
    function(const AName: string): string
    var
      LField: TKViewField;
    begin
      LField := ViewTable.FindField(AName);
      if Assigned(LField) then
        Result := LField.AliasedName
      else
        Result := AName;
    end,
    AValueIndex) as TKViewTableRecord;
end;

procedure TKViewTableStore.SetupFields;
var
  LViewFieldIndex: Integer;
  LViewField: TKViewField;
  LFieldNames: string;
  LModelFieldIndex: Integer;
  LModelField: TKModelField;
  LFieldModelField: TKModelField;

  procedure SetupField(const AViewField: TKViewField; const AName: string;
    const ADataType: TEFDataType; const AIsKey, AIsAccessGranted: Boolean;
    const AModelField: TKModelField);
  begin
    Assert(Assigned(AViewField), 'Assigned(AViewField)');

    if AIsAccessGranted or AIsKey then
    begin
      // Set field names and data types both in key and header.
      if AIsKey and not Assigned(Key.FindChild(AName)) then
        Key.AddChild(AName).DataType := ADataType;
      if not Assigned(Header.FindChild(AName)) then
        Header.AddField(AName).SetViewField(AViewField, ADataType).SetModelField(AModelField);
    end;
  end;

begin
  for LViewFieldIndex := 0 to FViewTable.FieldCount - 1 do
  begin
    LViewField := FViewTable.Fields[LViewFieldIndex];
    // An expression-only view field has no backing model field: pass nil rather
    // than dereferencing ModelField (which would raise 'Field not found'). Such
    // a field is not a reference (GetIsReference is guarded), so the reference
    // expansion below is not entered for it.
    if LViewField.HasModelField then
      LFieldModelField := LViewField.ModelField
    else
      LFieldModelField := nil;
    SetupField(LViewField, LViewField.AliasedName, LViewField.DataType,
      LViewField.IsKey and not LViewField.IsReference, LViewField.IsAccessGranted(ACM_READ),
      LFieldModelField);
    // URL fields for datatypes that provide downloadable content, such as images.
    if LViewField.IsPicture then
      SetupField(LViewField, LViewField.GetURLFieldName,
        TEFDataTypeFactory.Instance.GetDataType('String'),
        False, LViewField.IsAccessGranted(ACM_READ), LFieldModelField);
    // Expand reference fields. Also keep the reference field itself (above)
    // as it will hold the user-readable reference description.
    // For each reference field we create:
    // 1) the reference field itself (see above);
    // 2) a field for each field that is part of the reference (see below);
    // 3) a field that is the concatenation of all fields at (2).
    if LViewField.IsReference then
    begin
      Assert(LViewField.ModelField.FieldCount > 0, 'LViewField.ModelField.FieldCount > 0');

      for LModelFieldIndex := 0 to LViewField.ModelField.FieldCount - 1 do
      begin
        LModelField := LViewField.ModelField.Fields[LModelFieldIndex];
        SetupField(LViewField, LModelField.FieldName, LModelField.DataType,
          LModelField.IsKey and not LModelField.IsReference, LModelField.IsAccessGranted(ACM_READ),
          LModelField);
      end;

      // Let's assume a concatenation is a string.
      // By convention, we only use the first field for AC.
      LFieldNames := Join(LViewField.ModelField.GetFieldNames, TKConfig.Instance.MultiFieldSeparator);
      SetupField(LViewField, LFieldNames, TEFDataTypeFactory.Instance.GetDataType('String'),
        False, LViewField.ModelField.Fields[0].IsAccessGranted(ACM_READ), LViewField.ModelField);
    end;
  end;
end;

function TKViewTableStore.GetChildClass(const AName: string): TEFNodeClass;
begin
  if SameText(AName, 'Header') then
    Result := TKViewTableHeader
  else if SameText(AName, 'Records') then
    Result := TKViewTableRecords
  else
    Result := inherited GetChildClass(AName);
end;

function TKViewTableStore.GetHeader: TKViewTableHeader;
begin
  Result := inherited Header as TKViewTableHeader;
end;

function TKViewTableStore.GetRecord(const AKey: TEFTree; const AFormatSettings: TFormatSettings;
  const AValueIndex: Integer): TKViewTableRecord;
begin
  Result := inherited GetRecord(AKey, AFormatSettings,
    function(const AName: string): string
    var
      LField: TKViewField;
    begin
      LField := ViewTable.FindField(AName);
      if Assigned(LField) then
        Result := LField.AliasedName
      else
        Result := AName;
    end,
    AValueIndex) as TKViewTableRecord;
end;

function TKViewTableStore.GetRecords: TKViewTableRecords;
begin
  Result := inherited Records as TKViewTableRecords;
end;

function TKViewTableStore.Load(const AFilter, ASort: string;
  const AFrom, AFor: Integer; const AForEachRecord: TProc<TKVIewTableRecord>): Integer;
var
  LDBConnection: TEFDBConnection;
  LDBQuery: TEFDBQuery;
begin
  Assert(Assigned(FViewTable), 'Assigned(FViewTable)');

  LDBConnection := TKConfig.DatabaseFor(ViewTable.DatabaseName);
  LDBQuery := LDBConnection.CreateDBQuery;
  try
    if (AFrom = 0) and (AFor = 0) then
    begin
      TKSQLBuilder.CreateAndExecute(
        procedure (ASQLBuilder: TKSQLBuilder)
        begin
          ASQLBuilder.BuildSelectQuery(FViewTable, AFilter, ASort, LDBQuery, FMasterRecord);
        end);
      inherited Load(LDBQuery, False, False,
        procedure (ARecord: Kitto.Store.TKRecord)
        begin
          if Assigned(AForEachRecord) then
            AForEachRecord(ARecord as TKViewTableRecord);
        end);
      // Records loaded from DB are clean (not new) — needed for correct
      // state tracking in detail delete (rsNew vs rsClean → rsDeleted).
      Records.MarkAsClean;
      Result := RecordCount;
    end
    else
    begin
      TKSQLBuilder.CreateAndExecute(
        procedure (ASQLBuilder: TKSQLBuilder)
        begin
          ASQLBuilder.BuildCountQuery(FViewTable, AFilter, LDBQuery, FMasterRecord);
        end);
      LDBQuery.Open;
      try
        Result := LDBQuery.DataSet.Fields[0].AsInteger;
      finally
        LDBQuery.Close;
      end;
      TKSQLBuilder.CreateAndExecute(
        procedure (ASQLBuilder: TKSQLBuilder)
        begin
          ASQLBuilder.BuildSelectQuery(FViewTable, AFilter, ASort, LDBQuery, FMasterRecord, AFrom, AFor);
        end);
      inherited Load(LDBQuery, False, False,
        procedure (ARecord: Kitto.Store.TKRecord)
        begin
          if Assigned(AForEachRecord) then
            AForEachRecord(ARecord as TKViewTableRecord);
        end);
      // Records loaded from DB are clean (not new).
      Records.MarkAsClean;
    end;
  finally
    FreeAndNil(LDBQuery);
  end;
end;

{ TKViewTableHeader }

function TKViewTableHeader.AddField(const AFieldName: string): TKViewTableHeaderField;
begin
  Result := inherited AddField(AFieldName) as TKViewTableHeaderField;
end;

function TKViewTableHeader.FieldByName(const AFieldName: string): TKViewTableHeaderField;
begin
  Result := inherited FieldByName(AFieldName) as TKViewTableHeaderField;
end;

function TKViewTableHeader.FindField(const AFieldName: string): TKViewTableHeaderField;
begin
  Result := inherited FindField(AFieldName) as TKViewTableHeaderField;
end;

function TKViewTableHeader.GetChildClass(const AName: string): TEFNodeClass;
begin
  Result := TKViewTableHeaderField;
end;

function TKViewTableHeader.GetField(I: Integer): TKViewTableHeaderField;
begin
  Result := inherited Fields[I] as TKViewTableHeaderField;
end;

{ TKViewTableRecords }

function TKViewTableRecords.Append: TKViewTableRecord;
begin
  Result := inherited Append as TKViewTableRecord;
end;

function TKViewTableRecords.AppendAndInitialize: TKViewTableRecord;
begin
  Result := inherited AppendAndInitialize as TKViewTableRecord;
end;

function TKViewTableRecords.FindRecord(const AValues: TEFNode): TKViewTableRecord;
begin
  Result := inherited FindRecord(AValues) as TKViewTableRecord;
end;

function TKViewTableRecords.GetChildClass(const AName: string): TEFNodeClass;
begin
  Result := TKViewTableRecord;
end;

function TKViewTableRecords.GetRecord(
  const AValues: TEFNode): TKViewTableRecord;
begin
  Result := inherited GetRecord(AValues) as TKViewTableRecord;
end;

function TKViewTableRecords.GetRecord(I: Integer): TKViewTableRecord;
begin
  Result := inherited Records[I] as TKViewTableRecord;
end;

function TKViewTableRecords.GetStore: TKViewTableStore;
begin
  Result := inherited Store as TKViewTableStore;
end;

function TKViewTableRecords.GetXMLTagName: string;
begin
  Result := Store.ViewTable.Model.PluralModelName;
end;

{ TKViewTableRecord }

function TKViewTableRecord.AddDetailStore(const AStore: TKViewTableStore): TKViewTableStore;
begin
  Result := inherited AddDetailStore(AStore) as TKViewTableStore;
end;

procedure TKViewTableRecord.ApplyAfterRules;
begin
  Backup;
  try
    case State of
      rsNew: ViewTable.ApplyRules(
        procedure (ARuleImpl: TKRuleImpl)
        begin
          ARuleImpl.AfterAdd(Self);
        end);
      rsDirty: ViewTable.ApplyRules(
        procedure (ARuleImpl: TKRuleImpl)
        begin
          ARuleImpl.AfterUpdate(Self);
        end);
      rsDeleted: ViewTable.ApplyRules(
        procedure (ARuleImpl: TKRuleImpl)
        begin
          ARuleImpl.AfterDelete(Self);
        end);
    end;
  except
    Restore;
    raise;
  end;
  ClearBackup;
end;

procedure TKViewTableRecord.ApplyBeforeRules;
begin
  Backup;
  try
    case State of
      rsNew: ViewTable.ApplyRules(
        procedure (ARuleImpl: TKRuleImpl)
        begin
          ARuleImpl.BeforeAdd(Self);
        end);
      rsDirty: ViewTable.ApplyRules(
        procedure (ARuleImpl: TKRuleImpl)
        begin
          ARuleImpl.BeforeUpdate(Self);
        end);
      rsDeleted: ViewTable.ApplyRules(
        procedure (ARuleImpl: TKRuleImpl)
        begin
          ARuleImpl.BeforeDelete(Self);
        end);
    end;
  except
    Restore;
    raise;
  end;
  ClearBackup;
end;

procedure TKViewTableRecord.ApplyConfirmRules;
begin
  Backup;
  try
    ViewTable.ApplyRules(
      procedure (ARuleImpl: TKRuleImpl)
      begin
        ARuleImpl.AfterConfirm(Self);
      end);
  except
    Restore;
    raise;
  end;
  ClearBackup;
end;

var
  /// Last temporary key handed out by TKViewTableRecord.EnsureTemporaryKey:
  /// decremented atomically, sessions share it.
  GLastTemporaryKey: Integer = 0;

procedure TKViewTableRecord.EnsureTemporaryKey;
var
  I: Integer;
  LViewField: TKViewField;
  LField: TKViewTableField;
begin
  // Only a row that is not in the database yet, in a detail store.
  if (State <> rsNew) or not Assigned(Records) or not Assigned(Records.Store)
    or not Assigned(Records.Store.MasterRecord) then
    Exit;
  for I := 0 to ViewTable.FieldCount - 1 do
  begin
    LViewField := ViewTable.Fields[I];
    if not LViewField.IsKey or not Assigned(LViewField.ModelField)
      or not LViewField.ModelField.IsGenerated
      or not (LViewField.DataType is TEFIntegerDataType) then
      Continue;
    LField := FindField(LViewField.AliasedName);
    if Assigned(LField) and LField.IsNull then
      LField.AsInteger := TInterlocked.Decrement(GLastTemporaryKey);
  end;
end;

procedure TKViewTableRecord.ApplyEditRecordRules;
begin
  ViewTable.ApplyRules(
    procedure (ARuleImpl: TKRuleImpl)
    begin
      ARuleImpl.EditRecord(Self);
    end);
end;

procedure TKViewTableRecord.ApplyAfterShowEditWindowRules;
begin
  ViewTable.ApplyRules(
    procedure (ARuleImpl: TKRuleImpl)
    begin
      ARuleImpl.AfterShowEditWindow(Self);
    end);
end;

procedure TKViewTableRecord.ApplyDuplicateRecordRules;
begin
  ViewTable.ApplyRules(
    procedure (ARuleImpl: TKRuleImpl)
    begin
      ARuleImpl.DuplicateRecord(Self);
    end);
end;

procedure TKViewTableRecord.InitAsCloneOf(const ASource: TKViewTableRecord);
var
  LValues: TEFNode;
  LKeyDefaultValues: TEFNode;
begin
  Assert(Assigned(ASource), 'Assigned(ASource)');

  LValues := TEFNode.Clone(ASource,
    // Don't copy PK values: the clone must get a key of its own.
    procedure (const ASourceNode, ADestinationNode: TEFNode)
    var
      LViewField: TKViewField;
    begin
      LViewField := ViewTable.FindField(ASourceNode.Name);
      if Assigned(LViewField) and LViewField.IsKey then
        ADestinationNode.Value := Null;
    end);
  try
    // Re-apply the default values of the key fields only, so that generated
    // keys get a fresh value while the other fields keep the source's ones.
    LKeyDefaultValues := ViewTable.GetDefaultValues(True);
    try
      LValues.Merge(LKeyDefaultValues);
    finally
      FreeAndNil(LKeyDefaultValues);
    end;

    // Bulk assignment: no need to fire the FieldChanged cascade for every
    // field, the derived reference values are refreshed once below.
    Store.DoWithChangeNotificationsDisabled(
      procedure
      begin
        ReadFromNode(LValues);
      end);
  finally
    FreeAndNil(LValues);
  end;

  RefreshDerivedReferenceValues;

  // Fires BeforeNewRecord/NewRecord rules/AfterNewRecord and marks the record
  // as new, so that persisting it issues an INSERT rather than an UPDATE.
  ApplyNewRecordRulesAndFireEvents(ViewTable, True);
end;

procedure TKViewTableRecord.FieldChangeRulesHandler(const AField: TKField;
  const AOldValue, ANewValue: Variant);
var
  LField: TKViewTableField;
  LOldValue, LNewValue: Variant;
begin
  // Same body as Kitto1's TKExtFormPanelController.FieldChange: enumerate the
  // rules of the changed field's ViewField and invoke AfterFieldChange.
  if not (AField is TKViewTableField) then
    Exit;
  LField := TKViewTableField(AField);
  if LField.IsPartOfCompositeField then
    Exit;
  LOldValue := AOldValue;
  LNewValue := ANewValue;
  LField.ViewField.EnumRules(
    function (ARuleImpl: TKRuleImpl): Boolean
    begin
      ARuleImpl.AfterFieldChange(AField, LOldValue, LNewValue);
      Result := False; // Continue with the next rule.
    end);
end;

procedure TKViewTableRecord.ApplyNewRecordRules(const AFireFieldChangeRules: Boolean);
var
  LPreviousHandler: TKFieldChangeEvent;
begin
  // A NewRecord rule that assigns a field must trigger the AfterFieldChange
  // rules of that field: applications rely on it to derive a whole block of
  // values from one assignment. KittoSCM, for instance, sets the id of the
  // user doing the insert and expects the parent's name, surname, phone,
  // e-mail and address to be read from the registry
  // (RulesIscrizione.pas, TIscriviFiglio.NewRecord and TIscrizioneSetGenitore),
  // which is why that value is assigned there instead of being declared as a
  // model default.
  LPreviousHandler := OnFieldChange;
  if AFireFieldChangeRules then
    OnFieldChange := FieldChangeRulesHandler;
  try
    ViewTable.ApplyRules(
      procedure (ARuleImpl: TKRuleImpl)
      begin
        ARuleImpl.NewRecord(Self);
      end);
  finally
    OnFieldChange := LPreviousHandler;
  end;
  MarkAsNew;
end;

procedure TKViewTableRecord.ApplyNewRecordRulesAndFireEvents(const AViewTable: TKViewTable;
  const AIsCloned: Boolean; const AFireFieldChangeRules: Boolean);
begin
  Assert(Assigned(AViewTable), 'Assigned(AViewTable)');

  AViewTable.Model.BeforeNewRecord(Self, AIsCloned);
  Self.ApplyNewRecordRules(AFireFieldChangeRules);
  AViewTable.Model.AfterNewRecord(Self);
end;

procedure TKViewTableRecord.LoadDetailStores;
var
  I: Integer;
  LRecordIndex: Integer;
begin
  EnsureDetailStores;
  for I := 0 to DetailStoreCount - 1 do
  begin
    DetailStores[I].Load;
    for LRecordIndex := 0 to DetailStores[I].RecordCount - 1 do
      DetailStores[I].Records[LRecordIndex].LoadDetailStores;
  end;
end;

procedure TKViewTableRecord.Refresh(const AStrict: Boolean = False);
var
  LDBConnection: TEFDBConnection;
  LDBQuery: TEFDBQuery;
begin
  Assert(Assigned(ViewTable), 'Assigned(ViewTable)');

  LDBConnection := TKConfig.DatabaseFor(ViewTable.DatabaseName);
  LDBQuery := LDBConnection.CreateDBQuery;
  try
    TKSQLBuilder.CreateAndExecute(
      procedure (ASQLBuilder: TKSQLBuilder)
      begin
        ASQLBuilder.BuildSingletonSelectQuery(ViewTable, LDBQuery, GetFieldValues(Store.ViewTable.Model.GetKeyFieldNames));
      end);
    LDBQuery.Open;
    if AStrict and LDBQuery.DataSet.IsEmpty then
      raise Exception.Create('Record not found');
    if not LDBQuery.DataSet.IsEmpty then
      ReadFromFields(LDBQuery.DataSet.Fields);
    MarkAsClean;
  finally
    FreeAndNil(LDBQuery);
  end;
end;

procedure TKViewTableRecord.EnsureDetailStores;
var
  I: Integer;
  LStore: TKViewTableStore;
begin
  if DetailStoreCount = 0 then
  begin
    for I := 0 to Records.Store.ViewTable.DetailTableCount - 1 do
    begin
      LStore := Records.Store.ViewTable.DetailTables[I].CreateStore;
      LStore.MasterRecord := Self;
      AddDetailStore(LStore);
    end;
  end;
end;

function TKViewTableRecord.FieldByName(const AFieldName: string): TKViewTableField;
begin
  Result := inherited FieldByName(AFieldName) as TKViewTableField;
end;

function TKViewTableRecord.FindFieldByDBColumnName(const ADBColumnName: string): TKViewTableField;
var
  I: Integer;
  LField: TKViewTableField;
begin
  Result := nil;
  for I := 0 to FieldCount - 1 do
  begin
    LField := Fields[I];
    // Match the scalar (sub-)field that maps to the physical column. For a key
    // made of reference fields, GetKeyDBColumnNames returns the sub-field
    // columns (e.g. 'Codice_Mappa'): these are held by the scalar sub-fields
    // expanded into the store header, not by the reference field itself (whose
    // value can't be bound as a scalar parameter). Skip reference fields so the
    // bindable scalar sub-field is returned even when the reference is forced to
    // the same physical name.
    if Assigned(LField.ModelField) and not LField.ModelField.IsReference and
        SameText(LField.ModelField.DBColumnName, ADBColumnName) then
      Exit(LField);
  end;
end;

function TKViewTableRecord.FieldByDBColumnName(const ADBColumnName: string): TKViewTableField;
begin
  Result := FindFieldByDBColumnName(ADBColumnName);
  if not Assigned(Result) then
    raise EKError.CreateFmt('Couldn''t find a field with DB column name %s.',
      [ADBColumnName]);
end;

procedure TKViewTableRecord.FieldChanged(const AField: TKField; const AOldValue, ANewValue: Variant);
var
  LField: TKViewTableField;
  LStore: TKStore;
  I: Integer;
  LDerivedField: TKViewTableField;
  LViewField: TKViewField;
  LFieldNames: TArray<string>;
  LFieldValues: TArray<string>;
  LFilteredByFields: TArray<TKFilterByViewField>;
begin
  Assert(AField is TKViewTableField, 'AField is TKViewTableField');

  LField := TKViewTableField(AField);
  LViewField := LField.ViewField;

  // Forward the changed value to the multi-valued field constituent parts.
  if LField.IsCompositeField then
  begin
    LFieldNames := LField.FieldName.Split([TKConfig.Instance.MultiFieldSeparator], TStringSplitOptions.None);
    // Test for null and '' as well, since compound fields are always treated as
    // strings and never set to null.
    // A value made only of separators (all parts empty) counts as null too.
    if VarIsNull(ANewValue) or
      (string(ANewValue).Replace(TKConfig.Instance.MultiFieldSeparator, '') = '') then
    begin
      for I := Low(LFieldNames) to High(LFieldNames) do
        FieldByName(LFieldNames[I]).SetToNull;
    end
    else
    begin
      LFieldValues := string(ANewValue).Split([TKConfig.Instance.MultiFieldSeparator], TStringSplitOptions.None);
      if Length(LFieldNames) <> Length(LFieldValues) then
        raise EKError.CreateFmt('Composite field %s expects %d values, got %d (value: "%s").',
          [LField.FieldName, Length(LFieldNames), Length(LFieldValues), string(ANewValue)]);
      for I := Low(LFieldNames) to High(LFieldNames) do
        FieldByName(LFieldNames[I]).Value := LFieldValues[I];
    end;
  end;

  // See if LField is part of a reference. LField.ViewField gets a reference
  // to the reference ViewField, if any, or the corresponding ViewField otherwise.
  if LViewField.IsReference and not LField.IsPartOfCompositeField then
  begin
    if LField.FieldName <> LViewField.AliasedName then
    begin
      // Avoid re-entry.
      if FReferenceViewFieldBeingChanged = LViewField then
        Exit;

      FReferenceViewFieldBeingChanged := LViewField;
      try
        // Get derived values.
        { TODO : Optimization: If ANewValue is null or unassigned, you don't even need to create the store and query the database. }
        LStore := LViewField.CreateDerivedFieldsStore(EFVarToStr(ANewValue));
        try
          // Copy values to fields.
          for I := 0 to LStore.Header.FieldCount - 1 do
          begin
            LDerivedField := FindField(TranslateFieldName(LStore.Header.Fields[I].FieldName));
            if Assigned(LDerivedField) then
            begin
              if LStore.RecordCount > 0 then
                LDerivedField.AssignValue(LStore.Records[0].Fields[I])
              else
                LDerivedField.SetToNull;
            end;
          end;
          LField.ViewField.EnumRules(
            function (ARuleImpl: TKRuleImpl): Boolean
            begin
              ARuleImpl.AfterRefreshReferenceField(LField);
              Result := True;
            end);
        finally
          FreeAndNil(LStore);
        end;
      finally
        FReferenceViewFieldBeingChanged := nil;
      end;
    end;
    // Clear filtered-by fields only when changing the view field itself (not
    // any underlying real fields).
    if LField.FieldName = LViewField.AliasedName then
    begin
      LFilteredByFields := LViewField.Table.GetFilterByFields(
        function (AFilterByViewField: TKFilterByViewField): Boolean
        begin
          Result := AFilterByViewField.SourceField = LViewField;
          if Result then
          begin
            // Select all destination fields and clear them, forcing the change
            // event since we need it to update the UI.
            EnumChildren(
              procedure (const ANode: TEFNode)
              begin
                ANode.SetToNull(True);
              end,
              function (const ANode: TEFNode): Boolean
              begin
                Result := TKVIewTableField(ANode).ViewField = AFilterByViewField.DestinationField;
              end
            );
          end;
        end);
    end;
  end;
  inherited;
end;

procedure TKViewTableRecord.RefreshDerivedReferenceValues;
var
  I: Integer;
  LViewField: TKViewField;
  LCaptionField: TKViewTableField;
  LFKField: TKViewTableField;
  LStore: TKStore;
  LKeyValue: string;
begin
  for I := 0 to ViewTable.FieldCount - 1 do
  begin
    LViewField := ViewTable.Fields[I];
    if not LViewField.IsReference then
      Continue;
    // Only single-key references (the common case); composite keys are left as-is.
    if LViewField.ModelField.ReferencedModel.KeyFieldCount <> 1 then
      Continue;
    // No DerivedFieldsExist test here, on purpose: that function answers
    // whether the view table carries fields derived FROM this reference -- the
    // dotted <reference>.<field> ones, which GetFields materialises from
    // AutoAddFields only for a table that declares no Fields: of its own. The
    // reference's OWN caption depends on none of that: GetDerivedFields always
    // includes Self, and BuildDerivedSelectQuery handles that entry by
    // selecting the referenced model's CaptionField. The two guards below are
    // the ones that belong here: caption still empty and the foreign key set.
    // Skip if the reference caption is already resolved (records loaded from DB,
    // or references already refreshed by the per-field notify cycle).
    LCaptionField := FindField(LViewField.AliasedName);
    if Assigned(LCaptionField) and not LCaptionField.IsNull and (LCaptionField.AsString <> '') then
      Continue;
    // Foreign key must be set to look up the derived values.
    LFKField := FindField(LViewField.FieldNamesForUpdate);
    if not Assigned(LFKField) or LFKField.IsNull then
      Continue;
    LKeyValue := LFKField.AsString;
    if LKeyValue = '' then
      Continue;
    // Same mechanism as FieldChanged: query the referenced model for the
    // derived fields (caption + AutoAddFields) and copy them onto this record.
    LStore := LViewField.CreateDerivedFieldsStore(LKeyValue);
    try
      Store.DoWithChangeNotificationsDisabled(
        procedure
        var
          K: Integer;
          LDF: TKViewTableField;
        begin
          for K := 0 to LStore.Header.FieldCount - 1 do
          begin
            LDF := FindField(TranslateFieldName(LStore.Header.Fields[K].FieldName));
            if Assigned(LDF) then
            begin
              if LStore.RecordCount > 0 then
                LDF.AssignValue(LStore.Records[0].Fields[K])
              else
                LDF.SetToNull;
            end;
          end;
        end);
    finally
      FreeAndNil(LStore);
    end;
  end;
end;

procedure TKViewTableRecord.RefreshMasterReferenceValues;
var
  I: Integer;
  LViewField: TKViewField;
  LMasterRecord: TKViewTableRecord;
  LMasterViewTable: TKViewTable;

  // Copies one value from the master record onto ADestField, by the name of the
  // master's own field. Silent when there is nothing to copy: for a master read
  // from the database the detail rows already carry what the join brought.
  procedure CopyFromMaster(const AMasterFieldName: string;
    const ADestField: TKViewTableField);
  var
    LMasterValue: TKViewTableField;
  begin
    if not Assigned(ADestField) or (AMasterFieldName = '') then
      Exit;
    LMasterValue := LMasterRecord.FindField(
      LMasterViewTable.ApplyFieldAliasedName(AMasterFieldName));
    if not Assigned(LMasterValue) or LMasterValue.IsNull then
      Exit;
    Store.DoWithChangeNotificationsDisabled(
      procedure
      begin
        ADestField.AssignValue(LMasterValue);
      end);
  end;

  procedure CopyReferenceValues(const AReferenceField: TKViewField);
  var
    LCaptionField: TKModelField;
    LDerivedFields: TArray<TKViewField>;
    LDerivedField: TKViewField;
    LDerivedModelField: TKModelField;
  begin
    // FindCaptionField, not CaptionField: the latter asserts, and assertions are
    // compiled out of a Release build, so it would return nil and crash there
    // and only there.
    LCaptionField := LMasterViewTable.Model.FindCaptionField;
    // A caption that is an expression is computed by the database (see
    // TKSQLBuilder.AddReferenceFieldTerms): nothing in memory corresponds to
    // it.
    if Assigned(LCaptionField) and (LCaptionField.Expression = '') then
      CopyFromMaster(LCaptionField.FieldName, FindField(AReferenceField.AliasedName));

    // The reference's derived fields -- what AutoAddFields declares. Each
    // names a field of the referenced model, which here is the master, so its
    // value is in the master record. GetDerivedFields includes the reference
    // itself, which is the caption handled above.
    LDerivedFields := AReferenceField.GetDerivedFields;
    for LDerivedField in LDerivedFields do
    begin
      if LDerivedField = AReferenceField then
        Continue;
      // FindModelField, NOT HasModelField: the two disagree on a dotted
      // field. FindModelField resolves through Model, which for
      // <reference>.<field> is the REFERENCED model, while HasModelField looks
      // the same name up in Table.ModelName -- the detail's own model, where a
      // field belonging to the master does not exist.
      LDerivedModelField := LDerivedField.FindModelField;
      if not Assigned(LDerivedModelField) or (LDerivedModelField.Expression <> '') then
        Continue;
      CopyFromMaster(LDerivedModelField.FieldName,
        FindField(LDerivedField.AliasedName));
    end;
  end;

begin
  if not Assigned(Store) or not Assigned(Store.MasterRecord) then
    Exit;
  if not ViewTable.IsDetail then
    Exit;
  LMasterRecord := Store.MasterRecord;
  LMasterViewTable := LMasterRecord.ViewTable;

  for I := 0 to ViewTable.FieldCount - 1 do
  begin
    LViewField := ViewTable.Fields[I];
    // IsDetailReference, not "points at the master's model": a detail model
    // can reference the master more than once -- the reason
    // DetailReferences/ReferenceField exists -- and only one of those is the
    // link. TKViewField.IsDetailReference compares against
    // ModelDetailReference.ReferenceField, which is that one.
    if not LViewField.IsReference or not LViewField.IsDetailReference then
      Continue;
    CopyReferenceValues(LViewField);
  end;
end;

procedure TKViewTableRecord.FieldChanging(const AField: TKField;
  const AOldValue: Variant; var ANewValue: Variant; var ADoIt: Boolean);
var
  LField: TKViewTableField;
  LOldValue: Variant;
  LNewValue: Variant;
  LDoIt: Boolean;
begin
  inherited;
  Assert(AField is TKViewTableField, 'AField is TKViewTableField');

  LField := TKViewTableField(AField);
  LOldValue := AOldValue;
  LNewValue := ANewValue;
  LDoIt := ADoIt;
  LField.ViewField.EnumRules(
    function (ARuleImpl: TKRuleImpl): Boolean
    begin
      ARuleImpl.BeforeFieldChange(AField, LOldValue, LNewValue, LDoIt);
      Result := True;
    end);
  ADoIt := LDoIt;
  if ADoIt then
    ANewValue := LNewValue;
end;

function TKViewTableRecord.FindField(const AFieldName: string): TKViewTableField;
begin
  Result := inherited FindField(AFieldName) as TKViewTableField;
end;

function TKViewTableRecord.GetChildClass(const AName: string): TEFNodeClass;
begin
  Result := TKViewTableField;
end;

function TKViewTableRecord.GetDetailsStore(I: Integer): TKViewTableStore;
begin
  Result := inherited DetailStores[I] as TKViewTableStore;
end;

function TKViewTableRecord.GetField(I: Integer): TKViewTableField;
begin
  Result := inherited Fields[I] as TKViewTableField;
end;

function TKViewTableRecord.GetRecords: TKViewTableRecords;
begin
  Result := inherited Records as TKViewTableRecords;
end;

function TKViewTableRecord.GetStore: TKViewTableStore;
begin
  Result := Records.Store;
end;

function TKViewTableRecord.GetViewTable: TKViewTable;
begin
  Result := Store.ViewTable;
end;

function TKViewTableRecord.GetXMLTagName: string;
begin
  Result := ViewTable.ModelName;
end;

procedure TKViewTableRecord.HandleDeleteFileInstructions;
begin
  EnumFields(
    function (AField: TKField): Boolean
    var
      LFileToDelete: string;
    begin
      if (AField.DataType is TKFileReferenceDataType) and (AField.IsNull) then
      begin
        LFileToDelete := AField.GetString('Sys/DeleteFile');
        if FileExists(LFileToDelete) then
          TFile.Delete(LFileToDelete);
      end;
      Result := True;
    end
  );
end;

procedure TKViewTableRecord.InternalAfterReadFromNode;
begin
  inherited;
  if Records.Store.MasterRecord <> nil then
  begin
    SetDetailFieldValues(Records.Store.MasterRecord);
    // The key alone is not enough to show the row: the reference to the master
    // is rendered by its caption, which no query can produce while the master
    // has no row yet.
    RefreshMasterReferenceValues;
  end;
end;

procedure TKViewTableRecord.ExpandExpression(var AExpression: string);
var
  I: Integer;
  LField: TKViewTableField;
begin
  inherited ExpandExpression(AExpression);
  if Assigned(Store) and Assigned(Store.MasterRecord) then
  begin
    for I := 0 to Store.MasterRecord.FieldCount - 1 do
    begin
      LField := Store.MasterRecord.Fields[I];
      ReplaceAllCaseSensitive(AExpression, Format('{MasterRecord.%s}',[LField.FieldName]), LField.AsString);
    end;
  end;
end;

procedure TKViewTableRecord.ExpandFieldJSONValues(var AText: string;
  const AEmptyNulls: Boolean; const ASender: TKViewField = nil);
var
  I: Integer;
  LField: TKViewTableField;
begin
  for I := 0 to FieldCount - 1 do
  begin
    LField := Fields[I];
    if LField.ViewField <> ASender then
    begin
      ReplaceAllCaseSensitive(AText, '{' + LField.FieldName + '}', LField.GetAsJSONValue(True, False, True));
    end;
  end;
end;

procedure TKViewTableRecord.SetDetailFieldValues(const AMasterRecord: TKViewTableRecord);
var
  LMasterFieldNames: TStringDynArray;
  LDetailFieldNames: TStringDynArray;
  I: Integer;
begin
  Assert(Records.Store.ViewTable.IsDetail, 'Records.Store.ViewTable.IsDetail');

  // Get master and detail field names...
  LMasterFieldNames := Records.Store.ViewTable.MasterTable.Model.GetKeyFieldNames;
  Assert(Length(LMasterFieldNames) > 0, 'Length(LMasterFieldNames) > 0');
  LDetailFieldNames := Records.Store.ViewTable.ModelDetailReference.ReferenceField.GetFieldNames;
  Assert(Length(LDetailFieldNames) = Length(LMasterFieldNames), 'Length(LDetailFieldNames) = Length(LMasterFieldNames)');

  for I := 0 to High(LDetailFieldNames) do
  begin
    // ...alias them...
    LMasterFieldNames[I] := Records.Store.ViewTable.MasterTable.ApplyFieldAliasedName(LMasterFieldNames[I]);
    LDetailFieldNames[I] := Records.Store.ViewTable.ApplyFieldAliasedName(LDetailFieldNames[I]);
    // ... and copy values.
    GetNode(LDetailFieldNames[I]).AssignValue(AMasterRecord.GetNode(LMasterFieldNames[I]));
  end;
end;

function TKViewTableRecord.TranslateFieldName(const AFieldName: string): string;
var
  LViewField: TKViewField;
  LFieldIndex: Integer;
begin
  LViewField := FieldByName(AFieldName).ViewField;
  if LViewField.IsReference then
  begin
    LFieldIndex := IndexStr(AFieldName, LViewField.ModelField.GetFieldNames);
    if LFieldIndex >= 0 then
      Result := LViewField.ModelField.Fields[LFieldIndex].DBColumnName
    else
      Result := inherited TranslateFieldName(AFieldName);
  end
  else
    Result := LViewField.AliasedDBName;
end;

function TKViewTableRecord.FindDetailStoreByModelName(const AModelName: string;
  const AForceLoad: Boolean): TKViewTableStore;
var
  I: Integer;
  LDetailTableStore: TKViewTableStore;
begin
  Result := nil;
  for I := 0 to DetailStoreCount -1 do
  begin
    LDetailTableStore := DetailStores[I];
    if SameText(LDetailTableStore.ViewTable.ModelName, AModelName) then
    begin
      Result := LDetailTableStore;
      if (Result.RecordCount = 0) or AForceLoad then
        Result.Load;
      Break;
    end;
  end;
end;

function TKViewTableRecord.GetDetailStoreByModelName(const AModelName: string;
  const AForceLoad: Boolean): TKViewTableStore;
begin
  Result := FindDetailStoreByModelName(AModelName, AForceLoad);
  if not Assigned(Result) then
    raise EKError.CreateFmt(_('DetailStore %s not found.'), [AModelName]);
end;

{ TKViewTableField }

function TKViewTableField.GetAsJSONValue(const AForDisplay: Boolean; const AQuote: Boolean;
  const AEmptyNulls: Boolean): string;
const
  PASSWORD_CHARS = 8;
var
  LDisplayTemplate: string;
  LViewField: TKViewField;
begin
  Result := inherited GetAsJSONValue(AForDisplay, False, AEmptyNulls);
  LViewField := ViewField;
  if AForDisplay and Assigned(LViewField) then
  begin
    // Use value of IsPassword cached in the header for best speed.
    if HeaderField.ViewFieldIsPassword then
      Result := DupeString('*', Min(LViewField.DisplayWidth, PASSWORD_CHARS))
    else
    begin
      // Use value of DisplayTemplate cached in the header for best speed.
      LDisplayTemplate := HeaderField.ViewFieldDisplayTemplate;
      if LDisplayTemplate <> '' then
      begin
        // Replace other field values, this field's value and add back quotes.
        ReplaceAllCaseSensitive(LDisplayTemplate, '{value}', Result);
        ParentRecord.ExpandFieldJSONValues(LDisplayTemplate, AEmptyNulls, LViewField);
        Result := LDisplayTemplate;
      end;
    end;
  end;
  if AQuote and not SameText(Result, 'null') then
    Result := QuoteJSONStr(Result);
end;

function TKViewTableField.GetDecimalPrecision: Integer;
begin
  Result := ViewField.DecimalPrecision;
end;

function TKViewTableField.GetEmptyAsNull: Boolean;
begin
  Result := ViewField.EmptyAsNull;
end;

function TKViewTableField.GetHeaderField: TKViewTableHeaderField;
begin
  Result := inherited HeaderField as TKViewTableHeaderField;
end;

function TKViewTableField.GetModelField: TKModelField;
begin
  Result := HeaderField.ModelField;
end;

function TKViewTableField.GetParentRecord: TKViewTableRecord;
begin
  Result := inherited ParentRecord as TKViewTableRecord;
end;

function TKViewTableField.GetViewField: TKViewField;
begin
  Result := HeaderField.ViewField;
end;

function TKViewTableField.IsPhysicalPartOfReference: Boolean;
begin
  Result := ViewField.IsReference and (ModelField <> ViewField.ModelField);
end;

{ TKFileReferenceDataType }

class function TKFileReferenceDataType.GetTypeName: string;
begin
  Result := 'FileReference';
end;

{ TKViewTableHeaderField }

function TKViewTableHeaderField.SetModelField(const AValue: TKModelField): TKViewTableHeaderField;
begin
  FModelField := AValue;
  Result := Self;
end;

function TKViewTableHeaderField.SetViewField(const AValue: TKViewField; const AOverrideDataType: TEFDataType = nil): TKViewTableHeaderField;
begin
  FViewField := AValue;
  if Assigned(FViewField) then
  begin
    FViewFieldIsPassword := FViewField.IsPassword;
    FViewFieldDisplayTemplate := FViewField.DisplayTemplate;
    if AOverrideDataType = nil then
      DataType := FViewField.DataType
    else
      DataType := AOverrideDataType
  end
  else
  begin
    FViewFieldIsPassword := False;
    FViewFieldDisplayTemplate := '';
    DataType := nil;
  end;
  Result := Self;
end;

{ TKHTMLMemoDataType }

class function TKHTMLMemoDataType.GetTypeName: string;
begin
  Result := 'HTMLMemo';
end;

{ TKGroupingShowCountConfig }

function TKGroupingShowCountConfig.GetItemName: string;
begin
  Result := GetString('ItemName');
end;

function TKGroupingShowCountConfig.GetPluralItemName: string;
begin
  Result := GetString('PluralItemName');
end;

function TKGroupingShowCountConfig.GetTemplate: string;
begin
  Result := GetString('Template');
end;

{ TKGroupingConfig }

function TKGroupingConfig.GetFieldName: string;
begin
  Result := GetString('FieldName');
end;

function TKGroupingConfig.GetSortFieldNames: string;
begin
  Result := GetString('SortFieldNames');
end;

function TKGroupingConfig.GetEnableMenu: Boolean;
begin
  Result := GetBoolean('EnableMenu', False);
end;

function TKGroupingConfig.GetStartCollapsed: Boolean;
begin
  Result := GetBoolean('StartCollapsed', False);
end;

function TKGroupingConfig.GetShowName: Boolean;
begin
  Result := GetBoolean('ShowName', False);
end;

function TKGroupingConfig.GetAggregates: string;
begin
  // RTTI carrier only: the per-column aggregates are read node by node.
  Result := '';
end;

function TKGroupingConfig.GetShowCount: TKGroupingShowCountConfig;
begin
  Result := nil; // RTTI discovery only
end;

{ TKPopupWindowConfig }

function TKPopupWindowConfig.GetWidth: Integer;
begin
  Result := GetInteger('Width', 800);
end;

function TKPopupWindowConfig.GetHeight: Integer;
begin
  Result := GetInteger('Height', 600);
end;

{ TKFormControllerButtonConfig }

function TKFormControllerButtonConfig.GetCaption: string;
begin
  Result := GetString('Caption');
end;

function TKFormControllerButtonConfig.GetToolTip: string;
begin
  Result := GetString('ToolTip');
end;

{ TKFormControllerConfig }

function TKFormControllerConfig.GetKeepOpenAfterOperation: Boolean;
begin
  Result := GetBoolean('KeepOpenAfterOperation', False);
end;

{ TKEditControllerConfig }

function TKEditControllerConfig.GetWidth: Integer;
begin
  Result := GetInteger('Width', 0);
end;

function TKEditControllerConfig.GetHeight: Integer;
begin
  Result := GetInteger('Height', 0);
end;

function TKEditControllerConfig.GetLabelWidth: Integer;
begin
  Result := GetInteger('LabelWidth', 0);
end;

function TKEditControllerConfig.GetLabelAlign: string;
begin
  Result := GetString('LabelAlign');
end;

function TKEditControllerConfig.GetCloneButton: Boolean;
begin
  Result := GetBoolean('CloneButton', False);
end;

function TKEditControllerConfig.GetKeepOpenAfterOperation: Boolean;
begin
  Result := GetBoolean('KeepOpenAfterOperation', False);
end;

function TKEditControllerConfig.GetShowNavigationButtons: Boolean;
begin
  Result := GetBoolean('ShowNavigationButtons', False);
end;

function TKEditControllerConfig.GetApplyButton: string;
begin
  // RTTI carrier only: the ApplyButton block is read node by node at render time.
  Result := '';
end;

function TKEditControllerConfig.GetToolViews: TKToolViewsConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKFormControllerConfig.GetButtonScale: string;
begin
  Result := GetString('ButtonScale');
end;

function TKFormControllerConfig.GetCloneButton: TKFormControllerButtonConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKFormControllerConfig.GetConfirmButton: TKFormControllerButtonConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKFormControllerConfig.GetCancelButton: TKFormControllerButtonConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKFormControllerConfig.GetCloseButton: TKFormControllerButtonConfig;
begin
  Result := nil; // RTTI discovery only
end;

{ TKToolViewItem }

function TKToolViewItem.GetDisplayLabel: string;
begin
  Result := GetString('DisplayLabel');
end;

function TKToolViewItem.GetHint: string;
begin
  Result := GetString('Hint');
end;

function TKToolViewItem.GetImageName: string;
begin
  Result := GetString('ImageName');
end;

function TKToolViewItem.GetControllerType: string;
begin
  Result := GetString('Controller');
end;

function TKToolViewItem.GetRequireSelection: Boolean;
begin
  Result := GetBoolean('RequireSelection', False);
end;

function TKToolViewItem.GetAutoRefresh: string;
begin
  Result := GetString('AutoRefresh', 'All');
end;

function TKToolViewItem.GetConfirmationMessage: string;
begin
  Result := GetString('ConfirmationMessage');
end;

{ TKViewTableControllerConfig }

function TKViewTableControllerConfig.GetAutoOpen: Boolean;
begin
  Result := GetBoolean('AutoOpen', False);
end;

function TKViewTableControllerConfig.GetWidth: Integer;
begin
  Result := GetInteger('Width', 0);
end;

function TKViewTableControllerConfig.GetHeight: Integer;
begin
  Result := GetInteger('Height', 0);
end;

function TKViewTableControllerConfig.GetIsMultiSelect: Boolean;
begin
  Result := GetBoolean('IsMultiSelect', False);
end;

function TKViewTableControllerConfig.GetPageRecordCount: Integer;
begin
  Result := GetInteger('PageRecordCount');
end;

function TKViewTableControllerConfig.GetPagingTools: Boolean;
begin
  Result := GetBoolean('PagingTools', True);
end;

function TKViewTableControllerConfig.GetRowClassProvider: string;
begin
  Result := GetString('RowClassProvider');
end;

function TKViewTableControllerConfig.GetAllowViewing: Boolean;
begin
  Result := GetBoolean('AllowViewing', False);
end;

function TKViewTableControllerConfig.GetPreventEditing: Boolean;
begin
  Result := GetBoolean('PreventEditing', False);
end;

function TKViewTableControllerConfig.GetPreventAdding: Boolean;
begin
  Result := GetBoolean('PreventAdding', False);
end;

function TKViewTableControllerConfig.GetPreventDeleting: Boolean;
begin
  Result := GetBoolean('PreventDeleting', False);
end;

function TKViewTableControllerConfig.GetAllowDuplicating: Boolean;
begin
  Result := GetBoolean('AllowDuplicating', False);
end;

function TKViewTableControllerConfig.GetToolViews: TKToolViewsConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKViewTableControllerConfig.GetPopupWindow: TKPopupWindowConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKViewTableControllerConfig.GetGrouping: TKGroupingConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKViewTableControllerConfig.GetFormController: TKFormControllerConfig;
begin
  Result := nil; // RTTI discovery only
end;

function TKViewTableControllerConfig.GetForm: string;
begin
  // RTTI carrier only: the form layout is read via FindLayout('Form') at render
  // time (Controller/Form/Layout), not through this accessor.
  Result := '';
end;

function TKViewTableControllerConfig.GetGrid: string;
begin
  // RTTI carrier only: the grid layout is read via FindLayout('Grid').
  Result := '';
end;

function TKViewTableControllerConfig.GetDefaultAction: string;
begin
  Result := GetString('DefaultAction');
end;

function TKViewTableControllerConfig.GetAllowInsert: Boolean;
begin
  Result := GetBoolean('AllowInsert', True);
end;

function TKViewTableControllerConfig.GetAllowEdit: Boolean;
begin
  Result := GetBoolean('AllowEdit', True);
end;

function TKViewTableControllerConfig.GetAllowDelete: Boolean;
begin
  Result := GetBoolean('AllowDelete', True);
end;

function TKViewTableControllerConfig.GetAdd: string;
begin
  // RTTI carrier only: the Add action-options block is read node by node.
  Result := '';
end;

function TKViewTableControllerConfig.GetFilters: TKFilterPanelConfig;
begin
  Result := nil; // RTTI discovery only
end;

{ TKFilterItemFreeSearch }

function TKFilterItemFreeSearch.GetDefaultValue: string;
begin
  Result := GetString('DefaultValue');
end;

function TKFilterItemFreeSearch.GetExpressionTemplate: string;
begin
  Result := GetString('ExpressionTemplate');
end;

function TKFilterItemFreeSearch.GetWidth: Integer;
begin
  Result := GetInteger('Width', 10);
end;

function TKFilterItemFreeSearch.GetAutoSearchAfterChars: Integer;
begin
  Result := GetInteger('AutoSearchAfterChars', 0);
end;

function TKFilterItemFreeSearch.GetIsRequired: Boolean;
begin
  Result := GetBoolean('IsRequired', False);
end;

{ TKFilterItemDynaList }

function TKFilterItemDynaList.GetExpressionTemplate: string;
begin
  Result := GetString('ExpressionTemplate');
end;

function TKFilterItemDynaList.GetCommandText: string;
begin
  Result := GetString('CommandText');
end;

function TKFilterItemDynaList.GetQueryTemplate: string;
begin
  Result := GetString('QueryTemplate');
end;

function TKFilterItemDynaList.GetDefaultValueExpression: string;
begin
  Result := GetString('DefaultValueExpression');
end;

function TKFilterItemDynaList.GetWidth: Integer;
begin
  Result := GetInteger('Width', 20);
end;

function TKFilterItemDynaList.GetListWidth: Integer;
begin
  Result := GetInteger('ListWidth', 20);
end;

function TKFilterItemDynaList.GetAutoCompleteMinChars: Integer;
begin
  Result := GetInteger('AutoCompleteMinChars', 0);
end;

{ TKFilterItemDateSearch }

function TKFilterItemDateSearch.GetDefaultValue: string;
begin
  Result := GetString('DefaultValue');
end;

function TKFilterItemDateSearch.GetExpressionTemplate: string;
begin
  Result := GetString('ExpressionTemplate');
end;

function TKFilterItemDateSearch.GetWidth: Integer;
begin
  Result := GetInteger('Width', 10);
end;

function TKFilterItemDateSearch.GetLabelWidth: Integer;
begin
  Result := GetInteger('LabelWidth', 0);
end;

{ TKFilterItemList }

function TKFilterItemList.GetWidth: Integer;
begin
  Result := GetInteger('Width', 20);
end;

function TKFilterItemList.GetListWidth: Integer;
begin
  Result := GetInteger('ListWidth', 20);
end;

function TKFilterItemList.GetAutoCompleteMinChars: Integer;
begin
  Result := GetInteger('AutoCompleteMinChars', 0);
end;

function TKFilterItemList.GetItems: string;
begin
  // RTTI carrier only: the option entries are read node by node at filter-build
  // time (each entry's label is its value, with an Expression child).
  Result := '';
end;

{ TKFilterItemApplyButton }

function TKFilterItemApplyButton.GetImageName: string;
begin
  Result := GetString('ImageName', 'Find');
end;

{ TKFilterItemColumnBreak }

function TKFilterItemColumnBreak.GetLabelWidth: Integer;
begin
  Result := GetInteger('LabelWidth', 50);
end;

{ TKFilterItemSpacer }

function TKFilterItemSpacer.GetWidth: Integer;
begin
  Result := GetInteger('Width', 1);
end;

{ TKFilterPanelConfig }

function TKFilterPanelConfig.GetDisplayLabel: string;
begin
  Result := GetString('DisplayLabel', 'Filters');
end;

function TKFilterPanelConfig.GetLabelWidth: Integer;
begin
  Result := GetInteger('LabelWidth', 80);
end;

function TKFilterPanelConfig.GetConnector: string;
begin
  Result := GetString('Connector', 'and');
end;

function TKFilterPanelConfig.GetCollapsed: Boolean;
begin
  Result := GetBoolean('Collapsed', False);
end;

function TKFilterPanelConfig.GetCollapsible: Boolean;
begin
  Result := GetBoolean('Collapsible', True);
end;

function TKFilterPanelConfig.GetColumnWidth: Integer;
begin
  Result := GetInteger('ColumnWidth', 50);
end;

function TKFilterPanelConfig.GetLabelAlign: string;
begin
  Result := GetString('LabelAlign', 'Top');
end;

function TKFilterPanelConfig.GetItems: TKFilterItemsConfig;
begin
  Result := nil; // RTTI discovery only
end;

initialization
  TKViewRegistry.Instance.RegisterClass(TKMetadata.SYS_PREFIX + 'Data', TKDataView);
  TEFDataTypeRegistry.Instance.RegisterClass(TKFileReferenceDataType.GetTypeName, TKFileReferenceDataType);
  TEFDataTypeRegistry.Instance.RegisterClass(TKHTMLMemoDataType.GetTypeName, TKHTMLMemoDataType);

finalization
  // For some reason, the unit defining TKViewRegistry is finalized before this one.
  // I need to avlid creating TKViewRegistry.Instance at this point.
  if TKViewRegistry.HasInstance then
    TKViewRegistry.Instance.UnregisterClass(TKMetadata.SYS_PREFIX + 'Data');
  TEFDataTypeRegistry.Instance.UnregisterClass(TKFileReferenceDataType.GetTypeName);
  TEFDataTypeRegistry.Instance.UnregisterClass(TKHTMLMemoDataType.GetTypeName);

end.
