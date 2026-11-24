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
///  Defines the DB authenticator, an authenticator that uses a custom
///  table on the database to store users and passwords.
/// </summary>
unit Kitto.Auth.DB;

{$I Kitto.Defines.inc}

interface

uses
  System.RegularExpressions,
  {$IFDEF MSWINDOWS}
  // Only for the QR bitmap handed to AfterQRGeneration; see QRGenerate.
  Vcl.Graphics,
  {$ENDIF}
  EF.DB,
  EF.Tree,
  Kitto.Auth;

const
  // The %DB.TRUE% / %DB.FALSE% macros expand to the dialect-specific boolean literal
  // (1/0 on SQL Server and Oracle, TRUE/FALSE on PostgreSQL and Firebird 3+).
  // This lets the same default query work whether IS_ACTIVE / MUST_CHANGE_PASSWORD
  // are declared as integer/BIT/smallint or as native boolean.
  DEFAULT_READUSERCOMMANDTEXT =
    'select USER_NAME, PASSWORD_HASH, EMAIL_ADDRESS, MUST_CHANGE_PASSWORD from KITTO_USERS where IS_ACTIVE = %DB.TRUE% and USER_NAME = :USER_NAME';
  DEFAULT_SETPASSWORDCOMMANDTEXT =
    'update KITTO_USERS set PASSWORD_HASH = :PASSWORD_HASH, MUST_CHANGE_PASSWORD = %DB.FALSE% where IS_ACTIVE = %DB.TRUE% and USER_NAME = :USER_NAME';
  DEFAULT_RESETPASSWORDCOMMANDTEXT =
    'update KITTO_USERS set PASSWORD_HASH = :PASSWORD_HASH, MUST_CHANGE_PASSWORD = %DB.TRUE% where IS_ACTIVE = %DB.TRUE% and EMAIL_ADDRESS = :EMAIL_ADDRESS AND USER_NAME = :USER_NAME';
  DEFAULT_REGISTERNEWUSERCOMMANDTEXT =
    'insert into KITTO_USERS (USER_NAME, PASSWORD_HASH, IS_ACTIVE, MUST_CHANGE_PASSWORD, EMAIL_ADDRESS) VALUES (:USER_NAME, :PASSWORD_HASH, %DB.TRUE%, %DB.TRUE%, :EMAIL_ADDRESS)';
  DEFAULT_BCRYPT_READUSERCOMMANDTEXT =
    'select USER_NAME, PASSWORD_HASH, PASSWORD_B_HASH, EMAIL_ADDRESS, MUST_CHANGE_PASSWORD from KITTO_USERS where IS_ACTIVE = %DB.TRUE% and USER_NAME = :USER_NAME';
  DEFAULT_BCRYPT_SETPASSWORDCOMMANDTEXT =
    'update KITTO_USERS set PASSWORD_B_HASH = :PASSWORD_HASH, PASSWORD_HASH = null, MUST_CHANGE_PASSWORD = %DB.FALSE% where IS_ACTIVE = %DB.TRUE% and USER_NAME = :USER_NAME';
  DEFAULT_BCRYPT_RESETPASSWORDCOMMANDTEXT =
    'update KITTO_USERS set PASSWORD_B_HASH = :PASSWORD_HASH, PASSWORD_HASH = null, MUST_CHANGE_PASSWORD = %DB.TRUE% where IS_ACTIVE = %DB.TRUE% and EMAIL_ADDRESS = :EMAIL_ADDRESS AND USER_NAME = :USER_NAME';

