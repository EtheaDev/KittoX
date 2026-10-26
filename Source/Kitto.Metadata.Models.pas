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
///  The model metadata layer. Defines data models (TKModel) mapped to database
///  tables, their fields (TKModelField), detail (master-detail) references,
///  validation rules, and the catalog (TKModels) and registry that manage them.
///  Models are the source of truth for structure and defaults that views build
///  upon.
/// </summary>
unit Kitto.Metadata.Models;

{$I Kitto.Defines.inc}

interface

uses
  System.Types,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Data.DB,
  EF.Classes,
  EF.Tree,
  EF.Types,
  EF.Intf,
  EF.YAML.Attributes,
  Kitto.Metadata.Types,
  Kitto.Metadata,
  Kitto.Metadata.SubNodes;

type
  /// <summary>
  ///  Data type of a reference (foreign-key) field. Its stored value is the
  ///  referenced model's key.
  /// </summary>
  TKReferenceDataType = class(TEFDataType)
  protected
    procedure InternalFieldValueToNode(const AField: TField; const ANode: TEFNode); override;
    procedure InternalYamlValueToNode(const AYamlValue: string; const ANode: TEFNode;
      const AFormatSettings: TFormatSettings); override;
  public
    /// <summary>Returns the type name under which this data type is registered ('Reference').</summary>
    class function GetTypeName: string; override;
    /// <summary>Default value of EmptyAsNull for reference fields.</summary>
    function GetDefaultEmptyAsNull: Boolean; override;
    /// <summary>Returns True: reference fields support the EmptyAsNull setting.</summary>
    function SupportsEmptyAsNull: Boolean; override;
  end;

  TKModel = class;

  /// <summary>A single validation/business rule attached to a model or field.</summary>
  TKRule = class(TKMetadataItem)
  end;

  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  /// <summary>
  ///  Configuration for the SunEditor rich-text toolbar on HTMLMemo fields.
  ///  YAML path: Field/HTMLEditor
  /// </summary>
  /// <example>
  ///  HTMLEditor:
  ///    EnableFont: True
  ///    EnableFontSize: True
  ///    EnableFormat: True
  ///    EnableColors: True
  ///    EnableAlignments: True
  ///    EnableLinks: True
  ///    EnableLists: True
  ///    EnableSourceEdit: True
  /// </example>
  TKHTMLEditorConfig = class(TEFNode)
  private
    function GetEnableFont: Boolean;
    function GetEnableFontSize: Boolean;
    function GetEnableFormat: Boolean;
    function GetEnableColors: Boolean;
    function GetEnableAlignments: Boolean;
    function GetEnableLinks: Boolean;
    function GetEnableLists: Boolean;
    function GetEnableSourceEdit: Boolean;
  public
    [YamlNode('EnableFont', 'True', 'Show font family selector in toolbar')]
    property EnableFont: Boolean read GetEnableFont;

    [YamlNode('EnableFontSize', 'True', 'Show font size selector in toolbar')]
    property EnableFontSize: Boolean read GetEnableFontSize;

    [YamlNode('EnableFormat', 'True', 'Show bold/italic/underline/strike buttons')]
    property EnableFormat: Boolean read GetEnableFormat;

    [YamlNode('EnableColors', 'True', 'Show font color and highlight color pickers')]
    property EnableColors: Boolean read GetEnableColors;

    [YamlNode('EnableAlignments', 'True', 'Show text alignment buttons')]
    property EnableAlignments: Boolean read GetEnableAlignments;

    [YamlNode('EnableLinks', 'True', 'Show insert/edit hyperlink button')]
    property EnableLinks: Boolean read GetEnableLinks;

    [YamlNode('EnableLists', 'True', 'Show bulleted and numbered list buttons')]
    property EnableLists: Boolean read GetEnableLists;

    [YamlNode('EnableSourceEdit', 'True', 'Show view/edit HTML source button')]
    property EnableSourceEdit: Boolean read GetEnableSourceEdit;
  end;

  /// <summary>
  ///  Thumbnail dimensions for IsPicture blob fields.
  ///  YAML path: Field/IsPicture/Thumbnail
  /// </summary>
  /// <example>
  ///  IsPicture: True
  ///    Thumbnail:
  ///      Width: 150
  ///      Height: 150
  /// </example>
  TKThumbnailConfig = class(TEFNode)
  private
    function GetWidth: Integer;
    function GetHeight: Integer;
  public
    [YamlNode('Width', '150', 'Thumbnail width in pixels')]
    property Width: Integer read GetWidth;

    [YamlNode('Height', '150', 'Thumbnail height in pixels')]
    property Height: Integer read GetHeight;
  end;

  /// <summary>
  ///  Preview window dimensions for FileReference fields.
  ///  YAML path: Field/PreviewWindow
  /// </summary>
  /// <example>
  ///  PreviewWindow: True
  ///    Width: 226
  ///    Height: 320
  /// </example>
  TKPreviewWindowConfig = class(TEFNode)
  private
    function GetWidth: Integer;
    function GetHeight: Integer;
  public
    [YamlNode('Width', '226', 'Preview window width in pixels')]
    property Width: Integer read GetWidth;

    [YamlNode('Height', '320', 'Preview window height in pixels')]
    property Height: Integer read GetHeight;
  end;

  /// <summary>The collection of validation/business rules of a model or field.</summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  [YamlChildType('ForceUpperCase', '', 'Force value to upper case')]
  [YamlChildType('SubType', 'alpha_space', 'Field sub-type constraint')]
  [YamlChildType('MinLength', '', 'Minimum string length')]
  [YamlChildType('MaxLength', '', 'Maximum string length')]
  [YamlChildType('MaxUploadSize', '', 'Maximum upload file size')]
  [YamlChildType('DefaultFileName', '', 'Default file name for upload')]
  [YamlChildType('MinValue', '', 'Minimum numeric value')]
  [YamlChildType('MaxValue', '', 'Maximum numeric value')]
  [YamlChildType('ForceCamelCaps', '', 'Force CamelCaps formatting')]
  [YamlChildType('EnforceRange', '', 'Enforce numeric range')]
  [YamlChildType('Template', '', 'Regex or template validation')]
  [YamlChildType('CharFilter', '', 'Allowed characters filter')]
  [YamlChildType('ForceCase', '', 'Force value to specified case')]
  TKRules = class(TKMetadataItem)
  private
    function GetRule(const AIndex: Integer): TKRule;
    function GetRuleCount: Integer;
  protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
  public
    /// <summary>Number of rules in the collection.</summary>
    property RuleCount: Integer read GetRuleCount;
    /// <summary>The rules, by index (default property).</summary>
    property Rules[const AIndex: Integer]: TKRule read GetRule; default;

    /// <summary>
    ///  Returns True if there's a rule of the same type as the passed one.
    /// </summary>
    function HasRule(const ARule: TKRule): Boolean;
  end;

  TKModelFields = class;

  TKModelField = class;

  /// <summary>Predicate used to find a model field by a custom condition.</summary>
  TKModelFieldPredicate = reference to function(const AField: TKModelField): Boolean;

  /// <summary>An array of model fields.</summary>
  TKModelFieldArray = TArray<TKModelField>;

  /// <summary>A (field, foreign-field-name) pair constraining a reference lookup.</summary>
  TKFilterByField = TPair<TKModelField, string>;

  /// <summary>
  ///  A field of a model: maps to a database column (or is computed by an
  ///  expression) and carries the metadata (type, size, labels, default value,
  ///  visibility, rules, reference target, etc.) that views inherit from.
  ///  Reference fields can contain sub-fields making up the foreign key.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKModelField = class(TKMetadataItem)
  strict private
    function GetFieldName: string;
    function GetSize: Integer;
    function GetIsRequired: Boolean;
    function GetQualifiedDBColumnName: string;
    function GetModel: TKModel;
    function GetDisplayLabel: string;
    function GetDisplayLabel_Form: string;
    function GetDisplayLabel_Grid: string;
    function GetIsVisible: Boolean;
    function GetDisplayWidth: Integer;
    function GetIsComputed: Boolean;
    function GetIsReadOnly: Boolean;
    function GetIsKey: Boolean;
    function GetIsGenerated: Boolean;
    function GetIsPassword: Boolean;
    function GetIsPicture: Boolean;
    function GetDefaultValue: Variant;
    function GetDefaultDisplayWidth: Integer;
    function GetDefaultDisplayLabel: string;
    function GetDefaultEmptyAsNull: Boolean;
    function GetExpression: string;
    function GetAllowedValues: TEFPairs;
    function GetNotifyChange: Boolean;
    function GetColors: string;
    function GetAutoAddFields: string;
    function GetMaxUploadSize: string;
    function GetFilePath: string;
    function GetDisplayName: string;
    function GetContentType: string;
    function GetAcceptedWildCards: string;
    function GetLines: Integer;
    function GetEditLines: Integer;
    function GetUseSpeedButtons: Boolean;
    function GetFieldReadOnly: Boolean;
    function GetURL: string;
    function GetRules: TKRules;
    function GetDecimalPrecision: Integer;
    function GetCanUpdate: Boolean;
    function GetCanInsert: Boolean;
    function GetIsReference: Boolean;
    function GetReferencedModel: TKModel;
    function GetReferenceFieldNames: TStringDynArray;
    function GetReferencedModelName: string;
    function GetParentField: TKModelField;
    function GetField(I: Integer): TKModelField;
    function GetFieldCount: Integer;
    function GetHint: string;
    function GetEditFormat: string;
    function GetDisplayFormat: string;
    function GetQualifiedDBColumnNameOrExpression: string;
    function GetFieldNameOrExpression: string;
    function GetIsContained: Boolean;
    function GetDBColumnName: string;
    function GetPhysicalName: string;
    function GetAliasedDBColumnName: string;
    function GetFileNameField: string;
    function GetDefaultFilter: string;
    function GetDefaultFilterConnector: string;
    function GetDBColumnNameOrExpression: string;
    function GetAliasedDBColumnNameOrExpression: string;
    function GetDisplayTemplate: string;
    function GetBlankValue: Boolean;
    function GetAutoCompleteMinChars: Integer;
    function GetLookupFilter: string;
    function GetHTMLEditor: TKHTMLEditorConfig;
    function GetThumbnail: TKThumbnailConfig;
    function GetPreviewWindow: TKPreviewWindowConfig;
  strict protected
    class function BeautifyFieldName(const AFieldName: string): string; virtual;
    function GetChildClass(const AName: string): TEFNodeClass; override;
    /// <summary>Returns all main field properties at once.</summary>
    procedure GetFieldSpec(out ADataType: string; out ASize, ADecimalPrecision: Integer;
      out AIsRequired: Boolean; out AIsKey: Boolean; out AReferencedModel: string);
    function GetFields: TKModelFields;
    function GetDataType: TEFDataType; override;
  public
    /// <summary>Default value of AutoCompleteMinChars when not specified.</summary>
    const DEFAULT_AUTOCOMPLETEMINCHARS = 4;

    /// <summary>Returns the effective EmptyAsNull setting for this field.</summary>
    function GetEmptyAsNull: Boolean; override;
    /// <summary>Housekeeping performed before the field is saved to YAML.</summary>
    procedure BeforeSave; override;

    /// <summary>The access-control resource URI identifying this field.</summary>
    function GetResourceURI: string; override;

    /// <summary>The model this field belongs to.</summary>
    property Model: TKModel read GetModel;
    /// <summary>The field's logical name.</summary>
    property FieldName: string read GetFieldName;

    [YamlNode('PhysicalName', 'Physical DB column name (defaults to FieldName)')]
    property PhysicalName: string read GetPhysicalName;

    /// <summary>
    ///   Returns the PhysicalName or, if not specified, the
    ///   FieldName.
    /// </summary>
    property DBColumnName: string read GetDBColumnName;
    /// <summary>The DB column name, or the SQL expression for a computed field.</summary>
    property DBColumnNameOrExpression: string read GetDBColumnNameOrExpression;
    /// <summary>
    ///  Returns the physical column name (DBColumnName) plus, if the
    ///  field has a different logical name, a space and the logical name
    ///  (FieldName).
    /// </summary>
    property AliasedDBColumnName: string read GetAliasedDBColumnName;
    /// <summary>AliasedDBColumnName, or the SQL expression for a computed field.</summary>
    property AliasedDBColumnNameOrExpression: string read GetAliasedDBColumnNameOrExpression;
    /// <summary>The field name, or the SQL expression for a computed field.</summary>
    property FieldNameOrExpression: string read GetFieldNameOrExpression;
    /// <summary>The DB column name prefixed with the table name (table.column).</summary>
    property QualifiedDBColumnName: string read GetQualifiedDBColumnName;
    /// <summary>QualifiedDBColumnName, or the SQL expression for a computed field.</summary>
    property QualifiedDBColumnNameOrExpression: string read GetQualifiedDBColumnNameOrExpression;

    /// <summary>The field's data type.</summary>
    property DataType: TEFDataType read GetDataType;
    /// <summary>
    ///  Returns the DataType. For reference fields, returns the referenced
    ///  field's actual data type (recursively).
    /// </summary>
    function GetActualDataType: TEFDataType;
    /// <summary>The field size (e.g. string length); 0 when not applicable.</summary>
    property Size: Integer read GetSize;

    [YamlNode('DecimalPrecision', 'Number of decimal digits')]
    property DecimalPrecision: Integer read GetDecimalPrecision;

    [YamlNode('EditFormat', 'Input format mask for editing')]
    property EditFormat: string read GetEditFormat;

    [YamlNode('DisplayFormat', 'Display format for rendering values')]
    property DisplayFormat: string read GetDisplayFormat;

    /// <summary>
    ///   If the field is contained (as with local children of a
    ///   reference fields), returns the parent field, otherwise nil.
    /// </summary>
    property ParentField: TKModelField read GetParentField;
    /// <summary>Returns True if the field has a ParentField.</summary>
    property IsContained: Boolean read GetIsContained;
    /// <summary>True if the field is a reference.</summary>
    property IsReference: Boolean read GetIsReference;

    /// <summary>
    ///  Optional filter to use when creating select lists. Only applies to
    ///  reference fields.
    /// </summary>
    [YamlNode('DefaultFilter', 'SQL filter for reference selection lists')]
    property DefaultFilter: string read GetDefaultFilter;

    /// <summary>
    ///  Optional filter to use when creating lookup lists. Only applies to
    ///  reference fields.
    /// </summary>
    [YamlNode('LookupFilter', 'SQL filter for lookup combo queries')]
    property LookupFilter: string read GetLookupFilter;

    /// <summary>
    ///   Specifies the logical connector to use when appending the
    ///   DefaultFilter to an existing WHERE clause (for example, a referenced
    ///   model's own DefaultFilter). Defaults to 'and'; another common value
    ///   is 'or'.
    /// </summary>
    [YamlNode('DefaultFilterConnector', 'and', 'Logical connector (and/or) for DefaultFilter')]
    [YamlEnumType(TypeInfo(TKFilterConnector))]
    property DefaultFilterConnector: string read GetDefaultFilterConnector;

    /// <summary>If the field is part of a reference field, returns the number
    /// of physical fields that make up the reference.</summary>
    property FieldCount: Integer read GetFieldCount;
    /// <summary>
    ///  If the field is part of a reference field, returns the
    ///  physical fields that make up the reference.
    /// </summary>
    property Fields[I: Integer]: TKModelField read GetField;
    /// <summary>The sub-fields collection (the constituent fields of a reference
    /// field). Exposed for RTTI discovery of the YAML 'Fields' container.</summary>
    [YamlContainer('Fields', TKModelField, 'Constituent fields of a reference field')]
    property FieldList: TKModelFields read GetFields;

    /// <summary>Returns the sub-field with the given name; raises if absent.</summary>
    function FieldByName(const AName: string): TKModelField;
    /// <summary>Returns the sub-field with the given name, or nil.</summary>
    function FindField(const AName: string): TKModelField;
    /// <summary>Returns the sub-field with the given physical (DB) name, or nil.</summary>
    function FindFieldByPhysicalName(const APhysicalName: string): TKModelField;
    /// <summary>Returns the first sub-field satisfying APredicate, or nil.</summary>
    function FindFieldByPredicate(const APredicate: TKModelFieldPredicate): TKModelField;

    /// <summary>Returns the names of the sub-fields, if any.</summary>
    function GetFieldNames: TStringDynArray;
    /// <summary>Returns the DB names of the sub-fields, if any.</summary>
    function GetDBColumnNames: TStringDynArray;

    /// <summary>If the field is a reference, returns the referenced model's
    /// name, otherwise ''.</summary>
    property ReferencedModelName: string read GetReferencedModelName;
    /// <summary>If the field is a reference, returns the referenced model,
    /// otherwise nil.</summary>
    property ReferencedModel: TKModel read GetReferencedModel;
    /// <summary>If the field is a reference, returns the reference field names
    /// (that is the names of the fields, in the underlying table, that make up
    /// the foreign key to the referenced model).</summary>
    property ReferenceFieldNames: TStringDynArray read GetReferenceFieldNames;
    /// <summary>If the field is a reference, returns an array of its subfields
    /// (that is the fields, in the underlying table, that make up the foreign
    /// key to the referenced model).</summary>
    function GetReferenceFields: TKModelFieldArray;

    /// <summary>
    ///   Default requiredness status of this field in views. Defaults to
    ///   the database nullability status of the column.
    /// </summary>
    [YamlNode('IsRequired', 'Field is mandatory')]
    property IsRequired: Boolean read GetIsRequired;

    /// <summary>
    ///   Default visibility status of this field in views. Defaults to True.
    /// </summary>
    [YamlNode('IsVisible', 'True', 'Field visibility in views')]
    property IsVisible: Boolean read GetIsVisible;

    /// <summary>
    ///   Default read-only status of this field in views. Defaults to False.
    /// </summary>
    [YamlNode('IsReadOnly', 'False', 'Field is not editable')]
    property IsReadOnly: Boolean read GetIsReadOnly;

    /// <summary>
    ///   A field computed on server side. At client side is not editable. Defaults to False.
    /// </summary
    [YamlNode('IsComputed', 'False', 'Server-side computed field (not editable)')]
    property IsComputed: Boolean read GetIsComputed;

    /// <summary>
    ///   Returns True if the field is auto-generated at the database level,
    ///   such as an auto-increment field. Default is False.
    /// </summary>
    [YamlNode('IsGenerated', 'False', 'Auto-generated at DB level (e.g. auto-increment)')]
    property IsGenerated: Boolean read GetIsGenerated;

    [YamlNode('IsPassword', 'False', 'Mask input and enable hashed storage')]
    property IsPassword: Boolean read GetIsPassword;

    [YamlNode('IsPicture', 'False', 'Blob field contains image data')]
    property IsPicture: Boolean read GetIsPicture;

    /// <summary>A field that is not a physical field but rather computed by a
    /// SQL expression will have the expression stored in this
    /// property.</summary>
    [YamlNode('Expression', 'SQL expression for computed fields')]
    property Expression: string read GetExpression;

    /// <summary>Returns True if the field can be modified when inserting a new
    /// record. By default all fields for which CanActuallyModify returns True
    /// are editable, but you can makle a field non editable during insert by
    /// adding 'CanInsert: False' to its definition.</summary>
    /// <remarks>You can't make editable a field that is naturally non
    /// editable, such as an expression field.</remarks>
    [YamlNode('CanInsert', 'True', 'Field is editable when inserting a new record')]
    property CanInsert: Boolean read GetCanInsert;

    /// <summary>Returns True if the field can be modified when editing an
    /// existing record. By default all fields for which CanActuallyModify
    /// returns True are editable, but you can makle a field non editable
    /// during update by adding 'CanUpdate: False' to its definition.</summary>
    /// <remarks>You can't make editable a field that is naturally non
    /// editable, such as an expression field.</remarks>
    [YamlNode('CanUpdate', 'True', 'Field is editable when updating an existing record')]
    property CanUpdate: Boolean read GetCanUpdate;

    /// <summary>Returns True if a field is natually editable. All fields
    /// except expression fields are currently considered natually
    /// editable.</summary>
    function CanActuallyModify: Boolean;

    /// <summary>
    ///   Indicates that an empty value input by the user should be converted
    ///   to null when writing to the database. For string/date/time/datetime
    ///   fields defaults to True; for other data types defaults to False.
    /// </summary>
    /// <remarks>
    ///   Only relevant for string/date/time/datetime fields. In other cases,
    ///   empty values are always converted to null. If the field is not of one
    ///   of these types, this property always returns True.
    /// </remarks>
    /// <remarks>
    ///   If the field has a parent field, then the parent field's EmptyAsNull
    ///   is returned (IOW setting EmptyAsNull on fields that are part of
    ///   other fields, such as in multi-column reference fields, is
    ///   ineffective. You set it once for all in the parent field).
    /// </remarks>
    [YamlNode('EmptyAsNull', 'Convert empty input to NULL in the database')]
    property EmptyAsNull: Boolean read GetEmptyAsNull;

    /// <summary>If the field has a fixed list of allowed values, it is stored
    /// here. Each value has as an associated label.</summary>
    /// <remarks>Only string fields are currently supported.</remarks>
    [YamlNode('AllowedValues', 'Enumerated value:label pairs restricting this field (each child is <value>: <label>)')]
    property AllowedValues: TEFPairs read GetAllowedValues;

    /// <summary>When True, editing this field triggers the server-side change
    /// cascade (onchange notification). Read from the model field or overridden
    /// on the view field.</summary>
    [YamlNode('NotifyChange', 'False', 'Fire the server-side change cascade when this field is edited')]
    property NotifyChange: Boolean read GetNotifyChange;

    /// <summary>Conditional cell colouring: each child is <hex-color>: <regexp>;
    /// the value is coloured with the first colour whose regexp matches it.</summary>
    [YamlNode('Colors', 'Conditional colouring rules (each child is <hex-color>: <regexp matched against the value>)')]
    property Colors: string read GetColors;

    /// <summary>RTTI carrier for the AutoAddFields node: extra fields pulled in
    /// automatically when this reference field is selected. Read by path.</summary>
    [YamlNode('AutoAddFields', 'Extra fields auto-added when this reference field is chosen')]
    property AutoAddFields: string read GetAutoAddFields;

    [YamlNode('MaxUploadSize', 'Maximum upload size for this file/BLOB field (bytes, or with a unit e.g. 100KB)')]
    property MaxUploadSize: string read GetMaxUploadSize;

    // File/BLOB and rich-text field knobs.
    [YamlNode('Path', 'Server directory where this file field''s content is stored')]
    property FilePath: string read GetFilePath;
    [YamlNode('DisplayName', 'Alternative display name for this field')]
    property DisplayName: string read GetDisplayName;
    [YamlNode('ContentType', 'MIME content type for this file/BLOB field')]
    property ContentType: string read GetContentType;
    [YamlNode('AcceptedWildCards', 'Accepted file patterns for this upload field (space-separated wildcards)')]
    property AcceptedWildCards: string read GetAcceptedWildCards;
    [YamlNode('Lines', 'Number of visible lines for a memo field')]
    property Lines: Integer read GetLines;
    [YamlNode('EditLines', 'Number of visible lines for a memo field in edit mode')]
    property EditLines: Integer read GetEditLines;
    [YamlNode('UseSpeedButtons', 'False', 'Show speed buttons next to this field')]
    property UseSpeedButtons: Boolean read GetUseSpeedButtons;
    [YamlNode('ReadOnly', 'False', 'Field is read-only (legacy alias of IsReadOnly)')]
    property FieldReadOnly: Boolean read GetFieldReadOnly;
    [YamlNode('URL', 'URL associated with this field (e.g. for a hyperlink field)')]
    property URL: string read GetURL;

    /// <summary>
    ///   Default label for this field in views. Defaults to a beautified field
    ///   name. The beautifying function can be customized.
    /// </summary>
    [YamlNode('DisplayLabel', '', 'Label shown in forms and grids', True)]
    property DisplayLabel: string read GetDisplayLabel;

    /// <summary>
    ///   Default label for this field in Grid/List. If not present uses the
    ///   value of DisplayLabel.
    /// </summary>
    [YamlNode('DisplayLabel_Grid', '', 'Label override for grid columns', True)]
    property DisplayLabel_Grid: string read GetDisplayLabel_Grid;

    /// <summary>
    ///   Default label for this field in Form. If not present uses the
    ///   value of DisplayLabel.
    /// </summary>
    [YamlNode('DisplayLabel_Form', '', 'Label override for form fields', True)]
    property DisplayLabel_Form: string read GetDisplayLabel_Form;

    /// <summary>
    ///   Default label for this field into editing control when the value is missing
    /// </summary>
    [YamlNode('Hint', '', 'Placeholder text shown when field is empty', True)]
    property Hint: string read GetHint;

    /// <summary>
    ///   Default width for this field in views. Defaults to the field size for
    ///   string fields, and reasonable sizes for other field types.
    /// </summary>
    [YamlNode('DisplayWidth', 'Display width in characters')]
    property DisplayWidth: Integer read GetDisplayWidth;

    /// <summary>
    ///   A string format that will be used to render the field's value.
    ///  may include the {value} placeholder that will be replaced with the field's value
    ///  in read-only GUIs, and any {FieldName} placeholders for other fields' values.
    ///  A template of '{value}' acts the same as no template.
    /// </summary>
    [YamlNode('DisplayTemplate', 'Rendering template with {value} and {FieldName} placeholders')]
    property DisplayTemplate: string read GetDisplayTemplate;

    /// <summary>
    ///   Indicates to hide the field value when an image is displayed
    ///   (otherwise both image and value are shown).
    ///   If no image is displayed, this property is ignored.
    /// </summary>
    [YamlNode('BlankValue', 'False', 'Hide field value when an image is displayed')]
    property BlankValue: Boolean read GetBlankValue;

    /// <summary>
    ///   Indicates how many chars must be edited before the
    ///   search starts.
    ///   By default after 4 characters
    /// </summary>
    [YamlNode('AutoCompleteMinChars', '4', 'Minimum characters before autocomplete starts')]
    property AutoCompleteMinChars: Integer read GetAutoCompleteMinChars;

    /// <summary>
    ///   Optional value to set for the field when a new record is created.
    /// </summary>
    [YamlNode('DefaultValue', 'Value assigned when a new record is created')]
    property DefaultValue: Variant read GetDefaultValue;

    /// <summary>
    ///   Returns the default Display Width based on the DataType
    /// </summary>
    property DefaultDisplayWidth: Integer read GetDefaultDisplayWidth;

    /// <summary>
    ///   Returns the default Display label of the field as a
    ///   beautified value of FieldName
    /// </summary>
    property DefaultDisplayLabel: string read GetDefaultDisplayLabel;
    /// <summary>
    ///   Returns the default value form EmptyAsNull based on the DataType
    /// </summary>
    property DefaultEmptyAsNull: Boolean read GetDefaultEmptyAsNull;

    [YamlNode('IsKey', 'False', 'Field is part of the primary key')]
    property IsKey: Boolean read GetIsKey;

    [YamlContainer('Rules', TKRule, 'Business rules applied to this field')]
    property Rules: TKRules read GetRules;

    /// <summary>For blob or file reference fields, optionally specifies the
    /// name of another field in the same model that will store the
    /// original file name upon upload.</summary>
    [YamlNode('FileNameField', 'Name of companion field storing the uploaded file name')]
    property FileNameField: string read GetFileNameField;

    [YamlSubNode('HTMLEditor', TKHTMLEditorConfig, 'Rich-text editor toolbar options')]
    property HTMLEditor: TKHTMLEditorConfig read GetHTMLEditor;

    [YamlSubNode('IsPicture/Thumbnail', TKThumbnailConfig, 'Thumbnail dimensions for picture fields')]
    property Thumbnail: TKThumbnailConfig read GetThumbnail;

    [YamlSubNode('PreviewWindow', TKPreviewWindowConfig, 'File preview popup dimensions')]
    property PreviewWindow: TKPreviewWindowConfig read GetPreviewWindow;

    /// <summary>For a reference field with FilterBy nodes, returns the (field, foreign-field)
    /// pairs that constrain the lookup by the value of another field in the same model.</summary>
    function GetFilterByFields: TArray<TKFilterByField>;
  end;

  /// <summary>The collection of fields of a model (or the sub-fields of a
  /// reference field). The YAML child type of each entry selects the field's
  /// data type.</summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  [YamlChildType('StringField', 'String(10)', 'String field with max length')]
  [YamlChildType('IntegerField', 'Integer', 'Integer numeric field')]
  [YamlChildType('DateField', 'Date', 'Date field')]
  [YamlChildType('TimeField', 'Time', 'Time field')]
  [YamlChildType('DecimalField', 'Decimal', 'Decimal numeric field')]
  [YamlChildType('BlobField', 'Blob', 'Binary large object field')]
  [YamlChildType('FloatField', 'Float', 'Floating point field')]
  [YamlChildType('ReferenceField', 'Reference', 'Foreign key reference field')]
  [YamlChildType('BooleanField', 'Boolean', 'Boolean true/false field')]
  [YamlChildType('MemoField', 'Memo', 'Multi-line text field')]
  [YamlChildType('CurrencyField', 'Currency', 'Currency numeric field')]
  [YamlChildType('DateTimeField', 'DateTime', 'Date and time field')]
  [YamlChildType('ObjectField', 'Object', 'Nested object field')]
  [YamlChildType('FileReferenceField', 'FileReference', 'File reference field')]
  TKModelFields = class(TKMetadataItem)
  private
    function GetParentField: TKModelField;
    function GetField(I: Integer): TKModelField;
    function GetFieldCount: Integer;
  protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
  public
    /// <summary>Returns the field with the given name; raises if absent.</summary>
    function FieldByName(const AName: string): TKModelField;
    /// <summary>Returns the field with the given name, or nil.</summary>
    function FindField(const AName: string): TKModelField;
    /// <summary>Returns the field with the given physical (DB) name, or nil.</summary>
    function FindFieldByPhysicalName(const APhysicalName: string): TKModelField;
    /// <summary>Returns the first field satisfying APredicate, or nil.</summary>
    function FindFieldByPredicate(const APredicate: TKModelFieldPredicate): TKModelField;
    /// <summary>Number of fields.</summary>
    property FieldCount: Integer read GetFieldCount;
    /// <summary>The fields, by index (default property).</summary>
    property Fields[I: Integer]: TKModelField read GetField; default;
    /// <summary>Returns all field names, in order.</summary>
    function GetFieldNames: TStringDynArray;
    /// <summary>Returns all fields' DB column names, in order.</summary>
    function GetDBColumnNames: TStringDynArray;

    /// <summary>If the fields are contained inside a parent field, this
    /// property returns the parent field, otherwise nil.</summary>
    property ParentField: TKModelField read GetParentField;
  end;

  /// <summary>Base class for objects contained in a model (e.g. detail references).</summary>
  TKModelSubobject = class(TKMetadataItem)
  private
    function GetModel: TKModel;
  public
    /// <summary>The model this sub-object belongs to.</summary>
    property Model: TKModel read GetModel;
  end;

  /// <summary>
  ///  A master-detail reference from a model to a detail (child) model,
  ///  identifying the child model and the foreign-key field that links back to
  ///  this master model.
  /// </summary>
  /// <remarks>
  ///  The node's own value is the detail model's name:
  ///
  ///    DetailReferences:
  ///      Invitation: Invitation
  ///        CascadeDelete: True
  ///
  ///  Everything else is a child of it -- CascadeDelete above is a child of
  ///  Invitation, not a sibling. Written one level out it becomes a detail
  ///  reference of its own, named CascadeDelete, and is silently ignored as a
  ///  setting.
  ///
  ///  The nodes below carry [YamlNode] so KIDE and the MCP server know them.
  ///  TYamlAttributeReader reads the whole set at once and a class that
  ///  declares none is not checked at all (see KIDE.TreeValidator), so adding
  ///  one means declaring them all.
  /// </remarks>
  TKModelDetailReference = class(TKModelSubobject)
  strict private
    function GetDetailReferenceName: string;
    function GetReferenceField: TKModelField;
    function GetDetailModel: TKModel;
    function GetDetailModelName: string;
    function GetReferenceFieldName: string;
    function GetDisplayLabel: string;
    function GetDBForeignKeyName: string;
    function GetPhysicalName: string;
    function GetCascadeDelete: Boolean;
  strict protected
    class function BeautifyDetailName(const ADetailName: string): string; virtual;
  public
    /// <summary>The detail reference's physical (DB foreign-key) name.</summary>
    [YamlNode('PhysicalName', 'Physical DB foreign-key name of this relation')]
    property PhysicalName: string read GetPhysicalName;
    /// <summary>Returns PhysicalName.</summary>
    property DBForeignKeyName: string read GetDBForeignKeyName;
    /// <summary>Label shown for the detail table (defaults to a beautified name).</summary>
    [YamlNode('DisplayLabel', '', 'Label shown for the detail table (defaults to the detail model''s)', True)]
    property DisplayLabel: string read GetDisplayLabel;
    /// <summary>The detail reference's logical name.</summary>
    property DetailReferenceName: string read GetDetailReferenceName;
    /// <summary>The detail (child) model.</summary>
    property DetailModel: TKModel read GetDetailModel;
    /// <summary>Name of the detail (child) model.</summary>
    property DetailModelName: string read GetDetailModelName;

    /// <summary>Returns the counterpart reference field in the detail model.
    /// If there's only one reference field from the detail model to this
    /// master model, then it's assumed it is the one being looked for,
    /// otherwise its name is fetched from the ReferenceField parameter of the
    /// DetailReference.</summary>
    property ReferenceField: TKModelField read GetReferenceField;
    /// <summary>Name of the counterpart reference field in the detail model.</summary>
    [YamlNode('ReferenceField', '', 'Which reference of the detail model links back here, when it has more than one')]
    property ReferenceFieldName: string read GetReferenceFieldName;

    /// <summary>
    ///  Whether deleting a master deletes the rows of this detail along with
    ///  it. False unless the model says otherwise.
    /// </summary>
    /// <remarks>
    ///  Off by default on purpose: on by default would make one delete take an
    ///  unknown number of rows with it, in every application, without anyone
    ///  having asked. An application that wants it says so, per relation:
    ///
    ///    DetailReferences:
    ///      Invitation: Invitation
    ///        CascadeDelete: True
    ///
    ///  Where it is not said the delete is refused, with a message that names
    ///  the master and counts the rows holding it back instead of quoting a
    ///  constraint name at the user.
    /// </remarks>
    [YamlNode('CascadeDelete', 'False', 'Delete this detail''s rows along with the master')]
    property CascadeDelete: Boolean read GetCascadeDelete;
  end;

  /// <summary>The collection of master-detail references of a model.</summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  [YamlChildType('DetailTable', 'DetailTable', 'Detail table reference')]
  TKModelDetailReferences = class(TKMetadataItem)
  private
    function GetDetailReference(I: Integer): TKModelDetailReference;
    function GetDetailReferenceCount: Integer;
  protected
    function GetChildClass(const AName: string): TEFNodeClass; override;
  public
    /// <summary>The detail references, by index (default property).</summary>
    property DetailReferences[I: Integer]: TKModelDetailReference read GetDetailReference; default;
    /// <summary>Number of detail references.</summary>
    property DetailReferenceCount: Integer read GetDetailReferenceCount;
    /// <summary>Returns the detail reference with the given name; raises if absent.</summary>
    function DetailReferenceByName(const AName: string): TKModelDetailReference;
    /// <summary>Returns the detail reference with the given name, or nil.</summary>
    function FindDetailReference(const AName: string): TKModelDetailReference;
    /// <summary>Returns the detail reference pointing to the given model, or nil.</summary>
    function FindDetailReferenceToModel(const AModel: TKModel): TKModelDetailReference; overload;
    /// <summary>Returns the detail reference pointing to the named model, or nil.</summary>
    function FindDetailReferenceToModel(const AModelName: string): TKModelDetailReference; overload;
    /// <summary>Returns the detail reference whose FK is the given field, or nil.</summary>
    function FindDetailReferenceToField(const AField: TKModelField): TKModelDetailReference;
    /// <summary>Returns the detail reference with the given physical (FK) name, or nil.</summary>
    function FindDetailReferenceByPhysicalName(const APhysicalName: string): TKModelDetailReference;
  end;

  TKModels = class;

  /// <summary>
  ///  A data model: the metadata description of a database table (or view),
  ///  including its fields, primary key, detail references, rules, labels and
  ///  behavioral defaults. Provides the record I/O API (LoadRecords/SaveRecord)
  ///  that the default implementation carries out through SQL.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKModel = class(TKMetadata)
  strict private
    function GetFieldCount: Integer;
    function GetField(I: Integer): TKModelField;
    function GetModelName: string;
    function GetDefaultDisplayLabel: string;
    function GetDisplayLabel: string;
    function GetDefaultPluralDisplayLabel: string;
    function GetPluralDisplayLabel: string;
    function GetIsReadOnly: Boolean;
    function GetPreventAdding: Boolean;
    function GetPreventEditing: Boolean;
    function GetPreventDeleting: Boolean;
    function GetDefaultDefaultSorting: string;
    function GetDefaultSorting: string;
    function GetLookupSearchModel: string;
    function GetIsLarge: Boolean;
    function GetDefaultFilter: string;
    function GetRules: TKRules;
    function GetDetailReference(I: Integer): TKModelDetailReference;
    function GetDetailReferenceCount: Integer;
    const DEFAULT_IMAGE_NAME = 'default_model';
    function GetDefaultImageName: string;
    function GetImageName: string;
    function GetDefaultCaptionField: TKModelField;
    function GetCaptionField: TKModelField;
    function GetCaptionFieldName: string;
    function GetKeyField(I: Integer): TKModelField;
    function GetKeyFieldCount: Integer;
    function GetCatalog: TKModels;
    function GetDBTableName: string;
    function GetDefaultPhysicalName: string;
    function GetPhysicalName: string;
    function GetDatabaseName: string;
    function GetDefaultPluralModelName: string;
    function GetPluralModelName: string;
  strict protected
    function GetLookupSorting: string; protected
    function GetFields: TKModelFields;
    function GetChildClass(const AName: string): TEFNodeClass; override;
    function GetDetailReferences: TKModelDetailReferences;
    /// <summary>Builds the containers the accessors would otherwise create on
    /// first read, while the catalogue's load still holds its lock.</summary>
    procedure InternalAfterLoad; override;
    class function BeautifyModelName(const AModelName: string): string; virtual;
    class function GetClassNameForResourceURI: string; override;
  public
    /// <summary>Housekeeping performed before the model is saved to YAML
    /// (e.g. drops an empty DetailReferences node).</summary>
    procedure BeforeSave; override;
  public
    /// <summary>The models catalog this model belongs to.</summary>
    property Catalog: TKModels read GetCatalog;

    // ModelName is the model's identity and is ALWAYS the PersistentName (the
    // file name) — GetModelName never reads a 'ModelName' node. It is therefore
    // NOT required (and normally absent); an optional YamlNode only so a legacy
    // redundant 'ModelName:' line is still recognized rather than flagged.
    [YamlNode('ModelName', 'Model identifier (defaults to the file name; normally omitted)')]
    property ModelName: string read GetModelName;

    /// <summary>The default plural model name (the English plural of ModelName).</summary>
    property DefaultPluralModelName: string read GetDefaultPluralModelName;

    /// <summary>Plural form of ModelName. This is an identifier, not a caption:
    /// its only consumer is TKViewTableRecords.GetXMLTagName, which uses it as the
    /// name of the XML element wrapping a record set in TKRecords.GetAsXML (read by
    /// the XML export and FOP report tools). Do not localize it - the plural caption
    /// is PluralDisplayLabel.</summary>
    [YamlNode('PluralModelName', 'Plural form of model name')]
    property PluralModelName: string read GetPluralModelName;

    /// <summary>The default physical name (the ModelName) when PhysicalName is not set.</summary>
    property DefaultPhysicalName: string read GetDefaultPhysicalName;

    [YamlNode('PhysicalName', 'Physical DB table name (defaults to ModelName)')]
    property PhysicalName: string read GetPhysicalName;

    /// <summary>
    ///  Returns the physical database table name (PhysicalName
    ///  property) or, if not specified, the ModelName. It is the name to be
    ///  used to update the physical table.
    /// </summary>
    property DBTableName: string read GetDBTableName;

    [YamlNode('DisplayLabel', '', 'Label shown in the UI', True)]
    property DisplayLabel: string read GetDisplayLabel;
    /// <summary>The default display label (a beautified ModelName).</summary>
    property DefaultDisplayLabel: string read GetDefaultDisplayLabel;

    [YamlNode('PluralDisplayLabel', '', 'Plural label shown in the UI', True)]
    property PluralDisplayLabel: string read GetPluralDisplayLabel;
    /// <summary>The default plural display label (the English plural of DisplayLabel).</summary>
    property DefaultPluralDisplayLabel: string read GetDefaultPluralDisplayLabel;
    /// <summary>The default icon name when ImageName is not set.</summary>
    property DefaultImageName: string read GetDefaultImageName;

    [YamlNode('ImageName', 'Icon name for this model')]
    property ImageName: string read GetImageName;

    /// <summary>Number of first-level fields in the model.</summary>
    property FieldCount: Integer read GetFieldCount;
    /// <summary>The first-level fields, by index.</summary>
    property Fields[I: Integer]: TKModelField read GetField;
    /// <summary>The fields collection. Exposed (in addition to the indexed
    /// accessor) so the YAML 'Fields' container is discoverable via RTTI by the
    /// tree validator and the KIDE/MCP metadata tooling.</summary>
    [YamlContainer('Fields', TKModelField, 'The fields of this model')]
    property FieldList: TKModelFields read GetFields;
    /// <summary>Returns the field with the given name; raises if absent.</summary>
    function FieldByName(const AName: string): TKModelField;
    /// <summary>Returns the field with the given name, or nil.</summary>
    function FindField(const AName: string): TKModelField;
    /// <summary>Returns the field with the given physical (DB) name, or nil.</summary>
    function FindFieldByPhysicalName(const APhysicalName: string): TKModelField;
    /// <summary>
    ///  Calls AProc for all first-level fields in the model.
    /// </summary>
    procedure EnumFields(const AProc: TProc<TKModelField>);
    /// <summary>
    ///  Calls AProc for all first-level fields in the model except fields with
    ///  subfields (such as reference fields). In such cases, calls AProc for
    ///  each subfield and never for the parent field.
    /// </summary>
    procedure EnumPhysicalFields(const AProc: TProc<TKModelField>);

    /// <summary>
    ///  Returns an array of key field names. Throws an exception if no
    ///  primary key is defined.
    /// </summary>
    function GetKeyFieldNames: TStringDynArray;
    /// <summary>Returns an array of key physical field names.</summary>
    /// <param name="AQualify">If True, each field name is prefixed with the
    /// table name and a dot.</param>
    /// <param name="AAlias">If True, makes it so that every field that has a
    /// different physical name is aliased (meaning the physical name is
    /// output, followed by a space and the FieldName).</param>
    function GetKeyDBColumnNames(const AQualify: Boolean = False;
      const AAlias: Boolean = False): TStringDynArray;
    /// <summary>Number of fields that make up the primary key.</summary>
    property KeyFieldCount: Integer read GetKeyFieldCount;
    /// <summary>The primary-key fields, by index.</summary>
    property KeyFields[I: Integer]: TKModelField read GetKeyField;

    /// <summary>Number of detail (master-detail) references.</summary>
    property DetailReferenceCount: Integer read GetDetailReferenceCount;
    /// <summary>The detail references, by index.</summary>
    property DetailReferences[I: Integer]: TKModelDetailReference read GetDetailReference;
    /// <summary>The detail references collection. Exposed (in addition to the
    /// indexed accessor) so the YAML 'DetailReferences' container is discoverable
    /// via RTTI by the tree validator and the KIDE/MCP metadata tooling.</summary>
    [YamlContainer('DetailReferences', TKModelDetailReference, 'Master-detail relationships navigated as detail grids')]
    property DetailReferenceList: TKModelDetailReferences read GetDetailReferences;
    /// <summary>Returns the detail reference with the given name; raises if absent.</summary>
    function DetailReferenceByName(const AName: string): TKModelDetailReference;
    /// <summary>Returns the default caption field (heuristic), or nil.</summary>
    function FindDefaultCaptionField: TKModelField;
    /// <summary>Returns the caption field (CaptionField node, else default), or nil.</summary>
    function FindCaptionField: TKModelField;
    /// <summary>Returns the detail reference with the given name, or nil.</summary>
    function FindDetailReference(const AName: string): TKModelDetailReference;
    /// <summary>Returns the detail reference with the given physical (FK) name, or nil.</summary>
    function FindDetailReferenceByPhysicalName(const APhysicalName: string): TKModelDetailReference;

    /// <summary>If there's exactly one detail reference to the specified
    /// model, returns it, otherwise returns nil.</summary>
    function FindDetailReferenceByModel(const AModel: TKModel): TKModelDetailReference;

    /// <summary>If there's exactly one detail reference to the model with the
    /// specified name, returns it, otherwise returns nil.</summary>
    function FindDetailReferenceByModelName(const AModelName: string): TKModelDetailReference;

    /// <summary>Returns the first found detail reference to the specified
    /// reference field. If not found, returns nil.</summary>
    function FindDetailReferenceByField(const AField: TKModelField): TKModelDetailReference;

    /// <summary>If there's exactly one field referencing the specified model,
    /// it is returned. Otherwise the method returns nil.</summary>
    function FindReferenceField(const AModel: TKModel): TKModelField; overload;

    /// <summary>Finds and returns a field referencing a model with the
    /// specified name and all subfields listed in the specified field name
    /// array (and only these), otherwise nil.</summary>
    /// <param name="AModelName">Name of the referenced model.</param>
    /// <param name="AFieldNames">Names of the referencing fields.</param>
    /// <remarks>If AFieldNames contains only one item, a same-named reference
    /// field with no subfields does qualify as a return value. If AFieldNames
    /// contains several items (indicating a multi-field reference) then the
    /// name of the field does not matter and only the subfields
    /// contribute.</remarks>
    function FindReferenceField(const AModelName: string;
      const AFieldNames: TStringDynArray): TKModelField; overload;

    /// <summary>If a reference field with a ForeignKeyName property equals to
    /// the specified name exists, it is returned. Otherwise nil is
    /// returned.</summary>
    /// <param name="AForeignKeyName">Name of the database-level foreign
    /// key.</param>
    /// <remarks>Not all reference fields have a ForeignKeyName set.</remarks>
    function FindReferenceField(const AForeignKeyName: string): TKModelField; overload;

    [YamlNode('IsReadOnly', 'False', 'Model data is read-only')]
    property IsReadOnly: Boolean read GetIsReadOnly;

    /// <summary>Model-level default that prevents adding records. The REST API
    /// honors it (POST -> 405); a view Controller/PreventAdding overrides it for
    /// the GUI only (view-if-specified else this model default).</summary>
    [YamlNode('PreventAdding', 'False', 'Prevent adding records (Model default; REST-enforced)')]
    property PreventAdding: Boolean read GetPreventAdding;
    /// <summary>Model-level default that prevents editing records. The REST API
    /// honors it (PUT/PATCH -> 405); a view Controller/PreventEditing overrides
    /// it for the GUI only.</summary>
    [YamlNode('PreventEditing', 'False', 'Prevent editing records (Model default; REST-enforced)')]
    property PreventEditing: Boolean read GetPreventEditing;
    /// <summary>Model-level default that prevents deleting records. The REST API
    /// honors it (DELETE -> 405); a view Controller/PreventDeleting overrides it
    /// for the GUI only.</summary>
    [YamlNode('PreventDeleting', 'False', 'Prevent deleting records (Model default; REST-enforced)')]
    property PreventDeleting: Boolean read GetPreventDeleting;

    [YamlNode('DefaultFilter', 'SQL WHERE clause applied by default')]
    property DefaultFilter: string read GetDefaultFilter;

    /// <summary>True if the model's underlying data store is a large one. Used
    /// to decide the kind of lookup combo box to create. Se this to True if
    /// the cardinality of the underlying database table exceeds what you are
    /// comfortable to put in an Ajax response (typically a few hundred records,
    /// depending on the number and size of columns).</summary>
    [YamlNode('IsLarge', 'False', 'Large dataset: use autocomplete instead of full combo')]
    property IsLarge: Boolean read GetIsLarge;

    /// <summary>
    ///  Optional fixed ORDER BY expression to apply when building the select
    ///  SQL statement to display data. Should refer to fields through
    ///  qualified names. Defaults to the list of fields in the key, if any.
    /// </summary>
    [YamlNode('DefaultSorting', 'Default ORDER BY expression (qualified field names)')]
    property DefaultSorting: string read GetDefaultSorting;

    [YamlNode('LookupSearchModel', 'Model used to resolve lookups/searches against this model')]
    property LookupSearchModel: string read GetLookupSearchModel;
    /// <summary>The fallback sort expression (the key fields) when DefaultSorting is not set.</summary>
    property DefaultDefaultSorting: string read GetDefaultDefaultSorting;

    /// <summary>
    ///  Optional fixed ORDER BY expression to apply when building the select
    ///  SQL statement for lookup. Should refer to fields through
    ///  qualified names. Defaults CaptionField.DBColumnNameOrExpression
    /// </summary>
    [YamlNode('LookupSorting', 'ORDER BY expression for lookup queries')]
    property LookupSorting: string read GetLookupSorting;

    [YamlNode('CaptionField', 'Field used as display caption for this model')]
    property CaptionFieldName: string read GetCaptionFieldName;
    /// <summary>The heuristic default caption field (first string key/field).</summary>
    property DefaultCaptionField: TKModelField read GetDefaultCaptionField;
    /// <summary>The field used as the model's display caption.</summary>
    property CaptionField: TKModelField read GetCaptionField;

    [YamlContainer('Rules', TKRule, 'Business rules applied to this model')]
    property Rules: TKRules read GetRules;

    [YamlNode('DatabaseName', 'Database connection name (from Config.yaml)')]
    property DatabaseName: string read GetDatabaseName;

    /// <summary>
    ///  Loads a set or a page of records into the specified store.
    /// </summary>
    /// <param name="AStore">
    ///  Instance of the store to populate. May be (will probably be) an
    ///  instance?of an inherited class.
    /// </param>
    /// <param name="AFilterExpression">
    ///  Optional filter expression. It is commonly a SQL predicate, but it
    ///  suffices that it is meaningful to the particular model class.
    /// </param>
    /// <param name="ASortExpression">
    ///  Optional?sort expression. It is commonly a SQL ORDER BY clause, but
    ///  it suffices that it is meaningful to the particular model class.
    /// </param>
    /// <param name="AStart">
    ///  Optional: First record to load. If both this argument and ALimit are
    ///  0, all records matching the filter are loaded, otherwise only a page
    ///  starting from this record and ALimit records long tops.
    /// </param>
    /// <param name="ALimit">
    ///  Maximum number of records to load. It is the page size. Pass 0 in
    ///  both this argument and AStart to load all records matching the filter.
    /// </param>
    /// <returns>
    ///  Count of actually loaded records.
    /// </returns>
    function LoadRecords(const AStore: TEFTree; const AFilterExpression: string;
      const ASortExpression: string; const AStart: Integer = 0;
      const ALimit: Integer = 0; const AForEachRecord: TProc<TEFNode> = nil): Integer; virtual;

    /// <summary>Persists all records in AStore (insert/update/delete per record state),
    /// optionally in a single transaction; calls AAfterPersist on success.</summary>
    procedure SaveRecords(const AStore: TEFTree; const APersist: Boolean;
      const AAfterPersist: TProc; const AUseTransaction: Boolean = True); virtual;

    /// <summary>
    ///  Saves the specified record.
    /// </summary>
    /// <param name="ARecord">
    ///  Instance of the record to save. May be (will probably be) an instance
    ///  of an inherited class.
    /// </param>
    /// <param name="APersist">
    ///  If True, the record is to be persisted to the underlying data store,
    ///  otherwise it should only be prepared now and persisted later (for
    ///  example, when saving a detail record this argument is False).
    /// </param>
    /// <param name="AAfterPersist">
    ///  A procedure to be called after successfully persisting the record. It
    ///  will only be called if APersist is True and the save goes well.
    /// </param>
    /// <remarks>
    ///  In case of errors, this method raises exceptions and does not call
    ///  AAfterPersist.
    /// </remarks>
    procedure SaveRecord(const ARecord: TEFNode; const APersist: Boolean;
      const AAfterPersist: TProc; const AUseTransaction: Boolean = True); virtual;

    /// <summary>
    ///  Called when a new record is being created in the GUI, after applying
    ///  any default or cloned values but before applying new record rules.
    /// </summary>
    /// <param name="ARecord">
    ///  Instance of the record just created. May be (will probably be) an instance
    ///  of an inherited class.
    /// </param>
    /// <param name="AIsCloned">
    ///  If True, the record was created as a result of a clone operation, which
    ///  means it should contain values; otherwise it is empty except for the
    ///  default values.
    /// </param>
    procedure BeforeNewRecord(const ARecord: TEFNode; const AIsCloned: Boolean); virtual;
    /// <summary>
    ///  Called when a new record has been created in the GUI, after applying
    ///  any default or cloned values and new record rules.
    /// </summary>
    /// <param name="ARecord">
    ///  Instance of the record just created. May be (will probably be) an instance
    ///  of an inherited class.
    /// </param>
    procedure AfterNewRecord(const ARecord: TEFNode); virtual;
  end;

  /// <summary>Metaclass reference for TKModel and its descendants.</summary>
  TKModelClass = class of TKModel;

  /// <summary>A simple list of models.</summary>
  TKModelList = class(TList<TKModel>)
  public
    /// <summary>Adds the name of each model in the list to AStrings.</summary>
    procedure AddModelNamesToStrings(const AStrings: TStrings);
  end;

  TKModelRegistry = class;

  /// <summary>The catalog of all models, loaded from the Models/ directory.</summary>
  TKModels = class(TKMetadataCatalog)
  strict private
    class var FDefaultModelClassType: TKModelClass;
    function GetModelCount: Integer;
    function GetModel(I: Integer): TKModel;
  strict protected
    function GetObjectClassType: TKMetadataClass; override;
    function GetMetadataRegistry: TKMetadataRegistry; override;
    function GetModelRegistry: TKModelRegistry;
  public
    class constructor Create;
  public
    /// <summary>The class used to instantiate models (override to use a descendant).</summary>
    class property DefaultModelClassType: TKModelClass read FDefaultModelClassType write FDefaultModelClassType;
    /// <summary>Resets DefaultModelClassType to the framework default (TKModel).</summary>
    class procedure ResetDefaultModelClassType;

    /// <summary>Number of models in the catalog.</summary>
    property ModelCount: Integer read GetModelCount;
    /// <summary>The models, by index (default property).</summary>
    property Models[I: Integer]: TKModel read GetModel; default;
    /// <summary>Returns the model with the given name; raises if absent.</summary>
    function ModelByName(const AName: string): TKModel;
    /// <summary>Returns the model with the given name, or nil.</summary>
    function FindModel(const AName: string): TKModel;

    /// <summary>Returns the model referenced by the given node; raises if absent.</summary>
    function ModelByNode(const ANode: TEFNode): TKModel;
    /// <summary>Returns the model referenced by the given node, or nil.</summary>
    function FindModelByNode(const ANode: TEFNode): TKModel;

    /// <summary>
    ///  Returns a reference to the first found model with the
    ///  specified physical name. If a model has no custom physical name
    ///  specified, the (case insensitive) match is done on its name
    ///  instead.
    /// </summary>
    function FindModelByPhysicalName(const APhysicalName: string): TKModel;

    /// <summary>
    ///  Reads the Models/ directory from disk and fills AList with all
    ///  models found. AList is cleared first. If the catalog is not yet
    ///  open it calls Open; if already open it calls Refresh, so each
    ///  call reflects the current on-disk state.
    /// </summary>
    procedure GetModelList(const AList: TKModelList);
  end;

  /// <summary>Singleton registry mapping type ids to model classes.</summary>
  TKModelRegistry = class(TKMetadataRegistry)
  strict private
    class var FInstance: TKModelRegistry;
    class function GetInstance: TKModelRegistry; static;
  strict protected
    procedure BeforeRegisterClass(const AId: string; const AClass: TClass); override;
    class destructor Destroy;
  public
    /// <summary>The singleton model-class registry.</summary>
    class property Instance: TKModelRegistry read GetInstance;
    /// <summary>Returns the registered model class for the given id(s).</summary>
    function GetClass(const AId1, AId2: string): TKModelClass;
  end;

