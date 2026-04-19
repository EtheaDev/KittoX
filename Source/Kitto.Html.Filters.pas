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
///  KittoX filter support for the List controller.
///  Provides the filter registry, filter base classes for design-time
///  identification (used by KIDE), and the BuildFilterExpression utility
///  that builds SQL WHERE clauses from filter values.
///  Replaces Kitto.Ext.Filters from Kitto3.
/// </summary>
unit Kitto.Html.Filters;

{$I Kitto.Defines.inc}

interface

uses
  EF.Types,
  EF.Tree;

const
  DEFAULT_FILTER_WIDTH = 20;

type
  /// <summary>
  ///  Callback that returns the filter value for a given filter item index.
  ///  Used by BuildFilterExpression to abstract request parameter reading.
  /// </summary>
  TKXFilterValueGetter = reference to function(AIndex: Integer): string;

  /// <summary>
  ///  Keeps track of all registered filter classes. Used by KIDE designer
  ///  to identify filter types at design time.
  /// </summary>
  TKXFilterRegistry = class(TEFRegistry)
  private
    class var FInstance: TKXFilterRegistry;
    class function GetInstance: TKXFilterRegistry; static;
  public
    class property Instance: TKXFilterRegistry read GetInstance;
    class destructor Destroy;
  end;

  /// <summary>Base class for list-based filters.</summary>
  TKListFilterBase = class
  end;

  /// <summary>Static list filter.</summary>
  TKListFilter = class(TKListFilterBase)
  end;

  /// <summary>Dynamic list filter.</summary>
  TKDynaListFilter = class(TKListFilterBase)
  end;

  /// <summary>Base class for button-list filters.</summary>
  TKButtonListFilterBase = class
  end;

  /// <summary>Button list filter.</summary>
  TKButtonListFilter = class(TKButtonListFilterBase)
  end;

  /// <summary>Dynamic button list filter.</summary>
  TKDynaButtonListFilter = class(TKButtonListFilterBase)
  end;

  /// <summary>Free text search filter.</summary>
  TKFreeSearchFilter = class
  end;

  /// <summary>Date search filter.</summary>
  TKDateSearchFilter = class
  end;

  /// <summary>Boolean search filter.</summary>
  TKBooleanSearchFilter = class
  end;

  /// <summary>Numeric search filter.</summary>
  TKNumericSearchFilter = class
  end;

  /// <summary>Time search filter.</summary>
  TKTimeSearchFilter = class
  end;

  /// <summary>DateTime search filter.</summary>
  TKDateTimeSearchFilter = class
  end;

/// <summary>
///  Builds a SQL WHERE clause from all active filter values.
///  AItemsNode: the Filters/Items node from the view config.
///  AConnector: 'and' or 'or'.
///  AGetValue: callback to retrieve the current value for each filter index.
/// </summary>
function BuildFilterExpression(AItemsNode: TEFNode;
  const AConnector: string; AGetValue: TKXFilterValueGetter): string;

implementation

uses
  System.SysUtils,
  System.StrUtils;

{ TKXFilterRegistry }

class destructor TKXFilterRegistry.Destroy;
begin
  FreeAndNil(FInstance);
end;

class function TKXFilterRegistry.GetInstance: TKXFilterRegistry;
begin
  if not Assigned(FInstance) then
    FInstance := TKXFilterRegistry.Create;
  Result := FInstance;
end;

function BuildFilterExpression(AItemsNode: TEFNode;
  const AConnector: string; AGetValue: TKXFilterValueGetter): string;
var
  I, K: Integer;
  LNode, LSubItemsNode, LSubNode: TEFNode;
  LFilterType, LValue, LExpr, LEscapedValue: string;
  LKeys: TArray<string>;
  LBtnConnector, LSubExpr: string;
