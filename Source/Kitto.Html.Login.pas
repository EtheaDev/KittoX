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
///  KittoX Login and Logout controllers.
///  TKXLoginPanelController renders an HTML+HTMX login form (replaces TKExtLoginPanel).
///  TKXLogoutController logs out the user (replaces TKExtLogoutController).
/// </summary>
unit Kitto.Html.Login;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Html.Base,
  Kitto.Html.Controller,
  Kitto.Html.Tools;

type
  /// <summary>
  ///  Renders a login form using HTML + HTMX.
  ///  Equivalent of TKExtLoginPanel for the KittoX pipeline.
  /// </summary>
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXLoginPanelController = class(TKXComponent, IKXController)
  strict private
    FLocalStorageMode: string;
    FLocalStorageAskUser: Boolean;
    FLocalStorageAutoLogin: Boolean;
    function GetAppName: string;
    function RenderRegionContent(const ARegion, ACssClass: string): string;
    function RenderNorthContent: string;
    function RenderSouthContent: string;
    function RenderWestContent: string;
    function RenderEastContent: string;
    function RenderFields: string;
    function RenderLinks: string;
    function RenderLocalStorageCheckbox: string;
    function RenderScript: string;
    function RenderDatabaseChoice(const ALabelStyleAttr, AStyleAttr: string): string;
    function GetDialogStyle: string;
    function GetExtraWidth: Integer;
    function GetExtraHeight: Integer;
    function GetLabelWidth: Integer;
    function GetEditWidth: Integer;
    function GetLocalStorage: string;
    function GetTitle: string;
    function GetStyle: string;
    function GetSendQR: Boolean;
    function GetResetPassword: Boolean;
    function GetRegisterNewUser: Boolean;
    function GetPrivacyPolicy: Boolean;
    function GetFormPanel: string;
    function GetBorderPanel: string;
  public
    /// <summary>Renders the login form (fields, links, database choice, script).</summary>
    function Render: string; override;
    [YamlNode('ExtraWidth', '0', 'Extra width in pixels for the login dialog')]
    property ExtraWidth: Integer read GetExtraWidth;
    [YamlNode('ExtraHeight', '0', 'Extra height in pixels for the login dialog')]
    property ExtraHeight: Integer read GetExtraHeight;
    [YamlNode('LabelWidth', '100', 'Label width in pixels for the login form fields')]
    property LabelWidth: Integer read GetLabelWidth;
    [YamlNode('EditWidth', 'Width in pixels of the login input fields')]
    property EditWidth: Integer read GetEditWidth;
    /// <summary>RTTI carrier for the LocalStorage node (Mode/AskUser/AutoLogin):
    /// remembers the last user name/password in the browser. Read via
    /// FindNode('LocalStorage') at render time.</summary>
    [YamlNode('LocalStorage', 'Remember credentials in the browser (Mode: UserName/Password, AskUser, AutoLogin)')]
    property LocalStorage: string read GetLocalStorage;

    [YamlNode('Title', 'Login dialog title (defaults to the application title)')]
    property Title: string read GetTitle;
    [YamlNode('Style', 'Extra inline CSS applied to the login dialog')]
    property Style: string read GetStyle;
    [YamlNode('SendQR', 'False', 'Show the "send QR" action for two-factor enrolment')]
    property SendQR: Boolean read GetSendQR;
    [YamlNode('ResetPassword', 'False', 'Show the "password forgotten?" link (sub-node HrefStyle styles it)')]
    property ResetPassword: Boolean read GetResetPassword;
    [YamlNode('RegisterNewUser', 'False', 'Show the "register new user" link (sub-node HrefStyle styles it)')]
    property RegisterNewUser: Boolean read GetRegisterNewUser;
    [YamlNode('PrivacyPolicy', 'False', 'Show the "privacy policy" link (sub-node HrefStyle styles it)')]
    property PrivacyPolicy: Boolean read GetPrivacyPolicy;
    [YamlNode('FormPanel', 'Login form panel options (UserName label, LabelWidth)')]
    property FormPanel: string read GetFormPanel;
    [YamlNode('BorderPanel', 'Optional regions around the login form (WestView/SouthView/NorthView/EastView, each hosting a controller)')]
    property BorderPanel: string read GetBorderPanel;
  end;

  /// <summary>
  ///  Logs the current user out ending the current session.
  ///  Equivalent of TKExtLogoutController for the KittoX pipeline.
  /// </summary>
  TKXLogoutController = class(TKXToolController)
  protected
    procedure ExecuteTool; override;
  public
    /// <summary>The default display label for the logout action ('Logout').</summary>
    class function GetDefaultDisplayLabel: string;
    /// <summary>The default icon name for the logout action.</summary>
    class function GetDefaultImageName: string; override;
    /// <summary>Logout produces no HTML (it ends the session); returns an empty string.</summary>
    function Render: string; override;
  end;