/// <summary>Returns the input value unless it's a supported literal, in which
/// case evaluates the literal and returns it. Used by model and view fields to
/// compute default values.</summary>
function EvalExpression(const AExpression: Variant): Variant;

/// <summary>Returns the English plural of AName (used to derive PluralModelName).</summary>
function Pluralize(const AName: string): string;

implementation

uses
  System.StrUtils,
  System.Variants,
  System.Character,
  EF.StrUtils,
  EF.VariantUtils,
  EF.Localization,
  Kitto.Types,
  Kitto.Config,
  Kitto.DatabaseRouter;

function DefaultBeautifyName(const AName: string): string;
begin
  Result := AName;
  if ContainsStr(Result, '_') or (Result = UpperCase(Result)) then
    // Assume it's upper case with underscores.
    Result := Camelize(UpperUnderscoreToSpaced(Result))
  else
    // Assume it's camel.
    Result := CamelToSpaced(Result);
end;

function Pluralize(const AName: string): string;
begin
  Result := StripPrefixAndSuffix(AName, '_(' , ')');
  if Result  <> '' then
  begin
    if EndsText('y', Result) then
      Result := StripSuffix(Result, 'y') + 'ies'
    else if not EndsText('s', Result) then
      Result := Result + 's';
  end;
  if UpperCase(AName) = AName then
    Result := UpperCase(Result);
