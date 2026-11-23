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
///  KittoX language switcher controller. Renders a flag dropdown that lets the
///  end user change the interface language. Modeled on the ThemeSwitcher: it is
///  a controller dropped into a layout region via YAML (Controller:
///  LanguageSwitcher) and appears identically on the Login view and the Home
///  page.
///
///  Unlike the theme (a pure client-side, no-reload preference), the language is
///  a server-side per-session setting driven by gettext, so switching posts to
///  the anonymous endpoint /kx/setlang/{Lang} (TKXSetLangHandler) and reloads
///  the current page in the chosen language.
///
///  The list of offered languages is DISCOVERED, not configured: a language is
///  offered when &lt;AppHome&gt;\Locale\&lt;code&gt;\LC_MESSAGES holds at least one
///  COMPILED catalog (*.mo), plus English (the source language, which needs no
///  catalog). Two rules matter here:
///
///  - the folder must really carry a .mo. A bare folder, or one holding only
///    .po sources, translates nothing: offering it would let the user pick a
///    language and see the page unchanged.
///  - only &lt;AppHome&gt; counts. &lt;SystemHome&gt;\Locale is NOT scanned, because
///    KittoX ships framework catalogs (Kitto.mo) for de/es/it/pt and offering a
///    language on their strength alone yields a half-translated UI: framework
///    chrome translated, every application label still in the source language.
///
///  Each language id is mapped to a native display name and an ISO country code
///  for the flag SVG under Resources\flags. Adding a language is therefore a
///  matter of dropping the application's compiled catalog in place.
///
///  Renders only when Config.yaml has LanguagePerSession: True and at least two
///  languages are available; otherwise it emits nothing.
///
///  Drop in any layout via YAML:
///    Controller: LanguageSwitcher
/// </summary>
unit Kitto.Html.LanguageSwitcher;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.Base,
  Kitto.Html.Controller;

type
  /// <summary>Descriptor of a selectable interface language: the gettext id
  /// (e.g. 'it'), the native display name ('Italiano') and the ISO 3166 country
  /// code used to pick the flag SVG ('it').</summary>
  TKXLanguageInfo = record
    Code: string;
    NativeName: string;
    CountryCode: string;
  end;

  /// <summary>Shared helper: discovers the available interface languages from
  /// the Locale folders and maps each id to a native name and a flag. Used both
  /// by the switcher controller (to render options) and by the setlang endpoint
  /// (to validate the requested language).</summary>
  TKXLanguageCatalog = class
  public
    /// <summary>Returns the gettext ids of the languages offered by this
    /// application: English plus every language that has a compiled catalog
    /// under AppHome\Locale, restricted to the codes listed in the Config node
    /// Languages (comma-separated) when it is set. Ordered by a preferred list
    /// then alphabetically. Never empty: when the restriction leaves nothing,
    /// English stays.</summary>
    class function AvailableCodes: TArray<string>;
    /// <summary>True when ACode is one of the AvailableCodes (case-insensitive,
    /// region-normalized). Used to validate the setlang request.</summary>
    class function IsAvailable(const ACode: string): Boolean;
    /// <summary>Reduces a session language id ('it_IT', 'pt-BR') to its base
    /// two-letter id ('it', 'pt'), lowercased. Empty maps to 'en'.</summary>
    class function NormalizeCode(const ALanguageId: string): string;
    /// <summary>Native name + flag country code for a language id. Unknown ids
    /// fall back to the uppercased code as name and the code itself as flag.</summary>
    class function InfoFor(const ACode: string): TKXLanguageInfo;
    /// <summary>Renders the flag-dropdown HTML using AHtmlId as the root element
    /// id. Returns '' when LanguagePerSession is off or fewer than two languages
    /// are available. Shared by the LanguageSwitcher controller (Home page) and
    /// by the login form, which embeds it as a labelled field row.</summary>
    class function RenderSwitcherHtml(const AHtmlId: string): string;
  end;

  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  /// <summary>
  ///  Controller that renders the flag language dropdown. Emits markup only when
  ///  LanguagePerSession is enabled and more than one language is available.
  ///  Registered as controller type 'LanguageSwitcher'.
  /// </summary>
  TKXLanguageSwitcherController = class(TKXComponent, IKXController)
  public
    /// <summary>Renders the flag language dropdown control.</summary>
    function Render: string; override;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.IOUtils,
  System.Types,
  System.NetEncoding,
  EF.Localization,
  Kitto.Config,
  Kitto.Web.Application,
  Kitto.Web.Session,
  Kitto.Web.Routing.Scripts;

{ TKXLanguageCatalog }

// Preferred display order; anything else follows alphabetically.
const
  PREFERRED_ORDER: array[0..5] of string = ('en', 'it', 'de', 'es', 'fr', 'pt');

