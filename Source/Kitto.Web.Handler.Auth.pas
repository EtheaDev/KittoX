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
///   Self-contained attribute-based handler for the authentication family
///   (Sprint E.1.d of the routing refactor): login, reset-password,
///   change-password and logout. Replaces the delegating handler that used to
///   live in Kitto.Html.Login and call TKWebApplication.HandleKX*Request.
///
///   The endpoints are [TKXAnonymous] (reachable without prior authentication)
///   and the orchestration is split into virtual hooks so an application can
///   override individual steps by deriving from TKXAuthHandlerBase — e.g. to
///   accept an identity minted by a host web app instead of the built-in login.
///
///   The login PAGE (GET '/') is still served by TKWebApplication.Home; this
///   unit only handles the POST/action endpoints under /kx.
/// </summary>
unit Kitto.Web.Handler.Auth;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  Kitto.Web.Routing.Attributes;

type
  {$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}
  /// <summary>
  ///   Default auth handler. Register in the resource registry; applications
  ///   override behaviour by subclassing and overriding a hook (or a whole
  ///   endpoint method).
  /// </summary>
  [TKXPath('/kx')]
  TKXAuthHandlerBase = class
  protected
    /// <summary>Populates the auth data node from the POST form (UserName /
    /// Password). Override to source credentials elsewhere.</summary>
    procedure BuildAuthData(const AAuthData: TEFNode); virtual;
    /// <summary>Runs after a successful Authenticate: persists the chosen
    /// database cookie, declares the %Auth:* macros and emits the success
    /// marker the login form's JS reacts to.</summary>
    procedure AfterAuthenticateOK(const ADatabaseName: string); virtual;
    /// <summary>Runs after a failed Authenticate: emits the "invalid login"
    /// fragment.</summary>
    procedure AfterAuthenticateFail; virtual;
    /// <summary>Performs the actual password reset (default: delegates to the
    /// authenticator). Override to plug a custom reset/e-mail flow.</summary>
    procedure ResetPasswordEmail(const AParams: TEFNode); virtual;
  public
    /// POST form fields: UserName, Password, Language, DatabaseName.
    [TKXPath('/login')] [TKXPOST] [TKXAnonymous]
    procedure HandleLogin; virtual;
    [TKXPath('/resetpassword')] [TKXPOST] [TKXAnonymous]
    procedure HandleResetPassword; virtual;
    [TKXPath('/changepassword')] [TKXPOST] [TKXAnonymous]
    procedure HandleChangePassword; virtual;
    /// Ends the current session. Canonical endpoint; menus still emit
    /// GET kx/view/Logout via TKXLogoutController for now.
    [TKXPath('/logout')] [TKXANY] [TKXAnonymous]
    procedure HandleLogout; virtual;
  end;

implementation

uses
  System.SysUtils,
  System.NetEncoding,
  EF.Localization,
  EF.StrUtils,
  Kitto.Auth,
  Kitto.Web.Application,
  Kitto.Web.Session,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Web.Routing.Registry;

const
  COOKIE_DB_LIFETIME_DAYS = 30;

{ TKXAuthHandlerBase }

procedure TKXAuthHandlerBase.BuildAuthData(const AAuthData: TEFNode);
var
  LUserName, LPassword: string;
begin
  LUserName := TKWebRequest.Current.GetField('UserName');
  LPassword := TKWebRequest.Current.GetField('Password');
  if LUserName <> '' then
    AAuthData.SetString('UserName', LUserName);
  if LPassword <> '' then
    AAuthData.SetString('Password', LPassword);
end;

procedure TKXAuthHandlerBase.AfterAuthenticateOK(const ADatabaseName: string);
var
  LApp: TKWebApplication;
begin
  LApp := TKWebApplication.Current;

  // Persist the chosen environment as a cookie so the next visit pre-selects
  // the same database (30 days). Skipped when the authenticator carries its own
  // session-bound state (Auth: JWT ships the database in the 'db' claim), to
  // avoid a parallel kx_db cookie.
  if (ADatabaseName <> '')
    and not LApp.Authenticator.CarriesSessionIdInCredential then
    TKWebResponse.Current.SetCookie('kx_db', ADatabaseName,
      Now + COOKIE_DB_LIFETIME_DAYS);

  // Expose the active database to macro consumers (%Auth:DatabaseName% /
  // %Auth:Environment%), matching the StatusBar / login combo label.
  LApp.DeclareDatabaseMacros(TKWebSession.Current.AuthData);

  // Prevent Home from calling Logout on the next (redirect) request.
  TKWebSession.Current.RefreshingLanguage := True;

  // Success: hidden marker with the redirect URL; the login form's JS detects
  // it after the HTMX swap and performs the redirect. (We don't use HX-Redirect
  // because WebBroker formats custom headers as Name=Value instead of Name: Value.)
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(
    '<div id="kx-login-success" data-redirect="' + LApp.Path + '/" style="display:none"></div>');
