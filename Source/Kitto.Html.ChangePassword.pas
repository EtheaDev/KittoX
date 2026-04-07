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
///  KittoX ChangePassword controller. Renders a dialog with OldPassword,
///  NewPassword, and ConfirmNewPassword fields. Submits via HTMX POST
///  to kx/changepassword. Replaces TKExtChangePassword from
///  Kitto.Ext.ChangePassword.
/// </summary>
unit Kitto.Html.ChangePassword;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.Base,
  Kitto.Html.Controller,
  Kitto.Html.FormController,
  EF.YAML.Attributes;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXChangePasswordController = class(TKXFormController)
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
    class function GetDefaultDisplayLabel: string;
    class function GetDefaultImageName: string;
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

{ TKXChangePasswordController }

function TKXChangePasswordController.GetLabelWidth: Integer;
begin
  Result := Config.GetInteger('LabelWidth', 100);
end;

procedure TKXChangePasswordController.DoDisplay;
begin
  inherited;
  if Width = 0 then
    Width := 400;
  Height := Max(Height, 280);
end;

class function TKXChangePasswordController.GetDefaultDisplayLabel: string;
begin
  Result := _('Change Password');
end;

class function TKXChangePasswordController.GetDefaultImageName: string;
begin
  Result := 'password';
end;

function TKXChangePasswordController.GetFormId: string;
begin
  Result := 'kx-chgpw-form';
end;

function TKXChangePasswordController.GetFormAction: string;
begin
  Result := 'kx/changepassword';
end;

function TKXChangePasswordController.GetFormTarget: string;
begin
  Result := '#kx-chgpw-status';
end;

function TKXChangePasswordController.RenderFormBody: string;
var
  LOldPwLabel, LNewPwLabel, LConfirmPwLabel: string;
  LLabelStyleAttr: string;
  LLabelWidth: Integer;
begin
  LOldPwLabel := _('Old Password');
  LNewPwLabel := _('New Password');
  LConfirmPwLabel := _('Confirm New Password');
  LLabelWidth := Config.GetInteger('LabelWidth', 100);
  LLabelStyleAttr := Format(' style="min-width: %dpx; width: %0:dpx;"', [LLabelWidth]);

  Result :=
    '<div class="kx-rp-fields">' +
      '<div class="kx-login-field-row">' +
        '<label class="kx-login-field-label" for="kx-chgpw-old"' +
          LLabelStyleAttr + '>' +
          TNetEncoding.HTML.Encode(LOldPwLabel) + '</label>' +
        '<input type="password" id="kx-chgpw-old" name="OldPassword" ' +
          'class="kx-login-field-input" autocomplete="current-password" required>' +
      '</div>' +
      '<div class="kx-login-field-row">' +
        '<label class="kx-login-field-label" for="kx-chgpw-new"' +
          LLabelStyleAttr + '>' +
          TNetEncoding.HTML.Encode(LNewPwLabel) + '</label>' +
        '<input type="password" id="kx-chgpw-new" name="NewPassword" ' +
          'class="kx-login-field-input" autocomplete="new-password" required>' +
      '</div>' +
      '<div class="kx-login-field-row">' +
        '<label class="kx-login-field-label" for="kx-chgpw-confirm"' +
          LLabelStyleAttr + '>' +
          TNetEncoding.HTML.Encode(LConfirmPwLabel) + '</label>' +
        '<input type="password" id="kx-chgpw-confirm" name="ConfirmNewPassword" ' +
          'class="kx-login-field-input" autocomplete="new-password" required>' +
      '</div>' +
    '</div>';
end;

function TKXChangePasswordController.RenderFormButtons: string;
var
  LConfirmLabel, LChangingLabel, LConfirmIconHtml: string;
begin
  LConfirmLabel := _('Change password');
  LChangingLabel := _('Changing password...');
  LConfirmIconHtml := GetIconHTML('password', isLarge, 'kx-rp-button-icon');

  Result :=
    '<div id="kx-chgpw-status" class="kx-login-status">' +
      '<div class="kx-login-indicator htmx-indicator">' +
        '<span class="kx-login-spinner"></span>' +
        TNetEncoding.HTML.Encode(LChangingLabel) +
      '</div>' +
    '</div>' +
    '<button type="submit" class="kx-login-button" id="kx-chgpw-btn" disabled>' +
      LConfirmIconHtml +
      TNetEncoding.HTML.Encode(LConfirmLabel) +
    '</button>';
end;

function TKXChangePasswordController.RenderFormScript: string;
begin
  Result :=
    '(function() {' +
    '  var oldEl = document.getElementById("kx-chgpw-old");' +
    '  var newEl = document.getElementById("kx-chgpw-new");' +
    '  var confEl = document.getElementById("kx-chgpw-confirm");' +
    '  var btnEl = document.getElementById("kx-chgpw-btn");' +
    '  function updateBtn() {' +
    '    btnEl.disabled = (oldEl.value === "" || newEl.value === "" || ' +
    '      newEl.value !== confEl.value);' +
    '  }' +
    '  oldEl.addEventListener("input", updateBtn);' +
    '  newEl.addEventListener("input", updateBtn);' +
    '  confEl.addEventListener("input", updateBtn);' +
    '  updateBtn();' +
    '  oldEl.focus();' +
    '})();';
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('ChangePassword', TKXChangePasswordController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('ChangePassword');

end.