implementation

uses
  System.Classes,
  System.StrUtils,
  System.Rtti,
  System.NetEncoding,
  Kitto.TemplatePro,
  EF.Localization,
  EF.Macros,
  Kitto.Config,
  Kitto.Web.Application,
  Kitto.Web.Request,
  Kitto.Web.Session,
  Kitto.Html.LanguageSwitcher,
  Kitto.Html.TemplateEngine,
  Kitto.Html.Utils;

{ TKXLoginPanelController }

function TKXLoginPanelController.GetExtraWidth: Integer;
begin
  Result := Config.GetInteger('ExtraWidth', 0);
end;

function TKXLoginPanelController.GetExtraHeight: Integer;
begin
  Result := Config.GetInteger('ExtraHeight', 0);
end;

function TKXLoginPanelController.GetLabelWidth: Integer;
begin
  Result := Config.GetInteger('FormPanel/LabelWidth', 100);
end;

function TKXLoginPanelController.GetAppName: string;
begin
  Result := TKWebApplication.Current.Config.AppName;
end;

function TKXLoginPanelController.GetEditWidth: Integer;
begin
  Result := Config.GetInteger('EditWidth', 0);
end;

function TKXLoginPanelController.GetLocalStorage: string;
begin
  // RTTI carrier only: the LocalStorage options are read via FindNode at render time.
  Result := '';
end;

function TKXLoginPanelController.GetTitle: string;
begin
  Result := Config.GetString('Title');
end;

function TKXLoginPanelController.GetStyle: string;
begin
  Result := Config.GetString('Style');
end;

function TKXLoginPanelController.GetSendQR: Boolean;
begin
  Result := Config.GetBoolean('SendQR');
end;

function TKXLoginPanelController.GetResetPassword: Boolean;
begin
  Result := Config.GetBoolean('ResetPassword');
end;

function TKXLoginPanelController.GetRegisterNewUser: Boolean;
begin
  Result := Config.GetBoolean('RegisterNewUser');
end;

function TKXLoginPanelController.GetPrivacyPolicy: Boolean;
begin
  Result := Config.GetBoolean('PrivacyPolicy');
end;

function TKXLoginPanelController.GetFormPanel: string;
begin
  Result := Config.GetString('FormPanel');
end;

function TKXLoginPanelController.GetBorderPanel: string;
begin
  Result := Config.GetString('BorderPanel');
end;

function TKXLoginPanelController.GetDialogStyle: string;
var
  LStyle: string;
  LExtraWidth, LExtraHeight: Integer;
begin
  Result := '';
  LStyle := Config.GetString('Style', '');
  LExtraWidth := Config.GetInteger('ExtraWidth', 0);
  LExtraHeight := Config.GetInteger('ExtraHeight', 0);

  if LExtraWidth > 0 then
    Result := Result + Format('width: %dpx; ', [LExtraWidth]);
  if LExtraHeight > 0 then
    Result := Result + Format('min-height: %dpx; ', [LExtraHeight]);
  if LStyle <> '' then
    Result := Result + LStyle;
