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
///  RTTI-based discovery utilities for YAML-mapped properties.
///  Used by KIDE to enumerate a class's YAML metadata at runtime,
///  replacing the external MetadataTemplates YAML files.
/// </summary>
unit EF.YAML.AttributeUtils;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  System.Generics.Collections,
  EF.YAML.Attributes;

type
  /// <summary>
  ///  Identifies the kind of YAML mapping on a property.
  /// </summary>
  TYamlAttributeKind = (
    yakScalar,     // YamlNodeAttribute — optional scalar value
    yakRequired,   // YamlRequiredNodeAttribute — required scalar value
    yakContainer,  // YamlContainerAttribute — N homogeneous children
    yakSubNode     // YamlSubNodeAttribute — single config block
  );

  /// <summary>
  ///  Describes a single YAML-mapped property discovered via RTTI.
  /// </summary>
  TYamlPropertyInfo = record
    /// <summary>Delphi property name (e.g. 'IsVisible').</summary>
    PropertyName: string;
    /// <summary>YAML node path (e.g. 'IsVisible', 'PreviewWindow/Width').</summary>
    NodePath: string;
    /// <summary>Kind of YAML attribute (Scalar, Required, Container, SubNode).</summary>
    AttributeKind: TYamlAttributeKind;
    /// <summary>Default value for scalar nodes (empty string if none).</summary>
    DefaultValue: string;
    /// <summary>True if the attribute constructor provided an explicit default.</summary>
    HasDefaultValue: Boolean;
    /// <summary>English description for KIDE tooltips.</summary>
    Description: string;
    /// <summary>True if the property supports alternate language (DisplayLabel2).</summary>
    IsLocalizable: Boolean;
    /// <summary>RTTI type of the Delphi property (for enum detection, etc.).</summary>
    PropertyType: TRttiType;
    /// <summary>
    ///  For Container: the class of each child element.
    ///  For SubNode: the class of the sub-object.
    ///  Nil for scalar properties.
    /// </summary>
    ChildOrSubNodeClass: TClass;
  end;

  /// <summary>
  ///  Describes a single enum value mapping (YAML string to ordinal).
  /// </summary>
  TYamlEnumValueInfo = record
    /// <summary>Ordinal value in the Delphi enum.</summary>
    OrdinalValue: Integer;
    /// <summary>Delphi enum name (e.g. 'laTop').</summary>
    EnumName: string;
    /// <summary>YAML string representation (e.g. 'Top').</summary>
    YamlValue: string;
    /// <summary>English description for KIDE combo box items.</summary>
    Description: string;
  end;

  /// <summary>
  ///  Describes a child type that can be added to a container class.
  /// </summary>
  TYamlChildTypeInfo = record
    /// <summary>Node name (e.g. 'StringField', 'ForceUpperCase').</summary>
    Name: string;
    /// <summary>Default value (e.g. 'String(10)', 'Integer').</summary>
    DefaultValue: string;
    /// <summary>English description for KIDE tooltip.</summary>
    Description: string;
  end;

  /// <summary>
  ///  Static utility class for discovering YAML attributes via RTTI.
  /// </summary>
  TYamlAttributeReader = class
  private
    class var FContext: TRttiContext;
    class function GetAttributeKind(AAttr: TCustomAttribute): TYamlAttributeKind; static;
  public
    /// <summary>
    ///  Enumerates all properties of AClass that carry a YAML attribute,
    ///  returning a sorted array of TYamlPropertyInfo records.
    ///  Properties are sorted: Required first, then by NodePath alphabetically.
    /// </summary>
    class function GetYamlProperties(AClass: TClass): TArray<TYamlPropertyInfo>; static;

    /// <summary>
    ///  Returns the YAML attribute on a specific property, or nil if none.
    ///  The returned object is owned by the RTTI system — do not free it.
    /// </summary>
    class function GetYamlAttribute(AProp: TRttiProperty): TCustomAttribute; static;

    /// <summary>
    ///  Quick check: returns True if the property carries any YAML attribute.
    /// </summary>
    class function IsYamlMapped(AProp: TRttiProperty): Boolean; static;

    /// <summary>
    ///  Reads YamlEnumValue attributes from an enumerated type.
    ///  Returns one entry per enum ordinal, in ordinal order.
    ///  If ATypeInfo is not an enum or has no YamlEnumValue attributes,
    ///  returns an empty array.
    /// </summary>
    class function GetYamlEnumValues(ATypeInfo: PTypeInfo): TArray<TYamlEnumValueInfo>; static;

    /// <summary>
    ///  Converts a YAML string value to the corresponding enum ordinal,
    ///  using YamlEnumValue attributes on the enum type.
    ///  Raises an exception if the value is not found.
    /// </summary>
    class function YamlValueToOrdinal(ATypeInfo: PTypeInfo;
      const AYamlValue: string): Integer; static;

    /// <summary>
    ///  Converts an enum ordinal to its YAML string representation,
    ///  using YamlEnumValue attributes on the enum type.
    ///  Raises an exception if the ordinal has no YamlEnumValue attribute.
    /// </summary>
    class function OrdinalToYamlValue(ATypeInfo: PTypeInfo;
      AOrdinal: Integer): string; static;

    /// <summary>
    ///  Reads YamlChildType attributes from a container class.
    ///  Returns one entry per child type, in declaration order.
    ///  If AClass has no YamlChildType attributes, returns an empty array.
    /// </summary>
    class function GetYamlChildTypes(AClass: TClass): TArray<TYamlChildTypeInfo>; static;
  end;

