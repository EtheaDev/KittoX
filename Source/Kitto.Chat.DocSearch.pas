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
///  Deterministic help-chat provider (<c>docsearch</c>) that answers by
///  searching the bundled KittoX documentation index and pointing to the
///  matching published page. No API key, no network: it loads
///  <c>Resources/help/kittox-help.json</c> (generated from the VitePress corpus
///  by <c>Tools/build_help_index.py</c>) once, scores the user's terms against
///  each page (title weighted higher than body) and returns the best page's
///  summary plus a "read more" link to <c>HelpChat/DocBaseUrl</c>
///  (default https://ethea.it/docs/kittox/). It is the base example engine for
///  the help chat; a Claude/RAG provider can later reuse the same index.
/// </summary>
unit Kitto.Chat.DocSearch;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Chat.Provider;

type
  /// <summary>Answers from the local KittoX documentation index (name <c>docsearch</c>).</summary>
  TKXDocSearchProvider = class(TKXChatProviderBase)
  public
    function GetName: string; override;
    function Generate(const AHistory: TArray<TKXChatMessage>;
      const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc;
      const ACancel: IKXChatCancelToken): string; override;
  end;

  /// <summary>A documentation page returned by the shared search: title, absolute
  /// URL (base URL already joined) and one-line summary. Used both by the
  /// docsearch provider and by the Claude provider for RAG grounding.</summary>
  TKXHelpPage = record
    Title: string;
    Url: string;
    Summary: string;
    /// <summary>The passage that answers, not the beginning of the page: windows
    /// of text around the matching terms, merged and joined by an ellipsis. Empty
    /// when the whole page is short enough to be used as it is.</summary>
    Excerpt: string;
  end;

const
  /// <summary>Name of the deterministic documentation-search provider.</summary>
  KX_CHAT_PROVIDER_DOCSEARCH = 'docsearch';

/// <summary>
///  Searches the bundled documentation index for the pages best matching
///  <c>AQuery</c> (optionally biased by <c>AControllerType</c>, so a chat opened
///  from a List/Form view surfaces the matching framework page), most relevant
///  first, up to <c>AMaxPages</c> (&lt;= 0 defaults to 3). Returns <c>[]</c> when
///  the index is unavailable or nothing scores. Shared entry point for RAG
///  grounding: the Claude provider injects these pages into the system prompt.
/// </summary>
function KXSearchHelpPages(const AQuery, AControllerType: string;
  const AMaxPages: Integer; const AAreas: string = ''): TArray<TKXHelpPage>;

/// <summary>Truncating stemmer, language-neutral: eight characters or more keep
/// six, six or seven keep five, shorter ones stay whole. Brings singular and
/// plural, and most conjugations, to the same token without a dictionary for
/// each language — the documentation is English, the questions are not.</summary>
function KXChatStemToken(const AToken: string): string;

/// <summary>Lowercases, splits on anything that is not a letter or a digit,
/// drops words shorter than three characters and stopwords, and stems the
/// rest.</summary>
function KXChatTokenize(const AText: string): TArray<string>;

/// <summary>Counts the occurrences of ANeedle at the **start of a word** in
/// AHaystack (both already lowercased). Counting it anywhere would make "form"
/// match "information" and rank the wrong page.</summary>
function KXChatCountPrefixOccurrences(const AHaystack, ANeedle: string): Integer;

/// <summary>The passage of AText that answers: a window of characters around
/// each matching token, overlapping windows merged, pieces joined by an ellipsis,
/// the whole within AMaxChars. Returns the empty string when AText is already
/// shorter than the budget (the caller then uses it whole).</summary>
function KXChatBuildExcerpt(const AText, ALowerText: string;
  const ATokens: TArray<string>; const AMaxChars: Integer): string;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SyncObjs,
  System.Character,
  System.Generics.Collections,
  EF.Localization,
  Kitto.Config;

const
  /// <summary>Weight of a hit in the title: a page named like the question is
  /// the page about it.</summary>
  KX_DOC_TITLE_WEIGHT = 6.0;
  /// <summary>Weight of a hit in the page keywords (its headings): between the
  /// title and the body.</summary>
  KX_DOC_KEYWORD_WEIGHT = 3.0;
  /// <summary>Hits of one token in the body counted at most this many times, so
  /// a long page full of a common word does not bury the short page that
  /// answers.</summary>
  KX_DOC_BODY_HITS_CAP = 5;
  /// <summary>Multiplier of the tokens coming from the screen context: they name
  /// the page the user is on and must beat the words of a generic question.</summary>
  KX_DOC_HINT_WEIGHT = 2.0;
  /// <summary>Characters of context kept around each matching term.</summary>
  KX_DOC_EXCERPT_WINDOW = 600;
  /// <summary>Size of the excerpt handed to the provider, per page.</summary>
  KX_DOC_EXCERPT_MAXCHARS = 2000;

