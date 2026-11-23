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
///  The help-chat conversation store lives in memory for the life of the
///  process, so it needs a cap, and the cap must never drop the message the
///  client is polling. These tests use their own store instance (not the
///  singleton) so nothing here depends on a configuration or on order.
///  They also cover the cooperative cancel token and the completion that keeps
///  the partial of a cancelled reply.
/// </summary>
unit Kitto.ChatStoreTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TKXChatStoreTests = class
  public
    /// <summary>Past the cap the oldest completed messages go, newest stay.</summary>
    [Test]
    procedure Prune_DropsOldestCompleted;
    /// <summary>A pending message is never dropped: the client is polling its id.</summary>
    [Test]
    procedure Prune_KeepsPending;
    /// <summary>Cap at zero means no pruning at all.</summary>
    [Test]
    procedure Prune_Disabled_KeepsEverything;
    /// <summary>A cancelled reply keeps what was streamed; an empty one gets the note.</summary>
    [Test]
    procedure CompletePending_KeepsPartial_OrUsesFallback;
    /// <summary>Completing twice is refused: only a pending message can be closed.</summary>
    [Test]
    procedure CompletePending_OnCompletedMessage_IsRefused;
  end;

  [TestFixture]
  TKXChatCancelTokenTests = class
  public
    /// <summary>Starts clear, stays cancelled, and cancelling twice is harmless.</summary>
    [Test]
    procedure Cancel_IsStickyAndIdempotent;
  end;

implementation

uses
  System.SysUtils,
  Kitto.Chat.Provider,
  Kitto.Chat.Runner;

const
  USER = 'tester';

procedure TKXChatStoreTests.Prune_DropsOldestCompleted;
var
  LStore: TKXChatStore;
  LMessages: TArray<TKXChatMessage>;
  I: Integer;
begin
  LStore := TKXChatStore.Create;
  try
    LStore.MaxStoredMessages := 4;
    for I := 1 to 10 do
      LStore.AddUserMessage(USER, 'message ' + I.ToString);
    LMessages := LStore.GetMessages(USER);
    // Integer(): in Delphi 13 Length() of a dynamic array is NativeInt, and the
    // generic Assert.AreEqual cannot infer a type from two different ones.
    Assert.AreEqual(4, Integer(Length(LMessages)), 'the cap is the number of messages kept');
    Assert.AreEqual('message 7', LMessages[0].Content, 'the oldest survivor');
    Assert.AreEqual('message 10', LMessages[High(LMessages)].Content, 'the newest is always there');
  finally
    LStore.Free;
  end;
end;

procedure TKXChatStoreTests.Prune_KeepsPending;
var
  LStore: TKXChatStore;
  LPendingId: string;
  LMessage: TKXChatMessage;
  I: Integer;
begin
  LStore := TKXChatStore.Create;
  try
    LStore.MaxStoredMessages := 3;
    // The pending one is the oldest, so a cap that only counted would drop it.
    LPendingId := LStore.AddPendingAssistant(USER);
    for I := 1 to 20 do
      LStore.AddUserMessage(USER, 'message ' + I.ToString);
    Assert.IsTrue(LStore.TryGetMessage(USER, LPendingId, LMessage),
      'the message the client is polling must still be there');
    Assert.IsTrue(LMessage.Pending);
  finally
    LStore.Free;
  end;
end;

procedure TKXChatStoreTests.Prune_Disabled_KeepsEverything;
var
  LStore: TKXChatStore;
  I: Integer;
begin
  LStore := TKXChatStore.Create;
  try
    LStore.MaxStoredMessages := 0;
    for I := 1 to 30 do
      LStore.AddUserMessage(USER, 'message ' + I.ToString);
    Assert.AreEqual(30, Integer(Length(LStore.GetMessages(USER))));
  finally
    LStore.Free;
  end;
end;

procedure TKXChatStoreTests.CompletePending_KeepsPartial_OrUsesFallback;
var
  LStore: TKXChatStore;
  LWithPartial, LEmpty: string;
  LMessage: TKXChatMessage;
begin
  LStore := TKXChatStore.Create;
  try
    LWithPartial := LStore.AddPendingAssistant(USER);
    LStore.AppendAssistantToken(USER, LWithPartial, 'half an ');
    LStore.AppendAssistantToken(USER, LWithPartial, 'answer');
    Assert.IsTrue(LStore.CompletePending(USER, LWithPartial, 'cancelled'));
    Assert.IsTrue(LStore.TryGetMessage(USER, LWithPartial, LMessage));
    Assert.AreEqual('half an answer', LMessage.Content, 'what was streamed is kept');
    Assert.IsFalse(LMessage.Pending, 'the client must stop polling it');
    Assert.IsFalse(LMessage.IsError, 'a cancelled reply is not a failed one');

    LEmpty := LStore.AddPendingAssistant(USER);
    Assert.IsTrue(LStore.CompletePending(USER, LEmpty, 'cancelled'));
    Assert.IsTrue(LStore.TryGetMessage(USER, LEmpty, LMessage));
    Assert.AreEqual('cancelled', LMessage.Content, 'nothing streamed: the note is used');
  finally
    LStore.Free;
  end;
end;

procedure TKXChatStoreTests.CompletePending_OnCompletedMessage_IsRefused;
var
  LStore: TKXChatStore;
  LId: string;
  LMessage: TKXChatMessage;
begin
  LStore := TKXChatStore.Create;
  try
    LId := LStore.AddPendingAssistant(USER);
    LStore.CompleteAssistant(USER, LId, 'the real answer');
    Assert.IsFalse(LStore.CompletePending(USER, LId, 'cancelled'),
      'a cancel arriving after the answer must not overwrite it');
    Assert.IsTrue(LStore.TryGetMessage(USER, LId, LMessage));
    Assert.AreEqual('the real answer', LMessage.Content);
    Assert.IsFalse(LStore.CompletePending(USER, 'no-such-id', 'cancelled'));
  finally
    LStore.Free;
  end;
end;

procedure TKXChatCancelTokenTests.Cancel_IsStickyAndIdempotent;
var
  LToken: IKXChatCancelToken;
begin
  LToken := TKXChatCancelToken.Create;
  Assert.IsFalse(LToken.IsCancelled, 'a fresh token is not cancelled');
  LToken.Cancel;
  Assert.IsTrue(LToken.IsCancelled);
  LToken.Cancel;
  Assert.IsTrue(LToken.IsCancelled, 'cancelling twice changes nothing');
end;

initialization
  TDUnitX.RegisterTestFixture(TKXChatStoreTests);
  TDUnitX.RegisterTestFixture(TKXChatCancelTokenTests);

end.
