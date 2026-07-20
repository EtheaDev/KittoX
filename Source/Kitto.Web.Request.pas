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

unit Kitto.Web.Request;

{$I Kitto.Defines.inc}

interface

uses
  System.Classes,
  Web.HTTPApp,
  {$IFNDEF LINUX}
  Web.ReqMulti,
  {$ENDIF}
  EF.Tree;

type
  /// <summary>
  ///  Wraps a TWebRequest object and is used throughout Kitto whenever a
  ///  request object is needed. Adds Kitto-specific funcionality.
  ///  Not inheriting from TWebRequest (or specific derived classes) allows
  ///  to transparently support whatever deployment options WebBroker provides,
  ///  while still keeping Kitto-specific additional functionality.
  /// </summary>
  TKWebRequest = class
  private
    FQueryTree: TEFTree;
    FJSONContentTree: TEFTree;
    FRequest: TWebRequest;
    FOwnsRequest: Boolean;
    class threadvar FCurrent: TKWebRequest;
    function GetIsAjax: Boolean;
    class function GetCurrent: TKWebRequest; static;
    class procedure SetCurrent(const AValue: TKWebRequest); static;
    function GetIsRefresh: Boolean;
    function GetQueryTree: TEFTree;
    function GetJSONContentTree: TEFTree;
    function GetAcceptLanguage: string;
    function GetLanguage: string;
    function GetRemoteAddr: string;
    function GetUserAgent: string;
    function GetTimestamp: TDateTime;
    function GetFiles: TAbstractWebRequestFiles;
  public
    destructor Destroy; override;
  public
    /// <summary>
    ///  The name of the segment of the URL's path enclusing all method calls.
    /// </summary>
    const APP_NAMESPACE = 'app';
    /// <summary>The request bound to the current thread (per-request threadvar).</summary>
    class property Current: TKWebRequest read GetCurrent write SetCurrent;
    /// <summary>Frees and clears the current-thread request.</summary>
    class procedure ClearCurrent;

    /// <summary>Wraps the given WebBroker request (optionally taking ownership).</summary>
    constructor Create(const ARequest: TWebRequest; const AOwnsRequest: Boolean = True);

    /// <summary>True if the request is an XMLHttpRequest (X-Requested-With).</summary>
    property IsAjax: Boolean read GetIsAjax;
    /// <summary>True if the request is a browser refresh (non-Ajax, Cache-Control: max-age=0).</summary>
    property IsRefresh: Boolean read GetIsRefresh;

    /// <summary>
    ///  Returns all request query fields (names and decoded values) as a tree
    ///  object, which is only alive as long as the request object is.
    ///  Note: All values are treated as strings.
    /// </summary>
    property QueryTree: TEFTree read GetQueryTree;

    /// <summary>
    ///  Parses the request content as a JSON object and returns the data as a
    ///  tree object, which is only alive as long as the request object is.
    ///  Note: All values are treated as strings.
    /// </summary>
    property JSONContentTree: TEFTree read GetJSONContentTree;

    /// <summary>
    ///  Decodes and returns the value of the query field with the given name,
    ///  or '' if not found.
    /// </summary>
    function GetQueryField(const AName: string): string;
    /// <summary>
    ///  Returns the value of the header field with the given name,
    ///  or '' if not found.
    /// </summary>
    function GetHeaderField(const AName: string): string;
    /// <summary>
    ///  Decodes and returns the value of the POST form field with the given name
    ///  (from ContentFields), or '' if not found.
    /// </summary>
    function GetFormField(const AName: string): string;
    /// <summary>
    ///  Returns the POST body fields as a TStrings of name=value pairs (the RTL
    ///  ContentFields), by reference — owned by the request, do not free.
    ///  Backs the [TKXFormBody] parameter binding.
    /// </summary>
    function GetContentFields: TStrings;
    /// <summary>
    ///  Returns the value of a field searching first in ContentFields (POST body),
    ///  then in QueryFields (URL query string). Returns '' if not found.
    /// </summary>
    function GetField(const AName: string): string;
    /// <summary>
    ///  Returns True if a field with the given name is present in the POST
    ///  body or in the URL query string. Distinguishes "field not posted" from
    ///  "field posted with empty value", which GetField/GetFormField alone
    ///  cannot do.
    /// </summary>
    function HasField(const AName: string): Boolean;
    /// <summary>
    ///  Returns the value of the cookie with the given name,
    ///  or '' if not found.
    /// </summary>
    function GetCookie(const AName: string): string;

    /// <summary>True if the User-Agent indicates an iPhone.</summary>
    function IsBrowserIPhone: Boolean;
    /// <summary>True if the User-Agent indicates an iPad.</summary>
    function IsBrowserIPad: Boolean;
    /// <summary>True if the User-Agent indicates a mobile device (iPhone/iPad/Android/Windows Phone).</summary>
    function IsMobileBrowser: Boolean;
    /// <summary>True if the User-Agent indicates a Windows Phone.</summary>
    function IsBrowserWindowsPhone: Boolean;

    /// <summary>
    ///  True if the specified URL is interpreted as a page refresh (which
    ///  in Kitto means a new session).
    /// </summary>
    function IsPageRefresh(const AURLDocument: string): Boolean;

    /// <summary>The Accept-Language header value.</summary>
    property AcceptLanguage: string read GetAcceptLanguage;
    /// <summary>The requested language (from the Language query field).</summary>
    property Language: string read GetLanguage;
    /// <summary>The User-Agent header value.</summary>
    property UserAgent: string read GetUserAgent;
    /// <summary>The client's remote (IP) address.</summary>
    property RemoteAddr: string read GetRemoteAddr;
    /// <summary>The request timestamp (falls back to Now if the request has no date).</summary>
    property Timestamp: TDateTime read GetTimestamp;
    /// <summary>The uploaded files of a multipart request.</summary>
    property Files: TAbstractWebRequestFiles read GetFiles;
    /// <summary>HTTP method of the request (GET, POST, etc.).</summary>
    function Method: string;
  end;

  /// <summary>
  ///  Keeps track of some request data to be accessed after the request
  ///  object itself is destroyed.
  /// </summary>
  TKWebRequestInfo = record
    UserAgent: string;
    ClientAddress: string;
    DateTime: TDateTime;
    /// <summary>Resets all captured fields to empty.</summary>
    procedure ClearData;
    /// <summary>Captures UserAgent/ClientAddress/Timestamp from the given request.</summary>
    procedure SetData(const ARequest: TKWebRequest);
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.JSON,
  EF.JSON,
  EF.Logger;

