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
///   Defines the base authenticator and related classes and services.
///   Authenticators allow the creation of applications that require user
///   anthentication at startup.
/// </summary>
unit Kitto.Auth;

{$I Kitto.Defines.inc}

interface

uses
  System.Classes,
  EF.Types,
  EF.Classes,
  EF.Tree;

type
  /// <summary>
  ///   <para>Abstract base authenticator. An authenticator defines a method
  ///   for user authentication.</para>
  ///   <para>Only one authenticator may be active at any one time.</para>
  ///   <para>Applications wanting to use a custom authentication scheme should
  ///   create and register an authenticator, and then make it active through
  ///   the configuration.</para>
  /// </summary>
  TKAuthenticator = class(TEFComponent)
  strict private
    class threadvar FCurrent: TKAuthenticator;
    procedure ClearAuthData;
    procedure AssignSessionAuthData(const AAuthData: TEFNode);
  strict
  private
    FIsBCrypted: Boolean;
    /// <summary>Opaque per-authenticator state owned and populated by the JWT
    /// engine (Kitto.Auth.JWT) — its parsed TKJWTConfig for this authenticator.
    /// Held as TObject so the core carries no JOSE dependency; freed with the
    /// authenticator (and by the setter when replaced).</summary>
    FJWTState: TObject;
    procedure SetJWTState(const AValue: TObject);
    function GetAuthData: TEFNode; protected
    class function GetCurrent: TKAuthenticator; static;
    class procedure SetCurrent(const AValue: TKAuthenticator); static; protected
    function GetIsAuthenticated: Boolean; virtual;
    function GetIsBCrypted: Boolean; virtual;

    /// <summary>
    ///  Implements the IsClearPassword property.
    /// </summary>
    function GetIsClearPassword: Boolean; virtual;

    /// <summary>Called at the beginning of the authentication process, before
    /// InternalAuthenticate.</summary>
    procedure InternalBeforeAuthenticate(const AAuthData: TEFNode); virtual;

    /// <summary>Called at the end of the authentication process, in case of
    /// successful authentication.</summary>
    procedure InternalAfterAuthenticate(const AAuthData: TEFNode); virtual;

    /// <summary>Implements Authenticate. Descendants should verify that
    /// AAuthData contains all required items, query whatever authentication
    /// mechanism they encapsulate, and return True if a match is found and
    /// False otherwise.</summary>
    function InternalAuthenticate(const AAuthData: TEFNode): Boolean; virtual; abstract;

    /// <summary>Implements DefineAuthData.</summary>
    procedure InternalDefineAuthData(const AAuthData: TEFNode); virtual; abstract;

    /// <summary>Assign default values to AuthData.</summary>
    procedure InternalDefaultToAuthData(const AAuthData: TEFNode); virtual;

    /// <summary>
    ///  The body of the default InternalDefaultToAuthData: fills each auth item
    ///  from Config's Defaults/&lt;ItemName&gt; node. Not virtual, and kept apart
    ///  from the virtual method so that a subclass which re-declares
    ///  InternalDefaultToAuthData can still reach this behaviour when it has to
    ///  answer locally.
    /// </summary>
    procedure ApplyConfigDefaults(const AAuthData: TEFNode);

    /// <summary>This function should return a unique user identifier, to be
    /// used for example for access control. The default implementation returns
    /// 'PUBLIC', while a descendant will return the user name or something
    /// else, as needed.</summary>
    function GetUserName: string; virtual;

    /// <summary>For password-based authenticators, this function should return
    /// the current user's password (or hash). The default implementation
    /// returns a blank string.</summary>
    function GetPassword: string; virtual;

    /// <summary>Changes the current user's password in whatever underlying
    /// storage the authenticator uses. Only makes sense for password-based
    /// authenticator. The default implementation does nothing.</summary>
    /// <remarks>After calling this method, the user stays authenticated and
    /// the session's password is updated (the password used when first
    /// authenticating is lost). This allows a user to change his password more
    /// than once per session.</remarks>
    procedure SetPassword(const AValue: string); virtual;

    /// <summary>For PIN-based authenticators, this function should return
    /// the current user's secret code (to generate the 6-digit one time PIN).
    /// The default implementation returns a blank string.</summary>
    function GetSecretCode: string; virtual;

    /// <summary>Returns True if the authentication data contains a custom field
    /// called MUST_CHANGE_PASSWORD with value 1. Override this method to implement a
    /// custom way of signaling that the user needs to change his password.</summary>
    function GetMustChangePassword: Boolean; virtual;

    /// <summary>Returns True if the authentication data contains a custom field
    /// called MUST_CONFIRM_ACCESS with value 1. Override this method to implement a
    /// custom way of signaling that the user needs to confirm the access to the system.</summary>
    function GetMustConfirmAccess: Boolean; virtual;
  public
    /// <summary>Defines the auth data on the current session and creates the
    /// auth macro expander.</summary>
    procedure AfterConstruction; override;
    /// <summary>Frees the auth macro expander.</summary>
    destructor Destroy; override;
  public
    /// <summary>
    ///   <para>Receives an empty node which it should fill with the
    ///   definitions (names and types, not values) of all required auth items.
    ///   The system uses this information at login time, so that the user can
    ///   supply any auth data needed by the currently active authenticator.
    ///   The most common example of auth data is a UserName + Password
    ///   combination.</para>
    ///   <para>If no auth items are defined, then the system will not prompt
    ///   the user but will still call Authenticate passing in an empty
    ///   node.</para>
    /// </summary>
    procedure DefineAuthData(const AAuthData: TEFNode);

    /// <summary>
    ///  Checks whether the specified auth data designates a valid user
    ///  or not, and returns False if the authentication fails.
    /// </summary>
    function Authenticate(const AAuthData: TEFNode): Boolean;

    /// <summary>
    ///   Refills AAuthData from the user record WITHOUT checking a password,
    ///   for an identity already proven by other means — a validated JWT whose
    ///   server-side session was lost (timeout, restart) and re-created empty.
    ///   Authenticate seeds the auth data at login (the imposed-step flags
    ///   MUST_CHANGE_PASSWORD / MUST_CONFIRM_ACCESS, and any %Auth:field% a view
    ///   reads), but that state lives on the session and is gone once the
    ///   session is; a token outlives the session, so the identity survives
    ///   while the data behind it does not, and the imposed-step gate — which
    ///   reads the flags out of the auth data — would wave the request through.
    ///   Returns False when the user can no longer be established (unknown,
    ///   deactivated, deleted), so the caller can refuse the token: this is also
    ///   how a disabled account's still-valid token stops working. The default
    ///   does nothing and returns True (authenticators with no user record to
    ///   reload, e.g. TextFile/OSDB, carry all they need in the token).
    /// </summary>
    function RehydrateAuthData(const AUserName: string;
      const AAuthData: TEFNode): Boolean; virtual;

    /// <summary>Gives access to a copy of the auth data that was last passed
    /// to Authenticate (and possibly modified by the object during
    /// authentication).</summary>
    property AuthData: TEFNode read GetAuthData;

    /// <summary>Clears AuthData and turns off IsAuthenticated.</summary>
    procedure Logout; virtual;

    /// <summary>A unique identifier for the currently logged in user. The
    /// value depends on the particular descendant. By default, it's
    /// 'PUBLIC'.</summary>
    property UserName: string read GetUserName;

    /// <summary>For password-based authenticators, returns the current user's
    /// password or hash. The default implementation returns a blank
    /// string.</summary>
    property Password: string read GetPassword write SetPassword;

    /// <summary>For PIN-based authenticators, returns the current user's
    /// secret code (to generate the 6-digit one time PIN).
    /// The default implementation returns a blank string.</summary>
    property SecretCode: string read GetSecretCode;

    /// <summary>Returns True if the autheticator uses clear passwords, False
    /// if hashing is used. Only meaningful for password-based authenticators.
    /// By default, returns True.</summary>
    property IsClearPassword: Boolean read GetIsClearPassword;

    /// <summary>Returns True if authentication has successfully taken
    /// place.</summary>
    property IsAuthenticated: Boolean read GetIsAuthenticated;

    /// <summary>Returns True if the authentication data signals that the user
    /// must change his password. By default, this happens when a custom field
    /// called MUST_CHANGE_PASSWORD with value 1 is added to the authentication data.
    /// Querying this property is only meaningful after successful authentication.</summary>
    property MustChangePassword: Boolean read GetMustChangePassword;

    /// <summary>Returns True if the authentication need to confirm
    /// a pre-requisite to access to system.</summary>
    property MustConfirmAccess: Boolean read GetMustConfirmAccess;

    /// <summary>
    ///  Called (with no authenticated user) when a password reset is initiated.
    ///  Override this method to implement an application-defined scheme, such
    ///  as generating a random password and emailing it to the user.
    ///  The specified params depend on the calling controller.
    ///  A standard controller might specify the user name (UserName) or
    ///  email address (EmailAddress) to which the generated password should be sent.
    /// </summary>
    procedure ResetPassword(const AParams: TEFNode); virtual; abstract;

    /// <summary>Thread-local reference to the currently active authenticator
    /// instance for the request being served.</summary>
    class property Current: TKAuthenticator read GetCurrent write SetCurrent;

    /// <summary>
    ///  Called (with no authenticated user) when a QR code (for PIN authentication)
    ///  is requested. Override this method to implement an application-defined
    ///  scheme, such as generating a QR code containing the secret to share with
    ///  the third party authenticator app and emailing it to the user.
    ///  The specified params depend on the calling controller.
    ///  A standard controller might specify the user name (UserName) and
    ///  email address (EmailAddress) to which the generated QR code should be sent.
    /// </summary>
    procedure QRGenerate(const AParams: TEFNode); virtual; abstract;

    /// <summary>Returns True if the supplied password hash matches the stored
    /// one. Concrete authenticators define the actual matching rules.</summary>
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; virtual; abstract;

    /// <summary>Indicates whether the stored password is hashed with the BCrypt
    /// algorithm (as opposed to the legacy hash or clear text).</summary>
    property IsBCrypted: Boolean read GetIsBCrypted write FIsBCrypted;
  public
    /// <summary>
    ///  Tells whether this authenticator is able to write a new password to
    ///  wherever it keeps credentials. The default is True: every password-based
    ///  authenticator overrides SetPassword and can honour a change.
    ///
    ///  Authenticators that do NOT own the credentials return False — the
    ///  directory-backed ones (Auth: LDAP) being the case in point: passwords
    ///  live in the directory and must be changed there. Returning False is not
    ///  cosmetic: SetPassword's base implementation has an EMPTY body, so
    ///  without this the change-password handler would report success and write
    ///  nothing at all. Callers MUST consult this before writing (see
    ///  Kitto.Web.Handler.Auth.HandleChangePassword) and SHOULD consult it
    ///  before offering the UI (see Kitto.Html.ChangePassword).
    /// </summary>
    function SupportsPasswordChange: Boolean; virtual;

    /// <summary>
    ///  Returns the configuration node callers consult for user-facing auth
    ///  options (DatabaseChoices, ValidatePassword, IsPassepartoutEnabled, ...).
    ///  It is the authenticator's own Config: with the flat Auth model those keys
    ///  live directly under the Auth node, whether or not a JWT block is present.
    /// </summary>
    function EffectiveConfigNode: TEFTree; virtual;

    /// <summary>
    ///  Per-request hook invoked by TKWebApplication just after ActivateInstance
    ///  and before any route dispatch. When IsJWTEnabled it delegates to the
    ///  registered IKXJWTEngine to validate the request token, hydrate the
    ///  session and slide the expiration; otherwise it does nothing. Kept virtual
    ///  so a custom authenticator can still add per-request work.
    /// </summary>
    procedure AuthorizeRequest; virtual;

    /// <summary>
    ///  True when this authenticator is configured to issue/validate a JWT — i.e.
    ///  a JWT sub-node is present under its Auth config. When True the base
    ///  delegates token issue/validate/clear to the registered IKXJWTEngine, and
    ///  the credential itself carries the session id ('sid' claim), so the engine
    ///  must NOT emit a separate session-id cookie.
    /// </summary>
    function IsJWTEnabled: Boolean;

    /// <summary>
    ///  Issues the JWT cookie for the just-authenticated user and returns the
    ///  compact token when IsJWTEnabled; otherwise returns ''. Delegates to the
    ///  registered IKXJWTEngine. Used by the REST /token endpoint.
    /// </summary>
    function IssueToken: string;

    /// <summary>Opaque per-authenticator state owned by the JWT engine (see the
    /// field). Public so the engine can attach/read its parsed config; the base
    /// frees it. Assigning a new value frees the previous one.</summary>
    property JWTState: TObject read FJWTState write SetJWTState;
  end;
  /// <summary>Metaclass reference used to register and create authenticators
  /// by class.</summary>
  TKAuthenticatorClass = class of TKAuthenticator;

  /// <summary>
  ///  Crypto/transport engine for the optional JWT envelope. The base
  ///  TKAuthenticator decides WHEN to issue/validate/clear a token (from the
  ///  presence of a JWT sub-node in its config) but delegates the actual signing
  ///  and validation — and the third-party JOSE dependency — to an engine
  ///  registered by an opt-in unit (Kitto.Auth.JWT). Applications that do not use
  ///  JWT never link JOSE.
  /// </summary>
  IKXJWTEngine = interface
    ['{7E2A1B4C-9D6F-4A31-8C22-1F5E7B9A0D34}']
    /// <summary>Builds and writes the JWT cookie for a just-authenticated user;
    /// returns the compact token (for diagnostics).</summary>
    function IssueToken(const AAuthenticator: TKAuthenticator): string;
    /// <summary>Validates the request's token, hydrates the session and slides
    /// the expiration. Returns True when the request carries a valid token.</summary>
    function AuthorizeRequest(const AAuthenticator: TKAuthenticator): Boolean;
    /// <summary>Clears the JWT cookie (logout).</summary>
    procedure ClearToken(const AAuthenticator: TKAuthenticator);
  end;

  /// <summary>
  ///   <para>An abstract authenticator that requires UserName and Password as
  ///   auth data.</para>
  ///   <para>How the auth data is checked is deferred to the concrete
  ///   descendants. The value of the UserName auth item is also used as the
  ///   value for the UserName property.</para>
  /// </summary>
  TKClassicAuthenticator = class(TKAuthenticator)
  protected
    procedure InternalDefineAuthData(const AAuthData: TEFNode); override;
    function GetUserName: string; override;
    function GetPassword: string; override;
    function GetSecretCode: string; override;

    /// <summary>
    ///  The body of InternalDefineAuthData: declares the UserName, Password,
    ///  Language and SecretCode auth items. Not virtual, and kept apart from the
    ///  virtual method for the same reason as TKAuthenticator.ApplyConfigDefaults
    ///  — a decorator that re-declares InternalDefineAuthData as abstract can
    ///  still reach this behaviour when it has to answer locally.
    /// </summary>
    procedure DefineStandardAuthData(const AAuthData: TEFNode);
  end;

  /// <summary>The Null authenticator does not require authentication data and
  /// always grants authentication. It is used by default.</summary>
  TKNullAuthenticator = class(TKAuthenticator)
  protected
    procedure InternalDefineAuthData(const AAuthData: TEFNode); override;
    function InternalAuthenticate(
      const AAuthData: TEFNode): Boolean; override;
    function GetIsAuthenticated: Boolean; override;
  public
    /// <summary>
    ///  There is no credential store at all here, so the three members below
    ///  cannot do anything meaningful. They are implemented rather than left
    ///  abstract because abstract members of a factory-created class do not
    ///  fail at build time: they raise "Abstract Error" the first time a user
    ///  reaches the feature, which is a crash instead of an explanation.
    /// </summary>
    function SupportsPasswordChange: Boolean; override;
    /// <summary>Raises: there is no account whose password could be reset.</summary>
    procedure ResetPassword(const AParams: TEFNode); override;
    /// <summary>Raises: no per-user secret exists to enrol a device with.</summary>
    procedure QRGenerate(const AParams: TEFNode); override;
    /// <summary>Always False. No password is stored, so nothing can match one,
    /// and returning True would make an empty password look verified.</summary>
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; override;
  end;

  /// <summary>This class holds a list of registered authenticator
  /// classes.</summary>
  TKAuthenticatorRegistry = class(TEFRegistry)
  private
    class var FInstance: TKAuthenticatorRegistry;
    class function GetInstance: TKAuthenticatorRegistry; static;
  public
    /// <summary>Frees the singleton registry instance.</summary>
    class destructor Destroy;
    /// <summary>The lazily-created singleton registry instance.</summary>
    class property Instance: TKAuthenticatorRegistry read GetInstance;

    /// <summary>Adds an authenticator class to the registry.</summary>
    procedure RegisterClass(const AId: string; const AClass: TKAuthenticatorClass);
  end;

  /// <summary>Creates authenticators by Id.</summary>
  TKAuthenticatorFactory = class(TEFFactory)
  private
    class var FInstance: TKAuthenticatorFactory;
    class function GetInstance: TKAuthenticatorFactory; static;
  public
    /// <summary>Frees the singleton factory instance.</summary>
    class destructor Destroy;
    /// <summary>The lazily-created singleton factory instance.</summary>
    class property Instance: TKAuthenticatorFactory read GetInstance;

    /// <summary>Creates and returns an instance of the authenticator class
    /// identified by AClassId. Raises an exception if said class is not
    /// registered.</summary>
    function CreateObject(const AClassId: string): TKAuthenticator;
  end;

