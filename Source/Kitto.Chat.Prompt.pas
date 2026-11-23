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
///  What every AI provider of the help chat has to do before it can ask
///  anything of a model, and which has nothing to do with the API it speaks:
///  assemble the system prompt - identity, field of expertise, rules, language,
///  the screen the chat was opened from and the documentation excerpts - ask
///  for the search terms when the manual is written in another language, and
///  add the line of sources when the model names a page without linking it.
///  <para>It lives in a unit of its own, between the chat domain and the
///  providers, because the second provider proved the point: all of this was
///  written inside the Claude one, and none of it is about Claude. What a
///  provider still owns is only how the <i>bytes</i> of its own API are
///  shaped.</para>
/// </summary>
unit Kitto.Chat.Prompt;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Chat.Provider
  , Kitto.Chat.DocSearch
  ;

/// <summary>The last thing the user said: the question being answered.</summary>
function KXChatLastUserMessage(const AHistory: TArray<TKXChatMessage>): string;

/// <summary>
///  The user message before the last one, which is what a follow-up leans on:
///  on its own "and to cancel it?" carries none of the words that would find a
///  page.
/// </summary>
function KXChatPreviousUserMessage(const AHistory: TArray<TKXChatMessage>): string;

/// <summary>
///  The system prompt: the base instruction (or the configured override), who
///  the assistant is and when, its field of expertise, the rule that governs
///  that field, the rule about the language, the screen the chat was opened
///  from, and the documentation pages that best match the question.
///  <para><c>APages</c> comes back with the pages that were actually injected,
///  which is what <see cref="KXChatSourcesLine" /> needs afterwards.</para>
///  <para>Every setting is read through <c>AContext.Profile</c>: this is where
///  one assistant differs from another.</para>
/// </summary>
function KXChatBuildSystemPrompt(const AHistory: TArray<TKXChatMessage>;
  const AContext: TKXChatContext; const ASystemPromptOverride: string;
  const AGroundingMaxPages: Integer; const ASearchTerms: string;
  out APages: TArray<TKXHelpPage>): string;

/// <summary>
///  The line of search terms for this question, in the language the manual is
///  written in, or empty when there is nothing to gain (no <c>DocLanguage</c>,
///  the same language as the chat, the setting off) or nothing came back.
///  <para>It is asked of <c>AProvider</c> itself - one short request, no
///  streaming - so that the model which answers is also the one that writes the
///  terms. A provider that cannot do it answers empty and the search runs as it
///  would have anyway: what fails here costs the terms, never the reply.</para>
/// </summary>
function KXChatSearchTerms(const AProvider: TKXChatProviderBase;
  const AHistory: TArray<TKXChatMessage>; const AContext: TKXChatContext;
  const ACancel: IKXChatCancelToken): string;

/// <summary>
///  The line of sources to append to a reply: the system prompt asks the model
///  to cite the page it used, and most of the time it does. When it does not -
///  "according to the documentation", no link - the line is added from the
///  pages that were actually injected. A page is cited only if the reply names
///  it and does not already link it.
/// </summary>
function KXChatSourcesLine(const AReply: string;
  const APages: TArray<TKXHelpPage>): string;

implementation

uses
  System.SysUtils
  , System.Classes
  , EF.Localization
  , EF.Logger
  ;

function KXChatLastUserMessage(const AHistory: TArray<TKXChatMessage>): string;
var
  I: Integer;
begin
  Result := '';
  for I := High(AHistory) downto Low(AHistory) do
    if AHistory[I].Role = crUser then
      Exit(AHistory[I].Content);
end;

function KXChatPreviousUserMessage(const AHistory: TArray<TKXChatMessage>): string;
var
  I: Integer;
  LSeen: Boolean;
begin
  Result := '';
  LSeen := False;
  for I := High(AHistory) downto Low(AHistory) do
    if AHistory[I].Role = crUser then
    begin
      if LSeen then
        Exit(AHistory[I].Content);
      LSeen := True;
    end;
end;

function KXChatBuildSystemPrompt(const AHistory: TArray<TKXChatMessage>;
  const AContext: TKXChatContext; const ASystemPromptOverride: string;
  const AGroundingMaxPages: Integer; const ASearchTerms: string;
  out APages: TArray<TKXHelpPage>): string;
var
  LBase, LQuestion, LScreen, LLanguageRule, LAreas: string;
  LSb: TStringBuilder;
  LPages: TArray<TKXHelpPage>;
  LText: string;
  I: Integer;
