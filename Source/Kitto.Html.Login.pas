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
    function RenderNorthContent: string;
    function RenderSouthContent: string;
    function RenderFields: string;
    function RenderLinks: string;
    function RenderLocalStorageCheckbox: string;
    function RenderScript: string;
    function RenderDatabaseChoice(const ALabelStyleAttr, AStyleAttr: string): string;
    function GetDialogStyle: string;
    function GetExtraWidth: Integer;
    function GetExtraHeight: Integer;
    function GetLabelWidth: Integer;
  public
    function Render: string; override;
    [YamlNode('ExtraWidth', '0', 'Extra width in pixels for the login dialog')]
    property ExtraWidth: Integer read GetExtraWidth;
    [YamlNode('ExtraHeight', '0', 'Extra height in pixels for the login dialog')]
    property ExtraHeight: Integer read GetExtraHeight;
    [YamlNode('FormPanel/LabelWidth', '100', 'Label width in pixels for form fields')]
    property LabelWidth: Integer read GetLabelWidth;
  end;

  /// <summary>
  ///  Logs the current user out ending the current session.
  ///  Equivalent of TKExtLogoutController for the KittoX pipeline.
  /// </summary>
  TKXLogoutController = class(TKXToolController)
  protected
    procedure ExecuteTool; override;
  public
    class function GetDefaultDisplayLabel: string;
    class function GetDefaultImageName: string; override;
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
  Kitto.Web.Session,
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

function TKXLoginPanelController.RenderNorthContent: string;
var
  LNorthNode: TEFNode;
  LController: IKXController;
begin
  Result := '';
  LNorthNode := Config.FindNode('BorderPanel/NorthView/Controller');
  if not Assigned(LNorthNode) then
    Exit;

  LController := TKXControllerFactory.Instance.CreateController(View, nil, LNorthNode);
  LController.Display;
  Result := '<div class="kx-login-north">' + LController.Render + '</div>';
end;

function TKXLoginPanelController.RenderSouthContent: string;
var
  LSouthNode: TEFNode;
  LController: IKXController;
begin
  Result := '';
  LSouthNode := Config.FindNode('BorderPanel/SouthView/Controller');
  if not Assigned(LSouthNode) then
    Exit;

  LController := TKXControllerFactory.Instance.CreateController(View, nil, LSouthNode);
  LController.Display;
  Result := '<div class="kx-login-south">' + LController.Render + '</div>';
end;

function TKXLoginPanelController.RenderFields: string;
var
  LUserNameLabel, LPasswordLabel, LLanguageLabel: string;
  LLabelWidth: Integer;
  LInputStyle, LAppName: string;
  LLanguagePerSession: Boolean;
  LStyleAttr, LLabelStyleAttr: string;
begin
  LUserNameLabel := Config.GetString('FormPanel/UserName', _('User Name'));
  LPasswordLabel := Config.GetString('FormPanel/Password', _('Password'));
  LLanguageLabel := Config.GetString('FormPanel/Language', _('Language'));
  LLabelWidth := Config.GetInteger('FormPanel/LabelWidth', 100);
  LInputStyle := Config.GetString('FormPanel/InputStyle', '');
  LAppName := GetAppName;
  LLanguagePerSession := TKWebApplication.Current.Config.LanguagePerSession;

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

  if LLanguagePerSession then
  begin
    Result := Result +
      '<div class="kx-login-field-row">' +
        '<label class="kx-login-field-label" for="kx-login-language"' + LLabelStyleAttr + '>' +
          TNetEncoding.HTML.Encode(LLanguageLabel) + '</label>' +
        '<select id="kx-login-language" name="Language" class="kx-login-field-input"' + LStyleAttr + '>' +
          '<option value="it"' + IfThen(TKWebSession.Current.Language = 'it', ' selected', '') + '>Italiano</option>' +
          '<option value="en"' + IfThen(TKWebSession.Current.Language = 'en', ' selected', '') + '>English</option>' +
        '</select>' +
      '</div>';
  end;

  // LocalStorage checkbox
  Result := Result + RenderLocalStorageCheckbox;
end;

function TKXLoginPanelController.RenderDatabaseChoice(const ALabelStyleAttr, AStyleAttr: string): string;
var
  LChoicesNode: TEFNode;
  LChoicesRaw: string;
  LChoiceList: TArray<string>;
  LCurrent: string;
  LName, LLabel, LSelected: string;
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
  // Read via EffectiveConfigNode so that wrapping authenticators (e.g.
  // TKJWTAuthenticator with Auth/Inner) expose the same key transparently.
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

  Result :=
    '<div class="kx-login-field-row">' +
      '<label class="kx-login-field-label" for="kx-login-database"' + ALabelStyleAttr + '>' +
        TNetEncoding.HTML.Encode(LLabelText) + '</label>' +
      '<select id="kx-login-database" name="DatabaseName" class="kx-login-field-input"' + AStyleAttr + '>';
  for I := 0 to High(LChoiceList) do
  begin
    LName := Trim(LChoiceList[I]);
    if LName = '' then
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
    Result := Result +
      '<option value="' + TNetEncoding.HTML.Encode(LName) + '"' + LSelected + '>' +
        TNetEncoding.HTML.Encode(LLabel) + '</option>';
  end;
  Result := Result + '</select></div>';
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

    // Enable/disable button
    SB.Append('  function updateBtn() {').Append(sLineBreak);
    SB.Append('    btnEl.disabled = (userEl.value.trim() === "" || passEl.value.trim() === "");').Append(sLineBreak);
    SB.Append('  }').Append(sLineBreak);
    SB.Append('  userEl.addEventListener("input", updateBtn);').Append(sLineBreak);
    SB.Append('  passEl.addEventListener("input", updateBtn);').Append(sLineBreak);
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
          '<form id="kx-login-form" class="kx-login-form"' + LBodyStyleAttr +
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
