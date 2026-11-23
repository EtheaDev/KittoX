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
///  What the help chat answers depends on how the documentation is searched,
///  and the search is made of four pure steps: stemming, tokenizing, counting a
///  term at the start of a word, and cutting the passage that answers out of a
///  long page. They are tested here on their own, without an index, a config or
///  a provider.
/// </summary>
unit Kitto.ChatSearchTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TKXChatSearchTests = class
  public
    /// <summary>Truncation by length: long words lose more, short ones nothing.</summary>
    [Test]
    procedure Stem_TruncatesByLength;
    /// <summary>Singular and plural, and a conjugation, reach the same token.</summary>
    [Test]
    procedure Stem_BringsFormsTogether;
    /// <summary>Lowercase, no short words, no stopwords, everything stemmed.</summary>
    [Test]
    procedure Tokenize_DropsNoiseAndStems;
    /// <summary>A term is counted where a word begins, not inside another word.</summary>
    [Test]
    procedure CountPrefix_OnlyAtWordStart;
    /// <summary>A page shorter than the budget is left to the caller.</summary>
    [Test]
    procedure Excerpt_ShortPage_IsEmpty;
    /// <summary>A long page gives back the passage around the term, within budget.</summary>
    [Test]
    procedure Excerpt_LongPage_KeepsTheMatchingPassage;
    /// <summary>Two distant terms give two pieces, joined by an ellipsis.</summary>
    [Test]
    procedure Excerpt_TwoMatches_AreJoined;
  end;

implementation

uses
  System.SysUtils,
  Kitto.Chat.DocSearch;

procedure TKXChatSearchTests.Stem_TruncatesByLength;
begin
  Assert.AreEqual('config', KXChatStemToken('configure'), '9 characters keep 6');
  Assert.AreEqual('calend', KXChatStemToken('calendar'), '8 characters keep 6');
  Assert.AreEqual('filte', KXChatStemToken('filter'), '6 characters keep 5');
  Assert.AreEqual('panel', KXChatStemToken('panel'), 'shorter words are left alone');
  Assert.AreEqual('', KXChatStemToken(''));
end;

procedure TKXChatSearchTests.Stem_BringsFormsTogether;
begin
  Assert.AreEqual(KXChatStemToken('calendar'), KXChatStemToken('calendars'),
    'singular and plural must score the same page');
  Assert.AreEqual(KXChatStemToken('configure'), KXChatStemToken('configuration'));
  Assert.AreNotEqual(KXChatStemToken('calendar'), KXChatStemToken('controller'),
    'truncation must not make different words equal');
end;

procedure TKXChatSearchTests.Tokenize_DropsNoiseAndStems;
var
  LTokens: TArray<string>;
begin
  LTokens := KXChatTokenize('How can I configure the Calendar panel?');
  Assert.AreEqual(3, Integer(Length(LTokens)), 'how/can/the are stopwords, "I" is too short');
  Assert.AreEqual('config', LTokens[0]);
  Assert.AreEqual('calend', LTokens[1]);
  Assert.AreEqual('panel', LTokens[2]);
  Assert.AreEqual(0, Integer(Length(KXChatTokenize('how can I use this?'))),
    'a question made of noise alone produces nothing');
end;

procedure TKXChatSearchTests.CountPrefix_OnlyAtWordStart;
begin
  // "form" is in "information" too, but a page about information is not a page
  // about forms: counting it there would rank the wrong page.
  Assert.AreEqual(2, KXChatCountPrefixOccurrences('information form forms', 'form'));
  Assert.AreEqual(0, KXChatCountPrefixOccurrences('information', 'form'));
  Assert.AreEqual(1, KXChatCountPrefixOccurrences('form', 'form'), 'the start of the text counts');
  Assert.AreEqual(0, KXChatCountPrefixOccurrences('anything', ''));
  Assert.AreEqual(0, KXChatCountPrefixOccurrences('', 'form'));
end;

procedure TKXChatSearchTests.Excerpt_ShortPage_IsEmpty;
var
  LText: string;
begin
  LText := 'A short page about the calendar panel.';
  Assert.AreEqual('', KXChatBuildExcerpt(LText, LText.ToLower, ['calend'], 2000),
    'nothing to cut: the caller uses the page as it is');
end;

procedure TKXChatSearchTests.Excerpt_LongPage_KeepsTheMatchingPassage;
var
  LText, LExcerpt: string;
begin
  LText := StringOfChar('x', 3000) + ' thecalendarpanel ' + StringOfChar('y', 3000);
  LExcerpt := KXChatBuildExcerpt(LText, LText.ToLower, ['thecal'], 1000);
  Assert.IsTrue(LExcerpt.Contains('thecalendarpanel'), 'the passage that answers must be in it');
  Assert.IsTrue(Length(LExcerpt) <= 1000, 'the budget is a budget');
  Assert.IsTrue(Length(LExcerpt) > 0);
end;

procedure TKXChatSearchTests.Excerpt_TwoMatches_AreJoined;
var
  LText, LExcerpt: string;
begin
  LText := 'alpha ' + StringOfChar('x', 4000) + ' omega ' + StringOfChar('y', 4000);
  LExcerpt := KXChatBuildExcerpt(LText, LText.ToLower, ['alpha', 'omega'], 2000);
  Assert.IsTrue(LExcerpt.Contains('alpha'));
  Assert.IsTrue(LExcerpt.Contains('omega'));
  Assert.IsTrue(LExcerpt.Contains('...'), 'distant pieces are joined by an ellipsis');
end;

initialization
  TDUnitX.RegisterTestFixture(TKXChatSearchTests);

end.