/// <summary>Registers the JWT engine — called from Kitto.Auth.JWT's
/// initialization. The last registration wins.</summary>
procedure RegisterJWTEngine(const AEngine: IKXJWTEngine);
/// <summary>The registered JWT engine, or nil when no JWT-capable unit is
/// linked into the application.</summary>
function GetJWTEngine: IKXJWTEngine;

implementation

uses
  System.SysUtils,
  EF.StrUtils,
  EF.Localization,
  Kitto.Types,
  Kitto.Web.Application,
  Kitto.Web.Session;

var
  FJWTEngine: IKXJWTEngine;

procedure RegisterJWTEngine(const AEngine: IKXJWTEngine);
begin
  FJWTEngine := AEngine;
end;

function GetJWTEngine: IKXJWTEngine;
begin
  Result := FJWTEngine;
end;

// Returns the registered JWT engine, or raises a clear, actionable error when a
// JWT block is configured but no JWT-capable unit was linked into the app.
function RequireJWTEngine: IKXJWTEngine;
begin
  Result := FJWTEngine;
  if not Assigned(Result) then
    raise EKError.Create(_('Auth JWT is configured (a "JWT" block is present under Auth) ' +
      'but JWT support is not linked into this application. Add "Kitto.Auth.JWT" to your ' +
      'project''s UseKitto.pas.'));
