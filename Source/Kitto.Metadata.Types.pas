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
///  Enumerated types for fixed YAML string values used across the framework.
///  Each enum value is decorated with YamlEnumValue to map it to the
///  corresponding YAML string. KIDE reads these mappings via RTTI.
/// </summary>
unit Kitto.Metadata.Types;

{$I Kitto.Defines.inc}

interface

uses
  EF.YAML.Attributes;

type
  // --- Form Layout ---

  /// <summary>
  ///  Label positioning relative to the form field.
  ///  YAML node: LabelAlign (in Layout file or EditController).
  /// </summary>
  [YamlEnumValue('Top', 'Label above the field')]
  [YamlEnumValue('Left', 'Label to the left, left-aligned')]
  [YamlEnumValue('Right', 'Label to the left, right-aligned')]
  TKLabelAlign = (laTop, laLeft, laRight);

  /// <summary>
  ///  Where validation messages are displayed in the form.
  ///  YAML node: MsgTarget (in Layout file).
  /// </summary>
  [YamlEnumValue('Title', 'Validation message as field tooltip')]
  [YamlEnumValue('Under', 'Validation message below the field')]
  TKMsgTarget = (mtTitle, mtUnder);

  /// <summary>
  ///  Form operation mode (determines read/write, title, and behavior).
  ///  YAML node: Controller/Operation (in View or standalone form).
  /// </summary>
  [YamlEnumValue('add', 'Insert a new record')]
  [YamlEnumValue('edit', 'Edit an existing record')]
  [YamlEnumValue('view', 'View an existing record (read-only)')]
  [YamlEnumValue('dup', 'Duplicate an existing record')]
  TKFormOperation = (foAdd, foEdit, foView, foDup);

  // --- Toolbar ---

  /// <summary>
  ///  Toolbar button display scale.
  ///  YAML node: Controller/ToolButtonScale (in View definition).
  /// </summary>
  [YamlEnumValue('small', 'Icon only')]
  [YamlEnumValue('medium', 'Icon and text')]
  [YamlEnumValue('large', 'Large icon and text')]
  TKToolButtonScale = (tbsSmall, tbsMedium, tbsLarge);

  // --- Filters ---

  /// <summary>
  ///  Logical connector for combining filter conditions.
  ///  YAML node: Filters/Connector, DefaultFilterConnector (in Model/View field).
  /// </summary>
  [YamlEnumValue('and', 'Combine filters with AND')]
  [YamlEnumValue('or', 'Combine filters with OR')]
  TKFilterConnector = (fcAnd, fcOr);

  /// <summary>
  ///  Filter panel item types.
  ///  YAML node: Filters/Items/<ItemName> (item name determines the type).
  /// </summary>
  [YamlEnumValue('FreeSearch', 'Free text search across multiple fields')]
  [YamlEnumValue('DynaList', 'Dynamic drop-down list from query')]
  [YamlEnumValue('DateSearch', 'Date range filter')]
  [YamlEnumValue('NumericSearch', 'Numeric range filter')]
  [YamlEnumValue('BooleanSearch', 'Boolean yes/no filter')]
  [YamlEnumValue('ButtonList', 'Static button group filter')]
  [YamlEnumValue('DynaButtonList', 'Dynamic button group filter from query')]
  [YamlEnumValue('ColumnBreak', 'Column break in filter layout')]
  [YamlEnumValue('Spacer', 'Empty spacer in filter layout')]
  [YamlEnumValue('ApplyButton', 'Apply filters button')]
  TKFilterType = (ftFreeSearch, ftDynaList, ftDateSearch, ftNumericSearch,
    ftBooleanSearch, ftButtonList, ftDynaButtonList, ftColumnBreak, ftSpacer,
    ftApplyButton);

  // --- Grid ---

  /// <summary>
  ///  Sort direction for grid columns.
  ///  Used internally when processing sort requests.
  /// </summary>
  [YamlEnumValue('asc', 'Ascending order')]
  [YamlEnumValue('desc', 'Descending order')]
  TKSortDirection = (sdAsc, sdDesc);

  /// <summary>
  ///  Column text alignment in grids.
  ///  YAML node: Align (in Layout grid column).
  /// </summary>
  [YamlEnumValue('left', 'Left-aligned text')]
  [YamlEnumValue('center', 'Center-aligned text')]
  [YamlEnumValue('right', 'Right-aligned text')]
  TKColumnAlignment = (caLeft, caCenter, caRight);

  // --- Theme ---

  /// <summary>
  ///  Application color theme.
  ///  YAML node: Theme (in Config.yaml).
  /// </summary>
  [YamlEnumValue('light', 'Light color scheme')]
  [YamlEnumValue('dark', 'Dark color scheme')]
  [YamlEnumValue('Auto', 'Follow OS preference')]
  TKTheme = (thLight, thDark, thAuto);

  /// <summary>
  ///  Material Design icon style variant.
  ///  YAML node: Theme/IconStyle (in Config.yaml).
  /// </summary>
  [YamlEnumValue('filled', 'Filled icons (default)')]
  [YamlEnumValue('outlined', 'Outlined icons')]
  [YamlEnumValue('round', 'Rounded icons')]
  [YamlEnumValue('sharp', 'Sharp icons')]
  [YamlEnumValue('two-tone', 'Two-tone icons')]
  TKIconStyle = (isFilled, isOutlined, isRound, isSharp, isTwoTone);

  /// <summary>
  ///  Default icon size.
  ///  YAML node: Theme/IconSize (in Config.yaml).
  /// </summary>
  [YamlEnumValue('Small', 'Small icons (16px)')]
  [YamlEnumValue('Medium', 'Medium icons (24px, default)')]
  [YamlEnumValue('Large', 'Large icons (32px)')]
  TKIconSize = (izSmall, izMedium, izLarge);

  // --- Chart ---

  /// <summary>
  ///  Chart coordinate system type.
  ///  YAML node: Chart/Type (in ChartPanel view).
  /// </summary>
  [YamlEnumValue('Cartesian', 'Cartesian (X/Y) coordinate system')]
  [YamlEnumValue('Polar', 'Polar coordinate system (pie, radar)')]
  TKChartType = (ctCartesian, ctPolar);

  /// <summary>
  ///  Chart data series visualization type.
  ///  YAML node: Chart/Series/Series/Type (in ChartPanel view).
  /// </summary>
  [YamlEnumValue('Bar', 'Vertical bar chart')]
  [YamlEnumValue('Line', 'Line chart')]
  [YamlEnumValue('Pie', 'Pie chart')]
  [YamlEnumValue('Pie3D', '3D pie chart')]
  TKSeriesType = (stBar, stLine, stPie, stPie3D);

  /// <summary>
  ///  Chart axis position.
  ///  YAML node: Chart/Axes/Axis/Position (in ChartPanel view).
  /// </summary>
  [YamlEnumValue('Left', 'Left axis')]
  [YamlEnumValue('Right', 'Right axis')]
  [YamlEnumValue('Top', 'Top axis')]
  [YamlEnumValue('Bottom', 'Bottom axis')]
  TKAxisPosition = (apLeft, apRight, apTop, apBottom);

  // --- Login ---

  /// <summary>
  ///  Credentials stored in browser localStorage.
  ///  YAML node: LocalStorage/Mode (in LoginView controller).
  /// </summary>
  [YamlEnumValue('', 'No local storage')]
  [YamlEnumValue('UserName', 'Store username only')]
  [YamlEnumValue('Password', 'Store username and password')]
  TKLocalStorageMode = (lsmNone, lsmUserName, lsmPassword);

implementation

end.