type
  /// <summary>User data read from the database. Used internally as a helper
  /// class.</summary>
  TKAuthUser = class
  private
    FName: string;
    FPasswordHash: string;
  public
    /// <summary>The user name read from the database.</summary>
    property Name: string read FName write FName;
    /// <summary>The password hash read from the database.</summary>
    property PasswordHash: string read FPasswordHash write FPasswordHash;
  end;

  /// <summary>
  ///   <para>The DB authenticator uses a custom table in the database to
  ///   authenticate users. The table has fixed name and structure. To use a
  ///   different table name or structure, set parameters or create a
  ///   descendant. The authenticator needs the same auth items as its ancestor
  ///   <see cref="TKClassicAuthenticator" />.</para>
  ///   <para>In order for this authenticator to work, it is required that the
  ///   database contains a table called KITTO_USERS with the following
  ///   structure:</para>
  ///   <list type="table">
  ///     <listheader>
  ///       <term>Term</term>
  ///       <description>Description</description>
  ///     </listheader>
  ///     <item>
  ///       <term>USER_NAME</term>
  ///       <description>String uniquely identifying the user.</description>
  ///     </item>
  ///     <item>
  ///       <term>EMAIL_ADDRESS</term>
  ///       <description>Unique e-mail address for the user. This is optional,
  ///       and only used by ResetPassword.</description>
  ///     </item>
  ///     <item>
  ///       <term>PASSWORD_HASH</term>
  ///       <description>String containing the MD5 hash of the user's
  ///       password.</description>
  ///     </item>
  ///     <item>
  ///       <term>IS_ACTIVE</term>
  ///       <description>Set to 0 to disable (ignore) a user. Disabled users
  ///       will not be able to log in.</description>
  ///     </item>
  ///   </list>
  ///   <para>When Authenticate is called, the authenticator fetches the user
  ///   record (if active) and checks the supplied password against the MD5
  ///   hash stored there. You can use clear-text passwords instead of MD5
  ///   hashes if you set the IsClearPassword parameter to True. You can also
  ///   override the SQL select statement used to get the user record through
  ///   the ReadUserCommandText parameter, which allows you to use a different
  ///   structure without the need to define an inherited authenticator.</para>
  ///   <para>Parameters:</para>
  ///   <list type="table">
  ///     <listheader>
  ///       <term>Term</term>
  ///       <description>Description</description>
  ///     </listheader>
  ///     <item>
  ///       <term>IsClearPassword</term>
  ///       <description>Set this item to True to signify that the password is
  ///       stored in clear, and not hashed, in the database. Default
  ///       False.</description>
  ///     </item>
  ///     <item>
  ///       <term>ReadUserCommandText</term>
  ///       <description>A SQL select statement that selects a single user
  ///       record, with the fields USER_NAME and PASSWORD_HASH and a single
  ///       string parameter that will be filled in with the user name.
  ///       Example: select UNAME as USER_NAME, pwd as PASSWORD_HASH from USERS
  ///       where ENABLED = 1 and UNAME = :P1 Any additional fields returned by
  ///       the statement are kept as part of the auth data. Example: select
  ///       USER_NAME, PASSWORD_HASH, SOMEFIELD from USERS where IS_ACTIVE = 1
  ///       and USER_NAME = :P1 The item SOMEFIELD will be available as part of
  ///       the auth data (and as such, through the authentication-related
  ///       macros as well) for as long as the user is logged in. The item will
  ///       be of whatever data type SOMEFIELD is. You can have more than one
  ///       such items. This technique is useful to apply fixed user-dependent
  ///       filters to data sets and data partitioning among users, for
  ///       example.</description>
  ///     </item>
  ///     <item>
  ///       <term>IsPassepartoutEnabled</term>
  ///       <description>Set this item to True to signify that the passepartout
  ///       password is enabled (that means that a user can authenticate wither
  ///       with her own password or the passepartout password). If the
  ///       passepartout password is used to log in, the
  ///       IsPassepartoutAuthentication Boolean item is set to True into
  ///       AuthData.</description>
  ///     </item>
  ///     <item>
  ///       <term>PassepartoutPassword</term>
  ///       <description>A password to be used as a passepartout for every user
  ///       account. Setting this parameter has no effect if
  ///       IsPassepartoutEnabled is not True. The value of this parameter
  ///       represents a cleartext or hashed password depending on the value of
  ///       IsClearPassword.</description>
  ///     </item>
  ///     <item>
  ///       <term>AfterAuthenticateCommandText</term>
  ///       <description>Optional SQL statement that will be executed just
  ///       after authentication. Supports macros, even authentication-related
  ///       ones.</description>
  ///     </item>
  ///     <item>
  ///       <term>SetPasswordCommandText</term>
  ///       <description>A SQL update statement that updates the password field
  ///       of a given user's record. The statement must have two params named
  ///       USER_NAME (that will be filled with the current user's name) and
  ///       PASSWORD_HASH (that will be filled with the new password or
  ///       password hash depending on the state of IsClearPassword). By
  ///       default, the standard KITTO_USERS table is updated. This statement
  ///       is executed when the authenticator's Password property is set in
  ///       code.</description>
  ///     </item>
  ///   </list>
  /// </summary>
  TKDBAuthenticator = class(TKClassicAuthenticator)
  strict protected
    function GetIsClearPassword: Boolean; override;
    procedure SetPassword(const AValue: string); override;

    /// <summary>Generates and returns a random password. Apply application-defined
    /// rules by overriding this method.</summary>
    function GenerateRandomPassword: string; virtual;

    /// <summary>
    ///  True when the credential this authenticator verifies IS the password
    ///  stored in the user record. A descendant that delegates the check
    ///  elsewhere returns False: TKOSDBAuthenticator does exactly that when it
    ///  authenticates the operating-system user, because there the password
    ///  field carries nothing by design and the OS has already vouched for the
    ///  identity. Everything that DOES compare against a stored password must
    ///  leave this True.
    /// </summary>
    function IsPasswordTheStoredCredential: Boolean; virtual;

    /// <summary>
    ///  True (and logs the reason) when the login must be refused because the
    ///  password is the credential here and one of the two sides of the
    ///  comparison is empty. Neither side may be: GetStringHash('') returns '',
    ///  so an empty typed password produces an empty hash, which matches an
    ///  empty or NULL stored password - a login with no credential at all.
    ///  A user whose record carries no password gets in through the
    ///  password-reset flow, which mails them a temporary password; it does not
    ///  go through here.
    /// </summary>
    function RefuseEmptyPasswordLogin(const AUserName, ASuppliedPassword,
      AStoredPassword: string): Boolean;

    /// <summary>Returns True if the passepartout mechanism is enabled and the
    /// supplied password matches the passpartout password.</summary>
    function InternalAuthenticate(const AAuthData: TEFNode): Boolean; override;

    function GetDatabaseName: string;

    /// <summary>Returns the SQL statement to be used to update the password
    /// (or password hash) in a user's record in the database. Override this
    /// method to change the name or the structure of the predefined table of
    /// users.</summary>
    /// <remarks>The statement should have two params named PASSWORD_HASH and
    /// USER_NAME that will be filled in with the data used to locate the
    /// record and update the password.</remarks>
    function GetSetPasswordCommandText: string;

    /// <summary>Returns the SQL statement to be used to reset the password
    /// (or password hash) in a user's record in the database. Override this
    /// method to change the name or the structure of the predefined table of
    /// users.</summary>
    /// <remarks>The statement should have two params named PASSWORD_HASH and
    /// EMAIL_ADDRESS that will be filled in with the data used to locate the
    /// record and update the password.</remarks>
    function GetResetPasswordCommandText: string;

    /// <summary>Returns the SQL statement to be used to register a new user
    /// (with temporary password hash) in a user's record in the database.
    /// Override this method to change the name or the structure of the predefined
    /// table of users.</summary>
    /// <remarks>The statement should have three params named USER_NAME, PASSWORD_HASH
    /// and EMAIL_ADDRESS that will be filled in with the data used to locate the
    /// record and update the password.</remarks>
    function GetRegisterNewUserCommandText: string;

    /// <summary>Creates and returns an object with the user data read from the
    /// database. It is actually a template method that calls a set of virtual
    /// methods to do its job.</summary>
    function CreateAndReadUser(const AUserName: string; const AAuthData: TEFNode): TKAuthUser;

    /// <summary>Executes the AfterAuthenticateCommandText, if any
    /// provided.</summary>
    procedure InternalAfterAuthenticate(const AAuthData: TEFNode); override;

    /// <summary>Creates and returns an empty instance of TKAuthUser. Override
    /// this method if you need to use a descendant instead.</summary>
    function CreateUser: TKAuthUser; virtual;

    /// <summary>Returns the SQL statement to be executed just after
    /// authentication succeeded.</summary>
    function GetAfterAuthenticateCommandText: string; virtual;

    /// <summary>Returns the SQL statement to be used to read the user data
    /// from the database. Override this method to change the name or the
    /// structure of the predefined table of users.</summary>
    function GetReadUserCommandText(const AUserName: string): string; virtual;

    procedure GetSuppliedAuthData(const AAuthData: TEFNode; const AHashNeeded: Boolean;
      out ASuppliedUserName, ASuppliedPasswordHash: string;
      out AIsPassepartoutAuthentication: Boolean); virtual;

    /// <summary>Extracts from AAuthData the supplied password, in order to use
    /// it in an authentication attempt. If AHashNeeded is True, the password
    /// hash will be returned instead of the clear password.</summary>
    function GetSuppliedPasswordHash(const AAuthData: TEFNode;
      const AHashNeeded: Boolean): string; virtual;

    /// <summary>Extracts from AAuthData the supplied user name, in order to
    /// use it in an authentication attempt.</summary>
    function GetSuppliedUserName(const AAuthData: TEFNode): string; virtual;

    /// <summary>True if passepartout mode is enabled and the supplied password
    /// matches the passepartout password.</summary>
    function IsPassepartoutAuthentication(
      const ASuppliedPassword: string): Boolean; virtual;

    /// <summary>Returns True if AUserName is a valid user name. It is
    /// implemented using GetReadUserSQL to perform a query against the
    /// database to see if authentication data is available for this
    /// user.</summary>
    function IsValidUserName(const AUserName: string): Boolean; virtual;

    /// <summary>
    ///   <para>Reads data from the current record of the specified DB query
    ///   and stores it into AUser.</para>
    ///   <para>Override this method if your table of users has a non-default
    ///   structure or if you want to customize secret code generation
    ///   (for PIN-OTP authentication).</para>
    ///   <para>This method is usually overridden together with GetReadUserSQL,
    ///   and possibly also CreateUser.</para>
    /// </summary>
    procedure ReadUserFromRecord(const AUser: TKAuthUser;
      const ADBQuery: TEFDBQuery; const AAuthData: TEFNode); virtual;

    /// <summary>
    ///  Called by ResetPassword after generating the new random password
    ///  but before writing it to the database. Override this method to send
    ///  the generated password to the user so he can log in and change it.
    ///  The default implementation does nothing.
    /// </summary>
    /// <param name="AParams">
    ///  Contains all the params passed to ResetPassword plus the generated
    ///  password (in the "Password" node). This method is not supposed to
    ///  modify the params but can add custom ones if needed. They will be passed
    ///  back to the initiator of the password reset flow.
    /// </param>
    procedure BeforeResetPassword(const AParams: TEFNode); virtual;

    /// <summary>
    ///  Called by ResetPassword after writing the new random password
    ///  to the database but before committing the transaction. Override this method
    ///  if you need to perform additional database-related operations at this point
    ///  in time.
    ///  The default implementation does nothing.
    /// </summary>
    /// <param name="AParams">
    ///  Contains all the params passed to ResetPassword plus the generated
    ///  password (in the "Password" node). This method is not supposed to
    ///  modify the params but can add custom ones if needed. They will be passed
    ///  back to the initiator of the password reset flow.
    /// </param>
    procedure AfterResetPassword(const ADBConnection: TEFDBConnection; const AParams: TEFNode); virtual;

    {$IFDEF MSWINDOWS}
    /// <summary>
    ///  Called by QRGenerate after generating QR code for OTP authentication.
    ///  Override this method if you need to use this QR for any purpose, such
    ///  as sending it via email to a user. The default implementation does nothing.
    /// </summary>
    /// <param name="AParams">
    ///  Contains all the params passed to QRGenerate. This method is not supposed
    ///  to modify the params but can add custom ones if needed. They will be passed
    ///  back to the initiator of the QR generation flow.
    /// </param>
    procedure AfterQRGeneration(const AQRCode: TBitmap; const AParams: TEFNode); virtual;
    {$ENDIF}

  public
    /// <summary>Refills AAuthData from the KITTO_USERS record (no password
    /// check), for an identity a validated JWT already proved but whose session
    /// was lost. Returns False when the user is unknown or no longer active —
    /// the read filters IS_ACTIVE — so a disabled account's token stops
    /// working. See TKAuthenticator.RehydrateAuthData.</summary>
    function RehydrateAuthData(const AUserName: string;
      const AAuthData: TEFNode): Boolean; override;

    /// <summary>Returns True if ASuppliedPasswordHash matches
    /// AStoredPasswordHash. By default this means that they are the same
    /// value. A descendant might use different matching rules or disable
    /// matching altogether by overriding this method.</summary>
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; override;

    /// <summary>Generates a new random password for the user identified by
    /// UserName/EmailAddress in AParams, stores it (flagged as must-change) in
    /// the database and returns it via the AParams "Password" node.</summary>
    procedure ResetPassword(const AParams: TEFNode); override;

    /// <summary>Generates a QR code encoding the OTP shared secret for the user
    /// identified in AParams, for use in PIN (TOTP) authentication.</summary>
    procedure QRGenerate(const AParams: TEFNode); override;
  end;

  /// <summary>Same Authenticator as TKDBAuthenticator, it only manages hashed passwords
  ///  using BCrypt algorithm (in BCrypt unit).
  ///  It requires a field on the custom user table
  ///  named PASSWORD_HASH at least 60-CHARACTER LONG.
  ///  It shifts automatically from TKDBAuthenticator's hash method
  ///  to BCrypt (after the first successful login), without the need to do
  ///  a password reset.</summary>
  TKDBCryptAuthenticator = class(TKDBAuthenticator)

  strict private
    function GetRandomSpecialChar: char;
    /// <summary>BCrypt-hashes AValue. AForcedCost, when &gt; 0, sets the work
    /// factor for this one hash (the rehash path passes the stored cost + 1);
    /// otherwise it comes from BCryptCostValue in config, or 13. Passing the
    /// cost per call replaces a shared field that leaked the last rehash's cost
    /// into every later hash and was written from request threads without a
    /// lock.</summary>
    function GetBCryptedString(const AValue: string; const AForcedCost: Integer = 0): string;
    /// <summary>The password-policy regular expression and its error message.
    /// Falls back to the built-in defaults when the optional ValidatePassword
    /// node is absent, instead of dereferencing a nil node.</summary>
    procedure GetPasswordPolicy(out ARegEx, AErrorMsg: string);
    /// <summary>Stores AValue as the new password, hashing per IsClearPassword.
    /// When AValidatePolicy is True the ValidatePassword rule is enforced first;
    /// the migration/rehash path passes False, because the value is a password
    /// the user already authenticated with — re-validating it there would refuse
    /// a legitimate legacy password (e.g. shorter than the current rule) and
    /// lock the user out of the very login that would upgrade it.</summary>
    procedure StorePassword(const AValue: string; const AValidatePolicy: Boolean;
      const AForcedCost: Integer = 0);
  protected
    /// <summary>Generates and returns a random password compatible with special rules defined in SetPassword.</summary>
    function GenerateRandomPassword: string; override;

    /// <summary>
    ///   <para>Reads data from the current record of the specified DB query
    ///   and stores it into AUser.</para>
    ///   <para>This method is usually overridden together with GetReadUserSQL,
    ///   and possibly also CreateUser.</para>
    /// </summary>
    procedure ReadUserFromRecord(const AUser: TKAuthUser;
      const ADBQuery: TEFDBQuery; const AAuthData: TEFNode); override;

    /// <summary>Extracts from AAuthData the supplied password, in order to use
    /// it in an authentication attempt.</summary>
    function GetSuppliedPasswordHash(const AAuthData: TEFNode; const AHashNeeded: Boolean): string; override;

    procedure SetPassword(const AValue: string); override;
    /// <summary>Raise an exception in auto-login fails.</summary>
    function InternalAuthenticate(const AAuthData: TEFNode): Boolean; override;

    /// <summary>Returns the SQL statement to be used to read the user data
    /// from the database. Override this method to change the name or the
    /// structure of the predefined table of users.</summary>
    function GetReadUserCommandText(const AUserName: string): string; override;

    /// <summary>Returns the SQL statement to be used to update the password
    /// (or password hash) in a user's record in the database. Override this
    /// method to change the name or the structure of the predefined table of
    /// users.</summary>
    /// <remarks>The statement should have two params named PASSWORD_HASH and
    /// USER_NAME that will be filled in with the data used to locate the
    /// record and update the password.</remarks>
    function GetSetPasswordCommandText: string;

    /// <summary>Returns the SQL statement to be used to reset the password
    /// (or password hash) in a user's record in the database. Override this
    /// method to change the name or the structure of the predefined table of
    /// users.</summary>
    /// <remarks>The statement should have two params named PASSWORD_HASH and
    /// EMAIL_ADDRESS that will be filled in with the data used to locate the
    /// record and update the password.</remarks>
    function GetResetPasswordCommandText: string;

  public
    /// <summary>Marks the authenticator as BCrypt-enabled.</summary>
    procedure AfterConstruction; override;
    /// <summary>Returns True if the supplied password matches the stored BCrypt
    /// hash; transparently rehashes and upgrades the stored hash on success when
    /// its strength (cost) is below the configured threshold.</summary>
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; override;
    /// <summary>Resets the user's password to a new random, BCrypt-hashed value
    /// respecting the ValidatePassword rules.</summary>
    procedure ResetPassword(const AParams: TEFNode); override;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  Data.DB,
  EF.Localization,
  EF.Logger,
  EF.Types,
  EF.StrUtils,
  Kitto.Types,
  Kitto.Config,
  Kitto.DatabaseRouter,
  Kitto.Web.Session,
  Kitto.BCrypt,
  Kitto.Base32U,
  Kitto.GoogleOTP,
  Kitto.DelphiZXingQRCode;

