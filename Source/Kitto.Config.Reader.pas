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
///  Base class for typed config readers. A config reader reads a subtree of the
///  application configuration (a static YAML file, loaded once and cached on the
///  app-global TKConfig.Instance singleton) ONCE into typed fields, so the
///  runtime accesses values as, e.g., Config.Server.Port instead of repeated
///  Config.GetInteger('Server/Port') tree lookups. The same class carries the
///  [YamlNode]/[YamlSubNode] attributes that KIDE reads via RTTI to drive the
///  Config editor.
///
///  Lifecycle: the reader instance is STABLE for the life of TKConfig. On a
///  forced config reload (TKConfig.InvalidateConfig, typically for debugging) the
///  instance is not recreated — Refresh re-reads the fields in place, so any code
///  holding a reference (e.g. a cached Config.Server) keeps working.
///
///  Reading is nil-safe: a reader bound to a missing node (ANode = nil) returns
///  the declared defaults, so a subtree absent from the YAML needs no special
///  handling and no placeholder nodes are created in the tree.
/// </summary>
unit Kitto.Config.Reader;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree;

type
  TKConfigReader = class
  private
    FNode: TEFTree;
  protected
    /// <summary>Reads all fields from Node (nil-safe). Called by Create and by
    /// Refresh. Descendants override this and assign their F-fields using the
    /// GetInteger/GetString/... helpers below.</summary>
    procedure ReadConfig; virtual; abstract;

    /// <summary>The subtree this reader is bound to; nil when the node is absent
    /// from the YAML (the Get* helpers then return their defaults).</summary>
    property Node: TEFTree read FNode;

    // nil-safe readers over Node (missing node or missing path -> ADefault).
    function GetInteger(const APath: string; const ADefault: Integer = 0): Integer;
    function GetString(const APath: string; const ADefault: string = ''): string;
    function GetBoolean(const APath: string; const ADefault: Boolean = False): Boolean;
    function GetExpandedString(const APath: string; const ADefault: string = ''): string;

    /// <summary>Returns the child subtree at APath to bind a nested reader to,
    /// or nil when absent (nil-safe). Use it to create/refresh sub-readers, e.g.
    /// FJobs.Refresh(SubNode('Jobs')).</summary>
    function SubNode(const APath: string): TEFTree;
  public
    /// <summary>Binds the reader to ANode and reads all fields once.</summary>
    constructor Create(const ANode: TEFTree);

    /// <summary>Re-binds to ANode and re-reads all fields IN PLACE (keeps the
    /// instance stable across a forced config reload).</summary>
    procedure Refresh(const ANode: TEFTree);
  end;

implementation

{ TKConfigReader }

constructor TKConfigReader.Create(const ANode: TEFTree);
begin
  inherited Create;
  Refresh(ANode);
end;

procedure TKConfigReader.Refresh(const ANode: TEFTree);
begin
  FNode := ANode;
  ReadConfig;
end;

function TKConfigReader.GetInteger(const APath: string; const ADefault: Integer): Integer;
begin
  if FNode = nil then
    Result := ADefault
  else
    Result := FNode.GetInteger(APath, ADefault);
end;

function TKConfigReader.GetString(const APath: string; const ADefault: string): string;
begin
  if FNode = nil then
    Result := ADefault
  else
    Result := FNode.GetString(APath, ADefault);
end;

function TKConfigReader.GetBoolean(const APath: string; const ADefault: Boolean): Boolean;
begin
  if FNode = nil then
    Result := ADefault
  else
    Result := FNode.GetBoolean(APath, ADefault);
end;

function TKConfigReader.GetExpandedString(const APath: string; const ADefault: string): string;
begin
  if FNode = nil then
    Result := ADefault
  else
    Result := FNode.GetExpandedString(APath, ADefault);
end;

function TKConfigReader.SubNode(const APath: string): TEFTree;
begin
  if FNode = nil then
    Result := nil
  else
    Result := FNode.FindNode(APath, False);
end;

end.
