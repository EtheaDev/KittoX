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
///   JWT runtime infrastructure for KittoX authentication.
///   Wraps the delphi-jose-jwt library (paolo-rossi) with KittoX-specific
///   configuration parsing, key resolution, claims construction, validation
///   and cookie issuance helpers.
/// </summary>
unit Kitto.Web.JWT;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Generics.Collections,
  System.JSON,
  System.Rtti,
  EF.Tree,
  EF.Types,
  JOSE.Core.JWA,
  JOSE.Core.JWT,
  JOSE.Core.JWK,
  JOSE.Producer,
  JOSE.Consumer,
  JOSE.Types.Bytes;

type
  EKJWTError = class(Exception);

  TKJWTRoles = TArray<string>;

  /// <summary>
  ///  Single ACL row carried by the kx_acl claim. Mirrors the three columns of
  ///  the KITTO_PERMISSIONS table the DB access controller reads:
  ///    Pattern    — RESOURCE_URI_PATTERN (wildcards * ?, REGEX:, ~ negation)
  ///    Modes      — comma-separated list of ACM_* mode codes (V/M/E/A/D/R)
  ///    GrantValue — '0' / '1' for boolean grants, any string for non-standard modes
  ///  Serialised in the JWT as a 3-element JSON array [pattern, modes, grant].
  /// </summary>
  TKJWTAclEntry = record
    Pattern: string;
    Modes: string;
    GrantValue: string;
  end;

  TKJWTAclArray = TArray<TKJWTAclEntry>;

  /// <summary>
  ///  Strongly-typed view of validated JWT claims used by the KittoX runtime.
  ///  Populated by TKJWTValidator on a successful Validate call.
  /// </summary>
  TKJWTContext = record
    UserName: string;
    DisplayName: string;
    DatabaseName: string;
    Language: string;
    Roles: TKJWTRoles;
    /// Custom KittoX claim used to correlate to TKWebSession.SessionId.
    Sid: string;
    /// Standard JWT id (jti).
    Jti: string;
    IssuedAt: TDateTime;
    Expiration: TDateTime;
    NotBefore: TDateTime;
    Issuer: string;
    Audience: string;
    /// Raw token compact form, kept for cookie refresh decisions.
    CompactToken: string;
    IsValid: Boolean;
    /// ACL grant rows snapshotted at login time when AccessControl: JWT is
    /// configured (the framework sets IncludeACL automatically based on the
    /// configured access controller). Empty otherwise.
    Acl: TKJWTAclArray;
    HasAcl: Boolean;
    procedure Clear;
    function HasRole(const ARole: string): Boolean;
  end;

  /// <summary>
  ///  Resolved signing material. For HS* algorithms only PrivateKey is used.
  ///  For RS*/ES* PrivateKey is the PEM private key, PublicKey is the PEM
  ///  public key (verifier-only deploys can configure PublicKey alone).
  /// </summary>
  TKJWTSigningKey = record
    Algorithm: TJOSEAlgorithmId;
    PrivateKey: TBytes;
    PublicKey: TBytes;
    function HasPrivateKey: Boolean;
    function HasPublicKey: Boolean;
    function IsSymmetric: Boolean;
    procedure Clear;
  end;

  /// <summary>
  ///  Optional callback that returns the signing key, used as an override
  ///  point from UseKitto.pas when the key must be loaded from a vault or
  ///  similar external store. Registered via TKJWTSigningKeyRegistry.
  /// </summary>
  TKJWTSigningKeyProvider = reference to function: TKJWTSigningKey;

  /// <summary>
  ///  Process-wide registry of signing key providers, scoped by app name.
  /// </summary>
  TKJWTSigningKeyRegistry = class
  strict private
    class var FInstance: TKJWTSigningKeyRegistry;
    FProviders: TDictionary<string, TKJWTSigningKeyProvider>;
    class function GetInstance: TKJWTSigningKeyRegistry; static;
  public
    constructor Create;
    destructor Destroy; override;
    class destructor ClassDestroy;

    procedure RegisterProvider(const AAppName: string;
      const AProvider: TKJWTSigningKeyProvider);
    procedure UnregisterProvider(const AAppName: string);
    function FindProvider(const AAppName: string): TKJWTSigningKeyProvider;

    class property Instance: TKJWTSigningKeyRegistry read GetInstance;
  end;

  /// <summary>
  ///  Parsed configuration extracted from the Auth/JWT YAML node.
  /// </summary>
  TKJWTConfig = class
  strict private
    FAppName: string;
    FAuthNode: TEFTree;
    FAlgorithm: TJOSEAlgorithmId;
    FKeySpec: string;
    FPublicKeySpec: string;
    FIssuer: string;
    FAudience: string;
    FTokenLifetimeSeconds: Integer;
    FSlidingThresholdSeconds: Integer;
    FClockSkewSeconds: Integer;
    FCookieName: string;
    FCookiePath: string;
    FCookieSecure: Boolean;
    FCookieHttpOnly: Boolean;
    FCookieSameSite: string;
    FIncludeRoles: Boolean;
    FIncludeDB: Boolean;
    FIncludeDisplayName: Boolean;
    FIncludeLanguage: Boolean;
    FIncludeACL: Boolean;
    FResolvedKey: TKJWTSigningKey;
    FKeyResolved: Boolean;
    procedure Parse;
    procedure ResolveKey;
  public
    constructor Create(const AAppName: string; const AAuthNode: TEFTree);
    destructor Destroy; override;

    property AppName: string read FAppName;
    property Algorithm: TJOSEAlgorithmId read FAlgorithm;
    property Issuer: string read FIssuer;
    property Audience: string read FAudience;
    property TokenLifetimeSeconds: Integer read FTokenLifetimeSeconds;
    property SlidingThresholdSeconds: Integer read FSlidingThresholdSeconds;
    property ClockSkewSeconds: Integer read FClockSkewSeconds;
    property CookieName: string read FCookieName;
    property CookiePath: string read FCookiePath write FCookiePath;
    property CookieSecure: Boolean read FCookieSecure;
    property CookieHttpOnly: Boolean read FCookieHttpOnly;
    property CookieSameSite: string read FCookieSameSite;
    property IncludeRoles: Boolean read FIncludeRoles;
    property IncludeDB: Boolean read FIncludeDB;
    property IncludeDisplayName: Boolean read FIncludeDisplayName;
    property IncludeLanguage: Boolean read FIncludeLanguage;
    property IncludeACL: Boolean read FIncludeACL;

    function GetSigningKey: TKJWTSigningKey;
  end;

  /// <summary>
  ///  Builds a compact JWT from a TKJWTContext + signing config. Stateless.
  /// </summary>
  TKJWTBuilder = class
  public
    class function Build(const AContext: TKJWTContext;
      const AConfig: TKJWTConfig;
      const AExtraClaims: TArray<TPair<string, string>> = nil): string;
  end;

  /// <summary>
  ///  Validates a compact JWT against config + signing key. Stateless.
  /// </summary>
  TKJWTValidator = class
  public
    class function Validate(const ACompactToken: string;
      const AConfig: TKJWTConfig; out AContext: TKJWTContext;
      out AErrorMessage: string): Boolean;
  end;

  /// <summary>
  ///  Cookie helpers.
  /// </summary>
  TKJWTCookieHelper = class
  public
    class procedure Issue(const ACompactToken: string; const AConfig: TKJWTConfig);
    class procedure Clear(const AConfig: TKJWTConfig);
    class function ReadFromRequest(const AConfig: TKJWTConfig): string;
    class function ShouldSlide(const AContext: TKJWTContext;
      const AConfig: TKJWTConfig): Boolean;
  end;

