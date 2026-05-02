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
///   JWT authenticator. Wraps any other registered TKAuthenticator (e.g. DB,
///   TextFile, custom app authenticator) as the Inner provider that performs
///   the actual credential check, then issues a self-contained JWT in an
///   HttpOnly cookie. The wrapper exposes the same authenticator API as a
///   classic authenticator so the rest of the framework is unaware that JWT
///   is in use.
///
///   Phase A: Inner is a local authenticator (DB / TextFile / app-defined).
///   Phase C will add TKExternalAuthBase descendants for OIDC / SAML which
///   override BuildContext to map IdP-supplied claims and GetLoginUIMode to
///   request a redirect-based login form rendering.
/// </summary>
unit Kitto.Auth.JWT;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  EF.Tree,
  EF.Types,
  Kitto.Auth,
  Kitto.Web.JWT;

type
  /// <summary>
  ///  Hint to the login template renderer about what kind of login UI to
  ///  show for this authenticator. lumForm = traditional UserName/Password
  ///  form fields. lumRedirect = single button that triggers an external
  ///  redirect (Phase C — OIDC/SAML).
  /// </summary>
  TKLoginUIMode = (lumForm, lumRedirect);

  /// <summary>
  ///  JWT-issuing authenticator. Registered as 'JWT'.
  ///  Inherits from TKClassicAuthenticator so UserName/Password/Language/
  ///  SecretCode are wired to the standard session AuthData fields and the
  ///  inherited CanBypassURLParam guards them.
  /// </summary>
  TKJWTAuthenticator = class(TKClassicAuthenticator)
  // The per-thread JWT context cache used by TKJWTAccessController is
  // declared as a unit-level threadvar in the implementation section
  // (not as 'class threadvar' inside this class). Reason: the Delphi
  // compiler has been observed to compute wrong instance-memory offsets
  // when 'class threadvar' declarations of record types (TKJWTContext)
  // are mixed with regular instance fields in the same visibility block.
  // The symptom is silent field-offset corruption: writes to FConfig /
  // FConfigInitialized from one method appear to "reset themselves" by
  // the time another method reads them on the same instance pointer.
  // Keeping the threadvar entirely outside the class declaration is the
  // safe, observable, layout-stable choice.
  strict private
    FInner: TKAuthenticator;
    FConfig: TKJWTConfig;
    FInnerInitialized: Boolean;
    FConfigInitialized: Boolean;
    FAppName: string;
    procedure EnsureInner;
    procedure EnsureConfig;
    function ResolveAppName: string;
  strict protected
    /// <summary>
    ///  Snapshots the user's permissions (KITTO_PERMISSIONS rows for the user
    ///  plus all roles in KITTO_USER_ROLES) into a TKJWTAclArray. Reads the
    ///  SQL templates from TKConfig.Instance.Config.AccessControl/Read*CommandText,
    ///  falling back to TKDBAccessController defaults when those keys are
    ///  absent. Returns an empty array when no permissions are found.
    /// </summary>
    function BuildAclFromDB(const AUserId: string): TKJWTAclArray; virtual;

    /// Override to enrich the JWT context with custom claims before it is
    /// signed. The default fills sub/name/db/lang from session state, and
    /// (when Auth/Claims/IncludeACL=True) snapshots ACL rows into kx_acl.
    /// Phase C subclasses override to pull IdP-specific claims into the
    /// internal token.
    procedure BuildContext(out AContext: TKJWTContext); virtual;

    function InternalAuthenticate(const AAuthData: TEFNode): Boolean; override;
    procedure InternalAfterAuthenticate(const AAuthData: TEFNode); override;
    function GetIsClearPassword: Boolean; override;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;

    procedure Logout; override;
    procedure ResetPassword(const AParams: TEFNode); override;
    procedure QRGenerate(const AParams: TEFNode); override;
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; override;

    /// <summary>
    ///  Returns the Inner authenticator's Config so that callers reading
    ///  user-facing auth options (DatabaseChoices, ValidatePassword,
    ///  IsPassepartoutEnabled, ReadUserCommandText, etc.) keep working
    ///  with the same YAML keys when the app moves to Auth: JWT.
    /// </summary>
    function EffectiveConfigNode: TEFTree; override;

    /// <summary>
    ///  Validates the kx_token cookie attached to the current request,
    ///  hydrates the session from the verified claims, and slides the
    ///  cookie expiration if it is approaching. Called by
    ///  TKWebApplication.DoHandleRequest immediately after ActivateInstance.
    /// </summary>
    procedure AuthorizeRequest; override;

    /// Phase C extension point — the login template uses this to pick
    /// between rendering form fields or a "Login with X" button.
    function GetLoginUIMode: TKLoginUIMode; virtual;

    /// Builds and writes the JWT cookie to the current response. Called by
    /// InternalAfterAuthenticate on a successful login. Returns the compact
    /// JWT for diagnostics / logging.
    function IssueToken: string;

    /// Re-issues the cookie with a fresh expiration based on the supplied
    /// validated context. Used by the engine's sliding-expiration hook.
    function SlideToken(const AContext: TKJWTContext): string;

    /// Parsed configuration of the JWT layer.
    function JWTConfig: TKJWTConfig;

    /// The wrapped inner authenticator. Lazily created on first access.
    function Inner: TKAuthenticator;

    /// <summary>
    ///  True when AuthorizeRequest has just validated a JWT for the current
    ///  thread/request and the result is cached in CurrentContext. Used by
    ///  TKJWTAccessController to read the kx_acl claim without a second
    ///  signature verification per ACL call.
    /// </summary>
    class function HasContext: Boolean; static;

    /// <summary>
    ///  The validated context cached by AuthorizeRequest for the current
    ///  thread/request. Caller must check HasContext first.
    /// </summary>
    class function CurrentContext: TKJWTContext; static;

    /// <summary>
    ///  Clears the thread-local context cache. Called by AuthorizeRequest
    ///  when validation fails so subsequent ACL checks within the same
    ///  request fall back to the unauthenticated path.
    /// </summary>
    class procedure ClearCurrentContext; static;
  end;

