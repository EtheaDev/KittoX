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
///	  This unit defines a Kitto-specific localization interface to the open
///	  source translation tool dxgettext (GNU gettext for Delphi). It plugs into
///	  Ethea Foundation's localization architecture to allow Kitto applications
///	  to be localized by means of dxgettext.
///	</summary>
unit Kitto.Localization.dxgettext;

{$I Kitto.Defines.inc}

interface

uses
  System.Classes,
  EF.Intf,
  EF.Localization;

type
  ///	<summary>
  ///	  Localization tool that wraps dxgettext with Kitto-specific behaviour.
  ///	</summary>
  TKdxgettextLocalizationTool = class(TEFNoRefCountObject, IInterface,
    IEFInterface, IEFLocalizationTool)
  private
    const KITTO_TEXT_DOMAIN = 'Kitto';
  private
    FTextDomainBound: Boolean;
    procedure EnsureTextDomainBound;
  public
    /// <summary>Returns the tool as a TObject (IEFInterface support).</summary>
    function AsObject: TObject;
    /// <summary>Translates AString via dxgettext; AIdString optionally disambiguates identical texts.</summary>
    function TranslateString(const AString: string;
      const AIdString: string = ''): string;
    /// <summary>Translates all localizable properties of the given component and its children.</summary>
    procedure TranslateComponent(const AComponent: TComponent);
    /// <summary>Forces the active translation language to the given language id.</summary>
    procedure ForceLanguage(const ALanguageId: string);
    /// <summary>Returns the id of the language currently in use.</summary>
    function GetCurrentLanguageId: string;
    procedure AfterConstruction; override;
  end;

implementation

uses
  Kitto.gnugettext,
  Kitto.Config,
  EF.Logger;

{ TKdxgettextLocalizationTool }

procedure TKdxgettextLocalizationTool.AfterConstruction;
begin
  inherited;
  FTextDomainBound := False;
end;

function TKdxgettextLocalizationTool.AsObject: TObject;
begin
  Result := Self;
end;

procedure TKdxgettextLocalizationTool.ForceLanguage(const ALanguageId: string);
begin
  Kitto.gnugettext.UseLanguage(ALanguageId);
end;

function TKdxgettextLocalizationTool.GetCurrentLanguageId: string;
begin
  Result := Kitto.gnugettext.GetCurrentLanguage;
end;

procedure TKdxgettextLocalizationTool.TranslateComponent(const AComponent: TComponent);
begin
  EnsureTextDomainBound;
  Kitto.gnugettext.TranslateComponent(AComponent, KITTO_TEXT_DOMAIN);
  Kitto.gnugettext.TranslateComponent(AComponent, 'default');
end;

function TKdxgettextLocalizationTool.TranslateString(const AString,
  AIdString: string): string;
begin
  EnsureTextDomainBound;
  // Look in the Kitto text domain first, then in the application domain.
  Result := Kitto.gnugettext.dgettext(KITTO_TEXT_DOMAIN, AString);
  if Result = AString then
    Result := Kitto.gnugettext.dgettext('default', AString);
end;

procedure TKdxgettextLocalizationTool.EnsureTextDomainBound;
begin
  if not FTextDomainBound then
  begin
    Kitto.gnugettext.bindtextdomain(KITTO_TEXT_DOMAIN, TKConfig.Instance.SystemHomePath + 'locale');
    FTextDomainBound := True;
  end;
end;

// A problem of the translation catalogs used to be a MessageBox inside
// Kitto.gnugettext (see the ETHEA PATCH there): in a service or an ISAPI that is a
// process that stops and waits for a click nobody can give. It is a log line
// now - and a loud one, because "translations are turned off" is not a detail.
procedure LogLocalizationProblem(const AMessage, ATitle: string);
begin
  TEFLogger.Instance.LogHigh(ATitle + ': ' + AMessage);
end;

initialization
  Kitto.gnugettext.GnuGettextOnProblem := LogLocalizationProblem;
  TEFLocalizationToolRegistry.RegisterTool(TKdxgettextLocalizationTool.Create);

finalization
  TEFLocalizationToolRegistry.UnregisterTool;

end.
