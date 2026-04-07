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
///   Registry for dynamic script and CSS injection. Modules register their
///   required JS/CSS files in their initialization section. The page template
///   engine queries this registry to emit the appropriate tags.
/// </summary>
unit Kitto.Web.Routing.Scripts;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TKXScriptKind = (skScript, skStylesheet);

  TKXScriptEntry = record
    Path: string;        // relative path, e.g. '/js/chart.umd.min.js'
    Kind: TKXScriptKind;
    Defer: Boolean;      // add 'defer' attribute (for scripts only)
  end;

  /// <summary>
  ///   Singleton registry. Modules call RegisterScript/RegisterStylesheet
  ///   in their initialization sections. The page template queries
  ///   GetScriptTags to emit all registered resources as HTML tags.
  /// </summary>
  TKXScriptRegistry = class
  private
    FEntries: TList<TKXScriptEntry>;
    class var FInstance: TKXScriptRegistry;
    class function GetInstance: TKXScriptRegistry; static;
    function HasPath(const APath: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    class destructor DestroyClass;
    class property Instance: TKXScriptRegistry read GetInstance;

    /// <summary>Registers a JavaScript file (e.g. '/js/chart.umd.min.js').</summary>
    procedure RegisterScript(const APath: string; const ADefer: Boolean = False);

    /// <summary>Registers a CSS stylesheet (e.g. '/css/event-calendar.min.css').</summary>
    procedure RegisterStylesheet(const APath: string);

    /// <summary>
    ///   Returns HTML tags for all registered scripts, using the given
    ///   resource base path (e.g. '/myapp/res').
    /// </summary>
    function GetScriptTags(const AResPath: string): string;

    /// <summary>
    ///   Returns HTML tags for all registered stylesheets, using the given
    ///   resource base path.
    /// </summary>
    function GetStylesheetTags(const AResPath: string): string;
  end;

implementation

uses
  System.StrUtils;

{ TKXScriptRegistry }

constructor TKXScriptRegistry.Create;
begin
  inherited;
  FEntries := TList<TKXScriptEntry>.Create;
end;

destructor TKXScriptRegistry.Destroy;
begin
  FreeAndNil(FEntries);
  inherited;
end;

class destructor TKXScriptRegistry.DestroyClass;
begin
  FreeAndNil(FInstance);
end;

class function TKXScriptRegistry.GetInstance: TKXScriptRegistry;
begin
  if not Assigned(FInstance) then
    FInstance := TKXScriptRegistry.Create;
  Result := FInstance;
end;

function TKXScriptRegistry.HasPath(const APath: string): Boolean;
var
  I: Integer;
begin
  for I := 0 to FEntries.Count - 1 do
    if SameText(FEntries[I].Path, APath) then
      Exit(True);
  Result := False;
end;

procedure TKXScriptRegistry.RegisterScript(const APath: string; const ADefer: Boolean);
var
  LEntry: TKXScriptEntry;
begin
  if HasPath(APath) then
    Exit;
  LEntry.Path := APath;
  LEntry.Kind := skScript;
  LEntry.Defer := ADefer;
  FEntries.Add(LEntry);
end;

procedure TKXScriptRegistry.RegisterStylesheet(const APath: string);
var
  LEntry: TKXScriptEntry;
begin
  if HasPath(APath) then
    Exit;
  LEntry.Path := APath;
  LEntry.Kind := skStylesheet;
  LEntry.Defer := False;
  FEntries.Add(LEntry);
end;

function TKXScriptRegistry.GetScriptTags(const AResPath: string): string;
var
  I: Integer;
  LEntry: TKXScriptEntry;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    for I := 0 to FEntries.Count - 1 do
    begin
      LEntry := FEntries[I];
      if LEntry.Kind = skScript then
      begin
        SB.Append('  <script src="').Append(AResPath).Append(LEntry.Path).Append('"');
        if LEntry.Defer then
          SB.Append(' defer');
        SB.Append('></script>').AppendLine;
      end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXScriptRegistry.GetStylesheetTags(const AResPath: string): string;
var
  I: Integer;
  LEntry: TKXScriptEntry;
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    for I := 0 to FEntries.Count - 1 do
    begin
      LEntry := FEntries[I];
      if LEntry.Kind = skStylesheet then
        SB.Append('  <link rel="stylesheet" href="').Append(AResPath).Append(LEntry.Path).Append('">').AppendLine;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

end.
