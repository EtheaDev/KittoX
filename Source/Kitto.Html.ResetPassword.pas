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
///  KittoX ResetPassword controller. Renders a dialog with UserName and
///  EmailAddress fields. Submits via HTMX POST to kx/resetpassword.
///  Replaces TKExtResetPassword from Kitto.Ext.ResetPassword.
/// </summary>
unit Kitto.Html.ResetPassword;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.Base,
  Kitto.Html.Controller,
  Kitto.Html.FormController,
  EF.YAML.Attributes;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXResetPasswordController = class(TKXFormController)
  strict private
    function GetLabelWidth: Integer;
  strict protected
    procedure DoDisplay; override;
    function RenderFormBody: string; override;
    function RenderFormButtons: string; override;
    function GetFormId: string; override;
    function GetFormAction: string; override;
    function GetFormTarget: string; override;
    function RenderFormScript: string; override;
  public
    [YamlNode('LabelWidth', '100', 'Label width in pixels for form fields')]
    property LabelWidth: Integer read GetLabelWidth;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.NetEncoding,
  EF.Localization,
  Kitto.Html.Utils;

{ TKXResetPasswordController }

function TKXResetPasswordController.GetLabelWidth: Integer;
begin
  Result := Config.GetInteger('LabelWidth', 100);
end;

procedure TKXResetPasswordController.DoDisplay;
begin
  inherited;
  if Width = 0 then
    Width := 400;
  Height := Max(Height, 250);
end;

function TKXResetPasswordController.GetFormId: string;
begin
  Result := 'kx-resetpw-form';
end;

function TKXResetPasswordController.GetFormAction: string;
begin
  Result := 'kx/resetpassword';
end;

function TKXResetPasswordController.GetFormTarget: string;
begin
  Result := '#kx-rp-status';
end;

function TKXResetPasswordController.RenderFormBody: string;
var
  LUserNameLabel, LEmailLabel: string;
  LLabelStyleAttr: string;
  LLabelWidth: Integer;
begin
  LUserNameLabel := _('User Name');
  LEmailLabel := _('Email address');
  LLabelWidth := Config.GetInteger('LabelWidth', 100);
  LLabelStyleAttr := Format(' style="min-width: %dpx; width: %0:dpx;"', [LLabelWidth]);

  Result :=
    '<div class="kx-rp-fields">' +
      '<div class="kx-login-field-row">' +
        '<label class="kx-login-field-label" for="kx-rp-username"' +
          LLabelStyleAttr + '>' +
          TNetEncoding.HTML.Encode(LUserNameLabel) + '</label>' +
        '<input type="text" id="kx-rp-username" name="UserName" ' +
          'class="kx-login-field-input" autocomplete="username" required>' +
      '</div>' +
      '<div class="kx-login-field-row">' +
        '<label class="kx-login-field-label" for="kx-rp-email"' +
          LLabelStyleAttr + '>' +
          TNetEncoding.HTML.Encode(LEmailLabel) + '</label>' +
        '<input type="email" id="kx-rp-email" name="EmailAddress" ' +
          'class="kx-login-field-input" autocomplete="email" required>' +
      '</div>' +
    '</div>';
end;

function TKXResetPasswordController.RenderFormButtons: string;
var
  LSendLabel, LSendingLabel, LSendIconHtml: string;
begin
  LSendLabel := _('Send');
  LSendingLabel := _('Generating new password...');
  LSendIconHtml := GetIconHTML('email_go', isLarge, 'kx-rp-button-icon');

  Result :=
    '<div id="kx-rp-status" class="kx-login-status">' +
      '<div class="kx-login-indicator htmx-indicator">' +
        '<span class="kx-login-spinner"></span>' +
        TNetEncoding.HTML.Encode(LSendingLabel) +
      '</div>' +
    '</div>' +
    '<button type="submit" class="kx-login-button" id="kx-rp-btn" disabled>' +
      LSendIconHtml +
      TNetEncoding.HTML.Encode(LSendLabel) +
    '</button>';
end;

function TKXResetPasswordController.RenderFormScript: string;
begin
  Result :=
    '(function() {' +
    '  var userEl = document.getElementById("kx-rp-username");' +
    '  var emailEl = document.getElementById("kx-rp-email");' +
    '  var btnEl = document.getElementById("kx-rp-btn");' +
    '  function updateBtn() {' +
    '    btnEl.disabled = (userEl.value.trim() === "" || emailEl.value.trim() === "");' +
    '  }' +
    '  userEl.addEventListener("input", updateBtn);' +
    '  emailEl.addEventListener("input", updateBtn);' +
    '  updateBtn();' +
    '  userEl.focus();' +
    '})();';
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('ResetPassword', TKXResetPasswordController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('ResetPassword');

end.
