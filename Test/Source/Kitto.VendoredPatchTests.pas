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
///  Guards over the patches applied to vendored sources. They read the source
///  files themselves, which is unusual for a test and is the point: a patch to
///  somebody else's code is exactly what an alignment with upstream silently
///  undoes. It happened in this repository before - a configuration of a JSON
///  library went missing in a re-vendoring and every tool with an object
///  parameter started answering "X is required" - and nothing noticed.
///  <para>What is guarded here is worse than wrong behaviour: a server process
///  that <b>stops and waits for a click</b>.</para>
/// </summary>
unit Kitto.VendoredPatchTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TKVendoredPatchTests = class
  public
    /// <summary>gnugettext used to open a MessageBox when a catalog was not
    /// what it expected. In a Windows service or an ISAPI that window is a
    /// process that never comes back: nobody is at the desktop of a service.
    /// Both vendored copies must be free of it.</summary>
    [Test]
    procedure GnuGettext_OpensNoDialog;
    /// <summary>And the way out that replaced it must still be there, or the
    /// problem would simply be silent - which is how a server loses its
    /// translations without anybody knowing.</summary>
    [Test]
    procedure GnuGettext_ReportsTheProblemInstead;
    /// <summary>Nor may it reach for the VCL: a unit a server links has no
    /// business pulling in a user interface.</summary>
    [Test]
    procedure GnuGettext_UsesOnlyTheRtl;
  end;

implementation

uses
  System.SysUtils
  , System.Classes
  , System.IOUtils
  , System.StrUtils
  , Kitto.gnugettext
  , Kitto.TestUtils
  ;

/// The vendored sources, found by walking up from the binary as the rest of
/// the suite does.
function VendoredSource(const AFileName: string): string;
var
  LPath: string;
  I: Integer;
begin
  LPath := ExtractFilePath(ParamStr(0));
  for I := 0 to 6 do
  begin
    Result := TPath.Combine(TPath.Combine(TPath.Combine(LPath, 'Source'), 'ThirdParty'), AFileName);
    if TFile.Exists(Result) then
      Exit;
    LPath := TDirectory.GetParent(ExcludeTrailingPathDelimiter(LPath));
    if LPath = '' then
      Break;
  end;
  raise Exception.CreateFmt('Vendored source not found: %s', [AFileName]);
end;

/// The lines of a source file that are not comments: a rule about what the
/// code does must not be broken by what a comment says.
function CodeLines(const AFileName: string): TArray<string>;
var
  LLines: TArray<string>;
  LLine, LTrimmed: string;
  LResult: TStringList;
begin
  LLines := TFile.ReadAllLines(VendoredSource(AFileName));
  LResult := TStringList.Create;
  try
    for LLine in LLines do
    begin
      LTrimmed := LLine.TrimLeft;
      if LTrimmed.StartsWith('//') or LTrimmed.StartsWith('{') or
        LTrimmed.StartsWith('(*') then
        Continue;
      LResult.Add(LLine);
    end;
    Result := LResult.ToStringArray;
  finally
    LResult.Free;
  end;
end;

{ TKVendoredPatchTests }

procedure TKVendoredPatchTests.GnuGettext_OpensNoDialog;
const
  FILES: array[0..1] of string = ('gnugettext.pas', 'Kitto.gnugettext.pas');
var
  LFile, LLine: string;
begin
  for LFile in FILES do
    for LLine in CodeLines(LFile) do
      if LLine.Contains('MessageBox') then
        Assert.Fail(Format(
          '%s opens a dialog: "%s". A server process must not be able to - ' +
          'in a service or an ISAPI nobody closes it. Report the problem ' +
          'through GnuGettextOnProblem instead.', [LFile, LLine.Trim]));
  Assert.Pass;
end;

procedure TKVendoredPatchTests.GnuGettext_ReportsTheProblemInstead;
const
  FILES: array[0..1] of string = ('gnugettext.pas', 'Kitto.gnugettext.pas');
var
  LFile, LText: string;
begin
  for LFile in FILES do
  begin
    LText := TFile.ReadAllText(VendoredSource(LFile));
    Assert.IsTrue(LText.Contains('GnuGettextOnProblem'),
      LFile + ': the way out of the dialog is gone. An alignment with ' +
      'upstream probably took the patch with it.');
    Assert.IsTrue(LText.Contains('ETHEA PATCH'),
      LFile + ': the patch is not marked, and an unmarked patch is one that ' +
      'disappears at the next alignment.');
  end;

  // And the hook is a real one, that a program can take hold of.
  Assert.IsTrue(Assigned(@GnuGettextOnProblem) or not Assigned(GnuGettextOnProblem),
    'GnuGettextOnProblem must exist to be assignable');
end;

procedure TKVendoredPatchTests.GnuGettext_UsesOnlyTheRtl;
const
  FILES: array[0..1] of string = ('gnugettext.pas', 'Kitto.gnugettext.pas');
  FORBIDDEN: array[0..3] of string = ('Vcl.', 'FMX.', 'Vcl,', 'Forms,');
var
  LFile, LLine, LBad: string;
begin
  for LFile in FILES do
    for LLine in CodeLines(LFile) do
      for LBad in FORBIDDEN do
        if LLine.Contains(LBad) then
          Assert.Fail(Format('%s reaches for a user interface: "%s"',
            [LFile, LLine.Trim]));
  Assert.Pass;
end;

initialization
  TDUnitX.RegisterTestFixture(TKVendoredPatchTests);

end.