function StringToAlgorithmId(const S: string): TJOSEAlgorithmId;
function ResolveKeySpec(const ASpec: string): TBytes;

/// <summary>
///  Decodes the payload portion of a compact JWT without verifying the
///  signature, and extracts the 'sid' custom claim if present. Used by the
///  engine to correlate the request to a server-side TKWebSession before
///  the JWT signature is verified by the application's auth gate. Safety:
///  signature is still verified later before any authenticated operation,
///  so the unsafe decode here only affects which session object is bound
///  to the current thread — it cannot grant any privilege.
/// </summary>
function TryDecodeSidFromJWT(const ACompactToken: string; out ASid: string): Boolean;

implementation

uses
  System.NetEncoding,
  System.IOUtils,
  System.StrUtils,
  EF.StrUtils,
  EF.Logger,
  Kitto.Config,
  Kitto.Web.Request,
  Kitto.Web.Response,
  JOSE.Core.Base,
  JOSE.Core.Builder,
  JOSE.Core.JWS,
  JOSE.Context,
  JOSE.Consumer.Validators;

const
  DEFAULT_TOKEN_LIFETIME = 3600;
  DEFAULT_SLIDING_THRESHOLD = 600;
  DEFAULT_CLOCK_SKEW = 60;
  DEFAULT_COOKIE_NAME = 'kx_token';
  DEFAULT_COOKIE_SAMESITE = 'Lax';
  CLAIM_SID = 'sid';
  CLAIM_DB = 'db';
  CLAIM_NAME = 'name';
  CLAIM_ROLES = 'roles';
  CLAIM_LANG = 'lang';
  CLAIM_ACL = 'kx_acl';

