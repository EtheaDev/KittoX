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
unit EF.SysTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TEFSysTests = class
  strict private
    FTempPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure GetFileSize_ReturnsTheSize;

    [Test]
    procedure GetFileSize_OnMissingFile_ReturnsMinusOne;

    // The tests below exercise EF.Sys.Windows (cmd.exe, process handles,
    // TEFFileWriter), which only exists on Windows.
    {$IFDEF MSWINDOWS}
    /// <summary>
    ///  GetFileSize opens a search handle with FindFirst and used never to
    ///  close it: one kernel handle leaked per call. Reachable from anything
    ///  that checks a file size in a loop, and in a long-running service the
    ///  process eventually cannot open files at all. Many calls here would
    ///  exhaust the handles if the leak were back.
    /// </summary>
    [Test]
    procedure GetFileSize_CalledManyTimes_DoesNotLeakHandles;

    /// <summary>
    ///  Length counts characters and TStream.Write wants bytes, so exactly half
    ///  the content used to be written - and as raw UTF-16, unreadable by any
    ///  text reader. This is the only public file writer of the EF layer.
    /// </summary>
    [Test]
    procedure FileWriter_WritesTheWholeContent;

    /// <summary>
    ///  A command line has to reach the process whole, however long it is.
    ///
    ///  InternalExecuteApplication used to copy it into an array[0..511] of
    ///  Char with StrPCopy, which takes no length and does not truncate:
    ///  anything longer was written past the end of the array, over the locals
    ///  that follow it and, far enough along, the return address. This test
    ///  passes a command line of about nine hundred characters, which under the
    ///  old code would have written some four hundred characters past the end
    ///  of that buffer -- which is why it is not run against it. What it does
    ///  check is the other half: that the fix carries a long command line
    ///  through correctly rather than truncating it, since a silently truncated
    ///  command line runs something other than what was asked for.
    /// </summary>
    [Test]
    procedure ExecuteApplication_WithALongCommandLine_RunsItWhole;
    /// <summary>The short case, as a control: the exit code comes back.</summary>
    [Test]
    procedure ExecuteApplication_ReturnsTheExitCode;
    /// <summary>
    ///  The working directory went through a second buffer of the same kind.
    /// </summary>
    [Test]
    procedure ExecuteApplication_HonoursTheWorkingDirectory;
    /// <summary>An empty command line is an error, not a process.</summary>
    [Test]
    procedure ExecuteApplication_WithAnEmptyCommandLine_Fails;
    {$ENDIF}

    /// <summary>
    ///  UnregisterTool used to leave the current tool nil, and every _() call
    ///  goes through it without checking: the next translated string was an
    ///  access violation. All three callers are finalization sections, where a
    ///  unit finalized later can still want to log or raise something.
    /// </summary>
    [Test]
    procedure UnregisterLocalizationTool_LeavesTranslationWorking;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  EF.Sys.Windows,
  {$ENDIF}
  EF.Sys,
  EF.Localization,
  Kitto.TestUtils;

{ TEFSysTests }

procedure TEFSysTests.Setup;
begin
  FTempPath := TKTestUtils.CreateTempPath;
end;

procedure TEFSysTests.TearDown;
begin
  TKTestUtils.RemoveTempPath(FTempPath);
end;

procedure TEFSysTests.GetFileSize_ReturnsTheSize;
var
  LFileName: string;
begin
  LFileName := FTempPath + 'size.txt';
  TFile.WriteAllText(LFileName, '12345');
  Assert.AreEqual(Int64(5), Int64(GetFileSize(LFileName)));
end;

procedure TEFSysTests.GetFileSize_OnMissingFile_ReturnsMinusOne;
begin
  Assert.AreEqual(Int64(-1), Int64(GetFileSize(FTempPath + 'no_such_file.txt')));
end;

{$IFDEF MSWINDOWS}
procedure TEFSysTests.GetFileSize_CalledManyTimes_DoesNotLeakHandles;
const
  CALL_COUNT = 3000;
var
  LFileName: string;
  LBefore, LAfter: DWORD;
  I: Integer;