end;

function TKXLoginPanelController.RenderRegionContent(const ARegion, ACssClass: string): string;
var
  LNode: TEFNode;
  LController: IKXController;
begin
  // Generic renderer for the four optional BorderPanel regions of the login
  // dialog (NorthView / SouthView / WestView / EastView). Each hosts a single
  // child controller (HtmlPanel with a logo, ThemeSwitcher, etc.). Returns ''
  // when the region is not declared, so the template/CSS collapse it.
  Result := '';
  LNode := Config.FindNode('BorderPanel/' + ARegion + '/Controller');
  if not Assigned(LNode) then
    Exit;

  LController := TKXControllerFactory.Instance.CreateController(View, nil, LNode);
  LController.Display;
  Result := '<div class="' + ACssClass + '">' + LController.Render + '</div>';
end;

function TKXLoginPanelController.RenderNorthContent: string;
begin
  Result := RenderRegionContent('NorthView', 'kx-login-north');
end;

function TKXLoginPanelController.RenderSouthContent: string;
begin
  Result := RenderRegionContent('SouthView', 'kx-login-south');
end;

function TKXLoginPanelController.RenderWestContent: string;
begin
  Result := RenderRegionContent('WestView', 'kx-login-west');
end;

function TKXLoginPanelController.RenderEastContent: string;
begin
  Result := RenderRegionContent('EastView', 'kx-login-east');
end;

function TKXLoginPanelController.RenderFields: string;
var
  LUserNameLabel, LPasswordLabel: string;
  LLabelWidth: Integer;
  LInputStyle: string;
  LStyleAttr, LLabelStyleAttr: string;
  LLangHtml: string;
begin
  LUserNameLabel := Config.GetString('FormPanel/UserName', _('User Name'));
  LPasswordLabel := Config.GetString('FormPanel/Password', _('Password'));
  LLabelWidth := Config.GetInteger('FormPanel/LabelWidth', 100);
  LInputStyle := Config.GetString('FormPanel/InputStyle', '');

  LLabelStyleAttr := Format(' style="min-width: %dpx; width: %0:dpx;"', [LLabelWidth]);

  if LInputStyle <> '' then
    LStyleAttr := ' style="' + TNetEncoding.HTML.Encode(LInputStyle) + '"'
  else
    LStyleAttr := '';

  // Optional "environment" combo: shown before UserName when
  // Auth/DatabaseChoices is configured in Config.yaml.
  Result := RenderDatabaseChoice(LLabelStyleAttr, LStyleAttr);

  Result := Result +
    '<div class="kx-login-field-row">' +
      '<label class="kx-login-field-label" for="kx-login-username"' + LLabelStyleAttr + '>' +
        TNetEncoding.HTML.Encode(LUserNameLabel) + '</label>' +
      '<input type="text" id="kx-login-username" name="UserName" ' +
        'class="kx-login-field-input" autocomplete="username" required' +
        LStyleAttr + '>' +
    '</div>' +
    '<div class="kx-login-field-row">' +
      '<label class="kx-login-field-label" for="kx-login-password"' + LLabelStyleAttr + '>' +
        TNetEncoding.HTML.Encode(LPasswordLabel) + '</label>' +
      '<input type="password" id="kx-login-password" name="Password" ' +
        'class="kx-login-field-input" autocomplete="current-password" required' +
        LStyleAttr + '>' +
    '</div>';

  // Language selector: the reusable LanguageSwitcher (flag dropdown) embedded
  // as a labelled field row, in the same spot the old hardcoded combo used to
  // occupy ("Language" label on the left). The same controller also renders on
  // the Home page. Emits nothing when LanguagePerSession is off or only one
  // language ships.
  LLangHtml := TKXLanguageCatalog.RenderSwitcherHtml('kx-login-language');
  if LLangHtml <> '' then
    Result := Result +
      '<div class="kx-login-field-row">' +
        '<label class="kx-login-field-label"' + LLabelStyleAttr + '>' +
          TNetEncoding.HTML.Encode(_('Language')) + '</label>' +
        '<div class="kx-login-lang-cell">' + LLangHtml + '</div>' +
      '</div>';

  // LocalStorage checkbox
  Result := Result + RenderLocalStorageCheckbox;
