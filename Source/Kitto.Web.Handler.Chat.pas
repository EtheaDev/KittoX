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
///  Attribute-routed endpoints for the in-app help chat: the drawer history
///  partial, message send (enqueues the provider call on the chat runner and
///  returns the user bubble plus a pending assistant bubble), the poll endpoint
///  the client uses to fetch the assistant reply once the worker has produced it,
///  and a conversation reset, plus the two the header of the panel asks for: the
///  language switcher of the application and the conversation as a printable
///  document. Requires an authenticated user; all responses are HTML fragments
///  requested by htmx/fetch (with the X-KittoX header), so the navigation guard
///  leaves them alone and no [TKXNavigable] is needed - except the printable
///  document, which is a page opened in a tab of its own and says so.
/// </summary>
unit Kitto.Web.Handler.Chat;

{$I Kitto.Defines.inc}
{$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}

interface

uses
  Kitto.Web.Routing.Attributes;

type
  /// <summary>Serves the help-chat drawer history, message send, reply polling
  /// and conversation reset.</summary>
  [TKXPath('/kx/chat')]
  TKXChatHandler = class
  public
    /// <summary>Returns the HTML of the current user's conversation (all bubbles),
    /// or a greeting when empty. Requested when the drawer opens.</summary>
    [TKXPath('/panel')]
    [TKXGET]
    procedure HandlePanel;

    /// <summary>Accepts a user message (form fields <c>message</c> and optional
    /// <c>viewName</c>), appends it plus a pending assistant bubble, submits the
    /// provider call to the chat runner, and returns both bubbles for immediate
    /// display. The assistant bubble carries its id for polling.</summary>
    [TKXPath('/send')]
    [TKXPOST]
    procedure HandleSend;

    /// <summary>Returns the assistant bubble for the given message id. While the
    /// worker is still producing the reply the bubble is marked pending (typing
    /// indicator); once ready it carries the final text (or the error).</summary>
    [TKXPath('/poll/{MsgId}')]
    [TKXGET]
    procedure HandlePoll([TKXPathParam('MsgId')] const AMsgId: string);

    /// <summary>Asks the reply with the given id to stop and returns its bubble.
    /// Cooperative: a provider that cannot be interrupted finishes anyway, but the
    /// bubble is closed as soon as it notices, keeping what it had streamed.</summary>
    [TKXPath('/cancel/{MsgId}')]
    [TKXPOST]
    procedure HandleCancel([TKXPathParam('MsgId')] const AMsgId: string);

    /// <summary>Clears the current user's conversation and returns the greeting.</summary>
    [TKXPath('/clear')]
    [TKXPOST]
    procedure HandleClear;

    /// <summary>
    ///  Accepts one file for the conversation of the current user and answers
    ///  with the bar of the attachments, which the panel swaps in place. A file
    ///  that is refused - a type no model reads, a limit reached - comes back
    ///  as the same bar carrying the reason, because a refusal the user cannot
    ///  read is a file that vanished.
    /// </summary>
    [TKXPath('/attach')]
    [TKXPOST]
    procedure HandleAttach;

    /// <summary>Drops one attachment and answers with the bar.</summary>
    [TKXPath('/attach/{AttId}/remove')]
    [TKXPOST]
    procedure HandleAttachRemove([TKXPathParam('AttId')] const AAttId: string);

    /// <summary>The bar as it stands: what the panel asks for when it opens,
    /// so that a reload finds the files that are still attached. The twin
    /// project had the opposite bug - the bar emptied by a reload while the
    /// files kept going out with every question.</summary>
    [TKXPath('/attachments')]
    [TKXGET]
    procedure HandleAttachments;

    /// <summary>Returns the flag dropdown of the interface languages, for the
    /// header of the panel. The chat has no language of its own: this is the
    /// switcher of the application (same endpoint, same reload), so changing it
    /// here changes the whole interface - and the language the model is told to
    /// answer in. Empty when the application ships one language only or does not
    /// let the session choose: the client then shows no flag.</summary>
    [TKXPath('/langs')]
    [TKXGET]
    procedure HandleLangs;

    /// <summary>Returns the conversation as a printable document: a page of its
    /// own, not a fragment, which the client opens in a tab and prints (where
    /// the browser also offers to save it as PDF). The questions and the
    /// answers, nothing of the application around them - a drawer of a dark
    /// theme printed is a black rectangle.</summary>
    [TKXPath('/print')]
    [TKXGET]
    [TKXNavigable]
    procedure HandlePrint;
  end;