end;

{ TKNullAuthenticator }

procedure TKNullAuthenticator.InternalDefineAuthData(const AAuthData: TEFNode);
begin
  // No authentication data required.
end;

function TKNullAuthenticator.GetIsAuthenticated: Boolean;
begin
  Result := True;
end;

function TKNullAuthenticator.InternalAuthenticate(const AAuthData: TEFNode): Boolean;
begin
  Result := True;
end;

function TKNullAuthenticator.SupportsPasswordChange: Boolean;
begin
  // No credentials are stored, so there is nothing to change. Without this the
  // base SetPassword — whose body is empty — would run and the dialog would
  // report success while writing nothing.
  Result := False;
end;

procedure TKNullAuthenticator.ResetPassword(const AParams: TEFNode);
begin
  raise EKError.Create(_('Password reset is not available: this application does not authenticate users.'));
end;

procedure TKNullAuthenticator.QRGenerate(const AParams: TEFNode);
begin
  raise EKError.Create(_('PIN/QR authentication is not available: this application does not authenticate users.'));
end;

function TKNullAuthenticator.IsPasswordMatching(const ASuppliedPasswordHash,
  AStoredPasswordHash: string): Boolean;
begin
  // Never reached: authentication always succeeds without looking at a
  // password, and the password-change flow is refused by
  // SupportsPasswordChange before it gets here.
  Result := False;
