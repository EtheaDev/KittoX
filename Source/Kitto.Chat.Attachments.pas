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
///  What the user attaches to a question. An attachment is a value record -
///  name, media type, the bytes - kept per user in
///  <see cref="TKXChatAttachments" />, beside the conversation and not inside
///  it; a provider that can read documents turns it into whatever block its
///  API wants.
///  <para>Three kinds, because that is what the models accept: a
///  <c>document</c> (PDF) and an <c>image</c> travel as bytes, everything
///  textual (.txt, .md, .csv, .json, ...) is decoded here and travels inside
///  the question. No model reads a .docx or a .xlsx, so those are refused by
///  name, with a sentence that says so: sent and silently ignored, they would
///  look like they worked.</para>
///  <para>Pure RTL: no web, no VCL. Thread-safe, because request threads add
///  and remove attachments while a worker reads the copy it took.</para>
///  <para>They are deliberately <b>not</b> in <see cref="TKXChatStore" />: the
///  bytes of a PDF have no business in a conversation that is pruned by
///  message count and that one day will be persisted. Clearing the
///  conversation clears them too - that is the one place the two are tied.</para>
/// </summary>
unit Kitto.Chat.Attachments;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils
  , System.Classes
  , System.Generics.Collections
  , System.SyncObjs
  ;

const
  /// <summary>Attachments one conversation may hold at a time.</summary>
  KX_CHAT_DEF_ATTACH_MAXCOUNT = 5;
  /// <summary>Largest single attachment, in KB.</summary>
  KX_CHAT_DEF_ATTACH_MAXSIZEKB = 8192;
  /// <summary>Largest total per conversation, in KB. What goes up is a third
  /// larger than this: base64.</summary>
  KX_CHAT_DEF_ATTACH_MAXTOTALKB = 20480;
  /// <summary>Largest picture, in KB, whatever the limit on an attachment is.
  /// The services refuse a larger one - Anthropic at 5 MB, counted on the
  /// base64 text, which is a third larger than the file - and a refused
  /// picture would not fail one question but <b>all</b> of them: the
  /// attachments of a conversation go up again with every later question.</summary>
  KX_CHAT_DEF_ATTACH_IMAGEMAXKB = 3600;
  /// <summary>Attachments are off until the application turns them on. What
  /// the user attaches leaves the server and reaches the provider, and that
  /// is the application's decision to make, not the framework's.</summary>
  KX_CHAT_DEF_ATTACH_ENABLED = False;

  /// <summary>Media type of a PDF, the one document every model reads.</summary>
  KX_CHAT_MEDIA_PDF = 'application/pdf';
  /// <summary>Media type of the text files that have no better one of their
  /// own (.txt, .log, .ini). It is informative: a text attachment travels
  /// inside the question, where no provider declares a type.</summary>
  KX_CHAT_MEDIA_TEXT = 'text/plain';

