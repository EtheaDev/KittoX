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
///   Custom attributes for KittoX attribute-based routing and dependency injection.
///   Applied to resource classes and their methods to declare URL routes,
///   HTTP methods, and parameter bindings.
/// </summary>
unit Kitto.Web.Routing.Attributes;

{$I Kitto.Defines.inc}

interface

type
  /// <summary>
  ///   Declares the URL path template for a resource class (base path) or
  ///   a handler method (sub-path). Supports {ParamName} placeholders.
  ///   Example: [TKXPath('/kx/view/{ViewName}/data')]
  /// </summary>
  TKXPathAttribute = class(TCustomAttribute)
  private
    FValue: string;
  public
    /// <summary>Creates the attribute with the given URL path template.</summary>
    constructor Create(const AValue: string);
    /// <summary>The URL path template (e.g. '/kx/view/{ViewName}' or '/data').</summary>
    property Value: string read FValue;
  end;

  /// <summary>
  ///   Marks a handler method as responding to HTTP GET requests.
  /// </summary>
  TKXGETAttribute = class(TCustomAttribute);

  /// <summary>
  ///   Marks a handler method as responding to HTTP POST requests.
  /// </summary>
  TKXPOSTAttribute = class(TCustomAttribute);

  /// <summary>
  ///   Marks a handler method as responding to both GET and POST requests.
  /// </summary>
  TKXANYAttribute = class(TCustomAttribute);

  /// <summary>
  ///   Extracts a named segment from the URL path template.
  ///   The name must match a {ParamName} placeholder in the path.
  ///   Example: [TKXPathParam('ViewName')] const AViewName: string
  /// </summary>
  TKXPathParamAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    /// <summary>Creates the attribute bound to the given {placeholder} name.</summary>
    constructor Create(const AName: string);
    /// <summary>Name of the {placeholder} in the path this parameter captures.</summary>
    property Name: string read FName;
  end;

  /// <summary>
  ///   Extracts a named value from the URL query string (?name=value).
  ///   Example: [TKXQueryParam('key')] const AKey: string
  /// </summary>
  TKXQueryParamAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    /// <summary>Creates the attribute bound to the given query-string field name.</summary>
    constructor Create(const AName: string);
    /// <summary>Name of the query-string field (?Name=value) this parameter reads.</summary>
    property Name: string read FName;
  end;

  /// <summary>
  ///   Extracts a named value from the POST form body (application/x-www-form-urlencoded).
  ///   Falls back to query string if not found in POST body.
  ///   Example: [TKXFormParam('_op')] const AOperation: string
  /// </summary>
  TKXFormParamAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    /// <summary>Creates the attribute bound to the given POST-body field name.</summary>
    constructor Create(const AName: string);
    /// <summary>Name of the POST-body field this parameter reads (query-string fallback).</summary>
    property Name: string read FName;
  end;

  /// <summary>
  ///   Binds the whole POST body to a TStrings parameter (all name=value pairs,
  ///   the RTL ContentFields, by reference — do not free). Convenience for
  ///   handlers that want the raw form. The record-level binding for /save stays
  ///   in the handler, which needs the store / op / key lifecycle.
  ///   Example: [TKXFormBody] const AFields: TStrings
  /// </summary>
  TKXFormBodyAttribute = class(TCustomAttribute);

  /// <summary>
  ///   Marker attribute for dependency injection. The parameter type determines
  ///   what gets injected from the TKXInjectionRegistry.
  ///   Supported types: TKWebRequest, TKWebResponse, TKWebSession, TKConfig,
  ///   TKAuthenticator, TKViewTable, and any custom-registered type.
  ///   Example: [TKXContext] ASession: TKWebSession
  /// </summary>
  TKXContextAttribute = class(TCustomAttribute);

  /// <summary>
  ///   Marks a handler method as reachable WITHOUT authentication. The
  ///   authorization filter (TKXAuthorizationFilter) skips the auth gate for
  ///   such methods, so endpoints like login / reset-password / change-password
  ///   can be served to an unauthenticated session.
  /// </summary>
  TKXAnonymousAttribute = class(TCustomAttribute);

  /// <summary>
  ///   Marks a handler method as reachable by a top-level browser navigation
  ///   (address bar, opened link, window.open) — e.g. a blob/file download
  ///   opened in a new tab. By default every /kx/* endpoint returns an HTML
  ///   FRAGMENT meant to be loaded by the SPA (which always sends the
  ///   X-KittoX: true header); the navigation guard (TKXNavigationGuardFilter)
  ///   bounces any non-SPA top-level navigation to such a fragment endpoint back
  ///   to the app root. This attribute opts an endpoint OUT of that guard.
  /// </summary>
  TKXNavigableAttribute = class(TCustomAttribute);

implementation

{ TKXPathAttribute }

constructor TKXPathAttribute.Create(const AValue: string);
begin
  inherited Create;
  FValue := AValue;
end;

{ TKXPathParamAttribute }

constructor TKXPathParamAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

{ TKXQueryParamAttribute }

constructor TKXQueryParamAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

{ TKXFormParamAttribute }

constructor TKXFormParamAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

end.