/// <summary>Plain text to HTML: encodes the text and turns newlines into &lt;br&gt;.
/// Used for the user's own messages and for error texts, which are never
/// interpreted as Markdown.</summary>
function KXChatTextToHtml(const AText: string): string;

/// <summary>Markdown to a safe HTML fragment (CommonMark, active HTML escaped,
/// link and image URLs restricted to <see cref="KXChatIsSafeUrl" />). Tolerant
/// of partial input, so it also renders the growing partial of a streaming
/// reply. On any error it falls back to HTML-encoded text.</summary>
function KXChatMarkdownToSafeHtml(const AMarkdown: string): string;

/// <summary>True for URLs a chat bubble may link to: http(s), mailto, ftp(s),
/// anchors and relative paths. Anything with another scheme (javascript:,
/// data:, vbscript:, file:...) is rejected. Entity-encoded and whitespace-padded
/// schemes are normalized before the check.</summary>
function KXChatIsSafeUrl(const AUrl: string): Boolean;

/// <summary>Rewrites every href/src attribute of an HTML fragment whose URL is
/// not <see cref="KXChatIsSafeUrl" /> to "#" (the original is dropped). The
/// Markdown library escapes active elements but not dangerous link targets.</summary>
function KXChatSanitizeUrls(const AHtml: string): string;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.NetEncoding,
  System.RegularExpressions,
  EF.Tree,
  EF.Localization,
  Kitto.Auth,
  Kitto.Config,
  Kitto.Web.Request,
  Kitto.Web.Response,
  Kitto.Metadata.Views,
  Kitto.Web.Session,
  Kitto.Chat.Attachments,
  Kitto.Html.LanguageSwitcher,
  Kitto.Chat.Provider,
  Kitto.Chat.Runner,
  Kitto.Web.Routing.Registry,
  Kitto.MarkdownProcessor,
  Kitto.MarkdownUtils;

function RoleToClass(const ARole: TKXChatRole): string;
begin
  case ARole of
    crUser:      Result := 'user';
    crAssistant: Result := 'assistant';
  else
    Result := 'system';
  end;
end;

