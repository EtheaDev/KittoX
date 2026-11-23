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
///  The HTTP.sys host: a KittoX application served by the kernel-mode HTTP
///  stack of Windows instead of by Indy.
///  <para>What it buys, and why it exists beside the Indy host rather than in
///  place of it, is in <c>KittoX_HttpSys.md</c>. The three reasons in one
///  line: TLS on a standalone application without shipping OpenSSL, several
///  processes sharing one port, and requests queued by the kernel while an
///  application restarts.</para>
///  <para>Shape of it: one thread takes requests out of the queue and does
///  nothing else; everything after that - reading the rest of the body, the
///  whole pipeline, the answer - runs on the default task pool. The listener
///  must never be the slow part, or the queue grows while a thread waits for a
///  database.</para>
/// </summary>
unit Kitto.Web.Server.HttpSys;

{$I Kitto.Defines.inc}

interface

{$IFDEF MSWINDOWS}

uses
  System.SysUtils
  , System.Classes
  , Winapi.Windows
  , Kitto.Config
  , Kitto.Web.Engine
  , Kitto.Web.HttpSysApi
  ;

type
  /// <summary>
  ///  Serves a <see cref="TKWebEngine" /> through HTTP.sys. Same shape as the
  ///  Indy host: it owns the engine, <c>Setup</c> reads the configuration and
  ///  <c>Active</c> starts and stops it.
  /// </summary>
  TKHttpSysServer = class
  strict private
    FEngine: TKWebEngine;
    FQueue: THandle;
    FSession: HTTP_SERVER_SESSION_ID;
    FUrlGroup: HTTP_URL_GROUP_ID;
    FListener: TThread;
    FActive: Boolean;
    FPort: Integer;
    FBindAddress: string;
    FUrlPrefix: string;
    FMaxRequestBytes: Int64;
    FApiInitialized: Boolean;
    FUrlAdded: Boolean;
    procedure Check(const AResult: ULONG; const AContext: string);
    procedure SetActive(const AValue: Boolean);
    procedure Open;
    procedure Close;
    procedure ApplyTimeouts(const AIdleSeconds, AHeaderWaitSeconds: Integer);
    procedure ApplyQueueLength(const ALength: Integer);
    /// <summary>Reads what did not come with the request. Runs on a worker,
    /// never on the listener.</summary>
    function ReadRemainingBody(const ARequest: PHTTP_REQUEST;
      const AInitial: TBytes; out ATooLarge: Boolean): TBytes;
    procedure DispatchAsync(const ABuffer, AInitialBody: TBytes);
    procedure HandleOne(const ARequest: PHTTP_REQUEST; const ABody: TBytes);
    procedure SendBare(const ARequestId: HTTP_REQUEST_ID;
      const AStatusCode: Integer; const AText: string);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Reads port, bind address and limits from Config.yaml, exactly
    /// as the Indy host does - an application does not configure the host it
    /// happens to run on, it configures its server.</summary>
    procedure Setup(const AConfig: TKConfig);

    /// <summary>The engine this host serves.</summary>
    property Engine: TKWebEngine read FEngine;
    /// <summary>Starting and stopping.</summary>
    property Active: Boolean read FActive write SetActive;
    /// <summary>The port it listens on.</summary>
    property DefaultPort: Integer read FPort write FPort;
    /// <summary>Which interface to answer for. Empty is every one of them,
    /// which with this stack is the strong wildcard and needs a URL
    /// reservation; <c>localhost</c> is the one that needs none, and is what
    /// makes a first run possible without netsh.</summary>
    property BindAddress: string read FBindAddress write FBindAddress;
    /// <summary>The URL prefix registered with the kernel, once it is
    /// listening: useful in a log line and in the main form.</summary>
    property UrlPrefix: string read FUrlPrefix;
  end;

