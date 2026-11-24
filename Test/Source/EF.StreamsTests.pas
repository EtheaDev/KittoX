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
///  Tests for TEFBufferedReadFilter: what comes out of it has to be the bytes
///  of the decorated stream, in order, once, and nowhere but in the buffer the
///  caller supplied.
/// </summary>
unit EF.StreamsTests;

interface

uses
  System.Classes,
  System.SysUtils,
  EF.Streams,
  DUnitX.TestFramework;

type
  [TestFixture]
  TEFBufferedReadFilterTests = class
  strict private
    const
      // TEFBufferedReadFilter.BUFFER_SIZE. Not published by the unit, so the
      // tests that need to straddle the boundary carry their own copy; if the
      // constant there changes, ExpectedInternalBufferSize below says so.
      INTERNAL_BUFFER_SIZE = 16384;
      // Enough to need a second bufferful.
      STREAM_SIZE = 20000;
    var
      // The const section above stays open until a new one starts.
      FEndOfStreamCount: Integer;
    procedure EndOfStreamHandler(Sender: TObject);
    /// <summary>Byte I of the stream every test reads. Values do not repeat
    /// with a period of two, so a read that takes every other byte cannot come
    /// out looking right.</summary>
    class function ByteAt(const AIndex: Integer): Byte; static;
    /// <summary>A memory stream of ASize bytes, ByteAt(I) at each position,
    /// positioned at the start.</summary>
    class function SourceStream(const ASize: Integer): TMemoryStream; static;
  public
    [Setup]
    procedure Setup;

    /// <summary>
    ///  Regression. The internal buffer was a PChar and the position counting
    ///  into it a number of bytes, so from the second read onwards the source
    ///  offset was twice the intended one: the caller got every other byte, and
    ///  once the position passed half the buffer the filter was reading off the
    ///  end of its own allocation.
    /// </summary>
    [Test]
    [TestCase('two bytes at a time - what TEFTextStream.ReadLn asks for', '2')]
    [TestCase('one byte at a time', '1')]
    [TestCase('seven bytes at a time', '7')]
    [TestCase('an odd chunk that outlives the first bufferful', '3000')]
    procedure Read_InChunks_ReturnsEveryByteInOrder(const AChunkSize: Integer);

    /// <summary>
    ///  Regression. Between two fills of the internal buffer the destination
    ///  pointer was advanced by twice the bytes just written, so the remainder
    ///  of a read larger than the internal buffer landed past the end of the
    ///  caller's buffer. The destination here is far larger than the read, so
    ///  that a write that goes long lands inside this test's own memory and can
    ///  be reported instead of corrupting the heap.
    /// </summary>
    [Test]
    procedure Read_LargerThanTheInternalBuffer_WritesOnlyWhatTheCallerAskedFor;

    /// <summary>
    ///  A read that runs out of stream returns what there was and fires
    ///  OnEndOfStream, which is the class's documented contract.
    /// </summary>
    [Test]
    procedure Read_PastTheEnd_ReturnsWhatIsLeftAndFiresEndOfStream;

    /// <summary>
    ///  And a read attempted when there is nothing left at all fires it too.
    ///  That path used to return zero and say nothing.
    /// </summary>
    [Test]
    procedure Read_OnAnExhaustedStream_FiresEndOfStream;

    /// <summary>
    ///  Seek(0, soCurrent) reports the position the reader is logically at, not
    ///  the one the decorated stream has been advanced to by buffering.
    /// </summary>
    [Test]
    procedure Seek_Current_ReportsTheLogicalPosition;

    /// <summary>
    ///  Guards the copy of BUFFER_SIZE these tests carry: if it ever stops
    ///  matching, the boundary cases above stop straddling the boundary and
    ///  silently test nothing interesting.
    /// </summary>
    [Test]
    procedure ExpectedInternalBufferSize;
  end;

