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
///  Typed config reader for the user format-settings domain (Config.yaml node
///  <c>UserFormats</c>). Part of the per-domain organization of the config
///  metadata (replacing the monolithic Kitto.Metadata.SubNodes). Reads its
///  subtree once into typed fields (see TKConfigReader) AND carries the
///  [YamlNode] attributes that KIDE reads via RTTI for the Config editor.
/// </summary>
unit Kitto.Config.UserFormats;

{$I Kitto.Defines.inc}

interface

uses
  EF.YAML.Attributes,
  Kitto.Config.Reader;

type
  /// <summary>
  ///  Display/parse format overrides applied to the process FormatSettings at
  ///  startup. Every value is optional: an empty/absent entry keeps the value
  ///  inherited from the operating-system locale.
  ///  YAML path: UserFormats
  /// </summary>
  /// <example>
  ///  UserFormats:
  ///    Date: dd/mm/yyyy
  ///    Time: hh:nn:ss
  ///    Decimal: ','
  ///    Thousand: '.'
  ///    Currency: '&#8364;'
  /// </example>
  TKUserFormatsConfig = class(TKConfigReader)
  private
    FDate: string;
    FTime: string;
    FDecimal: string;
    FThousand: string;
    FCurrency: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('Date', 'Date display format (empty = OS locale)')]
    property Date: string read FDate;

    [YamlNode('Time', 'Time display format (empty = OS locale)')]
    property Time: string read FTime;

    [YamlNode('Decimal', 'Decimal separator, single char (empty = OS locale)')]
    property Decimal: string read FDecimal;

    [YamlNode('Thousand', 'Thousand separator, single char (empty = OS locale)')]
    property Thousand: string read FThousand;

    [YamlNode('Currency', 'Currency string/symbol (empty = OS locale)')]
    property Currency: string read FCurrency;

    [YamlNode('DecimalSeparator', 'Decimal separator, single char (long alias of Decimal)')]
    property DecimalSeparator: string read FDecimal;

    [YamlNode('ThousandSeparator', 'Thousand separator, single char (long alias of Thousand)')]
    property ThousandSeparator: string read FThousand;
  end;

implementation

{ TKUserFormatsConfig }

procedure TKUserFormatsConfig.ReadConfig;
begin
  // All defaults are '' (absent = keep OS locale value); the consumer in
  // TKConfig.AfterConstruction applies each only when non-empty.
  FDate := GetString('Date');
  FTime := GetString('Time');
  // Short and long key names are both accepted; the short one wins when both are set.
  FDecimal := GetString('Decimal');
  if FDecimal = '' then
    FDecimal := GetString('DecimalSeparator');
  FThousand := GetString('Thousand');
  if FThousand = '' then
    FThousand := GetString('ThousandSeparator');
  FCurrency := GetString('Currency');
end;

end.
