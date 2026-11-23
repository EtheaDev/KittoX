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
///  What the user may attach to a question, and what must be refused. The
///  refusals are the point of these tests: a file sent to a model that cannot
///  read it looks like it worked, and a limit that is not held is a conversation
///  that fails at its <i>second</i> question - the attachments go up again with
///  every later one.
/// </summary>
unit Kitto.ChatAttachmentTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TKXChatAttachmentTests = class
  public
    /// <summary>The type is decided by the extension, and only the accepted
    /// ones have one.</summary>
    [Test]
    procedure MediaType_ComesFromTheExtension;
    /// <summary>A .docx and a .xlsx are not readable by any model: refused by
    /// name, not sent and ignored.</summary>
    [Test]
    procedure OfficeFiles_AreNotAccepted;
    /// <summary>A PDF travels as a document, a picture as an image, everything
    /// else as text.</summary>
    [Test]
    procedure Kind_FollowsTheMediaType;
    /// <summary>A text file is decoded when it arrives: a BOM decides, and
    /// bytes that are not UTF-8 are read with the ANSI code page rather than
    /// turned into a page of question marks.</summary>
    [Test]
    procedure Text_IsDecodedHonouringTheBom;
    /// <summary>The size as the panel writes it next to the name.</summary>
    [Test]
    procedure Size_IsFormattedForAHuman;
    /// <summary>A text attachment goes inside the question, between fences
    /// carrying its name; a question with no textual attachment is untouched.</summary>
    [Test]
    procedure TextAttachments_GoIntoTheQuestion;
    /// <summary>A file of a type nobody reads is refused with a sentence that
    /// names it.</summary>
    [Test]
    procedure Add_RefusesATypeNoModelReads;
    /// <summary>Over the size of one file, over the total of the conversation,
    /// over the count: three different refusals.</summary>
    [Test]
    procedure Add_HoldsTheThreeLimits;
    /// <summary>A picture has a lower limit of its own, because the service
    /// refuses a larger one and a refused picture fails every later question.</summary>
    [Test]
    procedure Add_HoldsTheLimitOfAPicture;
    /// <summary>A path sent by the browser is dropped: only the name is
    /// kept.</summary>
    [Test]
    procedure Add_KeepsOnlyTheNameOfTheFile;
    /// <summary>What is attached is listed, found by id, dropped one at a time
    /// and dropped altogether.</summary>
    [Test]
    procedure Set_ListsFindsAndDrops;
    /// <summary>Two users do not see each other's attachments.</summary>
    [Test]
    procedure Set_KeepsUsersApart;
  end;

implementation

uses
  System.SysUtils
  , System.Classes
  , Kitto.Chat.Attachments
  ;

const
  TEST_USER = 'attachment.tests@ethea';
  OTHER_USER = 'somebody.else@ethea';

function Bytes(const ASize: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, ASize);
  for I := 0 to ASize - 1 do
    Result[I] := Byte(65 + (I mod 26));
end;

function NoLimits: TKXChatAttachmentLimits;
begin
  Result.MaxCount := 0;
  Result.MaxSizeBytes := 0;
  Result.MaxTotalBytes := 0;
  Result.MaxImageBytes := 0;
end;

procedure Clean;
begin
  TKXChatAttachments.Instance.ClearUser(TEST_USER);
  TKXChatAttachments.Instance.ClearUser(OTHER_USER);
end;

{ TKXChatAttachmentTests }

procedure TKXChatAttachmentTests.MediaType_ComesFromTheExtension;
begin
  Assert.AreEqual('application/pdf', KXChatMediaTypeOf('manual.pdf'));
  Assert.AreEqual('image/jpeg', KXChatMediaTypeOf('photo.JPG'), 'the case does not matter');
  Assert.AreEqual('text/csv', KXChatMediaTypeOf('rows.csv'));
  Assert.AreEqual('', KXChatMediaTypeOf('noextension'));
  Assert.IsTrue(KXChatIsAcceptedFile('notes.md'));
  Assert.IsTrue(KXChatAcceptedExtensions.Contains('.pdf'),
    'the list the file dialog offers names what is accepted');
end;

procedure TKXChatAttachmentTests.OfficeFiles_AreNotAccepted;
begin
  Assert.IsFalse(KXChatIsAcceptedFile('contract.docx'), 'no model reads a .docx');
  Assert.IsFalse(KXChatIsAcceptedFile('budget.xlsx'), 'nor a .xlsx');
  Assert.IsFalse(KXChatAcceptedExtensions.Contains('.docx'),
    'and the file dialog must not offer one');
end;

