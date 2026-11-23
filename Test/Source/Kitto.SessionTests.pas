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
///  A brand-new session must not read as already expired. It used to: the
///  last-request time is 0 until the first request refreshes it, so HasExpired
///  compared Now against 0 + Timeout and returned True the instant the session
///  was created — while the cleanup thread, which frees whatever HasExpired
///  reports, could free it out from under the request that had just created it.
///  These tests exercise HasExpired directly; no server or database is needed.
/// </summary>
unit Kitto.SessionTests;

interface

uses
  DUnitX.TestFramework,
  Kitto.Web.Session;

type
  [TestFixture]
  TKWebSessionExpiryTests = class
  public
    /// <summary>Just created, well within the timeout: not expired.</summary>
    [Test]
    procedure AFreshlyCreatedSessionIsNotExpired;

    /// <summary>The timeout itself still works: once the deadline has passed,
    /// the session is expired.</summary>
    [Test]
    procedure ASessionPastItsTimeoutIsExpired;
  end;

  /// <summary>
  ///  A session object must outlive every request being served on it. It did
  ///  not: a page refresh removed and re-created the session, freeing the old
  ///  object while other requests of the same session - a second tab, a reload
  ///  with something still loading - were working on it from other threads.
  ///  That was an access violation reproducible with two threads in a few
  ///  seconds (Test/Load, scenario "home"). These tests pin the rule that
  ///  cured it: a session that leaves the list while requests are in flight is
  ///  retired, and freed when the last of them gives it back.
  /// </summary>
  [TestFixture]
  TKWebSessionLifetimeTests = class
  private
    FSessions: TKWebSessions;
    function Acquire(const AId: string): TKWebSession;
    function LiveCount: Integer;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>Two requests presenting the same id are served on the same
    /// object.</summary>
    [Test]
    procedure TwoRequestsOfOneSessionShareTheObject;

    /// <summary>The page refresh of one request must not free the object the
    /// other is still using: it is retired, and goes when that one ends.</summary>
    [Test]
    procedure APageRefreshDoesNotFreeASessionInUse;

    /// <summary>With nobody else on it, the old object goes at once.</summary>
    [Test]
    procedure APageRefreshFreesASessionNobodyElseUses;

    /// <summary>After a refresh the id leads to the new object, and only to
    /// it: one live session, not two.</summary>
    [Test]
    procedure AfterAPageRefreshTheIdFindsTheNewSession;

    /// <summary>What a refresh carries over: authentication, auth data,
    /// database, the application-issued reload flag.</summary>
    [Test]
    procedure APageRefreshCarriesTheAuthenticationOver;

    /// <summary>An anonymous session carries no auth data over.</summary>
    [Test]
    procedure APageRefreshOfAnAnonymousSessionCarriesNoAuthData;

    /// <summary>Two refreshes of the same object, one after the other, as two
    /// tabs reloading together do: the second finds it already replaced.</summary>
    [Test]
    procedure TwoPageRefreshesOfTheSameObjectLeaveOneSession;

    /// <summary>The cleanup thread must not free an expired session while a
    /// request is being served on it; it does once the request has ended.</summary>
    [Test]
    procedure CleanupSparesAnExpiredSessionInUse;

    /// <summary>Removing a session in use (fatal error) takes it out of the
    /// list at once and frees it when the request ends.</summary>
    [Test]
    procedure RemovingASessionInUseDefersItsEnd;

    /// <summary>Many threads finding, refreshing and releasing the same id:
    /// no failure, one session left, nothing left retired.</summary>
    [Test]
    procedure ConcurrentRefreshesOfOneSessionSurvive;
  end;

  /// <summary>
  ///  Where the session timeout is read from. The New Project wizard wrote it
  ///  under <c>Server/SessionTimeOut</c>, a node the engine never read: the
  ///  value was ignored and every generated application ran on ten minutes.
  ///  The engine reads <c>Engine/Session/TimeOut</c>, and now falls back on the
  ///  other so that the projects already generated get what they asked for.
  /// </summary>
  [TestFixture]
  TKSessionTimeOutConfigTests = class
  public
    [Test]
    procedure WithNoNodeTheTimeoutIsTenMinutes;
    [Test]
    procedure TheEngineNodeIsRead;
    [Test]
    procedure TheOlderServerNodeIsReadWhenTheEngineNodeIsMissing;
    [Test]
    procedure TheEngineNodeWinsOverTheOlderOne;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.SyncObjs,
  EF.Tree,
  Kitto.Web.Engine;