end;

function TKXLoginPanelController.RenderDatabaseChoice(const ALabelStyleAttr, AStyleAttr: string): string;
var
  LChoicesNode: TEFNode;
  LChoicesRaw: string;
  LChoiceList: TArray<string>;
  LCurrent: string;
  LName, LLabel, LSelected, LOptions: string;
  LDbNode: TEFNode;
  LLabelText: string;
  I: Integer;
begin
  Result := '';
  // Read the explicit list of database choices the user is allowed to pick at
  // login time. Format: comma-separated list of database names defined under
  // the Databases node, e.g.
  //   Auth: TasKitto
  //     DatabaseChoices: FireDAC_MSSQL, FireDAC_PostgreSQL, FireDAC_Firebird
  // If this node is absent or empty, no combo is rendered (legacy behavior).
  // Read via EffectiveConfigNode (the authenticator's own Auth node).
  LChoicesNode := TKWebApplication.Current.Authenticator.EffectiveConfigNode
    .FindNode('DatabaseChoices');
  if not Assigned(LChoicesNode) then
    Exit;
  LChoicesRaw := LChoicesNode.AsString;
  if Trim(LChoicesRaw) = '' then
    Exit;
  LChoiceList := SplitString(LChoicesRaw, ',');
  if Length(LChoiceList) = 0 then
    Exit;

  // Default selection: rely on TKConfig.DatabaseName which already resolves
  // session override → DatabaseRouter → DefaultDatabaseName, in that order.
  // The session has already been populated from the kx_db cookie by
  // TKWebEngine.EnsureSession at the start of this request.
  LCurrent := TKWebApplication.Current.Config.DatabaseName;

  LLabelText := Config.GetString('FormPanel/Database', _('Environment'));

  // Build the <option> list first, skipping any choice that is not actually
  // usable: either its Databases/<Name> block is commented out, or the DB
  // adapter it references is not compiled into this build (its EF.DB.* unit is
  // not in the app's uses — e.g. an optional back-end like ODAC_Oracle). This
  // lets a config list optional databases that appear in the combo only when
  // they are enabled, instead of offering a selection that would fail to connect.
  LOptions := '';
  for I := 0 to High(LChoiceList) do
  begin
    LName := Trim(LChoiceList[I]);
    if LName = '' then
      Continue;
    // Skip choices whose database is not available (block disabled or adapter
    // unit not compiled in).
    if not TKWebApplication.Current.Config.IsDatabaseAvailable(LName) then
      Continue;
    // Optional per-database display label: Databases/<Name>/DisplayLabel.
    // Falls back to the raw config name.
    LDbNode := TKWebApplication.Current.Config.Config.FindNode(
      'Databases/' + LName + '/DisplayLabel');
    if Assigned(LDbNode) then
      LLabel := LDbNode.AsExpandedString
    else
      LLabel := LName;
    if SameText(LName, LCurrent) then
      LSelected := ' selected'
    else
      LSelected := '';
    LOptions := LOptions +
      '<option value="' + TNetEncoding.HTML.Encode(LName) + '"' + LSelected + '>' +
        TNetEncoding.HTML.Encode(LLabel) + '</option>';
  end;

  // No selectable database (all choices disabled) → render no combo.
  if LOptions = '' then
    Exit;

  Result :=
    '<div class="kx-login-field-row">' +
      '<label class="kx-login-field-label" for="kx-login-database"' + ALabelStyleAttr + '>' +
        TNetEncoding.HTML.Encode(LLabelText) + '</label>' +
      '<select id="kx-login-database" name="DatabaseName" class="kx-login-field-input"' + AStyleAttr + '>' +
      LOptions +
      '</select></div>';