{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

uses
  System.Threading
  , System.Math
  , EF.Logger
  , EF.Localization
  , Kitto.Config.Server
  , Kitto.Web.HttpSys
  ;

const
  /// <summary>Buffer handed to the kernel for one request. Headers and a small
  /// body fit in it; a bigger body is read afterwards, on the worker.</summary>
  INITIAL_REQUEST_BUFFER = 16 * 1024;
  /// <summary>How much is read at a time when going back for the rest of a
  /// body.</summary>
  BODY_CHUNK = 64 * 1024;
  /// <summary>Default cap on a request body. A host that accepts anything is a
  /// host anybody can fill the memory of.</summary>
  DEF_MAXREQUEST_MB = 32;

{ TKHttpSysServer }

constructor TKHttpSysServer.Create;
var
  LConfig: TKConfig;
begin
  inherited Create;
  FEngine := TKWebEngine.Create;
  FPort := 8080;
  FMaxRequestBytes := Int64(DEF_MAXREQUEST_MB) * 1024 * 1024;
  // Server-wide parameters live in a config of their own, as they do for the
  // Indy host: the application configs are per application.
  LConfig := TKConfig.Create;
  try
    Setup(LConfig);
  finally
    LConfig.Free;
  end;
end;

destructor TKHttpSysServer.Destroy;
begin
  Active := False;
  FEngine.Free;
  inherited;
end;

procedure TKHttpSysServer.Setup(const AConfig: TKConfig);
begin
  Assert(Assigned(AConfig));
  FPort := AConfig.Config.GetInteger('Server/Port', 8080);
  FBindAddress := AConfig.Config.GetString('Server/BindAddress');
  FMaxRequestBytes := Int64(AConfig.Config.GetInteger('Server/MaxRequestSizeMB',
    DEF_MAXREQUEST_MB)) * 1024 * 1024;
  if FMaxRequestBytes < 0 then
    FMaxRequestBytes := 0;
end;

procedure TKHttpSysServer.Check(const AResult: ULONG; const AContext: string);
begin
  if AResult <> NO_ERROR then
    raise Exception.Create(KXHttpSysErrorText(AResult, AContext));
end;

procedure TKHttpSysServer.ApplyTimeouts(const AIdleSeconds, AHeaderWaitSeconds: Integer);
var
  LTimeouts: HTTP_TIMEOUT_LIMIT_INFO;
begin
  if (AIdleSeconds <= 0) and (AHeaderWaitSeconds <= 0) then
    Exit;
  FillChar(LTimeouts, SizeOf(LTimeouts), 0);
  LTimeouts.Flags.Flags := 1; // present
  LTimeouts.IdleConnection := Max(0, Min(AIdleSeconds, High(Word)));
  LTimeouts.HeaderWait := Max(0, Min(AHeaderWaitSeconds, High(Word)));
  // Not fatal: a kernel that refuses a timeout still serves requests, and
  // refusing to start over it would be worse than the default it keeps.
  if HttpSetServerSessionProperty(FSession, HttpServerTimeoutsProperty,
    @LTimeouts, SizeOf(LTimeouts)) <> NO_ERROR then
    TEFLogger.Instance.Log('HTTP.sys: the timeouts were not applied.',
      TEFLogger.LOG_DETAILED);
end;

procedure TKHttpSysServer.ApplyQueueLength(const ALength: Integer);
var
  LLength: ULONG;
begin
  if ALength <= 0 then
    Exit;
  LLength := ALength;
  if HttpSetServerSessionProperty(FSession, HttpServerQueueLengthProperty,
    @LLength, SizeOf(LLength)) <> NO_ERROR then
    TEFLogger.Instance.Log('HTTP.sys: the queue length was not applied.',
      TEFLogger.LOG_DETAILED);
end;

procedure TKHttpSysServer.Open;
var
  LVersion: HTTP_VERSION;
  LBinding: HTTP_BINDING_INFO;
  LHost: string;
begin
  LVersion := KXHttpApiVersion2;
  Check(HttpInitialize(LVersion, HTTP_INITIALIZE_SERVER, nil), 'HttpInitialize');
  FApiInitialized := True;

  Check(HttpCreateServerSession(LVersion, FSession, 0), 'HttpCreateServerSession');
  Check(HttpCreateUrlGroup(FSession, FUrlGroup, 0), 'HttpCreateUrlGroup');
  Check(HttpCreateRequestQueue(LVersion, nil, nil, 0, FQueue), 'HttpCreateRequestQueue');

  // The binding is what ties the URLs of the group to this queue. Without it
  // the kernel accepts the URL and delivers the requests nowhere.
  FillChar(LBinding, SizeOf(LBinding), 0);
  LBinding.Flags.Flags := 1; // present
  LBinding.RequestQueueHandle := FQueue;
  Check(HttpSetUrlGroupProperty(FUrlGroup, HttpServerBindingProperty,
    @LBinding, SizeOf(LBinding)), 'HttpSetUrlGroupProperty(binding)');

  // An empty bind address means every interface, as it does for Indy; with
  // HTTP.sys that is the strong wildcard, which needs a URL reservation.
  // 'localhost' is the one prefix that normally needs none, which is what
  // makes a first run possible without netsh.
  LHost := FBindAddress;
  if LHost = '' then
    LHost := '+';
  FUrlPrefix := Format('http://%s:%d/', [LHost, FPort]);
  Check(HttpAddUrlToUrlGroup(FUrlGroup, PWideChar(FUrlPrefix), 0, 0),
    Format('HttpAddUrlToUrlGroup(%s)', [FUrlPrefix]));
  FUrlAdded := True;
end;

procedure TKHttpSysServer.Close;
begin
  if FUrlAdded and (FUrlGroup <> 0) then
  begin
    HttpRemoveUrlFromUrlGroup(FUrlGroup, PWideChar(FUrlPrefix), 0);
    FUrlAdded := False;
  end;
  if FUrlGroup <> 0 then
  begin
    HttpCloseUrlGroup(FUrlGroup);
    FUrlGroup := 0;
  end;
  if FQueue <> 0 then
  begin
    HttpCloseRequestQueue(FQueue);
    FQueue := 0;
  end;
  if FSession <> 0 then
  begin
    HttpCloseServerSession(FSession);
    FSession := 0;
  end;
  if FApiInitialized then
  begin
    HttpTerminate(HTTP_INITIALIZE_SERVER, nil);
    FApiInitialized := False;
  end;
end;

procedure TKHttpSysServer.SendBare(const ARequestId: HTTP_REQUEST_ID;
  const AStatusCode: Integer; const AText: string);
var
  LResponse: HTTP_RESPONSE;
  LChunk: HTTP_DATA_CHUNK;
  LReason, LBody, LType: AnsiString;
  LSent: ULONG;
begin
  FillChar(LResponse, SizeOf(LResponse), 0);
  LResponse.Base.Version.MajorVersion := 1;
  LResponse.Base.Version.MinorVersion := 1;
  LResponse.Base.StatusCode := AStatusCode;
  LReason := UTF8Encode(KXHttpSysReasonOf(AStatusCode));
  LResponse.Base.pReason := PAnsiChar(LReason);
  LResponse.Base.ReasonLength := Length(LReason);
  LType := 'text/plain; charset=utf-8';
  LResponse.Base.Headers.KnownHeaders[Ord(HttpHeaderResponseContentType)].pRawValue := PAnsiChar(LType);
  LResponse.Base.Headers.KnownHeaders[Ord(HttpHeaderResponseContentType)].RawValueLength := Length(LType);
  LBody := UTF8Encode(AText);
  if Length(LBody) > 0 then
  begin
    FillChar(LChunk, SizeOf(LChunk), 0);
    LChunk.DataChunkType := HttpDataChunkFromMemory;
    LChunk.FromMemory.pBuffer := PAnsiChar(LBody);
    LChunk.FromMemory.BufferLength := Length(LBody);
    LResponse.Base.EntityChunkCount := 1;
    LResponse.Base.pEntityChunks := @LChunk;
  end;
  LSent := 0;
  HttpSendHttpResponse(FQueue, ARequestId, 0, @LResponse, nil, LSent, nil, 0, nil, nil);
end;

function TKHttpSysServer.ReadRemainingBody(const ARequest: PHTTP_REQUEST;
  const AInitial: TBytes; out ATooLarge: Boolean): TBytes;
var
  LChunk: TBytes;
  LRead: ULONG;
  LResult: ULONG;
  LTotal: Int64;
  LOld: Integer;
begin
  Result := AInitial;
  ATooLarge := False;
  if (ARequest.Base.Flags and HTTP_REQUEST_FLAG_MORE_ENTITY_BODY_EXISTS) = 0 then
    Exit;

  SetLength(LChunk, BODY_CHUNK);
  repeat
    LRead := 0;
    LResult := HttpReceiveRequestEntityBody(FQueue, ARequest.Base.RequestId, 0,
      @LChunk[0], Length(LChunk), LRead, nil);
    if (LResult = NO_ERROR) and (LRead > 0) then
    begin
      LTotal := Int64(Length(Result)) + LRead;
      if (FMaxRequestBytes > 0) and (LTotal > FMaxRequestBytes) then
      begin
        ATooLarge := True;
        Exit;
      end;
      LOld := Length(Result);
      SetLength(Result, LOld + Integer(LRead));
      Move(LChunk[0], Result[LOld], LRead);
    end;
  until (LResult <> NO_ERROR) or (LRead = 0);
end;

procedure TKHttpSysServer.HandleOne(const ARequest: PHTTP_REQUEST;
  const ABody: TBytes);
var
  LRequest: TKHttpSysRequest;
  LResponse: TKHttpSysResponse;
begin
  LRequest := TKHttpSysRequest.Create(ARequest, ABody);
  LResponse := TKHttpSysResponse.Create(LRequest, FQueue);
  try
    // The same call the Indy host makes, with the same two flags: the engine
    // owns the pair and answers every request, 404 included.
    FEngine.SimpleHandleRequest(LRequest, LResponse, LRequest.PathInfo, False, True);
    // Now, and only now: the wrappers of KittoX have closed and written
    // everything they had into the response. Whatever the engine decided -
    // an answer, a redirect, a 404 - this is what puts it on the wire, and a
    // request that nobody answered gets the empty 200 the response was born
    // with rather than a client left waiting.
    LResponse.Transmit;
  finally
    LResponse.Free;
    LRequest.Free;
  end;
end;

procedure TKHttpSysServer.DispatchAsync(const ABuffer, AInitialBody: TBytes);
var
  LServer: TKHttpSysServer;
begin
  LServer := Self;
  // The managed arrays are captured: they keep the buffer the request points
  // into alive for as long as the task runs, which is the whole reason the
  // listener allocates a new one every time round.
  TTask.Run(
    procedure
    var
      LRequest: PHTTP_REQUEST;
      LBody: TBytes;
      LTooLarge: Boolean;
    begin
      LRequest := PHTTP_REQUEST(@ABuffer[0]);
      try
        LBody := LServer.ReadRemainingBody(LRequest, AInitialBody, LTooLarge);
        if LTooLarge then
          LServer.SendBare(LRequest.Base.RequestId, 413,
            _('The request is larger than this server accepts.'))
        else
          LServer.HandleOne(LRequest, LBody);
      except
        on E: Exception do
        begin
          TEFLogger.Instance.LogHigh('HTTP.sys: ' + E.Message);
          // The client is waiting: something has to go back, whatever broke.
          try
            LServer.SendBare(LRequest.Base.RequestId, 500, E.Message);
          except
            // Nothing left to do: the connection is gone.
          end;
        end;
      end;
    end);
end;

procedure TKHttpSysServer.SetActive(const AValue: Boolean);
var
  LServer: TKHttpSysServer;
  LConfig: TKConfig;
begin
  if AValue = FActive then
    Exit;

  if AValue then
  begin
    // The engine first: activating it is what makes its routes live, and a
    // host that starts listening before doing it answers 404 to everything.
    // It is the one thing the Indy host does in Startup that is not about
    // Indy.
    FEngine.Active := True;
    Open;
    FActive := True;

    LConfig := TKConfig.Create;
    try
      ApplyQueueLength(LConfig.Config.GetInteger('Server/QueueLength', 0));
      ApplyTimeouts(LConfig.Config.GetInteger('Server/IdleTimeoutSec', 0),
        LConfig.Config.GetInteger('Server/HeaderWaitSec', 0));
    finally
      LConfig.Free;
    end;

    LServer := Self;
    FListener := TThread.CreateAnonymousThread(
      procedure
      var
        LBuffer: TBytes;
        LRequest: PHTTP_REQUEST;
        LReceived: ULONG;
        LResult: ULONG;
        LInitial, LChunkBytes: TBytes;
        LChunk: PHTTP_DATA_CHUNK;
        I: Integer;
      begin
        while LServer.FActive do
        begin
          // A fresh buffer every time round: the request points into it, and
          // it travels to a worker. Reusing it would mean handing two workers
          // the same bytes.
          LBuffer := nil;
          SetLength(LBuffer, INITIAL_REQUEST_BUFFER);
          LRequest := PHTTP_REQUEST(@LBuffer[0]);
          LReceived := 0;

          LResult := HttpReceiveHttpRequest(LServer.FQueue, 0,
            HTTP_RECEIVE_REQUEST_FLAG_COPY_BODY, LRequest, Length(LBuffer),
            LReceived, nil);

          if not LServer.FActive then
            Break;

          if LResult = ERROR_MORE_DATA then
          begin
            // The headers did not fit. Ask again for the SAME request with a
            // buffer that does: dropping it - which is what the sibling
            // project does here - loses a request whose only sin is a long
            // cookie or a long token.
            LBuffer := nil;
            SetLength(LBuffer, LReceived + 4096);
            LRequest := PHTTP_REQUEST(@LBuffer[0]);
            LResult := HttpReceiveHttpRequest(LServer.FQueue,
              LRequest.Base.RequestId, HTTP_RECEIVE_REQUEST_FLAG_COPY_BODY,
              LRequest, Length(LBuffer), LReceived, nil);
          end;

          if LResult = NO_ERROR then
          begin
            // What came with the request: a few memcpys, cheap enough to do
            // here. Everything heavier is the worker's.
            LInitial := nil;
            for I := 0 to LRequest.Base.EntityChunkCount - 1 do
            begin
              LChunk := PHTTP_DATA_CHUNK(NativeUInt(LRequest.Base.pEntityChunks) +
                NativeUInt(I) * SizeOf(HTTP_DATA_CHUNK));
              if LChunk.DataChunkType <> HttpDataChunkFromMemory then
                Continue;
              SetLength(LChunkBytes, LChunk.FromMemory.BufferLength);
              if Length(LChunkBytes) > 0 then
              begin
                Move(LChunk.FromMemory.pBuffer^, LChunkBytes[0], Length(LChunkBytes));
                LInitial := LInitial + LChunkBytes;
              end;
            end;
            LServer.DispatchAsync(LBuffer, LInitial);
          end
          else if (LResult <> ERROR_OPERATION_ABORTED) and LServer.FActive then
            TEFLogger.Instance.LogHigh(
              KXHttpSysErrorText(LResult, 'HttpReceiveHttpRequest'));
        end;
      end);
    FListener.FreeOnTerminate := False;
    FListener.Start;
    TEFLogger.Instance.Log(Format('HTTP.sys: listening on %s', [FUrlPrefix]));
  end
  else
  begin
    FActive := False;
    // Closing the queue is what unblocks the listener: it comes back with
    // ERROR_OPERATION_ABORTED and the loop ends.
    Close;
    FEngine.Active := False;
    if Assigned(FListener) then
    begin
      FListener.WaitFor;
      FreeAndNil(FListener);
    end;
  end;
end;

{$ENDIF}

end.