{ TKDBAuthenticator }

{$IFDEF MSWINDOWS}
procedure TKDBAuthenticator.AfterQRGeneration(const AQRCode: TBitmap;
  const AParams: TEFNode);
begin
end;
{$ENDIF}

procedure TKDBAuthenticator.AfterResetPassword(const ADBConnection: TEFDBConnection; const AParams: TEFNode);
begin
end;

procedure TKDBAuthenticator.BeforeResetPassword(const AParams: TEFNode);
begin
end;

function TKDBAuthenticator.RehydrateAuthData(const AUserName: string;
  const AAuthData: TEFNode): Boolean;
var
  LUser: TKAuthUser;
begin
  if AUserName = '' then
    Exit(False);
  // CreateAndReadUser returns nil when the query — which filters IS_ACTIVE —
  // finds no row: unknown, deactivated or deleted user. It also fills AAuthData
  // with every column of the record (MUST_CHANGE_PASSWORD and the rest), which
  // is exactly what the imposed-step gate and the %Auth:field% macros need.
  LUser := CreateAndReadUser(AUserName, AAuthData);
  try
    Result := Assigned(LUser);
  finally
    LUser.Free;
  end;
end;

function TKDBAuthenticator.CreateAndReadUser(
  const AUserName: string; const AAuthData: TEFNode): TKAuthUser;
