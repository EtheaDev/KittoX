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

///	<summary>
///	  This unit contains a set of stream decorators to add buffering, textline
///	  support and other features to rtl streams.
///	</summary>
///	<remarks>
///	  Some code in this unit is based on code by Julian M. Bucknall and
///	  published on The Delphi Magazine.
///	</remarks>
unit EF.Streams;

{$I EF.Defines.inc}

interface

uses
  System.Classes,
  System.Generics.Collections;
  
type
  ///	<summary>
  ///	  Base class for all EF stream decorators and filters. It just forwards
  ///	  read and write requestes to an internal stream object, a reference to
  ///	  which is passed to the constructor.
  ///	</summary>
  TEFStreamDecorator = class(TStream)
  private
    FStream: TStream;
    FOwnsStream: Boolean;
    FOnEndOfStream: TNotifyEvent;
  protected
    property Stream: TStream read FStream;

    ///	<summary>
    ///	  Fires OnEndOfStream. Descendants that override Read without calling
    ///	  inherited are required to call this method to signal that the stream
    ///	  is over.
    ///	</summary>
    procedure DoEndOfStream;
  public
    ///	<summary>
    ///	  Creates an object that decorates AStream. If AOwnsStream is True,
    ///	  then the decorator acquires ownership of the stream and will destroy
    ///	  it when it is itself destroyed.
    ///	</summary>
    constructor Create(const AStream: TStream; const AOwnsStream: Boolean = True);
    /// <summary>Frees the decorated stream if the decorator owns it.</summary>
    destructor Destroy; override;
    /// <summary>Reads from the decorated stream, firing OnEndOfStream when fewer bytes than requested are read.</summary>
    function Read(var Buffer; Count: Longint): Longint; override;
    /// <summary>Writes to the decorated stream.</summary>
    function Write(const Buffer; Count: Longint): Longint; override;
    /// <summary>Seeks on the decorated stream (32-bit overload).</summary>
    function Seek(Offset: Longint; Origin: Word): Longint; overload; override;
    /// <summary>Seeks on the decorated stream (64-bit overload).</summary>
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; overload; override;

    ///	<summary>
    ///	  Fired when the end of the stream is reached while reading. IOW, when
    ///	  Read's return value is less than its Count argument. Handle this
    ///	  event if you do not have control over reads but still want to be
    ///	  notified when the stream is over.
    ///	</summary>
    property OnEndOfStream: TNotifyEvent read FOnEndOfStream write FOnEndOfStream;
  end;

  ///	<summary>
  ///	  A stream filter that only allows sequential reading.
  ///	</summary>
  TEFReadFilter = class(TEFStreamDecorator)
  private
    FGettingSize: Boolean;
  public
    /// <summary>Reads sequentially from the decorated stream.</summary>
    function Read(var Buffer; Count: Longint): Longint; override;
    /// <summary>Only supports the special Seek calls used to query the stream's size; any other seek raises an exception.</summary>
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    /// <summary>Not supported on a read-only filter; always raises an exception.</summary>
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

  ///	<summary>
  ///	  Adds buffering to the read stream filter. Use this class for efficient
  ///	  reading from a file or other medium.
  ///	</summary>
  TEFBufferedReadFilter = class(TEFReadFilter)
  private
    // PByte, not PChar: FBufferLength and FBufferPosition below are counts of
    // bytes, and indexing a PChar steps two bytes at a time on a Unicode
    // compiler. See the comment in Read.
    FBuffer: PByte;
    FBufferLength: Longint;
    FBufferPosition: Longint;
  protected
    ///	<summary>
    ///	  Reads new data from the internal stream into the buffer and resets
    ///	  the buffer's current position. Returns True when it has read at least
    ///	  one byte, False otherwise.
    ///	</summary>
    function ReadNextBuffer: Boolean;
  public
    /// <summary>Allocates the internal read buffer.</summary>
    procedure AfterConstruction; override;
    /// <summary>Frees the internal read buffer.</summary>
    destructor Destroy; override;
    /// <summary>Reads the requested number of bytes, refilling the internal buffer from the decorated stream as needed.</summary>
    function Read(var Buffer; Count: Longint): Longint; override;
    /// <summary>Returns the current logical position (accounting for buffered data); other seeks are delegated to the inherited filter.</summary>
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

  ///	<summary>
  ///	  A stream decorator that is able to read and write text lines to the
  ///	  decorated stream. Use it with a buffered read filter to efficiently
  ///	  read text lines from a file.
  ///	</summary>
  ///	<remarks>
  ///	  The stream is <b>UTF-8</b>, in both directions: WriteLn encodes to UTF-8
  ///	  and ReadLn decodes from it. It has to be one encoding for both, or a file
  ///	  this class writes is not a file it can read back — which is what used to
  ///	  happen, ReadLn reading two bytes per character as if it were UTF-16.
  ///	  No byte-order mark is written; one found at the start of the stream is
  ///	  skipped on reading.
  ///	</remarks>
  TEFTextStream = class(TEFStreamDecorator)
  private
    FLineBreak: string;
  public
    /// <summary>Initializes LineBreak to the platform default (sLineBreak).</summary>
    procedure AfterConstruction; override;
  public
    const
      ///	<summary>
      ///	  ReadLn returns this value when there's no more text.
      ///	</summary>
      EOT: string = #4;

    ///	<summary>
    ///	  <para>
    ///	    Line breaking sequence used to terminate lines written by WriteLn.
    ///	    Defaults to sLineBreak.
    ///	  </para>
    ///	  <para>
    ///	    Note: Currently it is NOT used by ReadLn.
    ///	  </para>
    ///	</summary>
    property LineBreak: string read FLineBreak write FLineBreak;

    ///	<summary>
    ///	  <para>
    ///	    Reads text from the current position up to (but not including) the
    ///	    next LF character, skipping any CR characters found. This supports
    ///	    both LF (Linux) and CR+LF (Windows) line breaking styles. It
    ///	    doesn't currently support the CR-only line breaking style. Returns
    ///	    EOT when there's no more text.
    ///	  </para>
    ///	  <para>
    ///	    The bytes are read one at a time and decoded as <b>UTF-8</b> once the
    ///	    line is complete, which is the encoding WriteLn produces. A
    ///	    byte-order mark at the start of the stream is not part of the first
    ///	    line and is skipped.
    ///	  </para>
    ///	  <para>
    ///	    Note: the value of the LineBreak property is ignored.
    ///	  </para>
    ///	</summary>
    function ReadLn: string;

    ///	<summary>
    ///	  Writes AString plus LineBreak to the stream.
    ///	</summary>
    procedure WriteLn(const AString: string);
  end;