type
  TKXDocEntry = record
    Title: string;
    Url: string;
    Summary: string;
    Text: string;      // body as indexed (original case), for the excerpt
    LTitle: string;    // lowercased title (for scoring)
    LKeywords: string; // lowercased keywords, space-joined (for scoring)
    LText: string;     // lowercased body (for scoring)
    /// <summary>The areas of the manual this page belongs to, lowercased, each
    /// one between two commas (',invoices,vat,'), so that belonging is a
    /// substring test and needs no list to walk. Empty when the page declares
    /// none, and a page that declares none is <b>everybody's</b>.</summary>
    LAreas: string;
  end;

var
  FIndex: TArray<TKXDocEntry>;
  FLoaded: Boolean;
  FLoadLock: TCriticalSection;

const
  STOPWORDS: array[0..39] of string = (
    'the', 'and', 'for', 'with', 'that', 'this', 'from', 'how', 'can', 'you',
    'are', 'what', 'when', 'where', 'which', 'your', 'not', 'use', 'does',
    'come', 'che', 'per', 'con', 'non', 'una', 'uno', 'gli', 'dei', 'del',
    'nel', 'sul', 'come', 'cosa', 'quando', 'dove', 'posso', 'devo', 'mio',
    'the', 'and');

function IsStopWord(const AWord: string): Boolean;
var
  S: string;
begin
  for S in STOPWORDS do
    if S = AWord then
      Exit(True);
  Result := False;
end;

// Resolves the help index file: HelpChat/DocIndex if set, else
// Resources/help/kittox-help.json under the app home, then the system home.
function ResolveIndexPath: string;
var
  LConfigured: string;
begin
  LConfigured := TKConfig.Instance.Config.GetExpandedString('HelpChat/DocIndex');
  if (LConfigured <> '') and TFile.Exists(LConfigured) then
    Exit(LConfigured);
  Result := TPath.Combine(TKConfig.AppHomePath, 'Resources\help\kittox-help.json');
  if TFile.Exists(Result) then
    Exit;
  Result := TPath.Combine(TKConfig.SystemHomePath, 'Resources\help\kittox-help.json');
end;

// The index may or may not carry keywords: an index built before they existed
// is still valid, it simply scores on title and body alone.
function ReadKeywords(const AObj: TJSONObject): string;
var
  LValue: TJSONValue;
  LArray: TJSONArray;
  I: Integer;
begin
  Result := '';
  LValue := AObj.GetValue('keywords');
  if LValue = nil then
    Exit;
  if LValue is TJSONArray then
  begin
    LArray := TJSONArray(LValue);
    for I := 0 to LArray.Count - 1 do
      Result := Result + ' ' + LArray.Items[I].Value;
  end
  else
    Result := LValue.Value;
  Result := Trim(Result);
end;

// The areas a page declares. Like the keywords, they may simply not be there:
// an index built before areas existed, or a manual that has no areas at all,
// is still a valid index - every page of it belongs to everybody.
function ReadAreas(const AObj: TJSONObject): string;
var
  LValue: TJSONValue;
  LArray: TJSONArray;
  I: Integer;
begin
  Result := '';
  LValue := AObj.GetValue('areas');
  if LValue = nil then
    Exit;
  if LValue is TJSONArray then
  begin
    LArray := TJSONArray(LValue);
    for I := 0 to LArray.Count - 1 do
      Result := Result + ',' + Trim(LArray.Items[I].Value);
  end
  else
    Result := ',' + StringReplace(LValue.Value, ';', ',', [rfReplaceAll]);
  Result := Trim(Result);
  if Result <> '' then
    Result := KXChatNormalizeAreas(Result);
end;

procedure EnsureLoaded;
var
  LPath, LJson: string;
  LArray: TJSONArray;
  LValue: TJSONValue;
  LObj: TJSONObject;
  LList: TList<TKXDocEntry>;
  LEntry: TKXDocEntry;
  I: Integer;