var
  LDBConnection: TEFDBConnection;
  LQuery: TEFDBQuery;
begin
  Result := nil;
  LDBConnection := TKConfig.DatabaseFor(GetDatabaseName);
  LQuery := LDBConnection.CreateDBQuery;
  try
    LQuery.CommandText := GetReadUserCommandText(AUserName);
    if LQuery.Params.Count <> 1 then
      raise EKError.CreateFmt(_('Wrong authentication query text: %s'), [LQuery.CommandText]);
    LQuery.Params[0].AsString := AUserName;
    LQuery.Open;
    try
      if not LQuery.DataSet.IsEmpty then
      begin
        Result := TKAuthUser.Create;
        try
          ReadUserFromRecord(Result, LQuery, AAuthData);
        except
          Result.Free;
          raise;
        end;
      end;
    finally
      LQuery.Close;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TKDBAuthenticator.CreateUser: TKAuthUser;
begin
  Result := TKAuthUser.Create;
end;

function TKDBAuthenticator.IsPasswordMatching(const ASuppliedPasswordHash,
  AStoredPasswordHash: string): Boolean;
begin
  Result := ASuppliedPasswordHash = AStoredPasswordHash;
end;

function TKDBAuthenticator.GenerateRandomPassword: string;
begin
  Result := GetRandomString(8, '01');
end;

function TKDBAuthenticator.GetAfterAuthenticateCommandText: string;
begin
  Result := Config.GetExpandedString('AfterAuthenticateCommandText');
end;

function TKDBAuthenticator.GetDatabaseName: string;
var
  LDatabaseRouterNode: TEFNode;
begin
  LDatabaseRouterNode := Config.FindNode('DatabaseRouter');
  if Assigned(LDatabaseRouterNode) then
    Result := TKDatabaseRouterFactory.Instance.GetDatabaseName(
      LDatabaseRouterNode.AsString, Self, LDatabaseRouterNode)
  else
    Result := TKConfig.Instance.DatabaseName;
end;

function TKDBAuthenticator.GetIsClearPassword: Boolean;
begin
  Result := Config.GetBoolean('IsClearPassword');
end;

function TKDBAuthenticator.GetReadUserCommandText(const AUserName: string): string;
begin
  Result := Config.GetString('ReadUserCommandText',
    DEFAULT_READUSERCOMMANDTEXT);
end;

function TKDBAuthenticator.GetRegisterNewUserCommandText: string;
begin
  Result := Config.GetString('RegisterNewUserCommandText', DEFAULT_REGISTERNEWUSERCOMMANDTEXT);
end;

function TKDBAuthenticator.GetResetPasswordCommandText: string;
begin
  Result := Config.GetString('ResetPasswordCommandText', DEFAULT_RESETPASSWORDCOMMANDTEXT);
end;

function TKDBAuthenticator.GetSuppliedPasswordHash(
  const AAuthData: TEFNode; const AHashNeeded: Boolean): string;
begin
  // The password TYPED at the login form is compared verbatim: it must never be
  // macro-expanded. Expanding it let a user type %Config:Auth/PassepartoutPassword%
  // and have it resolve to the real passepartout, or %Auth:UserName% and drive
  // the engine into a self-referential loop. Macros in a *default* credential
  // (Auth/Defaults) are expanded where they enter the auth data, in
  // TKAuthenticator.ApplyConfigDefaults.
  Result := AAuthData.GetString('Password');
  if AHashNeeded then
    Result := GetStringHash(Result);
end;

function TKDBAuthenticator.GetSuppliedUserName(const AAuthData: TEFNode): string;
begin
  // Verbatim, for the same reason as GetSuppliedPasswordHash.
  Result := AAuthData.GetString('UserName');
end;

procedure TKDBAuthenticator.InternalAfterAuthenticate(const AAuthData: TEFNode);

  function GetLocalDatabaseName: string;
  var
    LDatabaseRouterNode: TEFNode;
  begin
    LDatabaseRouterNode := Config.FindNode('AfterAuthenticateDatabaseRouter');
    if Assigned(LDatabaseRouterNode) then
      Result := TKDatabaseRouterFactory.Instance.GetDatabaseName(
        LDatabaseRouterNode.AsString, Self, LDatabaseRouterNode)
    else
      Result := TKConfig.Instance.DatabaseName;
  end;

var
  LDBConnection: TEFDBConnection;
  LAfterAuthenticateCommandText: string;
begin
  inherited;
  LAfterAuthenticateCommandText := GetAfterAuthenticateCommandText;

  if LAfterAuthenticateCommandText <> '' then
  begin
    LDBConnection := TKConfig.DatabaseFor(GetLocalDatabaseName);
    LDBConnection.ExecuteImmediate(LAfterAuthenticateCommandText);
  end;
end;

procedure TKDBAuthenticator.GetSuppliedAuthData(
  const AAuthData: TEFNode; const AHashNeeded: Boolean;
  out ASuppliedUserName, ASuppliedPasswordHash: string;
  out AIsPassepartoutAuthentication: Boolean);
var
  LSuppliedPassword: string;
  LLoginTypeNode: TEFNode;
begin
  LLoginTypeNode := Config.FindNode('LoginType');
  ASuppliedUserName := GetSuppliedUserName(AAuthData);
  if (Assigned(LLoginTypeNode)) and (AnsiUpperCase(LLoginTypeNode.AsString) = 'PIN') then
    ASuppliedPasswordHash := GetSuppliedPasswordHash(AAuthData, False)
  else
    ASuppliedPasswordHash := GetSuppliedPasswordHash(AAuthData, AHashNeeded);
  LSuppliedPassword := GetSuppliedPasswordHash(AAuthData, False);
  AIsPassepartoutAuthentication := IsPassepartoutAuthentication(LSuppliedPassword);
end;