type
  ///	<summary>A stream decorator that is capable of outputting XML data such
  ///	as tags and attributes, keeping track of the indent.</summary>
  ///	<remarks>It only supports UTF-8 encoding.</remarks>
  TEFXMLOutputStream = class(TEFTextStream)
  private
    ///	<summary>The indentation level used by WriteLnIndented is calculated
    ///	based on the number of open tags. When this stream is used to write a
    ///	piece of XML code (as opposed to the complete document), it might be
    ///	useful to set an additional indent level; that's what this class does
    ///	when it decorates a stream of the same type.</summary>
    FAdditionalIndentLevel: Integer;
    FOpenTags: TStack<string>;
    function GetIndentLevel: Integer;
    function GetOpenTags: TStack<string>;

    ///	<summary>Encodes the attribute names and values as a string suitable
    ///	for inclusion in a XML tag. If the arrays are empty, returns '',
    ///	otherwise the return string includes a leading ' '.</summary>
    function EncodeAttributes(const AAttributeNames,
      AAttributeValues: array of string): string;
    property OpenTags: TStack<string> read GetOpenTags;
    procedure WriteLnIndented(const AString: string);

    ///	<summary>Encodes AString. Call this method before writing anything (tag
    ///	names, attribute names and values, characters). WriteLnIndented
    ///	automatically calls ithis method. Currently only supports UTF-8
    ///	encoding.</summary>
    function EncodeString(const AString: string): string;
  public
    /// <summary>Inherits any indentation offset when this stream decorates another XML output stream.</summary>
    procedure AfterConstruction; override;
    /// <summary>Closes any still-open tags and frees the open-tags stack.</summary>
    destructor Destroy; override;

    ///	<summary>Writes the XML prolog. Call this before writing anything else
    ///	if you are producing a well-formed XML document.</summary>
    procedure WriteProlog;

    ///	<summary>Opens a tag, optionally with attributes. AAttributeNames must
    ///	have the same length as AAttributeValues.</summary>
    procedure OpenTag(const ATagName: string); overload;
    procedure OpenTag(const ATagName: string;
      const AAttributeNames: array of string;
      const AAttributeValues: array of string); overload;

    ///	<summary>Opens a tag, writes ATagCharacters and closes it all in a
    ///	single call. If ATagCharacter is empty, it uses the "&lt;ATagName
    ///	/&gt;" syntax. Optionally writes also the attributes in the opening tag
    ///	(in which case the tag cannot be empty).</summary>
    procedure WriteTag(const ATagName: string; const ATagCharacters: string = ''); overload;
    procedure WriteTag(const ATagName: string;
      const AAttributeNames: array of string;
      const AAttributeValues: array of string;
      const ATagCharacters: string = ''); overload;

    ///	<summary>Like WriteTag, but embeds ATagCharacters in a CDATA
    ///	section.</summary>
    procedure WriteCDATATag(const ATagName, ATagCharacters: string);

    ///	<summary>Closes the last opened tag, if any, and returns its name. If
    ///	no tag to close was found, it returns ''.</summary>
    function CloseTag: string;

    ///	<summary>Iteratively calls CloseTag until the stack of open tags is
    ///	empty. It is called automatically upon destruction.</summary>
    procedure CloseAllOpenTags;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Math;

