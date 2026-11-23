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

///	<summary>
///	  <para>Defines the file-based authenticator and related classes and
///	  services.</para>
///	  <para>This authenticator uses an external file containing user names and
///	  password hashes to authenticate users.</para>
///	</summary>
unit Kitto.Auth.TextFile;

{$I Kitto.Defines.inc}

interface

uses
  System.Classes,
  EF.Tree,
  Kitto.Auth;

const
  DEFAULT_USERLIST_FILENAME = '%HOME_PATH%FileAuthenticator.txt';
  ///	<summary>Separates the password from the user's attributes, and the
  ///	attributes from each other, on a line of the user list.</summary>
  USER_ATTRIBUTE_SEPARATOR = ';';

type
  ///	<summary>
  ///	  <para>The TextFile authenticator uses an external text file to
  ///	  authenticate users. The file should have a line for each user, in the
  ///	  format:</para>
  ///	  <para><c>&lt;user name&gt;=&lt;password hash&gt;[;&lt;Name&gt;=&lt;Value&gt;...]</c></para>
  ///	  <para>By convention, a # character at the beginning of a line disables
  ///	  a user. All lines beginning with # are ignored by the
  ///	  authenticator.</para>
  ///	  <para>What follows the password, separated by ';', is a list of
  ///	  Name=Value attributes of the user (a profile, a display name, an
  ///	  e-mail address...). After a successful login they are copied into the
  ///	  session's AuthData, where the %Auth:Name% macros read them, exactly
  ///	  like the extra columns of TKDBAuthenticator's ReadUserCommandText:
  ///	  <c>admin=12345;PROFILEID=ADMIN;DisplayName=Administrator</c>. A clear
  ///	  password (IsClearPassword) cannot therefore contain ';'.</para>
  ///	  <para>The authenticator needs the same auth items as its ancestor
  ///	  TKClassicAuthenticator.</para>
  ///	  <para>In order for this authenticator to work, it is required that the
  ///	  following file exists:</para>
  ///	  <para><c>%HOME_PATH%FileAuthenticator.txt</c></para>
  ///	  <para>You can override the file name by means of the FileName parameter
  ///	  (may contain macros).</para>
  ///	  <para>When Authenticate is called, the authenticator fetches the file
  ///	  data (which is not cached, meaning it is read anew at every
  ///	  authentication request) and check the supplied credentials against the
  ///	  user name and relevant password MD5 hash.</para>
  ///	  <para>Parameters:</para>
  ///	  <list type="table">
  ///	    <listheader>
  ///	      <term>Term</term>
  ///	      <description>Description</description>
  ///	    </listheader>
  ///	    <item>
  ///	      <term>IsClearPassword</term>
  ///	      <description>Set this item to true to signify that the password is
  ///	      stored in clear, and not hashed, in the external file. Default
  ///	      False.</description>
  ///	    </item>
  ///	    <item>
  ///	      <term>FileName</term>
  ///	      <description>Overrides the predefined user list file name. May
  ///	      contain macros.</description>
  ///	    </item>
  ///	  </list>
  ///	</summary>
  TKTextFileAuthenticator = class(TKClassicAuthenticator)
  protected
    function InternalAuthenticate(const AAuthData: TEFNode): Boolean; override;
    /// <summary>Copies the attributes of the user's line (what follows the
    /// password) into AAuthData.</summary>
    procedure InternalAfterAuthenticate(const AAuthData: TEFNode); override;
  protected
    ///	<summary>Re-reads the contents of the user list from the external file
    ///	and loads them into the supplied string list object.</summary>
    procedure RefreshUserList(const AUserList: TStrings); virtual;

    ///	<summary>Returns the name of the external file (full path, may contain
    ///	macros).</summary>
    function GetUserListFileName: string; virtual;

    ///	<summary>Splits the value part of a user line (everything after the
    ///	first '=') into the password hash and the Name=Value attributes that
    ///	may follow it, separated by ';'. AAttributes may be nil when only the
    ///	password is wanted.</summary>
    class procedure ParseUserLine(const ALineValue: string; out APasswordHash: string;
      const AAttributes: TStrings); static;

    ///	<summary>Looks AUserName up in the user list, re-reading the file: False
    ///	if the user is not listed (or is disabled); otherwise sets the stored
    ///	password hash (empty when the user carries none, which is a broken list
    ///	that only the passepartout can enter) and, when AAttributes is given,
    ///	adds the user's Name=Value attributes to it. It is the one place that
    ///	knows the file format: here the user's line, in TKIniFileAuthenticator
    ///	the user's section. Everything else (hashing, the empty-password rule,
    ///	the passepartout, AuthData) is shared.</summary>
    function FindUser(const AUserName: string; out APasswordHash: string;
      const AAttributes: TStrings): Boolean; virtual;

    ///	<summary>Reads the user list and sets every attribute of AUserName's
    ///	line as a string node of AAuthData. Returns False if the user is not
    ///	in the file.</summary>
    function ApplyUserAttributes(const AUserName: string; const AAuthData: TEFNode): Boolean;
  public
    /// <summary>Reloads the user's attributes from the file (the profile, for
    /// one) into a session that has lost its AuthData; False if the user is no
    /// longer listed.</summary>
    function RehydrateAuthData(const AUserName: string;
      const AAuthData: TEFNode): Boolean; override;
    /// <summary>
    ///  The user list is a read-only text file of name=hash pairs: there is no
    ///  write path, so a password cannot be changed or reset from here. The
    ///  three members below are implemented rather than left abstract because
    ///  abstract members of a factory-created class do not fail at build time:
    ///  they raise "Abstract Error" the first time a user reaches the feature.
    /// </summary>
    function SupportsPasswordChange: Boolean; override;
    /// <summary>Raises: the user list file is edited by hand, not rewritten by
    /// the application, so there is nowhere to store a new password.</summary>
    procedure ResetPassword(const AParams: TEFNode); override;
    /// <summary>Raises: the file format carries no per-user TOTP secret.</summary>
    procedure QRGenerate(const AParams: TEFNode); override;
    /// <summary>Always False, and never reached: InternalAuthenticate compares
    /// against the user list inline, and the password-change flow is refused by
    /// SupportsPasswordChange before it gets here.</summary>
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; override;
  end;