begin
  if FLoaded then
    Exit;
  FLoadLock.Enter;
  try
    if FLoaded then
      Exit;
    FIndex := nil;
    try
      LPath := ResolveIndexPath;
      if TFile.Exists(LPath) then
      begin
        LJson := TFile.ReadAllText(LPath, TEncoding.UTF8);
        LArray := TJSONObject.ParseJSONValue(LJson) as TJSONArray;
        if LArray <> nil then
          try
            LList := TList<TKXDocEntry>.Create;
            try
              for I := 0 to LArray.Count - 1 do
              begin
                LValue := LArray.Items[I];
                if LValue is TJSONObject then
                begin
                  LObj := TJSONObject(LValue);
                  LEntry := Default(TKXDocEntry);
                  LEntry.Title := LObj.GetValue<string>('title', '');
                  LEntry.Url := LObj.GetValue<string>('url', '');
                  LEntry.Summary := LObj.GetValue<string>('summary', '');
                  LEntry.Text := LObj.GetValue<string>('text', '');
                  LEntry.LTitle := LEntry.Title.ToLower;
                  LEntry.LKeywords := ReadKeywords(LObj).ToLower;
                  LEntry.LAreas := ReadAreas(LObj);
                  LEntry.LText := LEntry.Text.ToLower;
                  if LEntry.Title <> '' then
                    LList.Add(LEntry);
                end;
              end;
              FIndex := LList.ToArray;
            finally
              LList.Free;
            end;
          finally
            LArray.Free;
          end;
      end;
    except
      // A missing/corrupt index must not break the chat: leave FIndex empty and
      // let Generate return a graceful fallback.
      FIndex := nil;
    end;
    FLoaded := True;
  finally
    FLoadLock.Leave;
  end;
end;

function KXChatStemToken(const AToken: string): string;
begin
  if AToken.Length >= 8 then
    Result := AToken.Substring(0, 6)
  else if AToken.Length >= 6 then
    Result := AToken.Substring(0, 5)
  else
    Result := AToken;
end;

function KXChatTokenize(const AText: string): TArray<string>;
var
  LList: TList<string>;
  LCur: string;
  C: Char;

  procedure Flush;
  begin
    // The stopword list is checked on the whole word, before stemming: stemming
    // it first would make "come" and "cosa" different tokens again.
    if (LCur.Length >= 3) and not IsStopWord(LCur) then
      LList.Add(KXChatStemToken(LCur));
    LCur := '';
  end;

begin
  LList := TList<string>.Create;
  try
    LCur := '';
    for C in AText.ToLower do
      if C.IsLetterOrDigit then
        LCur := LCur + C
      else
        Flush;
    Flush;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function Tokenize(const AText: string): TArray<string>;
begin
  Result := KXChatTokenize(AText);
end;

function KXChatCountPrefixOccurrences(const AHaystack, ANeedle: string): Integer;
var
  P: Integer;
begin
  Result := 0;
  if (ANeedle = '') or (AHaystack = '') then
    Exit;
  P := PosEx(ANeedle, AHaystack, 1);
  while P > 0 do
  begin
    // Only at the start of a word: counting anywhere would make "form" match
    // "information", and the page about information would win.
    if (P = 1) or not AHaystack[P - 1].IsLetterOrDigit then
      Inc(Result);
    P := PosEx(ANeedle, AHaystack, P + 1);
  end;
end;

/// <summary>Position (1-based) of the first occurrence of ANeedle at the start
/// of a word, or 0.</summary>
function FindPrefix(const AHaystack, ANeedle: string): Integer;
var
  P: Integer;
begin
  Result := 0;
  if (ANeedle = '') or (AHaystack = '') then
    Exit;
  P := PosEx(ANeedle, AHaystack, 1);
  while P > 0 do
  begin
    if (P = 1) or not AHaystack[P - 1].IsLetterOrDigit then
      Exit(P);
    P := PosEx(ANeedle, AHaystack, P + 1);
  end;
end;

function ScoreEntry(const AEntry: TKXDocEntry; const ATokens: TArray<string>;
  const AWeight: Double): Double;
var
  LToken: string;
  LBody: Integer;
begin
  Result := 0;
  for LToken in ATokens do
  begin
    LBody := KXChatCountPrefixOccurrences(AEntry.LText, LToken);
    if LBody > KX_DOC_BODY_HITS_CAP then
      LBody := KX_DOC_BODY_HITS_CAP;
    Result := Result + AWeight * (
      KXChatCountPrefixOccurrences(AEntry.LTitle, LToken) * KX_DOC_TITLE_WEIGHT +
      KXChatCountPrefixOccurrences(AEntry.LKeywords, LToken) * KX_DOC_KEYWORD_WEIGHT +
      LBody);
  end;