const
  {
    Default buffer size for buffered stream filters.
  }
  BUFFER_SIZE = 16384;

{ TEFStreamDecorator }

constructor TEFStreamDecorator.Create(const AStream: TStream;
  const AOwnsStream: Boolean = True);
begin
  Assert(Assigned(AStream), 'Assigned(AStream)');

  inherited Create;
  FStream := AStream;
  FOwnsStream := AOwnsStream;
end;

destructor TEFStreamDecorator.Destroy;
begin
  if FOwnsStream then
    FreeAndNil(FStream);
  inherited;
end;

procedure TEFStreamDecorator.DoEndOfStream;
begin
  if Assigned(FOnEndOfStream) then
    FOnEndOfStream(Self);
end;

function TEFStreamDecorator.Read(var Buffer; Count: Longint): Longint;
begin
  Result := FStream.Read(Buffer, Count);
  if Result < Count then
    DoEndOfStream;
end;

function TEFStreamDecorator.Seek(Offset: Longint; Origin: Word): Longint;
begin
  Result := FStream.Seek(Offset, Origin);
end;

function TEFStreamDecorator.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
begin
  Result := FStream.Seek(Offset, Origin);
end;

function TEFStreamDecorator.Write(const Buffer; Count: Longint): Longint;
begin
  Result := FStream.Write(Buffer, Count);
end;

{ TEFReadFilter }

function TEFReadFilter.Read(var Buffer; Count: Longint): Longint;
begin
  Assert(not FGettingSize, 'not FGettingSize');

  Result := inherited Read(Buffer, Count);
end;

function TEFReadFilter.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  // Intercept and handle the special Seek calls, that is those made while
  // getting the stream's size.
  case Origin of
    soBeginning:
      if FGettingSize then
      begin
        Result := FStream.Position;
        if Offset = Result then
          Exit;
        FGettingSize := False;
      end;
    soCurrent:
      if (Offset = 0) and not FGettingSize then
      begin
        Result := FStream.Position;
        Exit;
      end;
    soEnd:
      if (Offset = 0) and not FGettingSize then
      begin
        Result := FStream.Size;
        FGettingSize := True;
        Exit;
      end;
  end;
  raise Exception.Create('Seek not available in a read stream filter.');
end;

function TEFReadFilter.Write(const Buffer; Count: Longint): Longint;
begin
  raise Exception.Create('Write not available in a read stream filter.');
end;

{ TEFBufferedReadFilter }

procedure TEFBufferedReadFilter.AfterConstruction;
begin
  inherited;
  GetMem(FBuffer, BUFFER_SIZE);
end;

destructor TEFBufferedReadFilter.Destroy;
begin
  FreeMem(FBuffer, BUFFER_SIZE);
  inherited;
end;

function TEFBufferedReadFilter.ReadNextBuffer: Boolean;
begin
  FBufferLength := FStream.Read(FBuffer^, BUFFER_SIZE);
  FBufferPosition := 0;
  Result := FBufferLength <> 0;
end;

// Every counter in here -- FBufferLength, FBufferPosition, LBytesToCopy and
// Count -- is a number of BYTES, so the two pointers walking over them are
// PByte. They used to be PChar, which on a Unicode compiler is a pointer to a
// two-byte element, and pointer arithmetic on it steps by elements:
//
//   FBuffer[FBufferPosition] sat at byte offset 2 * FBufferPosition, so every
//   read after the first one in a buffer took its bytes from twice as far in.
//   A caller consuming two bytes at a time -- TEFTextStream.ReadLn reads one
//   Char -- got every other byte, and once the position passed half the buffer
//   it was reading off the end of the allocation, up to 16 KB into whatever
//   followed it on the heap;
//
//   Inc(LPCharBuffer, LBytesToCopy) advanced the CALLER's buffer by twice the
//   bytes just written. A Read larger than the internal buffer wrote its
//   remainder past the end of the buffer the caller supplied.
//
// The code was written for a single-byte Char and never adjusted. It kept
// working for a read that fits in one bufferful from position zero, which is
// the only shape anything in the tree ever asked of it.
function TEFBufferedReadFilter.Read(var Buffer; Count: Longint): Longint;
var
  LDestination: PByte;
  LBytesToRead: Longint;
  LBytesToCopy: Longint;

  {
    Calculates and returns the number of bytes to copy from the internal
    buffer, depending on the requested number of bytes.
  }
  function HowManyBytesToCopy(const ARequestedBytes: Longint): Longint;
  begin
    Result := Min(FBufferLength - FBufferPosition, ARequestedBytes);
  end;