implementation

uses
  System.DateUtils,
  EF.Localization,
  EF.StrUtils,
  EF.Logger,
  Kitto.Config,
  Kitto.Web.Application,
  Kitto.Web.Session,
  Kitto.AccessControl.DB,
  Kitto.Store,
  JOSE.Core.JWA;

// Per-thread context cache populated by TKJWTAuthenticator.AuthorizeRequest
// and read by TKJWTAccessController.InternalGetAccessGrantValue. Each request
// runs on its own Indy worker thread; the threadvar isolates the cache so
// concurrent requests do not see each other's claims. See the comment in the
// class declaration for why these live here, NOT as 'class threadvar' inside
// the class body.
threadvar
  FCurrentContext: TKJWTContext;
  FHasCurrentContext: Boolean;

const
  CFG_INNER = 'Inner';

{ TKJWTAuthenticator }

procedure TKJWTAuthenticator.AfterConstruction;
begin
  inherited;
  // FAppName is resolved lazily in EnsureConfig instead of here. AfterConstruction
  // runs while TKWebApplication.GetAuthenticator is still wiring up the authenticator
  // (the YAML children of the Auth node are added AFTER CreateObject returns), and
  // depending on the call path TKConfig.Instance may not yet point to the active
  // app config — which would cause ResolveAppName to return '' for some instances
  // (silently breaking TKJWTSigningKeyRegistry lookups). EnsureConfig is invoked
  // later, on the first AuthorizeRequest / IssueToken / SlideToken call, by which
  // time the runtime is fully assembled.
  FAppName := '';
end;

destructor TKJWTAuthenticator.Destroy;
begin
  FreeAndNil(FConfig);
  FreeAndNil(FInner);
  inherited;
end;

function TKJWTAuthenticator.ResolveAppName: string;
begin
  // Read AppName directly from the loaded Config.yaml. TKConfig.AppName (class
  // function) can return the binary file name as a last-resort fallback when
  // called too early in the init chain (before the Home directory is fully
  // resolved), and that fallback gets cached in TKConfig's class var FAppName
  // for the rest of the process lifetime. The cached binary name (e.g.
  // "TasKitto") would then never match the AppName declared in Config.yaml
  // (e.g. "TaskittoX"), silently breaking TKJWTSigningKeyRegistry lookups
  // registered from UseKitto.pas with the YAML name.
  if Assigned(TKConfig.Instance) then
    Result := TKConfig.Instance.Config.GetString('AppName', '');
  if Result = '' then
    Result := TKConfig.AppName;
  if Result = '' then
    Result := 'KittoXApp';
