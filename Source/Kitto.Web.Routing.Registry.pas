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
///   Resource registry for attribute-based routing. Scans classes decorated
///   with [TKXPath] at registration time, caches RTTI method/parameter info,
///   and provides lookup for the activation engine.
/// </summary>
unit Kitto.Web.Routing.Registry;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  System.TypInfo;

type
  /// <summary>How the parameter value is sourced.</summary>
  TKXParamKind = (pkPathParam, pkQueryParam, pkFormParam, pkContext);

  /// <summary>Cached descriptor for a single method parameter.</summary>
  TKXParamInfo = record
    Name: string;            // attribute name (e.g., 'ViewName', 'key', '_op')
    Kind: TKXParamKind;
    RttiParam: TRttiParameter;
  end;

  /// <summary>Cached descriptor for a single handler method.</summary>
  TKXMethodInfo = class
  private
    FRttiMethod: TRttiMethod;
    FSubPath: string;          // method-level [TKXPath] value (e.g., '/data')
    FHttpMethod: string;       // 'GET', 'POST', or '' (ANY)
    FParams: TArray<TKXParamInfo>;
    FFullPathTokens: TArray<string>;  // merged base+sub path, split by '/'
    FLiteralCount: Integer;    // number of non-{param} tokens (for specificity sort)
  public
    property RttiMethod: TRttiMethod read FRttiMethod;
    property SubPath: string read FSubPath;
    property HttpMethod: string read FHttpMethod;
    property Params: TArray<TKXParamInfo> read FParams;
    property FullPathTokens: TArray<string> read FFullPathTokens;
    property LiteralCount: Integer read FLiteralCount;
  end;

  /// <summary>Cached descriptor for a resource class.</summary>
  TKXResourceInfo = class
  private
    FResourceClass: TClass;
    FBasePath: string;         // class-level [TKXPath] value (e.g., '/kx/view/{ViewName}')
    FMethods: TObjectList<TKXMethodInfo>;
  public
    constructor Create;
    destructor Destroy; override;
    property ResourceClass: TClass read FResourceClass;
    property BasePath: string read FBasePath;
    property Methods: TObjectList<TKXMethodInfo> read FMethods;
  end;

  /// <summary>
  ///   Singleton registry of all resource classes. Populated at startup
  ///   via RegisterResource calls in unit initialization sections.
  ///   Thread-safe for reads (populated before request threads start).
  /// </summary>
  TKXResourceRegistry = class
  private
    FResources: TObjectList<TKXResourceInfo>;
    FRttiCtx: TRttiContext;
    class var FInstance: TKXResourceRegistry;
    class function GetInstance: TKXResourceRegistry; static;
    procedure ScanClass(AClass: TClass; AInfo: TKXResourceInfo);
    procedure ScanMethod(AMethod: TRttiMethod; const ABasePath: string;
      AInfo: TKXResourceInfo);
    function SplitPath(const APath: string): TArray<string>;
    function CountLiterals(const ATokens: TArray<string>): Integer;
    procedure SortBySpecificity;
  public
    constructor Create;
    destructor Destroy; override;
    class destructor DestroyClass;
    class property Instance: TKXResourceRegistry read GetInstance;

    procedure RegisterResource(AClass: TClass);
    procedure UnregisterResource(AClass: TClass);
    property Resources: TObjectList<TKXResourceInfo> read FResources;
  end;

implementation

uses
  System.StrUtils,
  System.Generics.Defaults,
  Kitto.Web.Routing.Attributes;

{ TKXResourceInfo }

constructor TKXResourceInfo.Create;
begin
  inherited;
  FMethods := TObjectList<TKXMethodInfo>.Create(True);
end;

destructor TKXResourceInfo.Destroy;
begin
  FreeAndNil(FMethods);
  inherited;
end;

{ TKXResourceRegistry }

constructor TKXResourceRegistry.Create;
begin
  inherited;
  FResources := TObjectList<TKXResourceInfo>.Create(True);
  FRttiCtx := TRttiContext.Create;
end;