end;

function EvalExpression(const AExpression: Variant): Variant;
begin
  Result := AExpression;
  if SameText(EFVarToStr(Result), '{date}') then
    Result := Date
  else if SameText(EFVarToStr(Result), '{time}') then
    Result := Time
  else if SameText(EFVarToStr(Result), '{datetime}') or SameText(EFVarToStr(Result), '{now}') then
    Result := Now;
end;

{ TKModel }

procedure TKModel.BeforeNewRecord(const ARecord: TEFNode; const AIsCloned: Boolean);
begin
end;

procedure TKModel.InternalAfterLoad;

  // Reading FieldCount goes through GetFields, and Rules through GetRules:
  // evaluating them is the whole point, so they are handed to something that
  // does nothing with them rather than assigned to variables nobody reads.
  procedure Touch(const AContainer: TObject);
  begin
    Assert(Assigned(AContainer), 'Assigned(AContainer)');
  end;

  procedure PrepareField(const AField: TKModelField);
  var
    I: Integer;
  begin
    Touch(AField.Rules);
    // A field's own Fields are its parts, when it is a multi-part field.
    for I := 0 to AField.FieldCount - 1 do
      PrepareField(AField.Fields[I]);
  end;

var
  I: Integer;
begin
  inherited;

  // This object is cached by the catalogue and read by every request thread
  // from here on. TEFTree is not thread-safe, so anything that CREATES a node
  // has to happen now, while TKMetadataCatalog.LoadObject still holds its
  // lock: the accessors below build their container on first read, and two
  // threads reaching one of them at the same time on a shared model is a race
  // with nothing anywhere to protect it.
  Touch(GetRules);
  Touch(GetDetailReferences);
  Touch(GetFields);
  for I := 0 to FieldCount - 1 do
    PrepareField(Fields[I]);
