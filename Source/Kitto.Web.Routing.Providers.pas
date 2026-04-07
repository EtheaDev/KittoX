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
///   Registers the default injection providers for [TKXContext] parameters.
///   Include this unit in the application to enable standard context injection
///   (Request, Response, Session, Config, Authenticator, ViewTable).
/// </summary>
unit Kitto.Web.Routing.Providers;

{$I Kitto.Defines.inc}

interface

implementation

uses
  System.SysUtils,
  System.Rtti,
  System.TypInfo,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Html.Response,
  Kitto.Web.Session,
  Kitto.Config,
  Kitto.Auth,
  Kitto.Metadata.Views,
  Kitto.Metadata.DataView,
  Kitto.Web.Routing.Injection;

procedure RegisterProviders;
begin
  // TKWebRequest — current thread-local request
  TKXInjectionRegistry.Instance.RegisterProvider(TypeInfo(TKWebRequest),
    function(const AType: TRttiType; const AActivation: IKXActivationContext): TValue
    begin
      Result := TValue.From<TKWebRequest>(TKWebRequest.Current);
    end);

  // TKWebResponse — current thread-local response
  TKXInjectionRegistry.Instance.RegisterProvider(TypeInfo(TKWebResponse),
    function(const AType: TRttiType; const AActivation: IKXActivationContext): TValue
    begin
      Result := TValue.From<TKWebResponse>(TKWebResponse.Current);
    end);

  // TKXWebResponse — KittoX extended response
  TKXInjectionRegistry.Instance.RegisterProvider(TypeInfo(TKXWebResponse),
    function(const AType: TRttiType; const AActivation: IKXActivationContext): TValue
    begin
      Result := TValue.From<TKXWebResponse>(TKXWebResponse.Current);
    end);

  // TKWebSession — current thread-local session
  TKXInjectionRegistry.Instance.RegisterProvider(TypeInfo(TKWebSession),
    function(const AType: TRttiType; const AActivation: IKXActivationContext): TValue
    begin
      Result := TValue.From<TKWebSession>(TKWebSession.Current);
    end);

  // TKConfig — application configuration
  TKXInjectionRegistry.Instance.RegisterProvider(TypeInfo(TKConfig),
    function(const AType: TRttiType; const AActivation: IKXActivationContext): TValue
    begin
      Result := TValue.From<TKConfig>(TKConfig.Instance);
    end);

  // TKAuthenticator — current thread-local authenticator
  TKXInjectionRegistry.Instance.RegisterProvider(TypeInfo(TKAuthenticator),
    function(const AType: TRttiType; const AActivation: IKXActivationContext): TValue
    begin
      Result := TValue.From<TKAuthenticator>(TKAuthenticator.Current);
    end);

  // TKDataView — resolved from ViewName path param
  TKXInjectionRegistry.Instance.RegisterProvider(TypeInfo(TKDataView),
    function(const AType: TRttiType; const AActivation: IKXActivationContext): TValue
    var
      LViewName: string;
      LView: TKView;
    begin
      LViewName := AActivation.GetPathParam('ViewName');
      if LViewName <> '' then
      begin
        LView := TKConfig.Instance.Views.FindView(LViewName);
        if Assigned(LView) and (LView is TKDataView) then
          Result := TValue.From<TKDataView>(TKDataView(LView))
        else
          Result := TValue.Empty;
      end
      else
        Result := TValue.Empty;
    end);

  // TKViewTable — resolved from ViewName path param (MainTable)
  TKXInjectionRegistry.Instance.RegisterProvider(TypeInfo(TKViewTable),
    function(const AType: TRttiType; const AActivation: IKXActivationContext): TValue
    var
      LViewName: string;
      LView: TKView;
    begin
      LViewName := AActivation.GetPathParam('ViewName');
      if LViewName <> '' then
      begin
        LView := TKConfig.Instance.Views.FindView(LViewName);
        if Assigned(LView) and (LView is TKDataView) then
          Result := TValue.From<TKViewTable>(TKDataView(LView).MainTable)
        else
          Result := TValue.Empty;
      end
      else
        Result := TValue.Empty;
    end);
end;

initialization
  RegisterProviders;

end.