end;

function KXChatBuildExcerpt(const AText, ALowerText: string;
  const ATokens: TArray<string>; const AMaxChars: Integer): string;
type
  TWindow = record
    Start, Stop: Integer; // 0-based, Stop exclusive
  end;
var
  LWindows: TList<TWindow>;
  LWindow, LOther: TWindow;
  LToken, LPiece: string;
  P, I, LLen, LHalf, LBudget: Integer;
  LMerged: Boolean;
  LSb: TStringBuilder;
begin
  Result := '';
  LLen := AText.Length;
  if (AMaxChars <= 0) or (LLen = 0) or (LLen <= AMaxChars) then
    Exit; // short enough: the caller uses the page as it is
  LHalf := KX_DOC_EXCERPT_WINDOW div 2;
  LWindows := TList<TWindow>.Create;
  try
    for LToken in ATokens do
    begin
      P := FindPrefix(ALowerText, LToken);
      if P <= 0 then
        Continue;
      LWindow.Start := P - 1 - LHalf;
      if LWindow.Start < 0 then
        LWindow.Start := 0;
      LWindow.Stop := P - 1 + LToken.Length + LHalf;
      if LWindow.Stop > LLen then
        LWindow.Stop := LLen;
      // Merge with an overlapping window instead of repeating the same text.
      LMerged := False;
      for I := 0 to LWindows.Count - 1 do
      begin
        LOther := LWindows[I];
        if (LWindow.Start <= LOther.Stop) and (LWindow.Stop >= LOther.Start) then
        begin
          if LWindow.Start < LOther.Start then
            LOther.Start := LWindow.Start;
          if LWindow.Stop > LOther.Stop then
            LOther.Stop := LWindow.Stop;
          LWindows[I] := LOther;
          LMerged := True;
          Break;
        end;
      end;
      if not LMerged then
        LWindows.Add(LWindow);
    end;
    if LWindows.Count = 0 then
      Exit;
    LSb := TStringBuilder.Create;
    try
      LBudget := AMaxChars;
      for I := 0 to LWindows.Count - 1 do
      begin
        if LBudget <= 0 then
          Break;
        LWindow := LWindows[I];
        LPiece := Copy(AText, LWindow.Start + 1, LWindow.Stop - LWindow.Start);
        if Length(LPiece) > LBudget then
          LPiece := Copy(LPiece, 1, LBudget);
        Dec(LBudget, Length(LPiece));
        if LSb.Length > 0 then
          LSb.Append(' ... ');
        LSb.Append(Trim(LPiece));
      end;
      Result := LSb.ToString;
    finally
      LSb.Free;
    end;
  finally
    LWindows.Free;
  end;
end;

// The prefix of the links to the manual. The default is the published
// documentation of the framework; an application that has a manual of its own
// says where it is published, or declares the node empty to say that it is not
// published at all - and then its pages are named without being linked.
function DocBaseUrl: string;
begin
  Result := TKConfig.Instance.Config.GetExpandedString('HelpChat/DocBaseUrl',
    'https://ethea.it/docs/kittox/');
  if (Result <> '') and not Result.EndsWith('/') then
    Result := Result + '/';
end;

function KXSearchHelpPages(const AQuery, AControllerType: string;
  const AMaxPages: Integer; const AAreas: string): TArray<TKXHelpPage>;
var
  LTokens, LHintTokens, LAll: TArray<string>;
  LAreas: string;
  LScores: TArray<Double>;
  LUsed: TArray<Boolean>;
  LBase: string;
  LMax, LBestIdx, I, J: Integer;
  LBestScore: Double;
  LPages: TList<TKXHelpPage>;
  LPage: TKXHelpPage;