type
  /// <summary>
  ///  How an attachment reaches the model. <c>cakDocument</c> is a PDF and
  ///  <c>cakImage</c> a picture: both travel as base64 bytes in the block the
  ///  provider builds. <c>cakText</c> was decoded when it arrived and travels
  ///  as text inside the question.
  /// </summary>
  TKXChatAttachmentKind = (cakDocument, cakImage, cakText);

  /// <summary>
  ///  One attached file. A value record, copied into a request and handed to a
  ///  worker with no ownership concern, exactly like <c>TKXChatMessage</c>.
  /// </summary>
  TKXChatAttachment = record
    /// <summary>URL-safe id (hyphenated GUID, no braces).</summary>
    Id: string;
    /// <summary>Name as the user sees it: no path, no directory separator.</summary>
    FileName: string;
    /// <summary>IANA media type, as the provider must declare it.</summary>
    MediaType: string;
    /// <summary>How it travels, decided by the media type when it was accepted.</summary>
    Kind: TKXChatAttachmentKind;
    /// <summary>The bytes, for a document or an image; empty for text. Copying
    /// the record shares this array, it does not duplicate it: nobody writes
    /// into it after <see cref="TKXChatAttachments.TryAdd" />, which is what
    /// makes the copy handed to a worker safe.</summary>
    Data: TBytes;
    /// <summary>The decoded content, for a text attachment; empty otherwise.</summary>
    Text: string;
    /// <summary>When it was accepted (server local time).</summary>
    Created: TDateTime;
    /// <summary>Bytes of the file as it arrived, before any decoding.</summary>
    OriginalSize: Int64;

    /// <summary>A fresh URL-safe attachment id.</summary>
    class function NewId: string; static;
    /// <summary>True when nothing was ever put in it.</summary>
    function IsEmpty: Boolean;
    /// <summary>The bytes as the JSON of every provider wants them: base64 on
    /// one line, no breaks. Empty for a text attachment. Computed at every
    /// call - a provider asks once per request.</summary>
    function Base64: string;
    /// <summary>Extension without the dot, lowercase ('pdf'); empty when
    /// there is none.</summary>
    function Extension: string;
  end;

  /// <summary>
  ///  What an attachment may not exceed. A plain record, so this unit does not
  ///  depend on the configuration: the caller fills it from
  ///  <c>HelpChat/Attachments</c>.
  /// </summary>
  TKXChatAttachmentLimits = record
    /// <summary>Attachments a conversation may hold at a time (0 = no limit).</summary>
    MaxCount: Integer;
    /// <summary>Largest single file, in bytes as it arrives (0 = no limit).</summary>
    MaxSizeBytes: Int64;
    /// <summary>Largest total per conversation, in bytes as the files arrived
    /// (0 = no limit).</summary>
    MaxTotalBytes: Int64;
    /// <summary>Largest picture, in bytes (0 = no limit): see
    /// <c>KX_CHAT_DEF_ATTACH_IMAGEMAXKB</c> for why a picture has one of its
    /// own.</summary>
    MaxImageBytes: Int64;
    /// <summary>The limits of the <c>KX_CHAT_DEF_ATTACH_*</c> constants.</summary>
    class function Default: TKXChatAttachmentLimits; static;
  end;

  /// <summary>
  ///  The attachments of every conversation, keyed by user as the conversation
  ///  store is. A request takes a copy of the array, so a worker never reads
  ///  the live list. Process-global singleton, thread-safe.
  /// </summary>
  TKXChatAttachments = class
  strict private
    FLock: TCriticalSection;
    FItems: TObjectDictionary<string, TList<TKXChatAttachment>>;
    /// <summary>The list of AUser; nil, or a new one, when there is none.
    /// Call under the lock.</summary>
    function ListOf(const AUser: string; const ACreate: Boolean): TList<TKXChatAttachment>;
    function IndexOfIdLocked(const AList: TList<TKXChatAttachment>; const AId: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>
    ///  Accepts a file for AUser. False, with a localized sentence in AError
    ///  that the panel shows as it is, when the type is not one a model reads
    ///  or a limit is reached.
    ///  <para>Only the name of AFileName is kept, any path is dropped, and the
    ///  type is decided by the <b>extension alone</b> - the bytes are not
    ///  inspected. The count and the total are checked and the file added
    ///  under one lock, so two uploads arriving together cannot both take the
    ///  last place. Never raises; safe from any thread.</para>
    /// </summary>
    function TryAdd(const AUser, AFileName: string; const AData: TBytes;
      const ALimits: TKXChatAttachmentLimits; out AAttachment: TKXChatAttachment;
      out AError: string): Boolean;
    /// <summary>Copy of the attachments of AUser, oldest first: what a request
    /// takes with it. Empty for a conversation that has none.</summary>
    function ItemsOf(const AUser: string): TArray<TKXChatAttachment>;
    /// <summary>The one with this id, if the user has it.</summary>
    function TryGet(const AUser, AId: string; out AAttachment: TKXChatAttachment): Boolean;
    /// <summary>Drops one attachment; True when it was there. A reply already
    /// being produced keeps the copy it took.</summary>
    function Remove(const AUser, AId: string): Boolean;
    /// <summary>Drops every attachment of a user: what clearing the
    /// conversation does.</summary>
    procedure ClearUser(const AUser: string);
    /// <summary>Drops everything, of every user.</summary>
    procedure ClearAll;
    /// <summary>Attachments the user holds now.</summary>
    function Count(const AUser: string): Integer;
    /// <summary>Bytes held by the user, as they arrived.</summary>
    function TotalSize(const AUser: string): Int64;

    /// <summary>The process-global set.</summary>
    class function Instance: TKXChatAttachments; static;
  end;

/// <summary>The media type of a file name, by extension; empty when it is not
/// one of the types a model can be given.</summary>
function KXChatMediaTypeOf(const AFileName: string): string;

/// <summary>How a media type travels. Meaningless for a type that is not one
/// of the accepted ones - ask <see cref="KXChatIsAcceptedFile" /> first:
/// anything that is neither a PDF nor an image answers 'text'.</summary>
function KXChatKindOf(const AMediaType: string): TKXChatAttachmentKind;

/// <summary>True when a model can be given a file of this name.</summary>
function KXChatIsAcceptedFile(const AFileName: string): Boolean;

/// <summary>The extensions the file dialog of the panel offers
/// ('.pdf,.png,...'), which is also what this unit accepts.</summary>
function KXChatAcceptedExtensions: string;

/// <summary>Text of a file that arrived as bytes: honours a UTF-8, UTF-16 LE
/// or BE BOM, else reads UTF-8 and falls back to the ANSI code page when the
/// bytes are not valid UTF-8 - a .txt written by Notepad in 2003 is still a
/// .txt.</summary>
function KXChatDecodeText(const AData: TBytes): string;

/// <summary>A size as the panel shows it next to the file name ('1.4 MB'): B,
/// KB without decimals, MB with one.</summary>
function KXChatFormatSize(const ABytes: Int64): string;

/// <summary>True when at least one attachment travels as bytes - a PDF or a
/// picture: what a provider that cannot read documents has to report.</summary>
function KXChatHasBinaryAttachment(const AAttachments: TArray<TKXChatAttachment>): Boolean;

/// <summary>The question as the model receives it: the text attachments, each
/// between two fences carrying its name, and then what the user typed. The
/// question unchanged when no attachment is textual.
/// <para>It lives here and not in a provider because every API says this the
/// same way: what differs between them is only how the <i>bytes</i> of a PDF
/// travel.</para></summary>
function KXChatQuestionWithText(const AQuestion: string;
  const AAttachments: TArray<TKXChatAttachment>): string;

implementation

uses
  System.NetEncoding
  , System.Math
  , System.StrUtils
  , EF.Localization
  ;

type
  TKXAcceptedType = record
    Ext: string;
    MediaType: string;
    Kind: TKXChatAttachmentKind;
  end;

const
  /// <summary>Everything a model actually reads. A PDF and the four image
  /// formats go up as bytes; the rest is text, and whatever is not here is
  /// refused by name.</summary>
  KX_ACCEPTED: array[0..14] of TKXAcceptedType = (
    (Ext: 'pdf';  MediaType: KX_CHAT_MEDIA_PDF;  Kind: cakDocument),
    (Ext: 'png';  MediaType: 'image/png';        Kind: cakImage),
    (Ext: 'jpg';  MediaType: 'image/jpeg';       Kind: cakImage),
    (Ext: 'jpeg'; MediaType: 'image/jpeg';       Kind: cakImage),
    (Ext: 'gif';  MediaType: 'image/gif';        Kind: cakImage),
    (Ext: 'webp'; MediaType: 'image/webp';       Kind: cakImage),
    (Ext: 'txt';  MediaType: KX_CHAT_MEDIA_TEXT; Kind: cakText),
    (Ext: 'md';   MediaType: 'text/markdown';    Kind: cakText),
    (Ext: 'csv';  MediaType: 'text/csv';         Kind: cakText),
    (Ext: 'json'; MediaType: 'application/json'; Kind: cakText),
    (Ext: 'xml';  MediaType: 'text/xml';         Kind: cakText),
    (Ext: 'log';  MediaType: KX_CHAT_MEDIA_TEXT; Kind: cakText),
    (Ext: 'ini';  MediaType: KX_CHAT_MEDIA_TEXT; Kind: cakText),
    (Ext: 'yaml'; MediaType: 'text/yaml';        Kind: cakText),
    (Ext: 'yml';  MediaType: 'text/yaml';        Kind: cakText));

var
  FInstance: TKXChatAttachments;

function NormalizedExt(const AFileName: string): string;
begin
  Result := ExtractFileExt(AFileName).ToLower;
  if Result.StartsWith('.') then
    Result := Result.Substring(1);
end;

function KXChatMediaTypeOf(const AFileName: string): string;
var
  LExt: string;
  I: Integer;
begin
  Result := '';
  LExt := NormalizedExt(AFileName);
  if LExt = '' then
    Exit;
  for I := Low(KX_ACCEPTED) to High(KX_ACCEPTED) do
    if KX_ACCEPTED[I].Ext = LExt then
      Exit(KX_ACCEPTED[I].MediaType);
end;

function KXChatKindOf(const AMediaType: string): TKXChatAttachmentKind;
begin
  if SameText(AMediaType, KX_CHAT_MEDIA_PDF) then
    Result := cakDocument
  else if AMediaType.StartsWith('image/', True) then
    Result := cakImage
  else
    Result := cakText;
end;

function KXChatIsAcceptedFile(const AFileName: string): Boolean;
begin
  Result := KXChatMediaTypeOf(AFileName) <> '';
end;

function KXChatAcceptedExtensions: string;
var
  I: Integer;
  LSb: TStringBuilder;
begin
  LSb := TStringBuilder.Create;
  try
    for I := Low(KX_ACCEPTED) to High(KX_ACCEPTED) do
    begin
      if LSb.Length > 0 then
        LSb.Append(',');
      LSb.Append('.').Append(KX_ACCEPTED[I].Ext);
    end;
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

function KXChatDecodeText(const AData: TBytes): string;
var
  LEncoding: TEncoding;
  LPreamble: Integer;
begin
  Result := '';
  if Length(AData) = 0 then
    Exit;

  // A BOM decides, whatever anybody guesses.
  LEncoding := nil;
  LPreamble := TEncoding.GetBufferEncoding(AData, LEncoding, nil);
  if Assigned(LEncoding) then
    Exit(LEncoding.GetString(AData, LPreamble, Length(AData) - LPreamble));

  // No BOM: UTF-8 is the answer nine times out of ten, and the tenth is a file
  // written by an editor that never heard of it. UTF8Encode's decoder raises on
  // bytes that are not valid UTF-8, which is exactly the signal we need.
  try
    Result := TEncoding.UTF8.GetString(AData);
    // A decoder that replaces instead of raising leaves the replacement
    // character behind: treat that as a failure too, or a Latin-1 file comes
    // through as a page of question marks.
    if Result.Contains(#$FFFD) then
      Result := TEncoding.ANSI.GetString(AData);
  except
    on E: Exception do
      Result := TEncoding.ANSI.GetString(AData);
  end;
end;

function KXChatFormatSize(const ABytes: Int64): string;
begin
  if ABytes >= 1024 * 1024 then
    Result := Format('%.1f MB', [ABytes / (1024 * 1024)])
  else if ABytes >= 1024 then
    Result := Format('%d KB', [ABytes div 1024])
  else
    Result := Format('%d B', [ABytes]);
end;

function KXChatHasBinaryAttachment(const AAttachments: TArray<TKXChatAttachment>): Boolean;
var
  I: Integer;
begin
  for I := Low(AAttachments) to High(AAttachments) do
    if (AAttachments[I].Kind <> cakText) and (Length(AAttachments[I].Data) > 0) then
      Exit(True);
  Result := False;
end;

function KXChatQuestionWithText(const AQuestion: string;
  const AAttachments: TArray<TKXChatAttachment>): string;
var
  I: Integer;
  LSb: TStringBuilder;
  LAny: Boolean;
begin
  Result := AQuestion;
  LAny := False;
  for I := Low(AAttachments) to High(AAttachments) do
    if (AAttachments[I].Kind = cakText) and (AAttachments[I].Text <> '') then
    begin
      LAny := True;
      Break;
    end;
  if not LAny then
    Exit;

  LSb := TStringBuilder.Create;
  try
    LSb.Append(_('Files attached to the question:'));
    for I := Low(AAttachments) to High(AAttachments) do
      if (AAttachments[I].Kind = cakText) and (AAttachments[I].Text <> '') then
      begin
        LSb.Append(sLineBreak).Append(sLineBreak);
        // The name goes on the fence: the model quotes it back when it says
        // where a value came from, and with two files attached that is the
        // only way the user can tell the two answers apart.
        LSb.Append('```').Append(AAttachments[I].FileName).Append(sLineBreak);
        LSb.Append(AAttachments[I].Text);
        if not AAttachments[I].Text.EndsWith(sLineBreak) then
          LSb.Append(sLineBreak);
        LSb.Append('```');
      end;
    LSb.Append(sLineBreak).Append(sLineBreak);
    LSb.Append(_('The question:')).Append(sLineBreak).Append(AQuestion);
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

{ TKXChatAttachment }

class function TKXChatAttachment.NewId: string;
begin
  Result := TGUID.NewGuid.ToString.Trim(['{', '}']).ToLower;
end;

function TKXChatAttachment.IsEmpty: Boolean;
begin
  Result := Id = '';
end;

function TKXChatAttachment.Base64: string;
begin
  if Length(Data) = 0 then
    Result := ''
  else
    // The one-line flavour: a line break inside the value would be a line
    // break inside the JSON string the provider sends.
    Result := TNetEncoding.Base64String.EncodeBytesToString(Data);
end;

function TKXChatAttachment.Extension: string;
begin
  Result := NormalizedExt(FileName);
end;

{ TKXChatAttachmentLimits }

class function TKXChatAttachmentLimits.Default: TKXChatAttachmentLimits;
begin
  Result.MaxCount := KX_CHAT_DEF_ATTACH_MAXCOUNT;
  Result.MaxSizeBytes := Int64(KX_CHAT_DEF_ATTACH_MAXSIZEKB) * 1024;
  Result.MaxTotalBytes := Int64(KX_CHAT_DEF_ATTACH_MAXTOTALKB) * 1024;
  Result.MaxImageBytes := Int64(KX_CHAT_DEF_ATTACH_IMAGEMAXKB) * 1024;
end;

{ TKXChatAttachments }

constructor TKXChatAttachments.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FItems := TObjectDictionary<string, TList<TKXChatAttachment>>.Create([doOwnsValues]);
end;

destructor TKXChatAttachments.Destroy;
begin
  FLock.Enter;
  try
    FItems.Free;
  finally
    FLock.Leave;
  end;
  FLock.Free;
  inherited;
end;

class function TKXChatAttachments.Instance: TKXChatAttachments;
begin
  if not Assigned(FInstance) then
    FInstance := TKXChatAttachments.Create;
  Result := FInstance;
end;

function TKXChatAttachments.ListOf(const AUser: string;
  const ACreate: Boolean): TList<TKXChatAttachment>;
begin
  if not FItems.TryGetValue(AUser, Result) then
  begin
    if not ACreate then
      Exit(nil);
    Result := TList<TKXChatAttachment>.Create;
    FItems.Add(AUser, Result);
  end;
end;

function TKXChatAttachments.IndexOfIdLocked(const AList: TList<TKXChatAttachment>;
  const AId: string): Integer;
var
  I: Integer;
begin
  if Assigned(AList) then
    for I := 0 to AList.Count - 1 do
      if SameText(AList[I].Id, AId) then
        Exit(I);
  Result := -1;
end;

function TKXChatAttachments.TryAdd(const AUser, AFileName: string;
  const AData: TBytes; const ALimits: TKXChatAttachmentLimits;
  out AAttachment: TKXChatAttachment; out AError: string): Boolean;
var
  LList: TList<TKXChatAttachment>;
  LName, LMediaType: string;
  LKind: TKXChatAttachmentKind;
  LSize, LTotal: Int64;
  I: Integer;
begin
  Result := False;
  AError := '';
  AAttachment := Default(TKXChatAttachment);

  // The name only: a browser may send a path, and a path has no business here
  // - neither in what is shown nor, one day, in what is written anywhere.
  // Both separators are normalized to the one of this platform first:
  // ExtractFileName knows '\' and the drive colon on Windows, and a name sent
  // with '/' would come through whole.
  LName := ExtractFileName(StringReplace(StringReplace(Trim(AFileName),
    '/', PathDelim, [rfReplaceAll]), '\', PathDelim, [rfReplaceAll]));
  if LName = '' then
  begin
    AError := _('The file has no name.');
    Exit;
  end;

  LSize := Length(AData);
  if LSize = 0 then
  begin
    AError := Format(_('"%s" is empty.'), [LName]);
    Exit;
  end;

  LMediaType := KXChatMediaTypeOf(LName);
  if LMediaType = '' then
  begin
    // By name, and said plainly: no model reads a .docx or a .xlsx, and one
    // sent and ignored would look like it worked.
    AError := Format(_('"%s" is not a kind of file the assistant can read. ' +
      'Accepted: %s.'), [LName, KXChatAcceptedExtensions]);
    Exit;
  end;
  LKind := KXChatKindOf(LMediaType);

  if (ALimits.MaxSizeBytes > 0) and (LSize > ALimits.MaxSizeBytes) then
  begin
    AError := Format(_('"%0:s" is too large (%1:s): the limit is %2:s.'),
      [LName, KXChatFormatSize(LSize), KXChatFormatSize(ALimits.MaxSizeBytes)]);
    Exit;
  end;

  // A picture has a limit of its own, lower, because the service refuses a
  // larger one - and a refused picture fails not this question but every later
  // one, since the attachments go up again with each of them.
  if (LKind = cakImage) and (ALimits.MaxImageBytes > 0) and (LSize > ALimits.MaxImageBytes) then
  begin
    AError := Format(_('"%0:s" is too large for a picture (%1:s): the limit is %2:s.'),
      [LName, KXChatFormatSize(LSize), KXChatFormatSize(ALimits.MaxImageBytes)]);
    Exit;
  end;

  FLock.Enter;
  try
    LList := ListOf(AUser, True);

    // Count and total are read, and the file added, under one lock: two uploads
    // arriving together must not both take the last place.
    if (ALimits.MaxCount > 0) and (LList.Count >= ALimits.MaxCount) then
    begin
      AError := Format(_('No more than %d files can be attached to a conversation.'),
        [ALimits.MaxCount]);
      Exit;
    end;

    LTotal := 0;
    for I := 0 to LList.Count - 1 do
      LTotal := LTotal + LList[I].OriginalSize;
    if (ALimits.MaxTotalBytes > 0) and (LTotal + LSize > ALimits.MaxTotalBytes) then
    begin
      AError := Format(_('The attachments of this conversation would go over %s in all.'),
        [KXChatFormatSize(ALimits.MaxTotalBytes)]);
      Exit;
    end;

    AAttachment.Id := TKXChatAttachment.NewId;
    AAttachment.FileName := LName;
    AAttachment.MediaType := LMediaType;
    AAttachment.Kind := LKind;
    AAttachment.Created := Now;
    AAttachment.OriginalSize := LSize;
    if LKind = cakText then
      // Decoded once, here: what travels is the text, and the bytes are not
      // kept beside it.
      AAttachment.Text := KXChatDecodeText(AData)
    else
      AAttachment.Data := AData;

    LList.Add(AAttachment);
    Result := True;
  finally
    FLock.Leave;
  end;
end;

function TKXChatAttachments.ItemsOf(const AUser: string): TArray<TKXChatAttachment>;
var
  LList: TList<TKXChatAttachment>;
begin
  FLock.Enter;
  try
    LList := ListOf(AUser, False);
    if Assigned(LList) then
      Result := LList.ToArray
    else
      Result := [];
  finally
    FLock.Leave;
  end;
end;

function TKXChatAttachments.TryGet(const AUser, AId: string;
  out AAttachment: TKXChatAttachment): Boolean;
var
  LList: TList<TKXChatAttachment>;
  LIndex: Integer;
begin
  Result := False;
  AAttachment := Default(TKXChatAttachment);
  FLock.Enter;
  try
    LList := ListOf(AUser, False);
    LIndex := IndexOfIdLocked(LList, AId);
    if LIndex >= 0 then
    begin
      AAttachment := LList[LIndex];
      Result := True;
    end;
  finally
    FLock.Leave;
  end;
end;

function TKXChatAttachments.Remove(const AUser, AId: string): Boolean;
var
  LList: TList<TKXChatAttachment>;
  LIndex: Integer;
begin
  FLock.Enter;
  try
    LList := ListOf(AUser, False);
    LIndex := IndexOfIdLocked(LList, AId);
    Result := LIndex >= 0;
    if Result then
      LList.Delete(LIndex);
  finally
    FLock.Leave;
  end;
end;

procedure TKXChatAttachments.ClearUser(const AUser: string);
begin
  FLock.Enter;
  try
    FItems.Remove(AUser);
  finally
    FLock.Leave;
  end;
end;

procedure TKXChatAttachments.ClearAll;
begin
  FLock.Enter;
  try
    FItems.Clear;
  finally
    FLock.Leave;
  end;
end;

function TKXChatAttachments.Count(const AUser: string): Integer;
var
  LList: TList<TKXChatAttachment>;
begin
  FLock.Enter;
  try
    LList := ListOf(AUser, False);
    if Assigned(LList) then
      Result := LList.Count
    else
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

function TKXChatAttachments.TotalSize(const AUser: string): Int64;
var
  LList: TList<TKXChatAttachment>;
  I: Integer;
begin
  Result := 0;
  FLock.Enter;
  try
    LList := ListOf(AUser, False);
    if Assigned(LList) then
      for I := 0 to LList.Count - 1 do
        Result := Result + LList[I].OriginalSize;
  finally
    FLock.Leave;
  end;
end;

initialization

finalization
  FreeAndNil(FInstance);

end.