{ Helpers — declared at the top so they are visible to all class methods below. }

function StringToAlgorithmId(const S: string): TJOSEAlgorithmId;
var
  LUpper: string;
begin
  LUpper := UpperCase(Trim(S));
  if LUpper = 'HS256' then Exit(TJOSEAlgorithmId.HS256);
  if LUpper = 'HS384' then Exit(TJOSEAlgorithmId.HS384);
  if LUpper = 'HS512' then Exit(TJOSEAlgorithmId.HS512);
  if LUpper = 'RS256' then Exit(TJOSEAlgorithmId.RS256);
  if LUpper = 'RS384' then Exit(TJOSEAlgorithmId.RS384);
  if LUpper = 'RS512' then Exit(TJOSEAlgorithmId.RS512);
  if LUpper = 'ES256' then Exit(TJOSEAlgorithmId.ES256);
  if LUpper = 'ES384' then Exit(TJOSEAlgorithmId.ES384);
  if LUpper = 'ES512' then Exit(TJOSEAlgorithmId.ES512);
  Result := TJOSEAlgorithmId.Unknown;
end;

function IsSymmetricAlgorithm(const A: TJOSEAlgorithmId): Boolean;
begin
  Result := A in [TJOSEAlgorithmId.HS256, TJOSEAlgorithmId.HS384, TJOSEAlgorithmId.HS512];
end;

function ResolveKeySpec(const ASpec: string): TBytes;
var
  LSpec, LEnvName, LFileName, LValue: string;
begin
  LSpec := Trim(ASpec);
  if LSpec = '' then
    Exit(nil);

  if StartsText('env:', LSpec) then
  begin
    LEnvName := Copy(LSpec, 5, MaxInt);
    LValue := GetEnvironmentVariable(LEnvName);
    if LValue = '' then
      raise EKJWTError.CreateFmt('Environment variable %s for JWT signing key is not set',
        [LEnvName]);
    Result := TEncoding.UTF8.GetBytes(LValue);
    Exit;
  end;

  if StartsText('file:', LSpec) then
  begin
    LFileName := Copy(LSpec, 6, MaxInt);
    if not TFile.Exists(LFileName) then
      raise EKJWTError.CreateFmt('JWT signing key file not found: %s', [LFileName]);
    Result := TFile.ReadAllBytes(LFileName);
    Exit;
  end;

  // Inline literal — used for dev/testing only.
  Result := TEncoding.UTF8.GetBytes(LSpec);
end;

function BytesToJOSEBytes(const AB: TBytes): TJOSEBytes;
begin
  // Implicit conversion via TJOSEBytes operator Implicit(TBytes).
  Result := AB;
end;

function Base64UrlDecode(const AInput: string): TBytes;
var
  LSafe: string;
  LPad: Integer;
