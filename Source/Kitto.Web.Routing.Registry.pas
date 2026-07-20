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
  TKXParamKind = (pkPathParam, pkQueryParam, pkFormParam, pkFormBody, pkContext);

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
    FIsAnonymous: Boolean;     // [TKXAnonymous] — skip the auth gate for this method
    FIsNavigable: Boolean;     // [TKXNavigable] — reachable by top-level navigation
  public
    /// <summary>The RTTI method this descriptor was built from (used to invoke it).</summary>
    property RttiMethod: TRttiMethod read FRttiMethod;
    /// <summary>The method-level [TKXPath] sub-path (e.g. '/data'); '' if none.</summary>
    property SubPath: string read FSubPath;
    /// <summary>Accepted HTTP method ('GET'/'POST'/…); '' means any ([TKXANY]).</summary>
    property HttpMethod: string read FHttpMethod;
    /// <summary>Cached descriptors of the method's parameters, in declaration order.</summary>
    property Params: TArray<TKXParamInfo> read FParams;
    /// <summary>Full path (base + sub) split into tokens, used for URL matching.</summary>
    property FullPathTokens: TArray<string> read FFullPathTokens;
    /// <summary>Count of literal (non-{param}) tokens; higher = more specific route.</summary>
    property LiteralCount: Integer read FLiteralCount;
    /// <summary>True if decorated with [TKXAnonymous] (skips the authentication gate).</summary>
    property IsAnonymous: Boolean read FIsAnonymous;
    /// <summary>True if decorated with [TKXNavigable] (reachable by direct navigation).</summary>
    property IsNavigable: Boolean read FIsNavigable;
  end;

  /// <summary>Cached descriptor for a resource class.</summary>
  TKXResourceInfo = class
  private
    FResourceClass: TClass;
    FBasePath: string;         // class-level [TKXPath] value (e.g., '/kx/view/{ViewName}')
    FMethods: TObjectList<TKXMethodInfo>;
  public
    /// <summary>Creates the descriptor with an empty (owned) method list.</summary>
    constructor Create;
    /// <summary>Frees the owned method descriptors.</summary>
    destructor Destroy; override;
    /// <summary>The resource (handler) class this descriptor represents.</summary>
    property ResourceClass: TClass read FResourceClass;
    /// <summary>The class-level [TKXPath] base path (e.g. '/kx/view/{ViewName}').</summary>
    property BasePath: string read FBasePath;
    /// <summary>The handler methods discovered on the class (owned).</summary>
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
    /// <summary>Creates the registry with an empty (owned) resource list.</summary>
    constructor Create;
    /// <summary>Frees the owned resource descriptors and the RTTI context.</summary>
    destructor Destroy; override;
    /// <summary>Frees the singleton instance at unit finalization.</summary>
    class destructor DestroyClass;
    /// <summary>The lazily-created singleton registry instance.</summary>
    class property Instance: TKXResourceRegistry read GetInstance;

    /// <summary>Scans AClass via RTTI and registers its [TKXPath] handler methods,
    /// then re-sorts by specificity. No-op if the class exposes no handler method.</summary>
    procedure RegisterResource(AClass: TClass);
    /// <summary>
    ///   Registers AClass in place of the framework handler(s) sharing its base
    ///   [TKXPath], letting an application replace an endpoint by subclassing —
    ///   without forking the framework. Typical use from UseKitto.pas:
    ///     type TMyView = class(TKXViewHandlerBase) ... end;
    ///     TKXResourceRegistry.Instance.RegisterOverride(TMyView);
    ///   The base path is inherited from the ancestor, and RTTI GetMethods
    ///   surfaces every inherited route, so only the endpoint(s) actually
    ///   overridden must re-declare their routing attributes; overrides that
    ///   only customize virtual hooks (OnBeforeSave, …) need nothing extra.
    /// </summary>
    procedure RegisterOverride(AClass: TClass);
    /// <summary>Removes the resource registered for AClass, if present.</summary>
    procedure UnregisterResource(AClass: TClass);
    /// <summary>All registered resource descriptors, sorted by descending specificity.</summary>
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
  LHasPath, LHasHttpMethod, LIsAnonymous, LIsNavigable: Boolean;
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
  LIsAnonymous := False;
  LIsNavigable := False;

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
    end
    else if LAttr is TKXAnonymousAttribute then
      LIsAnonymous := True
    else if LAttr is TKXNavigableAttribute then
      LIsNavigable := True;
  end;

  // A method must have at least a path or HTTP method attribute to be a handler
  if not LHasPath and not LHasHttpMethod then
    Exit;

  LMethodInfo := TKXMethodInfo.Create;
  LMethodInfo.FRttiMethod := AMethod;
  LMethodInfo.FSubPath := LSubPath;
  LMethodInfo.FHttpMethod := LHttpMethod;
  LMethodInfo.FIsAnonymous := LIsAnonymous;
  LMethodInfo.FIsNavigable := LIsNavigable;

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
        else if LAttr is TKXFormBodyAttribute then
        begin
          LParamInfo.Kind := pkFormBody;
          LParamInfo.Name := '';
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
  LWalkType: TRttiType;
  LWalkClass: TClass;
  LAttr: TCustomAttribute;
  LMethod: TRttiMethod;
  LFound: Boolean;
begin
  LType := FRttiCtx.GetType(AClass);
  if not Assigned(LType) then
    Exit;

  // Read class-level [TKXPath], walking up the hierarchy so a subclass that
  // does NOT redeclare [TKXPath] inherits its ancestor's base path. Delphi RTTI
  // does not inherit class attributes, so this makes RegisterOverride ergonomic:
  // an override class need only re-declare the endpoint(s) it changes.
  AInfo.FResourceClass := AClass;
  AInfo.FBasePath := '';
  LWalkClass := AClass;
  while Assigned(LWalkClass) do
  begin
    LFound := False;
    LWalkType := FRttiCtx.GetType(LWalkClass);
    if Assigned(LWalkType) then
      for LAttr in LWalkType.GetAttributes do
        if LAttr is TKXPathAttribute then
        begin
          AInfo.FBasePath := TKXPathAttribute(LAttr).Value;
          LFound := True;
          Break;
        end;
    if LFound then
      Break;
    LWalkClass := LWalkClass.ClassParent;
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

procedure TKXResourceRegistry.RegisterOverride(AClass: TClass);
var
  LTempInfo: TKXResourceInfo;
  LBasePath: string;
  I: Integer;
begin
  // Scan AClass into a throwaway info to learn its (possibly inherited) base
  // path, then drop every currently-registered resource that shares that base
  // path (the framework handler being replaced) before registering AClass.
  LTempInfo := TKXResourceInfo.Create;
  try
    ScanClass(AClass, LTempInfo);
    LBasePath := LTempInfo.BasePath;
  finally
    FreeAndNil(LTempInfo);
  end;

  if LBasePath <> '' then
    for I := FResources.Count - 1 downto 0 do
      if SameText(FResources[I].BasePath, LBasePath) and
         (FResources[I].ResourceClass <> AClass) then
        FResources.Delete(I);

  RegisterResource(AClass);
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