implementation

uses
  System.Generics.Defaults;

{ TYamlAttributeReader }

class function TYamlAttributeReader.GetAttributeKind(
  AAttr: TCustomAttribute): TYamlAttributeKind;
begin
  if AAttr is YamlRequiredNodeAttribute then
    Result := yakRequired
  else if AAttr is YamlContainerAttribute then
    Result := yakContainer
  else if AAttr is YamlSubNodeAttribute then
    Result := yakSubNode
  else
    Result := yakScalar;
end;

class function TYamlAttributeReader.GetYamlAttribute(
  AProp: TRttiProperty): TCustomAttribute;
var
  LAttr: TCustomAttribute;
begin
  Result := nil;
  for LAttr in AProp.GetAttributes do
  begin
    if (LAttr is YamlNodeAttribute) or (LAttr is YamlContainerAttribute)
      or (LAttr is YamlSubNodeAttribute) then
      Exit(LAttr);
  end;
end;

class function TYamlAttributeReader.IsYamlMapped(
  AProp: TRttiProperty): Boolean;
begin
  Result := GetYamlAttribute(AProp) <> nil;
end;

class function TYamlAttributeReader.GetYamlProperties(
  AClass: TClass): TArray<TYamlPropertyInfo>;
var
  LType: TRttiType;
  LProp: TRttiProperty;
  LAttr: TCustomAttribute;
  LList: TList<TYamlPropertyInfo>;
  LInfo: TYamlPropertyInfo;
begin
  LType := FContext.GetType(AClass);
  if not Assigned(LType) then
    Exit(nil);

  LList := TList<TYamlPropertyInfo>.Create;
  try
    for LProp in LType.GetProperties do
    begin
      LAttr := GetYamlAttribute(LProp);
      if not Assigned(LAttr) then
        Continue;

      LInfo := Default(TYamlPropertyInfo);
      LInfo.PropertyName := LProp.Name;
      LInfo.PropertyType := LProp.PropertyType;
      LInfo.AttributeKind := GetAttributeKind(LAttr);

      if LAttr is YamlNodeAttribute then
      begin
        // Scalar or Required
        LInfo.NodePath := YamlNodeAttribute(LAttr).NodePath;
        LInfo.DefaultValue := YamlNodeAttribute(LAttr).DefaultValue;
        LInfo.HasDefaultValue := YamlNodeAttribute(LAttr).HasDefaultValue;
        LInfo.Description := YamlNodeAttribute(LAttr).Description;
        LInfo.IsLocalizable := YamlNodeAttribute(LAttr).IsLocalizable;
        LInfo.ChildOrSubNodeClass := nil;
      end
      else if LAttr is YamlContainerAttribute then
      begin
        LInfo.NodePath := YamlContainerAttribute(LAttr).NodePath;
        LInfo.Description := YamlContainerAttribute(LAttr).Description;
        LInfo.ChildOrSubNodeClass := YamlContainerAttribute(LAttr).ChildClass;
      end
      else if LAttr is YamlSubNodeAttribute then
      begin
        LInfo.NodePath := YamlSubNodeAttribute(LAttr).NodePath;
        LInfo.Description := YamlSubNodeAttribute(LAttr).Description;
        LInfo.ChildOrSubNodeClass := YamlSubNodeAttribute(LAttr).SubNodeClass;
      end;

      LList.Add(LInfo);
    end;

    // Sort: Required first, then alphabetically by NodePath
    LList.Sort(TComparer<TYamlPropertyInfo>.Construct(
      function(const L, R: TYamlPropertyInfo): Integer
      begin
        // Required nodes first
        if (L.AttributeKind = yakRequired) and (R.AttributeKind <> yakRequired) then
          Exit(-1);
        if (L.AttributeKind <> yakRequired) and (R.AttributeKind = yakRequired) then
          Exit(1);
        // Then by NodePath
        Result := CompareText(L.NodePath, R.NodePath);
      end
    ));

    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class function TYamlAttributeReader.GetYamlEnumValues(
  ATypeInfo: PTypeInfo): TArray<TYamlEnumValueInfo>;