destructor TKXResourceRegistry.Destroy;
begin
  FreeAndNil(FResources);
  FRttiCtx.Free;
  inherited;
end;

class destructor TKXResourceRegistry.DestroyClass;
begin
  FreeAndNil(FInstance);
end;

class function TKXResourceRegistry.GetInstance: TKXResourceRegistry;
begin
  if not Assigned(FInstance) then
    FInstance := TKXResourceRegistry.Create;
  Result := FInstance;
end;

function TKXResourceRegistry.SplitPath(const APath: string): TArray<string>;
var
  LPath: string;
  LList: TArray<string>;
  I, LCount: Integer;
begin
  LPath := APath;
  if (LPath <> '') and (LPath[1] = '/') then
    LPath := Copy(LPath, 2, MaxInt);
  if (LPath <> '') and (LPath[Length(LPath)] = '/') then
    LPath := Copy(LPath, 1, Length(LPath) - 1);
  if LPath = '' then
  begin
    Result := nil;
    Exit;
  end;
  LList := LPath.Split(['/']);
  // Filter empty tokens
  LCount := 0;
  for I := 0 to Length(LList) - 1 do
    if LList[I] <> '' then
      Inc(LCount);
  SetLength(Result, LCount);
  LCount := 0;
  for I := 0 to Length(LList) - 1 do
    if LList[I] <> '' then
    begin
      Result[LCount] := LList[I];
      Inc(LCount);
    end;
end;

function TKXResourceRegistry.CountLiterals(const ATokens: TArray<string>): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Length(ATokens) - 1 do
    if (ATokens[I] = '') or (ATokens[I][1] <> '{') then
      Inc(Result);
end;

procedure TKXResourceRegistry.ScanMethod(AMethod: TRttiMethod;
  const ABasePath: string; AInfo: TKXResourceInfo);
var
  LAttr: TCustomAttribute;
  LSubPath, LHttpMethod, LFullPath: string;
  LHasPath, LHasHttpMethod: Boolean;
  LMethodInfo: TKXMethodInfo;
  LParams: TArray<TRttiParameter>;
  I: Integer;
  LParamInfos: TList<TKXParamInfo>;
  LParamInfo: TKXParamInfo;
begin
  LSubPath := '';
  LHttpMethod := '';
  LHasPath := False;
  LHasHttpMethod := False;

  for LAttr in AMethod.GetAttributes do
  begin
    if LAttr is TKXPathAttribute then
    begin
      LSubPath := TKXPathAttribute(LAttr).Value;
      LHasPath := True;
    end
    else if LAttr is TKXGETAttribute then
    begin
      LHttpMethod := 'GET';
      LHasHttpMethod := True;
    end
    else if LAttr is TKXPOSTAttribute then
    begin
      LHttpMethod := 'POST';
      LHasHttpMethod := True;
    end
    else if LAttr is TKXANYAttribute then
    begin
      LHttpMethod := '';
      LHasHttpMethod := True;
    end;
  end;

  // A method must have at least a path or HTTP method attribute to be a handler
  if not LHasPath and not LHasHttpMethod then
    Exit;

  LMethodInfo := TKXMethodInfo.Create;
  LMethodInfo.FRttiMethod := AMethod;
  LMethodInfo.FSubPath := LSubPath;
  LMethodInfo.FHttpMethod := LHttpMethod;

  // Build full path tokens
  LFullPath := ABasePath;
  if LSubPath <> '' then
  begin
    if (LFullPath <> '') and (LFullPath[Length(LFullPath)] = '/') then
      LFullPath := Copy(LFullPath, 1, Length(LFullPath) - 1);
    if (LSubPath <> '') and (LSubPath[1] <> '/') then
      LFullPath := LFullPath + '/';
    LFullPath := LFullPath + LSubPath;
  end;
  LMethodInfo.FFullPathTokens := SplitPath(LFullPath);
  LMethodInfo.FLiteralCount := CountLiterals(LMethodInfo.FFullPathTokens);

  // Scan parameters
  LParams := AMethod.GetParameters;
  LParamInfos := TList<TKXParamInfo>.Create;
  try
    for I := 0 to Length(LParams) - 1 do
    begin
      LParamInfo.Name := '';
      LParamInfo.Kind := pkContext; // default
      LParamInfo.RttiParam := LParams[I];

      for LAttr in LParams[I].GetAttributes do
      begin
        if LAttr is TKXPathParamAttribute then
        begin
          LParamInfo.Kind := pkPathParam;
          LParamInfo.Name := TKXPathParamAttribute(LAttr).Name;
        end
        else if LAttr is TKXQueryParamAttribute then
        begin
          LParamInfo.Kind := pkQueryParam;
          LParamInfo.Name := TKXQueryParamAttribute(LAttr).Name;
        end
        else if LAttr is TKXFormParamAttribute then
        begin
          LParamInfo.Kind := pkFormParam;
          LParamInfo.Name := TKXFormParamAttribute(LAttr).Name;
        end
        else if LAttr is TKXContextAttribute then
        begin
          LParamInfo.Kind := pkContext;
          LParamInfo.Name := '';
        end;
      end;
      LParamInfos.Add(LParamInfo);
    end;
    LMethodInfo.FParams := LParamInfos.ToArray;
  finally
    LParamInfos.Free;
  end;

  AInfo.Methods.Add(LMethodInfo);