begin
  // base64url -> base64 (RFC 4648 §5): replace - with +, _ with /, pad to mod 4 with '='.
  LSafe := StringReplace(AInput, '-', '+', [rfReplaceAll]);
  LSafe := StringReplace(LSafe, '_', '/', [rfReplaceAll]);
  LPad := Length(LSafe) mod 4;
  if LPad > 0 then
    LSafe := LSafe + StringOfChar('=', 4 - LPad);
  Result := TNetEncoding.Base64.DecodeStringToBytes(LSafe);
end;

function TryDecodeSidFromJWT(const ACompactToken: string; out ASid: string): Boolean;
var
  LParts: TArray<string>;
  LJsonBytes: TBytes;
  LJson: TJSONObject;
  LValue: TJSONValue;
begin
  Result := False;
  ASid := '';
  if Trim(ACompactToken) = '' then
    Exit;
  LParts := ACompactToken.Split(['.']);
  if Length(LParts) < 2 then
    Exit;
  try
    LJsonBytes := Base64UrlDecode(LParts[1]);
    LJson := TJSONObject.ParseJSONValue(TEncoding.UTF8.GetString(LJsonBytes)) as TJSONObject;
    if not Assigned(LJson) then
      Exit;
    try
      LValue := LJson.GetValue('sid');
      if Assigned(LValue) then
      begin
        ASid := LValue.Value;
        Result := ASid <> '';
      end;
    finally
      LJson.Free;
    end;
  except
    on E: Exception do
    begin
      // Malformed token — silently fall back. The engine will create a fresh
      // session and the auth gate will redirect the user to the login page.
      Result := False;
    end;
  end;
end;

function StringToJOSEBytes(const S: string): TJOSEBytes;
begin
  Result := S;
end;

function EncodeRolesAsCSV(const ARoles: TKJWTRoles): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ARoles) do
  begin
    if I > 0 then
      Result := Result + ',';
    Result := Result + ARoles[I];
  end;
end;

function DecodeRolesFromCSV(const ACSV: string): TKJWTRoles;
var
  LParts: TArray<string>;
  I: Integer;
begin
  if Trim(ACSV) = '' then
    Exit(nil);
  LParts := ACSV.Split([',']);
  SetLength(Result, Length(LParts));
  for I := 0 to High(LParts) do
    Result[I] := Trim(LParts[I]);
end;

function EncodeAclAsJsonString(const AAcl: TKJWTAclArray): string;
var
  LRoot, LEntry: TJSONArray;
  I: Integer;
begin
  if Length(AAcl) = 0 then
    Exit('');
  LRoot := TJSONArray.Create;
  try
    for I := 0 to High(AAcl) do
    begin
      LEntry := TJSONArray.Create;
      LEntry.Add(AAcl[I].Pattern);
      LEntry.Add(AAcl[I].Modes);
      LEntry.Add(AAcl[I].GrantValue);
      LRoot.AddElement(LEntry);
    end;
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function DecodeAclFromJsonString(const AJson: string): TKJWTAclArray;
var
  LParsed: TJSONValue;
  LRoot: TJSONArray;
  LEntry: TJSONArray;
  I: Integer;
begin
  Result := nil;
  if Trim(AJson) = '' then
    Exit;
  LParsed := TJSONObject.ParseJSONValue(AJson);
  if not (LParsed is TJSONArray) then
  begin
    LParsed.Free;
    Exit;
  end;
  LRoot := TJSONArray(LParsed);
  try
    SetLength(Result, LRoot.Count);
    for I := 0 to LRoot.Count - 1 do
    begin
      Result[I].Pattern := '';
      Result[I].Modes := '';
      Result[I].GrantValue := '';
      if not (LRoot.Items[I] is TJSONArray) then
        Continue;
      LEntry := TJSONArray(LRoot.Items[I]);
      if LEntry.Count < 3 then
        Continue;
      Result[I].Pattern := LEntry.Items[0].Value;
      Result[I].Modes := LEntry.Items[1].Value;
      Result[I].GrantValue := LEntry.Items[2].Value;
    end;
  finally
    LRoot.Free;
  end;
end;

{ TKJWTContext }