end;

procedure TKModel.BeforeSave;
begin
  inherited;
  // Avoid storing the DetailReferences node if it's empty.
  if GetDetailReferences.DetailReferenceCount = 0 then
    DeleteNode('DetailReferences');
  // Same for Rules, which InternalAfterLoad creates even when there are none.
  if GetRules.RuleCount = 0 then
    DeleteNode('Rules');
end;

function TKModel.DetailReferenceByName(const AName: string): TKModelDetailReference;
begin
  Result := GetDetailReferences.DetailReferenceByName(AName);
end;

procedure TKModel.EnumFields(const AProc: TProc<TKModelField>);
var
  I: Integer;
begin
  if Assigned(AProc) then
    for I := 0 to FieldCount - 1 do
      AProc(Fields[I]);
end;

procedure TKModel.EnumPhysicalFields(const AProc: TProc<TKModelField>);
var
  I, J: Integer;
begin
  if Assigned(AProc) then
  begin
    for I := 0 to FieldCount - 1 do
    begin
      if Fields[I].FieldCount > 0 then
      begin
        for J := 0 to Fields[I].FieldCount - 1 do
          AProc(Fields[I].Fields[J]);
      end
      else
        AProc(Fields[I]);
    end;
  end;
end;

function TKModel.FieldByName(const AName: string): TKModelField;
begin
  Result := GetFields.FieldByName(AName);