class function TKXLanguageCatalog.InfoFor(const ACode: string): TKXLanguageInfo;
begin
  Result.Code := ACode;
  // Native names (endonyms) + ISO 3166 country code for the flag SVG.
  if SameText(ACode, 'en') then
  begin
    Result.NativeName := 'English';       Result.CountryCode := 'gb';
  end
  else if SameText(ACode, 'it') then
  begin
    Result.NativeName := 'Italiano';      Result.CountryCode := 'it';
  end
  else if SameText(ACode, 'de') then
  begin
    Result.NativeName := 'Deutsch';       Result.CountryCode := 'de';
  end
  else if SameText(ACode, 'es') then
  begin
    Result.NativeName := 'Español';       Result.CountryCode := 'es';
  end
  else if SameText(ACode, 'pt') then
  begin
    Result.NativeName := 'Português';     Result.CountryCode := 'pt';
  end
  else if SameText(ACode, 'fr') then
  begin
    Result.NativeName := 'Français';      Result.CountryCode := 'fr';
  end
  else
  begin
    // Unknown language: best effort. Name = uppercased code, flag = code
    // (works when the id happens to match a country, otherwise no flag shows).
    Result.NativeName := UpperCase(ACode);
    Result.CountryCode := LowerCase(ACode);
  end;
end;

class function TKXLanguageCatalog.NormalizeCode(const ALanguageId: string): string;
var
  I: Integer;
begin
  Result := LowerCase(Trim(ALanguageId));
  if Result = '' then
    Exit('en');
  // Strip region suffix: 'it_IT' / 'pt-BR' -> 'it' / 'pt'.
  I := 1;
  while (I <= Length(Result)) and CharInSet(Result[I], ['a'..'z']) do
    Inc(I);
  Result := Copy(Result, 1, I - 1);
  if Result = '' then
    Result := 'en';
end;

class function TKXLanguageCatalog.AvailableCodes: TArray<string>;
var
  LFound: TStringList;

  /// <summary>True when ALangDir actually carries a compiled gettext catalog
  /// (LC_MESSAGES\*.mo). A bare language folder — or one holding only .po
  /// sources — translates nothing, so it must not add an entry to the
  /// switcher: the user would pick a language and see no change.</summary>
  function HasCompiledCatalog(const ALangDir: string): Boolean;
  var
    LMessagesDir: string;
  begin
    LMessagesDir := TPath.Combine(ALangDir, 'LC_MESSAGES');
    Result := TDirectory.Exists(LMessagesDir) and
      (Length(TDirectory.GetFiles(LMessagesDir, '*.mo')) > 0);
  end;

  procedure ScanLocaleDir(const ABaseHome: string);
  var
    LLocaleDir, LSub, LCode: string;
    LDirs: TStringDynArray;
  begin
    if ABaseHome = '' then
      Exit;
    LLocaleDir := TPath.Combine(ABaseHome, 'Locale');
    if not TDirectory.Exists(LLocaleDir) then
      Exit;
    LDirs := TDirectory.GetDirectories(LLocaleDir);
    for LSub in LDirs do
    begin
      LCode := TKXLanguageCatalog.NormalizeCode(ExtractFileName(ExcludeTrailingPathDelimiter(LSub)));
      if (LCode <> '') and HasCompiledCatalog(LSub) and (LFound.IndexOf(LCode) < 0) then
        LFound.Add(LCode);
    end;
  end;

var
  I: Integer;
  LOrdered, LAllowedList: TStringList;
  LCode, LAllowed: string;
begin
  LFound := TStringList.Create;
  try
    LFound.CaseSensitive := False;
    // English is always offered (source language, no catalog needed).
    LFound.Add('en');
    // Only the APPLICATION's catalogs decide which languages are offered.
    // SystemHome is deliberately NOT scanned: KittoX ships framework catalogs
    // (Kitto.mo) for de/es/it/pt, and offering a language on their strength
    // alone produced a half-translated UI — framework chrome translated,
    // every application label still in the source language. A language is
    // usable only when the application itself ships a catalog for it.
    ScanLocaleDir(TKConfig.AppHomePath);

    // Languages: it, de — the application names the languages it offers. English
    // is the source language of the framework, not necessarily of the
    // application: an app whose labels are written in Italian would otherwise
    // offer an "English" that shows Italian labels under English chrome.
    LAllowed := TKConfig.Instance.Config.GetString('Languages');
    if Trim(LAllowed) <> '' then
    begin
      LAllowedList := TStringList.Create;
      try
        LAllowedList.CaseSensitive := False;
        for LCode in LAllowed.Split([',', ';', ' '], TStringSplitOptions.ExcludeEmpty) do
          LAllowedList.Add(TKXLanguageCatalog.NormalizeCode(LCode));
        for I := LFound.Count - 1 downto 0 do
          if LAllowedList.IndexOf(LFound[I]) < 0 then
            LFound.Delete(I);
        if LFound.Count = 0 then
          LFound.Add('en');
      finally
        LAllowedList.Free;
      end;
    end;

    // Emit in the preferred order first, then any remaining alphabetically.
    LOrdered := TStringList.Create;
    try
      for I := Low(PREFERRED_ORDER) to High(PREFERRED_ORDER) do
        if LFound.IndexOf(PREFERRED_ORDER[I]) >= 0 then
          LOrdered.Add(PREFERRED_ORDER[I]);
      LFound.Sort;
      for LCode in LFound do
        if LOrdered.IndexOf(LCode) < 0 then
          LOrdered.Add(LCode);
      Result := LOrdered.ToStringArray;
    finally
      LOrdered.Free;
    end;
  finally
    LFound.Free;
  end;