begin
  Result := '';
  if not Assigned(AItemsNode) then
    Exit;

  for I := 0 to AItemsNode.ChildCount - 1 do
  begin
    LNode := AItemsNode.Children[I];
    LFilterType := LNode.Name;
    LExpr := '';

    // Skip layout-only nodes
    if SameText(LFilterType, 'ColumnBreak') or
       SameText(LFilterType, 'Spacer') or
       SameText(LFilterType, 'ApplyButton') then
      Continue;

    LValue := AGetValue(I);
    if LValue = '' then
      Continue;

    // HTML date/datetime inputs return ISO values ('YYYY-MM-DD' or
    // 'YYYY-MM-DDTHH:MM[:SS]'). For SQL Server 'datetime' columns, the
    // 'YYYY-MM-DD' form is language-dependent: with an Italian session
    // (DATEFORMAT dmy) '2026-04-15' is parsed as yyyy-dd-mm, i.e. day 04
    // / month 15 -> out of range. The basic 'YYYYMMDD[ HH:MM[:SS]]' form
    // (no separators between date components) is always parsed as
    // year-month-day regardless of DATEFORMAT / language, so we rewrite
    // the value here before it gets substituted into the SQL template.
    if SameText(LFilterType, 'DateSearch') and (Length(LValue) = 10) then
      LValue := Copy(LValue, 1, 4) + Copy(LValue, 6, 2) + Copy(LValue, 9, 2)
    else if SameText(LFilterType, 'DateTimeSearch') and (Length(LValue) >= 16) then
      LValue := Copy(LValue, 1, 4) + Copy(LValue, 6, 2) + Copy(LValue, 9, 2) +
                ' ' + Copy(LValue, 12, MaxInt);

    // SQL injection prevention: escape single quotes
    LEscapedValue := ReplaceStr(LValue, '''', '''''');

    if SameText(LFilterType, 'FreeSearch') or
       SameText(LFilterType, 'DynaList') or
       SameText(LFilterType, 'DateSearch') or
       SameText(LFilterType, 'TimeSearch') or
       SameText(LFilterType, 'NumericSearch') then
    begin
      LExpr := LNode.GetExpandedString('ExpressionTemplate');
      if LExpr <> '' then
        LExpr := ReplaceText(LExpr, '{value}', LEscapedValue);
    end
    else if SameText(LFilterType, 'List') then
    begin
      LSubItemsNode := LNode.FindNode('Items');
      if Assigned(LSubItemsNode) then
      begin
        LSubNode := LSubItemsNode.FindNode(LValue);
        if Assigned(LSubNode) then
          LExpr := LSubNode.GetExpandedString('Expression');
      end;
    end
    else if SameText(LFilterType, 'DateTimeSearch') then
    begin
      LExpr := LNode.GetExpandedString('ExpressionTemplate');
      if LExpr <> '' then
        LExpr := ReplaceText(LExpr, '{value}', LEscapedValue);
    end
    else if SameText(LFilterType, 'BooleanSearch') then
    begin
      // Checkbox only sends value when checked
      LExpr := LNode.GetExpandedString('ExpressionTemplate');
    end
    else if SameText(LFilterType, 'ButtonList') or
            SameText(LFilterType, 'DynaButtonList') then
    begin
      // Value is comma-separated list of selected item keys (e.g. "Blond,Red")
      LSubItemsNode := LNode.FindNode('Items');
      if Assigned(LSubItemsNode) then
      begin
        LBtnConnector := LNode.GetString('Connector', 'or');
        LKeys := LValue.Split([',']);
        LExpr := '';
        for K := 0 to Length(LKeys) - 1 do
        begin
          LSubNode := LSubItemsNode.FindNode(Trim(LKeys[K]));
          if Assigned(LSubNode) then
          begin
            LSubExpr := LSubNode.GetExpandedString('Expression');
            if LSubExpr <> '' then
            begin
              if LExpr = '' then
                LExpr := '(' + LSubExpr + ')'
              else
                LExpr := LExpr + ' ' + LBtnConnector + ' (' + LSubExpr + ')';
            end;
          end;
        end;
      end;
    end;

    if LExpr <> '' then
    begin
      if Result = '' then
        Result := '(' + LExpr + ')'
      else
        Result := Result + ' ' + AConnector + ' (' + LExpr + ')';
    end;
  end;
end;

initialization
  TKXFilterRegistry.Instance.RegisterClass('List', TKListFilter);
  TKXFilterRegistry.Instance.RegisterClass('DynaList', TKDynaListFilter);
  TKXFilterRegistry.Instance.RegisterClass('ButtonList', TKButtonListFilter);
  TKXFilterRegistry.Instance.RegisterClass('DynaButtonList', TKDynaButtonListFilter);
  TKXFilterRegistry.Instance.RegisterClass('FreeSearch', TKFreeSearchFilter);
  TKXFilterRegistry.Instance.RegisterClass('DateSearch', TKDateSearchFilter);
  TKXFilterRegistry.Instance.RegisterClass('TimeSearch', TKTimeSearchFilter);
  TKXFilterRegistry.Instance.RegisterClass('DateTimeSearch', TKDateTimeSearchFilter);
  TKXFilterRegistry.Instance.RegisterClass('NumericSearch', TKNumericSearchFilter);
  TKXFilterRegistry.Instance.RegisterClass('BooleanSearch', TKBooleanSearchFilter);

end.
