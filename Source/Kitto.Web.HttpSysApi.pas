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
///  Delphi translation of the Windows HTTP Server API (<c>httpapi.dll</c>), the
///  kernel-mode HTTP stack that IIS and Kestrel are built on.
///  <para>This is <b>version 2</b> of the API - the one with a server session,
///  a URL group and a request queue of its own - and not version 1, which is
///  the shorter road: v2 is what carries the timeouts, the length of the queue
///  and the limit on connections as <b>properties of the server session</b>,
///  and those are exactly the three things a KittoX application already
///  configures on the Indy host. With v1 they would be settings that quietly
///  do nothing.</para>
///  <para>What the API is for, and what it buys, is written in
///  <c>KittoX_HttpSys.md</c>. The short version: TLS without OpenSSL, bound by
///  <c>netsh</c> from the Windows certificate store; several processes sharing
///  one port; and requests queued by the kernel while an application
///  restarts.</para>
///  <para>Windows only, and it says so: everything is inside
///  <c>{$IFDEF MSWINDOWS}</c>.</para>
/// </summary>
unit Kitto.Web.HttpSysApi;

{$I Kitto.Defines.inc}

interface

{$IFDEF MSWINDOWS}

uses
  Winapi.Windows
  ;

{ Every enumeration below mirrors a C enum, which the Windows headers lay out as
  a 4-byte int. Delphi's default is the smallest type that fits - one byte here -
  which would silently shift every record field declared after one. }
{$MINENUMSIZE 4}

const
  HTTPAPI_DLL = 'httpapi.dll';

  /// <summary>Initialize the server side of the API (as opposed to the
  /// configuration side, which this unit does not use).</summary>
  HTTP_INITIALIZE_SERVER = 1;

  /// <summary>Ask for the body to be copied into the same buffer as the
  /// request, when it fits: one call instead of two for the common small
  /// POST.</summary>
  HTTP_RECEIVE_REQUEST_FLAG_COPY_BODY = 1;

  /// <summary>Close the connection after this response.</summary>
  HTTP_SEND_RESPONSE_FLAG_DISCONNECT = $00000001;
  /// <summary>More body follows, in later calls.</summary>
  HTTP_SEND_RESPONSE_FLAG_MORE_DATA = $00000002;

  /// <summary>The request carries more body than was handed over.</summary>
  HTTP_REQUEST_FLAG_MORE_ENTITY_BODY_EXISTS = $00000001;

