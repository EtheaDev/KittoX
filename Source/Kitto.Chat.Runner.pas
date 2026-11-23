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
///  In-memory conversation store and asynchronous runner for the help chat.
///  <see cref="TKXChatStore" /> keeps one conversation per user (v1: single
///  thread, no DB persistence — the history lives for the session). Sending a
///  message appends the user message plus a <c>Pending</c> assistant message and
///  submits a request to <see cref="TKXChatRunner" />, a small worker pool
///  separate from the Indy request threads (so a slow provider call — e.g. an
///  LLM HTTP round-trip — never blocks the web server) and separate from the
///  notification job queue (so chat replies do not surface in the bell). The
///  worker calls the configured provider and writes the reply back into the
///  store; the client retrieves it by polling the chat poll endpoint.
/// </summary>
unit Kitto.Chat.Runner;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  Kitto.Chat.Provider;

type
  /// <summary>
  ///  In-memory conversation store, one conversation per key. Thread-safe: the
  ///  web (request) threads append messages and read history, while runner
  ///  (worker) threads complete the pending assistant messages. Process-global
  ///  singleton.
  ///  <para>The key is the <b>conversation</b>, which
  ///  <see cref="KXChatConversationKey" /> builds: the user alone while the
  ///  application declares one assistant - which is the usual case, and the key
  ///  it always had - the user and the assistant when it declares more, so that
  ///  the expert of one field and the expert of another do not end up answering
  ///  each other's questions in a single thread.</para>
  /// </summary>
  TKXChatStore = class
  strict private
    FLock: TCriticalSection;
    FConversations: TObjectDictionary<string, TList<TKXChatMessage>>;
    FMaxStoredMessages: Integer;
    function EnsureList(const AKey: string): TList<TKXChatMessage>;
    function IndexOfId(const AList: TList<TKXChatMessage>; const AId: string): Integer;
    procedure PruneLocked(const AList: TList<TKXChatMessage>);
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Appends a user message to the user's conversation and returns it.</summary>
    function AddUserMessage(const AKey, AContent: string): TKXChatMessage;
    /// <summary>Appends a placeholder assistant message (Pending) and returns its id;
    /// the runner later completes it in place.</summary>
    function AddPendingAssistant(const AKey: string): string;
    /// <summary>Appends AToken to the (still pending) assistant message AId,
    /// leaving it pending. A streaming provider calls this for each token, so the
    /// poll endpoint returns the growing partial reply and the drawer fills in
    /// incrementally without any server-push machinery.</summary>
    procedure AppendAssistantToken(const AKey, AId, AToken: string);
    /// <summary>Marks the pending assistant message AId as completed with AContent.</summary>
    procedure CompleteAssistant(const AKey, AId, AContent: string);
    /// <summary>Closes a pending assistant message keeping whatever it already
    /// holds (the partial of a streaming reply that was cancelled); when it holds
    /// nothing, AFallback is used instead. Returns False if the message is not
    /// there or is already complete.</summary>
    function CompletePending(const AKey, AId, AFallback: string): Boolean;
    /// <summary>Marks the pending assistant message AId as failed with an error text.</summary>
    procedure FailAssistant(const AKey, AId, AError: string);
    /// <summary>Returns a copy of the assistant message AId, if present.</summary>
    function TryGetMessage(const AKey, AId: string; out AMessage: TKXChatMessage): Boolean;
    /// <summary>Returns the full conversation of the user, in order.</summary>
    function GetMessages(const AKey: string): TArray<TKXChatMessage>;
    /// <summary>Returns the completed (non-pending, non-error) messages to feed the
    /// provider as context, most recent AMaxMessages kept (0 = all).</summary>
    function GetHistory(const AKey: string; const AMaxMessages: Integer): TArray<TKXChatMessage>;
    /// <summary>Clears the user's conversation.</summary>
    procedure Clear(const AKey: string);

    /// <summary>The process-global conversation store.</summary>
    class function Instance: TKXChatStore; static;

    /// <summary>Cap on the messages kept per user. The conversation is in memory
    /// for the life of the process: without a cap it only grows, which on a
    /// long-lived server with many users is a slow leak. Completed messages are
    /// dropped oldest-first; a pending one is never dropped, or the client would
    /// poll an id that no longer exists.</summary>
    property MaxStoredMessages: Integer read FMaxStoredMessages write FMaxStoredMessages;
  end;

  /// <summary>
  ///  Worker-pool runner that produces assistant replies off the request thread.
  ///  Submitted requests run the configured provider and write the reply into the
  ///  <see cref="TKXChatStore" />. Pool size from <c>HelpChat/PoolSize</c>
  ///  (default 2). Process-global singleton.
  /// </summary>
  TKXChatRunner = class
  private
  type
    TKXChatRequest = record
      /// <summary>The conversation this reply belongs to, not the user:
      /// one conversation per assistant (see KXChatConversationKey).</summary>
      ConversationKey: string;
      AssistantId: string;
      ProviderName: string;
      Context: TKXChatContext;
      MaxHistory: Integer;
    end;
  private
    FSubmissions: TThreadedQueue<TKXChatRequest>;
    FWorkers: TObjectList<TThread>;
    FTokens: TDictionary<string, IKXChatCancelToken>;
    FTokensLock: TCriticalSection;
    procedure RunRequest(const ARequest: TKXChatRequest);
    class function TokenKey(const AKey, AId: string): string; static;
    function TakeToken(const AKey, AId: string): IKXChatCancelToken;
    procedure ReleaseToken(const AKey, AId: string);
    procedure CancelAll;
  public
    constructor Create(const APoolSize: Integer);
    destructor Destroy; override;

    /// <summary>Submits a request: the worker will run AProviderName against the
    /// user's current history and complete the assistant message AAssistantId.</summary>
    procedure Submit(const AKey, AAssistantId, AProviderName: string;
      const AContext: TKXChatContext; const AMaxHistory: Integer);

    /// <summary>Asks the reply identified by AAssistantId to stop. Cooperative:
    /// the provider decides how soon it notices, and keeps what it has already
    /// streamed. True when a request with that id was still running.</summary>
    function Cancel(const AKey, AAssistantId: string): Boolean;

    /// <summary>The process-global chat runner, created on first use.</summary>
    class function Instance: TKXChatRunner; static;
  end;