const
  CLIENT = '127.0.0.1';

procedure TKWebSessionExpiryTests.AFreshlyCreatedSessionIsNotExpired;
var
  LSession: TKWebSession;
begin
  LSession := TKWebSession.Create('127.0.0.1', 'sid-fresh', 10 * OneMinute);
  try
    Assert.IsFalse(LSession.HasExpired,
      'A session created a moment ago, with a 10-minute timeout, must not be ' +
      'reported as expired before it has served a single request.');
  finally
    LSession.Free;
  end;
end;

procedure TKWebSessionExpiryTests.ASessionPastItsTimeoutIsExpired;
var
  LSession: TKWebSession;
begin
  // A negative timeout puts the deadline (creation time + timeout) in the past,
  // so the session is expired now — deterministically, without waiting. This
  // pins that the fresh-session fix did not disable expiry altogether.
  LSession := TKWebSession.Create('127.0.0.1', 'sid-stale', -OneMinute);
  try
    Assert.IsTrue(LSession.HasExpired,
      'A session whose deadline has passed must still be reported as expired.');
  finally
    LSession.Free;
  end;
end;

{ TKWebSessionLifetimeTests }

procedure TKWebSessionLifetimeTests.Setup;
begin
  FSessions := TKWebSessions.Create(10 * OneMinute);
end;

procedure TKWebSessionLifetimeTests.TearDown;
begin
  FreeAndNil(FSessions);
end;

function TKWebSessionLifetimeTests.Acquire(const AId: string): TKWebSession;
var
  LCreated: Boolean;
begin
  Result := FSessions.FindOrCreateSession(AId, CLIENT, LCreated);
end;

function TKWebSessionLifetimeTests.LiveCount: Integer;
begin
  Result := Length(FSessions.GetSessionInfos);
end;

procedure TKWebSessionLifetimeTests.TwoRequestsOfOneSessionShareTheObject;
var
  LFirst, LSecond: TKWebSession;
begin
  LFirst := Acquire('sid');
  LSecond := Acquire('sid');
  Assert.AreSame(LFirst, LSecond, 'Same id, same session object.');
  Assert.AreEqual(1, LiveCount, 'One id must not produce two sessions.');
  FSessions.ReleaseSession(LFirst);
  FSessions.ReleaseSession(LSecond);
  Assert.AreEqual(1, LiveCount,
    'A session nobody is using at the moment is still a live session.');
end;

procedure TKWebSessionLifetimeTests.APageRefreshDoesNotFreeASessionInUse;
var
  LInFlight, LRefreshing, LNew: TKWebSession;
begin
  // Two requests of the same session: one is in flight, the other is a page
  // refresh.
  LInFlight := Acquire('sid');
  LInFlight.AuthData.SetString('UserName', 'ada');
  LRefreshing := Acquire('sid');

  LNew := FSessions.RenewSession(LRefreshing, CLIENT);

  Assert.AreNotSame(LInFlight, LNew, 'A page refresh starts on a new object.');
  Assert.AreEqual(1, FSessions.GetRetiredSessionCount,
    'The old object is still in use by the other request: it must be waiting, ' +
    'not freed.');
  // The request in flight goes on working on its object.
  Assert.AreEqual('ada', LInFlight.AuthData.GetString('UserName'));
  Assert.AreEqual('sid', LInFlight.SessionId);

  FSessions.ReleaseSession(LInFlight);
  Assert.AreEqual(0, FSessions.GetRetiredSessionCount,
    'The last request on the old object has ended: it must be gone.');
  FSessions.ReleaseSession(LNew);
end;

procedure TKWebSessionLifetimeTests.APageRefreshFreesASessionNobodyElseUses;
var
  LNew: TKWebSession;
begin
  LNew := FSessions.RenewSession(Acquire('sid'), CLIENT);
  Assert.AreEqual(0, FSessions.GetRetiredSessionCount,
    'Nobody else was using the old object: nothing to wait for.');
  Assert.AreEqual(1, LiveCount);
  FSessions.ReleaseSession(LNew);
end;

procedure TKWebSessionLifetimeTests.AfterAPageRefreshTheIdFindsTheNewSession;
var
  LOld, LNew, LFound: TKWebSession;
begin
  LOld := Acquire('sid');
  LNew := FSessions.RenewSession(LOld, CLIENT);
  Assert.AreEqual('sid', LNew.SessionId, 'A refresh keeps the id.');

  LFound := Acquire('sid');
  Assert.AreSame(LNew, LFound, 'The id must lead to the new object.');
  Assert.AreEqual(1, LiveCount, 'One live session for one id.');
  FSessions.ReleaseSession(LFound);
  FSessions.ReleaseSession(LNew);