end;

function TKModel.FindDetailReference(const AName: string): TKModelDetailReference;
begin
  Result := GetDetailReferences.FindDetailReference(AName);
end;

function TKModel.FindDetailReferenceByField(const AField: TKModelField): TKModelDetailReference;
begin
  Result := GetDetailReferences.FindDetailReferenceToField(AField);
end;

function TKModel.FindDetailReferenceByPhysicalName(
  const APhysicalName: string): TKModelDetailReference;
begin
  Result := GetDetailReferences.FindDetailReferenceByPhysicalName(APhysicalName);
end;

function TKModel.FindDetailReferenceByModel(const AModel: TKModel): TKModelDetailReference;
begin
  Result := GetDetailReferences.FindDetailReferenceToModel(AModel);
end;

function TKModel.FindDetailReferenceByModelName(
  const AModelName: string): TKModelDetailReference;
begin
  Result := GetDetailReferences.FindDetailReferenceToModel(AModelName);
end;

function TKModel.FindField(const AName: string): TKModelField;
begin
  Result := GetFields.FindField(AName);
end;

function TKModel.FindFieldByPhysicalName(const APhysicalName: string): TKModelField;
begin
  Result := GetFields.FindFieldByPhysicalName(APhysicalName);
end;

function TKModel.FindReferenceField(const AForeignKeyName: string): TKModelField;
var
  I: Integer;
begin
  Assert(AForeignKeyName <> '', 'AForeignKeyName <> ''''');

  Result := nil;
  for I := 0 to FieldCount - 1 do
  begin
    if Fields[I].IsReference and SameText(Fields[I].PhysicalName, AForeignKeyName) then
    begin
      Result := Fields[I];
      Break;
    end;
  end;
end;

function TKModel.FindReferenceField(const AModelName: string;
  const AFieldNames: TStringDynArray): TKModelField;
var
  LFieldIdx: Integer;
  LSubFieldIdx: Integer;
  LFound: Boolean;
begin
  Assert(AModelName <> '', 'AModelName <> ''''');
  Assert(Length(AFieldNames) > 0, 'Length(AFieldNames) > 0');

  Result := nil;
  for LFieldIdx := 0 to FieldCount - 1 do
  begin
    if Fields[LFieldIdx].IsReference and SameText(Fields[LFieldIdx].ReferencedModelName, AModelName) then
    begin
      if (Length(AFieldNames) = 1) and SameText(Fields[LFieldIdx].FieldName, AFieldNames[0]) then
      begin
        Result := Fields[LFieldIdx];
        Break;
      end
      else if (Length(AFieldNames) > 1) and (Length(AFieldNames) = Fields[LFieldIdx].FieldCount) then
      begin
        LFound := True;
        for LSubFieldIdx := Low(AFieldNames) to High(AFieldNames) do
        begin
          if Fields[LFieldIdx].FindField(AFieldNames[LSubFieldIdx]) = nil then
          begin
            LFound := False;
            Break;
          end;
        end;
        if LFound then
        begin
          Result := Fields[LFieldIdx];
          Break;
        end;
      end;
    end;
  end;
end;

function TKModel.FindCaptionField: TKModelField;
var
  LFieldName: string;
begin
  Result := nil;
  LFieldName := CaptionFieldName;
  if LFieldName <> '' then
    Result := FindField(LFieldName);
  // Find first visible non-key field.
  if Result = nil then
    Result := FindDefaultCaptionField;
end;

function TKModel.FindReferenceField(const AModel: TKModel): TKModelField;
var
  I: Integer;
  LCount: Integer;
begin
  Assert(Assigned(AModel), 'Assigned(AModel)');

  Result := nil;
  LCount := 0;
  for I := 0 to FieldCount - 1 do
  begin
    if Fields[I].IsReference and (Fields[I].ReferencedModel = AModel) then
    begin
      Result := Fields[I];
      Inc(LCount);
      if LCount > 1 then
        Break;
    end;
  end;
  if LCount <> 1 then
    Result := nil;
end;

function TKModel.GetField(I: Integer): TKModelField;
begin
  Result := GetFields[I] as TKModelField;
end;

function TKModel.GetFieldCount: Integer;
begin
  Result := GetFields.FieldCount;
end;

function TKModel.GetFields: TKModelFields;
begin
  Result := FindChild('Fields', True) as TKModelFields;
end;

function TKModel.GetRules: TKRules;
begin
  Result := GetNode('Rules', True) as TKRules;
end;

function TKModel.LoadRecords(const AStore: TEFTree; const AFilterExpression,
  ASortExpression: string; const AStart, ALimit: Integer;
  const AForEachRecord: TProc<TEFNode>): Integer;
begin
  //In descendant classes this method must be implemented
  Result := 0;
end;

procedure TKModel.SaveRecord(const ARecord: TEFNode; const APersist: Boolean;
  const AAfterPersist: TProc; const AUseTransaction: Boolean);
begin
  //In descendant classes this method must be implemented
  ;
end;

procedure TKModel.SaveRecords(const AStore: TEFTree; const APersist: Boolean;
  const AAfterPersist: TProc; const AUseTransaction: Boolean);
begin
  //In descendant classes this method must be implemented
  ;
end;

function TKModel.GetDefaultImageName: string;
begin
  Result := DEFAULT_IMAGE_NAME;
end;

function TKModel.GetImageName: string;
begin
  Result := GetString('ImageName');
  if Result = '' then
    Result := GetDefaultImageName;
end;

function TKModel.GetIsLarge: Boolean;
begin
  Result := GetBoolean('IsLarge');
end;

function TKModel.GetIsReadOnly: Boolean;
begin
  Result := GetBoolean('IsReadOnly');
end;

function TKModel.GetPreventAdding: Boolean;
begin
  Result := GetBoolean('PreventAdding');
end;

function TKModel.GetPreventEditing: Boolean;
begin
  Result := GetBoolean('PreventEditing');
end;

function TKModel.GetPreventDeleting: Boolean;
begin
  Result := GetBoolean('PreventDeleting');
end;

function TKModel.GetPhysicalName: string;
begin
  Result := GetString('PhysicalName');
end;

function TKModel.GetDefaultPluralDisplayLabel: string;
begin
  Result := Pluralize(DisplayLabel);
end;

function TKModel.GetPluralDisplayLabel: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('PluralDisplayLabel2')
  else
    Result := GetString('PluralDisplayLabel');
  if Result = '' then
    Result := GetDefaultPluralDisplayLabel;
end;

function TKModel.GetDefaultPluralModelName: string;
begin
  Result := Pluralize(ModelName);
end;

function TKModel.GetPluralModelName: string;
begin
  Result := GetString('PluralModelName');
  if Result = '' then
    Result := GetDefaultPluralModelName;
end;

function TKModel.GetKeyField(I: Integer): TKModelField;
var
  LKeyFieldNames: TStringDynArray;
begin
  LKeyFieldNames := GetKeyFieldNames;
  // Not an Assert. This index comes from the metadata, not from a contract
  // between callers: TKModelField.GetSize and GetDecimalPrecision pass the
  // position of a reference's subfield, and a reference that declares one
  // subfield more than the referenced model has key fields lands here. With
  // assertions compiled out, as they are in Release, the read went past the end
  // of the array and FieldByName then looked for whatever was in memory.
  //
  // Callers that index KeyFields[0] are covered too: a referenced model with no
  // primary key at all reaches this with an empty array, and one of them --
  // TKXFormPanelController building the WHERE clause that reads a reference's
  // caption -- is a live request path with no guard of its own.
  if (I < 0) or (I >= Length(LKeyFieldNames)) then
    raise EKError.CreateFmt(_('Model %s has %d key field(s), so there is no ' +
      'key field %d. A reference field pointing at this model has to declare ' +
      'exactly as many subfields as it has key fields, in the same order.'),
      [ModelName, Length(LKeyFieldNames), I]);
  Result := FieldByName(LKeyFieldNames[I]);
