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
///   TKWebRoute descendant that plugs the attribute-based router into the
///   existing KittoX route chain. Inserted BEFORE TKWebApplication so that
///   attribute-routed handlers get first crack; unmatched requests fall
///   through to the legacy DoHandleRequest.
/// </summary>
unit Kitto.Web.Routing.Route;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Web.Routes,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Web.URL;

type
  TKXRoutingRoute = class(TKWebRoute)
  private
    FAppPath: string;
    FApplication: TObject; // TKWebApplication — stored as TObject to avoid circular uses
  protected
    function DoHandleRequest(const ARequest: TKWebRequest;
      const AResponse: TKWebResponse; const AURL: TKWebURL): Boolean; override;
  public
    constructor Create(const AAppPath: string; AApplication: TObject);
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  {$IFDEF DEBUG}
  Winapi.Windows,
  {$ENDIF}
  EF.Logger,
  Kitto.Web.Application,
  Kitto.Web.Routing.Injection,
  Kitto.Web.Routing.Registry,
  Kitto.Web.Routing.Activation;

{ TKXRoutingRoute }

constructor TKXRoutingRoute.Create(const AAppPath: string; AApplication: TObject);
begin
  inherited Create;
  FAppPath := AAppPath;
  FApplication := AApplication;
end;

function TKXRoutingRoute.DoHandleRequest(const ARequest: TKWebRequest;
  const AResponse: TKWebResponse; const AURL: TKWebURL): Boolean;
var
  LActivation: IKXActivationContext;
  LActivationObj: TKXActivation;
begin
  Result := False;

  // Create activation as interface — ref counting handles lifetime (like MARS)
  LActivationObj := TKXActivation.Create(AURL, FAppPath, ARequest.Method);
  LActivation := LActivationObj; // ref count = 1

  TEFLogger.Instance.Log('KXRouting: ' + ARequest.Method + ' Path="' +
    AURL.Path + '" Doc="' + AURL.Document +
    '" AppPath="' + FAppPath +
    '" resources=' + IntToStr(TKXResourceRegistry.Instance.Resources.Count), TEFLogger.LOG_DEBUG);

  if LActivationObj.TryMatch then
  begin
    // Activate thread-local context (Authenticator, AccessController, Macros)
    // same as TKWebApplication.DoHandleRequest does before its handlers.
    TKWebApplication(FApplication).ActivateInstance;
    try
      LActivationObj.Invoke;
      Result := True;
    finally
      TKWebApplication(FApplication).DeactivateInstance;
    end;
  end;
  // LActivation goes out of scope → ref count = 0 → auto-freed
end;

end.