procedure TKJWTContext.Clear;
begin
  UserName := '';
  DisplayName := '';
  DatabaseName := '';
  Language := '';
  Roles := nil;
  Sid := '';
  Jti := '';
  IssuedAt := 0;
  Expiration := 0;
  NotBefore := 0;
  Issuer := '';
  Audience := '';
  CompactToken := '';
  IsValid := False;
  Acl := nil;
  HasAcl := False;
end;

function TKJWTContext.HasRole(const ARole: string): Boolean;
var
  LRole: string;
begin
  for LRole in Roles do
    if SameText(LRole, ARole) then
      Exit(True);
  Result := False;
end;

{ TKJWTSigningKey }

procedure TKJWTSigningKey.Clear;
begin
  Algorithm := TJOSEAlgorithmId.Unknown;
  PrivateKey := nil;
  PublicKey := nil;
end;

function TKJWTSigningKey.HasPrivateKey: Boolean;
begin
  Result := Length(PrivateKey) > 0;
end;

function TKJWTSigningKey.HasPublicKey: Boolean;
begin
  Result := Length(PublicKey) > 0;
end;

function TKJWTSigningKey.IsSymmetric: Boolean;
begin
  Result := IsSymmetricAlgorithm(Algorithm);
end;

{ TKJWTSigningKeyRegistry }

constructor TKJWTSigningKeyRegistry.Create;
begin
  inherited Create;
  FProviders := TDictionary<string, TKJWTSigningKeyProvider>.Create;
end;

destructor TKJWTSigningKeyRegistry.Destroy;
begin
  FreeAndNil(FProviders);
  inherited;
end;

class destructor TKJWTSigningKeyRegistry.ClassDestroy;
begin
  FreeAndNil(FInstance);
end;

class function TKJWTSigningKeyRegistry.GetInstance: TKJWTSigningKeyRegistry;
begin
  if FInstance = nil then
    FInstance := TKJWTSigningKeyRegistry.Create;
  Result := FInstance;
end;

procedure TKJWTSigningKeyRegistry.RegisterProvider(const AAppName: string;
  const AProvider: TKJWTSigningKeyProvider);
begin
  Assert(Assigned(AProvider));
  FProviders.AddOrSetValue(LowerCase(AAppName), AProvider);
end;

procedure TKJWTSigningKeyRegistry.UnregisterProvider(const AAppName: string);
begin
  FProviders.Remove(LowerCase(AAppName));
end;

function TKJWTSigningKeyRegistry.FindProvider(
  const AAppName: string): TKJWTSigningKeyProvider;
begin
  if not FProviders.TryGetValue(LowerCase(AAppName), Result) then
    if not FProviders.TryGetValue('', Result) then
      Result := nil;
end;

{ TKJWTConfig }

constructor TKJWTConfig.Create(const AAppName: string; const AAuthNode: TEFTree);
begin
  Assert(Assigned(AAuthNode));
  inherited Create;
  FAppName := AAppName;
  FAuthNode := AAuthNode;
  FResolvedKey.Clear;
  FKeyResolved := False;
  Parse;
end;

destructor TKJWTConfig.Destroy;
begin
  inherited;
end;

procedure TKJWTConfig.Parse;
var
  LClaims: TEFNode;
