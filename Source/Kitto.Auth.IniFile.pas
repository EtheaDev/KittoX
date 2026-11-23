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
///	  <para>Defines the INI-file authenticator.</para>
///	  <para>This authenticator uses an external INI file, one section per
///	  user, to authenticate users: the same job as the TextFile authenticator
///	  with a file that is easier to write by hand.</para>
///	</summary>
unit Kitto.Auth.IniFile;

{$I Kitto.Defines.inc}

interface

uses
  System.Classes,
  EF.Tree,
  Kitto.Auth.TextFile;

const
  DEFAULT_INI_USERLIST_FILENAME = '%HOME_PATH%FileAuthenticator.ini';
  ///	<summary>The key of a user's section that holds the password (or its
  ///	hash). Every other key is an attribute of the user.</summary>
  INI_PASSWORD_KEY = 'Password';
  ///	<summary>A user whose section has this key set to True is treated as
  ///	not listed: the INI equivalent of the leading # of the TextFile
  ///	format.</summary>
  INI_DISABLED_KEY = 'Disabled';

type
  ///	<summary>
  ///	  <para>The Ini authenticator (Auth: Ini) uses an external INI file to
  ///	  authenticate users. The file has a section for each user, named after
  ///	  the user, with the password under the Password key and any other
  ///	  attribute of the user under a key of its own:</para>
  ///	  <para><c>[admin]</c></para>
  ///	  <para><c>Password=12345</c></para>
  ///	  <para><c>PROFILEID=ADMIN</c></para>
  ///	  <para><c>DisplayName=Administrator</c></para>
  ///	  <para>It is the TextFile authenticator with another file format: the
  ///	  same parameters (FileName, IsClearPassword, the passepartout), the same
  ///	  rules (no login with an empty password on either side, user name
  ///	  matched case-insensitively, the file re-read at every login so an edit
  ///	  needs no restart), the same way of handing the user's attributes to the
  ///	  session's AuthData (where the %Auth:Name% macros read them). What the
  ///	  INI format buys: the password is a key like the others, so it may
  ///	  contain ';' and nothing has to be kept in order on a line, and a user
  ///	  is disabled with Disabled=True in its section (commenting out every
  ///	  line of the section removes the user as well; commenting out the
  ///	  header line alone does not: the keys left below it belong to the
  ///	  previous section).</para>
  ///	  <para>UserName and Password are never applied as attributes. The
  ///	  default file is %HOME_PATH%FileAuthenticator.ini (FileName overrides
  ///	  it, macros allowed); with IsClearPassword False, the default, Password
  ///	  holds the MD5 hash.</para>
  ///	</summary>
  TKIniFileAuthenticator = class(TKTextFileAuthenticator)
  protected
    function GetUserListFileName: string; override;
    ///	<summary>Looks the user's section up: Password is the stored hash,
    ///	every other key an attribute. A missing or Disabled=True section is
    ///	"not listed".</summary>
    function FindUser(const AUserName: string; out APasswordHash: string;
      const AAttributes: TStrings): Boolean; override;
  public
    /// <summary>Raises: the INI file is edited by hand, not rewritten by the
    /// application, so there is nowhere to store a new password.</summary>
    procedure ResetPassword(const AParams: TEFNode); override;
    /// <summary>Raises: the file format carries no per-user TOTP secret.</summary>
    procedure QRGenerate(const AParams: TEFNode); override;
  end;

implementation

uses
  System.SysUtils,
  System.IniFiles,
  EF.Localization,
  EF.Logger,
  EF.Types,
  Kitto.Auth,
  Kitto.Types;

{ TKIniFileAuthenticator }

function TKIniFileAuthenticator.GetUserListFileName: string;
begin
  Result := Config.GetExpandedString('FileName', DEFAULT_INI_USERLIST_FILENAME);
end;

function TKIniFileAuthenticator.FindUser(const AUserName: string;
  out APasswordHash: string; const AAttributes: TStrings): Boolean;
var
  LFileName: string;
  LIni: TMemIniFile;
  LKeys: TStringList;
  I: Integer;
  LKey: string;
begin
  APasswordHash := '';
  LFileName := GetUserListFileName;
  if not FileExists(LFileName) then
    raise EEFError.CreateFmt(_('File %s not found.'), [LFileName]);

  // A local instance, read anew at every call, for the same reasons as the
  // TextFile list: an edit takes effect at the next login, and two concurrent
  // logins share nothing. UTF-8, so a display name may carry accents.
  LIni := TMemIniFile.Create(LFileName, TEncoding.UTF8);
  try
    Result := LIni.SectionExists(AUserName);
    if not Result then
      Exit;
    // ReadBool wants a number: read the text, so True/False work too.
    if StrToBoolDef(Trim(LIni.ReadString(AUserName, INI_DISABLED_KEY, '')), False) then
    begin
      TEFLogger.Instance.LogFmt('User %s is disabled in the user list file %s (%s=True).',
        [AUserName, LFileName, INI_DISABLED_KEY], TEFLogger.LOG_DETAILED);
      Exit(False);
    end;
    APasswordHash := Trim(LIni.ReadString(AUserName, INI_PASSWORD_KEY, ''));
    if Assigned(AAttributes) then
    begin
      LKeys := TStringList.Create;
      try
        LIni.ReadSectionValues(AUserName, LKeys);
        for I := 0 to LKeys.Count - 1 do
        begin
          LKey := Trim(LKeys.Names[I]);
          if (LKey = '') or SameText(LKey, INI_PASSWORD_KEY) or SameText(LKey, INI_DISABLED_KEY) then
            Continue;
          AAttributes.Add(LKey + '=' + Trim(LKeys.ValueFromIndex[I]));
        end;
      finally
        LKeys.Free;
      end;
    end;
  finally
    LIni.Free;
  end;
end;

procedure TKIniFileAuthenticator.ResetPassword(const AParams: TEFNode);
begin
  raise EKError.Create(_('Password reset is not supported by the Ini authenticator: edit the user list file instead.'));
end;

procedure TKIniFileAuthenticator.QRGenerate(const AParams: TEFNode);
begin
  raise EKError.Create(_('PIN/QR authentication is not supported by the Ini authenticator.'));
end;

initialization
  TKAuthenticatorRegistry.Instance.RegisterClass('Ini', TKIniFileAuthenticator);

finalization
  TKAuthenticatorRegistry.Instance.UnregisterClass('Ini');

end.