{ TKWebRequest }

class procedure TKWebRequest.ClearCurrent;
begin
  FreeAndNil(FCurrent);
end;

constructor TKWebRequest.Create(const ARequest: TWebRequest; const AOwnsRequest: Boolean);
begin
  Assert(Assigned(ARequest));
  inherited Create;
  FRequest := ARequest;
  FOwnsRequest := AOwnsRequest;
end;

destructor TKWebRequest.Destroy;
begin
  FreeAndNil(FQueryTree);
  FreeAndNil(FJSONContentTree);
  if FOwnsRequest then
    FreeAndNil(FRequest);
  inherited;
end;

function TKWebRequest.GetAcceptLanguage: string;
begin
  Result := GetHeaderField('Accept-Language');
end;

function TKWebRequest.GetCookie(const AName: string): string;
begin
  Result := FRequest.CookieFields.Values[AName];
end;

class function TKWebRequest.GetCurrent: TKWebRequest;
begin
  Result := FCurrent;
end;

function TKWebRequest.GetFiles: TAbstractWebRequestFiles;
begin
  Result := FRequest.Files;
end;

function TKWebRequest.GetHeaderField(const AName: string): string;
begin
  Result := FRequest.GetFieldByName(AName);
end;

function TKWebRequest.GetIsAjax: Boolean;
begin
  Result := FRequest.GetFieldByName('X-Requested-With') = 'XMLHttpRequest';
end;

function TKWebRequest.GetIsRefresh: Boolean;
begin
  Result := not IsAjax and (FRequest.GetFieldByName('Cache-Control') = 'max-age=0');
end;

function TKWebRequest.GetJSONContentTree: TEFTree;
var
  LJSON: TJSONValue;
begin
  if not Assigned(FJSONContentTree) then
  begin
    FJSONContentTree := TEFTree.Create;
    LJSON := TJSONObject.ParseJSONValue(FRequest.Content);
    try
      Assert(Assigned(LJSON));
      Assert(LJSON is TJSONObject);
      LoadJSONObjectInTree(TJSONObject(LJSON), FJSONContentTree);
    finally
      FreeAndNil(LJSON);
    end;
  end;
  Result := FJSONContentTree;
end;