end;

{ TKAuthenticatorRegistry }

class destructor TKAuthenticatorRegistry.Destroy;
begin
  FreeAndNil(FInstance);
end;

class function TKAuthenticatorRegistry.GetInstance: TKAuthenticatorRegistry;
begin
  if FInstance = nil then
    FInstance := TKAuthenticatorRegistry.Create;
  Result := FInstance;
end;

procedure TKAuthenticatorRegistry.RegisterClass(const AId: string; const AClass: TKAuthenticatorClass);
begin
  inherited RegisterClass(AId, AClass);
end;

{ TKAuthenticatorFactory }

function TKAuthenticatorFactory.CreateObject(const AClassId: string): TKAuthenticator;
begin
  Result := inherited CreateObject(AClassId) as TKAuthenticator;
end;

class destructor TKAuthenticatorFactory.Destroy;
begin
  FreeAndNil(FInstance);
end;

class function TKAuthenticatorFactory.GetInstance: TKAuthenticatorFactory;
begin
  if FInstance = nil then
    FInstance := TKAuthenticatorFactory.Create(TKAuthenticatorRegistry.Instance);
  Result := FInstance;
end;

{ TKAuthenticator }

function TKAuthenticator.GetAuthData: TEFNode;
begin
  Result := TKWebSession.Current.AuthData;