begin
  LFileName := FTempPath + 'handles.txt';
  TFile.WriteAllText(LFileName, 'x');

  GetProcessHandleCount(GetCurrentProcess, LBefore);
  for I := 1 to CALL_COUNT do
    GetFileSize(LFileName);
  GetProcessHandleCount(GetCurrentProcess, LAfter);

  // Some drift is normal in a running process; a leak of one handle per call
  // would show up as thousands.
  Assert.IsTrue(LAfter - LBefore < 100,
    Format('%d handles held after %d calls: the search handle is not being closed.',
      [LAfter - LBefore, CALL_COUNT]));
end;

procedure TEFSysTests.FileWriter_WritesTheWholeContent;
var
  LWriter: TEFFileWriter;
  LFileName: string;
  LContent: string;
begin
  LFileName := FTempPath + 'written.txt';
  LContent := 'First line.' + sLineBreak + 'Second line, longer than the first one.';
  LWriter := TEFFileWriter.Create;
  try
    LWriter.WriteFile(LFileName, LContent);
  finally
    LWriter.Free;
  end;

  Assert.IsTrue(TFile.Exists(LFileName), 'The file was not written at all.');
  Assert.AreEqual(LContent, TFile.ReadAllText(LFileName, TEncoding.UTF8),
    'The file does not contain what was written.');
end;

procedure TEFSysTests.ExecuteApplication_WithALongCommandLine_RunsItWhole;
var
  LPadding, LCommand: string;
begin
  // The padding sits inside a comparison of two equal strings, so the whole
  // line has to arrive for the exit to run: a line cut anywhere in the middle
  // leaves the quotes unbalanced and cmd reports a syntax error instead of 42.
  // ('rem <padding> & exit 42' does not work: rem swallows the & as part of
  // the remark, and the exit never runs -- which this test caught.)
  LPadding := StringOfChar('A', 420);
  LCommand := 'cmd.exe /c if "' + LPadding + '"=="' + LPadding + '" exit 42';
  Assert.IsTrue(Length(LCommand) > 512,
    'The command line is not long enough to mean anything: ' +
    IntToStr(Length(LCommand)) + ' characters.');
  Assert.AreEqual(42, ExecuteApplication(LCommand, '', True, SW_HIDE),
    'A command line of ' + IntToStr(Length(LCommand)) +
    ' characters did not reach the process whole.');
end;

procedure TEFSysTests.ExecuteApplication_ReturnsTheExitCode;
begin
  Assert.AreEqual(3, ExecuteApplication('cmd.exe /c exit 3', '', True, SW_HIDE));
  Assert.AreEqual(0, ExecuteApplication('cmd.exe /c exit 0', '', True, SW_HIDE));
end;

procedure TEFSysTests.ExecuteApplication_HonoursTheWorkingDirectory;
var
  LMarkerName: string;
begin
  // The marker exists only in the temporary directory this fixture creates, so
  // an exit code of 5 means the process really started there.
  LMarkerName := 'kx_marker.txt';
  TFile.WriteAllText(TPath.Combine(FTempPath, LMarkerName), 'x');
  Assert.AreEqual(5, ExecuteApplication(
    'cmd.exe /c if exist ' + LMarkerName + ' exit 5', FTempPath, True, SW_HIDE),
    'The process did not start in the directory it was given.');
end;

procedure TEFSysTests.ExecuteApplication_WithAnEmptyCommandLine_Fails;
begin
  Assert.AreEqual(-1, ExecuteApplication('', '', True, SW_HIDE));
end;
{$ENDIF}

procedure TEFSysTests.UnregisterLocalizationTool_LeavesTranslationWorking;
begin
  // No saving and restoring of the previous tool: these interfaces are not
  // reference counted (TEFNoRefCountObject) and RegisterTool frees the object
  // behind the one it replaces, so a saved reference is dangling by the time it
  // could be put back -- registering it again broke every _() call in the rest
  // of the suite. Unregistering already leaves a working tool behind, which is
  // the whole point of this test, and it is the same one the suite started
  // with: EF.Localization installs a TEFNullLocalizationTool at startup.
  TEFLocalizationToolRegistry.UnregisterTool;
  Assert.IsNotNull(TEFLocalizationToolRegistry.CurrentTool,
    'Unregistering left no tool at all, so the next _() would be an access ' +
    'violation.');
  // The call every translated string in the framework makes.
  Assert.AreEqual('untranslated', _('untranslated'));
end;

initialization
  TDUnitX.RegisterTestFixture(TEFSysTests);

end.