end;

procedure TKJWTAuthenticator.EnsureConfig;
begin
  // Fast path: once FConfigInitialized has been set the field is stable. The
  // double-checked TMonitor lock below avoids two concurrent requests both
  // creating a TKJWTConfig (the loser instance would leak when FConfig is
  // overwritten). The Indy thread pool can issue many requests in parallel,
  // and the very first wave reaches AuthorizeRequest before FConfigInitialized
  // flips to True.
  if FConfigInitialized then
    Exit;
  TMonitor.Enter(Self);
  try
    if FConfigInitialized then
      Exit;
    // Resolve the app name now (lazy). At this point we are inside an active
    // request — TKWebApplication.Current is set and its Config has been fully
    // loaded — so reading AppName from the YAML is reliable.
    if FAppName = '' then
      FAppName := ResolveAppName;
    FConfig := TKJWTConfig.Create(FAppName, Config);
    // Default cookie path to the app path so other apps on the same host
    // don't see this token.
    if FConfig.CookiePath = '' then
    begin
      if Assigned(TKWebApplication.Current) and (TKWebApplication.Current.Path <> '') then
        FConfig.CookiePath := TKWebApplication.Current.Path
      else
        FConfig.CookiePath := '/';
    end;
    FConfigInitialized := True;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TKJWTAuthenticator.EnsureInner;
var
  LInnerNode: TEFNode;
  LInnerType: string;
  I: Integer;
begin
  // Same double-checked locking pattern as EnsureConfig — first request wave
  // can reach Authenticate / IsClearPassword in parallel, and we must not
  // create more than one Inner authenticator (subsequent ones would leak
  // when FInner is overwritten and would also bypass the registry-side state).
  if FInnerInitialized then
    Exit;
  TMonitor.Enter(Self);
  try
    if FInnerInitialized then
      Exit;

    LInnerNode := Config.FindNode(CFG_INNER);
    if not Assigned(LInnerNode) then
      raise EKJWTError.Create(_('Auth: JWT requires an Inner authenticator. Set Auth/Inner in Config.yaml.'));

    LInnerType := LInnerNode.AsString;
    if LInnerType = '' then
      raise EKJWTError.Create(_('Auth/Inner must specify the inner authenticator class id (e.g. DB, TextFile, custom).'));

    FInner := TKAuthenticatorFactory.Instance.CreateObject(LInnerType);
    // Copy children of Inner node into Inner's Config so it sees the same YAML
    // params it would normally read at the top level.
    for I := 0 to LInnerNode.ChildCount - 1 do
      FInner.Config.AddChild(TEFNode.Clone(LInnerNode.Children[I]));
    FInnerInitialized := True;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TKJWTAuthenticator.Inner: TKAuthenticator;
begin
  EnsureInner;
  Result := FInner;
end;

function TKJWTAuthenticator.JWTConfig: TKJWTConfig;
begin
  EnsureConfig;
  Result := FConfig;
end;

function TKJWTAuthenticator.InternalAuthenticate(const AAuthData: TEFNode): Boolean;
begin
  EnsureInner;
  EnsureConfig;
  Result := FInner.Authenticate(AAuthData);
end;

procedure TKJWTAuthenticator.InternalAfterAuthenticate(const AAuthData: TEFNode);
begin
  inherited;
  // After Inner.Authenticate, session.AuthData holds the credential set
  // ENRICHED by Inner (e.g. FIRST_NAME, LAST_NAME, EMAIL_ADDRESS pulled out
  // of KITTO_USERS by TKDBAuthenticator). The wrapper Authenticate method
  // is about to overwrite session.AuthData with the original AAuthData
  // (login form fields only) right after we return. Sync the enrichment
  // INTO AAuthData here so that final assign keeps the enriched values.
  AAuthData.Assign(TKWebSession.Current.AuthData);
  // Inner has filled session AuthData by the time we get here. Issue the
  // JWT cookie now so the response carries the credential.
  IssueToken;
end;

function TKJWTAuthenticator.BuildAclFromDB(const AUserId: string): TKJWTAclArray;
var
  LStorage: TKUserPermissionStorage;
  LAclConfig: TEFNode;
  I: Integer;