end;

class function TKAuthenticator.GetCurrent: TKAuthenticator;
begin
  Result := FCurrent;
end;

class procedure TKAuthenticator.SetCurrent(const AValue: TKAuthenticator);
begin
  FCurrent := AValue;
end;

procedure TKAuthenticator.AfterConstruction;
begin
  inherited;
  // Seeding the session's auth data is SESSION work, and the session is
  // thread-local and established per request by the engine: outside the request
  // pipeline there is none. Constructing any authenticator there -- a test, a
  // command-line tool, KIDE -- dereferenced nil and died in the constructor, and
  // that is why Kitto.MasterDetailTests had to be left out of the test project.
  // Inside the pipeline nothing changes: the session is always there by the time
  // an authenticator is built, so this ran unconditionally before and runs
  // unconditionally now.
  if Assigned(TKWebSession.Current) then
  begin
    DefineAuthData(TKWebSession.Current.AuthData);
    TKWebSession.Current.IsAuthenticated := False;
  end;
  // Object state, not session state — see GetIsBCrypted. Explicit even though
  // Delphi zeroes the field, to mirror Kitto1 and to keep the pairing with the
  // line above readable.
  FIsBCrypted := False;
end;

destructor TKAuthenticator.Destroy;
begin
  FreeAndNil(FJWTState);
  inherited;
