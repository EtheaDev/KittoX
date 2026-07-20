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
///   Dependency injection registry for [TKXContext] parameters.
///   Maps type info to provider functions that resolve values from the
///   current activation context (session, config, request, etc.).
/// </summary>
unit Kitto.Web.Routing.Injection;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Rtti,
  System.TypInfo;

type
  /// <summary>
  ///   Interface for the activation context, used by injection providers
  ///   to access path parameters and other request state.
  ///   Implemented by TKXActivation (Kitto.Web.Routing.Activation).
  /// </summary>
  IKXActivationContext = interface
    ['{F3A2B7C4-8D1E-4F5A-9C6B-2E7D8A3F1B5C}']
    /// <summary>Returns the captured value of the named path parameter ('' if absent).</summary>
    function GetPathParam(const AName: string): string;
  end;

  /// <summary>
  ///   Provider function that resolves a value for a [TKXContext] parameter.
  ///   Receives the RTTI type and the activation context interface.
  ///   Returns TValue.Empty if unable to provide.
  /// </summary>
  TKXInjectionProvider = reference to function(
    const AType: TRttiType;
    const AActivation: IKXActivationContext): TValue;

  /// <summary>
  ///   Singleton registry of injection providers, keyed by PTypeInfo.
  ///   Providers are registered at startup and queried per-request during
  ///   parameter filling. Extensible by applications.
  /// </summary>
  TKXInjectionRegistry = class
  private
    FProviders: TDictionary<PTypeInfo, TKXInjectionProvider>;
    class var FInstance: TKXInjectionRegistry;
    class function GetInstance: TKXInjectionRegistry; static;
  public
    /// <summary>Creates the registry with an empty provider map.</summary>
    constructor Create;
    /// <summary>Frees the provider map.</summary>
    destructor Destroy; override;
    /// <summary>Frees the singleton instance at unit finalization.</summary>
    class destructor DestroyClass;
    /// <summary>The lazily-created singleton registry instance.</summary>
    class property Instance: TKXInjectionRegistry read GetInstance;

    /// <summary>
    ///   Registers a provider for a specific type. If a provider for the
    ///   same type already exists, it is replaced (allowing overrides).
    /// </summary>
    procedure RegisterProvider(const ATypeInfo: PTypeInfo;
      const AProvider: TKXInjectionProvider);

    /// <summary>
    ///   Resolves a value for the given RTTI type using the registered provider.
    ///   Returns TValue.Empty if no provider is registered for the type.
    /// </summary>
    function Resolve(const AType: TRttiType;
      const AActivation: IKXActivationContext): TValue;
  end;

implementation

{ TKXInjectionRegistry }

constructor TKXInjectionRegistry.Create;
begin
  inherited;
  FProviders := TDictionary<PTypeInfo, TKXInjectionProvider>.Create;
end;

destructor TKXInjectionRegistry.Destroy;
begin
  FreeAndNil(FProviders);
  inherited;
end;

class destructor TKXInjectionRegistry.DestroyClass;
begin
  FreeAndNil(FInstance);
end;

class function TKXInjectionRegistry.GetInstance: TKXInjectionRegistry;
begin
  if not Assigned(FInstance) then
    FInstance := TKXInjectionRegistry.Create;
  Result := FInstance;
end;

procedure TKXInjectionRegistry.RegisterProvider(const ATypeInfo: PTypeInfo;
  const AProvider: TKXInjectionProvider);
begin
  FProviders.AddOrSetValue(ATypeInfo, AProvider);
end;

function TKXInjectionRegistry.Resolve(const AType: TRttiType;
  const AActivation: IKXActivationContext): TValue;
var
  LProvider: TKXInjectionProvider;
begin
  if Assigned(AType) and FProviders.TryGetValue(AType.Handle, LProvider) then
    Result := LProvider(AType, AActivation)
  else
    Result := TValue.Empty;
end;

end.