end;

function TKModel.GetKeyFieldCount: Integer;
begin
  Result := Length(GetKeyFieldNames);
end;

function TKModel.GetKeyFieldNames: TStringDynArray;
var
  I, J: Integer;

  procedure AppendToResult(const AField: TKModelField);
  var
    LLength: Integer;
  begin
    Assert(Assigned(AField), 'Assigned(AField)');

    if AField.IsKey then
    begin
      LLength := Length(Result) + 1;
      SetLength(Result, LLength);
      Result[LLength - 1] := AField.FieldName;
    end;
  end;

begin
  SetLength(Result, 0);
  for I := 0 to FieldCount - 1 do
  begin
    if Fields[I].IsReference then
    begin
      for J := 0 to Fields[I].FieldCount - 1 do
        AppendToResult(Fields[I].Fields[J]);
    end
    else
      AppendToResult(Fields[I]);
  end;
  if Length(Result) = 0 then
    raise Exception.CreateFmt(_('Model %s has no primary key.'), [ModelName]);
end;

function TKModel.GetKeyDBColumnNames(const AQualify: Boolean; const AAlias: Boolean): TStringDynArray;
var
  I, J: Integer;

  procedure AppendToResult(const AField: TKModelField);
  var
    LLength: Integer;
  begin
    Assert(Assigned(AField), 'Assigned(AField)');

    if AField.IsKey then
    begin
      LLength := Length(Result) + 1;
      SetLength(Result, LLength);
      if AQualify then
        Result[LLength - 1] := AField.QualifiedDBColumnName
      else
        Result[LLength - 1] := AField.DBColumnName;
      if AAlias and not SameText(AField.DBColumnName, AField.FieldName) then
        Result[LLength - 1] := Result[LLength - 1] + ' ' + AField.FieldName;
    end;
  end;

begin
  SetLength(Result, 0);
  for I := 0 to FieldCount - 1 do
  begin
    if Fields[I].IsReference then
    begin
      for J := 0 to Fields[I].FieldCount - 1 do
        AppendToResult(Fields[I].Fields[J]);
    end
    else
      AppendToResult(Fields[I]);
  end;
end;

function TKModel.GetModelName: string;
begin
  Result := PersistentName;
end;

function TKModel.FindDefaultCaptionField: TKModelField;
var
  I: Integer;
  LFirstVisibleField: TKModelField;
begin
  Result := nil;
  // Find first visible non-key and non-reference field
  LFirstVisibleField := nil;
  for I := 0 to FieldCount - 1 do
  begin
    if Fields[I].IsVisible and not Fields[i].IsReference then
    begin
      if not Assigned(LFirstVisibleField) then
        LFirstVisibleField := Fields[I];
      if not Fields[I].IsKey then
      begin
        Result := Fields[I];
        Break;
      end;
    end;
  end;
    if Result = nil then
      Result := LFirstVisibleField;
  if (Result = nil) and (FieldCount > 0) then
    Result := Fields[0];
end;

function TKModel.GetDefaultCaptionField: TKModelField;
begin
  Result := FindDefaultCaptionField;
end;

function TKModel.GetCaptionField: TKModelField;
begin
  Result := FindCaptionField;
  // Assertions are on in Release: a model with no field usable as a caption
  // (no CaptionField set, no visible non-key field) would have raised
  // EAssertionFailed with the useless text 'Result <> nil'. Name the model.
  if Result = nil then
    raise EKError.CreateFmt(_('Model %s has no field usable as a caption field.'), [ModelName]);
end;

function TKModel.GetCaptionFieldName: string;
begin
  Result := GetString('CaptionField');
end;

function TKModel.GetCatalog: TKModels;
begin
  Result := inherited Catalog as TKModels;
end;

function TKModel.GetChildClass(const AName: string): TEFNodeClass;
begin
  if SameText(AName, 'Fields') then
    Result := TKModelFields
  else if SameText(AName, 'DetailReferences') then
    Result := TKModelDetailReferences
  else if SameText(AName, 'Rules') then
    Result := TKRules
  else
    Result := inherited GetChildClass(AName);
end;

class function TKModel.GetClassNameForResourceURI: string;
begin
  // Avoid using any model implementation class name here.
  Result := 'Model';
end;

function TKModel.GetDefaultDefaultSorting: string;
begin
  Result := Join(GetKeyDBColumnNames(True), ', ');
end;

function TKModel.GetDefaultSorting: string;
begin
  Result := GetString('DefaultSorting');
  if Result = '' then
    Result := GetDefaultDefaultSorting;
end;

function TKModel.GetLookupSearchModel: string;
begin
  Result := GetString('LookupSearchModel');
end;

function TKModel.GetLookupSorting: string;
begin
  Result := GetString('LookupSorting');
  if Result = '' then
    Result := CaptionField.DBColumnNameOrExpression;
end;

function TKModel.GetDetailReference(I: Integer): TKModelDetailReference;
begin
  Result := GetDetailReferences[I];
end;

function TKModel.GetDetailReferenceCount: Integer;
begin
  Result := GetDetailReferences.DetailReferenceCount;
end;

function TKModel.GetDetailReferences: TKModelDetailReferences;
begin
  Result := FindChild('DetailReferences', True) as TKModelDetailReferences;
end;

function TKModel.GetDatabaseName: string;
var
  LDatabaseRouterNode: TEFNode;
begin
  LDatabaseRouterNode := FindNode('DatabaseRouter');
  if Assigned(LDatabaseRouterNode) then
    Result := TKDatabaseRouterFactory.Instance.GetDatabaseName(
      LDatabaseRouterNode.AsString, Self, LDatabaseRouterNode)
  else
    Result := TKConfig.Instance.DatabaseName;
end;

function TKModel.GetDefaultPhysicalName: string;
begin
  Result := ModelName;
end;

function TKModel.GetDBTableName: string;
begin
  Result := PhysicalName;
  if Result = '' then
    Result := GetDefaultPhysicalName;
end;

function TKModel.GetDefaultFilter: string;
begin
  Result := GetString('DefaultFilter');
end;

function TKModel.GetDefaultDisplayLabel: string;
begin
  Result := BeautifyModelName(ModelName);
end;

function TKModel.GetDisplayLabel: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('DisplayLabel2')
  else
    Result := GetString('DisplayLabel');
  if Result = '' then
    Result := GetDefaultDisplayLabel;
end;

procedure TKModel.AfterNewRecord(const ARecord: TEFNode);
begin
end;

class function TKModel.BeautifyModelName(const AModelName: string): string;
begin
  Result := DefaultBeautifyName(AModelName);
end;

{ TKModelField }

procedure TKModelField.GetFieldSpec(out ADataType: string; out ASize, ADecimalPrecision: Integer;
  out AIsRequired: Boolean; out AIsKey: Boolean; out AReferencedModel: string);
var
  LStrings: TStringDynArray;
  LDataType: TEFDataType;
  LStringValue: string;
begin
  // Calling AsString here would cause an infinite loop.
  LStringValue := EFVarToStr(Value);
  AIsRequired := ContainsText(LStringValue, ' not null');
  AIsKey := ContainsText(LStringValue, ' primary key');
  LStrings := Split(StripSuffix(StripSuffix(LStringValue, ' primary key'), ' not null'), '(,)');
  while (Length(LStrings) > 0) and (Trim(LStrings[High(LStrings)]) = '') do
    SetLength(LStrings, Length(LStrings) - 1);

  if Length(LStrings) > 0 then
    ADataType := LStrings[0]
  else
    ADataType := TEFStringDataType.GetTypeName;
  if Length(LStrings) > 1 then
  begin
    LDataType := TEFDataTypeFactory.Instance.GetDataType(ADataType);
    if LDataType is TKReferenceDataType then
    begin
      ASize := 0;
      ADecimalPrecision := -1;
      AReferencedModel := LStrings[1];
    end
    else
    begin
      // A malformed spec (e.g. String(abc)) used to surface as a bare
      // EConvertError 'abc is not a valid integer' with no clue which field or
      // model it came from. Name the field.
      if not TryStrToInt(Trim(LStrings[1]), ASize) then
        raise EKError.CreateFmt(_('Field %s: invalid size "%s" in its field spec.'),
          [FieldName, Trim(LStrings[1])]);
      if Length(LStrings) > 2 then
      begin
        if not TryStrToInt(Trim(LStrings[2]), ADecimalPrecision) then
          raise EKError.CreateFmt(_('Field %s: invalid decimal precision "%s" in its field spec.'),
            [FieldName, Trim(LStrings[2])]);
      end
      else
        ADecimalPrecision := 0;

      AReferencedModel := '';
    end;
  end
  else
  begin
    ASize := 0;
    ADecimalPrecision := 0;
    AReferencedModel := '';
  end;
end;

function TKModelField.GetFileNameField: string;
begin
  Result := GetString('FileNameField');
end;

function TKModelField.GetHTMLEditor: TKHTMLEditorConfig;
begin
  Result := FindNode('HTMLEditor') as TKHTMLEditorConfig;
end;

function TKModelField.GetThumbnail: TKThumbnailConfig;
var
  LPictureNode: TEFNode;
begin
  LPictureNode := FindNode('IsPicture');
  if Assigned(LPictureNode) then
    Result := LPictureNode.FindNode('Thumbnail') as TKThumbnailConfig
  else
    Result := nil;
end;

function TKModelField.GetPreviewWindow: TKPreviewWindowConfig;
begin
  Result := FindNode('PreviewWindow') as TKPreviewWindowConfig;
end;

function TKModelField.GetFilterByFields: TArray<TKFilterByField>;
var
  LNode: TEFNode;
  I: Integer;
begin
  SetLength(Result, 0);
  LNode := FindNode('FilterBy');
  if Assigned(LNode) then
  begin
    SetLength(Result, LNode.ChildCount);
    for I := Low(Result) to High(Result) do
    begin
      Result[I].Key := FieldByName(LNode.Children[I].Name);
      Result[I].Value := LNode.Children[I].AsString;
    end;
  end;
end;

function TKModelField.GetHint: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('Hint2')
  else
    Result := GetString('Hint');
end;

function TKModelField.GetIsContained: Boolean;
begin
  Result := ParentField <> nil;
end;

function TKModelField.GetIsGenerated: Boolean;
begin
  Result := GetBoolean('IsGenerated', False);
end;

function TKModelField.GetIsPassword: Boolean;
begin
  Result := GetBoolean('IsPassword', False);
end;

function TKModelField.GetIsPicture: Boolean;
begin
  Result := GetBoolean('IsPicture', False);
end;

function TKModelField.GetIsKey: Boolean;
var
  LDataType: string;
  LSize, LDecimalPrecision: Integer;
  LIsRequired: Boolean;
  LReferencedModel: string;
  LParentField: TKModelField;
begin
  LParentField := ParentField;
  if Assigned(LParentField) then
    Result := ParentField.IsKey
  else
    GetFieldSpec(LDataType, LSize, LDecimalPrecision, LIsRequired, Result, LReferencedModel);
end;

function TKModelField.GetIsComputed: Boolean;
begin
  Result := GetBoolean('IsComputed');
end;

function TKModelField.GetIsReadOnly: Boolean;
begin
  Result := GetBoolean('IsReadOnly', False);
end;

function TKModelField.GetIsReference: Boolean;
begin
  Result := DataType is TKReferenceDataType;
end;

function TKModelField.GetIsRequired: Boolean;
var
  LDataType: string;
  LSize, LDecimalPrecision: Integer;
  LIsKey: Boolean;
  LReferencedModel: string;
  LParentField: TKModelField;
begin
  LParentField := ParentField;
  if Assigned(LParentField) then
    Result := ParentField.IsRequired
  else
    GetFieldSpec(LDataType, LSize, LDecimalPrecision, Result, LIsKey, LReferencedModel);
end;

function TKModelField.GetIsVisible: Boolean;
begin
  Result := GetBoolean('IsVisible', True);
end;

function TKModelField.GetLookupFilter: string;
begin
  Result := GetString('LookupFilter');
end;

function TKModelField.GetQualifiedDBColumnName: string;
begin
  Result := Model.DBTableName + '.' + DBColumnName;
end;

function TKModelField.GetQualifiedDBColumnNameOrExpression: string;
begin
  if Expression <> '' then
    Result := Expression
  else
    Result := QualifiedDBColumnName;
end;

function TKModelField.GetReferencedModel: TKModel;
begin
  if IsReference then
    Result := Model.Catalog.ModelByName(ReferencedModelName)
  else
    Result := nil;
end;

function TKModelField.GetReferencedModelName: string;
var
  LDataType: string;
  LSize, LDecimalPrecision: Integer;
  LIsRequired: Boolean;
  LIsKey: Boolean;
  LParentField: TKModelField;
begin
  LParentField := ParentField;
  if Assigned(LParentField) and (LParentField.IsReference) then
    Result := ParentField.ReferencedModelName
  else
    GetFieldSpec(LDataType, LSize, LDecimalPrecision, LIsRequired, LIsKey, Result);
end;

function TKModelField.GetReferenceFieldNames: TStringDynArray;
begin
  if IsReference then
    Result := GetNode('Fields').GetChildNames
  else
    Result := nil;
end;

function TKModelField.GetReferenceFields: TKModelFieldArray;
begin
  if IsReference then
    Result := TKModelFieldArray(GetNode('Fields').ToArray)
  else
    Result := nil;
