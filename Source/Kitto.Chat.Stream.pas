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
///  The sink a streaming AI provider hands to the HTTP client: a write-only
///  stream that cuts the bytes of a server-sent-events body into lines and
///  gives each line to <see cref="TKXChatSSEStream.ProcessLine" />, which is
///  all a provider has to write - the rest of the machinery is the same
///  whatever the service.
///  <para>This is the point where streaming crosses three layers without
///  anybody opening a channel towards the browser: the tokens are appended to
///  the conversation store as they arrive, and the client sees them growing
///  because it is polling.</para>
/// </summary>
unit Kitto.Chat.Stream;

{$I Kitto.Defines.inc}

interface

uses
  System.Classes
  , System.SysUtils
  , Kitto.Chat.Provider
  ;

type
  /// <summary>
  ///  Base of the streaming sinks. A provider derives from it and overrides
  ///  <see cref="ProcessLine" /> with the shape of its own events, calling
  ///  <see cref="Emit" /> for each piece of text and <see cref="Fail" /> for an
  ///  error the service reports mid-stream.
  /// </summary>
  TKXChatSSEStream = class abstract (TStream)
  strict private
    FOnToken: TKXChatTokenProc;
    FCancel: IKXChatCancelToken;
    FPending: TBytes;       // bytes not yet forming a complete line
    FText: TStringBuilder;  // accumulated assistant text (the returned reply)
    FRaw: TStringBuilder;   // full decoded body (for error extraction)
    FError: string;         // set by Fail
    FWritten: Int64;
    procedure Drain(const AFlushRemainder: Boolean);
    function GetText: string;
    function GetRaw: string;
  protected
    /// <summary>One line of the body, already decoded and without its line
    /// break. Everything a provider has to know about its own stream.</summary>
    procedure ProcessLine(const ALine: string); virtual; abstract;
    /// <summary>A piece of the reply: it is accumulated and handed at once to
    /// whoever is listening, which is what makes it appear in the panel while
    /// it is still being written.</summary>
    procedure Emit(const AToken: string);
    /// <summary>The service said something went wrong while the reply was
    /// being produced. The first one wins, and it is raised at the end.</summary>
    procedure Fail(const AMessage: string);
  public
    constructor Create(const AOnToken: TKXChatTokenProc;
      const ACancel: IKXChatCancelToken);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    /// <summary>Flushes any trailing partial line (the body may not end in a
    /// newline).</summary>
    procedure Finish;
    /// <summary>The reply as it stands.</summary>
    property Text: string read GetText;
    /// <summary>The whole decoded body, for extracting an error out of a
    /// response that was not a stream at all.</summary>
    property Raw: string read GetRaw;
    /// <summary>What the service reported mid-stream, or empty.</summary>
    property Error: string read FError;
  end;

implementation

{ TKXChatSSEStream }

constructor TKXChatSSEStream.Create(const AOnToken: TKXChatTokenProc;
  const ACancel: IKXChatCancelToken);
begin
  inherited Create;
  FOnToken := AOnToken;
  FCancel := ACancel;
  FText := TStringBuilder.Create;
  FRaw := TStringBuilder.Create;
end;

destructor TKXChatSSEStream.Destroy;
begin
  FText.Free;
  FRaw.Free;
  inherited;
end;

procedure TKXChatSSEStream.Emit(const AToken: string);
begin
  if AToken = '' then
    Exit;
  FText.Append(AToken);
  if Assigned(FOnToken) then
    FOnToken(AToken);
end;

procedure TKXChatSSEStream.Fail(const AMessage: string);
begin
  if FError = '' then
    FError := AMessage;
end;

function TKXChatSSEStream.GetText: string;
begin
  Result := FText.ToString;
end;

function TKXChatSSEStream.GetRaw: string;
begin
  Result := FRaw.ToString;
end;

function TKXChatSSEStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := 0; // write-only sink
end;

function TKXChatSSEStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  // THTTPClient treats the response stream as an append sink; report the end.
  Result := FWritten;
end;

function TKXChatSSEStream.Write(const Buffer; Count: Longint): Longint;
var
  LOld: Integer;
begin
  // The one place where the provider has control while the answer is arriving:
  // raising here aborts the HTTP read at once. What was already streamed is in
  // the store, and the runner keeps it.
  if Assigned(FCancel) and FCancel.IsCancelled then
    raise EKXChatCancelled.Create('cancelled');
  if Count > 0 then
  begin
    LOld := Length(FPending);
    SetLength(FPending, LOld + Count);
    Move(Buffer, FPending[LOld], Count);
    Inc(FWritten, Count);
    Drain(False);
  end;
  Result := Count;
end;

procedure TKXChatSSEStream.Finish;
begin
  Drain(True);
end;

procedure TKXChatSSEStream.Drain(const AFlushRemainder: Boolean);
var
  I, LStart, LLen: Integer;
  LLineBytes: TBytes;
  LRemainder: TBytes;

  procedure EmitLine(const ABytes: TBytes);
  var
    LDecoded: string;
    LTrimmed: TBytes;
    LN: Integer;
  begin
    LN := Length(ABytes);
    // A complete line ends before the #10; strip a trailing #13 (CRLF).
    if (LN > 0) and (ABytes[LN - 1] = 13) then
    begin
      LTrimmed := System.Copy(ABytes, 0, LN - 1);
      LDecoded := TEncoding.UTF8.GetString(LTrimmed);
    end
    else
      LDecoded := TEncoding.UTF8.GetString(ABytes);
    FRaw.Append(LDecoded).Append(#10);
    ProcessLine(LDecoded);
  end;

begin
  LStart := 0;
  I := 0;
  while I < Length(FPending) do
  begin
    if FPending[I] = 10 then // #10 line feed
    begin
      LLineBytes := System.Copy(FPending, LStart, I - LStart);
      EmitLine(LLineBytes);
      LStart := I + 1;
    end;
    Inc(I);
  end;

  LLen := Length(FPending) - LStart;
  if LLen > 0 then
    LRemainder := System.Copy(FPending, LStart, LLen)
  else
    LRemainder := nil;

  if AFlushRemainder and (Length(LRemainder) > 0) then
  begin
    EmitLine(LRemainder);
    LRemainder := nil;
  end;

  FPending := LRemainder;
end;

end.