implementation

uses
  System.SysUtils,
  EF.Intf,
  EF.Localization,
  EF.Logger,
  EF.Types,
  EF.StrUtils,
  Kitto.Config,
  Kitto.Types;

{ TKTextFileAuthenticator }

function TKTextFileAuthenticator.GetUserListFileName: string;
begin
  Result := Config.GetExpandedString('FileName', DEFAULT_USERLIST_FILENAME);
end;

function  TKTextFileAuthenticator.InternalAuthenticate(
  const AAuthData: TEFNode): Boolean;
var
  LIsPassepartoutEnabled: Boolean;
  LIsClearPassword: Boolean;
  LPassepartoutPassword: string;
  LSuppliedPasswordHash: string;
  LSuppliedPassword: string;
  LStoredPasswordHash: string;
  LUserName: string;
begin
  // The typed credentials are compared verbatim and never macro-expanded: see
  // TKDBAuthenticator.GetSuppliedPasswordHash. Config-default macros are
  // expanded in TKAuthenticator.ApplyConfigDefaults.
  LSuppliedPasswordHash := AAuthData.GetString('Password');

  LIsClearPassword := Config.GetBoolean('IsClearPassword', False);
  LIsPassepartoutEnabled := Config.GetBoolean('IsPassepartoutEnabled', False);
  LPassepartoutPassword := Config.GetString('PassepartoutPassword');
  LSuppliedPassword := LSuppliedPasswordHash;
  if not LIsClearPassword then
    LSuppliedPasswordHash := GetStringHash(LSuppliedPasswordHash);

  LUserName := AAuthData.GetString('UserName');

  if LUserName = '' then
    Exit(False);

  // An empty password is refused before anything is compared. GetStringHash('')
  // returns '' by design, so an empty password produces an empty "hash" in both
  // modes and every comparison below would be a comparison of two empty strings.
  // Same reason why TKLDAPAuthenticator refuses it before the bind.
  if LSuppliedPassword = '' then
  begin
    TEFLogger.Instance.LogFmt('Authentication refused for user %s: empty password.',
      [LUserName], TEFLogger.LOG_DETAILED);
    Exit(False);
  end;

  // "Not listed" and "listed without a password" must be told apart: the first
  // is an unknown user, the second is a listed user who cannot be authenticated
  // BY PASSWORD - but who the passepartout may still legitimately impersonate,
  // exactly as TKDBAuthenticator does for a user row whose password column is
  // empty. FindUser answers both. Only the password takes part in the
  // comparison: the user's attributes are applied by InternalAfterAuthenticate.
  if not FindUser(LUserName, LStoredPasswordHash, nil) then
  begin
    TEFLogger.Instance.LogFmt('Authentication refused: user %s is not in the user list file.',
      [LUserName], TEFLogger.LOG_DETAILED);
    Exit(False);
  end;
  if LStoredPasswordHash = '' then
    // The user IS in the file, with no password. That is a broken user list:
    // say so out loud. No Exit: only the password comparison is off the table.
    TEFLogger.Instance.LogFmt('User %s has no password in the user list file %s: '+
      'no password can authenticate it.',
      [LUserName, GetUserListFileName], TEFLogger.LOG_ALWAYS);

  // An empty stored hash never takes part in the comparison: it used to match an empty
  // supplied password, which let anybody in by typing any user name - one absent from
  // the file, or one disabled with a leading # - and leaving the password box empty.
  Result := (LStoredPasswordHash <> '') and (LSuppliedPasswordHash = LStoredPasswordHash);

  // The passepartout is a master password: it is meant to let an operator in as anybody,
  // so - like TKDBAuthenticator.IsPassepartoutAuthentication - it applies to any LISTED
  // user, including one whose line carries no password. It is compared with the password
  // as typed, never with its hash, and it is ignored when left empty, because an empty
  // PassepartoutPassword with IsPassepartoutEnabled: True would accept an empty password
  // for every user in the file.
  if not Result and LIsPassepartoutEnabled and (LPassepartoutPassword <> '') then
    Result := LSuppliedPassword = LPassepartoutPassword;
