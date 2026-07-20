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
///   Request-filter middleware for the attribute-based router (Sprint E.1 of the
///   routing refactor). A filter wraps the dispatch of a request with
///   BeforeInvoke / AfterInvoke / OnException hooks, letting cross-cutting
///   concerns (JWT hydration, authorization gate, error handling) live outside
///   the individual handlers and outside TKWebApplication.DoHandleRequest.
///
///   This unit is intentionally dependency-free (no uses of Kitto.Web.Application
///   / Request / Response): it defines only the contracts, the mutable request
///   context data-holder, the global filter registry and the chain runner. The
///   concrete filters (which need the application/session/response) live in
///   Kitto.Web.Routing.AppFilters, to avoid a circular unit dependency.
///
///   The chain exposes two shapes because of a Delphi limitation: an anonymous
///   method cannot call the enclosing routine's nested functions. The legacy
///   TKWebApplication.DoHandleRequest dispatch is a big if/else built on ~24
///   nested IsKX*Request probes, so it uses the PHASED api (RunBefore /
///   HandleException / RunAfter) with the dispatch kept as inline code. The
///   attribute pipeline, whose dispatch is a single method call, uses the
///   convenience closure api Run().
/// </summary>
unit Kitto.Web.Routing.Filters;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  /// <summary>
  ///   Per-request context handed to every filter. The router populates it
  ///   before running the chain.
  ///   - AllowUnauthenticated: the request is exempt from the authentication
  ///     gate (login / reset / change / logout, the app root/home, or a view
  ///     declared public via ACName).
  ///   - AllowSessionLost: the request is exempt from the "session lost" fatal
  ///     check (the recovery endpoints only: home + login/reset/change).
  ///   These two differ intentionally: a public view is served without auth but
  ///   still raises on a lost session, matching the legacy behaviour.
  ///
  ///   A filter's BeforeInvoke may fully satisfy the request (e.g. the auth gate
  ///   writing a 404): it sets Handled := True, and the chain then skips the
  ///   dispatch and any remaining BeforeInvoke.
  /// </summary>
  IKXRequestContext = interface
    ['{6B1E0B2A-6C2E-4E4E-9E7B-4A9D5C3F1E20}']
    function GetPath: string;
    function GetHttpMethod: string;
    function GetAllowUnauthenticated: Boolean;
    function GetAllowSessionLost: Boolean;
    function GetAllowDirectNavigation: Boolean;
    function GetHandled: Boolean;
    procedure SetHandled(const AValue: Boolean);
    /// <summary>Request path (URL.Path), used for logging and gate decisions.</summary>
    property Path: string read GetPath;
    /// <summary>HTTP method of the request ('GET'/'POST'/…).</summary>
    property HttpMethod: string read GetHttpMethod;
    /// <summary>The endpoint may be served to a non-authenticated session
    /// (login/reset/change/logout, home, or a view public via ACName).</summary>
    property AllowUnauthenticated: Boolean read GetAllowUnauthenticated;
    /// <summary>The endpoint is exempt from the "session lost" fatal check
    /// (recovery endpoints only: home + login/reset/change).</summary>
    property AllowSessionLost: Boolean read GetAllowSessionLost;
    /// The matched endpoint may be reached by a top-level browser navigation
    /// (address bar / opened link / window.open) rather than only as an SPA
    /// sub-request. True for the home page, [TKXAnonymous] and [TKXNavigable]
    /// endpoints (e.g. blob downloads); False for the HTML-fragment endpoints,
    /// which the navigation guard bounces back to the app root.
    property AllowDirectNavigation: Boolean read GetAllowDirectNavigation;
    /// <summary>Set by a filter's BeforeInvoke to fully satisfy the request
    /// (e.g. a 404 or a redirect): the chain then skips dispatch and the
    /// remaining BeforeInvoke.</summary>
    property Handled: Boolean read GetHandled write SetHandled;
  end;

  /// <summary>
  ///   A request filter. Registered globally via TKXFilterRegistry and run by
  ///   TKXFilterChain around the request dispatch.
  /// </summary>
  IKXRequestFilter = interface
    ['{2F8C4D1A-9B3E-4A6D-8F2C-1D5E7A9B0C34}']
    /// Runs before dispatch (in registration order). May set AContext.Handled.
    procedure BeforeInvoke(const AContext: IKXRequestContext);
    /// Runs after dispatch (in reverse registration order), always, like a finally.
    procedure AfterInvoke(const AContext: IKXRequestContext);
    /// Given an exception escaping dispatch or a BeforeInvoke, returns True if it
    /// handled it (e.g. rendered an error dialog); False to let it propagate.
    function OnException(const AContext: IKXRequestContext; E: Exception): Boolean;
  end;

  /// <summary>Concrete, mutable request context populated by the router.</summary>
  TKXRequestContext = class(TInterfacedObject, IKXRequestContext)
  private
    FPath: string;
    FHttpMethod: string;
    FAllowUnauthenticated: Boolean;
    FAllowSessionLost: Boolean;
    FAllowDirectNavigation: Boolean;
    FHandled: Boolean;
  public
    /// <summary>Creates the context with the gate flags computed by the router
    /// (AllowDirectNavigation defaults True — the legacy home branch is navigable).</summary>
    constructor Create(const APath, AHttpMethod: string;
      const AAllowUnauthenticated, AAllowSessionLost: Boolean;
      const AAllowDirectNavigation: Boolean = True);
    function GetPath: string;
    function GetHttpMethod: string;
    function GetAllowUnauthenticated: Boolean;
    function GetAllowSessionLost: Boolean;
    function GetAllowDirectNavigation: Boolean;
    function GetHandled: Boolean;
    procedure SetHandled(const AValue: Boolean);
  end;

  /// <summary>
  ///   Global, ordered list of request filters. Populated at startup from unit
  ///   initialization sections. Registration order defines nesting: the first
  ///   registered filter is the OUTERMOST layer (its BeforeInvoke runs first and
  ///   its OnException runs last) — register the error handler first so it wraps
  ///   everything.
  /// </summary>
  TKXFilterRegistry = class
  private
    FFilters: TList<IKXRequestFilter>;
    class var FInstance: TKXFilterRegistry;
    class function GetInstance: TKXFilterRegistry; static;
  public
    /// <summary>Creates the registry with an empty filter list.</summary>
    constructor Create;
    /// <summary>Frees the filter list (the filter interfaces are ref-counted).</summary>
    destructor Destroy; override;
    /// <summary>Frees the singleton instance at unit finalization.</summary>
    class destructor DestroyClass;
    /// <summary>The lazily-created singleton registry instance.</summary>
    class property Instance: TKXFilterRegistry read GetInstance;

    /// <summary>Appends a filter; registration order defines nesting (first = outermost).</summary>
    procedure RegisterFilter(const AFilter: IKXRequestFilter);
    /// <summary>The registered filters, in registration (outermost-first) order.</summary>
    property Filters: TList<IKXRequestFilter> read FFilters;
  end;

  /// <summary>
  ///   Runs the filter chain around a request dispatch. Use the phased instance
  ///   api when the dispatch is inline code (legacy DoHandleRequest), or the
  ///   class Run() convenience when the dispatch is a closure (attribute route).
  ///   With no filters registered both are transparent pass-throughs.
  /// </summary>
  TKXFilterChain = class
  private
    FContext: IKXRequestContext;
    FRan: Integer; // index of the last filter whose BeforeInvoke has run
  public
    /// <summary>Creates a chain bound to the given per-request context.</summary>
    constructor Create(const AContext: IKXRequestContext);
    /// BeforeInvoke for all filters, in order. Stops early if Context.Handled.
    procedure RunBefore;
    /// Reverse OnException walk over the filters that ran; True if one handled it.
    function HandleException(E: Exception): Boolean;
    /// AfterInvoke in reverse over the filters that ran. Call from a finally.
    procedure RunAfter;
    property Context: IKXRequestContext read FContext;

    /// <summary>Convenience runner for a closure dispatch (the attribute route):
    /// runs BeforeInvoke, the dispatch (unless already Handled), OnException on
    /// failure, and AfterInvoke in a finally. Transparent if no filters.</summary>
    class function Run(const AContext: IKXRequestContext;
      const ADispatch: TFunc<Boolean>): Boolean;
  end;

