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
///  Date/time format conversion utilities.
///  Compatibility unit providing format conversion methods originally
///  from the ExtJS wrapper layer.
/// </summary>
unit Kitto.JS.Formatting;

{$I Kitto.Defines.inc}

interface

type
  TJS = class
  public
    /// <summary>Converts a Delphi date/time format string to the equivalent JavaScript format.</summary>
    class function DelphiDateTimeFormatToJSDateTimeFormat(const ADateTimeFormat: string): string;
    /// <summary>Converts a Delphi date format string to the equivalent JavaScript format.</summary>
    class function DelphiDateFormatToJSDateFormat(const ADateFormat: string): string;
    /// <summary>Converts a Delphi time format string to the equivalent JavaScript format.</summary>
    class function DelphiTimeFormatToJSTimeFormat(const ATimeFormat: string): string;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils;

class function TJS.DelphiDateFormatToJSDateFormat(const ADateFormat: string): string;
begin
  Result := ReplaceText(ADateFormat, 'yyyy', 'Y');
  Result := ReplaceText(Result, 'yy', 'y');
  Result := ReplaceText(Result, 'dd', 'd');
  Result := ReplaceText(Result, 'mm', 'm');
end;

class function TJS.DelphiTimeFormatToJSTimeFormat(const ATimeFormat: string): string;
begin
  Result := ReplaceText(ATimeFormat, 'hh', 'H');
  Result := ReplaceText(Result, 'mm', 'i');
  Result := ReplaceText(Result, 'nn', 'i');
  Result := ReplaceText(Result, 'ss', 's');
end;

class function TJS.DelphiDateTimeFormatToJSDateTimeFormat(const ADateTimeFormat: string): string;
var
  LFormats: TArray<string>;
begin
  LFormats := ADateTimeFormat.Split([' '], 2);
  if Length(LFormats) >= 2 then
    Result := DelphiDateFormatToJSDateFormat(LFormats[0]) + ' ' + DelphiTimeFormatToJSTimeFormat(LFormats[1])
  else
    Result := DelphiDateFormatToJSDateFormat(ADateTimeFormat);
end;

end.