end;

procedure TKXResourceRegistry.ScanClass(AClass: TClass; AInfo: TKXResourceInfo);
var
  LType: TRttiType;
  LAttr: TCustomAttribute;
  LMethod: TRttiMethod;
begin
  LType := FRttiCtx.GetType(AClass);
  if not Assigned(LType) then
    Exit;

  // Read class-level [TKXPath]
  AInfo.FResourceClass := AClass;
  AInfo.FBasePath := '';
  for LAttr in LType.GetAttributes do
  begin
    if LAttr is TKXPathAttribute then
    begin
      AInfo.FBasePath := TKXPathAttribute(LAttr).Value;
      Break;
    end;
  end;

  // Scan public methods
  for LMethod in LType.GetMethods do
  begin
    if LMethod.Visibility in [mvPublic, mvPublished] then
      ScanMethod(LMethod, AInfo.BasePath, AInfo);
  end;
end;

function CompareResourceSpecificity(const L, R: TKXResourceInfo): Integer;
var
  LMaxL, LMaxR: Integer;
  I: Integer;
begin
  // Compare by max method specificity in each resource
  LMaxL := 0;
  for I := 0 to L.Methods.Count - 1 do
    if L.Methods[I].LiteralCount > LMaxL then
      LMaxL := L.Methods[I].LiteralCount;
  LMaxR := 0;
  for I := 0 to R.Methods.Count - 1 do
    if R.Methods[I].LiteralCount > LMaxR then
      LMaxR := R.Methods[I].LiteralCount;
  // Higher specificity first (descending)
  Result := LMaxR - LMaxL;
end;

procedure TKXResourceRegistry.SortBySpecificity;
begin
  // Sort: more literal tokens first (higher specificity wins).
  // This ensures /detail/{Idx}/delete matches before /delete.
  FResources.Sort(TComparer<TKXResourceInfo>.Construct(CompareResourceSpecificity));
end;

procedure TKXResourceRegistry.RegisterResource(AClass: TClass);
var
  LInfo: TKXResourceInfo;
begin
  LInfo := TKXResourceInfo.Create;
  try
    ScanClass(AClass, LInfo);
    if LInfo.Methods.Count = 0 then
    begin
      FreeAndNil(LInfo);
      Exit;
    end;
    FResources.Add(LInfo);
    SortBySpecificity;
  except
    FreeAndNil(LInfo);
    raise;
  end;
end;

procedure TKXResourceRegistry.UnregisterResource(AClass: TClass);
var
  I: Integer;
begin
  for I := FResources.Count - 1 downto 0 do
    if FResources[I].ResourceClass = AClass then
    begin
      FResources.Delete(I);
      Break;
    end;
end;

end.