begin
  FAlgorithm := StringToAlgorithmId(FAuthNode.GetString('SigningAlgorithm', 'HS256'));
  if FAlgorithm = TJOSEAlgorithmId.Unknown then
    raise EKJWTError.CreateFmt('Unknown JWT signing algorithm: %s',
      [FAuthNode.GetString('SigningAlgorithm')]);

  FKeySpec := FAuthNode.GetString('SigningKey');
  FPublicKeySpec := FAuthNode.GetString('SigningPublicKey');

  FIssuer := FAuthNode.GetString('Issuer');
  if FIssuer = '' then
    FIssuer := FAppName;

  FAudience := FAuthNode.GetString('Audience', 'kx-app');
  FTokenLifetimeSeconds := FAuthNode.GetInteger('TokenLifetime', DEFAULT_TOKEN_LIFETIME);
  FSlidingThresholdSeconds := FAuthNode.GetInteger('SlidingThreshold', DEFAULT_SLIDING_THRESHOLD);
  FClockSkewSeconds := FAuthNode.GetInteger('ClockSkew', DEFAULT_CLOCK_SKEW);

  FCookieName := FAuthNode.GetString('Cookie/Name', DEFAULT_COOKIE_NAME);
  FCookiePath := FAuthNode.GetString('Cookie/Path');
  FCookieSecure := FAuthNode.GetBoolean('Cookie/Secure', True);
  FCookieHttpOnly := FAuthNode.GetBoolean('Cookie/HttpOnly', True);
  FCookieSameSite := FAuthNode.GetString('Cookie/SameSite', DEFAULT_COOKIE_SAMESITE);

  FIncludeRoles := False;
  FIncludeDB := True;
  FIncludeDisplayName := True;
  FIncludeLanguage := True;
  LClaims := FAuthNode.FindNode('Claims');
  if Assigned(LClaims) then
  begin
    FIncludeRoles := LClaims.GetBoolean('IncludeRoles', FIncludeRoles);
    FIncludeDB := LClaims.GetBoolean('IncludeDB', FIncludeDB);
    FIncludeDisplayName := LClaims.GetBoolean('IncludeDisplayName', FIncludeDisplayName);
    FIncludeLanguage := LClaims.GetBoolean('IncludeLanguage', FIncludeLanguage);
  end;

  // IncludeACL is NOT user-configurable: it is fully derived from the
  // configured AccessControl. The kx_acl claim is meaningful only when
  // `AccessControl: JWT` consumes it; with any other controller
  // (DB, Null, ...) snapshotting permission rows into the cookie would
  // be wasted bytes and could leak unused grants. Tying the two settings
  // together at parse time keeps the model unambiguous: the user picks the
  // access controller, the framework picks the JWT shape.
  FIncludeACL := SameText(
    TKConfig.Instance.Config.GetExpandedString('AccessControl', ''), 'JWT');
end;

procedure TKJWTConfig.ResolveKey;
var
  LProvider: TKJWTSigningKeyProvider;
  LBytes: TBytes;
begin
  if FKeyResolved then
    Exit;

  LProvider := TKJWTSigningKeyRegistry.Instance.FindProvider(FAppName);
  if Assigned(LProvider) then
  begin
    FResolvedKey := LProvider();
    if FResolvedKey.Algorithm = TJOSEAlgorithmId.Unknown then
      FResolvedKey.Algorithm := FAlgorithm;
    if FResolvedKey.Algorithm <> FAlgorithm then
      raise EKJWTError.CreateFmt(
        'JWT signing key provider for app %s returned algorithm %s, but config declares %s',
        [FAppName, FResolvedKey.Algorithm.AsString, FAlgorithm.AsString]);
  end
  else
  begin
    if FKeySpec = '' then
      raise EKJWTError.Create(
        'JWT signing key not configured. Set Auth/SigningKey in YAML (env: file: or inline)' +
        ' or register a provider via TKJWTSigningKeyRegistry from UseKitto.pas.');
    LBytes := ResolveKeySpec(FKeySpec);
    if Length(LBytes) = 0 then
      raise EKJWTError.Create('JWT signing key resolved to empty bytes');
    FResolvedKey.Algorithm := FAlgorithm;
    FResolvedKey.PrivateKey := LBytes;
    if not IsSymmetricAlgorithm(FAlgorithm) then
    begin
      if FPublicKeySpec <> '' then
        FResolvedKey.PublicKey := ResolveKeySpec(FPublicKeySpec)
      else
        // Same bytes assumed to contain both keys (PEM bundle), or signer
        // also has the public key. For verifier-only deploys configure
        // SigningPublicKey explicitly.
        FResolvedKey.PublicKey := LBytes;
    end;
  end;

  FKeyResolved := True;
end;

function TKJWTConfig.GetSigningKey: TKJWTSigningKey;
begin
  ResolveKey;
  Result := FResolvedKey;
end;

{ TKJWTBuilder }