/// <summary>Formats a fresh URL-safe message id (hyphenated hex, no braces).</summary>
function NewChatId: string;

implementation

uses
  EF.Localization,
  Kitto.Config;

type
  TKXChatWorker = class(TThread)
  strict private
    FRunner: TKXChatRunner;
  protected
    procedure Execute; override;
  public
    constructor Create(const ARunner: TKXChatRunner);
  end;

var
  FStoreInstance: TKXChatStore;
  FRunnerInstance: TKXChatRunner;
  FSingletonLock: TCriticalSection;

function NewChatId: string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := Copy(GUIDToString(LGuid), 2, 36);
end;

{ TKXChatStore }

constructor TKXChatStore.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FConversations := TObjectDictionary<string, TList<TKXChatMessage>>.Create([doOwnsValues]);
end;

destructor TKXChatStore.Destroy;
begin
  FConversations.Free;
  FLock.Free;
  inherited;
end;

function TKXChatStore.EnsureList(const AKey: string): TList<TKXChatMessage>;
begin
  if not FConversations.TryGetValue(AKey, Result) then
  begin
    Result := TList<TKXChatMessage>.Create;
    FConversations.Add(AKey, Result);
  end;
end;

function TKXChatStore.IndexOfId(const AList: TList<TKXChatMessage>; const AId: string): Integer;
var
  I: Integer;
begin
  for I := 0 to AList.Count - 1 do
    if AList[I].Id = AId then
      Exit(I);
  Result := -1;
end;

function TKXChatStore.AddUserMessage(const AKey, AContent: string): TKXChatMessage;
begin
  Result := Default(TKXChatMessage);
  Result.Id := NewChatId;
  Result.Role := crUser;
  Result.Content := AContent;
  Result.Created := Now;
  FLock.Enter;
  try
    EnsureList(AKey).Add(Result);
    PruneLocked(EnsureList(AKey));
  finally
    FLock.Leave;
  end;
end;

function TKXChatStore.AddPendingAssistant(const AKey: string): string;
var
  LMessage: TKXChatMessage;
begin
  LMessage := Default(TKXChatMessage);
  LMessage.Id := NewChatId;
  LMessage.Role := crAssistant;
  LMessage.Created := Now;
  LMessage.Pending := True;
  FLock.Enter;
  try
    EnsureList(AKey).Add(LMessage);
    PruneLocked(EnsureList(AKey));
  finally
    FLock.Leave;
  end;
  Result := LMessage.Id;
