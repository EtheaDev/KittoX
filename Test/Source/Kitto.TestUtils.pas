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
///  Helpers shared by the test suite.
/// </summary>
unit Kitto.TestUtils;

interface

uses
  System.SysUtils;

type
  TKTestUtils = class
  public
    /// <summary>
    ///  Runs AProc on a worker thread and tells whether it finished within
    ///  ATimeoutMS. Use it for anything that could fail by NOT returning: a
    ///  plain call would hang the whole run, whereas this reports a failed
    ///  test and carries on.
    ///
    ///  An exception raised by AProc is re-raised here, so the test reports it
    ///  as usual. When the timeout expires the thread is killed and its object
    ///  deliberately leaked: it is stuck inside framework code, there is no
    ///  safe way to unwind it, and the run is about to end anyway. POSIX has no
    ///  way to kill a single thread, so there it is left running instead.
    /// </summary>
    class function RunsWithin(const AProc: TProc;
      const ATimeoutMS: Cardinal = 2000): Boolean; static;

    /// <summary>Full path of the Test\Data folder, wherever the test binary
    /// was built. Raises if the folder cannot be found.</summary>
    class function DataPath: string; static;

    /// <summary>Full path of a file inside Test\Data.</summary>
    class function DataFile(const AFileName: string): string; static;

    /// <summary>A fresh empty folder under the system temp path, removed by
    /// RemoveTempPath. Used by tests that write files.</summary>
    class function CreateTempPath: string; static;
    class procedure RemoveTempPath(const APath: string); static;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SyncObjs
  {$IFDEF MSWINDOWS}
  , Winapi.Windows
  {$ENDIF}
  ;

{ TKTestUtils }

class function TKTestUtils.RunsWithin(const AProc: TProc;
  const ATimeoutMS: Cardinal): Boolean;
var
  LThread: TThread;
  LDone: TEvent;
  LFatalMessage: string;
  LFatalClassName: string;
  LHasFatal: Boolean;
begin
  Assert(Assigned(AProc));

  // Signalled when AProc returns or raises. A portable alternative to waiting
  // on the thread handle, which only Windows offers with a timeout. On timeout
  // the event is leaked along with the thread, which may still set it later.
  LDone := TEvent.Create(nil, True, False, '');
  LThread := TThread.CreateAnonymousThread(
    procedure
    begin
      try
        AProc();
      finally
        LDone.SetEvent;
      end;
    end);
  LThread.FreeOnTerminate := False;
  LThread.Start;

  if LDone.WaitFor(ATimeoutMS) <> wrSignaled then
  begin
    // Still running: the code under test did not return. See the note above on
    // why the thread object is not freed.
    {$IFDEF MSWINDOWS}
    TerminateThread(LThread.Handle, 0);
    {$ENDIF}
    Exit(False);
  end;
  LDone.Free;
  // AProc is over; let the thread finish so FatalException is set.
  LThread.WaitFor;

  LHasFatal := False;
  LFatalMessage := '';
  LFatalClassName := '';
  try
    if Assigned(LThread.FatalException) then
    begin
      LHasFatal := True;
      LFatalClassName := LThread.FatalException.ClassName;
      if LThread.FatalException is Exception then
        LFatalMessage := Exception(LThread.FatalException).Message;
    end;
  finally
    LThread.Free;
  end;

  if LHasFatal then
    raise Exception.CreateFmt('%s raised on the worker thread: %s',
      [LFatalClassName, LFatalMessage]);

  Result := True;
end;

class function TKTestUtils.DataPath: string;
var
  LPath: string;
  I: Integer;
begin
  // The binary lives a few levels below the Test folder (Bin\<platform>\<config>),
  // and the working directory is not guaranteed, so walk up looking for Data.
  LPath := ExtractFilePath(ParamStr(0));
  for I := 0 to 6 do
  begin
    if TDirectory.Exists(TPath.Combine(LPath, 'Data')) then
      Exit(IncludeTrailingPathDelimiter(TPath.Combine(LPath, 'Data')));
    LPath := TDirectory.GetParent(ExcludeTrailingPathDelimiter(LPath));
    if LPath = '' then
      Break;
  end;
  raise Exception.CreateFmt(
    'Test data folder not found walking up from "%s".', [ExtractFilePath(ParamStr(0))]);
end;

class function TKTestUtils.DataFile(const AFileName: string): string;
begin
  Result := DataPath + AFileName;
end;

class function TKTestUtils.CreateTempPath: string;
begin
  Result := IncludeTrailingPathDelimiter(
    TPath.Combine(TPath.GetTempPath, 'KittoXTests_' + TPath.GetGUIDFileName(True)));
  TDirectory.CreateDirectory(Result);
end;

class procedure TKTestUtils.RemoveTempPath(const APath: string);
begin
  if (APath <> '') and TDirectory.Exists(APath) then
    TDirectory.Delete(APath, True);
end;

end.