begin
  Result := [];
  EnsureLoaded;
  if Length(FIndex) = 0 then
    Exit;

  // Two groups with different weights: the words of the question, and those of
  // the screen the chat was opened from, which name the page the user is on and
  // must beat the words of a generic "how do I use this screen?".
  LTokens := Tokenize(AQuery);
  LHintTokens := [];
  if AControllerType <> '' then
    LHintTokens := Tokenize(AControllerType);
  if (Length(LTokens) = 0) and (Length(LHintTokens) = 0) then
    Exit;
  LAll := LTokens + LHintTokens;

  // The areas this assistant reads. A page that belongs to none is everybody's,
  // and an assistant that declares none reads the whole manual: a score of zero
  // is how a page is left out, so nothing else below has to know about areas.
  LAreas := KXChatNormalizeAreas(AAreas);

  SetLength(LScores, Length(FIndex));
  for I := 0 to High(FIndex) do
    if not KXChatAreaMatches(FIndex[I].LAreas, LAreas) then
      LScores[I] := 0
    else
      LScores[I] := ScoreEntry(FIndex[I], LTokens, 1.0) +
                    ScoreEntry(FIndex[I], LHintTokens, KX_DOC_HINT_WEIGHT);

  LBase := DocBaseUrl;
  LMax := AMaxPages;
  if LMax <= 0 then
    LMax := 3;
  SetLength(LUsed, Length(FIndex));

  LPages := TList<TKXHelpPage>.Create;
  try
    // Greedy top-N by score (score must be > 0 to be relevant at all).
    for J := 1 to LMax do
    begin
      LBestIdx := -1;
      LBestScore := 0;
      for I := 0 to High(FIndex) do
        if (not LUsed[I]) and (LScores[I] > LBestScore) then
        begin
          LBestScore := LScores[I];
          LBestIdx := I;
        end;
      if LBestIdx < 0 then
        Break;
      LUsed[LBestIdx] := True;
      LPage := Default(TKXHelpPage);
      LPage.Title := FIndex[LBestIdx].Title;
      // No base: the manual of this application is not published anywhere, and
      // a page of it has no address. Half an address - 'invoices.html' against
      // the root of the application - is a link that leads to a 404, which is
      // worse for the user than a page named and not linked.
      if LBase = '' then
        LPage.Url := ''
      else
        LPage.Url := LBase + FIndex[LBestIdx].Url;
      LPage.Summary := FIndex[LBestIdx].Summary;
      // The passage that answers, not the first paragraph of a long page.
      LPage.Excerpt := KXChatBuildExcerpt(FIndex[LBestIdx].Text, FIndex[LBestIdx].LText,
        LAll, KX_DOC_EXCERPT_MAXCHARS);
      LPages.Add(LPage);
    end;
    Result := LPages.ToArray;
  finally
    LPages.Free;
  end;
end;

{ TKXDocSearchProvider }

function TKXDocSearchProvider.GetName: string;
begin
  Result := KX_CHAT_PROVIDER_DOCSEARCH;
end;

function TKXDocSearchProvider.Generate(const AHistory: TArray<TKXChatMessage>;
  const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc;
  const ACancel: IKXChatCancelToken): string;
var
  LQuestion, LBody: string;
  LPages: TArray<TKXHelpPage>;
  I: Integer;
begin
  EnsureLoaded;

  // The last user message is the question.
  LQuestion := '';
  for I := High(AHistory) downto Low(AHistory) do
    if AHistory[I].Role = crUser then
    begin
      LQuestion := AHistory[I].Content;
      Break;
    end;

  if (Length(FIndex) = 0) then
    Exit(Format(_('The help index is not available. See the [documentation](%s).'),
      [DocBaseUrl]));

  // Same search the AI provider grounds on: one scoring, one behaviour.
  // Restricted to the areas of the manual this assistant reads, if it says.
  LPages := KXSearchHelpPages(LQuestion, AContext.ControllerType, 2,
    KXChatSetting(AContext.Profile, 'DocAreas'));
  if Length(LPages) = 0 then
    Exit(Format(_('I could not find a specific page for your question. Browse the [documentation](%s).'),
      [DocBaseUrl]));

  // The passage that answers when the page is long, the summary when it is not.
  LBody := LPages[0].Excerpt;
  if Trim(LBody) = '' then
    LBody := LPages[0].Summary;

  // Markdown: the chat renderer turns links and bold into safe HTML.
  Result := Format('**%s**'#10#10'%s'#10#10'[%s](%s)',
    [LPages[0].Title, LBody, _('Read more'), LPages[0].Url]);

  if Length(LPages) > 1 then
    Result := Result + Format(#10#10'%s [%s](%s)',
      [_('See also:'), LPages[1].Title, LPages[1].Url]);
end;

initialization
  FLoadLock := TCriticalSection.Create;
  TKXChatProviderRegistry.RegisterProvider(KX_CHAT_PROVIDER_DOCSEARCH, TKXDocSearchProvider);

finalization
  if TKXChatProviderRegistry.IsRegistered(KX_CHAT_PROVIDER_DOCSEARCH) then
    TKXChatProviderRegistry.UnregisterProvider(KX_CHAT_PROVIDER_DOCSEARCH);
  FLoadLock.Free;

end.