end;

procedure TKXChatStore.AppendAssistantToken(const AKey, AId, AToken: string);
var
  LList: TList<TKXChatMessage>;
  LIndex: Integer;
  LMessage: TKXChatMessage;
begin
  if AToken = '' then
    Exit;
  FLock.Enter;
  try
    if FConversations.TryGetValue(AKey, LList) then
    begin
      LIndex := IndexOfId(LList, AId);
      if LIndex >= 0 then
      begin
        LMessage := LList[LIndex];
        LMessage.Content := LMessage.Content + AToken;
        // Stays Pending: the client keeps polling and the bubble shows the
        // partial text until CompleteAssistant flips it.
        LList[LIndex] := LMessage;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TKXChatStore.CompletePending(const AKey, AId, AFallback: string): Boolean;
var
  LList: TList<TKXChatMessage>;
  LIndex: Integer;
  LMessage: TKXChatMessage;
begin
  Result := False;
  FLock.Enter;
  try
    if FConversations.TryGetValue(AKey, LList) then
    begin
      LIndex := IndexOfId(LList, AId);
      if LIndex >= 0 then
      begin
        LMessage := LList[LIndex];
        if LMessage.Pending then
        begin
          if Trim(LMessage.Content) = '' then
            LMessage.Content := AFallback;
          LMessage.Pending := False;
          LMessage.IsError := False;
          LList[LIndex] := LMessage;
          Result := True;
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TKXChatStore.PruneLocked(const AList: TList<TKXChatMessage>);
var
  I: Integer;
begin
  // Called with the lock held, from the two points where the list grows. Walks
  // from the oldest and removes completed messages until the list is within the
  // cap; a pending message is skipped, never removed.
  if FMaxStoredMessages <= 0 then
    Exit;
  I := 0;
  while (AList.Count > FMaxStoredMessages) and (I < AList.Count) do
    if AList[I].Pending then
      Inc(I)
    else
      AList.Delete(I);
end;

procedure TKXChatStore.CompleteAssistant(const AKey, AId, AContent: string);
var
  LList: TList<TKXChatMessage>;
  LIndex: Integer;
  LMessage: TKXChatMessage;
begin
  FLock.Enter;
  try
    if FConversations.TryGetValue(AKey, LList) then
    begin
      LIndex := IndexOfId(LList, AId);
      if LIndex >= 0 then
      begin
        LMessage := LList[LIndex];
        LMessage.Content := AContent;
        LMessage.Pending := False;
        LMessage.IsError := False;
        LList[LIndex] := LMessage;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TKXChatStore.FailAssistant(const AKey, AId, AError: string);
var
  LList: TList<TKXChatMessage>;
  LIndex: Integer;
  LMessage: TKXChatMessage;
begin
  FLock.Enter;
  try
    if FConversations.TryGetValue(AKey, LList) then
    begin
      LIndex := IndexOfId(LList, AId);
      if LIndex >= 0 then
      begin
        LMessage := LList[LIndex];
        LMessage.Content := AError;
        LMessage.Pending := False;
        LMessage.IsError := True;
        LList[LIndex] := LMessage;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TKXChatStore.TryGetMessage(const AKey, AId: string; out AMessage: TKXChatMessage): Boolean;
var
  LList: TList<TKXChatMessage>;
  LIndex: Integer;
begin
  Result := False;
  FLock.Enter;
  try
    if FConversations.TryGetValue(AKey, LList) then
    begin
      LIndex := IndexOfId(LList, AId);
      if LIndex >= 0 then
      begin
        AMessage := LList[LIndex];
        Result := True;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TKXChatStore.GetMessages(const AKey: string): TArray<TKXChatMessage>;
var
  LList: TList<TKXChatMessage>;
begin
  FLock.Enter;
  try
    if FConversations.TryGetValue(AKey, LList) then
      Result := LList.ToArray
    else
      Result := [];
  finally
    FLock.Leave;
  end;
end;

function TKXChatStore.GetHistory(const AKey: string; const AMaxMessages: Integer): TArray<TKXChatMessage>;
var
  LList: TList<TKXChatMessage>;
  LKept: TList<TKXChatMessage>;
  I: Integer;