type
  HTTP_OPAQUE_ID = ULONGLONG;
  HTTP_SERVER_SESSION_ID = HTTP_OPAQUE_ID;
  HTTP_URL_GROUP_ID = HTTP_OPAQUE_ID;
  HTTP_REQUEST_ID = HTTP_OPAQUE_ID;
  HTTP_CONNECTION_ID = HTTP_OPAQUE_ID;
  HTTP_RAW_CONNECTION_ID = HTTP_OPAQUE_ID;
  HTTP_URL_CONTEXT = HTTP_OPAQUE_ID;

  /// <summary>Which property of a server session or of a URL group is being
  /// read or written. Only a few are used here; the order is the one of
  /// http.h and must not be rearranged.</summary>
  HTTP_SERVER_PROPERTY = (
    HttpServerAuthenticationProperty,
    HttpServerLoggingProperty,
    HttpServerQosProperty,
    HttpServerTimeoutsProperty,
    HttpServerQueueLengthProperty,
    HttpServerStateProperty,
    HttpServer503VerbosityProperty,
    HttpServerBindingProperty,
    HttpServerExtendedAuthenticationProperty,
    HttpServerListenEndpointProperty,
    HttpServerChannelBindProperty,
    HttpServerProtectionLevelProperty
  );

  /// <summary>The verb of a request. <c>HttpVerbUnknown</c> means the verb is
  /// in <c>pUnknownVerb</c> instead.</summary>
  HTTP_VERB = (
    HttpVerbUnparsed = 0,
    HttpVerbUnknown,
    HttpVerbInvalid,
    HttpVerbOPTIONS,
    HttpVerbGET,
    HttpVerbHEAD,
    HttpVerbPOST,
    HttpVerbPUT,
    HttpVerbDELETE,
    HttpVerbTRACE,
    HttpVerbCONNECT,
    HttpVerbTRACK,
    HttpVerbMOVE,
    HttpVerbCOPY,
    HttpVerbPROPFIND,
    HttpVerbPROPPATCH,
    HttpVerbMKCOL,
    HttpVerbLOCK,
    HttpVerbUNLOCK,
    HttpVerbSEARCH,
    HttpVerbMaximum
  );

  /// <summary>The request headers the kernel knows by name. The ones it does
  /// not are in the unknown-header array, which is where <c>X-KittoX</c> and
  /// every other header of ours arrives.</summary>
  HTTP_HEADER_ID = (
    HttpHeaderCacheControl = 0,
    HttpHeaderConnection,
    HttpHeaderDate,
    HttpHeaderKeepAlive,
    HttpHeaderPragma,
    HttpHeaderTrailer,
    HttpHeaderTransferEncoding,
    HttpHeaderUpgrade,
    HttpHeaderVia,
    HttpHeaderWarning,
    HttpHeaderAllow,
    HttpHeaderContentLength,
    HttpHeaderContentType,
    HttpHeaderContentEncoding,
    HttpHeaderContentLanguage,
    HttpHeaderContentLocation,
    HttpHeaderContentMd5,
    HttpHeaderContentRange,
    HttpHeaderExpires,
    HttpHeaderLastModified,
    HttpHeaderAccept,
    HttpHeaderAcceptCharset,
    HttpHeaderAcceptEncoding,
    HttpHeaderAcceptLanguage,
    HttpHeaderAuthorization,
    HttpHeaderCookie,
    HttpHeaderExpect,
    HttpHeaderFrom,
    HttpHeaderHost,
    HttpHeaderIfMatch,
    HttpHeaderIfModifiedSince,
    HttpHeaderIfNoneMatch,
    HttpHeaderIfRange,
    HttpHeaderIfUnmodifiedSince,
    HttpHeaderMaxForwards,
    HttpHeaderProxyAuthorization,
    HttpHeaderReferer,
    HttpHeaderRange,
    HttpHeaderTe,
    HttpHeaderTranslate,
    HttpHeaderUserAgent,
    HttpHeaderRequestMaximum
  );

  /// <summary>The response headers the kernel knows by name. A header that is
  /// not here travels as an unknown one, with its name spelled out.</summary>
  HTTP_RESPONSE_HEADER_ID = (
    HttpHeaderResponseCacheControl = 0,
    HttpHeaderResponseConnection,
    HttpHeaderResponseDate,
    HttpHeaderResponseKeepAlive,
    HttpHeaderResponsePragma,
    HttpHeaderResponseTrailer,
    HttpHeaderResponseTransferEncoding,
    HttpHeaderResponseUpgrade,
    HttpHeaderResponseVia,
    HttpHeaderResponseWarning,
    HttpHeaderResponseAllow,
    HttpHeaderResponseContentLength,
    HttpHeaderResponseContentType,
    HttpHeaderResponseContentEncoding,
    HttpHeaderResponseContentLanguage,
    HttpHeaderResponseContentLocation,
    HttpHeaderResponseContentMd5,
    HttpHeaderResponseContentRange,
    HttpHeaderResponseExpires,
    HttpHeaderResponseLastModified,
    HttpHeaderResponseAcceptRanges,
    HttpHeaderResponseAge,
    HttpHeaderResponseEtag,
    HttpHeaderResponseLocation,
    HttpHeaderResponseProxyAuthenticate,
    HttpHeaderResponseRetryAfter,
    HttpHeaderResponseServer,
    HttpHeaderResponseSetCookie,
    HttpHeaderResponseVary,
    HttpHeaderResponseWwwAuthenticate,
    HttpHeaderResponseMaximum
  );

  HTTP_DATA_CHUNK_TYPE = (
    HttpDataChunkFromMemory = 0,
    HttpDataChunkFromFileHandle,
    HttpDataChunkFromFragmentCache,
    HttpDataChunkFromFragmentCacheEx,
    HttpDataChunkTrailers,
    HttpDataChunkMaximum
  );

  HTTP_VERSION = record
    MajorVersion: USHORT;
    MinorVersion: USHORT;
  end;

  HTTP_KNOWN_HEADER = record
    RawValueLength: USHORT;
    pRawValue: PAnsiChar;
  end;
  PHTTP_KNOWN_HEADER = ^HTTP_KNOWN_HEADER;

  HTTP_UNKNOWN_HEADER = record
    NameLength: USHORT;
    RawValueLength: USHORT;
    pName: PAnsiChar;
    pRawValue: PAnsiChar;
  end;
  PHTTP_UNKNOWN_HEADER = ^HTTP_UNKNOWN_HEADER;

  HTTP_REQUEST_HEADERS = record
    UnknownHeaderCount: USHORT;
    pUnknownHeaders: PHTTP_UNKNOWN_HEADER;
    TrailerCount: USHORT;
    pTrailers: PHTTP_UNKNOWN_HEADER;
    KnownHeaders: array[0..Ord(HttpHeaderRequestMaximum) - 1] of HTTP_KNOWN_HEADER;
  end;

  HTTP_RESPONSE_HEADERS = record
    UnknownHeaderCount: USHORT;
    pUnknownHeaders: PHTTP_UNKNOWN_HEADER;
    TrailerCount: USHORT;
    pTrailers: PHTTP_UNKNOWN_HEADER;
    KnownHeaders: array[0..Ord(HttpHeaderResponseMaximum) - 1] of HTTP_KNOWN_HEADER;
  end;

  /// <summary>The URL as the kernel parsed it, in UTF-16: this is where the
  /// path and the query string come from, already decoded and canonicalized -
  /// which is one thing less to get wrong than parsing the raw bytes.</summary>
  HTTP_COOKED_URL = record
    FullUrlLength: USHORT;
    HostLength: USHORT;
    AbsPathLength: USHORT;
    QueryStringLength: USHORT;
    pFullUrl: PWideChar;
    pHost: PWideChar;
    pAbsPath: PWideChar;
    pQueryString: PWideChar;
  end;

  HTTP_TRANSPORT_ADDRESS = record
    // PSOCKADDR, kept as a plain pointer so this unit does not have to pick
    // between WinSock and WinSock2.
    pRemoteAddress: Pointer;
    pLocalAddress: Pointer;
  end;

  HTTP_DATA_CHUNK = record
    DataChunkType: HTTP_DATA_CHUNK_TYPE;
    case Integer of
      0: (FromMemory: record
            pBuffer: Pointer;
            BufferLength: ULONG;
          end);
      1: (FromFileHandle: record
            ByteRange_StartingOffset: ULARGE_INTEGER;
            ByteRange_Length: ULARGE_INTEGER;
            FileHandle: THandle;
          end);
  end;
  PHTTP_DATA_CHUNK = ^HTTP_DATA_CHUNK;

  HTTP_SSL_INFO = record
    ServerCertKeySize: USHORT;
    ConnectionKeySize: USHORT;
    ServerCertIssuerSize: ULONG;
    ServerCertSubjectSize: ULONG;
    pServerCertIssuer: PAnsiChar;
    pServerCertSubject: PAnsiChar;
    pClientCertInfo: Pointer;
    SslClientCertNegotiated: ULONG;
  end;
  PHTTP_SSL_INFO = ^HTTP_SSL_INFO;

  HTTP_REQUEST_V1 = record
    Flags: ULONG;
    ConnectionId: HTTP_CONNECTION_ID;
    RequestId: HTTP_REQUEST_ID;
    UrlContext: HTTP_URL_CONTEXT;
    Version: HTTP_VERSION;
    Verb: HTTP_VERB;
    UnknownVerbLength: USHORT;
    RawUrlLength: USHORT;
    pUnknownVerb: PAnsiChar;
    pRawUrl: PAnsiChar;
    CookedUrl: HTTP_COOKED_URL;
    Address: HTTP_TRANSPORT_ADDRESS;
    Headers: HTTP_REQUEST_HEADERS;
    BytesReceived: ULONGLONG;
    EntityChunkCount: USHORT;
    pEntityChunks: PHTTP_DATA_CHUNK;
    RawConnectionId: HTTP_RAW_CONNECTION_ID;
    pSslInfo: PHTTP_SSL_INFO;
  end;
  PHTTP_REQUEST_V1 = ^HTTP_REQUEST_V1;

  /// <summary>Version 2 of the request: the same thing with two fields more at
  /// the end. Received as a V2 and read as a V1, which is what the fields this
  /// host needs live in.</summary>
  HTTP_REQUEST_V2 = record
    Base: HTTP_REQUEST_V1;
    RequestInfoCount: USHORT;
    pRequestInfo: Pointer;
  end;
  PHTTP_REQUEST_V2 = ^HTTP_REQUEST_V2;

  HTTP_REQUEST = HTTP_REQUEST_V2;
  PHTTP_REQUEST = PHTTP_REQUEST_V2;

  HTTP_RESPONSE_V1 = record
    Flags: ULONG;
    Version: HTTP_VERSION;
    StatusCode: USHORT;
    ReasonLength: USHORT;
    pReason: PAnsiChar;
    Headers: HTTP_RESPONSE_HEADERS;
    EntityChunkCount: USHORT;
    pEntityChunks: PHTTP_DATA_CHUNK;
  end;
  PHTTP_RESPONSE_V1 = ^HTTP_RESPONSE_V1;

  HTTP_RESPONSE_V2 = record
    Base: HTTP_RESPONSE_V1;
    ResponseInfoCount: USHORT;
    pResponseInfo: Pointer;
  end;
  PHTTP_RESPONSE_V2 = ^HTTP_RESPONSE_V2;

  HTTP_RESPONSE = HTTP_RESPONSE_V2;
  PHTTP_RESPONSE = PHTTP_RESPONSE_V2;

  /// <summary>Says whether a property is present. Every v2 property structure
  /// starts with one of these.</summary>
  HTTP_PROPERTY_FLAGS = record
    /// <summary>Bit 0 is 'Present'; the other 31 are reserved.</summary>
    Flags: ULONG;
  end;

  /// <summary>Binds a URL group to a request queue: this is the v2 way of
  /// saying where the requests of these URLs must be delivered.</summary>
  HTTP_BINDING_INFO = record
    Flags: HTTP_PROPERTY_FLAGS;
    RequestQueueHandle: THandle;
  end;

  /// <summary>The timeouts of a server session, in seconds. Zero means 'leave
  /// the default of the kernel alone', per field.</summary>
  HTTP_TIMEOUT_LIMIT_INFO = record
    Flags: HTTP_PROPERTY_FLAGS;
    EntityBody: USHORT;
    DrainEntityBody: USHORT;
    RequestQueue: USHORT;
    IdleConnection: USHORT;
    HeaderWait: USHORT;
    MinSendRate: ULONG;
  end;