end;

function TKModelField.GetResourceURI: string;
begin
  Result := Model.GetResourceURI;
  if Result <> '' then
    Result := Result + '/' + FieldName;
end;

function TKModelField.GetRules: TKRules;
begin
  Result := GetNode('Rules', True) as TKRules;
end;

class function TKModelField.BeautifyFieldName(const AFieldName: string): string;
begin
  Result := DefaultBeautifyName(AFieldName);
end;

procedure TKModelField.BeforeSave;
begin
  inherited;
  // Avoid storing the Fields node if it's empty.
  if GetFields.FieldCount = 0 then
    DeleteNode('Fields');
  if Length(AllowedValues) = 0 then
    DeleteNode('AllowedValues');
  if GetRules.RuleCount = 0 then
    DeleteNode('Rules');
end;

function TKModelField.FieldByName(const AName: string): TKModelField;
begin
  Result := GetFields.FieldByName(AName);
end;

function TKModelField.FindField(const AName: string): TKModelField;
begin
  Result := GetFields.FindField(AName);
end;

function TKModelField.FindFieldByPhysicalName(
  const APhysicalName: string): TKModelField;
begin
  Result := GetFields.FindFieldByPhysicalName(APhysicalName);
end;

function TKModelField.FindFieldByPredicate(
  const APredicate: TKModelFieldPredicate): TKModelField;
begin
  Result := FindChildByPredicate(
    function (const ANode: TEFNode): Boolean
    begin
      Result := APredicate(ANode as TKModelField);
    end) as TKModelField;
end;

function TKModelField.GetActualDataType: TEFDataType;
begin
  Result := DataType;
  if (Result is TKReferenceDataType) then
  begin
    Assert(Assigned(ReferencedModel), 'Assigned(ReferencedModel)');
    // No assertion on the key field count: KeyFields reports a missing one
    // properly now, naming the model and how many it has.
    Result := ReferencedModel.KeyFields[0].GetActualDataType;
  end;
end;

function TKModelField.GetAliasedDBColumnName: string;
begin
  Result := DBColumnName;
  if not SameText(Result, FieldName) then
    Result := Result + ' ' + FieldName;
end;

function TKModelField.GetAliasedDBColumnNameOrExpression: string;
begin
  Result := DBColumnNameOrExpression;
  if not SameText(Result, FieldName) then
    Result := Result + ' ' + FieldName;
end;

function TKModelField.GetAllowedValues: TEFPairs;
begin
  Result := GetChildrenAsPairs('AllowedValues');
end;

function TKModelField.GetNotifyChange: Boolean;
begin
  Result := GetBoolean('NotifyChange', False);
end;

function TKModelField.GetColors: string;
begin
  // RTTI carrier only: the <hex-color>: <regexp> pairs are read as pairs
  // (GetChildrenAsPairs('Colors')) at render time, not through this accessor.
  Result := '';
end;

function TKModelField.GetAutoAddFields: string;
begin
  // RTTI carrier only: the field list is read via FindNode('AutoAddFields').
  Result := '';
end;

function TKModelField.GetMaxUploadSize: string;
begin
  // String (not integer): the value may carry a unit, e.g. "100KB".
  Result := GetString('MaxUploadSize');
end;

function TKModelField.GetFilePath: string;
begin
  Result := GetString('Path');
end;

function TKModelField.GetDisplayName: string;
begin
  Result := GetString('DisplayName');
end;

function TKModelField.GetContentType: string;
begin
  Result := GetString('ContentType');
end;

function TKModelField.GetAcceptedWildCards: string;
begin
  Result := GetString('AcceptedWildCards');
end;

function TKModelField.GetLines: Integer;
begin
  Result := GetInteger('Lines', 0);
end;

function TKModelField.GetEditLines: Integer;
begin
  Result := GetInteger('EditLines', 0);
end;

function TKModelField.GetUseSpeedButtons: Boolean;
begin
  Result := GetBoolean('UseSpeedButtons', False);
end;

function TKModelField.GetFieldReadOnly: Boolean;
begin
  Result := GetBoolean('ReadOnly', False);
end;

function TKModelField.GetURL: string;
begin
  Result := GetString('URL');
end;

function TKModelField.GetBlankValue: Boolean;
begin
  Result := GetBoolean('BlankValue');
end;

function TKModelField.GetAutoCompleteMinChars: Integer;
begin
  Result := GetInteger('AutoCompleteMinChars', DEFAULT_AUTOCOMPLETEMINCHARS);
end;

function TKModelField.CanActuallyModify: Boolean;
begin
  Result := (Expression = '') and not IsComputed and not IsGenerated;
end;

function TKModelField.GetCanUpdate: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('CanUpdate');
  if Assigned(LNode) then
    Result := LNode.AsBoolean and CanActuallyModify
  else
    Result := CanActuallyModify;
end;

function TKModelField.GetCanInsert: Boolean;
var
  LNode: TEFNode;
begin
  LNode := FindNode('CanInsert');
  if Assigned(LNode) then
    Result := LNode.AsBoolean and CanActuallyModify
  else
    Result := CanActuallyModify;
end;

function TKModelField.GetChildClass(const AName: string): TEFNodeClass;
begin
  if SameText(AName, 'Rules') then
    Result := TKRules
  else if SameText(AName, 'Fields') then
    Result := TKModelFields
  else if SameText(AName, 'HTMLEditor') then
    Result := TKHTMLEditorConfig
  else if SameText(AName, 'PreviewWindow') then
    Result := TKPreviewWindowConfig
  else
    Result := inherited GetChildClass(AName);
end;

function TKModelField.GetDataType: TEFDataType;
var
  LSize, LDecimalPrecision: Integer;
  LIsRequired: Boolean;
  LIsKey: Boolean;
  LReferencedModel: string;
  LParentField: TKModelField;
  LParentRefModel: TKModel;
  LDataType: string;
begin
  if Assigned(Model) and Assigned(Model.Catalog) then
  begin
    LParentField := ParentField;
    if Assigned(LParentField) and LParentField.IsReference then
    begin
      LParentRefModel := Model.Catalog.FindModel(LParentField.ReferencedModelName);
      if Assigned(LParentRefModel) and (Index < LParentRefModel.KeyFieldCount) then
        Result := LParentRefModel.KeyFields[Index].GetActualDataType
      else
      begin
        GetFieldSpec(LDataType, LSize, LDecimalPrecision, LIsRequired, LIsKey, LReferencedModel);
        if LDataType <> '' then
          Result := TEFDataTypeFactory.Instance.GetDataType(LDataType)
        else
          Result := TEFDataTypeFactory.Instance.GetDataType('String');
      end;
    end
    else
    begin
      GetFieldSpec(LDataType, LSize, LDecimalPrecision, LIsRequired, LIsKey, LReferencedModel);
      Result := TEFDataTypeFactory.Instance.GetDataType(LDataType);
    end;
//    if Result is TKReferenceDataType then
//      Result := ParentField.ReferencedModel.KeyFields[Index].ReferencedModel.KeyFields[0].DataType;
  end
  else
    Result := inherited GetDataType;
end;

function TKModelField.GetDBColumnName: string;
begin
  Result := PhysicalName;
  if Result = '' then
    Result := FieldName;
end;

function TKModelField.GetDBColumnNameOrExpression: string;
begin
  if Expression <> '' then
    Result := Expression
  else
    Result := DBColumnName;
end;

function TKModelField.GetDBColumnNames: TStringDynArray;
begin
  Result := GetFields.GetDBColumnNames;
end;

function TKModelField.GetDecimalPrecision: Integer;
var
  LDataType: string;
  LSize: Integer;
  LIsRequired: Boolean;
  LIsKey: Boolean;
  LReferencedModel: string;
  LParentField: TKModelField;
begin
  LParentField := ParentField;
  if Assigned(LParentField) and ParentField.IsReference then
    Result := ParentField.ReferencedModel.KeyFields[Index].DecimalPrecision
  else
    GetFieldSpec(LDataType, LSize, Result, LIsRequired, LIsKey, LReferencedModel);
  // '<= 0', not '= 0'. GetFieldSpec sets -1 for a reference field, meaning
  // 'not applicable', and the guard here used to catch only the 0 that a
  // non-reference field gets when its spec does not say. The -1 travelled all
  // the way to TKField.GetAsJSONValue, which assigns this to
  // TFormatSettings.CurrencyDecimals -- a Byte -- so rendering any list or
  // form containing a reference raised a range error on that assignment.
  // Invisible for as long as {$R} was forced off in Debug builds, which
  // EF.Defines.inc did until the first correction of this review; in Release
  // the -1 was stored as 255 and the value was formatted with 255 decimals
  // asked for.
  if Result <= 0 then
    Result := 2;
end;

function TKModelField.GetDefaultFilter: string;
begin
  Result := GetString('DefaultFilter');
end;

function TKModelField.GetDefaultFilterConnector: string;
begin
  Result := GetString('DefaultFilterConnector', 'and');
end;

function TKModelField.GetDefaultValue: Variant;
var
  LStringValue: string;
begin
  Result := EvalExpression(GetValue('DefaultValue'));
  if DataType is TEFStringDataType then
  begin
    LStringValue := EFVarToStr(Result);
    TKConfig.Instance.MacroExpansionEngine.Expand(LStringValue);
    Result := LStringValue;
  end;
end;

function TKModelField.GetDefaultDisplayWidth: Integer;
begin
  Result := DataType.GetDefaultDisplayWidth(Size);
end;

function TKModelField.GetDefaultDisplayLabel: string;
begin
  Result := BeautifyFieldName(FieldName);
end;

function TKModelField.GetDefaultEmptyAsNull: Boolean;
var
  LNode: TEFNode;
begin
  if DataType.SupportsEmptyAsNull then
  begin
    if ParentField <> nil then
      Result := ParentField.EmptyAsNull
    else
    begin
      LNode := FindChild('EmptyAsNull', False);
      if Assigned(LNode) then
        Result := LNode.AsBoolean
      else
        Result := inherited GetEmptyAsNull;
    end;
  end
  else
    Result := False;
end;

function TKModelField.GetDisplayFormat: string;
begin
  Result := GetString('DisplayFormat');
  if (Result = '') and DataType.HasScale then
    Result := ',0.' + DupeString('0', DecimalPrecision);
end;

function TKModelField.GetDisplayLabel: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('DisplayLabel2')
  else
    Result := GetString('DisplayLabel');
  if Result = '' then
    Result := GetDefaultDisplayLabel;
end;

function TKModelField.GetDisplayLabel_Form: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('DisplayLabel_Form2')
  else
    Result := GetString('DisplayLabel_Form');
  if Result = '' then
    Result := DisplayLabel;
end;

function TKModelField.GetDisplayLabel_Grid: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('DisplayLabel_Grid2')
  else
    Result := GetString('DisplayLabel_Grid');
  if Result = '' then
    Result := DisplayLabel;
end;

function TKModelField.GetDisplayTemplate: string;
begin
  Result := GetString('DisplayTemplate');
end;

function TKModelField.GetDisplayWidth: Integer;
begin
  Result := GetInteger('DisplayWidth');
  if Result = 0 then
    Result := DefaultDisplayWidth;
end;

function TKModelField.GetEditFormat: string;
begin
  Result := GetString('EditFormat');
end;

function TKModelField.GetEmptyAsNull: Boolean;
begin
  if DataType.SupportsEmptyAsNull then
    Result := GetDefaultEmptyAsNull
  else
    Result := inherited GetEmptyAsNull;
end;

function TKModelField.GetExpression: string;
begin
  Result := GetString('Expression');
end;

function TKModelField.GetField(I: Integer): TKModelField;
begin
  Result := GetFields[I];
end;

function TKModelField.GetFieldCount: Integer;
begin
  Result := GetFields.ChildCount;
end;

function TKModelField.GetFieldName: string;
begin
  Result := Name;
end;

function TKModelField.GetFieldNameOrExpression: string;
begin
  if Expression <> '' then
    Result := Expression
  else
    Result := FieldName;
end;

function TKModelField.GetFieldNames: TStringDynArray;
begin
  Result := GetFields.GetFieldNames;
end;

function TKModelField.GetFields: TKModelFields;
begin
  Result := GetNode('Fields', True) as TKModelFields;
end;

function TKModelField.GetSize: Integer;
var
  LDataType: string;
  LDecimalPrecision: Integer;
  LIsRequired: Boolean;
  LIsKey: Boolean;
  LReferencedModel: string;
  LParentField: TKModelField;
begin
  LParentField := ParentField;
  if Assigned(LParentField) and ParentField.IsReference then
    Result := ParentField.ReferencedModel.KeyFields[Index].Size
  else
    GetFieldSpec(LDataType, Result, LDecimalPrecision, LIsRequired, LIsKey, LReferencedModel);
end;

function TKModelField.GetModel: TKModel;
begin
  Result := GetRoot as TKModel;
end;

function TKModelField.GetParentField: TKModelField;
begin
  if Assigned(Parent) and (Parent is TKModelFields) then
    Result := TKModelFields(Parent).ParentField
  else
    Result := nil;
end;

function TKModelField.GetPhysicalName: string;
begin
  Result := GetString('PhysicalName', FieldName);
end;

{ TKModelFields }

function TKModelFields.FieldByName(const AName: string): TKModelField;
begin
  Result := FindField(AName);
  if not Assigned(Result) then
    raise EKError.CreateFmt('Field %s not found.', [AName]);
end;

function TKModelFields.FindField(const AName: string): TKModelField;
var
  I: Integer;
begin
  Result := FindChild(AName) as TKModelField;
  if not Assigned(Result) then
  begin
    for I := 0 to FieldCount - 1 do
    begin
      Result := Fields[I].FindField(AName);
      if Assigned(Result) then
        Exit;
    end;
  end;
end;