begin
  FLock.Enter;
  try
    if not FConversations.TryGetValue(AKey, LList) then
      Exit(nil);
    LKept := TList<TKXChatMessage>.Create;
    try
      for I := 0 to LList.Count - 1 do
        if not LList[I].Pending and not LList[I].IsError then
          LKept.Add(LList[I]);
      // Keep only the most recent AMaxMessages (0 or negative = all).
      if (AMaxMessages > 0) and (LKept.Count > AMaxMessages) then
        LKept.DeleteRange(0, LKept.Count - AMaxMessages);
      Result := LKept.ToArray;
    finally
      LKept.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TKXChatStore.Clear(const AKey: string);
begin
  FLock.Enter;
  try
    FConversations.Remove(AKey);
  finally
    FLock.Leave;
  end;
end;

class function TKXChatStore.Instance: TKXChatStore;
begin
  if FStoreInstance = nil then
  begin
    FSingletonLock.Enter;
    try
      if FStoreInstance = nil then
      begin
        FStoreInstance := TKXChatStore.Create;
        FStoreInstance.MaxStoredMessages := TKConfig.Instance.Config.GetInteger(
          'HelpChat/MaxStoredMessages', KX_HELPCHAT_DEF_MAXSTORED);
      end;
    finally
      FSingletonLock.Leave;
    end;
  end;
  Result := FStoreInstance;
end;

{ TKXChatWorker }

constructor TKXChatWorker.Create(const ARunner: TKXChatRunner);
begin
  FRunner := ARunner;
  inherited Create(False);
end;

procedure TKXChatWorker.Execute;
var
  LRequest: TKXChatRunner.TKXChatRequest;
begin
  while not Terminated do
  begin
    if FRunner.FSubmissions.PopItem(LRequest) = wrSignaled then
    begin
      // On DoShutDown some RTL versions unblock PopItem with wrSignaled but a
      // default (empty) item; a real request always carries a user name, so an
      // empty user name is the shutdown sentinel.
      if LRequest.ConversationKey = '' then
        Break;
      FRunner.RunRequest(LRequest);
    end
    else
      Break; // shutdown / abandoned
  end;
end;

{ TKXChatRunner }

constructor TKXChatRunner.Create(const APoolSize: Integer);
var
  I, LSize: Integer;
begin
  inherited Create;
  LSize := APoolSize;
  if LSize < 1 then
    LSize := 1;
  FSubmissions := TThreadedQueue<TKXChatRequest>.Create(1000, INFINITE, INFINITE);
  FTokens := TDictionary<string, IKXChatCancelToken>.Create;
  FTokensLock := TCriticalSection.Create;
  FWorkers := TObjectList<TThread>.Create(True);
  for I := 1 to LSize do
    FWorkers.Add(TKXChatWorker.Create(Self));
end;

destructor TKXChatRunner.Destroy;
var
  LThread: TThread;
begin
  // Cancel first: a worker inside an HTTP round-trip to a model would otherwise
  // be waited for until its response timeout, which is minutes, not seconds.
  if Assigned(FTokens) then
    CancelAll;
  if Assigned(FSubmissions) then
    FSubmissions.DoShutDown; // wakes the workers blocked in PopItem
  if Assigned(FWorkers) then
    for LThread in FWorkers do
      LThread.Terminate;
  FreeAndNil(FWorkers); // frees/joins each worker
  FreeAndNil(FSubmissions);
  FreeAndNil(FTokens);
  FreeAndNil(FTokensLock);
  inherited;
end;

procedure TKXChatRunner.RunRequest(const ARequest: TKXChatRequest);
var
  LProvider: IKXChatProvider;
  LCancel: IKXChatCancelToken;
  LReply, LKey, LAssistantId: string;
