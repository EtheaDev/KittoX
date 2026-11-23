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
///  The WebBroker request and response of the HTTP.sys host:
///  <see cref="TKHttpSysRequest" /> over an <c>HTTP_REQUEST</c> handed over by
///  the kernel, <see cref="TKHttpSysResponse" /> over
///  <c>HttpSendHttpResponse</c>.
///  <para>This is the whole of what a second host costs. KittoX speaks
///  <c>TWebRequest</c>/<c>TWebResponse</c> everywhere - the engine, the routes,
///  the handlers, even the Indy host, which wraps Indy into the same pair - so
///  a new host is a new pair and nothing else. It is also why the pair is
///  worth getting exactly right: everything above it believes what it
///  says.</para>
///  <para>Nothing of the kernel's buffer is kept: the strings are extracted in
///  the constructor. The buffer the kernel filled stays valid only as long as
///  the listener holds it, and a request that travels to a worker thread must
///  not point into it.</para>
/// </summary>
unit Kitto.Web.HttpSys;

{$I Kitto.Defines.inc}

interface

{$IFDEF MSWINDOWS}

uses
  System.SysUtils
  , System.Classes
  , Winapi.Windows
  , Web.HTTPApp
  , Kitto.Web.HttpSysApi
  ;

type
  /// <summary>
  ///  A request as the kernel delivered it, read into Delphi strings.
  /// </summary>
  TKHttpSysRequest = class(TWebRequest)
  strict private
    FMethod: string;
    FProtocolVersion: string;
    FRawUrl: string;
    FPathInfo: string;
    FQuery: string;
    FHost: string;
    FRemoteAddr: string;
    FServerPort: Int64;
    FHeaders: TStringList;   // name=value, every header the request carried
    FContent: TBytes;
    FReadPos: Integer;
    FRequestId: HTTP_REQUEST_ID;
    procedure ReadHeaders(const ARequest: PHTTP_REQUEST);
    procedure ReadAddress(const ARequest: PHTTP_REQUEST);
  strict protected
    function GetRawContent: TBytes; override;
    function GetStringVariable(Index: Integer): string; override;
    function GetDateVariable(Index: Integer): TDateTime; override;
    function GetIntegerVariable(Index: Integer): Int64; override;
  public
    /// <summary>
    ///  Reads everything this request is made of out of the kernel's buffer.
    ///  <c>ABody</c> is the body as the host assembled it - what came with the
    ///  request plus whatever it had to go back for.
    /// </summary>
    constructor Create(const ARequest: PHTTP_REQUEST; const ABody: TBytes);
    destructor Destroy; override;

    function ReadClient(var Buffer; Count: Integer): Integer; override;
    function ReadString(Count: Integer): string; override;
    function TranslateURI(const URI: string): string; override;
    function WriteClient(var Buffer; Count: Integer): Integer; override;
    function WriteString(const AString: string): Boolean; override;
    function WriteHeaders(StatusCode: Integer; const ReasonString, Headers: string): Boolean; override;
    function GetFieldByName(const Name: string): string; override;
    procedure ExtractAllHeaders(Strings: TStrings); override;

    /// <summary>The id the answer has to be sent against.</summary>
    property RequestId: HTTP_REQUEST_ID read FRequestId;
    /// <summary>The path of the request, decoded by the kernel.</summary>
    property PathInfo: string read FPathInfo;
  end;

  /// <summary>
  ///  The answer, sent to the kernel when <see cref="SendResponse" /> is
  ///  called - which is what the engine does at the end of a request.
  /// </summary>
  TKHttpSysResponse = class(TWebResponse)
  strict private
    FQueue: THandle;
    FRequestId: HTTP_REQUEST_ID;
    FStatusCode: Integer;
    FStringVars: array[0..11] of string;
    FDateVars: array[0..2] of TDateTime;
    FContentLength: Int64;
    FContent: TBytes;
    FLogMessage: string;
    FSent: Boolean;
    FSendRequested: Boolean;
    FKeepAlive: Boolean;
    /// <summary>The AnsiString values the API is given pointers into. They
    /// have to outlive the call, which is why they are fields and not
    /// locals.</summary>
    FHeaderValues: TArray<AnsiString>;
    FHeaderNames: TArray<AnsiString>;
    FReason: AnsiString;
    function Keep(const AValue: string): PAnsiChar;
    function KeepName(const AValue: string): PAnsiChar;
    procedure CollectBody;
  strict protected
    function GetStringVariable(Index: Integer): string; override;
    procedure SetStringVariable(Index: Integer; const Value: string); override;
    function GetDateVariable(Index: Integer): TDateTime; override;
    procedure SetDateVariable(Index: Integer; const Value: TDateTime); override;
    function GetIntegerVariable(Index: Integer): Int64; override;
    procedure SetIntegerVariable(Index: Integer; Value: Int64); override;
    function GetContent: string; override;
    procedure SetContent(const Value: string); override;
    function GetStatusCode: Integer; override;
    procedure SetStatusCode(Value: Integer); override;
    function GetLogMessage: string; override;
    procedure SetLogMessage(const Value: string); override;
  public
    constructor Create(const ARequest: TKHttpSysRequest; const AQueue: THandle);
    /// <summary>
    ///  What the engine calls when it considers the answer ready. It does
    ///  <b>not</b> put it on the wire: the engine calls this while the KittoX
    ///  wrappers are still alive, and those write into the response as they
    ///  close - the content type with its charset, the last of the body. Under
    ///  Indy nothing is lost, because there SendResponse fills a structure and
    ///  the network write happens later; here the write is the send, and
    ///  sending at once loses whatever is written afterwards.
    ///  <para>The host calls <see cref="Transmit" /> when the whole round is
    ///  over. That is the one place a difference between the two hosts was
    ///  measured - the short answers came back empty - and the one place this
    ///  class differs from the obvious implementation.</para>
    /// </summary>
    procedure SendResponse; override;
    procedure SendRedirect(const URI: string); override;
    function Sent: Boolean; override;
    /// <summary>Puts the answer on the wire. Called by the host, once, after
    /// everything that writes into the response has finished.</summary>
    procedure Transmit;
    /// <summary>False asks the kernel to close the connection after this
    /// answer.</summary>
    property KeepAlive: Boolean read FKeepAlive write FKeepAlive;
  end;

