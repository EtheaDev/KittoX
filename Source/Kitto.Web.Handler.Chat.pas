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
///  and a conversation reset. Requires an authenticated user; all responses are
///  HTML fragments requested by htmx/fetch (with the X-KittoX header), so the
///  navigation guard leaves them alone and no [TKXNavigable] is needed.
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

    /// <summary>Clears the current user's conversation and returns the greeting.</summary>
    [TKXPath('/clear')]
    [TKXPOST]
    procedure HandleClear;
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
  System.StrUtils,
  System.NetEncoding,
  System.RegularExpressions,
  EF.Tree,
  EF.Localization,
  Kitto.Auth,
  Kitto.Config,
  Kitto.Web.Request,
  Kitto.Web.Response,
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

function GreetingHtml: string;
var
  LGreeting: string;
begin
  // NB: keep the literal here (not KX_HELPCHAT_DEF_GREETING) so dxgettext can
  // extract it for translation. The constant carries the same text and is used
  // by the config class, the [YamlNode] default and the KIDE frame.
  LGreeting := TKConfig.Instance.Config.GetExpandedString('HelpChat/Greeting',
    _('Hi! Ask me anything about how to use the application.'));
  Result :=
    '<div class="kx-chat-msg kx-chat-assistant kx-chat-greeting">' +
      '<div class="kx-chat-bubble">' + KXChatTextToHtml(LGreeting) + '</div>' +
    '</div>';
end;

function RenderHistory(const AUser: string): string;
var
  LMessages: TArray<TKXChatMessage>;
  LMessage: TKXChatMessage;
begin
  LMessages := TKXChatStore.Instance.GetMessages(AUser);
  if Length(LMessages) = 0 then
    Exit(GreetingHtml);
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

{ TKXChatHandler }

procedure TKXChatHandler.HandlePanel;
begin
  WritePartial(RenderHistory(TKAuthenticator.Current.UserName));
end;

procedure TKXChatHandler.HandleSend;
var
  LUser, LText, LViewName, LControllerType: string;
  LConfig: TEFTree;
  LMaxLen: Integer;
  LUserMessage, LAssistantMessage: TKXChatMessage;
  LAssistantId: string;
  LContext: TKXChatContext;
begin
  LUser := TKAuthenticator.Current.UserName;
  LText := Trim(TKWebRequest.Current.GetContentFields.Values['message']);
  LViewName := Trim(TKWebRequest.Current.GetContentFields.Values['viewName']);
  LControllerType := Trim(TKWebRequest.Current.GetContentFields.Values['controllerType']);

  LConfig := TKConfig.Instance.Config;
  LMaxLen := LConfig.GetInteger('HelpChat/MessageMaxLength', KX_HELPCHAT_DEF_MSGMAXLEN);
  if (LText = '') then
  begin
    WritePartial('');
    Exit;
  end;
  if (LMaxLen > 0) and (Length(LText) > LMaxLen) then
    LText := Copy(LText, 1, LMaxLen);

  // Record the user message and a pending assistant placeholder, then hand the
  // provider call to the runner (off the request thread).
  LUserMessage := TKXChatStore.Instance.AddUserMessage(LUser, LText);
  LAssistantId := TKXChatStore.Instance.AddPendingAssistant(LUser);

  LContext := Default(TKXChatContext);
  LContext.UserName := LUser;
  LContext.ViewName := LViewName;
  LContext.ControllerType := LControllerType;

  TKXChatRunner.Instance.Submit(LUser, LAssistantId,
    LConfig.GetString('HelpChat/Provider', KX_CHAT_PROVIDER_STUB),
    LContext, LConfig.GetInteger('HelpChat/HistoryMaxMessages', KX_HELPCHAT_DEF_HISTMAXMSG));

  // Return both bubbles: the user message and the pending assistant placeholder
  // (the client starts polling the latter by its id).
  TKXChatStore.Instance.TryGetMessage(LUser, LAssistantId, LAssistantMessage);
  WritePartial(RenderBubble(LUserMessage) + RenderBubble(LAssistantMessage));
end;

procedure TKXChatHandler.HandlePoll(const AMsgId: string);
var
  LMessage: TKXChatMessage;
begin
  if TKXChatStore.Instance.TryGetMessage(TKAuthenticator.Current.UserName, AMsgId, LMessage) then
    WritePartial(RenderBubble(LMessage))
  else
    WritePartial('');
end;

procedure TKXChatHandler.HandleClear;
begin
  TKXChatStore.Instance.Clear(TKAuthenticator.Current.UserName);
  WritePartial(GreetingHtml);
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