end;

procedure TKAuthenticator.DefineAuthData(const AAuthData: TEFNode);
begin
  Assert(Assigned(AAuthData), 'Assigned(AAuthData)');

  InternalDefineAuthData(AAuthData);

  InternalDefaultToAuthData(AAuthData);
end;

function TKAuthenticator.GetIsAuthenticated: Boolean;
begin
  Result := TKWebSession.Current.IsAuthenticated;
end;

function TKAuthenticator.GetIsBCrypted: Boolean;
begin
  // Reads the authenticator's OWN field, not the session's: whether credentials
  // are BCrypt-hashed is a property of the configured authenticator class, the
  // same for every user, and it is set once in TKDBCryptAuthenticator's
  // AfterConstruction. This is what Kitto1 did (Kitto.Auth.pas:370-372 in the
  // 3.x sources).
  //
  // It used to read TKWebSession.Current.IsBCrypted, which could never be True:
  // the port moved AuthData, IsAuthenticated and this flag from the object to the
  // session — right for the first two, which ARE per-user — but only the getter
  // and the initialisation were moved, while the one writer that sets it True
  // kept writing the object field through the property. Nothing ever assigned
  // the session flag anything but False, so IsBCrypted always answered False and
  // the BCrypt branch of the change-password comparison was dead code. On top of
  // that, a per-session home cannot work here anyway: the authenticator is a
  // single instance per application, so its AfterConstruction runs once, in
  // whichever session happened to create it, and every other session would have
  // read False regardless.
  Result := FIsBCrypted;
end;

function TKAuthenticator.GetIsClearPassword: Boolean;
begin
  Result := True;
end;

function TKAuthenticator.GetPassword: string;
begin
  Result := '';
end;

function TKAuthenticator.GetSecretCode: string;
begin
  Result := '';
end;

function TKAuthenticator.GetMustChangePassword: Boolean;
begin
  Result := TKWebSession.Current.AuthData.GetInteger('MUST_CHANGE_PASSWORD') = 1;
end;

function TKAuthenticator.GetMustConfirmAccess: Boolean;
begin
  Result := TKWebSession.Current.AuthData.GetInteger('MUST_CONFIRM_ACCESS') = 1;
end;

function TKAuthenticator.GetUserName: string;
begin
  Result := 'PUBLIC';