procedure TKXChatAttachmentTests.Kind_FollowsTheMediaType;
begin
  Assert.IsTrue(KXChatKindOf('application/pdf') = cakDocument);
  Assert.IsTrue(KXChatKindOf('image/png') = cakImage);
  Assert.IsTrue(KXChatKindOf('text/markdown') = cakText);
end;

procedure TKXChatAttachmentTests.Text_IsDecodedHonouringTheBom;
var
  LUtf8, LAnsi: TBytes;
begin
  // 'perche' with an acute e, in UTF-8, with its BOM. The expected value is
  // built from the character code and not written as a literal: the test
  // sources carry no BOM, so the compiler would read a letter outside ASCII in
  // the code page of the machine and the test would be about that instead.
  LUtf8 := [$EF, $BB, $BF, $70, $65, $72, $63, $68, $C3, $A9];
  Assert.AreEqual('perch' + Char($00E9), KXChatDecodeText(LUtf8), 'the BOM decides');

  // The same word in Latin-1: not valid UTF-8, and it must not come through as
  // a replacement character.
  LAnsi := [$70, $65, $72, $63, $68, $E9];
  Assert.IsFalse(KXChatDecodeText(LAnsi).Contains(#$FFFD),
    'a file written before UTF-8 existed is still a file');

  Assert.AreEqual('', KXChatDecodeText(nil), 'nothing decodes to nothing');
end;

procedure TKXChatAttachmentTests.Size_IsFormattedForAHuman;
begin
  Assert.AreEqual('512 B', KXChatFormatSize(512));
  Assert.AreEqual('2 KB', KXChatFormatSize(2048));
  Assert.IsTrue(KXChatFormatSize(1572864).Contains('MB'), 'a megabyte is said in MB');
end;

procedure TKXChatAttachmentTests.TextAttachments_GoIntoTheQuestion;
var
  LAtt: TKXChatAttachment;
  LOut: string;
begin
  LAtt := Default(TKXChatAttachment);
  LAtt.FileName := 'rows.csv';
  LAtt.Kind := cakText;
  LAtt.Text := 'a;b;c';

  LOut := KXChatQuestionWithText('What is in it?', [LAtt]);
  Assert.IsTrue(LOut.Contains('rows.csv'), 'the name goes on the fence: ' + LOut);
  Assert.IsTrue(LOut.Contains('a;b;c'), 'and the content is there: ' + LOut);
  Assert.IsTrue(LOut.Contains('What is in it?'), 'with the question itself: ' + LOut);

  // A picture is not text: the question is handed over untouched, and the bytes
  // travel in a block of their own.
  LAtt := Default(TKXChatAttachment);
  LAtt.FileName := 'shot.png';
  LAtt.Kind := cakImage;
  LAtt.Data := Bytes(10);
  Assert.AreEqual('What is in it?', KXChatQuestionWithText('What is in it?', [LAtt]));
  Assert.IsTrue(KXChatHasBinaryAttachment([LAtt]), 'and it is one that travels as bytes');
end;

procedure TKXChatAttachmentTests.Add_RefusesATypeNoModelReads;
var
  LAtt: TKXChatAttachment;
  LError: string;
begin
  Clean;
  try
    Assert.IsFalse(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'contract.docx',
      Bytes(100), NoLimits, LAtt, LError));
    Assert.IsTrue(LError.Contains('contract.docx'),
      'the refusal names the file: ' + LError);
    Assert.AreEqual(0, TKXChatAttachments.Instance.Count(TEST_USER));

    Assert.IsFalse(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'empty.txt',
      nil, NoLimits, LAtt, LError), 'an empty file is nothing to read');
  finally
    Clean;
  end;
end;

procedure TKXChatAttachmentTests.Add_HoldsTheThreeLimits;
var
  LAtt: TKXChatAttachment;
  LError: string;
  LLimits: TKXChatAttachmentLimits;
begin
  Clean;
  try
    LLimits := NoLimits;
    LLimits.MaxSizeBytes := 1000;
    Assert.IsFalse(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'big.txt',
      Bytes(2000), LLimits, LAtt, LError), 'over the size of one file');
    Assert.IsTrue(LError <> '', 'and it says so');

    LLimits := NoLimits;
    LLimits.MaxTotalBytes := 1500;
    Assert.IsTrue(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'one.txt',
      Bytes(1000), LLimits, LAtt, LError), LError);
    Assert.IsFalse(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'two.txt',
      Bytes(1000), LLimits, LAtt, LError), 'over the total of the conversation');

    Clean;
    LLimits := NoLimits;
    LLimits.MaxCount := 1;
    Assert.IsTrue(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'one.txt',
      Bytes(10), LLimits, LAtt, LError), LError);
    Assert.IsFalse(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'two.txt',
      Bytes(10), LLimits, LAtt, LError), 'over the count');
  finally
    Clean;
  end;