/// <summary>Initializes the API. Must be balanced by <c>HttpTerminate</c>.</summary>
function HttpInitialize(Version: HTTP_VERSION; Flags: ULONG;
  pReserved: Pointer): ULONG; stdcall;

/// <summary>Releases what <c>HttpInitialize</c> took.</summary>
function HttpTerminate(Flags: ULONG; pReserved: Pointer): ULONG; stdcall;

/// <summary>Creates a server session, which is what the properties - timeouts,
/// queue length, connection limit - belong to.</summary>
function HttpCreateServerSession(Version: HTTP_VERSION;
  var pServerSessionId: HTTP_SERVER_SESSION_ID; Reserved: ULONG): ULONG; stdcall;

function HttpCloseServerSession(ServerSessionId: HTTP_SERVER_SESSION_ID): ULONG; stdcall;

/// <summary>Creates a URL group inside a server session: the set of URLs this
/// host answers for.</summary>
function HttpCreateUrlGroup(ServerSessionId: HTTP_SERVER_SESSION_ID;
  var pUrlGroupId: HTTP_URL_GROUP_ID; Reserved: ULONG): ULONG; stdcall;

function HttpCloseUrlGroup(UrlGroupId: HTTP_URL_GROUP_ID): ULONG; stdcall;

/// <summary>Creates the request queue the kernel delivers into.</summary>
function HttpCreateRequestQueue(Version: HTTP_VERSION; pName: PWideChar;
  pSecurityAttributes: Pointer; Flags: ULONG;
  var pReqQueueHandle: THandle): ULONG; stdcall;