end;

procedure TKXAuthHandlerBase.AfterAuthenticateFail;
begin
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(
    '<div class="kx-login-error">' +
      TNetEncoding.HTML.Encode(_('Invalid login.')) +
    '</div>');
end;

procedure TKXAuthHandlerBase.HandleLogin;
var
  LApp: TKWebApplication;
  LAuthData: TEFNode;
  LLanguage, LDatabaseName: string;
begin
  LApp := TKWebApplication.Current;

  // Always regenerate the session ID at login: recovers transparently from a
  // stale session cookie (server restarted / timed out) and hardens against
  // session fixation (the ID changes after successful authentication).
  TKWebSession.Current.RegenerateId;

  // Reset any previously selected database environment. A stale kx_db cookie
  // from another app (or a removed Databases entry) would make DatabaseFor look
  // up a non-existent name and crash. Re-set below only if the user picks one.
  TKWebSession.Current.DatabaseName := '';
  TKWebResponse.Current.SetCookie('kx_db', '', Now - 1);

  LLanguage := TKWebRequest.Current.GetField('Language');
  LDatabaseName := TKWebRequest.Current.GetField('DatabaseName');

  if LLanguage <> '' then
  begin
    TKWebSession.Current.RefreshingLanguage := True;
    TKWebSession.Current.Language := LLanguage;
  end;

  // Apply the chosen database BEFORE authenticating, so the auth query (to
  // KITTO_USERS via TKConfig.Database) is routed to the picked database.
  if LDatabaseName <> '' then
    TKWebSession.Current.DatabaseName := LDatabaseName;

  LAuthData := TEFNode.Create;
  try
    LApp.Authenticator.DefineAuthData(LAuthData);
    BuildAuthData(LAuthData);
    if LApp.Authenticator.Authenticate(LAuthData) then
      AfterAuthenticateOK(LDatabaseName)
    else
      AfterAuthenticateFail;
  finally
    LAuthData.Free;
  end;
end;

procedure TKXAuthHandlerBase.ResetPasswordEmail(const AParams: TEFNode);
begin
  TKWebApplication.Current.Authenticator.ResetPassword(AParams);
end;

procedure TKXAuthHandlerBase.HandleResetPassword;
var
  LParams: TEFNode;
  LUserName, LEmailAddress: string;
begin
  LUserName := TKWebRequest.Current.GetField('UserName');
  LEmailAddress := TKWebRequest.Current.GetField('EmailAddress');

  LParams := TEFNode.Create;
  try
    LParams.SetString('UserName', LUserName);
    LParams.SetString('EmailAddress', LEmailAddress);
    try
      ResetPasswordEmail(LParams);
      // Info dialog; OK also closes the ResetPassword overlay behind it.
      TKWebResponse.Current.Items.Clear;
      TKWebResponse.Current.SetCustomHeader('HX-Retarget', 'body');
      TKWebResponse.Current.SetCustomHeader('HX-Reswap', 'beforeend');
      TKWebResponse.Current.Items.AddHTML(
        '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
          '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
            '<div class="kx-msgbox-header kx-msgbox-info">' +
              '<div class="kx-msgbox-icon kx-msgbox-icon-info"></div>' +
              '<span>' + _('Reset Password') + '</span>' +
            '</div>' +
            '<div class="kx-msgbox-body">' +
              TNetEncoding.HTML.Encode(
                _('A new temporary password was generated and sent to the specified e-mail address.')) +
            '</div>' +
            '<div class="kx-msgbox-footer">' +
              '<button onclick="' +
                'var dlg=document.querySelector(''.kx-dialog-overlay'');' +
                'if(dlg)dlg.remove();' +
                'this.closest(''.kx-msgbox-overlay'').remove();">OK</button>' +
            '</div>' +
          '</div>' +
        '</div>');
    except
      on E: Exception do
      begin
        // Error dialog (same pattern as the global error handler).
        TKWebResponse.Current.Items.Clear;
        TKWebResponse.Current.SetCustomHeader('HX-Retarget', 'body');
        TKWebResponse.Current.SetCustomHeader('HX-Reswap', 'beforeend');
        TKWebResponse.Current.Items.AddHTML(
          '<div class="kx-msgbox-overlay" onclick="this.remove()">' +
            '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
              '<div class="kx-msgbox-header kx-msgbox-error">' +
                '<div class="kx-msgbox-icon kx-msgbox-icon-error"></div>' +
                '<span>' + _('Error') + '</span>' +
              '</div>' +
              '<div class="kx-msgbox-body">' +
                TNetEncoding.HTML.Encode(E.Message) +
              '</div>' +
              '<div class="kx-msgbox-footer">' +
                '<button onclick="this.closest(''.kx-msgbox-overlay'').remove();">OK</button>' +
              '</div>' +
            '</div>' +
          '</div>');
      end;
    end;
  finally
    LParams.Free;
  end;