function TKDBAuthenticator.InternalAuthenticate(const AAuthData: TEFNode): Boolean;
var
  LSuppliedUserName: string;
  LSuppliedPasswordHash: string;
  LSuppliedPassword: string;
  LIsPassepartoutAuthentication: Boolean;
  LUser: TKAuthUser;
  LLoginTypeNode: TEFNode;
  LTokenValue: integer;
begin
  GetSuppliedAuthData(AAuthData, not IsClearPassword,
    LSuppliedUserName, LSuppliedPasswordHash, LIsPassepartoutAuthentication);
  // Read before CreateAndReadUser: reading the user record overwrites the
  // 'Password' item of the auth data with the STORED credential (see
  // TKDBCryptAuthenticator.ReadUserFromRecord), so afterwards there is no way
  // to tell what the user actually typed.
  LSuppliedPassword := GetSuppliedPasswordHash(AAuthData, False);

  if LSuppliedUserName <> '' then
  begin
    LUser := CreateAndReadUser(LSuppliedUserName, AAuthData);
    try
      if Assigned(LUser) then
      begin
        LLoginTypeNode := Config.FindNode('LoginType');
        if LIsPassepartoutAuthentication then
        begin
          AAuthData.SetBoolean('IsPassepartoutAuthentication', True);
          Result := True;
        end
        else if (Assigned(LLoginTypeNode)) and (AnsiUpperCase(LLoginTypeNode.AsString) = 'PIN') then
        begin
          // No per-user secret, no PIN login. See ReadUserFromRecord: falling
          // back to a secret derived from the user name would let anyone who
          // knows a user name compute the code, and this branch REPLACES the
          // password check, so that would be a login with no credential at all.
          if AAuthData.GetString('SecretCode') = '' then
          begin
            TEFLogger.Instance.Log('PIN login refused: the user record carries no '+
              'SECRET_CODE. Add the column to ReadUserCommandText and store a random '+
              'per-user secret in it.', TEFLogger.LOG_ALWAYS);
            Result := False;
          end
          else if not TryStrToInt(LSuppliedPasswordHash,LTokenValue) then
            Result := False
          else
            Result := ValidateTOPT(AAuthData.GetString('SecretCode'),LTokenValue);
        end
        else if RefuseEmptyPasswordLogin(LSuppliedUserName, LSuppliedPassword,
            LUser.PasswordHash) then
          Result := False
        else
          Result := IsPasswordMatching(LSuppliedPasswordHash, LUser.PasswordHash);
      end
      else
        Result := False;
    finally
      FreeAndNil(LUser);
    end;
  end
  else
    Result := False;
end;

function TKDBAuthenticator.IsPasswordTheStoredCredential: Boolean;
begin
  Result := True;
end;

function TKDBAuthenticator.RefuseEmptyPasswordLogin(const AUserName,
  ASuppliedPassword, AStoredPassword: string): Boolean;
begin
  Result := False;
  if not IsPasswordTheStoredCredential then
    Exit;
  if ASuppliedPassword = '' then
  begin
    TEFLogger.Instance.LogFmt('Authentication refused for user %s: empty password.',
      [AUserName], TEFLogger.LOG_DETAILED);
    Result := True;
  end
  else if AStoredPassword = '' then
  begin
    TEFLogger.Instance.LogFmt('Authentication refused for user %s: the user record '+
      'carries no password (the column is empty or NULL). Send the user a temporary '+
      'password with the password-reset flow instead: an empty stored password would '+
      'otherwise be matched by an empty typed one.', [AUserName], TEFLogger.LOG_ALWAYS);
    Result := True;
  end;
end;

function TKDBAuthenticator.IsPassepartoutAuthentication(const ASuppliedPassword: string): Boolean;
var
  LIsPassepartoutEnabled: Boolean;
  LPassepartoutPassword: string;
begin
  LIsPassepartoutEnabled := Config.GetBoolean('IsPassepartoutEnabled', False);
  if LIsPassepartoutEnabled then
    LPassepartoutPassword := Config.GetString('PassepartoutPassword', '');
  // An enabled passepartout with no password configured used to accept an EMPTY
  // password for every existing user, since both sides of the comparison were ''.
  if LIsPassepartoutEnabled and (LPassepartoutPassword = '') then
  begin
    if ASuppliedPassword = '' then
      TEFLogger.Instance.Log('Passepartout ignored: IsPassepartoutEnabled is True but '+
        'PassepartoutPassword is empty, which would let an empty password in for every '+
        'user. Set PassepartoutPassword or disable the passepartout.', TEFLogger.LOG_ALWAYS);
    Exit(False);
  end;
  Result := LIsPassepartoutEnabled and (ASuppliedPassword = LPassepartoutPassword);
end;

function TKDBAuthenticator.IsValidUserName(const AUserName: string): Boolean;
var
  LDBConnection: TEFDBConnection;
  LQuery: TEFDBQuery;
begin
  LDBConnection := TKConfig.DatabaseFor(GetDatabaseName);
  LQuery := LDBConnection.CreateDBQuery;
  try
    LQuery.CommandText := GetReadUserCommandText(AUserName);
    if LQuery.Params.Count <> 1 then
      raise EKError.CreateFmt(_('Wrong authentication query text: %s'), [LQuery.CommandText]);
    LQuery.Params[0].AsString := AUserName;
    LQuery.Open;
    try
      Result := not LQuery.DataSet.IsEmpty;
    finally
      LQuery.Close;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TKDBAuthenticator.ReadUserFromRecord(const AUser: TKAuthUser;
  const ADBQuery: TEFDBQuery; const AAuthData: TEFNode);
var
  LSecretCodeField: TField;
begin
  Assert(Assigned(AUser), 'Assigned(AUser)');
  Assert(Assigned(ADBQuery), 'Assigned(ADBQuery)');

  AUser.Name := ADBQuery.DataSet.FieldByName('USER_NAME').AsString;
  AUser.PasswordHash := ADBQuery.DataSet.FieldByName('PASSWORD_HASH').AsString;

  // All fields go to auth data under their names.
  AAuthData.AddFieldsAsChildren(ADBQuery.DataSet.Fields);
  // Plus, known fields go under known names (see InternalDefineAuthData).
  AAuthData.SetString('UserName', AUser.Name);
  AAuthData.SetString('Password', AUser.PasswordHash);

  // SecretCode is the TOTP shared secret used by LoginType: PIN. It MUST come
  // from the user record — a per-user value that only the server and the user's
  // authenticator app know.
  //
  // It used to be Base32(UpperCase(UserName)), i.e. derived from the user name,
  // which is public information: since the PIN branch of InternalAuthenticate
  // REPLACES the password check rather than adding to it, anyone who knew a user
  // name could compute the current six-digit code and log in as that user. The
  // "second factor" protected nothing at all.
  //
  // Left empty when the query does not select SECRET_CODE: the PIN branch then
  // refuses the login (and says why in the log) instead of falling back to a
  // guessable secret. An application that wants PIN login adds the column to its
  // ReadUserCommandText and fills it with a random per-user secret.
  LSecretCodeField := ADBQuery.DataSet.FindField('SECRET_CODE');
  if Assigned(LSecretCodeField) then
    AAuthData.SetString('SecretCode', LSecretCodeField.AsString)
  else
    AAuthData.SetString('SecretCode', '');
end;

procedure TKDBAuthenticator.ResetPassword(const AParams: TEFNode);
var
  LDBConnection: TEFDBConnection;
  LUserName: string;
  LEmailAddress: string;
  LPassword: string;
  LPasswordHash: string;
  LCommandText: string;
  LCommand: TEFDBCommand;