begin
  LCancel := TakeToken(ARequest.ConversationKey, ARequest.AssistantId);
  if LCancel = nil then
    LCancel := TKXChatCancelToken.Create;
  try
    try
      // Cancelled while still queued: nothing was asked of the provider, so the
      // bubble is closed at once instead of leaving the client polling.
      if LCancel.IsCancelled then
      begin
        TKXChatStore.Instance.CompletePending(ARequest.ConversationKey, ARequest.AssistantId,
          _('Reply cancelled.'));
        Exit;
      end;
      // Which assistant is answering: the provider reads its own settings
      // through it, down to the model and the key.
      LProvider := TKXChatProviderRegistry.CreateProvider(ARequest.ProviderName,
        ARequest.Context.Profile);
      // Copy to locals so the token callback (invoked synchronously during
      // Generate) does not depend on the const-parameter's lifetime.
      LKey := ARequest.ConversationKey;
      LAssistantId := ARequest.AssistantId;
      LReply := LProvider.Generate(
        TKXChatStore.Instance.GetHistory(ARequest.ConversationKey, ARequest.MaxHistory),
        ARequest.Context,
        // A streaming provider appends each token to the store as it arrives, so
        // the poll endpoint returns the growing partial. Non-streaming providers
        // (stub, docsearch) ignore this callback.
        procedure(const AToken: string)
        begin
          TKXChatStore.Instance.AppendAssistantToken(LKey, LAssistantId, AToken);
        end,
        LCancel);
      TKXChatStore.Instance.CompleteAssistant(ARequest.ConversationKey, ARequest.AssistantId, LReply);
    except
      // A cancelled reply is a short reply, not a failed one: what the provider
      // had already streamed is in the store and stays there.
      on EKXChatCancelled do
        TKXChatStore.Instance.CompletePending(ARequest.ConversationKey, ARequest.AssistantId,
          _('Reply cancelled.'));
      on E: Exception do
        TKXChatStore.Instance.FailAssistant(ARequest.ConversationKey, ARequest.AssistantId, E.Message);
    end;
  finally
    ReleaseToken(ARequest.ConversationKey, ARequest.AssistantId);
  end;
end;

class function TKXChatRunner.TokenKey(const AKey, AId: string): string;
begin
  Result := AKey + '|' + AId;
end;

function TKXChatRunner.TakeToken(const AKey, AId: string): IKXChatCancelToken;
begin
  FTokensLock.Enter;
  try
    if not FTokens.TryGetValue(TokenKey(AKey, AId), Result) then
      Result := nil;
  finally
    FTokensLock.Leave;
  end;
end;

procedure TKXChatRunner.ReleaseToken(const AKey, AId: string);
begin
  FTokensLock.Enter;
  try
    FTokens.Remove(TokenKey(AKey, AId));
  finally
    FTokensLock.Leave;
  end;
end;

procedure TKXChatRunner.CancelAll;
var
  LToken: IKXChatCancelToken;
begin
  FTokensLock.Enter;
  try
    for LToken in FTokens.Values do
      LToken.Cancel;
  finally
    FTokensLock.Leave;
  end;
end;

function TKXChatRunner.Cancel(const AKey, AAssistantId: string): Boolean;
var
  LToken: IKXChatCancelToken;
begin
  LToken := TakeToken(AKey, AAssistantId);
  Result := Assigned(LToken);
  if Result then
    LToken.Cancel;
end;

procedure TKXChatRunner.Submit(const AKey, AAssistantId, AProviderName: string;
  const AContext: TKXChatContext; const AMaxHistory: Integer);
var
  LRequest: TKXChatRequest;
begin
  LRequest := Default(TKXChatRequest);
  LRequest.ConversationKey := AKey;
  LRequest.AssistantId := AAssistantId;
  LRequest.ProviderName := AProviderName;
  LRequest.Context := AContext;
  LRequest.MaxHistory := AMaxHistory;
  // Registered before the request is queued: a cancel arriving while it is still
  // in the queue must find the token, or it would have nothing to cancel.
  FTokensLock.Enter;
  try
    FTokens.AddOrSetValue(TokenKey(AKey, AAssistantId), TKXChatCancelToken.Create);
  finally
    FTokensLock.Leave;
  end;
  FSubmissions.PushItem(LRequest);
end;

class function TKXChatRunner.Instance: TKXChatRunner;
begin
  if FRunnerInstance = nil then
  begin
    FSingletonLock.Enter;
    try
      if FRunnerInstance = nil then
        FRunnerInstance := TKXChatRunner.Create(
          TKConfig.Instance.Config.GetInteger('HelpChat/PoolSize', KX_HELPCHAT_DEF_POOLSIZE));
    finally
      FSingletonLock.Leave;
    end;
  end;
  Result := FRunnerInstance;
end;

initialization
  FSingletonLock := TCriticalSection.Create;

finalization
  FreeAndNil(FRunnerInstance);
  FreeAndNil(FStoreInstance);
  FreeAndNil(FSingletonLock);

end.
