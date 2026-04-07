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
///   Session provider interface abstracting the transport mechanism for
///   session identification. Current implementation: cookie-based.
///   Future: JWT token-based (Authorization: Bearer header).
/// </summary>
unit Kitto.Web.Routing.Session;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  Kitto.Web.Request,
  Kitto.Web.Response;

type
  /// <summary>
  ///   Abstraction for session ID transport. Implementations handle
  ///   reading the session ID from requests and writing it to responses.
  ///   The session state itself (TKWebSession) is unchanged.
  /// </summary>
  IKXSessionProvider = interface
    ['{B8A3E4F1-6C2D-4A9B-8E7F-1D3C5A2B4E6F}']
    /// <summary>
    ///   Extracts the session ID from the incoming request.
    ///   Returns empty string if no session ID is present.
    /// </summary>
    function GetSessionId(const ARequest: TKWebRequest): string;

    /// <summary>
    ///   Sets the session ID on the outgoing response (e.g., Set-Cookie header).
    /// </summary>
    procedure SetSessionId(const AResponse: TKWebResponse;
      const ASessionId: string; const AExpires: TDateTime);

    /// <summary>
    ///   Removes/invalidates the session ID on the outgoing response.
    /// </summary>
    procedure RemoveSession(const AResponse: TKWebResponse);
  end;

  /// <summary>
  ///   Cookie-based session provider. Reads and writes the session ID
  ///   as an HTTP cookie. This is the current KittoX behavior.
  /// </summary>
  TKXCookieSessionProvider = class(TInterfacedObject, IKXSessionProvider)
  private
    FCookieName: string;
  public
    constructor Create(const ACookieName: string = 'kx_session');
    function GetSessionId(const ARequest: TKWebRequest): string;
    procedure SetSessionId(const AResponse: TKWebResponse;
      const ASessionId: string; const AExpires: TDateTime);
    procedure RemoveSession(const AResponse: TKWebResponse);
  end;

implementation

{ TKXCookieSessionProvider }

constructor TKXCookieSessionProvider.Create(const ACookieName: string);
begin
  inherited Create;
  FCookieName := ACookieName;
end;

function TKXCookieSessionProvider.GetSessionId(const ARequest: TKWebRequest): string;
begin
  Result := ARequest.GetCookie(FCookieName);
end;

procedure TKXCookieSessionProvider.SetSessionId(const AResponse: TKWebResponse;
  const ASessionId: string; const AExpires: TDateTime);
begin
  AResponse.SetCookie(FCookieName, ASessionId, AExpires);
end;

procedure TKXCookieSessionProvider.RemoveSession(const AResponse: TKWebResponse);
begin
  AResponse.SetCookie(FCookieName, '', Now - 1);
end;

end.