begin
  Result := nil;
  if AUserId = '' then
    Exit;

  LStorage := TKUserPermissionStorage.Create;
  try
    // Read the SQL templates from the AccessControl YAML node. The node
    // exists for both AccessControl: DB and AccessControl: JWT (the latter
    // uses the same keys for fallback queries). When absent, fall back to
    // the defaults baked into TKDBAccessController.
    LAclConfig := TKConfig.Instance.Config.FindNode('AccessControl');
    if Assigned(LAclConfig) then
    begin
      LStorage.ReadPermissionsCommandText :=
        LAclConfig.GetString('ReadPermissionsCommandText', DEFAULT_READPERMISSIONCOMMANDTEXT);
      LStorage.ReadRolesCommandText :=
        LAclConfig.GetString('ReadRolesCommandText', DEFAULT_READROLESCOMMANDTEXT);
      // Carry over DatabaseRouter / extra config so GetDatabaseName resolves
      // the same way the runtime DB controller would.
      for I := 0 to LAclConfig.ChildCount - 1 do
        if LStorage.Config.FindChild(LAclConfig.Children[I].Name) = nil then
          LStorage.Config.AddChild(TEFNode.Clone(LAclConfig.Children[I]));
    end
    else
    begin
      LStorage.ReadPermissionsCommandText := DEFAULT_READPERMISSIONCOMMANDTEXT;
      LStorage.ReadRolesCommandText := DEFAULT_READROLESCOMMANDTEXT;
    end;

    // Setting UserId triggers the actual load (user permissions + role
    // permissions). Failures bubble up as DB exceptions and abort the login.
    LStorage.UserId := AUserId;

    SetLength(Result, LStorage.Permissions.RecordCount);
    for I := 0 to LStorage.Permissions.RecordCount - 1 do
    begin
      Result[I].Pattern    := LStorage.Permissions.Records[I].Fields[0].AsString;
      Result[I].Modes      := LStorage.Permissions.Records[I].Fields[1].AsString;
      Result[I].GrantValue := LStorage.Permissions.Records[I].Fields[2].AsString;
    end;

    TEFLogger.Instance.LogFmt('JWT ACL snapshot built for %s: %d rows',
      [AUserId, Length(Result)], TEFLogger.LOG_DETAILED);
  finally
    LStorage.Free;
  end;
end;

procedure TKJWTAuthenticator.BuildContext(out AContext: TKJWTContext);
var
  LSession: TKWebSession;
begin
  AContext.Clear;
  LSession := TKWebSession.Current;

  AContext.UserName := FInner.UserName;
  if FConfig.IncludeDisplayName then
    AContext.DisplayName := LSession.DisplayName;
  if FConfig.IncludeDB then
    AContext.DatabaseName := LSession.DatabaseName;
  if FConfig.IncludeLanguage then
    AContext.Language := LSession.Language;

  if FConfig.IncludeACL then
  begin
    AContext.Acl := BuildAclFromDB(AContext.UserName);
    AContext.HasAcl := Length(AContext.Acl) > 0;
  end;

  // Sid keeps the JWT correlated to the server-side TKWebSession that
  // holds non-serializable state (open controllers, in-memory stores).
  AContext.Sid := LSession.SessionId;
  // Jti left empty — TKJWTBuilder generates a fresh GUID.
end;

function TKJWTAuthenticator.IssueToken: string;
var
  LContext: TKJWTContext;
begin
  EnsureConfig;
  EnsureInner;
  BuildContext(LContext);
  Result := TKJWTBuilder.Build(LContext, FConfig);
  TKJWTCookieHelper.Issue(Result, FConfig);
  TEFLogger.Instance.LogFmt('JWT issued for user %s, sid %s, app %s',
    [LContext.UserName, LContext.Sid, FAppName], TEFLogger.LOG_DETAILED);
end;

function TKJWTAuthenticator.SlideToken(const AContext: TKJWTContext): string;
var
  LContext: TKJWTContext;
begin
  EnsureConfig;
  // Re-issue with a fresh exp but preserve sid/sub/etc. from the validated
  // context. We do not rebuild from current session — the validated token
  // is the source of truth for identity claims.
  LContext := AContext;
  LContext.CompactToken := '';
  LContext.IsValid := False;
  Result := TKJWTBuilder.Build(LContext, FConfig);
  TKJWTCookieHelper.Issue(Result, FConfig);