end;

function TKXLoginPanelController.RenderLocalStorageCheckbox: string;
var
  LLocalStorageOptions: TEFNode;
  LCheckboxLabel: string;
  LCheckedAttr: string;
begin
  Result := '';
  LLocalStorageOptions := Config.FindNode('LocalStorage');
  if not Assigned(LLocalStorageOptions) then
  begin
    FLocalStorageMode := '';
    FLocalStorageAskUser := False;
    FLocalStorageAutoLogin := False;
    Exit;
  end;

  FLocalStorageMode := LLocalStorageOptions.GetString('Mode');
  FLocalStorageAskUser := LLocalStorageOptions.GetBoolean('AskUser');
  FLocalStorageAutoLogin := LLocalStorageOptions.GetBoolean('AutoLogin', False);

  if (FLocalStorageMode = '') or not FLocalStorageAskUser then
    Exit;

  if SameText(FLocalStorageMode, 'Password') then
    LCheckboxLabel := Config.GetString('FormPanel/RememberCredentials', _('Remember Credentials'))
  else
    LCheckboxLabel := Config.GetString('FormPanel/RememberUserName', _('Remember User Name'));

  if LLocalStorageOptions.GetBoolean('AskUser/Default', True) then
    LCheckedAttr := ' checked'
  else
    LCheckedAttr := '';

  Result :=
    '<div class="kx-login-field-row kx-login-checkbox-row">' +
      '<label class="kx-login-field-label" for="kx-login-localstorage">&nbsp;</label>' +
      '<label class="kx-login-checkbox-label">' +
        '<input type="checkbox" id="kx-login-localstorage" name="LocalStorageEnabled" value="true"' +
          LCheckedAttr + '> ' +
        TNetEncoding.HTML.Encode(LCheckboxLabel) +
      '</label>' +
    '</div>';
end;

function TKXLoginPanelController.RenderLinks: string;

  function RenderLink(const ANodeName, ADefaultLabel: string): string;
  var
    LNode: TEFNode;
    LStyle: string;
    LStyleAttr: string;
  begin
    Result := '';
    LNode := Config.FindNode(ANodeName);
    if not Assigned(LNode) or not LNode.AsBoolean then
      Exit;
    LStyle := LNode.GetString('HrefStyle', '');
    if LStyle <> '' then
      LStyleAttr := ' style="' + TNetEncoding.HTML.Encode(LStyle) + '"'
    else
      LStyleAttr := '';
    Result :=
      '<a href="#" class="kx-login-link"' + LStyleAttr +
        ' hx-get="kx/view/' + ANodeName + '"' +
        ' hx-target="body" hx-swap="beforeend">' +
        TNetEncoding.HTML.Encode(_(ADefaultLabel)) +
      '</a>';
  end;

begin
  Result := '';
  Result := Result + RenderLink('ResetPassword', 'Password forgotten?');
  Result := Result + RenderLink('RegisterNewUser', 'New User? Register...');
  Result := Result + RenderLink('PrivacyPolicy', 'Privacy policy...');
  if Result <> '' then
    Result := '<div class="kx-login-links">' + Result + '</div>';
end;

function TKXLoginPanelController.RenderScript: string;
var
  LAppName: string;
  SB: TStringBuilder;