/// <summary>The reason phrase of a status code, for the few a help chat and a
/// data application actually produce. Anything else answers with its own
/// number, which no client reads anyway.</summary>
function KXHttpSysReasonOf(const AStatusCode: Integer): string;

{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

uses
  System.DateUtils
  , System.StrUtils
  , System.NetEncoding
  , Winapi.WinSock
  , Winapi.Winsock2
  ;

const
  // TWebRequest string variables, by the index its properties declare.
  RV_METHOD = 0;
  RV_PROTOCOLVERSION = 1;
  RV_URL = 2;
  RV_QUERY = 3;
  RV_PATHINFO = 4;
  RV_PATHTRANSLATED = 5;
  RV_CACHECONTROL = 6;
  RV_DATE = 7;          // date variable
  RV_ACCEPT = 8;
  RV_FROM = 9;
  RV_HOST = 10;
  RV_IFMODIFIEDSINCE = 11; // date variable
  RV_REFERER = 12;
  RV_USERAGENT = 13;
  RV_CONTENTENCODING = 14;
  RV_CONTENTTYPE = 15;
  RV_CONTENTLENGTH = 16;   // integer variable
  RV_CONTENTVERSION = 17;
  RV_DERIVEDFROM = 18;
  RV_EXPIRES = 19;         // date variable
  RV_TITLE = 20;
  RV_REMOTEADDR = 21;
  RV_REMOTEHOST = 22;
  RV_SCRIPTNAME = 23;
  RV_SERVERPORT = 24;      // integer variable
  RV_CONNECTION = 26;
  RV_COOKIE = 27;
  RV_AUTHORIZATION = 28;

  // TWebResponse string variables.
  SV_VERSION = 0;
  SV_REASONSTRING = 1;
  SV_SERVER = 2;
  SV_WWWAUTHENTICATE = 3;
  SV_REALM = 4;
  SV_ALLOW = 5;
  SV_LOCATION = 6;
  SV_CONTENTENCODING = 7;
  SV_CONTENTTYPE = 8;
  SV_CONTENTVERSION = 9;
  SV_DERIVEDFROM = 10;
  SV_TITLE = 11;

  // TWebResponse date variables.
  DV_DATE = 0;
  DV_EXPIRES = 1;
  DV_LASTMODIFIED = 2;

function KXHttpSysReasonOf(const AStatusCode: Integer): string;
begin
  case AStatusCode of
    200: Result := 'OK';
    201: Result := 'Created';
    204: Result := 'No Content';
    301: Result := 'Moved Permanently';
    302: Result := 'Found';
    304: Result := 'Not Modified';
    400: Result := 'Bad Request';
    401: Result := 'Unauthorized';
    403: Result := 'Forbidden';
    404: Result := 'Not Found';
    405: Result := 'Method Not Allowed';
    413: Result := 'Payload Too Large';
    500: Result := 'Internal Server Error';
    503: Result := 'Service Unavailable';
  else
    Result := IntToStr(AStatusCode);
  end;
end;

{ TKHttpSysRequest }

procedure TKHttpSysRequest.ReadHeaders(const ARequest: PHTTP_REQUEST);

  function Raw(const APtr: PAnsiChar; const ALen: Integer): string;
  var
    LBytes: TBytes;
  begin
    Result := '';
    if (APtr = nil) or (ALen <= 0) then
      Exit;
    SetLength(LBytes, ALen);
    Move(APtr^, LBytes[0], ALen);
    Result := TEncoding.UTF8.GetString(LBytes);
  end;

const
  KNOWN_NAMES: array[0..Ord(HttpHeaderRequestMaximum) - 1] of string = (
    'Cache-Control', 'Connection', 'Date', 'Keep-Alive', 'Pragma', 'Trailer',
    'Transfer-Encoding', 'Upgrade', 'Via', 'Warning', 'Allow', 'Content-Length',
    'Content-Type', 'Content-Encoding', 'Content-Language', 'Content-Location',
    'Content-MD5', 'Content-Range', 'Expires', 'Last-Modified', 'Accept',
    'Accept-Charset', 'Accept-Encoding', 'Accept-Language', 'Authorization',
    'Cookie', 'Expect', 'From', 'Host', 'If-Match', 'If-Modified-Since',
    'If-None-Match', 'If-Range', 'If-Unmodified-Since', 'Max-Forwards',
    'Proxy-Authorization', 'Referer', 'Range', 'TE', 'Translate', 'User-Agent');
var
  I: Integer;
  LUnknown: PHTTP_UNKNOWN_HEADER;
  LHeader: HTTP_KNOWN_HEADER;
begin
  for I := 0 to Ord(HttpHeaderRequestMaximum) - 1 do
  begin
    LHeader := ARequest.Base.Headers.KnownHeaders[I];
    if (LHeader.RawValueLength > 0) and (LHeader.pRawValue <> nil) then
      FHeaders.Add(KNOWN_NAMES[I] + '=' + Raw(LHeader.pRawValue, LHeader.RawValueLength));
  end;

  // Everything the kernel does not know by name - X-KittoX among them, which
  // is the header the whole client side of KittoX marks its requests with.
  for I := 0 to ARequest.Base.Headers.UnknownHeaderCount - 1 do
  begin
    LUnknown := PHTTP_UNKNOWN_HEADER(NativeUInt(ARequest.Base.Headers.pUnknownHeaders) +
      NativeUInt(I) * SizeOf(HTTP_UNKNOWN_HEADER));
    FHeaders.Add(Raw(LUnknown.pName, LUnknown.NameLength) + '=' +
      Raw(LUnknown.pRawValue, LUnknown.RawValueLength));
  end;
end;

procedure TKHttpSysRequest.ReadAddress(const ARequest: PHTTP_REQUEST);

  // Both families, because both arrive: on Windows, localhost resolves to IPv6
  // first, and a client address read as IPv4 only comes back empty for every
  // local request - which the engine refuses, since a session is bound to the
  // address it was opened from.
  function AddressOf(const APtr: Pointer): string;
  var
    LFamily: Word;
    LBuffer: array[0..63] of AnsiChar;
    LText: MarshaledAString;
  begin
    Result := '';
    if not Assigned(APtr) then
      Exit;
    LFamily := PWord(APtr)^;
    FillChar(LBuffer, SizeOf(LBuffer), 0);
    case LFamily of
      AF_INET:
        LText := inet_ntop(AF_INET, @PSockAddrIn(APtr).sin_addr, @LBuffer[0], SizeOf(LBuffer));
      AF_INET6:
        // The address of a sockaddr_in6 is 8 bytes into it: family, port and
        // flow info come first.
        LText := inet_ntop(AF_INET6, Pointer(NativeUInt(APtr) + 8), @LBuffer[0], SizeOf(LBuffer));
    else
      LText := nil;
    end;
    if LText <> nil then
      Result := string(AnsiString(LText));
  end;

  function PortOf(const APtr: Pointer): Integer;
  begin
    // The port sits in the same place in both families, right after the two
    // bytes of the family.
    if Assigned(APtr) then
      Result := ntohs(PWord(NativeUInt(APtr) + 2)^)
    else
      Result := 0;
  end;

begin
  FRemoteAddr := AddressOf(ARequest.Base.Address.pRemoteAddress);
  FServerPort := PortOf(ARequest.Base.Address.pLocalAddress);
end;

constructor TKHttpSysRequest.Create(const ARequest: PHTTP_REQUEST;
  const ABody: TBytes);

  function Cooked(const APtr: PWideChar; const ALenBytes: Integer): string;
  begin
    if (APtr = nil) or (ALenBytes <= 0) then
      Result := ''
    else
      // The cooked URL is UTF-16 and its lengths are in BYTES.
      SetString(Result, APtr, ALenBytes div SizeOf(WideChar));
  end;

const
  VERB_NAMES: array[HTTP_VERB] of string = (
    '', '', '', 'OPTIONS', 'GET', 'HEAD', 'POST', 'PUT', 'DELETE', 'TRACE',
    'CONNECT', 'TRACK', 'MOVE', 'COPY', 'PROPFIND', 'PROPPATCH', 'MKCOL',
    'LOCK', 'UNLOCK', 'SEARCH', '');
var
  LBytes: TBytes;
begin
  inherited Create;
  FHeaders := TStringList.Create;
  FHeaders.NameValueSeparator := '=';
  FContent := ABody;
  FReadPos := 0;
  FRequestId := ARequest.Base.RequestId;

  // The verb: the kernel names the ones it knows and hands over the bytes of
  // the ones it does not.
  if (ARequest.Base.Verb = HttpVerbUnknown) and (ARequest.Base.pUnknownVerb <> nil) then
  begin
    SetLength(LBytes, ARequest.Base.UnknownVerbLength);
    if Length(LBytes) > 0 then
      Move(ARequest.Base.pUnknownVerb^, LBytes[0], Length(LBytes));
    FMethod := TEncoding.UTF8.GetString(LBytes);
  end
  else if ARequest.Base.Verb in [Low(HTTP_VERB)..High(HTTP_VERB)] then
    FMethod := VERB_NAMES[ARequest.Base.Verb];

  FProtocolVersion := Format('HTTP/%d.%d',
    [ARequest.Base.Version.MajorVersion, ARequest.Base.Version.MinorVersion]);

  FPathInfo := Cooked(ARequest.Base.CookedUrl.pAbsPath, ARequest.Base.CookedUrl.AbsPathLength);
  FQuery := Cooked(ARequest.Base.CookedUrl.pQueryString, ARequest.Base.CookedUrl.QueryStringLength);
  // The query string arrives with its '?': what WebBroker calls Query is what
  // follows it.
  if FQuery.StartsWith('?') then
    FQuery := FQuery.Substring(1);
  FHost := Cooked(ARequest.Base.CookedUrl.pHost, ARequest.Base.CookedUrl.HostLength);
  FRawUrl := FPathInfo;
  if FQuery <> '' then
    FRawUrl := FRawUrl + '?' + FQuery;

  ReadHeaders(ARequest);
  ReadAddress(ARequest);
  UpdateMethodType;
end;

destructor TKHttpSysRequest.Destroy;
begin
  FHeaders.Free;
  inherited;
end;

function TKHttpSysRequest.GetRawContent: TBytes;
begin
  Result := FContent;
end;

function TKHttpSysRequest.GetStringVariable(Index: Integer): string;
begin
  case Index of
    RV_METHOD: Result := FMethod;
    RV_PROTOCOLVERSION: Result := FProtocolVersion;
    RV_URL: Result := FRawUrl;
    RV_QUERY: Result := FQuery;
    RV_PATHINFO: Result := FPathInfo;
    RV_PATHTRANSLATED: Result := FPathInfo;
    RV_HOST: Result := FHost;
    RV_REMOTEADDR, RV_REMOTEHOST: Result := FRemoteAddr;
    // Nothing of the URL is the name of a script here: the whole path is the
    // path, as it is under Indy.
    RV_SCRIPTNAME: Result := '';
    RV_CACHECONTROL: Result := FHeaders.Values['Cache-Control'];
    RV_ACCEPT: Result := FHeaders.Values['Accept'];
    RV_FROM: Result := FHeaders.Values['From'];
    RV_REFERER: Result := FHeaders.Values['Referer'];
    RV_USERAGENT: Result := FHeaders.Values['User-Agent'];
    RV_CONTENTENCODING: Result := FHeaders.Values['Content-Encoding'];
    RV_CONTENTTYPE: Result := FHeaders.Values['Content-Type'];
    RV_CONTENTVERSION: Result := FHeaders.Values['Content-Version'];
    RV_DERIVEDFROM: Result := FHeaders.Values['Derived-From'];
    RV_TITLE: Result := FHeaders.Values['Title'];
    RV_CONNECTION: Result := FHeaders.Values['Connection'];
    RV_COOKIE: Result := FHeaders.Values['Cookie'];
    RV_AUTHORIZATION: Result := FHeaders.Values['Authorization'];
  else
    Result := '';
  end;
end;

function TKHttpSysRequest.GetDateVariable(Index: Integer): TDateTime;

  function HeaderDate(const AName: string): TDateTime;
  var
    LValue: string;
  begin
    LValue := FHeaders.Values[AName];
    if LValue = '' then
      Exit(0);
    // An unparsable date is no date: a request must not fail over the shape of
    // an If-Modified-Since.
    try
      Result := StrToDateTimeDef(LValue, 0);
    except
      Result := 0;
    end;
  end;

begin
  case Index of
    RV_DATE: Result := HeaderDate('Date');
    RV_IFMODIFIEDSINCE: Result := HeaderDate('If-Modified-Since');
    RV_EXPIRES: Result := HeaderDate('Expires');
  else
    Result := 0;
  end;
end;

function TKHttpSysRequest.GetIntegerVariable(Index: Integer): Int64;
begin
  case Index of
    RV_CONTENTLENGTH: Result := Length(FContent);
    RV_SERVERPORT: Result := FServerPort;
  else
    Result := -1;
  end;
end;

function TKHttpSysRequest.GetFieldByName(const Name: string): string;
begin
  Result := FHeaders.Values[Name];
end;

procedure TKHttpSysRequest.ExtractAllHeaders(Strings: TStrings);
begin
  Strings.Assign(FHeaders);
end;

function TKHttpSysRequest.ReadClient(var Buffer; Count: Integer): Integer;
begin
  Result := Length(FContent) - FReadPos;
  if Result > Count then
    Result := Count;
  if Result > 0 then
  begin
    Move(FContent[FReadPos], Buffer, Result);
    Inc(FReadPos, Result);
  end
  else
    Result := 0;
end;

function TKHttpSysRequest.ReadString(Count: Integer): string;
var
  LBytes: TBytes;
  LRead: Integer;
begin
  SetLength(LBytes, Count);
  LRead := ReadClient(LBytes[0], Count);
  SetLength(LBytes, LRead);
  Result := TEncoding.UTF8.GetString(LBytes);
end;

function TKHttpSysRequest.TranslateURI(const URI: string): string;
begin
  // There is no document root to translate against: the engine resolves what
  // it serves from its own configuration.
  Result := URI;
end;

function TKHttpSysRequest.WriteClient(var Buffer; Count: Integer): Integer;
begin
  // Writing to the client through the request object belongs to the CGI world.
  // The response does the writing here, and it does it in one go.
  Result := 0;
end;

function TKHttpSysRequest.WriteString(const AString: string): Boolean;
begin
  Result := False;
end;

function TKHttpSysRequest.WriteHeaders(StatusCode: Integer;
  const ReasonString, Headers: string): Boolean;
begin
  Result := False;
end;

{ TKHttpSysResponse }

constructor TKHttpSysResponse.Create(const ARequest: TKHttpSysRequest;
  const AQueue: THandle);
begin
  inherited Create(ARequest);
  FQueue := AQueue;
  FRequestId := ARequest.RequestId;
  FStatusCode := 200;
  FContentLength := -1;
  FKeepAlive := True;
  FStringVars[SV_VERSION] := ARequest.ProtocolVersion;
  FStringVars[SV_CONTENTTYPE] := 'text/html';
  FDateVars[DV_DATE] := Now;
end;

function TKHttpSysResponse.GetStringVariable(Index: Integer): string;
begin
  if (Index >= Low(FStringVars)) and (Index <= High(FStringVars)) then
    Result := FStringVars[Index]
  else
    Result := '';
end;

procedure TKHttpSysResponse.SetStringVariable(Index: Integer; const Value: string);
begin
  if (Index >= Low(FStringVars)) and (Index <= High(FStringVars)) then
    FStringVars[Index] := Value;
end;

function TKHttpSysResponse.GetDateVariable(Index: Integer): TDateTime;
begin
  if (Index >= Low(FDateVars)) and (Index <= High(FDateVars)) then
    Result := FDateVars[Index]
  else
    Result := 0;
end;

procedure TKHttpSysResponse.SetDateVariable(Index: Integer; const Value: TDateTime);
begin
  if (Index >= Low(FDateVars)) and (Index <= High(FDateVars)) then
    FDateVars[Index] := Value;
end;

function TKHttpSysResponse.GetIntegerVariable(Index: Integer): Int64;
begin
  if Index = 0 then
    Result := FContentLength
  else
    Result := -1;
end;

procedure TKHttpSysResponse.SetIntegerVariable(Index: Integer; Value: Int64);
begin
  if Index = 0 then
    FContentLength := Value;
end;

function TKHttpSysResponse.GetContent: string;
begin
  Result := TEncoding.UTF8.GetString(FContent);
end;

procedure TKHttpSysResponse.SetContent(const Value: string);
begin
  FContent := TEncoding.UTF8.GetBytes(Value);
end;

function TKHttpSysResponse.GetStatusCode: Integer;
begin
  Result := FStatusCode;
end;

procedure TKHttpSysResponse.SetStatusCode(Value: Integer);
begin
  FStatusCode := Value;
end;

function TKHttpSysResponse.GetLogMessage: string;
begin
  Result := FLogMessage;
end;

procedure TKHttpSysResponse.SetLogMessage(const Value: string);
begin
  FLogMessage := Value;
end;

function TKHttpSysResponse.Sent: Boolean;
begin
  // True as soon as the engine has asked: it is what keeps it from building a
  // second answer over the one it just produced.
  Result := FSent or FSendRequested;
end;

function TKHttpSysResponse.Keep(const AValue: string): PAnsiChar;
var
  LIndex: Integer;
begin
  // The API is given pointers, not strings: every value it will read has to be
  // alive until HttpSendHttpResponse has returned.
  LIndex := Length(FHeaderValues);
  SetLength(FHeaderValues, LIndex + 1);
  FHeaderValues[LIndex] := UTF8Encode(AValue);
  Result := PAnsiChar(FHeaderValues[LIndex]);
end;

function TKHttpSysResponse.KeepName(const AValue: string): PAnsiChar;
var
  LIndex: Integer;
begin
  LIndex := Length(FHeaderNames);
  SetLength(FHeaderNames, LIndex + 1);
  FHeaderNames[LIndex] := UTF8Encode(AValue);
  Result := PAnsiChar(FHeaderNames[LIndex]);
end;

procedure TKHttpSysResponse.CollectBody;
var
  LStream: TStream;
  LRead: Int64;
begin
  // A content stream wins over the string content: it is what the framework
  // uses for a file, a report, a download.
  LStream := ContentStream;
  if not Assigned(LStream) then
    Exit;
  LStream.Position := 0;
  LRead := LStream.Size;
  SetLength(FContent, LRead);
  if LRead > 0 then
    LStream.ReadBuffer(FContent[0], LRead);
end;

procedure TKHttpSysResponse.SendRedirect(const URI: string);
begin
  StatusCode := 302;
  Location := URI;
  SendResponse;
end;



procedure TKHttpSysResponse.SendResponse;
begin
  // Noted, not sent: see the comment on the declaration.
  FSendRequested := True;
end;

procedure TKHttpSysResponse.Transmit;
var
  LResponse: HTTP_RESPONSE;
  LChunk: HTTP_DATA_CHUNK;
  LUnknown: TArray<HTTP_UNKNOWN_HEADER>;
  LBytesSent: ULONG;
  LFlags: ULONG;
  LResult: ULONG;
  I: Integer;

  procedure Known(const AId: HTTP_RESPONSE_HEADER_ID; const AValue: string);
  begin
    if AValue = '' then
      Exit;
    LResponse.Base.Headers.KnownHeaders[Ord(AId)].pRawValue := Keep(AValue);
    LResponse.Base.Headers.KnownHeaders[Ord(AId)].RawValueLength :=
      Length(UTF8Encode(AValue));
  end;

  procedure Unknown(const AName, AValue: string);
  var
    LIndex: Integer;
  begin
    if (AName = '') or (AValue = '') then
      Exit;
    LIndex := Length(LUnknown);
    SetLength(LUnknown, LIndex + 1);
    LUnknown[LIndex].pName := KeepName(AName);
    LUnknown[LIndex].NameLength := Length(UTF8Encode(AName));
    LUnknown[LIndex].pRawValue := Keep(AValue);
    LUnknown[LIndex].RawValueLength := Length(UTF8Encode(AValue));
  end;

begin
  if FSent then
    Exit;
  FSendRequested := True;

  CollectBody;
  FillChar(LResponse, SizeOf(LResponse), 0);
  LResponse.Base.Version.MajorVersion := 1;
  LResponse.Base.Version.MinorVersion := 1;
  LResponse.Base.StatusCode := FStatusCode;
  FReason := UTF8Encode(IfThen(FStringVars[SV_REASONSTRING] <> '',
    FStringVars[SV_REASONSTRING], KXHttpSysReasonOf(FStatusCode)));
  LResponse.Base.pReason := PAnsiChar(FReason);
  LResponse.Base.ReasonLength := Length(FReason);

  Known(HttpHeaderResponseContentType, FStringVars[SV_CONTENTTYPE]);
  Known(HttpHeaderResponseContentEncoding, FStringVars[SV_CONTENTENCODING]);
  Known(HttpHeaderResponseLocation, FStringVars[SV_LOCATION]);
  Known(HttpHeaderResponseServer, FStringVars[SV_SERVER]);
  Known(HttpHeaderResponseWwwAuthenticate, FStringVars[SV_WWWAUTHENTICATE]);
  Known(HttpHeaderResponseAllow, FStringVars[SV_ALLOW]);
  // The kernel adds a Content-Length of its own for a response that is sent in
  // one go, which this one always is.
  if FDateVars[DV_LASTMODIFIED] <> 0 then
    Known(HttpHeaderResponseLastModified,
      FormatDateTime('ddd, dd mmm yyyy hh":"nn":"ss "GMT"',
        TTimeZone.Local.ToUniversalTime(FDateVars[DV_LASTMODIFIED])));
  if FDateVars[DV_EXPIRES] <> 0 then
    Known(HttpHeaderResponseExpires,
      FormatDateTime('ddd, dd mmm yyyy hh":"nn":"ss "GMT"',
        TTimeZone.Local.ToUniversalTime(FDateVars[DV_EXPIRES])));

  // Every cookie is a Set-Cookie of its own, and the known-header slot holds
  // one value: they travel as unknown headers, which may repeat.
  for I := 0 to Cookies.Count - 1 do
    Unknown('Set-Cookie', Cookies[I].HeaderValue);

  for I := 0 to CustomHeaders.Count - 1 do
    Unknown(CustomHeaders.Names[I], CustomHeaders.ValueFromIndex[I]);

  if Length(LUnknown) > 0 then
  begin
    LResponse.Base.Headers.UnknownHeaderCount := Length(LUnknown);
    LResponse.Base.Headers.pUnknownHeaders := PHTTP_UNKNOWN_HEADER(@LUnknown[0]);
  end;

  if Length(FContent) > 0 then
  begin
    FillChar(LChunk, SizeOf(LChunk), 0);
    LChunk.DataChunkType := HttpDataChunkFromMemory;
    LChunk.FromMemory.pBuffer := @FContent[0];
    LChunk.FromMemory.BufferLength := Length(FContent);
    LResponse.Base.EntityChunkCount := 1;
    LResponse.Base.pEntityChunks := @LChunk;
  end;

  LFlags := 0;
  if not FKeepAlive then
    LFlags := HTTP_SEND_RESPONSE_FLAG_DISCONNECT;

  LBytesSent := 0;
  LResult := HttpSendHttpResponse(FQueue, FRequestId, LFlags, @LResponse, nil,
    LBytesSent, nil, 0, nil, nil);
  FSent := True;
  if LResult <> NO_ERROR then
    raise Exception.Create(KXHttpSysErrorText(LResult, 'HttpSendHttpResponse'));
end;

{$ENDIF}

end.