end;

procedure TKWebSessionLifetimeTests.APageRefreshCarriesTheAuthenticationOver;
var
  LOld, LNew: TKWebSession;
begin
  LOld := Acquire('sid');
  LOld.IsAuthenticated := True;
  LOld.AuthData.SetString('UserName', 'ada');
  LOld.DatabaseName := 'Other';
  LOld.ReloadingHome := True;

  LNew := FSessions.RenewSession(LOld, CLIENT);

  Assert.IsTrue(LNew.IsAuthenticated, 'A refresh must not log the user out by itself.');
  Assert.AreEqual('ada', LNew.AuthData.GetString('UserName'));
  Assert.AreEqual('Other', LNew.DatabaseName);
  Assert.IsTrue(LNew.ReloadingHome,
    'The reload flag is how Home tells an application-issued reload from F5.');
  FSessions.ReleaseSession(LNew);
end;

procedure TKWebSessionLifetimeTests.APageRefreshOfAnAnonymousSessionCarriesNoAuthData;
var
  LOld, LNew: TKWebSession;
begin
  LOld := Acquire('sid');
  // What a failed or pending login leaves behind.
  LOld.AuthData.SetString('UserName', 'ada');

  LNew := FSessions.RenewSession(LOld, CLIENT);

  Assert.IsFalse(LNew.IsAuthenticated);
  Assert.AreEqual('', LNew.AuthData.GetString('UserName'),
    'Auth data of a session that was not authenticated must not survive.');
  FSessions.ReleaseSession(LNew);
end;

procedure TKWebSessionLifetimeTests.TwoPageRefreshesOfTheSameObjectLeaveOneSession;
var
  LTabOne, LTabTwo, LNewOne, LNewTwo: TKWebSession;
begin
  LTabOne := Acquire('sid');
  LTabTwo := Acquire('sid');

  LNewOne := FSessions.RenewSession(LTabOne, CLIENT);
  // The second refresh holds an object the first has already replaced.
  LNewTwo := FSessions.RenewSession(LTabTwo, CLIENT);

  Assert.AreNotSame(LNewOne, LNewTwo, 'Each request is served on its own object.');
  Assert.AreEqual(1, LiveCount,
    'An id must never lead to two live sessions: the later refresh replaces ' +
    'the earlier one.');
  Assert.AreEqual(1, FSessions.GetRetiredSessionCount,
    'The object both started from has no request left and is gone; the one ' +
    'the first refresh created is still being served.');

  FSessions.ReleaseSession(LNewOne);
  Assert.AreEqual(0, FSessions.GetRetiredSessionCount);
  FSessions.ReleaseSession(LNewTwo);
  Assert.AreEqual(1, LiveCount);
end;

procedure TKWebSessionLifetimeTests.CleanupSparesAnExpiredSessionInUse;
var
  LSessions: TKWebSessions;
  LSession: TKWebSession;
  LCreated: Boolean;
begin
  // A negative timeout: every session is past its deadline as soon as created.
  LSessions := TKWebSessions.Create(-OneMinute);
  try
    LSession := LSessions.FindOrCreateSession('sid', CLIENT, LCreated);
    Assert.IsTrue(LSession.HasExpired, 'Premise: the session reads as expired.');

    LSessions.CleanupExpiredSessions;
    Assert.AreEqual(1, Integer(Length(LSessions.GetSessionInfos)),
      'A request is being served on it: expired or not, it must stay.');

    LSessions.ReleaseSession(LSession);
    LSessions.CleanupExpiredSessions;
    Assert.AreEqual(0, Integer(Length(LSessions.GetSessionInfos)),
      'Once the request has ended the timeout applies again.');
  finally
    LSessions.Free;
  end;
end;

procedure TKWebSessionLifetimeTests.RemovingASessionInUseDefersItsEnd;
var
  LFailing, LOther: TKWebSession;
begin
  LFailing := Acquire('sid');
  LOther := Acquire('sid');

  FSessions.RemoveSession(LFailing);
  Assert.AreEqual(0, LiveCount, 'Removed: no new request must find it.');
  Assert.AreEqual(1, FSessions.GetRetiredSessionCount,
    'Two requests are still on it.');

  FSessions.ReleaseSession(LFailing);
  Assert.AreEqual(1, FSessions.GetRetiredSessionCount, 'One request left.');
  Assert.AreEqual('sid', LOther.SessionId, 'And it is still working on it.');
  FSessions.ReleaseSession(LOther);
  Assert.AreEqual(0, FSessions.GetRetiredSessionCount);
