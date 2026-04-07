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
///  Base form controller for non-data-aware modal forms (ResetPassword,
///  ChangePassword, etc.). Provides a standard form wrapper with toolbar,
///  body, and buttons. AllowClose defaults to True (modal dialog).
///  Data-aware forms use TKXFormPanelController (Kitto.Html.Form) instead.
/// </summary>
unit Kitto.Html.FormController;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.Panel;

type
  /// <summary>
  ///  Abstract base class for non-data-aware form controllers.
  ///  Subclasses implement RenderFormBody (required) and optionally
  ///  override RenderFormButtons, RenderFormToolbar, GetFormId,
  ///  GetFormAction, GetFormTarget, and RenderFormScript.
  ///  AllowClose defaults to True so these forms render as modal dialogs.
  /// </summary>
  TKXFormController = class abstract(TKXPanelControllerBase)
  strict protected
    function GetDefaultIsModal: Boolean; override;

    /// <summary>
    ///  Returns the inner HTML content of the form body. Required.
    /// </summary>
    function RenderFormBody: string; virtual; abstract;

    /// <summary>
    ///  Returns HTML for the button bar below the form body.
    ///  Default returns empty string.
    /// </summary>
    function RenderFormButtons: string; virtual;

    /// <summary>
    ///  Returns HTML for a toolbar above the form body.
    ///  Default returns empty string.
    /// </summary>
    function RenderFormToolbar: string; virtual;

    /// <summary>
    ///  Returns the form element id. If non-empty, RenderContent wraps
    ///  everything in a &lt;form&gt; tag. Default returns empty string.
    /// </summary>
    function GetFormId: string; virtual;

    /// <summary>
    ///  Returns the hx-post URL for the form. Default returns empty string.
    /// </summary>
    function GetFormAction: string; virtual;

    /// <summary>
    ///  Returns the hx-target selector for the form. Default returns empty string.
    /// </summary>
    function GetFormTarget: string; virtual;

    /// <summary>
    ///  Returns inline JavaScript to execute after rendering.
    ///  Default returns empty string.
    /// </summary>
    function RenderFormScript: string; virtual;

    /// <summary>
    ///  Assembles toolbar + body + buttons, optionally wrapped in a form tag.
    /// </summary>
    function RenderContent: string; override;
  end;

implementation

uses
  System.SysUtils;

{ TKXFormController }

function TKXFormController.GetDefaultIsModal: Boolean;
begin
  Result := True;
end;

function TKXFormController.RenderFormButtons: string;
begin
  Result := '';
end;

function TKXFormController.RenderFormToolbar: string;
begin
  Result := '';
end;

function TKXFormController.GetFormId: string;
begin
  Result := '';
end;

function TKXFormController.GetFormAction: string;
begin
  Result := '';
end;

function TKXFormController.GetFormTarget: string;
begin
  Result := '';
end;

function TKXFormController.RenderFormScript: string;
begin
  Result := '';
end;

function TKXFormController.RenderContent: string;
var
  LToolbar, LBody, LButtons, LFormId, LScript: string;
begin
  LToolbar := RenderFormToolbar;
  LBody := '<div class="kx-form-body">' + RenderFormBody + '</div>';
  LButtons := RenderFormButtons;
  if LButtons <> '' then
    LButtons := '<div class="kx-form-toolbar">' + LButtons + '</div>';

  LFormId := GetFormId;
  if LFormId <> '' then
  begin
    Result := '<form id="' + LFormId + '" class="kx-form-panel"'
      + ' hx-post="' + GetFormAction + '"'
      + ' hx-target="' + GetFormTarget + '"'
      + ' hx-swap="innerHTML"'
      + ' onkeydown="if(event.key===''Escape''){event.preventDefault();'
      +   'this.closest(''.kx-dialog-overlay'').remove();}">'
      + LToolbar + LBody + LButtons
      + '</form>';
  end
  else
    Result := LToolbar + LBody + LButtons;

  LScript := RenderFormScript;
  if LScript <> '' then
    Result := Result + '<script>' + LScript + '</script>';
end;

end.