function HttpCloseRequestQueue(ReqQueueHandle: THandle): ULONG; stdcall;

/// <summary>Sets a property of a URL group - the binding to a queue, above
/// all.</summary>
function HttpSetUrlGroupProperty(UrlGroupId: HTTP_URL_GROUP_ID;
  aProperty: HTTP_SERVER_PROPERTY; pPropertyInformation: Pointer;
  PropertyInformationLength: ULONG): ULONG; stdcall;

/// <summary>Sets a property of a server session - the timeouts, the length of
/// the queue, the limit on connections.</summary>
function HttpSetServerSessionProperty(ServerSessionId: HTTP_SERVER_SESSION_ID;
  aProperty: HTTP_SERVER_PROPERTY; pPropertyInformation: Pointer;
  PropertyInformationLength: ULONG): ULONG; stdcall;

/// <summary>Adds a URL prefix to a group. This is where a missing URL
/// reservation shows up, as ERROR_ACCESS_DENIED.</summary>
function HttpAddUrlToUrlGroup(UrlGroupId: HTTP_URL_GROUP_ID;
  pFullyQualifiedUrl: PWideChar; UrlContext: HTTP_URL_CONTEXT;
  Reserved: ULONG): ULONG; stdcall;

function HttpRemoveUrlFromUrlGroup(UrlGroupId: HTTP_URL_GROUP_ID;
  pFullyQualifiedUrl: PWideChar; Flags: ULONG): ULONG; stdcall;