end;

procedure TKXAuthHandlerBase.HandleChangePassword;
var
  LApp: TKWebApplication;
  LAuthenticator: TKAuthenticator;
  LOldPassword, LNewPassword, LConfirmNewPassword: string;
  LOldPasswordHash, LStoredHash: string;
  LErrorMsg: string;

  function GetPasswordHash(const AClearPassword: string): string;
  begin
    if LAuthenticator.IsClearPassword then
      Result := AClearPassword
    else
      Result := GetStringHash(AClearPassword);
  end;

  procedure RespondError(const AMsg: string);
  begin
    TKWebResponse.Current.Items.Clear;
    TKWebResponse.Current.Items.AddHTML(
      '<div class="kx-login-error">' +
        TNetEncoding.HTML.Encode(AMsg) +
      '</div>');
  end;

begin
  LApp := TKWebApplication.Current;
  LAuthenticator := LApp.Authenticator;

  LOldPassword := TKWebRequest.Current.GetField('OldPassword');
  LNewPassword := TKWebRequest.Current.GetField('NewPassword');
  LConfirmNewPassword := TKWebRequest.Current.GetField('ConfirmNewPassword');

  LStoredHash := LAuthenticator.Password;
  LOldPasswordHash := GetPasswordHash(LOldPassword);

  LErrorMsg := '';
  if LOldPasswordHash <> LStoredHash then
    LErrorMsg := _('Old Password is wrong.')
  else if GetPasswordHash(LNewPassword) = LStoredHash then
    LErrorMsg := _('New Password must be different than old password.')
  else if LNewPassword <> LConfirmNewPassword then
    LErrorMsg := _('Confirm New Password is wrong.');

  if LErrorMsg <> '' then
  begin
    RespondError(LErrorMsg);
    Exit;
  end;

  try
    LAuthenticator.Password := LConfirmNewPassword;
    // Success: info dialog, then redirect to home (forces re-login).
    TKWebResponse.Current.Items.Clear;
    TKWebResponse.Current.SetCustomHeader('HX-Retarget', 'body');
    TKWebResponse.Current.SetCustomHeader('HX-Reswap', 'beforeend');
    TKWebResponse.Current.Items.AddHTML(
      '<div class="kx-msgbox-overlay">' +
        '<div class="kx-msgbox-dialog" onclick="event.stopPropagation()">' +
          '<div class="kx-msgbox-header kx-msgbox-info">' +
            '<div class="kx-msgbox-icon kx-msgbox-icon-info"></div>' +
            '<span>' + _('Change Password') + '</span>' +
          '</div>' +
          '<div class="kx-msgbox-body">' +
            TNetEncoding.HTML.Encode(
              _('Password changed successfully. You will be redirected to the login page.')) +
          '</div>' +
          '<div class="kx-msgbox-footer">' +
            '<button onclick="window.location.href=''' + LApp.Path + '/'';">OK</button>' +
          '</div>' +
        '</div>' +
      '</div>');
    LApp.Logout;
  except
    on E: Exception do
      RespondError(E.Message);
  end;
end;

procedure TKXAuthHandlerBase.HandleLogout;
begin
  TKWebApplication.Current.Logout;
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXAuthHandlerBase);

finalization
  TKXResourceRegistry.Instance.UnregisterResource(TKXAuthHandlerBase);

end.