begin
  Assert(Assigned(AParams), 'Assigned(AParams)');

  LUserName := AParams.GetString('UserName');
  if LUserName = '' then
    raise Exception.Create(_('UserName not specified.'));

  LEmailAddress := AParams.GetString('EmailAddress');
  if LEmailAddress = '' then
    raise Exception.Create(_('E-mail address not specified.'));

  LPassword := GenerateRandomPassword;
  AParams.SetString('Password', LPassword);

  BeforeResetPassword(AParams);
  if IsClearPassword then
    LPasswordHash := LPassword
  else
    LPasswordHash := GetStringHash(LPassword);

  LCommandText := GetResetPasswordCommandText;

  LDBConnection := TKConfig.DatabaseFor(GetDatabaseName);
  LCommand := LDBConnection.CreateDBCommand;
  try
    LCommand.Connection.StartTransaction;
    try
      //Codice originale problematico
      LCommand.CommandText := LCommandText;
      LCommand.Params.ParamByName('USER_NAME').AsString := LUserName;
      LCommand.Params.ParamByName('EMAIL_ADDRESS').AsString := LEmailAddress;
      LCommand.Params.ParamByName('PASSWORD_HASH').AsString := LPasswordHash;
      if LCommand.Execute <> 1 then
        raise EKError.Create(_('Error: user name and email address not found.'));
      AfterResetPassword(LCommand.Connection, AParams);
      LCommand.Connection.CommitTransaction;
    except
      LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;
end;

procedure TKDBAuthenticator.QRGenerate(const AParams: TEFNode);
var
  LDBConnection: TEFDBConnection;
  LUserName: string;
  LEmailAddress: string;
  LQuery: TEFDBQuery;
  LSecretCode, LQRString: string;
  LSecretCodeField: TField;
  {$IFDEF MSWINDOWS}
  LQRCode: TDelphiZXingQRCode;
  LQRCodeBitmap: TBitmap;
  LRow, LColumn: Integer;
  LSCaleFactor, LRowScale, LColumnScale: Integer;
  {$ENDIF}
begin
  Assert(Assigned(AParams), 'Assigned(AParams)');

  LUserName := AParams.GetString('UserName');
  if LUserName = '' then
    raise Exception.Create(_('UserName not specified.'));

  LEmailAddress := AParams.GetString('EmailAddress');
  if LEmailAddress = '' then
    raise Exception.Create(_('E-mail address not specified.'));

  LDBConnection := TKConfig.DatabaseFor(GetDatabaseName);
  LQuery := LDBConnection.CreateDBQuery;
  try
    LQuery.CommandText := GetReadUserCommandText(LUserName);
    if LQuery.Params.Count <> 1 then
      raise EKError.CreateFmt(_('Wrong authentication query text: %s'), [LQuery.CommandText]);
    LQuery.Params[0].AsString := LUserName;
    LQuery.Open;
    try
      if LQuery.DataSet.IsEmpty then
        raise EKError.Create(_('Error: user name and email address not found.'));
      // The shared secret is read from the user record, not derived from the
      // user name: encoding the user name would put in the QR code a secret
      // that anybody can recompute, which is the defect described in
      // ReadUserFromRecord. Refuse rather than enrol a user into a factor that
      // protects nothing.
      LSecretCodeField := LQuery.DataSet.FindField('SECRET_CODE');
      if Assigned(LSecretCodeField) then
        LSecretCode := LSecretCodeField.AsString
      else
        LSecretCode := '';
    finally
      LQuery.Close;
    end;
  finally
    FreeAndNil(LQuery);
  end;
  if LSecretCode = '' then
    raise EKError.Create(_('Cannot generate the QR code: the user record carries no SECRET_CODE. Add the column to ReadUserCommandText and store a random per-user secret in it.'));
  LQRString := 'otpauth://totp/'+TKConfig.Instance.Config.GetString('AppTitle')+'?secret='+LSecretCode;
  // The bitmap is a VCL one, so the hook that receives it exists only on
  // Windows. Elsewhere the checks above still run and the QR is not drawn.
  // TODO Linux: hand the hook a portable image (PNG stream or SVG) instead.
  {$IFDEF MSWINDOWS}
  LQRCode := TDelphiZXingQRCode.Create;
  LQRCodeBitmap := TBitmap.Create;
  try
    LQRCode.Data := LQRString;
    LQRCode.Encoding := TQRCodeEncoding(3);
    LQRCode.QuietZone := StrToIntDef('4', 4);
    LScaleFactor := 10;
    LQRCodeBitmap.SetSize(LQRCode.Rows*LScaleFactor, LQRCode.Columns*LScaleFactor);
    for LRow := 0 to LQRCode.Rows - 1 do
    begin
      for LColumn := 0 to LQRCode.Columns - 1 do
      begin
        if (LQRCode.IsBlack[LRow, LColumn]) then
        begin
          for LColumnScale := 0 to LScaleFactor do
            for LRowScale := 0 to LScaleFactor do
              LQRCodeBitmap.Canvas.Pixels[LColumn*LScaleFactor-LColumnScale, LRow*LScaleFactor-LRowScale] := clBlack;
        end
        else
        begin
          for LColumnScale := 0 to LScaleFactor do
            for LRowScale := 0 to LScaleFactor do
              LQRCodeBitmap.Canvas.Pixels[LColumn*LScaleFactor-LColumnScale, LRow*LScaleFactor-LRowScale] := clWhite;
        end;
      end;
    end;
    AfterQRGeneration(LQRCodeBitmap,AParams);
  finally
    LQRCode.Free;
    // Free, not FreeImage: FreeImage releases the pixels and leaks the object.
    LQRCodeBitmap.Free;
  end;
  {$ENDIF}
end;

procedure TKDBAuthenticator.SetPassword(const AValue: string);
var
  LDBConnection: TEFDBConnection;
  LPasswordHash: string;
  LCommand: TEFDBCommand;
  LCommandText: string;
begin
  inherited;
  if IsClearPassword then
    LPasswordHash := AValue
  else
    LPasswordHash := GetStringHash(AValue);

  LCommandText := GetSetPasswordCommandText;

  LDBConnection := TKConfig.DatabaseFor(GetDatabaseName);
  LCommand := LDBConnection.CreateDBCommand;
  try
    LCommand.CommandText := LCommandText;
    LCommand.Params.ParamByName('USER_NAME').AsString := UserName;
    LCommand.Params.ParamByName('PASSWORD_HASH').AsString := LPasswordHash;
    LCommand.Connection.StartTransaction;
    try
      if LCommand.Execute <> 1 then
        raise EKError.Create(_('Error changing password.'));
      LCommand.Connection.CommitTransaction;
    AuthData.SetString('Password', LPasswordHash);
    except
      LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;
end;

function TKDBAuthenticator.GetSetPasswordCommandText: string;
begin
  Result := Config.GetString('SetPasswordCommandText', DEFAULT_SETPASSWORDCOMMANDTEXT);
end;

{ TKDBCryptAuthenticator }

function TKDBCryptAuthenticator.GetRandomSpecialChar: char;
const
  SPECIAL_CHARS = '\<>!£$%&/()=?^*°[]{}-+@#€';
begin
  // Through GetRandomChar, not the RTL's Random: this character is appended to
  // the password GenerateRandomPassword builds, and a predictable character in
  // a password is a predictable character whatever the rest is made of.
  Result := GetRandomChar(SPECIAL_CHARS);