function TKWebRequest.GetLanguage: string;
begin
  Result := FRequest.QueryFields.Values['Language'];
end;

function TKWebRequest.GetFormField(const AName: string): string;
begin
  // The RTL (WebBroker ExtractContentFields, Decode=True) already URL-decodes
  // the POST body once when filling ContentFields. Do NOT decode again: a
  // second URL decode over already-decoded text corrupts any value that looks
  // like an encoded sequence — '%XX', '+' (turned into a space), and, depending
  // on the RTL version, reserved chars such as '?'. That silently alters
  // passwords (login fails), saved field values, search/filter terms and record
  // keys. Transport decoding must happen exactly once, and the RTL already does
  // it. See BUG_Double_URL_Decode.md.
  Result := FRequest.ContentFields.Values[AName];
end;

function TKWebRequest.GetContentFields: TStrings;
begin
  // By reference: the WebBroker request owns ContentFields for the request's life.
  Result := FRequest.ContentFields;
end;

function TKWebRequest.GetField(const AName: string): string;
begin
  // Try POST body first, then URL query string.
  Result := GetFormField(AName);
  if Result = '' then
    Result := GetQueryField(AName);
end;

function TKWebRequest.HasField(const AName: string): Boolean;
begin
  Result := (FRequest.ContentFields.IndexOfName(AName) >= 0) or
            (FRequest.QueryFields.IndexOfName(AName) >= 0);
end;

function TKWebRequest.GetQueryField(const AName: string): string;
begin
  // The RTL already URL-decodes the query string once when filling QueryFields
  // (WebBroker, Decode=True). Do NOT decode again — see the note in
  // GetFormField and BUG_Double_URL_Decode.md. This also fixes GetQueryTree
  // (which calls this) and the composite record keys, whose per-piece decode in
  // Kitto.Web.Application.pas now receives a correctly single-decoded input.
  Result := FRequest.QueryFields.Values[AName];
end;

function TKWebRequest.GetQueryTree: TEFTree;
var
  I: Integer;
begin
  if not Assigned(FQueryTree) then
  begin
    FQueryTree := TEFTree.Create;
    for I := 0 to FRequest.QueryFields.Count - 1 do
    begin
      if FRequest.QueryFields.Names[I] <> '' then
        FQueryTree.AddChild(FRequest.QueryFields.Names[I], GetQueryField(FRequest.QueryFields.Names[I]));
    end;
  end;
  Result := FQueryTree;
end;

function TKWebRequest.Method: string;
begin
  Result := FRequest.Method;
end;

function TKWebRequest.GetRemoteAddr: string;
begin
  Result := FRequest.RemoteAddr;
end;

function TKWebRequest.GetTimestamp: TDateTime;
begin
  Result := FRequest.Date;
  if Result <= 0 then
    Result := Now;
end;

function TKWebRequest.GetUserAgent: string;
begin
  Result := FRequest.UserAgent;
end;

function TKWebRequest.IsBrowserIPhone: Boolean;
begin
  Result := string(FRequest.UserAgent).Contains('iPhone');
end;

function TKWebRequest.IsBrowserWindowsPhone: Boolean;
begin
  Result := string(FRequest.UserAgent).Contains('Windows Phone');
end;

function TKWebRequest.IsBrowserIPad: Boolean;
begin
  Result := string(FRequest.UserAgent).Contains('iPad');
end;

function TKWebRequest.IsMobileBrowser: Boolean;
var
  LUserAgent: string;
begin
  LUserAgent := FRequest.UserAgent;
  Result := LUserAgent.Contains('Windows Phone') or
    LUserAgent.Contains('iPhone') or
    LUserAgent.Contains('iPad') or
    LUserAgent.Contains('Android');
end;

function TKWebRequest.IsPageRefresh(const AURLDocument: string): Boolean;
begin
  Result := not IsAjax and MatchText(AURLDocument, ['', APP_NAMESPACE]);
end;

class procedure TKWebRequest.SetCurrent(const AValue: TKWebRequest);
begin
  FCurrent := AValue;
end;

{ TKWebRequestInfo }

procedure TKWebRequestInfo.ClearData;
begin
  UserAgent := '';
  ClientAddress := '';
  DateTime := 0;
end;

procedure TKWebRequestInfo.SetData(const ARequest: TKWebRequest);
begin
  UserAgent := ARequest.UserAgent;
  ClientAddress := ARequest.RemoteAddr;
  DateTime := ARequest.Timestamp;
end;

end.
