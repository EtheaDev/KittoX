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

unit Kitto.Web.Response;

{$I Kitto.Defines.inc}

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.SysUtils,
  Web.HTTPApp;

type
  /// <summary>
  ///  Simplified response content container for KittoX (HTMX).
  ///  Replaces the former TJSResponseItems which contained the full
  ///  ExtJS JS generation pipeline.
  /// </summary>
  TKWebResponseContent = class
  private
    FItems: TStringList;
    FCharset: string;
    function GetEncoding: TEncoding;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    /// <summary>Removes all accumulated HTML.</summary>
    procedure Clear;
    /// <summary>Appends an HTML fragment to the content.</summary>
    procedure AddHTML(const AHTML: string);
    /// <summary>Returns the full accumulated HTML and clears the buffer.</summary>
    function Consume: string;
    /// <summary>The content type for this HTML content ('text/html; charset=…').</summary>
    function GetContentType: string;
    /// <summary>The character set used for the content (default utf-8).</summary>
    property Charset: string read FCharset write FCharset;
    /// <summary>The text encoding matching Charset.</summary>
    property Encoding: TEncoding read GetEncoding;
    /// <summary>Number of HTML fragments accumulated.</summary>
    property Count: Integer read GetCount;
  end;

  TKWebResponse = class
  private
    FResponse: TWebResponse;
    FItems: TStack<TKWebResponseContent>;
    FOwnsResponse: Boolean;
    class threadvar FCurrent: TKWebResponse;
    class function GetCurrent: TKWebResponse; static;
    class procedure SetCurrent(const AValue: TKWebResponse); static;
    function GetItems: TKWebResponseContent;
    function GetContentType: string;
    procedure SetContentType(const Value: string);
    function GetStatusCode: Integer;
    procedure SetStatusCode(const Value: Integer);
    function GetCustomHeaders: TStrings;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  public
    /// <summary>The response bound to the current thread (per-request threadvar).</summary>
    class property Current: TKWebResponse read GetCurrent write SetCurrent;
    /// <summary>Frees and clears the current-thread response.</summary>
    class procedure ClearCurrent;

    /// <summary>Wraps the given WebBroker response (optionally taking ownership).</summary>
    constructor Create(const AResponse: TWebResponse; const AOwnsResponse: Boolean = True);

    /// <summary>The response Content-Type header.</summary>
    property ContentType: string read GetContentType write SetContentType;
    /// <summary>The HTTP status code.</summary>
    property StatusCode: Integer read GetStatusCode write SetStatusCode;
    /// <summary>Sets (or replaces) a custom response header.</summary>
    procedure SetCustomHeader(const AName, AValue: string);
    /// <summary>The custom response headers collection.</summary>
    property CustomHeaders: TStrings read GetCustomHeaders;
    /// <summary>Writes a simple cookie (name/value/expiry).</summary>
    procedure SetCookie(const AName, AValue: string; const AExpires: TDateTime);
    /// <summary>
    ///  Writes a cookie with the full set of attributes needed by JWT auth:
    ///  Path, HttpOnly, Secure, SameSite. Pass an empty path to use '/'.
    ///  ASameSite values: 'Strict' | 'Lax' | 'None' | '' (omit attribute).
    /// </summary>
    procedure SetSecureCookie(const AName, AValue: string; const AExpires: TDateTime;
      const APath: string; const AHttpOnly: Boolean; const ASecure: Boolean;
      const ASameSite: string);

    /// <summary>True if any HTML content has been accumulated in Items.</summary>
    function HasItems: Boolean;
    /// <summary>The top HTML content buffer (the HTMX/HTML output pipeline).</summary>
    property Items: TKWebResponseContent read GetItems;
    /// <summary>
    ///  Generates content for all the Items and sets Content/ContentStream and
    ///  ContentType accordingly. Then finalizes the response. Called as a final
    ///  act after all request handlers have had a chance at contributing to it.
    /// </summary>
    procedure Send;

    /// <summary>
    ///  Takes care of freeing a previous content stream, if any, before
    ///  assigning a new one.
    /// </summary>
    procedure ReplaceContentStream(const AStream: TStream);
  end;

implementation

{ TKWebResponseContent }

constructor TKWebResponseContent.Create;
begin
  inherited Create;
  FItems := TStringList.Create;
end;

destructor TKWebResponseContent.Destroy;
begin
  FreeAndNil(FItems);
  inherited;
end;

