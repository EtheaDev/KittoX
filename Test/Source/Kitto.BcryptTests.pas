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
///  Password hashes must verify on every platform KittoX runs on: a database
///  moved from a Windows server to a Linux one keeps its KITTO_USERS table, and
///  a hash that no longer verifies locks its user out without a word.
///
///  The hashes below were produced on Windows, where Kitto.Bcrypt prepares the
///  password with FoldStringW and hashes with the CryptoAPI. On Linux the same
///  steps go through ICU and System.Hash; these tests are what proves the two
///  agree. On Windows they pass by construction and guard against regressions.
/// </summary>
unit Kitto.BcryptTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TKBcryptTests = class
  public
    /// <summary>A hash made on Windows verifies here.</summary>
    [Test]
    [TestCase('ASCII', 'ascii')]
    [TestCase('Latin accents and euro', 'latin')]
    [TestCase('Fullwidth', 'fullwidth')]
    [TestCase('Surrogate pair', 'surrogate')]
    [TestCase('Halfwidth katakana', 'halfkana')]
    procedure WindowsHash_Verifies(const AVector: string);

    /// <summary>
    ///  The password is normalized with NFKC before hashing (that is what
    ///  FoldStringW(MAP_FOLDCZONE) turns out to do on Windows), so its
    ///  equivalent spellings verify against the same hash: a decomposed accent,
    ///  fullwidth digits, halfwidth katakana.
    /// </summary>
    [Test]
    [TestCase('Decomposed accents', 'latin,decomposed')]
    [TestCase('Fullwidth to ASCII', 'fullwidth,ascii-equivalent')]
    [TestCase('Halfwidth to fullwidth katakana', 'halfkana,fullwidth-kana')]
    procedure EquivalentSpelling_Verifies(const AVector, ASpelling: string);

    /// <summary>A wrong password still fails: normalization must not make
    /// unrelated passwords collide.</summary>
    [Test]
    procedure WrongPassword_DoesNotVerify;

    /// <summary>The SHA-256 prehash, null terminator included, as on
    /// Windows.</summary>
    [Test]
    procedure Prehash256_MatchesWindows;

    /// <summary>Hash and verify on this platform, which exercises its random
    /// salt source.</summary>
    [Test]
    procedure HashThenCheck_RoundTrips;

    /// <summary>Two hashes of one password differ: the salt is random.</summary>
    [Test]
    procedure TwoHashes_HaveDifferentSalts;

    /// <summary>The library's own known-answer self test.</summary>
    [Test]
    procedure LibrarySelfTest_Passes;
  end;

implementation

uses
  System.SysUtils,
  Kitto.Bcrypt;

function VectorPassword(const AName: string): string;
begin
  if AName = 'ascii' then
    Result := 'password'
  else if AName = 'latin' then
    Result := 'p' + #$00E0 + 'ssw' + #$00F6 + 'rd' + #$20AC
  else if AName = 'fullwidth' then
    Result := #$FF30#$FF41#$FF53#$FF53#$FF11#$FF12#$FF13
  else if AName = 'surrogate' then
    Result := #$D83D#$DD11 + 'key'
  else if AName = 'halfkana' then
    Result := #$FF76 + 'x'
  // Equivalent spellings of the vectors above.
  else if AName = 'decomposed' then
    Result := 'pa' + #$0300 + 'sswo' + #$0308 + 'rd' + #$20AC
  else if AName = 'ascii-equivalent' then
    Result := 'Pass123'
  else if AName = 'fullwidth-kana' then
    Result := #$30AB + 'x'
  else
    raise Exception.CreateFmt('Unknown vector "%s"', [AName]);
end;

function VectorHash(const AName: string): string;
begin
  // Generated on Windows (Delphi 13, Win64) with TBCrypt.HashPassword(P, 4).
  if AName = 'ascii' then
    Result := '$2a$04$MqGnNVVmhoxJPvpaXPC6VOQ5oybLc2zIuZB4GdySQaN2P4l3fMrX2'
  else if AName = 'latin' then
    Result := '$2a$04$0tdnYnee2pH47U6ksVRvAearAKgsEH4YtJ6d5YIkIWCSW9NRSznaK'
  else if AName = 'fullwidth' then
    Result := '$2a$04$ZUeG1rOg/u.ni4AvC49fCOdaTSsXHnnrk8WZPQnBRAYGBy.bpIAC6'
  else if AName = 'surrogate' then
    Result := '$2a$04$7zzb5gg2NfLqY8td6faxk.CwzPoLQ16Aa7pXjEGnTPfEYY3dvTm/6'
  else if AName = 'halfkana' then
    Result := '$2a$04$8cun9uT4rDSx0ITUdzFWtuzdf9ANYXfnT98GHNrVmpeMAfH.cw4dC'
  else
    raise Exception.CreateFmt('Unknown vector "%s"', [AName]);
end;

function Verifies(const APassword, AHash: string): Boolean;
var
  LRehashNeeded: Boolean;
begin
  Result := TBCrypt.CheckPassword(APassword, AHash, LRehashNeeded);
end;

{ TKBcryptTests }

procedure TKBcryptTests.WindowsHash_Verifies(const AVector: string);
begin
  Assert.IsTrue(Verifies(VectorPassword(AVector), VectorHash(AVector)),
    'The hash made on Windows for "' + AVector + '" does not verify here.');
end;

procedure TKBcryptTests.EquivalentSpelling_Verifies(const AVector, ASpelling: string);
begin
  Assert.IsTrue(Verifies(VectorPassword(ASpelling), VectorHash(AVector)),
    '"' + ASpelling + '" is not normalized to the same password as "' + AVector + '".');
end;

procedure TKBcryptTests.WrongPassword_DoesNotVerify;
begin
  Assert.IsFalse(Verifies('passwort', VectorHash('ascii')));
  Assert.IsFalse(Verifies('p' + #$00E1 + 'ssw' + #$00F6 + 'rd' + #$20AC, VectorHash('latin')));
end;

procedure TKBcryptTests.Prehash256_MatchesWindows;
begin
  Assert.AreEqual('4FQIYEXzaDXcnczroK0QXDH9Gb7RWOmFhhP5EQS4kYs=',
    TBCrypt.Prehash256('password'));
  Assert.AreEqual('Jg/1mtoNOY/XJ4aAUyXbhNTr0t24MKfHDN8kO1+pVKM=',
    TBCrypt.Prehash256(VectorPassword('latin')));
end;

procedure TKBcryptTests.HashThenCheck_RoundTrips;
var
  LHash: string;
begin
  LHash := TBCrypt.HashPassword(VectorPassword('latin'), 4);
  Assert.IsTrue(Verifies(VectorPassword('latin'), LHash));
  Assert.IsTrue(Verifies(VectorPassword('decomposed'), LHash));
end;

procedure TKBcryptTests.TwoHashes_HaveDifferentSalts;
begin
  Assert.AreNotEqual(TBCrypt.HashPassword('password', 4), TBCrypt.HashPassword('password', 4));
end;

procedure TKBcryptTests.LibrarySelfTest_Passes;
begin
  Assert.IsTrue(TBCrypt.SelfTest);
end;

initialization
  TDUnitX.RegisterTestFixture(TKBcryptTests);

end.
