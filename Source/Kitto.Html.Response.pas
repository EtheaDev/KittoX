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
///  HTML response helper for KittoX.
///  Wraps the existing TKWebResponse to send full HTML pages or HTMX fragments.
/// </summary>
unit Kitto.Html.Response;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  Kitto.Web.Request,
  Kitto.Web.Response;

type
  /// <summary>
  ///  Helper class for sending KittoX HTML responses.
  ///  Uses a threadvar Current for per-request access.
  /// </summary>
  TKXWebResponse = class
  strict private
    class threadvar FCurrent: TKXWebResponse;
    class function GetCurrent: TKXWebResponse; static;
    class procedure SetCurrent(const AValue: TKXWebResponse); static;
  public
    class property Current: TKXWebResponse read GetCurrent write SetCurrent;
    class procedure ClearCurrent;

    /// <summary>
    ///  Sends a full HTML page response (for initial page load).
    /// </summary>
    procedure SendHTML(const AHTML: string);

    /// <summary>
    ///  Sends an HTML fragment response (for HTMX partial updates).
    /// </summary>
    procedure SendFragment(const AHTML: string);

    /// <summary>
    ///  Returns True if the current request is an HTMX request
    ///  (has the HX-Request header).
    /// </summary>
    function IsHtmxRequest: Boolean;
  end;

implementation

{ TKXWebResponse }

class procedure TKXWebResponse.ClearCurrent;
begin
  FreeAndNil(FCurrent);
end;

class function TKXWebResponse.GetCurrent: TKXWebResponse;
begin
  if FCurrent = nil then
    FCurrent := TKXWebResponse.Create;
  Result := FCurrent;
end;

class procedure TKXWebResponse.SetCurrent(const AValue: TKXWebResponse);
begin
  FCurrent := AValue;
end;

function TKXWebResponse.IsHtmxRequest: Boolean;
begin
  Result := TKWebRequest.Current.GetHeaderField('HX-Request') = 'true';
end;

procedure TKXWebResponse.SendHTML(const AHTML: string);
begin
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(AHTML);
  TKWebResponse.Current.ContentType := 'text/html; charset=utf-8';
end;

procedure TKXWebResponse.SendFragment(const AHTML: string);
begin
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(AHTML);
  TKWebResponse.Current.ContentType := 'text/html; charset=utf-8';
end;

end.