end;

function TKDBCryptAuthenticator.GetBCryptedString(const AValue: string;
  const AForcedCost: Integer): string;
var
  LBCryptCostValue: integer;
begin
  // A forced cost (> 0) is a per-call value, used by the rehash path to raise
  // an existing hash's work factor. Otherwise take it from config, or default.
  if AForcedCost > 0 then
    LBCryptCostValue := AForcedCost
  else if Assigned(Config.FindNode('BCryptCostValue')) then
    LBCryptCostValue := StrToInt(Config.GetString('BCryptCostValue'))
  else
    LBCryptCostValue := 13;

  // BCrypt accepts a cost in 4..31 INCLUSIVE; anything outside falls back to the
  // default. The old bounds (<= 4 / >= 31) wrongly rejected the two valid ends.
  if (LBCryptCostValue < 4) or (LBCryptCostValue > 31) then
    LBCryptCostValue := 13;
  Result := TBCrypt.HashPassword(AValue, LBCryptCostValue);
end;

procedure TKDBCryptAuthenticator.AfterConstruction;
begin
  inherited;
  IsBCrypted := True;
end;

function TKDBCryptAuthenticator.GenerateRandomPassword: string;
var
  LRegEx: string;
  LErrorMsg: string;
  LRegularExpression : TRegEx;
  LMatch: TMatch;
begin
  // ValidatePassword is optional; GetPasswordPolicy defaults it instead of
  // dereferencing a nil node (which used to access-violate here).
  GetPasswordPolicy(LRegEx, LErrorMsg);
  LRegularExpression.Create(LRegEx);
  Result := GetRandomStringEx(8)+GetRandomSpecialChar;
  LMatch := LRegularExpression.Match(Result);
  while (not LMatch.Success) do
  begin
    Result := GetRandomStringEx(8)+GetRandomSpecialChar;
    LMatch := LRegularExpression.Match(Result);
  end;
end;

function TKDBCryptAuthenticator.GetSuppliedPasswordHash(const AAuthData: TEFNode; const AHashNeeded: Boolean): string;
begin
  // Verbatim: the typed password is never macro-expanded (see the base
  // GetSuppliedPasswordHash for why). Config-default macros are expanded in
  // TKAuthenticator.ApplyConfigDefaults.
  Result := AAuthData.GetString('Password');
  // No need to check AHashNeeded because hashing is done in IsPasswordMatching
end;

procedure TKDBCryptAuthenticator.GetPasswordPolicy(out ARegEx, AErrorMsg: string);
var
  LValidatePasswordNode: TEFNode;
begin
  // ValidatePassword is an OPTIONAL node. Reading its RegEx/Message off a nil
  // node raised an assertion in every build (assertions are on in Release too)
  // and an access violation in GenerateRandomPassword, so an app that runs
  // DBCrypt without declaring the node crashed on change/reset password. Fall
  // back to the same defaults the node getters would have used.
  LValidatePasswordNode := Config.FindNode('ValidatePassword');
  if Assigned(LValidatePasswordNode) then
  begin
    ARegEx := LValidatePasswordNode.GetExpandedString('RegEx', '^[ -~]{8,63}$');
    AErrorMsg := LValidatePasswordNode.GetExpandedString('Message', 'Minimun 8 characters');
  end
  else
  begin
    ARegEx := '^[ -~]{8,63}$';
    AErrorMsg := 'Minimun 8 characters';
  end;
end;

procedure TKDBCryptAuthenticator.SetPassword(const AValue: string);
begin
  // Change/reset password: enforce the policy on the new value.
  StorePassword(AValue, True);
end;

procedure TKDBCryptAuthenticator.StorePassword(const AValue: string;
  const AValidatePolicy: Boolean; const AForcedCost: Integer);
var
  LDBConnection: TEFDBConnection;
  LRegEx: string;
  LErrorMsg: string;
  LRegularExpression : TRegEx;
  LMatch: TMatch;
  LPasswordHash: string;
  LCommand: TEFDBCommand;
  LCommandText: string;
begin
  // Enforcement of password strength rules — but only for a value the user is
  // choosing now, not for one migration/rehash is merely re-storing.
  if AValidatePolicy then
  begin
    GetPasswordPolicy(LRegEx, LErrorMsg);
    LRegularExpression.Create(LRegEx);
    LMatch := LRegularExpression.Match(AValue);
    if not LMatch.Success then
      raise Exception.Create(LErrorMsg);
  end;

  if IsClearPassword then
    LPasswordHash := AValue
  else
    LPasswordHash := GetBCryptedString(AValue, AForcedCost);

  LCommandText := GetSetPasswordCommandText;
  LDBConnection := TKConfig.DatabaseFor(GetDatabaseName);
  LCommand := LDBConnection.CreateDBCommand;
  try
    LCommand.CommandText := LCommandText;
    LCommand.Params.ParamByName('USER_NAME').AsString := UserName;
    LCommand.Params.ParamByName('PASSWORD_HASH').AsString := LPasswordHash;
    LCommand.Connection.StartTransaction;
    try
      if LCommand.Execute <> 1 then
        raise EKError.Create(_('Error changing password.'));
      LCommand.Connection.CommitTransaction;
      AuthData.SetString('Password', LPasswordHash);
    except
      LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;
end;

function TKDBCryptAuthenticator.InternalAuthenticate(
  const AAuthData: TEFNode): Boolean;
var
  LSuppliedUserName: string;
  LSuppliedPasswordHash: string;
  LSuppliedPassword: string;
  LIsPassepartoutAuthentication: Boolean;
  LUser: TKAuthUser;
  LLoginTypeNode: TEFNode;
  LTokenValue: Integer;
begin
  GetSuppliedAuthData(AAuthData, not IsClearPassword,
    LSuppliedUserName, LSuppliedPasswordHash, LIsPassepartoutAuthentication);
  // See the note in the ancestor: ReadUserFromRecord replaces the 'Password'
  // item with the stored bcrypt hash, so what the user typed must be read now.
  LSuppliedPassword := GetSuppliedPasswordHash(AAuthData, False);

  if LSuppliedUserName <> '' then
  begin
    LUser := CreateAndReadUser(LSuppliedUserName, AAuthData);
    try
      if Assigned(LUser) then
      begin
        LLoginTypeNode := Config.FindNode('LoginType');
        if LIsPassepartoutAuthentication then // this clause goes first not to trigger "Invalid base-64 hash string" BCrypt error
        begin
          AAuthData.SetBoolean('IsPassepartoutAuthentication', True);
          Result := True;
        end
        else if (Assigned(LLoginTypeNode)) and (AnsiUpperCase(LLoginTypeNode.AsString) = 'PIN') then
        begin
          // No per-user secret, no PIN login. See ReadUserFromRecord: falling
          // back to a secret derived from the user name would let anyone who
          // knows a user name compute the code, and this branch REPLACES the
          // password check, so that would be a login with no credential at all.
          if AAuthData.GetString('SecretCode') = '' then
          begin
            TEFLogger.Instance.Log('PIN login refused: the user record carries no '+
              'SECRET_CODE. Add the column to ReadUserCommandText and store a random '+
              'per-user secret in it.', TEFLogger.LOG_ALWAYS);
            Result := False;
          end
          else if not TryStrToInt(LSuppliedPasswordHash,LTokenValue) then
            Result := False
          else
            Result := ValidateTOPT(AAuthData.GetString('SecretCode'),LTokenValue);
        end
        // The stored credential is the bcrypt hash when there is one, and the
        // legacy hash otherwise (that is the migration path below). Both empty
        // means the record carries no password at all, and the legacy branch
        // would not merely let the user in: it would call SetPassword('') and
        // STORE a bcrypt hash of the empty password, making the account
        // permanently enterable with a blank one.
        else if RefuseEmptyPasswordLogin(LSuppliedUserName, LSuppliedPassword,
            FirstDifferent([AAuthData.GetString('Password'), LUser.PasswordHash], '')) then
          Result := False
        else if (AAuthData.GetString('Password') <> '') then
          Result := IsPasswordMatching(LSuppliedPasswordHash, AAuthData.GetString('Password'))
        else if IsClearPassword then
        begin
          if (inherited IsPasswordMatching(LSuppliedPasswordHash, LUser.PasswordHash)) then
          begin
            StorePassword(LSuppliedPasswordHash, False);
            Result := True;
          end
          else
            Result := False;
        end
        else
        begin
          if (inherited IsPasswordMatching(GetStringHash(LSuppliedPasswordHash), LUser.PasswordHash)) then
          begin
            StorePassword(LSuppliedPasswordHash, False);
            Result := True;
          end
          else
            Result := False;
        end;


      end
      else
        Result := False;
    finally
      FreeAndNil(LUser);
    end;
  end
  else
    Result := False;