end;

procedure TKWebSessionLifetimeTests.ConcurrentRefreshesOfOneSessionSurvive;
const
  THREADS = 8;
  ROUNDS = 2000;
var
  LThreads: array[0..THREADS - 1] of TThread;
  LFailures: Integer;
  LFirstFailure: string;
  I: Integer;
begin
  LFailures := 0;
  LFirstFailure := '';
  for I := 0 to THREADS - 1 do
  begin
    LThreads[I] := TThread.CreateAnonymousThread(
      procedure
      var
        LRound: Integer;
        LSession: TKWebSession;
        LCreated: Boolean;
      begin
        try
          for LRound := 1 to ROUNDS do
          begin
            LSession := FSessions.FindOrCreateSession('sid', CLIENT, LCreated);
            try
              // Every other request is a page refresh; the rest are ordinary
              // requests that read the session while the others replace it.
              if Odd(LRound) then
              begin
                LSession := FSessions.RenewSession(LSession, CLIENT);
                // What Home does on its own object: log out and in again.
                LSession.LockAuthData;
                try
                  LSession.AuthData.Clear;
                  LSession.AuthData.SetString('UserName', 'ada');
                finally
                  LSession.UnlockAuthData;
                end;
                LSession.IsAuthenticated := True;
              end
              else if LSession.SessionId <> 'sid' then
                raise Exception.Create('Session id read as "' + LSession.SessionId + '"');
            finally
              FSessions.ReleaseSession(LSession);
            end;
          end;
        except
          on E: Exception do
            if TInterlocked.Increment(LFailures) = 1 then
              LFirstFailure := E.ClassName + ': ' + E.Message;
        end;
      end);
    LThreads[I].FreeOnTerminate := False;
  end;
  for I := 0 to THREADS - 1 do
    LThreads[I].Start;
  for I := 0 to THREADS - 1 do
  begin
    LThreads[I].WaitFor;
    LThreads[I].Free;
  end;

  Assert.AreEqual(0, LFailures, 'First failure: ' + LFirstFailure);
  Assert.AreEqual(1, LiveCount, 'One id, one live session, however it got there.');
  Assert.AreEqual(0, FSessions.GetRetiredSessionCount,
    'Every request has ended: nothing may be left waiting.');
end;

{ TKSessionTimeOutConfigTests }

procedure TKSessionTimeOutConfigTests.WithNoNodeTheTimeoutIsTenMinutes;
var
  LConfig: TEFTree;
begin
  LConfig := TEFTree.Create;
  try
    Assert.AreEqual(10, ReadSessionTimeOutMinutes(LConfig),
      'A configuration that says nothing gets the default.');
  finally
    LConfig.Free;
  end;
end;

procedure TKSessionTimeOutConfigTests.TheEngineNodeIsRead;
var
  LConfig: TEFTree;
begin
  LConfig := TEFTree.Create;
  try
    LConfig.SetInteger('Engine/Session/TimeOut', 30);
    Assert.AreEqual(30, ReadSessionTimeOutMinutes(LConfig),
      'Engine/Session/TimeOut is the node of the session timeout.');
  finally
    LConfig.Free;
  end;
end;

procedure TKSessionTimeOutConfigTests.TheOlderServerNodeIsReadWhenTheEngineNodeIsMissing;
var
  LConfig: TEFTree;
begin
  LConfig := TEFTree.Create;
  try
    LConfig.SetInteger('Server/SessionTimeOut', 45);
    Assert.AreEqual(45, ReadSessionTimeOutMinutes(LConfig),
      'A project generated by the old wizard has its timeout under Server.');
  finally
    LConfig.Free;
  end;
end;

procedure TKSessionTimeOutConfigTests.TheEngineNodeWinsOverTheOlderOne;
var
  LConfig: TEFTree;
begin
  LConfig := TEFTree.Create;
  try
    LConfig.SetInteger('Server/SessionTimeOut', 45);
    LConfig.SetInteger('Engine/Session/TimeOut', 30);
    Assert.AreEqual(30, ReadSessionTimeOutMinutes(LConfig),
      'With both nodes the engine one decides.');
  finally
    LConfig.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TKSessionTimeOutConfigTests);
  TDUnitX.RegisterTestFixture(TKWebSessionExpiryTests);
  TDUnitX.RegisterTestFixture(TKWebSessionLifetimeTests);

end.
