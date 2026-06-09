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

unit Kitto.Web.Server;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  IdCustomHTTPServer,
  IdContext,
  Web.HTTPApp,
  Kitto.Config,
  Kitto.Web.Engine,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Web.URL;

type
  /// <summary>
  ///  Indy-based HTTP server implementation for stand-alone Kitto applications
  ///  (GUI, console, service, daemon modes). Encapsulates a TKWebEngine and
  ///  a thread scheduler.
  /// </summary>
  TKWebServer = class(TIdCustomHTTPServer)
  private
    FEngine: TKWebEngine;
    procedure InitThreadScheduler(const AThreadPoolSize: Integer);
  protected
    procedure Startup; override;
    procedure Shutdown; override;
    procedure DoCommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo); override;
    procedure DoCommandOther(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo); override;
  public
    procedure Setup(AConfig: TKConfig);
    procedure AfterConstruction; override;
    destructor Destroy; override;
  public
    // Internal object; we might add ability to provide it externally at some point if needed.
    property Engine: TKWebEngine read FEngine;
  end;

implementation

uses
  System.StrUtils,
  System.Classes,
  System.IOUtils,
  IdHTTPWebBrokerBridge,
  IdSchedulerOfThreadPool,
  EF.Logger,
  EF.StrUtils,
  Kitto.Web.Types;

{ TKWebServer }

procedure TKWebServer.AfterConstruction;
var
  LConfig: TKConfig;
begin
  inherited;
  FEngine := TKWebEngine.Create;
  // Standard config objects are per application; we need to create our own
  // instance in order to read server-wide params.
  LConfig := TKConfig.Create;
  try
    Setup(LConfig);
  finally
    FreeAndNil(LConfig);
  end;
end;

destructor TKWebServer.Destroy;
begin
  FreeAndNil(FEngine);
  inherited;
end;

procedure TKWebServer.DoCommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  LRequest: TWebRequest;
  LResponse: TWebResponse;
  LStream: TStream;
begin
  inherited;
  Assert(Assigned(FEngine));

  LRequest := TIdHTTPAppRequest.Create(AContext, ARequestInfo, AResponseInfo);
  LResponse := TIdHTTPAppResponse.Create(LRequest, AContext, ARequestInfo, AResponseInfo);
  // Switch content stream ownership so that we have it still alive in AResponseInfo
  // which will destroy it later.
  LResponse.FreeContentStream := False;
  AResponseInfo.FreeContentStream := True;
  FEngine.SimpleHandleRequest(LRequest, LResponse, ARequestInfo.Document, True, True);
  // After DoCommandGet returns, Indy's TIdHTTPServerContext.Run checks:
  //   if Assigned(ContentStream) then WriteContent;
  // This second WriteContent would seek the stream back to 0 and re-write the entire
  // response body — a wasted duplicate send.  If the client closed the connection
  // (e.g. a browser PDF viewer that already has what it needs), it also raises
  // EIdSocketError.  Take unconditional ownership of the stream and nil it out so
  // Indy skips the check entirely.
  if Assigned(AResponseInfo.ContentStream) then
  begin
    LStream := AResponseInfo.ContentStream;
    AResponseInfo.FreeContentStream := False; // we take ownership — Indy destructor won't free
    AResponseInfo.ContentStream := nil;        // direct field write; Indy skips WriteContent
    FreeAndNil(LStream);
  end;
end;

procedure TKWebServer.DoCommandOther(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  inherited;
  DoCommandGet(AContext, ARequestInfo, AResponseInfo);
end;

procedure TKWebServer.InitThreadScheduler(const AThreadPoolSize: Integer);
var
  LScheduler: TIdSchedulerOfThreadPool;
begin
  if Assigned(Scheduler) then
  begin
    Scheduler.Free;
    Scheduler := nil;
  end;

  LScheduler := TIdSchedulerOfThreadPool.Create(Self);
  LScheduler.PoolSize := AThreadPoolSize;
  Scheduler := LScheduler;
  // MaxConnections must NOT be capped to PoolSize. With TIdSchedulerOfThreadPool,
  // PoolSize only sets how many worker threads are kept warm in the pool — Indy
  // spawns transient threads on demand beyond it. Setting MaxConnections =
  // PoolSize artificially refuses the (PoolSize+1)-th concurrent connection and,
  // worse, makes Indy close the excess socket (handle -> -1 = INVALID_SOCKET);
  // a follow-up op on that closed handle raises a first-chance AV
  // ("reading 0xFFFFFFFFFFFFFFFF") that Indy swallows internally — invisible
  // standalone, but the native Win64 IDE debugger breaks on it. 0 = unlimited:
  // the pool keeps PoolSize warm threads, never refuses a connection, no
  // closed-socket AV. See KITTOX.md for the full diagnosis.
  MaxConnections := 0;
end;

procedure TKWebServer.Setup(AConfig: TKConfig);
var
  LThreadPoolSize: Integer;
  LBindAddress: string;
begin
  DefaultPort := AConfig.Config.GetInteger('Server/Port', 8080);
  LThreadPoolSize := AConfig.Config.GetInteger('Server/ThreadPoolSize', 20);
  InitThreadScheduler(LThreadPoolSize);
  // Server/BindAddress: restrict to a specific interface (e.g. '127.0.0.1'
  // for desktop/embedded mode to avoid Windows Firewall prompts).
  // Default is empty = listen on all interfaces (0.0.0.0).
  LBindAddress := AConfig.Config.GetString('Server/BindAddress');
  if LBindAddress <> '' then
  begin
    Bindings.Clear;
    with Bindings.Add do
    begin
      IP := LBindAddress;
      Port := DefaultPort;
    end;
  end;
end;

procedure TKWebServer.Shutdown;
begin
  inherited;
  Bindings.Clear;
  FEngine.Active := False;
end;

procedure TKWebServer.Startup;
begin
  FEngine.Active := True;
  Bindings.Clear;
  inherited;
end;

end.