var
  LType: TRttiType;
  LAttr: TCustomAttribute;
  LList: TList<TYamlEnumValueInfo>;
  LInfo: TYamlEnumValueInfo;
  LOrdinal: Integer;
begin
  if (ATypeInfo = nil) or (ATypeInfo.Kind <> tkEnumeration) then
    Exit(nil);

  LType := FContext.GetType(ATypeInfo);
  if not Assigned(LType) then
    Exit(nil);

  LList := TList<TYamlEnumValueInfo>.Create;
  try
    LOrdinal := 0;
    for LAttr in LType.GetAttributes do
    begin
      if LAttr is YamlEnumValueAttribute then
      begin
        LInfo := Default(TYamlEnumValueInfo);
        LInfo.OrdinalValue := LOrdinal;
        LInfo.EnumName := GetEnumName(ATypeInfo, LOrdinal);
        LInfo.YamlValue := YamlEnumValueAttribute(LAttr).YamlValue;
        LInfo.Description := YamlEnumValueAttribute(LAttr).Description;
        LList.Add(LInfo);
        Inc(LOrdinal);
      end;
    end;

    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

class function TYamlAttributeReader.YamlValueToOrdinal(ATypeInfo: PTypeInfo;
  const AYamlValue: string): Integer;
var
  LValues: TArray<TYamlEnumValueInfo>;
  I: Integer;
begin
  LValues := GetYamlEnumValues(ATypeInfo);
  for I := 0 to High(LValues) do
    if SameText(LValues[I].YamlValue, AYamlValue) then
      Exit(LValues[I].OrdinalValue);
  raise Exception.CreateFmt('Unknown YAML enum value "%s" for type %s',
    [AYamlValue, ATypeInfo.Name]);
end;

class function TYamlAttributeReader.OrdinalToYamlValue(ATypeInfo: PTypeInfo;
  AOrdinal: Integer): string;
var
  LValues: TArray<TYamlEnumValueInfo>;
  I: Integer;
begin
  LValues := GetYamlEnumValues(ATypeInfo);
  for I := 0 to High(LValues) do
    if LValues[I].OrdinalValue = AOrdinal then
      Exit(LValues[I].YamlValue);
  raise Exception.CreateFmt('No YAML mapping for ordinal %d of type %s',
    [AOrdinal, ATypeInfo.Name]);
end;

class function TYamlAttributeReader.GetYamlChildTypes(
  AClass: TClass): TArray<TYamlChildTypeInfo>;
var
  LType: TRttiType;
  LAttr: TCustomAttribute;
  LList: TList<TYamlChildTypeInfo>;
  LInfo: TYamlChildTypeInfo;
begin
  LType := FContext.GetType(AClass);
  if not Assigned(LType) then
    Exit(nil);

  LList := TList<TYamlChildTypeInfo>.Create;
  try
    for LAttr in LType.GetAttributes do
    begin
      if LAttr is YamlChildTypeAttribute then
      begin
        LInfo := Default(TYamlChildTypeInfo);
        LInfo.Name := YamlChildTypeAttribute(LAttr).Name;
        LInfo.DefaultValue := YamlChildTypeAttribute(LAttr).DefaultValue;
        LInfo.Description := YamlChildTypeAttribute(LAttr).Description;
        LList.Add(LInfo);
      end;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

end.