/// <summary>Takes the next request out of the queue, blocking until one
/// arrives or the queue is closed.</summary>
function HttpReceiveHttpRequest(ReqQueueHandle: THandle; RequestId: HTTP_REQUEST_ID;
  Flags: ULONG; pRequestBuffer: PHTTP_REQUEST; RequestBufferLength: ULONG;
  var pBytesReceived: ULONG; pOverlapped: POverlapped): ULONG; stdcall;

/// <summary>Reads the part of the body that did not come with the
/// request.</summary>
function HttpReceiveRequestEntityBody(ReqQueueHandle: THandle;
  RequestId: HTTP_REQUEST_ID; Flags: ULONG; pBuffer: Pointer;
  BufferLength: ULONG; var pBytesReceived: ULONG;
  pOverlapped: POverlapped): ULONG; stdcall;

/// <summary>Sends status, headers and - unless more is coming - the
/// body.</summary>
function HttpSendHttpResponse(ReqQueueHandle: THandle; RequestId: HTTP_REQUEST_ID;
  Flags: ULONG; pHttpResponse: PHTTP_RESPONSE; pCachePolicy: Pointer;
  var pBytesSent: ULONG; pReserved1: Pointer; Reserved2: ULONG;
  pOverlapped: POverlapped; pLogData: Pointer): ULONG; stdcall;