// Plain-text -> safe HTML: encode, then turn newlines into <br>.
function KXChatTextToHtml(const AText: string): string;
begin
  Result := TNetEncoding.HTML.Encode(AText);
  Result := StringReplace(Result, #13#10, '<br>', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '<br>', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '<br>', [rfReplaceAll]);
end;

function KXChatIsSafeUrl(const AUrl: string): Boolean;
var
  LUrl: string;
  C: Char;
  LColon, LSlash: Integer;
begin
  // Normalize what a browser would tolerate before looking at the scheme:
  // entities (java&#115;cript:), control characters and spaces (java\tscript:).
  LUrl := '';
  for C in TNetEncoding.HTML.Decode(AUrl) do
    if Ord(C) > 32 then
      LUrl := LUrl + C;
  if LUrl = '' then
    Exit(True); // empty: harmless
  LUrl := LUrl.ToLower;
  if LUrl.StartsWith('#') or LUrl.StartsWith('/') or LUrl.StartsWith('./') or LUrl.StartsWith('../') then
    Exit(True);
  if LUrl.StartsWith('http://') or LUrl.StartsWith('https://') or LUrl.StartsWith('mailto:') or
     LUrl.StartsWith('ftp://') or LUrl.StartsWith('ftps://') then
    Exit(True);
  // No scheme at all (no ':' before the first '/', '?' or '#'): a relative path.
  LColon := LUrl.IndexOf(':');
  if LColon < 0 then
    Exit(True);
  LSlash := LUrl.IndexOfAny(['/', '?', '#']);
  Result := (LSlash >= 0) and (LSlash < LColon);
end;

type
  // TMatchEvaluator is a method pointer ("of object"), hence the tiny holder.
  TKXUrlAttributeSanitizer = class
    function Evaluate(const AMatch: TMatch): string;
  end;

function TKXUrlAttributeSanitizer.Evaluate(const AMatch: TMatch): string;
var
  LQuoted, LUrl: string;
begin
  // Group 2 is the quoted value, whichever quote was used: strip the delimiters
  // (the optional inner groups are not reliable across RTL versions).
  LQuoted := AMatch.Groups[2].Value;
  LUrl := LQuoted.Substring(1, LQuoted.Length - 2);
  if KXChatIsSafeUrl(LUrl) then
    Result := AMatch.Value
  else
    Result := AMatch.Groups[1].Value + '"#"';
end;

function KXChatSanitizeUrls(const AHtml: string): string;
var
  LSanitizer: TKXUrlAttributeSanitizer;
begin
  // (href|src) = "..." or '...': the value is checked, never rewritten in
  // place; an unsafe target becomes a harmless anchor.
  LSanitizer := TKXUrlAttributeSanitizer.Create;
  try
    Result := TRegEx.Replace(AHtml, '(\b(?:href|src)\s*=\s*)("[^"]*"|''[^'']*'')',
      LSanitizer.Evaluate, [roIgnoreCase]);
  finally
    LSanitizer.Free;
  end;
end;

// Renders the assistant's Markdown reply to a safe HTML fragment using Ethea's
// MarkdownProcessor (vendored under Source\ThirdParty\MarkdownProcessor):
// CommonMark dialect in safe mode (AllowUnsafe = False), so active HTML
// (script/iframe/object/applet/frame...) is escaped and AI-produced content
// cannot inject markup. Safe mode does NOT restrict link targets, though:
// [x](javascript:alert(1)) is valid CommonMark and comes out as a live anchor,
// so the rendered fragment is passed through KXChatSanitizeUrls. Tolerant of
// partial input, so it also renders the growing partial while a streaming
// provider is still producing the reply. On any error it falls back to plain
// HTML-encoded text.
function KXChatMarkdownToSafeHtml(const AMarkdown: string): string;
var
  LProcessor: TMarkdownProcessor;
begin
  if Trim(AMarkdown) = '' then
    Exit('');
  try
    LProcessor := TMarkdownProcessor.CreateDialect(mdCommonMark);
    try
      LProcessor.AllowUnsafe := False;
      Result := KXChatSanitizeUrls(LProcessor.Process(AMarkdown));
    finally
      LProcessor.Free;
    end;
  except
    on E: Exception do
      Result := KXChatTextToHtml(AMarkdown);
  end;
end;

// Renders one message as a chat bubble. A pending assistant message shows a
// typing indicator instead of text; an error message gets the error class.
function RenderBubble(const AMessage: TKXChatMessage): string;
var
  LExtra, LBody: string;
begin
  LExtra := '';
  if AMessage.Pending then
  begin
    // The client keeps polling while data-pending is set. A streaming provider
    // fills Content token by token: show the partial reply (same restricted
    // markdown as the final bubble) once there is any text, otherwise the
    // typing indicator.
    LExtra := ' data-pending="1"';
    if AMessage.Content <> '' then
      LBody := KXChatMarkdownToSafeHtml(AMessage.Content)
    else
      LBody := '<span class="kx-chat-typing"><span></span><span></span><span></span></span>';
  end
  else if AMessage.IsError then
  begin
    LExtra := ' data-error="1"';
    LBody := KXChatTextToHtml(AMessage.Content);
  end
  else if AMessage.Role = crAssistant then
    // Completed assistant reply: render its Markdown as safe HTML.
    LBody := KXChatMarkdownToSafeHtml(AMessage.Content)
  else
    LBody := KXChatTextToHtml(AMessage.Content);

  Result :=
    '<div class="kx-chat-msg kx-chat-' + RoleToClass(AMessage.Role) +
      IfThen(AMessage.IsError, ' kx-chat-msg-error', '') + '"' +
      ' data-msgid="' + AMessage.Id + '"' + LExtra + '>' +
      '<div class="kx-chat-bubble">' + LBody + '</div>' +
    '</div>';
end;

// Which assistant answers a chat opened from AViewName: the view says so with
// its own HelpChatProfile node, and says nothing in an application that
// declares one assistant - which is the usual case.
//
// It is read from the metadata and not from the request: the client says which
// screen it is on, as it does for the context, and what that screen means is
// decided here. A name that is not declared falls back to the assistant at the
// root rather than being refused: a typo in a view must not take the help away.
function ProfileOfView(const AViewName: string): string;
var
  LView: TKView;
begin
  Result := '';
  if AViewName = '' then
    Exit;
  LView := TKConfig.Instance.Views.FindView(AViewName);
  if Assigned(LView) then
    Result := LView.GetString('HelpChatProfile');
  if not KXChatIsProfile(Result) then
    Result := '';
end;

// The assistant the panel says it is talking to. It comes back from the client,
// which got it from the panel endpoint, because the screen may well have
// changed since - and a reply must not get lost because the user clicked
// another tab while it was being written.
//
// Trusting the client here is deliberate and bounded: a profile is not a
// permission. It names which expert answers out of the ones this application
// declares, and all of them read the same public manual; a value that is not
// declared is simply the root one. Nothing of a view's own authorization rides
// on it.
function RequestedProfile: string;
begin
  Result := Trim(TKWebRequest.Current.GetField('profile'));
  if not KXChatIsProfile(Result) then
    Result := '';
end;

// The identity of the assistant, for the header of the panel: it travels with
// the conversation and not with the page, because the page is loaded once and
// the assistant depends on where the chat was opened from.
function IdentityHtml(const AProfile: string): string;
begin
  Result := '<span class="kx-chat-ident" hidden data-profile="' +
    TNetEncoding.HTML.Encode(AProfile) + '" data-name="' +
    TNetEncoding.HTML.Encode(KXChatPromptField(
      KXChatSetting(AProfile, 'AssistantName', _('Help')))) + '"></span>';
end;

// The bar of the attachments: one chip per file, with its name, its size and
// the button that drops it, plus the reason of a refusal when there is one.
// Empty - no element at all - when there is nothing to show: the stylesheet
// hides an empty bar, so the composer does not grow a blank strip.
function RenderAttachmentBar(const AUser, AError: string): string;
var
  LItems: TArray<TKXChatAttachment>;
  LSb: TStringBuilder;
  I: Integer;
begin
  LItems := TKXChatAttachments.Instance.ItemsOf(AUser);
  if (Length(LItems) = 0) and (AError = '') then
    Exit('');

  LSb := TStringBuilder.Create;
  try
    for I := Low(LItems) to High(LItems) do
    begin
      LSb.Append('<span class="kx-chat-att" data-id="')
        .Append(TNetEncoding.HTML.Encode(LItems[I].Id)).Append('">');
      LSb.Append('<span class="kx-chat-att-name" title="')
        .Append(TNetEncoding.HTML.Encode(LItems[I].FileName)).Append('">')
        .Append(TNetEncoding.HTML.Encode(LItems[I].FileName)).Append('</span>');
      LSb.Append('<span class="kx-chat-att-size">')
        .Append(TNetEncoding.HTML.Encode(KXChatFormatSize(LItems[I].OriginalSize))).Append('</span>');
      LSb.Append('<button type="button" class="kx-chat-att-del" data-id="')
        .Append(TNetEncoding.HTML.Encode(LItems[I].Id)).Append('" title="')
        .Append(TNetEncoding.HTML.Encode(_('Remove'))).Append('">&times;</button>');
      LSb.Append('</span>');
    end;
    if AError <> '' then
      LSb.Append('<span class="kx-chat-att-error">')
        .Append(TNetEncoding.HTML.Encode(AError)).Append('</span>');
    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

function GreetingHtml(const AProfile: string): string;
var
  LGreeting: string;
begin
  // NB: keep the literal here (not KX_HELPCHAT_DEF_GREETING) so dxgettext can
  // extract it for translation. The constant carries the same text and is used
  // by the config class, the [YamlNode] default and the KIDE frame.
  LGreeting := KXChatSetting(AProfile, 'Greeting',
    _('Hi! Ask me anything about how to use the application.'));
  Result :=
    '<div class="kx-chat-msg kx-chat-assistant kx-chat-greeting">' +
      '<div class="kx-chat-bubble">' + KXChatTextToHtml(LGreeting) + '</div>' +
    '</div>';
end;

function RenderHistory(const AKey, AProfile: string): string;
var
  LMessages: TArray<TKXChatMessage>;
  LMessage: TKXChatMessage;
begin
  LMessages := TKXChatStore.Instance.GetMessages(AKey);
  if Length(LMessages) = 0 then
    Exit(GreetingHtml(AProfile));
  Result := '';
  for LMessage in LMessages do
    Result := Result + RenderBubble(LMessage);
end;

procedure WritePartial(const AHtml: string);
begin
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(AHtml);
  TKWebResponse.Current.ContentType := 'text/html; charset=utf-8';
end;

// --- the printable document -------------------------------------------------
// Not the panel: a document. It knows nothing of bubbles, of the theme of the
// application or of its stylesheet - it carries its own, black on white, and
// stands on its own with no resource to fetch. The browser prints it, and from
// the same dialog saves it as PDF.
const
  PRINT_CSS =
    'html,body{margin:0;padding:0;background:#fff;color:#1a1a1a}' +
    'body{font-family:"Segoe UI","Segoe UI Variable",system-ui,-apple-system,sans-serif;' +
      'font-size:10.5pt;line-height:1.55;padding:18mm 16mm}' +
    '.kx-doc-head{border-bottom:1.5pt solid #555;padding-bottom:6pt;margin-bottom:14pt}' +
    '.kx-doc-head h1{margin:0;font-size:18pt;line-height:1.25}' +
    '.kx-doc-meta{margin-top:3pt;font-size:8.5pt;color:#5c6660}' +
    '.kx-doc-turn{margin:0 0 12pt 0;page-break-inside:avoid}' +
    '.kx-doc-who{margin:0 0 2pt 0;font-size:9pt;font-weight:600;color:#444;' +
      'text-transform:uppercase;letter-spacing:.04em}' +
    '.kx-doc-text{margin:0;padding-left:8pt;border-left:2pt solid #ddd}' +
    '.kx-doc-text > :first-child{margin-top:0}' +
    '.kx-doc-text > :last-child{margin-bottom:0}' +
    '.kx-doc-text p{margin:.35em 0}' +
    '.kx-doc-text ul,.kx-doc-text ol{margin:.3em 0;padding-left:1.5em}' +
    '.kx-doc-text code{font-family:ui-monospace,Consolas,monospace;font-size:.92em}' +
    '.kx-doc-text pre{padding:6pt 8pt;background:#f4f4f4;border-radius:3pt;' +
      'white-space:pre-wrap;word-wrap:break-word}' +
    '.kx-doc-text table{border-collapse:collapse;margin:.4em 0}' +
    '.kx-doc-text th,.kx-doc-text td{border:.5pt solid #bbb;padding:3pt 6pt;' +
      'font-size:9.5pt;text-align:left}' +
    '.kx-doc-text a{color:#1a4f8a}' +
    '.kx-doc-empty{color:#777;font-style:italic}' +
    '@media print{body{padding:0}a{text-decoration:none}}';

// One turn of the conversation. The pending reply and the errors are left out:
// a document records what was said, not what was being written.
function PrintableTurn(const AMessage: TKXChatMessage; const AUserLabel, AAssistantLabel: string): string;
var
  LWho, LBody: string;
begin
  if AMessage.Pending or AMessage.IsError or (Trim(AMessage.Content) = '') then
    Exit('');
  if AMessage.Role = crUser then
  begin
    LWho := AUserLabel;
    LBody := KXChatTextToHtml(AMessage.Content);
  end
  else
  begin
    LWho := AAssistantLabel;
    LBody := KXChatMarkdownToSafeHtml(AMessage.Content);
  end;
  Result :=
    '<section class="kx-doc-turn">' +
      '<p class="kx-doc-who">' + TNetEncoding.HTML.Encode(LWho) + '</p>' +
      '<div class="kx-doc-text">' + LBody + '</div>' +
    '</section>';
end;

function PrintableDocument(const AUser: string): string;
var
  LMessages: TArray<TKXChatMessage>;
  LMessage: TKXChatMessage;
  LTitle, LAssistant, LBody, LMeta: string;
begin
  // NB: the literal default of the name is repeated here (not the constant) so
  // dxgettext can extract it, as at the other use sites.
  LAssistant := TKConfig.Instance.Config.GetExpandedString('HelpChat/AssistantName', _('Help'));
  if Trim(LAssistant) = '' then
    LAssistant := _('Help');
  LTitle := Format('%s - %s', [TKConfig.Instance.AppTitle, LAssistant]);

  LBody := '';
  LMessages := TKXChatStore.Instance.GetMessages(AUser);
  for LMessage in LMessages do
    LBody := LBody + PrintableTurn(LMessage, _('Question'), LAssistant);
  if LBody = '' then
    LBody := '<p class="kx-doc-empty">' + TNetEncoding.HTML.Encode(_('There is nothing to print yet.')) + '</p>';

  LMeta := Format(_('%0:s - printed on %1:s'),
    [AUser, FormatDateTime('dddd, d mmmm yyyy, hh:nn', Now)]);

  Result :=
    '<!DOCTYPE html><html><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">' +
    '<title>' + TNetEncoding.HTML.Encode(LTitle) + '</title>' +
    '<style>' + PRINT_CSS + '</style></head><body>' +
    '<div class="kx-doc-head"><h1>' + TNetEncoding.HTML.Encode(LTitle) + '</h1>' +
    '<div class="kx-doc-meta">' + TNetEncoding.HTML.Encode(LMeta) + '</div></div>' +
    LBody +
    // The dialog opens by itself: the button said print. Cancelling it leaves
    // the document on the screen, which is a fair second use of the page.
    '<script>window.addEventListener("load",function(){window.print();});</script>' +
    '</body></html>';
end;

{ TKXChatHandler }

procedure TKXChatHandler.HandlePanel;
var
  LProfile: string;
begin
  // Opening is the one moment the screen decides: from here on the panel says
  // which assistant it is talking to, and the identity travels with the
  // conversation.
  LProfile := ProfileOfView(Trim(TKWebRequest.Current.GetField('viewName')));
  WritePartial(IdentityHtml(LProfile) +
    RenderHistory(KXChatConversationKey(TKAuthenticator.Current.UserName, LProfile),
      LProfile));
end;

procedure TKXChatHandler.HandleSend;
var
  LUser, LKey, LProfile, LText, LViewName, LControllerType: string;
  LView: TKView;
  LMaxLen: Integer;
  LUserMessage, LAssistantMessage: TKXChatMessage;
  LAssistantId: string;
  LContext: TKXChatContext;
begin
  LUser := TKAuthenticator.Current.UserName;
  LProfile := RequestedProfile;
  LKey := KXChatConversationKey(LUser, LProfile);
  LText := Trim(TKWebRequest.Current.GetContentFields.Values['message']);
  LViewName := Trim(TKWebRequest.Current.GetContentFields.Values['viewName']);
  LControllerType := Trim(TKWebRequest.Current.GetContentFields.Values['controllerType']);

  LMaxLen := KXChatSettingInteger(LProfile, 'MessageMaxLength', KX_HELPCHAT_DEF_MSGMAXLEN);
  if (LText = '') then
  begin
    WritePartial('');
    Exit;
  end;
  if (LMaxLen > 0) and (Length(LText) > LMaxLen) then
    LText := Copy(LText, 1, LMaxLen);

  // Record the user message and a pending assistant placeholder, then hand the
  // provider call to the runner (off the request thread).
  LUserMessage := TKXChatStore.Instance.AddUserMessage(LKey, LText);
  LAssistantId := TKXChatStore.Instance.AddPendingAssistant(LKey);

  LContext := Default(TKXChatContext);
  LContext.UserName := LUser;
  LContext.Profile := LProfile;
  // Read here and carried along: the reply is produced on a worker, and a
  // session is thread-local. It is what the prompt names as the language of the
  // chat.
  LContext.Language := TKXLanguageCatalog.NormalizeCode(TKWebSession.Current.Language);
  LContext.ViewName := LViewName;
  LContext.ControllerType := LControllerType;
  // The client says which screen it is on, nothing more: label and controller
  // type are read here from the metadata. Trusting the client for those would
  // mean answering about a screen the user may not even be allowed to see.
  if LViewName <> '' then
  begin
    LView := TKConfig.Instance.Views.FindView(LViewName);
    if Assigned(LView) then
    begin
      LContext.ViewLabel := LView.DisplayLabel;
      if LContext.ControllerType = '' then
        LContext.ControllerType := LView.GetString('Controller');
    end;
  end;

  // A copy, taken here: the user may drop a file while the reply is being
  // written, and a request answers against what it was given. They belong to
  // the conversation, so they travel again with every later question.
  if KXChatAttachmentsEnabled then
    LContext.Attachments := TKXChatAttachments.Instance.ItemsOf(LKey);

  // The provider too is read through the profile: one assistant may be answered
  // by Claude and another by an OpenAI-compatible service.
  TKXChatRunner.Instance.Submit(LKey, LAssistantId,
    KXChatSettingRaw(LProfile, 'Provider', KX_CHAT_PROVIDER_STUB),
    LContext, KXChatSettingInteger(LProfile, 'HistoryMaxMessages',
      KX_HELPCHAT_DEF_HISTMAXMSG));

  // Return both bubbles: the user message and the pending assistant placeholder
  // (the client starts polling the latter by its id).
  TKXChatStore.Instance.TryGetMessage(LKey, LAssistantId, LAssistantMessage);
  WritePartial(RenderBubble(LUserMessage) + RenderBubble(LAssistantMessage));
end;

procedure TKXChatHandler.HandlePoll(const AMsgId: string);
var
  LMessage: TKXChatMessage;
begin
  if TKXChatStore.Instance.TryGetMessage(
    KXChatConversationKey(TKAuthenticator.Current.UserName, RequestedProfile),
    AMsgId, LMessage) then
    WritePartial(RenderBubble(LMessage))
  else
    WritePartial('');
end;

procedure TKXChatHandler.HandleCancel(const AMsgId: string);
var
  LUser: string;
  LMessage: TKXChatMessage;
begin
  LUser := KXChatConversationKey(TKAuthenticator.Current.UserName, RequestedProfile);
  TKXChatRunner.Instance.Cancel(LUser, AMsgId);
  // The bubble goes back whatever the outcome: if the provider noticed at once
  // the client sees it closed, otherwise its next poll will.
  if TKXChatStore.Instance.TryGetMessage(LUser, AMsgId, LMessage) then
    WritePartial(RenderBubble(LMessage))
  else
    WritePartial('');
end;

procedure TKXChatHandler.HandleClear;
var
  LUser, LProfile: string;
begin
  LProfile := RequestedProfile;
  LUser := KXChatConversationKey(TKAuthenticator.Current.UserName, LProfile);
  TKXChatStore.Instance.Clear(LUser);
  // The attachments go with the conversation they belonged to. It is the one
  // place where the two are tied, and it is the only way the user has to take
  // back everything that was sent out.
  TKXChatAttachments.Instance.ClearUser(LUser);
  WritePartial(GreetingHtml(LProfile));
end;

procedure TKXChatHandler.HandleAttach;
var
  LUser, LError: string;
  LLimits: TKXChatAttachmentLimits;
  LData: TBytes;
  LStream: TStream;
  LAttachment: TKXChatAttachment;
  LDeclared: Int64;
begin
  LUser := KXChatConversationKey(TKAuthenticator.Current.UserName, RequestedProfile);
  if not KXChatAttachmentsEnabled then
  begin
    // Not an error of the user's making: the endpoint exists whatever the
    // configuration says, and says no when the application has not opted in.
    WritePartial(RenderAttachmentBar(LUser,
      _('Attachments are not enabled for this application.')));
    Exit;
  end;

  LLimits := KXChatAttachmentLimits;

  // What the request declares, refused before the body is touched. The bytes
  // have already arrived by now - the host parses the multipart body before a
  // handler sees it - but nothing of them is read or kept. The slack is the
  // framing of the multipart envelope, which is not part of the file.
  LDeclared := StrToInt64Def(TKWebRequest.Current.GetHeaderField('Content-Length'), 0);
  if (LLimits.MaxSizeBytes > 0) and (LDeclared > LLimits.MaxSizeBytes + 64 * 1024) then
  begin
    WritePartial(RenderAttachmentBar(LUser,
      Format(_('That file is too large: the limit is %s.'),
        [KXChatFormatSize(LLimits.MaxSizeBytes)])));
    Exit;
  end;

  if TKWebRequest.Current.Files.Count = 0 then
  begin
    WritePartial(RenderAttachmentBar(LUser, _('No file was sent.')));
    Exit;
  end;

  LStream := TKWebRequest.Current.Files[0].Stream;
  LStream.Position := 0;
  SetLength(LData, LStream.Size);
  if Length(LData) > 0 then
    LStream.ReadBuffer(LData[0], Length(LData));

  if TKXChatAttachments.Instance.TryAdd(LUser, TKWebRequest.Current.Files[0].FileName,
    LData, LLimits, LAttachment, LError)
  then
    WritePartial(RenderAttachmentBar(LUser, ''))
  else
    WritePartial(RenderAttachmentBar(LUser, LError));
end;

procedure TKXChatHandler.HandleAttachRemove(const AAttId: string);
var
  LUser: string;
begin
  LUser := KXChatConversationKey(TKAuthenticator.Current.UserName, RequestedProfile);
  // Nothing is said when the id is not there: the bar that comes back is the
  // truth, whatever the client believed.
  TKXChatAttachments.Instance.Remove(LUser, AAttId);
  WritePartial(RenderAttachmentBar(LUser, ''));
end;

procedure TKXChatHandler.HandleAttachments;
begin
  WritePartial(RenderAttachmentBar(
    KXChatConversationKey(TKAuthenticator.Current.UserName, RequestedProfile), ''));
end;

procedure TKXChatHandler.HandleLangs;
begin
  // The switcher of the application, rendered where the panel wants it. Reusing
  // it means one list of languages, one validated endpoint (kx/setlang) and one
  // behaviour: the page reloads and everything speaks the new language.
  WritePartial(TKXLanguageCatalog.RenderSwitcherHtml('kx-chat-lang'));
end;

procedure TKXChatHandler.HandlePrint;
begin
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(PrintableDocument(TKAuthenticator.Current.UserName));
  TKWebResponse.Current.ContentType := 'text/html; charset=utf-8';
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXChatHandler);
  // Signals to the core that the Help Chat subsystem is linked, so the startup
  // guard can tell an app that enabled HelpChat but forgot to add this unit (and
  // a provider) to its UseKitto.pas.
  TKXOptionalFeatureRegistry.Declare('HelpChat');

finalization
  TKXResourceRegistry.Instance.UnregisterResource(TKXChatHandler);

end.