end;

procedure TKAuthenticator.InternalBeforeAuthenticate(const AAuthData: TEFNode);
begin
end;

procedure TKAuthenticator.InternalDefaultToAuthData(const AAuthData: TEFNode);
begin
  ApplyConfigDefaults(AAuthData);
end;

procedure TKAuthenticator.ApplyConfigDefaults(const AAuthData: TEFNode);
var
  I: Integer;
  LDefaultNode: TEFNode;
  LDefaultsNode: TEFNode;
begin
  // Get meaningful defaults, from configuration.
  //
  // These come from Auth/Defaults, which is authored by whoever writes the
  // application config, so they are trusted and may legitimately carry a macro:
  // Auth/Defaults/Password: %ENV_VAR% pulls a service password from the
  // environment, %Config:...% reads another config node, and so on. They are
  // expanded HERE, as they enter the auth data from configuration.
  //
  // The credential a user TYPES at the login form must never be expanded (see
  // GetSuppliedUserName / GetSuppliedPasswordHash, which now compare it
  // verbatim): expanding it would let anyone type %Config:Auth/PassepartoutPassword%
  // and have it resolve to the real passepartout, logging in as any user. That
  // is why the expansion lives on the config side of the fence and not on the
  // supplied side.
  for I := 0 to AAuthData.ChildCount - 1 do
  begin
    LDefaultNode := Config.FindNode('Defaults/' + AAuthData.Children[I].Name);
    if Assigned(LDefaultNode) then
      AAuthData.Children[I].AsString := LDefaultNode.AsExpandedString
    else
      AAuthData.Children[I].AssignValue(nil);
  end;

  // Seed any EXTRA default that is not one of the standard auth items handled
  // above (UserName/Password/Language/SecretCode). This lets the config pre-set
  // an application-specific auth field the standard flow does not declare -- most
  // usefully the user profile that a %Auth:<field>% macro reads to resolve a
  // profile-dependent HomeView. Example: with
  //   Auth: <Authenticator>
  //     Defaults:
  //       UserName: SYSDBA
  //       Password: ...
  //       PROFILEID: ADMIN
  // %Auth:PROFILEID% resolves to ADMIN before login, so %Auth:PROFILEID%_Home is
  // found. A real login overwrites these with the user record's own fields (the
  // authenticator reads them from the DB), so a seeded value only stands in the
  // pre-/failed-authentication state -- which is exactly what a deliberate
  // default login, and a design-time preview (KIDEX) that cannot link an app's
  // custom authenticator, need. The name is the auth field the app reads, not a
  // fixed 'Profile' keyword: every app names its profile field its own way (SCM
  // uses PROFILEID). Trusted, config-authored, and expanded like the items above.
  LDefaultsNode := Config.FindNode('Defaults');
  if Assigned(LDefaultsNode) then
    for I := 0 to LDefaultsNode.ChildCount - 1 do
      if not Assigned(AAuthData.FindNode(LDefaultsNode.Children[I].Name)) then
        AAuthData.SetString(LDefaultsNode.Children[I].Name,
          LDefaultsNode.Children[I].AsExpandedString);
end;

function TKAuthenticator.SupportsPasswordChange: Boolean;
begin
  // Every password-based authenticator overrides SetPassword and can honour a
  // change. Those that do not own the credentials (Auth: LDAP) override this
  // with False, so callers can refuse instead of reporting a silent success.
  Result := True;
end;

function TKAuthenticator.EffectiveConfigNode: TEFTree;
begin
  Result := Config;
end;

procedure TKAuthenticator.SetJWTState(const AValue: TObject);
begin
  if FJWTState <> AValue then
  begin
    FJWTState.Free;
    FJWTState := AValue;
  end;
end;

function TKAuthenticator.IsJWTEnabled: Boolean;
begin
  // A JWT sub-node under the auth config turns on the token envelope; the base
  // then delegates issue/validate/clear to the registered IKXJWTEngine.
  Result := Assigned(Config.FindNode('JWT'));
end;

function TKAuthenticator.IssueToken: string;
begin
  if IsJWTEnabled then
    Result := RequireJWTEngine.IssueToken(Self)
  else
    Result := '';
end;