end;

class procedure TKTextFileAuthenticator.ParseUserLine(const ALineValue: string;
  out APasswordHash: string; const AAttributes: TStrings);
var
  LParts: TArray<string>;
  I: Integer;
begin
  LParts := ALineValue.Split([USER_ATTRIBUTE_SEPARATOR]);
  if Length(LParts) = 0 then
    APasswordHash := ''
  else
    APasswordHash := Trim(LParts[0]);
  if Assigned(AAttributes) then
    for I := 1 to High(LParts) do
      if Trim(LParts[I]) <> '' then
        AAttributes.Add(Trim(LParts[I]));
end;

function TKTextFileAuthenticator.FindUser(const AUserName: string;
  out APasswordHash: string; const AAttributes: TStrings): Boolean;
var
  LUserList: TStringList;
begin
  APasswordHash := '';
  // A LOCAL list, not a shared field: RefreshUserList calls LoadFromFile, which
  // clears and repopulates. A single shared instance mutated here meant that two
  // concurrent logins raced — one clearing the list while the other read
  // IndexOfName/Values — for an index error, an access violation, or a spurious
  // refusal. The file is re-read every login anyway, so a per-call list costs
  // nothing over the shared one.
  LUserList := TStringList.Create;
  try
    RefreshUserList(LUserList);
    // TStrings.Values returns '' both for a name that is not in the file and
    // for a line carrying no value ('user='): IndexOfName tells them apart.
    Result := LUserList.IndexOfName(AUserName) >= 0;
    if Result then
      ParseUserLine(LUserList.Values[AUserName], APasswordHash, AAttributes);
  finally
    LUserList.Free;
  end;
end;

function TKTextFileAuthenticator.ApplyUserAttributes(const AUserName: string;
  const AAuthData: TEFNode): Boolean;
var
  LAttributes: TStringList;
  LPasswordHash: string;
  I: Integer;
  LName: string;
begin
  Assert(Assigned(AAuthData), 'Assigned(AAuthData)');

  LAttributes := TStringList.Create;
  try
    Result := FindUser(AUserName, LPasswordHash, LAttributes);
    if not Result then
      Exit;
    for I := 0 to LAttributes.Count - 1 do
    begin
      LName := Trim(LAttributes.Names[I]);
      // The credentials typed by the user are not for the file to override.
      if (LName = '') or SameText(LName, 'UserName') or SameText(LName, 'Password') then
        Continue;
      AAuthData.SetString(LName, Trim(LAttributes.ValueFromIndex[I]));
    end;
  finally
    LAttributes.Free;
  end;
end;

procedure TKTextFileAuthenticator.InternalAfterAuthenticate(const AAuthData: TEFNode);
begin
  inherited;
  ApplyUserAttributes(AAuthData.GetString('UserName'), AAuthData);
end;

function TKTextFileAuthenticator.RehydrateAuthData(const AUserName: string;
  const AAuthData: TEFNode): Boolean;
begin
  Result := ApplyUserAttributes(AUserName, AAuthData);
end;

procedure TKTextFileAuthenticator.RefreshUserList(const AUserList: TStrings);
var
  LFileName: string;
  LLineIndex: Integer;
begin
  LFileName := GetUserListFileName;

  if not FileExists(LFileName) then
    raise EEFError.CreateFmt(_('File %s not found.'), [LFileName]);

  AUserList.LoadFromFile(LFileName);

  // Remove comments.
  for LLineIndex := AUserList.Count - 1 downto 0 do
    if Pos('#', Trim(AUserList[LLineIndex])) = 1 then
      AUserList.Delete(LLineIndex);
end;


function TKTextFileAuthenticator.SupportsPasswordChange: Boolean;
begin
  // The user list is read-only: nothing here can write a new password.
  Result := False;
end;

procedure TKTextFileAuthenticator.ResetPassword(const AParams: TEFNode);
begin
  raise EKError.Create(_('Password reset is not supported by the TextFile authenticator: edit the user list file instead.'));
end;

procedure TKTextFileAuthenticator.QRGenerate(const AParams: TEFNode);
begin
  raise EKError.Create(_('PIN/QR authentication is not supported by the TextFile authenticator.'));
end;

function TKTextFileAuthenticator.IsPasswordMatching(const ASuppliedPasswordHash,
  AStoredPasswordHash: string): Boolean;
begin
  // Never reached: InternalAuthenticate compares the hashes inline against the
  // user list, and the password-change flow is refused by
  // SupportsPasswordChange before it gets here.
  Result := False;
end;

initialization
  TKAuthenticatorRegistry.Instance.RegisterClass('TextFile', TKTextFileAuthenticator);

finalization
  TKAuthenticatorRegistry.Instance.UnregisterClass('TextFile');

end.