class function TKJWTBuilder.Build(const AContext: TKJWTContext;
  const AConfig: TKJWTConfig;
  const AExtraClaims: TArray<TPair<string, string>>): string;
var
  LBuilder: IJOSEProducerBuilder;
  LProducer: IJOSEProducer;
  LKey: TKJWTSigningKey;
  LNow: TDateTime;
  LRolesCsv: string;
  LExtra: TPair<string, string>;
begin
  LKey := AConfig.GetSigningKey;
  LNow := Now;

  LBuilder := TJOSEProducerBuilder.New
    .SetAlgorithm(LKey.Algorithm)
    .SetIssuer(AConfig.Issuer)
    .SetAudience(AConfig.Audience)
    .SetIssuedAt(LNow)
    .SetNotBefore(LNow)
    .SetExpiration(IncSecond(LNow, AConfig.TokenLifetimeSeconds))
    .SetSubject(AContext.UserName);

  if AContext.Jti <> '' then
    LBuilder := LBuilder.SetJWTId(AContext.Jti)
  else
    LBuilder := LBuilder.SetJWTId(CreateCompactGuidStr);

  if AContext.Sid <> '' then
    LBuilder := LBuilder.SetCustomClaim(CLAIM_SID, AContext.Sid);

  if AConfig.IncludeDisplayName and (AContext.DisplayName <> '') then
    LBuilder := LBuilder.SetCustomClaim(CLAIM_NAME, AContext.DisplayName);

  if AConfig.IncludeDB and (AContext.DatabaseName <> '') then
    LBuilder := LBuilder.SetCustomClaim(CLAIM_DB, AContext.DatabaseName);

  if AConfig.IncludeLanguage and (AContext.Language <> '') then
    LBuilder := LBuilder.SetCustomClaim(CLAIM_LANG, AContext.Language);

  if AConfig.IncludeRoles and (Length(AContext.Roles) > 0) then
  begin
    LRolesCsv := EncodeRolesAsCSV(AContext.Roles);
    LBuilder := LBuilder.SetCustomClaim(CLAIM_ROLES, LRolesCsv);
  end;

  if AConfig.IncludeACL and AContext.HasAcl and (Length(AContext.Acl) > 0) then
    // Stored as a JSON-stringified array. The extra escape layer is the
    // price we pay to keep going through TJOSEProducerBuilder.SetCustomClaim
    // which is RTTI-based and does not handle TJSONArray TValue cleanly.
    // For typical ACL sizes (~50 rows, a few KB) the overhead is negligible.
    LBuilder := LBuilder.SetCustomClaim(CLAIM_ACL, EncodeAclAsJsonString(AContext.Acl));

  if Assigned(AExtraClaims) then
    for LExtra in AExtraClaims do
      LBuilder := LBuilder.SetCustomClaim(LExtra.Key, LExtra.Value);

  if LKey.IsSymmetric then
    LBuilder := LBuilder.SetKey(BytesToJOSEBytes(LKey.PrivateKey))
  else
    LBuilder := LBuilder.SetKeyPair(
      BytesToJOSEBytes(LKey.PublicKey),
      BytesToJOSEBytes(LKey.PrivateKey));

  LProducer := LBuilder.Build;
  Result := LProducer.GetCompactString;
end;

{ TKJWTValidator }

class function TKJWTValidator.Validate(const ACompactToken: string;
  const AConfig: TKJWTConfig; out AContext: TKJWTContext;
  out AErrorMessage: string): Boolean;
var
  LConsumer: IJOSEConsumer;
  LKey: TKJWTSigningKey;
  LJOSEContext: TJOSEContext;
  LClaims: TJWTClaims;
  LStr: string;
  LVerifyKey: TJOSEBytes;