function TKModelFields.FindFieldByPhysicalName(
  const APhysicalName: string): TKModelField;
var
  I: Integer;
begin
  Result := FindChildByPredicate(
    function (const ANode: TEFNode): Boolean
    begin
      Result := SameText((ANode as TKModelField).PhysicalName, APhysicalName);
    end) as TKModelField;
  if not Assigned(Result) then
  begin
    for I := 0 to FieldCount - 1 do
    begin
      Result := Fields[I].FindFieldByPhysicalName(APhysicalName);
      if Assigned(Result) then
        Exit;
    end;
  end;
end;

function TKModelFields.FindFieldByPredicate(
  const APredicate: TKModelFieldPredicate): TKModelField;
var
  I: Integer;
  LPredicate: TEFTree.TNodePredicate;
begin
  LPredicate :=
    function (const ANode: TEFNode): Boolean
    begin
      Result := APredicate(ANode as TKModelField);
    end;
  Result := FindChildByPredicate(LPredicate) as TKModelField;
  if not Assigned(Result) then
  begin
    for I := 0 to FieldCount - 1 do
    begin
      Result := Fields[I].FindFieldByPredicate(APredicate);
      if Assigned(Result) then
        Exit;
    end;
  end;
end;

function TKModelFields.GetChildClass(const AName: string): TEFNodeClass;
begin
  Result := TKModelField;
end;

function TKModelFields.GetDBColumnNames: TStringDynArray;
var
  I: Integer;
begin
  SetLength(Result, FieldCount);
  for I := Low(Result) to High(Result) do
    Result[I] := Fields[I].DBColumnName;
end;

function TKModelFields.GetField(I: Integer): TKModelField;
begin
  Result := Children[I] as TKModelField;
end;

function TKModelFields.GetFieldCount: Integer;
begin
  Result := ChildCount;
end;

function TKModelFields.GetFieldNames: TStringDynArray;
begin
  Result := GetChildNames;
end;

function TKModelFields.GetParentField: TKModelField;
begin
  if Assigned(Parent) and (Parent is TKModelField) then
    Result := TKModelField(Parent)
  else
    Result := nil;
end;

{ TKModelSubobject }

function TKModelSubobject.GetModel: TKModel;
var
  LParent: TEFTree;
begin
  LParent := Parent;
  // Walk UP the parent chain to the owning model (a TKModel is a TEFTree, not a
  // TEFNode, so it ends the loop). The step must advance LParent: it used to
  // read TEFNode(Parent).Parent -- Parent is fixed, so every iteration recomputed
  // the same grandparent. That is an infinite loop whenever the grandparent is
  // itself a TEFNode (a subobject nested more than one level down); it only ever
  // terminated because the cases in play had the model as the grandparent.
  while Assigned(LParent) and (LParent is TEFNode) do
    LParent := TEFNode(LParent).Parent;

  Result := LParent as TKModel;

  Assert(Assigned(Result), 'Assigned(Result)');
end;

{ TKModels }

class constructor TKModels.Create;
begin
  ResetDefaultModelClassType;
end;

function TKModels.FindModel(const AName: string): TKModel;
begin
  Result := FindObject(AName) as TKModel;
end;

function TKModels.FindModelByNode(const ANode: TEFNode): TKModel;
begin
  Result := FindObjectByNode(ANode) as TKModel;
end;

function TKModels.FindModelByPhysicalName(const APhysicalName: string): TKModel;
begin
  Result := FindObjectByPredicate(
    function (const AObject: TKMetadata): Boolean
    var
      LModel: TKModel;
    begin
      LModel := AObject as TKModel;
      Result := SameText(IfThen(LModel.PhysicalName <> '', LModel.PhysicalName, LModel.ModelName), APhysicalName);
    end) as TKModel;
end;

function TKModels.GetObjectClassType: TKMetadataClass;
begin
  Result := FDefaultModelClassType;
end;

function TKModels.GetMetadataRegistry: TKMetadataRegistry;
begin
  Result := TKModelRegistry.Instance;
end;

function TKModels.GetModel(I: Integer): TKModel;
begin
  Result := Objects[I] as TKModel;
end;

function TKModels.GetModelCount: Integer;
begin
  Result := ObjectCount;
end;

procedure TKModels.GetModelList(const AList: TKModelList);
var
  I: Integer;
begin
  Assert(Assigned(AList), 'Assigned(AList)');
  AList.Clear;
  if not IsOpen then
    Open
  else
    Refresh;
  for I := 0 to ModelCount - 1 do
    AList.Add(Models[I]);
end;

function TKModels.GetModelRegistry: TKModelRegistry;
begin
  Result := GetMetadataRegistry as TKModelRegistry;
end;

function TKModels.ModelByName(const AName: string): TKModel;
begin
  Result := ObjectByName(AName) as TKModel;
end;

function TKModels.ModelByNode(const ANode: TEFNode): TKModel;
begin
  Result := ObjectByNode(ANode) as TKModel;
end;

class procedure TKModels.ResetDefaultModelClassType;
begin
  FDefaultModelClassType := TKModel;
end;

{ TKRules }

function TKRules.GetChildClass(const AName: string): TEFNodeClass;
begin
  Result := TKRule;
end;

function TKRules.GetRule(const AIndex: Integer): TKRule;
begin
  Result := Children[AIndex] as TKRule;
end;

function TKRules.GetRuleCount: Integer;
begin
  Result := ChildCount;
end;

function TKRules.HasRule(const ARule: TKRule): Boolean;
begin
  Result := Assigned(ARule) and Assigned(FindChild(ARule.Name));
end;

{ TKModelDetailReference }

class function TKModelDetailReference.BeautifyDetailName(const ADetailName: string): string;
begin
  Result := DefaultBeautifyName(ADetailName);
end;

function TKModelDetailReference.GetDBForeignKeyName: string;
begin
  Result := PhysicalName;
end;

function TKModelDetailReference.GetCascadeDelete: Boolean;
begin
  Result := GetBoolean('CascadeDelete', False);
end;

function TKModelDetailReference.GetDetailModel: TKModel;
begin
  Result := Model.Catalog.ModelByName(DetailModelName);
end;

function TKModelDetailReference.GetDetailModelName: string;
begin
  Result := AsString;
end;

function TKModelDetailReference.GetDetailReferenceName: string;
begin
  Result := Name;
end;

function TKModelDetailReference.GetDisplayLabel: string;
begin
  if TKConfig.Instance.UseAltLanguage then
    Result := GetString('DisplayLabel2')
  else
    Result := GetString('DisplayLabel');
  if (Result = '') and (DetailModel <> nil) then
    Result := DetailModel.DisplayLabel;
  if Result = '' then
    Result := BeautifyDetailName(DetailReferenceName);
end;

function TKModelDetailReference.GetPhysicalName: string;
begin
  Result := GetString('PhysicalName');
end;

function TKModelDetailReference.GetReferenceField: TKModelField;
begin
  Result := DetailModel.FindReferenceField(Model);
  if Result = nil then
  begin
    if ReferenceFieldName <> '' then
      Result := DetailModel.FieldByName(ReferenceFieldName);
    if not Assigned(Result) or not Result.IsReference or not (Result.ReferencedModel = Model) then
      raise EKError.CreateFmt('No reference field in detail model %s to detail reference %s in master model %s.',
        [DetailModel.ModelName, DetailReferenceName, Model.ModelName]);
  end;
end;

function TKModelDetailReference.GetReferenceFieldName: string;
begin
  Result := GetString('ReferenceField');
end;

{ TKModelDetails }

function TKModelDetailReferences.DetailReferenceByName(const AName: string): TKModelDetailReference;
begin
  Result := ChildByName(AName) as TKModelDetailReference;
end;

function TKModelDetailReferences.FindDetailReference(const AName: string): TKModelDetailReference;
begin
  Result := FindChild(AName) as TKModelDetailReference;
end;

function TKModelDetailReferences.FindDetailReferenceByPhysicalName(
  const APhysicalName: string): TKModelDetailReference;
begin
  Result := FindChildByPredicate(
    function (const ANode: TEFNode): Boolean
    begin
      Result := SameText((ANode as TKModelDetailReference).PhysicalName, APhysicalName);
    end) as TKModelDetailReference;
end;

function TKModelDetailReferences.FindDetailReferenceToField(
  const AField: TKModelField): TKModelDetailReference;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to DetailReferenceCount - 1 do
  begin
    if DetailReferences[I].ReferenceField = AField then
    begin
      Result := DetailReferences[I];
      Break;
    end;
  end;
end;

function TKModelDetailReferences.FindDetailReferenceToModel(
  const AModelName: string): TKModelDetailReference;
var
  I: Integer;
  LCount: Integer;
begin
  Result := nil;
  LCount := 0;
  for I := 0 to DetailReferenceCount - 1 do
  begin
    if SameText(DetailReferences[I].DetailModelName, AModelName) then
    begin
      Result := DetailReferences[I];
      Inc(LCount);
    end;
  end;
  if LCount <> 1 then
    Result := nil;
end;

function TKModelDetailReferences.FindDetailReferenceToModel(
  const AModel: TKModel): TKModelDetailReference;
var
  I: Integer;
  LCount: Integer;
begin
  Result := nil;
  LCount := 0;
  for I := 0 to DetailReferenceCount - 1 do
  begin
    if DetailReferences[I].DetailModel = AModel then
    begin
      Result := DetailReferences[I];
      Inc(LCount);
    end;
  end;
  if LCount <> 1 then
    Result := nil;
end;

function TKModelDetailReferences.GetChildClass(const AName: string): TEFNodeClass;
begin
  Result := TKModelDetailReference;
end;

function TKModelDetailReferences.GetDetailReference(I: Integer): TKModelDetailReference;
begin
  Result := Children[I] as TKModelDetailReference;
end;

function TKModelDetailReferences.GetDetailReferenceCount: Integer;
begin
  Result := ChildCount;
end;

{ TKReferenceDataType }

function TKReferenceDataType.GetDefaultEmptyAsNull: Boolean;
begin
  Result := True;
end;

class function TKReferenceDataType.GetTypeName: string;
begin
  Result := 'Reference';
end;

procedure TKReferenceDataType.InternalFieldValueToNode(const AField: TField;
  const ANode: TEFNode);
begin
  ANode.Value := AField.Value;
end;

procedure TKReferenceDataType.InternalYamlValueToNode(const AYamlValue: string;
  const ANode: TEFNode; const AFormatSettings: TFormatSettings);
begin
  raise EEFError.CreateFmt('%s.InternalYamlValueToNode: Unsupported call.', [ClassName]);
end;

function TKReferenceDataType.SupportsEmptyAsNull: Boolean;
begin
  Result := True;
end;

{ TKModelList }

procedure TKModelList.AddModelNamesToStrings(const AStrings: TStrings);
var
  LModel: TKModel;
begin
  for LModel in Self do
    AStrings.Add(LModel.ModelName);
end;

{ TKModelRegistry }

procedure TKModelRegistry.BeforeRegisterClass(const AId: string;
  const AClass: TClass);
begin
  inherited;
  if not AClass.InheritsFrom(TKModel) then
    raise EKError.CreateFmt('Cannot register class %s (Id %s). Class is not a %s subclass.', [AClass.ClassName, AId, TKModel.ClassName]);
//  if not Supports(AClass, IKModel) then
//    raise EKError.CreateFmt('Cannot register class %s (Id %s). Class does not support %s interface.', [AClass.ClassName, AId, GetTypeName(TypeInfo(IKModel))]);
end;

class destructor TKModelRegistry.Destroy;
begin
  FreeAndNil(FInstance);
end;

function TKModelRegistry.GetClass(const AId1, AId2: string): TKModelClass;
begin
  Result := TKModelClass(inherited GetClass(AId1, AId2));
end;

class function TKModelRegistry.GetInstance: TKModelRegistry;
begin
  if FInstance = nil then
    FInstance := TKModelRegistry.Create;
  Result := FInstance;
end;

{ TKHTMLEditorConfig }

function TKHTMLEditorConfig.GetEnableFont: Boolean;
begin
  Result := GetBoolean('EnableFont', True);
end;

function TKHTMLEditorConfig.GetEnableFontSize: Boolean;
begin
  Result := GetBoolean('EnableFontSize', True);
end;

function TKHTMLEditorConfig.GetEnableFormat: Boolean;
begin
  Result := GetBoolean('EnableFormat', True);
end;

function TKHTMLEditorConfig.GetEnableColors: Boolean;
begin
  Result := GetBoolean('EnableColors', True);
end;

function TKHTMLEditorConfig.GetEnableAlignments: Boolean;
begin
  Result := GetBoolean('EnableAlignments', True);
end;

function TKHTMLEditorConfig.GetEnableLinks: Boolean;
begin
  Result := GetBoolean('EnableLinks', True);
end;

function TKHTMLEditorConfig.GetEnableLists: Boolean;
begin
  Result := GetBoolean('EnableLists', True);
end;

function TKHTMLEditorConfig.GetEnableSourceEdit: Boolean;
begin
  Result := GetBoolean('EnableSourceEdit', True);
end;

{ TKThumbnailConfig }

function TKThumbnailConfig.GetWidth: Integer;
begin
  Result := GetInteger('Width', 150);
end;

function TKThumbnailConfig.GetHeight: Integer;
begin
  Result := GetInteger('Height', 150);
end;

{ TKPreviewWindowConfig }

function TKPreviewWindowConfig.GetWidth: Integer;
begin
  Result := GetInteger('Width', 226);
end;

function TKPreviewWindowConfig.GetHeight: Integer;
begin
  Result := GetInteger('Height', 320);
end;

initialization
  TEFDataTypeRegistry.Instance.RegisterClass(TKReferenceDataType.GetTypeName, TKReferenceDataType);

finalization
  TEFDataTypeRegistry.Instance.UnregisterClass(TKReferenceDataType.GetTypeName);

end.