begin
  LDestination := @Buffer;
  Result := 0;
  // Fill the internal buffer if required.
  if FBufferPosition = FBufferLength then
    if not ReadNextBuffer then
    begin
      // Fewer bytes than asked for -- none at all, in fact -- and the class
      // promises OnEndOfStream in that case. This path used to leave silently.
      if Count > 0 then
        DoEndOfStream;
      Exit;
    end;
  LBytesToRead := Count;
  // How many bytes should we copy from the internal buffer?
  LBytesToCopy := HowManyBytesToCopy(LBytesToRead);
  // Copy 'em.
  Move(FBuffer[FBufferPosition], LDestination^, LBytesToCopy);
  Inc(Result, LBytesToCopy);
  // Once the bytes are copied, adjust the counters.
  Inc(FBufferPosition, LBytesToCopy);
  Dec(LBytesToRead, LBytesToCopy);
  // Still bytes to read? Read and copy 'em.
  while LBytesToRead <> 0 do
  begin
    // Go right after the data we just copied.
    Inc(LDestination, LBytesToCopy);
    // The internal buffer was copied entirely, so read another one.
    if not ReadNextBuffer then
    begin
      if Result < Count then
        DoEndOfStream;
      Exit;
    end;
    // How many bytes should we copy from the internal buffer?
    LBytesToCopy := HowManyBytesToCopy(LBytesToRead);
    // Copy 'em. ReadNextBuffer has just reset the position to zero, so the
    // source is the start of the buffer.
    Move(FBuffer^, LDestination^, LBytesToCopy);
    Inc(Result, LBytesToCopy);
    // Once the bytes are copied, adjust the counters.
    Inc(FBufferPosition, LBytesToCopy);
    Dec(LBytesToRead, LBytesToCopy);
  end;
  if Result < Count then
    DoEndOfStream;
end;

function TEFBufferedReadFilter.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
begin
  if (Offset = 0) and (Origin = soCurrent) then
    Result := FStream.Position - FBufferLength + FBufferPosition
  else
    Result := inherited Seek(Offset, Origin);
end;

{ TEFTextStream }

procedure TEFTextStream.AfterConstruction;
begin
  inherited;
  FLineBreak := sLineBreak;
end;

function TEFTextStream.ReadLn: string;
const
  CR = 13;
  LF = 10;
  BOM = #$FEFF;
  INITIAL_CAPACITY = 256;
var
  LByte: Byte;
  LBytes: TBytes;
  LCount: Integer;
  LBytesRead: Longint;
  LAtStart: Boolean;
begin
  // A BYTE at a time, and the decoding at the end, because the stream is UTF-8:
  // this used to read SizeOf(Char) — two bytes — and compare the pair against
  // LF, which is UTF-16. On text that WriteLn had produced it therefore
  // returned garbage, and found a line break only where two bytes happened to
  // be exactly $000A: for plain ASCII, never. Reader and writer could not
  // agree on the same file, whatever it contained.
  //
  // Byte-wise reading costs nothing here, and this class is documented to be
  // used behind a TEFBufferedReadFilter, which serves those reads from its own
  // buffer.
  LAtStart := Seek(Int64(0), soCurrent) = 0;
  SetLength(LBytes, INITIAL_CAPACITY);
  LCount := 0;
  LBytesRead := Read(LByte, SizeOf(LByte));
  if LBytesRead = 0 then
    Exit(EOT);
  while (LBytesRead <> 0) and (LByte <> LF) do
  begin
    // CR skipped, so both LF and CR+LF work, as before. A CR-only stream still
    // reads as a single line: that limitation is unchanged and documented.
    if LByte <> CR then
    begin
      if LCount = Length(LBytes) then
        SetLength(LBytes, Length(LBytes) * 2);
      LBytes[LCount] := LByte;
      Inc(LCount);
    end;
    LBytesRead := Read(LByte, SizeOf(LByte));
  end;
  SetLength(LBytes, LCount);
  Result := TEncoding.UTF8.GetString(LBytes);
  // A byte-order mark belongs to the file, not to its first line. WriteLn never
  // emits one, but a file written by something else may carry it, and decoded
  // it would arrive as a leading U+FEFF inside the text. Dropped here rather
  // than by peeking ahead, which a read filter cannot undo.
  if LAtStart and Result.StartsWith(BOM) then
    Result := Result.Substring(1);