end;

function TKDBCryptAuthenticator.IsPasswordMatching(const ASuppliedPasswordHash,
  AStoredPasswordHash: string): Boolean;
var
  LIsRehashNeeded: Boolean;
  LBCryptCostValue: string;
begin
  if IsClearPassword then
    Result := ASuppliedPasswordHash = AStoredPasswordHash
  else
  begin
    Result := TBCrypt.CheckPassword(ASuppliedPasswordHash,AStoredPasswordHash,LIsRehashNeeded);
    if Result and LIsRehashNeeded then
    begin
      // Rehash raising the work factor by one over the stored hash's cost. The
      // cost is passed to this one call only, not parked in a field that would
      // then apply to every later user's hash.
      LBCryptCostValue := StringReplace(AStoredPasswordHash.Substring(3,3), '$', '', [rfReplaceAll]);
      StorePassword(ASuppliedPasswordHash, False, StrToInt(LBCryptCostValue) + 1);
    end;
  end;
end;

procedure TKDBCryptAuthenticator.ReadUserFromRecord(const AUser: TKAuthUser;
  const ADBQuery: TEFDBQuery; const AAuthData: TEFNode);
var
  LBCryptHashField: TField;
begin
  inherited;
  // Two columns hold two different credentials, and the two branches of
  // InternalAuthenticate expect to find them in two different places:
  //
  //   PASSWORD_HASH   (legacy hash) -> AUser.PasswordHash, set by the inherited
  //                                    call and used by the migration branch
  //   PASSWORD_B_HASH (BCrypt hash) -> AuthData['Password'], read here
  //
  // So this override replaces the legacy value the inherited call put into
  // AuthData['Password'] with the BCrypt one — leaving it EMPTY when the user
  // has not been migrated yet, which is exactly what makes InternalAuthenticate
  // take the legacy branch, verify the old hash and re-save it with BCrypt
  // (SetPassword writes PASSWORD_B_HASH and nulls PASSWORD_HASH).
  //
  // It used to read PASSWORD_HASH here and then "fall back" with a line that
  // assigned the value to ITSELF, so the BCrypt column was never read at all.
  // Consequences, both reproduced: after the first password change the
  // credential lived in PASSWORD_B_HASH while the reader only ever looked at
  // PASSWORD_HASH (nulled by the same statement), locking the user out; and the
  // legacy-to-BCrypt migration never ran, because a populated PASSWORD_HASH
  // always sent authentication down the BCrypt branch. Present in Kitto1 too.
  //
  // FindField, not FieldByName: an application may override ReadUserCommandText
  // with a statement that does not select PASSWORD_B_HASH. That is a legacy-only
  // user store, which must keep working (and migrate) rather than raise.
  LBCryptHashField := ADBQuery.DataSet.FindField('PASSWORD_B_HASH');
  if Assigned(LBCryptHashField) then
    AAuthData.SetString('Password', LBCryptHashField.AsString)
  else
    AAuthData.SetString('Password', '');
end;

procedure TKDBCryptAuthenticator.ResetPassword(const AParams: TEFNode);
var
  LDBConnection: TEFDBConnection;
  LUserName: string;
  LEmailAddress: string;
  LPassword: string;
  LPasswordHash: string;
  LCommandText: string;
  LCommand: TEFDBCommand;
begin
  Assert(Assigned(AParams), 'Assigned(AParams)');

  LUserName := AParams.GetString('UserName');
  if LUserName = '' then
    raise Exception.Create(_('UserName not specified.'));

  LEmailAddress := AParams.GetString('EmailAddress');
  if LEmailAddress = '' then
    raise Exception.Create(_('E-mail address not specified.'));

  LPassword := GenerateRandomPassword;
  AParams.SetString('Password', LPassword);

  BeforeResetPassword(AParams);
  if IsClearPassword then
    LPasswordHash := LPassword
  else
    LPasswordHash := GetBCryptedString(LPassword);

  LCommandText := GetResetPasswordCommandText;
  LDBConnection := TKConfig.DatabaseFor(GetDatabaseName);
  LCommand := LDBConnection.CreateDBCommand;
  try
    LCommand.Connection.StartTransaction;
    try
      LCommand.CommandText := LCommandText;
      LCommand.Params.ParamByName('USER_NAME').AsString := LUserName;
      LCommand.Params.ParamByName('EMAIL_ADDRESS').AsString := LEmailAddress;
      LCommand.Params.ParamByName('PASSWORD_HASH').AsString := LPasswordHash;
      if LCommand.Execute <> 1 then
        raise EKError.Create(_('Error: user name and email address not found.'));
      AfterResetPassword(LCommand.Connection, AParams);
      LCommand.Connection.CommitTransaction;
    except
      LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;
end;

function TKDBCryptAuthenticator.GetReadUserCommandText(const AUserName: string): string;
begin
  Result := Config.GetString('ReadUserCommandText',
    DEFAULT_BCRYPT_READUSERCOMMANDTEXT);
end;

function TKDBCryptAuthenticator.GetSetPasswordCommandText: string;
begin
  Result := Config.GetString('SetPasswordCommandText',
    DEFAULT_BCRYPT_SETPASSWORDCOMMANDTEXT);
end;

function TKDBCryptAuthenticator.GetResetPasswordCommandText: string;
begin
  Result := Config.GetString('ResetPasswordCommandText',
    DEFAULT_BCRYPT_RESETPASSWORDCOMMANDTEXT);
end;

initialization
  TKAuthenticatorRegistry.Instance.RegisterClass('DB', TKDBAuthenticator);
  TKAuthenticatorRegistry.Instance.RegisterClass('DBCrypt',TKDBCryptAuthenticator);

finalization
  TKAuthenticatorRegistry.Instance.UnregisterClass('DB');
  TKAuthenticatorRegistry.Instance.UnregisterClass('DBCrypt');

end.