begin
  LAppName := GetAppName;
  SB := TStringBuilder.Create;
  try
    SB.Append('<script>').Append(sLineBreak);
    SB.Append('(function() {').Append(sLineBreak);
    SB.Append('  var appName = ').Append(QuotedStr(LAppName)).Append(';').Append(sLineBreak);
    SB.Append('  var userEl = document.getElementById("kx-login-username");').Append(sLineBreak);
    SB.Append('  var passEl = document.getElementById("kx-login-password");').Append(sLineBreak);
    SB.Append('  var btnEl = document.getElementById("kx-login-btn");').Append(sLineBreak);
    SB.Append('  var formEl = document.getElementById("kx-login-form");').Append(sLineBreak);
    SB.Append('  var lsCheckEl = document.getElementById("kx-login-localstorage");').Append(sLineBreak);

    // Retrieve from localStorage
    if SameText(FLocalStorageMode, 'UserName') or SameText(FLocalStorageMode, 'Password') then
    begin
      SB.Append('  var storedUser = localStorage.getItem(appName + "_UserName");').Append(sLineBreak);
      SB.Append('  if (storedUser) userEl.value = storedUser;').Append(sLineBreak);
    end;
    if SameText(FLocalStorageMode, 'Password') then
    begin
      SB.Append('  var storedPass = localStorage.getItem(appName + "_Password");').Append(sLineBreak);
      SB.Append('  if (storedPass) passEl.value = storedPass;').Append(sLineBreak);
    end;
    if FLocalStorageAskUser then
    begin
      SB.Append('  if (lsCheckEl) {').Append(sLineBreak);
      SB.Append('    var storedLs = localStorage.getItem(appName + "_LocalStorageEnabled");').Append(sLineBreak);
      SB.Append('    if (storedLs !== null) lsCheckEl.checked = (storedLs === "true");').Append(sLineBreak);
      SB.Append('  }').Append(sLineBreak);
    end;

    // Enable/disable button. Disabled until the page is fully loaded, because
    // htmx binds hx-post on DOMContentLoaded and a click before that submits
    // the form natively. 'complete', not 'interactive': the latter fires as
    // soon as the DOM is parsed, while the user still sees a loading page.
    //
    // Loading is the ONLY condition. The button used to stay disabled while
    // either field read empty, updated on "input"; but a browser's password
    // manager fills both fields without an "input" event and (Chrome, Edge)
    // keeps the autofilled password unreadable by script until the user's
    // first gesture on the page, so the button showed the not-allowed cursor
    // over credentials that were plainly there, until a click anywhere. Empty
    // fields are refused by the inputs' own "required" (htmx does not issue
    // the request while the form is invalid), which needs no script.
    SB.Append('  function ready() {').Append(sLineBreak);
    SB.Append('    return !!window.htmx && document.readyState === "complete";').Append(sLineBreak);
    SB.Append('  }').Append(sLineBreak);
    SB.Append('  function updateBtn() {').Append(sLineBreak);
    SB.Append('    btnEl.disabled = !ready();').Append(sLineBreak);
    SB.Append('  }').Append(sLineBreak);
    SB.Append('  document.addEventListener("DOMContentLoaded", updateBtn);').Append(sLineBreak);
    SB.Append('  window.addEventListener("load", updateBtn);').Append(sLineBreak);
    SB.Append('  updateBtn();').Append(sLineBreak);

    // Focus logic
    SB.Append('  if (userEl.value && !passEl.value) passEl.focus();').Append(sLineBreak);
    SB.Append('  else userEl.focus();').Append(sLineBreak);

    // Detect successful login
    SB.Append('  formEl.addEventListener("htmx:afterSettle", function(evt) {').Append(sLineBreak);
    SB.Append('    var successEl = document.getElementById("kx-login-success");').Append(sLineBreak);
    SB.Append('    if (successEl) {').Append(sLineBreak);
    if FLocalStorageMode <> '' then
    begin
      SB.Append('      var doSave = true;').Append(sLineBreak);
      if FLocalStorageAskUser then
        SB.Append('      if (lsCheckEl) doSave = lsCheckEl.checked;').Append(sLineBreak);
      SB.Append('      if (doSave) {').Append(sLineBreak);
      if SameText(FLocalStorageMode, 'UserName') or SameText(FLocalStorageMode, 'Password') then
        SB.Append('        localStorage.setItem(appName + "_UserName", userEl.value);').Append(sLineBreak);
      if SameText(FLocalStorageMode, 'Password') then
        SB.Append('        localStorage.setItem(appName + "_Password", passEl.value);').Append(sLineBreak);
      if FLocalStorageAskUser then
        SB.Append('        if (lsCheckEl) localStorage.setItem(appName + "_LocalStorageEnabled", lsCheckEl.checked ? "true" : "false");').Append(sLineBreak);
      SB.Append('      } else {').Append(sLineBreak);
      SB.Append('        localStorage.removeItem(appName + "_UserName");').Append(sLineBreak);
      SB.Append('        localStorage.removeItem(appName + "_Password");').Append(sLineBreak);
      SB.Append('        localStorage.removeItem(appName + "_LocalStorageEnabled");').Append(sLineBreak);
      SB.Append('      }').Append(sLineBreak);
    end;
    SB.Append('      window.location.href = successEl.dataset.redirect;').Append(sLineBreak);
    SB.Append('    }').Append(sLineBreak);
    SB.Append('  });').Append(sLineBreak);

    // AutoLogin
    if FLocalStorageAutoLogin then
    begin
      SB.Append('  if (userEl.value && passEl.value) {').Append(sLineBreak);
      SB.Append('    setTimeout(function() { htmx.trigger(formEl, "submit"); }, 200);').Append(sLineBreak);
      SB.Append('  }').Append(sLineBreak);
    end;

    SB.Append('})();').Append(sLineBreak);
    SB.Append('</script>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXLoginPanelController.Render: string;
var
  LTemplatePath: string;
  LHtmlId: string;
  LTitle: TEFNode;
  LTitleStr: string;
  LDialogStyle: string;
  LNorthContent: string;
  LSouthContent: string;
  LWestContent: string;
  LEastContent: string;
  LFieldsContent: string;
  LLinksContent: string;
  LLoginLabel: string;
  LLoggingInLabel: string;
  LButtonStyle: string;
  LButtonStyleAttr: string;
  LBodyStyle: string;
  LBodyStyleAttr: string;
  LScriptContent: string;
  LLoginIconHtml: string;
begin
  LHtmlId := GetHtmlId;
  LTitle := Config.FindNode('Title');
  if Assigned(LTitle) then
    LTitleStr := _(LTitle.AsExpandedString)
  else
    LTitleStr := _(TKWebApplication.Current.Config.AppTitle);

  LDialogStyle := GetDialogStyle;
  LNorthContent := RenderNorthContent;
  LSouthContent := RenderSouthContent;
  LWestContent := RenderWestContent;
  LEastContent := RenderEastContent;
  LFieldsContent := RenderFields;
  LLinksContent := RenderLinks;
  LLoginLabel := _('Login');
  LLoggingInLabel := _('Logging in...');
  LButtonStyle := Config.GetString('FormPanel/ButtonStyle', '');
  if LButtonStyle <> '' then
    LButtonStyleAttr := ' style="' + TNetEncoding.HTML.Encode(LButtonStyle) + '"'
  else
    LButtonStyleAttr := '';

  LLoginIconHtml := GetIconHTML('login', isLarge, 'kx-login-button-icon');
  LBodyStyle := Config.GetString('FormPanel/BodyStyle', '');
  if LBodyStyle <> '' then
    LBodyStyleAttr := ' style="' + TNetEncoding.HTML.Encode(LBodyStyle) + '"'
  else
    LBodyStyleAttr := '';

  LScriptContent := RenderScript;

  LTemplatePath := TKXTemplateEngine.Instance.FindTemplatePath('', 'Login');
  if LTemplatePath <> '' then
  begin
    Result := TKXTemplateEngine.Instance.Render(LTemplatePath,
      procedure(ATemplate: ITProCompiledTemplate)
      begin
        ATemplate.SetData('htmlId', TValue.From<string>(LHtmlId));
        ATemplate.SetData('title', TValue.From<string>(LTitleStr));
        ATemplate.SetData('dialogStyle', TValue.From<string>(LDialogStyle));
        ATemplate.SetData('northContent', TValue.From<string>(LNorthContent));
        ATemplate.SetData('southContent', TValue.From<string>(LSouthContent));
        ATemplate.SetData('westContent', TValue.From<string>(LWestContent));
        ATemplate.SetData('eastContent', TValue.From<string>(LEastContent));
        ATemplate.SetData('fieldsContent', TValue.From<string>(LFieldsContent));
        ATemplate.SetData('linksContent', TValue.From<string>(LLinksContent));
        ATemplate.SetData('loginLabel', TValue.From<string>(LLoginLabel));
        ATemplate.SetData('buttonStyleAttr', TValue.From<string>(LButtonStyleAttr));
        ATemplate.SetData('bodyStyleAttr', TValue.From<string>(LBodyStyleAttr));
        ATemplate.SetData('loginIconHtml', TValue.From<string>(LLoginIconHtml));
        ATemplate.SetData('loggingInLabel', TValue.From<string>(LLoggingInLabel));
        ATemplate.SetData('scriptContent', TValue.From<string>(LScriptContent));
      end);
  end
  else
  begin
    // Inline fallback if no template file found
    Result :=
      '<div id="' + LHtmlId + '" class="kx-login-overlay">' +
        '<div class="kx-login-dialog"' + IfThen(LDialogStyle <> '', ' style="' + LDialogStyle + '"', '') + '>' +
          '<div class="kx-login-header">' +
            '<span class="kx-login-title">' + TNetEncoding.HTML.Encode(LTitleStr) + '</span>' +
          '</div>' +
          LNorthContent +
          '<form id="kx-login-form" class="kx-login-form" method="post" action="kx/login"' + LBodyStyleAttr +
            ' hx-post="kx/login" hx-target="#kx-login-status" hx-swap="innerHTML">' +
            '<div class="kx-login-fields">' +
              LFieldsContent +
            '</div>' +
            LLinksContent +
            '<div class="kx-login-footer">' +
              '<div id="kx-login-status" class="kx-login-status">' +
                '<div class="kx-login-indicator htmx-indicator">' +
                  '<span class="kx-login-spinner"></span>' +
                  TNetEncoding.HTML.Encode(LLoggingInLabel) +
                '</div>' +
              '</div>' +
              '<button type="submit" class="kx-login-button" id="kx-login-btn" disabled' + LButtonStyleAttr + '>' +
                LLoginIconHtml +
                TNetEncoding.HTML.Encode(LLoginLabel) +
              '</button>' +
            '</div>' +
          '</form>' +
          LSouthContent +
        '</div>' +
      '</div>' +
      LScriptContent;
  end;
end;

{ TKXLogoutController }

procedure TKXLogoutController.ExecuteTool;
begin
  inherited;
  // Defence in depth: the menu now posts to kx/logout, but this controller is
  // still reachable via the bare kx/view/Logout route, which is [TKXANY] and
  // therefore answers GET too. Log out only on a POST, so a cross-site GET here
  // cannot end the session (logout-CSRF).
  if SameText(TKWebRequest.Current.Method, 'POST') then
    TKWebApplication.Current.Logout;
end;

function TKXLogoutController.Render: string;
begin
  // Return a marker element that the global htmx:afterSettle listener
  // in _Page.html will detect and trigger a full page reload.
  // Note: we can't use Items (Reload adds to Items but SendFragment clears them)
  // and we can't use response headers (WebBroker formats them incorrectly).
  Result := '<div class="kx-reload-trigger" data-action="reload" style="display:none"></div>';
end;

class function TKXLogoutController.GetDefaultDisplayLabel: string;
begin
  Result := _('Logout');
end;

class function TKXLogoutController.GetDefaultImageName: string;
begin
  Result := 'logout';
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('Login', TKXLoginPanelController);
  TKXControllerRegistry.Instance.RegisterClass('Logout', TKXLogoutController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('Login');
  TKXControllerRegistry.Instance.UnregisterClass('Logout');

end.