end;

class function TKXLanguageCatalog.IsAvailable(const ACode: string): Boolean;
var
  LNorm, LCode: string;
begin
  LNorm := NormalizeCode(ACode);
  for LCode in AvailableCodes do
    if SameText(LCode, LNorm) then
      Exit(True);
  Result := False;
end;

{ TKXLanguageCatalog.RenderSwitcherHtml }

class function TKXLanguageCatalog.RenderSwitcherHtml(const AHtmlId: string): string;
var
  LCodes: TArray<string>;
  LCurrent: string;
  LCurInfo, LInfo: TKXLanguageInfo;
  LCode, LOptions, LCurFlag: string;

  function FlagImg(const AInfo: TKXLanguageInfo; const ACssClass: string): string;
  var
    LUrl: string;
  begin
    LUrl := TKWebApplication.Current.FindResourceURL('flags/' + AInfo.CountryCode + '.svg');
    if LUrl <> '' then
      Result := '<img class="' + ACssClass + '" src="' + TNetEncoding.HTML.Encode(LUrl) +
        '" alt="" aria-hidden="true">'
    else
      Result := '';
  end;

begin
  // Gate: honor the same switch that already governs the login language combo.
  if not TKWebApplication.Current.Config.LanguagePerSession then
    Exit('');

  LCodes := AvailableCodes;
  // Nothing to switch between: don't render a one-item dropdown.
  if Length(LCodes) < 2 then
    Exit('');

  LCurrent := NormalizeCode(TKWebSession.Current.Language);
  LCurInfo := InfoFor(LCurrent);

  LOptions := '';
  for LCode in LCodes do
  begin
    LInfo := TKXLanguageCatalog.InfoFor(LCode);
    LOptions := LOptions +
      '<li role="none">' +
        '<button type="button" role="menuitemradio" class="kx-lang-opt' +
          IfThen(SameText(LCode, LCurrent), ' kx-lang-opt-active', '') + '"' +
          ' aria-checked="' + IfThen(SameText(LCode, LCurrent), 'true', 'false') + '"' +
          ' onclick="kxLang.set(''' + LCode + ''')">' +
          FlagImg(LInfo, 'kx-lang-flag') +
          '<span class="kx-lang-name">' + TNetEncoding.HTML.Encode(LInfo.NativeName) + '</span>' +
        '</button>' +
      '</li>';
  end;

  LCurFlag := FlagImg(LCurInfo, 'kx-lang-flag');

  // Native <details>/<summary> gives free open/close with no toggle JS; the
  // menu is absolutely positioned by the CSS so it can pop over a short band.
  Result :=
    '<details id="' + AHtmlId + '" class="kx-lang-switcher">' +
      '<summary class="kx-lang-current" aria-haspopup="true" title="' +
        TNetEncoding.HTML.Encode(_('Language')) + '" aria-label="' +
        TNetEncoding.HTML.Encode(_('Language')) + '">' +
        LCurFlag +
        '<span class="kx-lang-name">' + TNetEncoding.HTML.Encode(LCurInfo.NativeName) + '</span>' +
        '<svg class="kx-lang-caret" viewBox="0 0 24 24" width="16" height="16" ' +
          'fill="currentColor" aria-hidden="true"><path d="M7 10l5 5 5-5z"/></svg>' +
      '</summary>' +
      '<ul class="kx-lang-menu" role="menu">' + LOptions + '</ul>' +
    '</details>';
end;

{ TKXLanguageSwitcherController }

function TKXLanguageSwitcherController.Render: string;
begin
  Result := TKXLanguageCatalog.RenderSwitcherHtml(GetHtmlId);
end;

initialization
  TKXScriptRegistry.Instance.RegisterScript('/js/kxlang.js');
  TKXControllerRegistry.Instance.RegisterClass('LanguageSwitcher', TKXLanguageSwitcherController);

end.