implementation

{ TKXRequestContext }

constructor TKXRequestContext.Create(const APath, AHttpMethod: string;
  const AAllowUnauthenticated, AAllowSessionLost: Boolean;
  const AAllowDirectNavigation: Boolean = True);
begin
  inherited Create;
  FPath := APath;
  FHttpMethod := AHttpMethod;
  FAllowUnauthenticated := AAllowUnauthenticated;
  FAllowSessionLost := AAllowSessionLost;
  FAllowDirectNavigation := AAllowDirectNavigation;
  FHandled := False;
end;

function TKXRequestContext.GetPath: string;
begin
  Result := FPath;
end;

function TKXRequestContext.GetHttpMethod: string;
begin
  Result := FHttpMethod;
end;

function TKXRequestContext.GetAllowUnauthenticated: Boolean;
begin
  Result := FAllowUnauthenticated;
end;

function TKXRequestContext.GetAllowSessionLost: Boolean;
begin
  Result := FAllowSessionLost;
end;

function TKXRequestContext.GetAllowDirectNavigation: Boolean;
begin
  Result := FAllowDirectNavigation;
end;

function TKXRequestContext.GetHandled: Boolean;
begin
  Result := FHandled;
end;

procedure TKXRequestContext.SetHandled(const AValue: Boolean);
begin
  FHandled := AValue;