end;

procedure TEFTextStream.WriteLn(const AString: string);
var
  LBuffer: UTF8String;
begin
  LBuffer := UTF8String(AString + FLineBreak);
  Write(LBuffer[1], Length(LBuffer));
end;

{ TEFXMLOutputStream }

procedure TEFXMLOutputStream.AfterConstruction;
begin
  inherited;
  if Stream is TEFXMLOutputStream then
    FAdditionalIndentLevel := TEFXMLOutputStream(Stream).GetIndentLevel;
end;

procedure TEFXMLOutputStream.CloseAllOpenTags;
begin
  while CloseTag <> '' do
    ;
end;

function TEFXMLOutputStream.CloseTag: string;
begin
  if OpenTags.Count = 0 then
    Result := ''
  else
  begin
    Result := OpenTags.Pop;
    WriteLnIndented('</' + Result + '>');
  end;
end;

destructor TEFXMLOutputStream.Destroy;
begin
  CloseAllOpenTags;
  FreeAndNil(FOpenTags);
  inherited;
end;

function TEFXMLOutputStream.GetIndentLevel: Integer;
begin
  Result := OpenTags.Count * 2;
end;

function TEFXMLOutputStream.GetOpenTags: TStack<string>;
begin
  if not Assigned(FOpenTags) then
    FOpenTags := TStack<string>.Create;
  Result := FOpenTags;
end;

function TEFXMLOutputStream.EncodeAttributes(const AAttributeNames: array of string;
  const AAttributeValues: array of string): string;
var
  LAttributeIndex: Integer;
begin
  Assert(Length(AAttributeNames) = Length(AAttributeValues), 'Length(AAttributeNames) = Length(AAttributeValues)');
  if Length(AAttributeNames) = 0 then
    Result := ''
  else
  begin
    Result := ' ';
    for LAttributeIndex := Low(AAttributeNames) to High(AAttributeNames) do
      Result := Result + AAttributeNames[LAttributeIndex] + '="' +
        AAttributeValues[LAttributeIndex] + '" ';
    // Remove the trailing space.
    Delete(Result, Length(Result), 1);
  end;
end;

function TEFXMLOutputStream.EncodeString(const AString: string): string;
begin
  // See TEFTextStream.WriteLn.
  {$IFDEF UNICODE}
  Result := AString;
  {$ELSE}
  Result := AnsiToUtf8(AString);
  {$ENDIF}
end;

procedure TEFXMLOutputStream.OpenTag(const ATagName: string;
  const AAttributeNames: array of string;
  const AAttributeValues: array of string);
begin
  WriteLnIndented('<' + ATagName
    + EncodeAttributes(AAttributeNames, AAttributeValues) + '>');
  OpenTags.Push(ATagName);
end;

procedure TEFXMLOutputStream.OpenTag(const ATagName: string);
begin
  OpenTag(ATagName, [], []);
end;

procedure TEFXMLOutputStream.WriteTag(const ATagName: string;
  const AAttributeNames, AAttributeValues: array of string;
  const ATagCharacters: string);
begin
  if ATagCharacters <> '' then
    WriteLnIndented('<' + ATagName
      + EncodeAttributes(AAttributeNames, AAttributeValues) + '>'
      + ATagCharacters + '</' + ATagName + '>')
  else
    WriteLnIndented('<' + ATagName
      + EncodeAttributes(AAttributeNames, AAttributeValues) + ' />');
end;

procedure TEFXMLOutputStream.WriteTag(const ATagName: string;
  const ATagCharacters: string = '');
begin
  WriteTag(ATagName, [], [], ATagCharacters);
end;

procedure TEFXMLOutputStream.WriteCDATATag(const ATagName: string;
  const ATagCharacters: string);
begin
  WriteTag(ATagName, [], [], '<![CDATA[' + ATagCharacters + ']]>');
end;

procedure TEFXMLOutputStream.WriteLnIndented(const AString: string);
var
  LIndentStr: string;
begin
  LIndentStr := DupeString(' ', GetIndentLevel + FAdditionalIndentLevel);
  WriteLn(LIndentStr + EncodeString(AString));
end;

procedure TEFXMLOutputStream.WriteProlog;
begin
  WriteLn('<?xml version="1.0" encoding="UTF-8" ?>');
end;

end.
