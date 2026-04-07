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
    procedure Clear;
    procedure AddHTML(const AHTML: string);
    function Consume: string;
    function GetContentType: string;
    property Charset: string read FCharset write FCharset;
    property Encoding: TEncoding read GetEncoding;
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
    function GetCustomHeaders: TStrings;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  public
    class property Current: TKWebResponse read GetCurrent write SetCurrent;
    class procedure ClearCurrent;

    constructor Create(const AResponse: TWebResponse; const AOwnsResponse: Boolean = True);

    property ContentType: string read GetContentType write SetContentType;
    procedure SetCustomHeader(const AName, AValue: string);
    property CustomHeaders: TStrings read GetCustomHeaders;
    procedure SetCookie(const AName, AValue: string; const AExpires: TDateTime);

    function HasItems: Boolean;
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
