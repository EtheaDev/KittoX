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
///  KittoX theme switcher controller. Renders a 3-button toggle group
///  (Light / Auto / Dark) that lets the end user override the configured
///  theme. The choice is persisted in localStorage per KittoX AppName via
///  the companion kxtheme.js module; an inline boot script emitted by
///  TKWebApplication applies the saved value before the CSS paints, so
///  the page never flashes the wrong theme.
///
///  The switcher renders only when Config.yaml declares
///    Theme: Auto
///      UserSelection: True
///  With Theme: Light/Dark explicit, the admin has fixed the theme and
///  this controller emits nothing (no surprising client-side override).
///
///  Drop in any layout via YAML:
///    Controller: ThemeSwitcher
///  Typical placements: Login view (BorderPanel SouthView), Home dashboard
///  near the auth panel, or a topbar slot.
/// </summary>
unit Kitto.Html.ThemeSwitcher;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.Base,
  Kitto.Html.Controller;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXThemeSwitcherController = class(TKXComponent, IKXController)
  public
    /// <summary>Renders the Light/Auto/Dark theme switcher control.</summary>
    function Render: string; override;
  end;

implementation

uses
  System.SysUtils,
  System.NetEncoding,
  EF.Localization,
  EF.Tree,
  Kitto.Config,
  Kitto.Metadata.SubNodes,
  Kitto.Web.Routing.Scripts;

{ TKXThemeSwitcherController }

function TKXThemeSwitcherController.Render: string;
var
  LAppName, LHtmlId: string;
  LJsEscApp: string;
begin
  // Gate: render only when the server-side Theme allows the user to switch
  // (Mode=Auto + UserSelection=True). All the Theme-node reading is
  // encapsulated in TKThemeConfig — with Light/Dark fixed, nothing to switch.
  if not TKThemeConfig.IsUserSelectionEnabled(
       TKConfig.Instance.Config.FindNode('Theme')) then
    Exit('');

  LAppName := TKConfig.AppName;
  // JS string-literal escape (single quotes used in the onclick handler).
  LJsEscApp := StringReplace(LAppName, '''', '\''', [rfReplaceAll]);
  LHtmlId := GetHtmlId;

  // Three-button toggle group. The icons are inline SVGs from the Material
  // set so we don't need to depend on the runtime icon style preference.
  // The buttons call kxTheme.set(...) which writes localStorage and
  // updates the html[data-theme] attribute; the kx-theme-changed event
  // (dispatched on window) lets the active-state CSS class react.
  Result :=
    '<div id="' + LHtmlId + '" class="kx-theme-switcher" role="group" aria-label="' +
      TNetEncoding.HTML.Encode(_('Theme')) + '">' +
      '<button type="button" class="kx-theme-btn" data-theme-value="light" ' +
        'title="' + TNetEncoding.HTML.Encode(_('Light')) + '" ' +
        'onclick="kxTheme.set(''' + LJsEscApp + ''',''light'')">' +
        '<svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true">' +
          '<path d="M12 7a5 5 0 100 10 5 5 0 000-10zm0-5a1 1 0 011 1v2a1 1 0 11-2 0V3a1 1 0 011-1zm0' +
          ' 18a1 1 0 011 1v2a1 1 0 11-2 0v-2a1 1 0 011-1zM5.64 4.22l1.42 1.42a1 1 0 11-1.42 1.42L4.22' +
          ' 5.64a1 1 0 011.42-1.42zm12.72 12.72l1.42 1.42a1 1 0 11-1.42 1.42l-1.42-1.42a1 1 0 011.42-1.42zM2' +
          ' 12a1 1 0 011-1h2a1 1 0 110 2H3a1 1 0 01-1-1zm18 0a1 1 0 011-1h2a1 1 0 110 2h-2a1 1 0 01-1-1zM5.64 19.78a1 1 0 11-1.42-1.42l1.42-1.42a1 1 0 011.42 1.42l-1.42 1.42zm12.72-12.72a1 1 0 11-1.42-1.42l1.42-1.42a1 1 0 011.42 1.42l-1.42 1.42z"/>' +
        '</svg>' +
      '</button>' +
      '<button type="button" class="kx-theme-btn" data-theme-value="auto" ' +
        'title="' + TNetEncoding.HTML.Encode(_('Auto (follow OS preference)')) + '" ' +
        'onclick="kxTheme.set(''' + LJsEscApp + ''',''auto'')">' +
        '<svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true">' +
          '<path d="M12 3a9 9 0 100 18 9 9 0 000-18zm0 16V5a7 7 0 010 14z"/>' +
        '</svg>' +
      '</button>' +
      '<button type="button" class="kx-theme-btn" data-theme-value="dark" ' +
        'title="' + TNetEncoding.HTML.Encode(_('Dark')) + '" ' +
        'onclick="kxTheme.set(''' + LJsEscApp + ''',''dark'')">' +
        '<svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden="true">' +
          '<path d="M21 12.79A9 9 0 1111.21 3 7 7 0 0021 12.79z"/>' +
        '</svg>' +
      '</button>' +
    '</div>' +
    // Sync the active state on load and on theme change.
    '<script>(function(){' +
      'function sync(){' +
        'var mode=window.kxTheme?window.kxTheme.get(' + AnsiQuotedStr(LAppName, '''') + '):' + '''auto'';' +
        'var root=document.getElementById(' + AnsiQuotedStr(LHtmlId, '''') + ');' +
        'if(!root)return;' +
        'root.querySelectorAll(''.kx-theme-btn'').forEach(function(b){' +
          'b.classList.toggle(''kx-theme-btn-active'',b.dataset.themeValue===mode);' +
        '});' +
      '}' +
      'sync();' +
      'window.addEventListener(''kx-theme-changed'',sync);' +
    '})();</script>';
end;

initialization
  TKXScriptRegistry.Instance.RegisterScript('/js/kxtheme.js');
  TKXControllerRegistry.Instance.RegisterClass('ThemeSwitcher', TKXThemeSwitcherController);

end.