procedure TKWebResponseContent.Clear;
begin
  FItems.Clear;
end;

procedure TKWebResponseContent.AddHTML(const AHTML: string);
begin
  FItems.Add(AHTML);
end;

function TKWebResponseContent.Consume: string;
begin
  Result := FItems.Text;
  Clear;
end;

function TKWebResponseContent.GetContentType: string;
begin
  Result := 'text/html; charset=' + FCharset;
end;

function TKWebResponseContent.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TKWebResponseContent.GetEncoding: TEncoding;
begin
  if FCharset = 'utf-8' then
    Result := TEncoding.UTF8
  else
    Result := TEncoding.ANSI;
end;

{ TKWebResponse }

class procedure TKWebResponse.ClearCurrent;
begin
  FreeAndNil(FCurrent);
end;

constructor TKWebResponse.Create(const AResponse: TWebResponse; const AOwnsResponse: Boolean);
begin
  Assert(Assigned(AResponse));
  inherited Create;
  FResponse := AResponse;
  FOwnsResponse := AOwnsResponse;
end;

destructor TKWebResponse.Destroy;
begin
  Assert(FItems.Count = 1);
  FItems.Pop.Free;
  FreeAndNil(FItems);
  if FOwnsResponse then
    FreeAndNil(FResponse);
  inherited;
end;

function TKWebResponse.GetContentType: string;
begin
  Result := FResponse.ContentType;
end;

class function TKWebResponse.GetCurrent: TKWebResponse;
begin
  Result := FCurrent;
end;

function TKWebResponse.GetCustomHeaders: TStrings;
begin
  Result := FResponse.CustomHeaders;
end;

function TKWebResponse.GetItems: TKWebResponseContent;
begin
  Assert(FItems.Count > 0);
  Result := FItems.Peek;
end;

function TKWebResponse.HasItems: Boolean;
begin
  Result := Assigned(FItems);
end;

procedure TKWebResponse.Send;
begin
  if Items.Count > 0 then
  begin
    ReplaceContentStream(TStringStream.Create(Items.Consume, Items.Encoding));
    ContentType := Items.GetContentType;
  end;
  if not FResponse.Sent then
    FResponse.SendResponse;
end;

procedure TKWebResponse.ReplaceContentStream(const AStream: TStream);
var
  LContentStream: TStream;
begin
  if Assigned(FResponse.ContentStream) then
  begin
    LContentStream := FResponse.ContentStream;
    FResponse.ContentStream := nil;
    FreeAndNil(LContentStream);
  end;
  FResponse.ContentStream := AStream;
end;

procedure TKWebResponse.SetContentType(const Value: string);
begin
  FResponse.ContentType := Value;
end;

function TKWebResponse.GetStatusCode: Integer;
begin
  Result := FResponse.StatusCode;
end;

procedure TKWebResponse.SetStatusCode(const Value: Integer);
begin
  FResponse.StatusCode := Value;
end;

procedure TKWebResponse.SetCookie(const AName, AValue: string; const AExpires: TDateTime);
var
  LCookie: TCookie;
begin
  LCookie := FResponse.Cookies.Add;
  LCookie.Name := AName;
  LCookie.Value := AValue;
  LCookie.Path := '/';
  LCookie.Expires := AExpires;
end;

procedure TKWebResponse.SetSecureCookie(const AName, AValue: string;
  const AExpires: TDateTime; const APath: string;
  const AHttpOnly: Boolean; const ASecure: Boolean; const ASameSite: string);
var
  LCookie: TCookie;
  LPath: string;
begin
  LPath := APath;
  if LPath = '' then
    LPath := '/';
  LCookie := FResponse.Cookies.Add;
  LCookie.Name := AName;
  LCookie.Value := AValue;
  LCookie.Path := LPath;
  LCookie.Expires := AExpires;
  LCookie.HttpOnly := AHttpOnly;
  LCookie.Secure := ASecure;
  LCookie.SameSite := ASameSite;
end;

class procedure TKWebResponse.SetCurrent(const AValue: TKWebResponse);
begin
  FCurrent := AValue;
end;

procedure TKWebResponse.SetCustomHeader(const AName, AValue: string);
begin
  FResponse.SetCustomHeader(AName, AValue);
end;

procedure TKWebResponse.AfterConstruction;
begin
  inherited;
  FItems := TStack<TKWebResponseContent>.Create;
  FItems.Push(TKWebResponseContent.Create);
end;

end.