end;

procedure TKXChatAttachmentTests.Add_HoldsTheLimitOfAPicture;
var
  LAtt: TKXChatAttachment;
  LError: string;
  LLimits: TKXChatAttachmentLimits;
begin
  Clean;
  try
    LLimits := NoLimits;
    LLimits.MaxSizeBytes := 100000;
    LLimits.MaxImageBytes := 1000;

    // The same size: accepted as text, refused as a picture.
    Assert.IsTrue(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'notes.txt',
      Bytes(5000), LLimits, LAtt, LError), LError);
    Assert.IsFalse(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'shot.png',
      Bytes(5000), LLimits, LAtt, LError),
      'a picture has a limit of its own, and it is lower');
  finally
    Clean;
  end;
end;

procedure TKXChatAttachmentTests.Add_KeepsOnlyTheNameOfTheFile;
var
  LAtt: TKXChatAttachment;
  LError: string;
begin
  Clean;
  try
    Assert.IsTrue(TKXChatAttachments.Instance.TryAdd(TEST_USER,
      'C:\Users\someone\Documents\manual.pdf', Bytes(50), NoLimits, LAtt, LError), LError);
    Assert.AreEqual('manual.pdf', LAtt.FileName,
      'what the browser said about its own disk is not kept');
    Assert.AreEqual('pdf', LAtt.Extension);
    Assert.IsTrue(LAtt.Kind = cakDocument);
    Assert.IsTrue(LAtt.Base64 <> '', 'the bytes are there, as the API wants them');
  finally
    Clean;
  end;
end;

procedure TKXChatAttachmentTests.Set_ListsFindsAndDrops;
var
  LFirst, LSecond, LFound: TKXChatAttachment;
  LError: string;
  LItems: TArray<TKXChatAttachment>;
begin
  Clean;
  try
    Assert.IsTrue(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'one.txt',
      Bytes(100), NoLimits, LFirst, LError), LError);
    Assert.IsTrue(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'two.pdf',
      Bytes(200), NoLimits, LSecond, LError), LError);

    LItems := TKXChatAttachments.Instance.ItemsOf(TEST_USER);
    // Length is a NativeInt in Delphi 13: the cast is what lets the generic
    // Assert pick one type for both sides.
    Assert.AreEqual(2, Integer(Length(LItems)));
    Assert.AreEqual('one.txt', LItems[0].FileName, 'oldest first');
    Assert.AreEqual(Int64(300), TKXChatAttachments.Instance.TotalSize(TEST_USER));

    Assert.IsTrue(TKXChatAttachments.Instance.TryGet(TEST_USER, LSecond.Id, LFound));
    Assert.AreEqual('two.pdf', LFound.FileName);

    Assert.IsTrue(TKXChatAttachments.Instance.Remove(TEST_USER, LFirst.Id));
    Assert.IsFalse(TKXChatAttachments.Instance.Remove(TEST_USER, LFirst.Id),
      'dropping what is no longer there is not an error, it is just False');
    Assert.AreEqual(1, TKXChatAttachments.Instance.Count(TEST_USER));

    TKXChatAttachments.Instance.ClearUser(TEST_USER);
    Assert.AreEqual(0, TKXChatAttachments.Instance.Count(TEST_USER));
  finally
    Clean;
  end;
end;

procedure TKXChatAttachmentTests.Set_KeepsUsersApart;
var
  LMine, LTheirs: TKXChatAttachment;
  LError: string;
  LFound: TKXChatAttachment;
begin
  Clean;
  try
    Assert.IsTrue(TKXChatAttachments.Instance.TryAdd(TEST_USER, 'mine.txt',
      Bytes(10), NoLimits, LMine, LError), LError);
    Assert.IsTrue(TKXChatAttachments.Instance.TryAdd(OTHER_USER, 'theirs.txt',
      Bytes(10), NoLimits, LTheirs, LError), LError);

    Assert.AreEqual(1, TKXChatAttachments.Instance.Count(TEST_USER));
    // The id of somebody else's file is not a way to reach it.
    Assert.IsFalse(TKXChatAttachments.Instance.TryGet(TEST_USER, LTheirs.Id, LFound));
    Assert.IsFalse(TKXChatAttachments.Instance.Remove(TEST_USER, LTheirs.Id));
    Assert.AreEqual(1, TKXChatAttachments.Instance.Count(OTHER_USER),
      'and it is still there');
  finally
    Clean;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TKXChatAttachmentTests);

end.