/// <summary>Sends more body for a response opened with MORE_DATA.</summary>
function HttpSendResponseEntityBody(ReqQueueHandle: THandle;
  RequestId: HTTP_REQUEST_ID; Flags: ULONG; EntityChunkCount: USHORT;
  pEntityChunks: PHTTP_DATA_CHUNK; var pBytesSent: ULONG; pReserved1: Pointer;
  Reserved2: ULONG; pOverlapped: POverlapped; pLogData: Pointer): ULONG; stdcall;

/// <summary>The version structure for 2.0, which is what this unit asks
/// for.</summary>
function KXHttpApiVersion2: HTTP_VERSION;

/// <summary>True when <c>httpapi.dll</c> is there and answers - which on any
/// supported Windows it is.</summary>
function KXHttpSysAvailable: Boolean;

/// <summary>A Windows error code as a sentence, with the code in it: a host
/// that cannot start must say why in a way that can be searched for.</summary>
function KXHttpSysErrorText(const AError: ULONG; const AContext: string): string;

{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

uses
  System.SysUtils
  ;

function HttpInitialize; external HTTPAPI_DLL;
function HttpTerminate; external HTTPAPI_DLL;
function HttpCreateServerSession; external HTTPAPI_DLL;
function HttpCloseServerSession; external HTTPAPI_DLL;
function HttpCreateUrlGroup; external HTTPAPI_DLL;
function HttpCloseUrlGroup; external HTTPAPI_DLL;
function HttpCreateRequestQueue; external HTTPAPI_DLL;
function HttpSetUrlGroupProperty; external HTTPAPI_DLL;
function HttpSetServerSessionProperty; external HTTPAPI_DLL;
function HttpAddUrlToUrlGroup; external HTTPAPI_DLL;
function HttpRemoveUrlFromUrlGroup; external HTTPAPI_DLL;
function HttpReceiveHttpRequest; external HTTPAPI_DLL;
function HttpReceiveRequestEntityBody; external HTTPAPI_DLL;
function HttpSendHttpResponse; external HTTPAPI_DLL;
function HttpSendResponseEntityBody; external HTTPAPI_DLL;

function HttpCloseRequestQueue(ReqQueueHandle: THandle): ULONG;
begin
  // There is an HttpCloseRequestQueue in the DLL, but closing the handle is
  // what it does and it is what works on every version: the queue is a kernel
  // object like any other.
  if ReqQueueHandle = 0 then
    Exit(NO_ERROR);
  if Winapi.Windows.CloseHandle(ReqQueueHandle) then
    Result := NO_ERROR
  else
    Result := GetLastError;
end;

function KXHttpApiVersion2: HTTP_VERSION;
begin
  Result.MajorVersion := 2;
  Result.MinorVersion := 0;
end;

function KXHttpSysAvailable: Boolean;
var
  LModule: HMODULE;
begin
  LModule := LoadLibrary(HTTPAPI_DLL);
  Result := LModule <> 0;
  if Result then
    FreeLibrary(LModule);
end;

function KXHttpSysErrorText(const AError: ULONG; const AContext: string): string;
var
  LMessage: string;
begin
  LMessage := Trim(SysErrorMessage(AError));
  if LMessage = '' then
    LMessage := 'unknown error';
  Result := Format('%s failed: %d (%s)', [AContext, AError, LMessage]);
  // The two that are worth explaining rather than reporting: they are what a
  // first run hits, and the message of the system does not say what to do.
  case AError of
    ERROR_ACCESS_DENIED:
      Result := Result + '. The URL is not reserved for this account: run ' +
        'netsh http add urlacl url=<the url> user=<the account>, or listen on ' +
        'localhost, or run elevated.';
    ERROR_SHARING_VIOLATION, ERROR_ALREADY_EXISTS:
      Result := Result + '. Another process - another application, or IIS - ' +
        'already answers for this URL.';
  end;
end;

{$ENDIF}

end.