end;

procedure TKJWTAuthenticator.Logout;
begin
  inherited;
  if FConfigInitialized then
    TKJWTCookieHelper.Clear(FConfig);
  if FInnerInitialized and Assigned(FInner) then
    FInner.Logout;
end;

procedure TKJWTAuthenticator.ResetPassword(const AParams: TEFNode);
begin
  EnsureInner;
  FInner.ResetPassword(AParams);
end;

procedure TKJWTAuthenticator.QRGenerate(const AParams: TEFNode);
begin
  EnsureInner;
  FInner.QRGenerate(AParams);
end;

function TKJWTAuthenticator.IsPasswordMatching(const ASuppliedPasswordHash,
  AStoredPasswordHash: string): Boolean;
begin
  EnsureInner;
  Result := FInner.IsPasswordMatching(ASuppliedPasswordHash, AStoredPasswordHash);
end;

function TKJWTAuthenticator.GetIsClearPassword: Boolean;
begin
  EnsureInner;
  Result := FInner.IsClearPassword;
end;

function TKJWTAuthenticator.GetLoginUIMode: TKLoginUIMode;
begin
  Result := lumForm;
end;

class function TKJWTAuthenticator.HasContext: Boolean;
begin
  Result := FHasCurrentContext;
end;

class function TKJWTAuthenticator.CurrentContext: TKJWTContext;
begin
  Result := FCurrentContext;
end;

class procedure TKJWTAuthenticator.ClearCurrentContext;
begin
  FCurrentContext.Clear;
  FHasCurrentContext := False;
end;

function TKJWTAuthenticator.EffectiveConfigNode: TEFTree;
begin
  EnsureInner;
  if Assigned(FInner) then
    Result := FInner.Config
  else
    Result := inherited EffectiveConfigNode;
end;

procedure TKJWTAuthenticator.AuthorizeRequest;
var
  LCookie: string;
  LContext: TKJWTContext;
  LErr: string;
begin
  // Reset any context left over from a previous request on this thread.
  ClearCurrentContext;

  EnsureConfig;
  LCookie := TKJWTCookieHelper.ReadFromRequest(FConfig);
  if Trim(LCookie) = '' then
  begin
    // No token: treat the request as unauthenticated. Public endpoints
    // (Home, Login) keep working; protected ones get redirected to login.
    TKWebSession.Current.IsAuthenticated := False;
    Exit;
  end;
  if not TKJWTValidator.Validate(LCookie, FConfig, LContext, LErr) then
  begin
    TEFLogger.Instance.LogFmt('JWT cookie validation failed: %s', [LErr],
      TEFLogger.LOG_DETAILED);
    TKJWTCookieHelper.Clear(FConfig);
    TKWebSession.Current.IsAuthenticated := False;
    Exit;
  end;
  // Token verified: this request is authenticated. Hydrate session state
  // from the validated claims, but only fields that the server-side session
  // does not already carry.
  TKWebSession.Current.IsAuthenticated := True;
  TKWebSession.Current.AuthData.SetString('UserName', LContext.UserName);
  if (TKWebSession.Current.DatabaseName = '') and (LContext.DatabaseName <> '') then
    TKWebSession.Current.DatabaseName := LContext.DatabaseName;
  if (TKWebSession.Current.Language = '') and (LContext.Language <> '') then
    TKWebSession.Current.Language := LContext.Language;
  if TKWebSession.Current.DisplayName = '' then
    TKWebSession.Current.DisplayName := LContext.DisplayName;

  // Cache the validated context on the thread for the rest of this request.
  // TKJWTAccessController reads it (and especially the kx_acl claim) without
  // having to re-validate the JWT on every IsAccessGranted call.
  FCurrentContext := LContext;
  FHasCurrentContext := True;

  if TKJWTCookieHelper.ShouldSlide(LContext, FConfig) then
    SlideToken(LContext);
end;

initialization
  TKAuthenticatorRegistry.Instance.RegisterClass('JWT', TKJWTAuthenticator);

finalization
  TKAuthenticatorRegistry.Instance.UnregisterClass('JWT');

end.