begin
  Result := False;
  AContext.Clear;
  AErrorMessage := '';

  if Trim(ACompactToken) = '' then
  begin
    AErrorMessage := 'Empty JWT';
    Exit;
  end;

  LKey := AConfig.GetSigningKey;
  if LKey.IsSymmetric or (not LKey.HasPublicKey) then
    LVerifyKey := BytesToJOSEBytes(LKey.PrivateKey)
  else
    LVerifyKey := BytesToJOSEBytes(LKey.PublicKey);

  try
    LConsumer := TJOSEConsumerBuilder.NewConsumer
      .SetClaimsClass(TJWTClaims)
      .SetVerificationKey(LVerifyKey)
      .SetSkipVerificationKeyValidation
      .SetExpectedIssuer(True, AConfig.Issuer)
      .SetExpectedAudience(True, [AConfig.Audience])
      .SetRequireExpirationTime
      .SetRequireIssuedAt
      .SetAllowedClockSkew(AConfig.ClockSkewSeconds, TJOSETimeUnit.Seconds)
      .Build;

    LJOSEContext := TJOSEContext.Create(StringToJOSEBytes(ACompactToken), TJWTClaims);
    try
      LConsumer.ProcessContext(LJOSEContext);
      LClaims := LJOSEContext.GetClaims;

      AContext.UserName := LClaims.Subject;
      AContext.Issuer := LClaims.Issuer;
      AContext.Audience := LClaims.Audience;
      AContext.IssuedAt := LClaims.IssuedAt;
      AContext.Expiration := LClaims.Expiration;
      AContext.NotBefore := LClaims.NotBefore;
      AContext.Jti := LClaims.JWTId;
      AContext.CompactToken := ACompactToken;

      if Assigned(LClaims.JSON) then
      begin
        if LClaims.JSON.TryGetValue<string>(CLAIM_SID, LStr) then
          AContext.Sid := LStr;
        if LClaims.JSON.TryGetValue<string>(CLAIM_NAME, LStr) then
          AContext.DisplayName := LStr;
        if LClaims.JSON.TryGetValue<string>(CLAIM_DB, LStr) then
          AContext.DatabaseName := LStr;
        if LClaims.JSON.TryGetValue<string>(CLAIM_LANG, LStr) then
          AContext.Language := LStr;
        if LClaims.JSON.TryGetValue<string>(CLAIM_ROLES, LStr) then
          AContext.Roles := DecodeRolesFromCSV(LStr);
        if LClaims.JSON.TryGetValue<string>(CLAIM_ACL, LStr) then
        begin
          AContext.Acl := DecodeAclFromJsonString(LStr);
          AContext.HasAcl := Length(AContext.Acl) > 0;
        end;
      end;

      AContext.IsValid := True;
      Result := True;
    finally
      LJOSEContext.Free;
    end;
  except
    on E: Exception do
    begin
      AErrorMessage := E.Message;
      TEFLogger.Instance.LogFmt('JWT validation failed: %s', [E.Message],
        TEFLogger.LOG_DETAILED);
    end;
  end;
end;

{ TKJWTCookieHelper }

class procedure TKJWTCookieHelper.Issue(const ACompactToken: string;
  const AConfig: TKJWTConfig);
var
  LExpires: TDateTime;
begin
  LExpires := IncSecond(Now, AConfig.TokenLifetimeSeconds);
  TKWebResponse.Current.SetSecureCookie(
    AConfig.CookieName, ACompactToken,
    LExpires,
    AConfig.CookiePath,
    AConfig.CookieHttpOnly,
    AConfig.CookieSecure,
    AConfig.CookieSameSite);
end;

class procedure TKJWTCookieHelper.Clear(const AConfig: TKJWTConfig);
begin
  TKWebResponse.Current.SetSecureCookie(
    AConfig.CookieName, '',
    Now - 1,
    AConfig.CookiePath,
    AConfig.CookieHttpOnly,
    AConfig.CookieSecure,
    AConfig.CookieSameSite);
end;

class function TKJWTCookieHelper.ReadFromRequest(
  const AConfig: TKJWTConfig): string;
begin
  Result := TKWebRequest.Current.GetCookie(AConfig.CookieName);
end;

class function TKJWTCookieHelper.ShouldSlide(const AContext: TKJWTContext;
  const AConfig: TKJWTConfig): Boolean;
begin
  Result := AContext.IsValid and
    (SecondsBetween(AContext.Expiration, Now) < AConfig.SlidingThresholdSeconds);
end;

end.