end;

{ TKXFilterRegistry }

constructor TKXFilterRegistry.Create;
begin
  inherited;
  FFilters := TList<IKXRequestFilter>.Create;
end;

destructor TKXFilterRegistry.Destroy;
begin
  FreeAndNil(FFilters);
  inherited;
end;

class destructor TKXFilterRegistry.DestroyClass;
begin
  FreeAndNil(FInstance);
end;

class function TKXFilterRegistry.GetInstance: TKXFilterRegistry;
begin
  if not Assigned(FInstance) then
    FInstance := TKXFilterRegistry.Create;
  Result := FInstance;
end;

procedure TKXFilterRegistry.RegisterFilter(const AFilter: IKXRequestFilter);
begin
  FFilters.Add(AFilter);
end;

{ TKXFilterChain }

constructor TKXFilterChain.Create(const AContext: IKXRequestContext);
begin
  inherited Create;
  FContext := AContext;
  FRan := -1;
end;

procedure TKXFilterChain.RunBefore;
var
  LFilters: TList<IKXRequestFilter>;
  I: Integer;
begin
  LFilters := TKXFilterRegistry.Instance.Filters;
  for I := 0 to LFilters.Count - 1 do
  begin
    FRan := I;
    LFilters[I].BeforeInvoke(FContext);
    if FContext.Handled then
      Break;
  end;
end;

function TKXFilterChain.HandleException(E: Exception): Boolean;
var
  LFilters: TList<IKXRequestFilter>;
  I: Integer;
begin
  // Innermost to outermost (reverse registration order): the first that returns
  // True stops the walk. The error handler, registered first, is the last resort.
  LFilters := TKXFilterRegistry.Instance.Filters;
  Result := False;
  for I := FRan downto 0 do
    if LFilters[I].OnException(FContext, E) then
      Exit(True);
end;

procedure TKXFilterChain.RunAfter;
var
  LFilters: TList<IKXRequestFilter>;
  I: Integer;
begin
  LFilters := TKXFilterRegistry.Instance.Filters;
  for I := FRan downto 0 do
    LFilters[I].AfterInvoke(FContext);
end;

class function TKXFilterChain.Run(const AContext: IKXRequestContext;
  const ADispatch: TFunc<Boolean>): Boolean;
var
  LChain: TKXFilterChain;
begin
  // Fast path: no filters → transparent pass-through.
  if TKXFilterRegistry.Instance.Filters.Count = 0 then
    Exit(ADispatch());

  LChain := TKXFilterChain.Create(AContext);
  try
    LChain.RunBefore;
    try
      if AContext.Handled then
        Result := True
      else
        Result := ADispatch();
    except
      on E: Exception do
      begin
        if not LChain.HandleException(E) then
          raise;
        Result := True;
      end;
    end;
  finally
    LChain.RunAfter;
    LChain.Free;
  end;
end;

end.