begin
  // Use the configured override if present, else the localized default. The
  // literal is kept here (not a constant) so dxgettext can extract it.
  LBase := ASystemPromptOverride;
  if LBase = '' then
    LBase := _('You are the in-app help assistant for a web application built with the KittoX framework. ' +
      'Answer the user concisely and practically, focusing on how to use the application. ' +
      'Prefer the documentation excerpts provided below when they are relevant, and cite the linked page. ' +
      'If you are not sure, say so and point to the documentation rather than inventing details. ' +
      'Reply in the same language as the user. You may use short Markdown (links, bold, inline code).');

  // Who it is, when it is answering, and the field it knows: all three live at
  // the root of HelpChat (or of the profile) and not in the provider section,
  // because changing model must not change who the assistant is. Through the
  // profile: who the assistant is and what it is expert of are exactly the two
  // things a second assistant exists to change. NB: the literal default of the
  // name is repeated here (not the constant) so dxgettext can extract it.
  LBase := KXChatComposeSystemPrompt(
    KXChatComposeIdentity(
      KXChatPromptField(KXChatSetting(AContext.Profile, 'AssistantName', _('Help'))),
      KXChatNowText),
    KXChatSetting(AContext.Profile, 'Expertise'), LBase);

  // The language of the chat is the language of the session the question was
  // asked from: it travels in the context, because here we are on a worker and
  // a session is thread-local. Saying it is not the same as letting the model
  // follow the question - two words written in English inside an Italian
  // application are not a change of language - and it is the only thing the
  // flag in the header of the panel changes for the model.
  // DocLanguage is empty unless the manual is written in another language than
  // the one the user reads the answers in.
  LLanguageRule := KXChatComposeLanguageRule(KXChatLanguageName(AContext.Language),
    KXChatLanguageName(KXChatSetting(AContext.Profile, 'DocLanguage')));
  if LLanguageRule <> '' then
    LBase := LBase + ' ' + LLanguageRule;

  LSb := TStringBuilder.Create;
  try
    LSb.Append(LBase);

    // Context of the screen the chat was opened from, when available.
    if (AContext.ViewName <> '') or (AContext.ControllerType <> '') then
    begin
      if AContext.ViewLabel <> '' then
        LScreen := AContext.ViewLabel
      else
        LScreen := AContext.ViewName;
      LSb.Append(#10#10);
      // Both travel in the request: the view name is the label when the view is
      // not found, and the controller type is taken as posted when the view does
      // not give one. Neither may reach the prompt as more than one line.
      LSb.Append(Format(_('The user is currently on the "%s" screen (controller type: %s).'),
        [KXChatPromptField(LScreen), KXChatPromptField(AContext.ControllerType, 60)]));
    end;

    // RAG grounding: inject the best-matching documentation pages.
    if AGroundingMaxPages <> 0 then
    begin
      LQuestion := KXChatLastUserMessage(AHistory);
      // With the terms, the question is searched together with the words the
      // manual is likely to use - and without the hint of the screen. The hint
      // weighs enough to keep the page of the current screen on top whatever
      // the question says, which is right when the question has no words the
      // index knows, and wrong as soon as it has: measured in the sibling
      // project, dropping it with the terms in hand took the Italian questions
      // whose answer is on another page from three right out of six to five,
      // and the questions written in the words of someone who never read the
      // manual from one out of seven to six.
      // The areas restrict the manual to what this assistant is supposed to
      // read; a page that declares no area is everybody's.
      LAreas := KXChatSetting(AContext.Profile, 'DocAreas');
      if ASearchTerms <> '' then
        LPages := KXSearchHelpPages(LQuestion + ' ' + ASearchTerms, '',
          AGroundingMaxPages, LAreas)
      else
        LPages := KXSearchHelpPages(LQuestion, AContext.ControllerType,
          AGroundingMaxPages, LAreas);
      APages := LPages;
      if Length(LPages) > 0 then
      begin
        LSb.Append(#10#10);
        LSb.Append(_('Relevant documentation excerpts:'));
        for I := Low(LPages) to High(LPages) do
        begin
          LSb.Append(#10#10);
          LText := LPages[I].Excerpt;
          if Trim(LText) = '' then
            LText := LPages[I].Summary;
          // A page with no address is named and not linked: its manual is not
          // published anywhere, and a link that leads nowhere is worse than
          // none.
          if LPages[I].Url <> '' then
            LSb.Append(Format('## %s'#10'%s'#10'%s: %s',
              [LPages[I].Title, LText, _('Source'), LPages[I].Url]))
          else
            LSb.Append(Format('## %s'#10'%s', [LPages[I].Title, LText]));
        end;
      end;
    end;

    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

function KXChatSearchTerms(const AProvider: TKXChatProviderBase;
  const AHistory: TArray<TKXChatMessage>; const AContext: TKXChatContext;
  const ACancel: IKXChatCancelToken): string;
var
  LChat, LDoc, LPrompt: string;
begin
  Result := '';
  if not Assigned(AProvider) then
    Exit;
  if not KXChatSettingBoolean(AContext.Profile, 'TranslateSearch',
    KX_HELPCHAT_DEF_TRANSLATESEARCH) then
    Exit;

  LChat := KXChatLanguageName(AContext.Language);
  LDoc := KXChatLanguageName(KXChatSetting(AContext.Profile, 'DocLanguage'));
  if not KXChatNeedsSearchTerms(LChat, LDoc) then
    Exit;

  LPrompt := KXChatComposeSearchTermsPrompt(KXChatLastUserMessage(AHistory),
    KXChatPreviousUserMessage(AHistory), LDoc,
    KXChatSetting(AContext.Profile, 'SearchTermsPrompt'));
  if LPrompt = '' then
    Exit;

  Result := KXChatCleanSearchTerms(
    AProvider.CompleteText(LPrompt, KX_HELPCHAT_SEARCHTERMS_TOKENS, ACancel));
  if Result <> '' then
    TEFLogger.Instance.Log('Help Chat: search terms: ' + Result, TEFLogger.LOG_DETAILED);
end;

function KXChatSourcesLine(const AReply: string;
  const APages: TArray<TKXHelpPage>): string;
var
  LPage: TKXHelpPage;
  LLowerReply: string;
begin
  Result := '';
  if (Trim(AReply) = '') or (Length(APages) = 0) then
    Exit;
  LLowerReply := AReply.ToLower;
  for LPage in APages do
  begin
    if (LPage.Title = '') or (LPage.Url = '') then
      Continue;
    if not LLowerReply.Contains(LPage.Title.ToLower) then
      Continue;
    if AReply.Contains(LPage.Url) then
      Continue; // already linked: nothing to add
    Exit(Format(#10#10'%s: [%s](%s)', [_('Source'), LPage.Title, LPage.Url]));
  end;
end;

end.