type
  /// <summary>
  ///  TEFTextStream reads back what it writes, and both directions are UTF-8.
  ///
  ///  There was no test that ever wrote and then read: WriteLn encoded to UTF-8
  ///  while ReadLn read SizeOf(Char) — two bytes — per character, as if the
  ///  stream were UTF-16. So a file this class wrote was not a file it could
  ///  read, and on plain ASCII it never even found a line break, because a line
  ///  break was only recognised where two bytes happened to be exactly $000A.
  ///  The round trip is the whole point of the class, and it is what these
  ///  cases pin.
  /// </summary>
  [TestFixture]
  TEFTextStreamTests = class
  strict private
    /// <summary>Writes the lines with WriteLn, then reads them back with
    /// ReadLn from the beginning, and returns what came back.</summary>
    function RoundTrip(const ALines: TArray<string>;
      const ALineBreak: string = ''): TArray<string>;
    /// <summary>Reads every line of a stream built from the given raw bytes,
    /// stopping at EOT.</summary>
    function ReadLinesOf(const ABytes: TBytes): TArray<string>;
  public
    /// <summary>One line of plain ASCII comes back identical. Before the fix
    /// this alone failed: ReadLn consumed the line two bytes at a time.</summary>
    [Test]
    procedure WriteLnThenReadLn_Ascii_ComesBackIdentical;

    /// <summary>Accented and multi-byte characters survive the round trip:
    /// two, three and four UTF-8 bytes per character.</summary>
    [Test]
    procedure WriteLnThenReadLn_NonAscii_ComesBackIdentical;

    /// <summary>Several lines come back in order, one per ReadLn.</summary>
    [Test]
    procedure WriteLnThenReadLn_ManyLines_ComeBackInOrder;

    /// <summary>An empty line stays an empty line, and is not mistaken for the
    /// end of the text.</summary>
    [Test]
    procedure WriteLnThenReadLn_AnEmptyLine_StaysEmpty;

    /// <summary>Both LF and CR+LF are accepted, whatever LineBreak says: the
    /// property is documented not to affect reading.</summary>
    [Test]
    [TestCase('LF', #10)]
    [TestCase('CRLF', #13#10)]
    procedure ReadLn_EitherLineBreak_ReadsTheSameLines(const ALineBreak: string);

    /// <summary>Past the last line ReadLn answers EOT.</summary>
    [Test]
    procedure ReadLn_PastTheEnd_ReturnsEOT;

    /// <summary>A byte-order mark belongs to the file, not to the text: it does
    /// not turn up at the head of the first line.</summary>
    [Test]
    procedure ReadLn_OnAStreamWithABOM_DoesNotReturnItInTheText;

    /// <summary>WriteLn writes no byte-order mark of its own.</summary>
    [Test]
    procedure WriteLn_WritesNoBOM;

    /// <summary>And the bytes on the stream really are UTF-8, not just
    /// self-consistent: checked against TEncoding.UTF8.</summary>
    [Test]
    procedure WriteLn_ProducesUTF8Bytes;
  end;

implementation

{ TEFBufferedReadFilterTests }

procedure TEFBufferedReadFilterTests.Setup;
begin
  FEndOfStreamCount := 0;
end;

procedure TEFBufferedReadFilterTests.EndOfStreamHandler(Sender: TObject);
begin
  Inc(FEndOfStreamCount);
end;

class function TEFBufferedReadFilterTests.ByteAt(const AIndex: Integer): Byte;
begin
  // 31 is odd and coprime with 256, so consecutive values differ and the
  // sequence does not repeat within a byte's range.
  Result := Byte((AIndex * 31 + 17) and $FF);
end;

class function TEFBufferedReadFilterTests.SourceStream(const ASize: Integer): TMemoryStream;
var
  LStream: TMemoryStream;
  LBytes: TBytes;
  I: Integer;
begin
  SetLength(LBytes, ASize);
  for I := 0 to ASize - 1 do
    LBytes[I] := ByteAt(I);
  LStream := TMemoryStream.Create;
  try
    if ASize > 0 then
      LStream.WriteBuffer(LBytes[0], ASize);
    LStream.Position := 0;
  except
    LStream.Free;
    raise;
  end;
  Result := LStream;
end;

procedure TEFBufferedReadFilterTests.Read_InChunks_ReturnsEveryByteInOrder(
  const AChunkSize: Integer);
var
  LFilter: TEFBufferedReadFilter;
  LChunk: TBytes;
  LRead, LTotal, I: Integer;
begin
  SetLength(LChunk, AChunkSize);
  LFilter := TEFBufferedReadFilter.Create(SourceStream(STREAM_SIZE), True);
  try
    LTotal := 0;
    repeat
      LRead := LFilter.Read(LChunk[0], AChunkSize);
      for I := 0 to LRead - 1 do
        Assert.AreEqual(ByteAt(LTotal + I), LChunk[I],
          Format('Byte %d of the stream came back wrong, reading %d at a time.',
            [LTotal + I, AChunkSize]));
      Inc(LTotal, LRead);
    until LRead < AChunkSize;
    Assert.AreEqual(STREAM_SIZE, LTotal,
      'The filter did not return the whole stream.');
  finally
    LFilter.Free;
  end;
end;

procedure TEFBufferedReadFilterTests.Read_LargerThanTheInternalBuffer_WritesOnlyWhatTheCallerAskedFor;
const
  SENTINEL = $CD;
  // Four times the read, so that a destination pointer advanced twice as fast
  // as it should still lands inside this array.
  DESTINATION_SIZE = STREAM_SIZE * 4;
var
  LFilter: TEFBufferedReadFilter;
  LDestination: TBytes;
  LRead, I: Integer;
begin
  SetLength(LDestination, DESTINATION_SIZE);
  FillChar(LDestination[0], DESTINATION_SIZE, SENTINEL);

  LFilter := TEFBufferedReadFilter.Create(SourceStream(STREAM_SIZE), True);
  try
    LRead := LFilter.Read(LDestination[0], STREAM_SIZE);
    Assert.AreEqual(STREAM_SIZE, LRead, 'The filter did not return the whole stream.');
  finally
    LFilter.Free;
  end;

  for I := 0 to STREAM_SIZE - 1 do
    Assert.AreEqual(ByteAt(I), LDestination[I],
      Format('Byte %d of the stream came back wrong.', [I]));
  for I := STREAM_SIZE to DESTINATION_SIZE - 1 do
    Assert.AreEqual(Byte(SENTINEL), LDestination[I],
      Format('The filter wrote at offset %d, past the %d bytes it was given.',
        [I, STREAM_SIZE]));
end;

procedure TEFBufferedReadFilterTests.Read_PastTheEnd_ReturnsWhatIsLeftAndFiresEndOfStream;
var
  LFilter: TEFBufferedReadFilter;
  LDestination: TBytes;
  LRead, I: Integer;
begin
  SetLength(LDestination, STREAM_SIZE * 2);
  LFilter := TEFBufferedReadFilter.Create(SourceStream(STREAM_SIZE), True);
  try
    LFilter.OnEndOfStream := EndOfStreamHandler;
    LRead := LFilter.Read(LDestination[0], STREAM_SIZE * 2);
    Assert.AreEqual(STREAM_SIZE, LRead);
    for I := 0 to STREAM_SIZE - 1 do
      Assert.AreEqual(ByteAt(I), LDestination[I],
        Format('Byte %d of the stream came back wrong.', [I]));
    Assert.AreEqual(1, FEndOfStreamCount, 'OnEndOfStream did not fire.');
  finally
    LFilter.Free;
  end;
end;

procedure TEFBufferedReadFilterTests.Read_OnAnExhaustedStream_FiresEndOfStream;
var
  LFilter: TEFBufferedReadFilter;
  LDestination: TBytes;
begin
  SetLength(LDestination, 16);
  LFilter := TEFBufferedReadFilter.Create(SourceStream(0), True);
  try
    LFilter.OnEndOfStream := EndOfStreamHandler;
    // Longint, not a literal Integer: it is 64-bit on Linux64.
    Assert.AreEqual<Longint>(0, LFilter.Read(LDestination[0], 16));
    Assert.AreEqual(1, FEndOfStreamCount,
      'OnEndOfStream did not fire on a read that returned nothing.');
  finally
    LFilter.Free;
  end;
end;

procedure TEFBufferedReadFilterTests.Seek_Current_ReportsTheLogicalPosition;
var
  LFilter: TEFBufferedReadFilter;
  LDestination: TBytes;
begin
  SetLength(LDestination, 100);
  LFilter := TEFBufferedReadFilter.Create(SourceStream(STREAM_SIZE), True);
  try
    Assert.AreEqual(Int64(0), LFilter.Seek(Int64(0), soCurrent));
    LFilter.Read(LDestination[0], 100);
    // 100, not the 16384 the decorated stream has been advanced to.
    Assert.AreEqual(Int64(100), LFilter.Seek(Int64(0), soCurrent));
    LFilter.Read(LDestination[0], 100);
    Assert.AreEqual(Int64(200), LFilter.Seek(Int64(0), soCurrent));
  finally
    LFilter.Free;
  end;
end;

procedure TEFBufferedReadFilterTests.ExpectedInternalBufferSize;
var
  LSource: TMemoryStream;
  LFilter: TEFBufferedReadFilter;
  LDestination: TBytes;
begin
  SetLength(LDestination, 1);
  LSource := SourceStream(STREAM_SIZE);
  LFilter := TEFBufferedReadFilter.Create(LSource, True);
  try
    // One byte asked for, one bufferful actually taken off the decorated
    // stream: its position is the filter's buffer size.
    LFilter.Read(LDestination[0], 1);
    Assert.AreEqual(Int64(INTERNAL_BUFFER_SIZE), LSource.Position,
      'The internal buffer is no longer ' + IntToStr(INTERNAL_BUFFER_SIZE) +
      ' bytes: the boundary cases in this fixture need their constant updated.');
  finally
    LFilter.Free;
  end;
end;

{ TEFTextStreamTests }

function TEFTextStreamTests.RoundTrip(const ALines: TArray<string>;
  const ALineBreak: string): TArray<string>;
var
  LMemory: TMemoryStream;
  LText: TEFTextStream;
  LLine: string;
  LRead: string;
begin
  SetLength(Result, 0);
  LMemory := TMemoryStream.Create;
  try
    LText := TEFTextStream.Create(LMemory, False);
    try
      if ALineBreak <> '' then
        LText.LineBreak := ALineBreak;
      for LLine in ALines do
        LText.WriteLn(LLine);
      LMemory.Position := 0;
      repeat
        LRead := LText.ReadLn;
        if LRead <> TEFTextStream.EOT then
          Result := Result + [LRead];
      until LRead = TEFTextStream.EOT;
    finally
      LText.Free;
    end;
  finally
    LMemory.Free;
  end;
end;

function TEFTextStreamTests.ReadLinesOf(const ABytes: TBytes): TArray<string>;
var
  LMemory: TMemoryStream;
  LText: TEFTextStream;
  LRead: string;
begin
  SetLength(Result, 0);
  LMemory := TMemoryStream.Create;
  try
    if Length(ABytes) > 0 then
      LMemory.WriteBuffer(ABytes[0], Length(ABytes));
    LMemory.Position := 0;
    LText := TEFTextStream.Create(LMemory, False);
    try
      repeat
        LRead := LText.ReadLn;
        if LRead <> TEFTextStream.EOT then
          Result := Result + [LRead];
      until LRead = TEFTextStream.EOT;
    finally
      LText.Free;
    end;
  finally
    LMemory.Free;
  end;
end;

procedure TEFTextStreamTests.WriteLnThenReadLn_Ascii_ComesBackIdentical;
var
  LBack: TArray<string>;
begin
  LBack := RoundTrip(['The quick brown fox']);
  Assert.AreEqual(1, Integer(Length(LBack)), 'One line written, one line read');
  Assert.AreEqual('The quick brown fox', LBack[0]);
end;

procedure TEFTextStreamTests.WriteLnThenReadLn_NonAscii_ComesBackIdentical;
var
  LBack: TArray<string>;
  LLine: string;
begin
  // Two bytes (à, è), three (€, 日), four (the emoji, a surrogate pair in UTF-16)
  LLine := 'Città perché 10€ 日本 ' + #$D83D#$DE00;
  LBack := RoundTrip([LLine]);
  Assert.AreEqual(1, Integer(Length(LBack)));
  Assert.AreEqual(LLine, LBack[0]);
end;

procedure TEFTextStreamTests.WriteLnThenReadLn_ManyLines_ComeBackInOrder;
var
  LBack: TArray<string>;
begin
  LBack := RoundTrip(['prima', 'seconda', 'terza']);
  Assert.AreEqual(3, Integer(Length(LBack)));
  Assert.AreEqual('prima', LBack[0]);
  Assert.AreEqual('seconda', LBack[1]);
  Assert.AreEqual('terza', LBack[2]);
end;

procedure TEFTextStreamTests.WriteLnThenReadLn_AnEmptyLine_StaysEmpty;
var
  LBack: TArray<string>;
begin
  LBack := RoundTrip(['sopra', '', 'sotto']);
  Assert.AreEqual(3, Integer(Length(LBack)), 'The empty line is a line, not the end');
  Assert.AreEqual('sopra', LBack[0]);
  Assert.AreEqual('', LBack[1]);
  Assert.AreEqual('sotto', LBack[2]);
end;

procedure TEFTextStreamTests.ReadLn_EitherLineBreak_ReadsTheSameLines(
  const ALineBreak: string);
var
  LBack: TArray<string>;
begin
  LBack := RoundTrip(['una', 'due'], ALineBreak);
  Assert.AreEqual(2, Integer(Length(LBack)));
  Assert.AreEqual('una', LBack[0]);
  Assert.AreEqual('due', LBack[1]);
end;

procedure TEFTextStreamTests.ReadLn_PastTheEnd_ReturnsEOT;
var
  LMemory: TMemoryStream;
  LText: TEFTextStream;
begin
  LMemory := TMemoryStream.Create;
  try
    LText := TEFTextStream.Create(LMemory, False);
    try
      LText.WriteLn('sola');
      LMemory.Position := 0;
      Assert.AreEqual('sola', LText.ReadLn);
      Assert.AreEqual(TEFTextStream.EOT, LText.ReadLn, 'End of text');
      Assert.AreEqual(TEFTextStream.EOT, LText.ReadLn, 'And it stays EOT');
    finally
      LText.Free;
    end;
  finally
    LMemory.Free;
  end;
end;

procedure TEFTextStreamTests.ReadLn_OnAStreamWithABOM_DoesNotReturnItInTheText;
var
  LBytes: TBytes;
  LBack: TArray<string>;
begin
  LBytes := [$EF, $BB, $BF] + TEncoding.UTF8.GetBytes('con il BOM davanti' + #10);
  LBack := ReadLinesOf(LBytes);
  Assert.AreEqual(1, Integer(Length(LBack)));
  Assert.AreEqual('con il BOM davanti', LBack[0],
    'The byte-order mark belongs to the file, not to the first line');
end;

procedure TEFTextStreamTests.WriteLn_WritesNoBOM;
var
  LMemory: TMemoryStream;
  LText: TEFTextStream;
  LFirst: Byte;
begin
  LMemory := TMemoryStream.Create;
  try
    LText := TEFTextStream.Create(LMemory, False);
    try
      LText.WriteLn('abc');
      LMemory.Position := 0;
      LMemory.ReadBuffer(LFirst, 1);
      Assert.AreEqual(Byte(Ord('a')), LFirst, 'The text starts at the first byte');
    finally
      LText.Free;
    end;
  finally
    LMemory.Free;
  end;
end;

procedure TEFTextStreamTests.WriteLn_ProducesUTF8Bytes;
var
  LMemory: TMemoryStream;
  LText: TEFTextStream;
  LWritten: TBytes;
  LExpected: TBytes;
begin
  LMemory := TMemoryStream.Create;
  try
    LText := TEFTextStream.Create(LMemory, False);
    try
      LText.LineBreak := #10;
      LText.WriteLn('perché 10€');
    finally
      LText.Free;
    end;
    SetLength(LWritten, LMemory.Size);
    LMemory.Position := 0;
    if LMemory.Size > 0 then
      LMemory.ReadBuffer(LWritten[0], LMemory.Size);
  finally
    LMemory.Free;
  end;
  LExpected := TEncoding.UTF8.GetBytes('perché 10€' + #10);
  Assert.AreEqual(Length(LExpected), Length(LWritten), 'Same number of bytes');
  Assert.IsTrue(CompareMem(@LExpected[0], @LWritten[0], Length(LExpected)),
    'The bytes on the stream are the UTF-8 encoding of the text');
end;

initialization
  TDUnitX.RegisterTestFixture(TEFBufferedReadFilterTests);
  TDUnitX.RegisterTestFixture(TEFTextStreamTests);

end.