procedure TKAuthenticator.AuthorizeRequest;
begin
  // When a JWT envelope is configured, delegate to the engine to validate the
  // request token, hydrate the session and slide the expiration. Otherwise
  // there is nothing to do (plain session-cookie authenticators).
  if IsJWTEnabled then
    RequireJWTEngine.AuthorizeRequest(Self);
end;

procedure TKAuthenticator.Logout;
var
  LEngine: IKXJWTEngine;
begin
  // Clear the JWT cookie first (when configured) so the browser stops sending a
  // stale token, then drop the server-side auth data and session flag.
  if IsJWTEnabled then
  begin
    LEngine := GetJWTEngine;
    if Assigned(LEngine) then
      LEngine.ClearToken(Self);
  end;
  ClearAuthData;
  TKWebSession.Current.IsAuthenticated := False;
end;

procedure TKAuthenticator.SetPassword(const AValue: string);
begin
end;

procedure TKAuthenticator.ClearAuthData;
begin
  // Under the session's auth lock: a page refresh of the same session, on
  // another thread, may be copying this tree right now (RenewSession).
  TKWebSession.Current.LockAuthData;
  try
    TKWebSession.Current.AuthData.Clear;
    DefineAuthData(TKWebSession.Current.AuthData);
  finally
    TKWebSession.Current.UnlockAuthData;
  end;
end;

procedure TKAuthenticator.InternalAfterAuthenticate(
  const AAuthData: TEFNode);
begin
end;

function TKAuthenticator.RehydrateAuthData(const AUserName: string;
  const AAuthData: TEFNode): Boolean;
begin
  // Default: nothing to reload. Overridden by authenticators that own a user
  // record (TKDBAuthenticator).
  Result := True;
end;

procedure TKAuthenticator.AssignSessionAuthData(const AAuthData: TEFNode);
begin
  // See ClearAuthData for the lock.
  TKWebSession.Current.LockAuthData;
  try
    TKWebSession.Current.AuthData.Assign(AAuthData);
  finally
    TKWebSession.Current.UnlockAuthData;
  end;
end;

function TKAuthenticator.Authenticate(const AAuthData: TEFNode): Boolean;
begin
  Assert(Assigned(AAuthData), 'Assigned(AAuthData)');

  Result := False;
  // Make sure the macros are enabled while authenticating.
  AssignSessionAuthData(AAuthData);
  try
    InternalBeforeAuthenticate(AAuthData);
    Result := InternalAuthenticate(AAuthData);
    TKWebSession.Current.IsAuthenticated := Result;
    if Result then
    begin
      InternalAfterAuthenticate(AAuthData);
      // Pick up any data changed by InternalAfterAuthenticate.
      AssignSessionAuthData(AAuthData);
      // Issue the JWT cookie once the session carries the final identity, when a
      // JWT envelope is configured. The engine reads the user name and the
      // session claims (display name, database, language).
      if IsJWTEnabled then
        RequireJWTEngine.IssueToken(Self);
    end;
  finally
    if not Result then
      // Make sure we don't expand any macro that hasn't passed
      // authentication.
      Logout;
  end;
end;

{ TKClassicAuthenticator }

function TKClassicAuthenticator.GetPassword: string;
begin
  Result := TKWebSession.Current.AuthData.GetString('Password');
end;

function TKClassicAuthenticator.GetSecretCode: string;
begin
  Result := TKWebSession.Current.AuthData.GetString('SecretCode');
end;

function TKClassicAuthenticator.GetUserName: string;
begin
  Result := TKWebSession.Current.AuthData.GetString('UserName');
end;

procedure TKClassicAuthenticator.InternalDefineAuthData(const AAuthData: TEFNode);
begin
  DefineStandardAuthData(AAuthData);
end;

procedure TKClassicAuthenticator.DefineStandardAuthData(const AAuthData: TEFNode);
begin
  AAuthData.SetString('UserName', '');
  AAuthData.SetString('Password', '');
  AAuthData.SetString('Language', '');
  AAuthData.SetString('SecretCode','');
end;

initialization
  TKAuthenticatorRegistry.Instance.RegisterClass(NODE_NULL_VALUE, TKNullAuthenticator);

finalization
  TKAuthenticatorRegistry.Instance.UnregisterClass(NODE_NULL_VALUE);

end.

