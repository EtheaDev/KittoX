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
///  Claude-backed help-chat provider (name <c>claude</c>). It sends the
///  conversation to Anthropic's Messages API (<c>POST /v1/messages</c>) with
///  <c>stream: true</c> and forwards each token to the runner via the
///  <c>AOnToken</c> callback as it arrives, so the poll endpoint returns the
///  growing partial reply and the drawer fills in incrementally with no
///  server-push (SSE-to-the-browser) machinery — the existing 1.2s client poll
///  is enough. There is no official Anthropic SDK for Delphi, so the call is
///  made with <c>System.Net.HttpClient</c> and the Anthropic Server-Sent-Events
///  response is parsed by <see cref="TKXAnthropicStream" /> as bytes arrive.
///
///  Answers are grounded on the bundled documentation index (RAG): the pages
///  best matching the question are injected into the system prompt via
///  <see cref="KXSearchHelpPages" /> so the model answers from the real docs and
///  cites the published page instead of inventing details.
///
///  Configuration (Config.yaml, all under <c>HelpChat/Claude/</c>):
///  <code>
///  HelpChat:
///    Provider: claude
///    Claude:
///      ApiKey: %ENV(ANTHROPIC_API_KEY)%   # or the key directly; env var is the fallback
///      Model: claude-haiku-4-5            # default
///      MaxTokens: 1024
///      Version: 2023-06-01                # anthropic-version header
///      BaseUrl: https://api.anthropic.com
///      GroundingMaxPages: 3               # doc pages injected as context (0 = off)
///      SystemPrompt: ''                   # optional override of the base instruction
///      ConnectTimeoutMs: 15000
///      ResponseTimeoutMs: 120000
///  </code>
///  The API key is read from <c>HelpChat/Claude/ApiKey</c> (macro-expanded, so
///  <c>%ENV(...)%</c> works) and falls back to the <c>ANTHROPIC_API_KEY</c>
///  environment variable. When neither is set the provider raises a clear
///  configuration error (surfaced in the chat as an error bubble).
/// </summary>
unit Kitto.Chat.Provider.Claude;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Chat.Provider;

const
  // Claude provider default values — single source of truth, shared by the reader
  // below (getter defaults), its [YamlNode] attributes and the KIDE frame.
  KX_CLAUDE_DEF_MODEL = 'claude-haiku-4-5';
  KX_CLAUDE_DEF_MAXTOKENS = 1024;
  KX_CLAUDE_DEF_GROUNDING = 3;
  KX_CLAUDE_DEF_VERSION = '2023-06-01';
  KX_CLAUDE_DEF_BASEURL = 'https://api.anthropic.com';
  KX_CLAUDE_DEF_CONNECTTIMEOUTMS = 15000;
  KX_CLAUDE_DEF_RESPONSETIMEOUTMS = 120000;

type
  /// <summary>
  ///  Typed reader for the Claude help-chat provider settings (Provider: claude).
  ///  Two roles in one class, co-located with the provider it configures:
  ///   (1) runtime — reads every HelpChat/Claude/* value ONCE at construction into
  ///       fields, so the provider accesses them as FConfig.Model instead of
  ///       repeated Config.GetString/GetInteger tree lookups;
  ///   (2) design-time — the [YamlNode] attributes let KIDE discover the schema via
  ///       RTTI, and the class-level [YamlConfigNode('HelpChat/Claude')] binds it to
  ///       that YAML node WITHOUT the parent config class referencing it by type
  ///       (KIDE finds it by scanning the linked types). It is a plain reader
  ///       (not a TEFNode): it reads from the config tree, it does not live in it.
  /// </summary>
  /// <example>
  ///  HelpChat:
  ///    Provider: claude
  ///    Claude:
  ///      ApiKey: %ENV(ANTHROPIC_API_KEY)%
  ///      Model: claude-haiku-4-5
  ///      MaxTokens: 1024
  ///      GroundingMaxPages: 3
  /// </example>
  [YamlConfigNode('HelpChat/Claude')]
  TKClaudeProviderConfig = class
  private
    FApiKey: string;
    FModel: string;
    FMaxTokens: Integer;
    FGroundingMaxPages: Integer;
    FSystemPrompt: string;
    FBaseUrl: string;
    FVersion: string;
    FConnectTimeoutMs: Integer;
    FResponseTimeoutMs: Integer;
  public
    /// <summary>Reads HelpChat/Claude/* from AConfig once. ApiKey is macro-expanded
    /// and falls back to the ANTHROPIC_API_KEY env var when empty; BaseUrl is
    /// normalized (no trailing slash); SystemPrompt is the raw override ('' means
    /// the provider applies its localized default). AConfig is normally
    /// TKConfig.Instance.Config.</summary>
    constructor Create(const AConfig: TEFTree; const AProfile: string = '');

    [YamlNode('ApiKey', 'Anthropic API key. Supports %ENV(ANTHROPIC_API_KEY)%; falls back to the ANTHROPIC_API_KEY env var when empty')]
    property ApiKey: string read FApiKey;

    [YamlNode('Model', KX_CLAUDE_DEF_MODEL, 'Claude model id')]
    property Model: string read FModel;

    [YamlNode('MaxTokens', KX_CLAUDE_DEF_MAXTOKENS, 'Maximum tokens in the assistant reply')]
    property MaxTokens: Integer read FMaxTokens;

    [YamlNode('GroundingMaxPages', KX_CLAUDE_DEF_GROUNDING, 'Documentation pages injected as RAG context (0 = off)')]
    property GroundingMaxPages: Integer read FGroundingMaxPages;

    [YamlNode('SystemPrompt', 'System prompt override (empty = framework default)', True)]
    property SystemPrompt: string read FSystemPrompt;

    [YamlNode('BaseUrl', KX_CLAUDE_DEF_BASEURL, 'Anthropic API base URL')]
    property BaseUrl: string read FBaseUrl;

    [YamlNode('Version', KX_CLAUDE_DEF_VERSION, 'Value of the anthropic-version header')]
    property Version: string read FVersion;

    [YamlNode('ConnectTimeoutMs', KX_CLAUDE_DEF_CONNECTTIMEOUTMS, 'HTTP connect timeout in milliseconds')]
    property ConnectTimeoutMs: Integer read FConnectTimeoutMs;

    [YamlNode('ResponseTimeoutMs', KX_CLAUDE_DEF_RESPONSETIMEOUTMS, 'HTTP response timeout in milliseconds')]
    property ResponseTimeoutMs: Integer read FResponseTimeoutMs;
  end;

  /// <summary>Streams assistant replies from Anthropic's Claude Messages API.</summary>
  TKXClaudeProvider = class(TKXChatProviderBase)
  private
    FConfig: TKClaudeProviderConfig;
  public
    /// <summary>Reads the HelpChat/Claude/* config once (the provider is created
    /// per chat request), so Generate accesses typed fields instead of the tree.</summary>
    constructor Create; override;
    destructor Destroy; override;
    function GetName: string; override;
    function SupportsStreaming: Boolean; override;
    function CompleteText(const APrompt: string; const AMaxTokens: Integer;
      const ACancel: IKXChatCancelToken): string; override;
    procedure Configure(const AProfile: string); override;
    function Generate(const AHistory: TArray<TKXChatMessage>;
      const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc;
      const ACancel: IKXChatCancelToken): string; override;
  end;

const
  /// <summary>Name of the Claude help-chat provider.</summary>
  KX_CHAT_PROVIDER_CLAUDE = 'claude';

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.StrUtils,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  EF.Localization,
  EF.Logger,
  Kitto.Config,
  Kitto.Chat.Attachments,
  Kitto.Chat.Prompt,
  Kitto.Chat.Stream,
  Kitto.Chat.DocSearch;

type
  /// <summary>
  ///  Write-only TStream that receives the Anthropic SSE response body as it is
  ///  streamed by THTTPClient and parses it incrementally. It accumulates raw
  ///  bytes, splits on newlines, and for each complete <c>data:</c> line decodes
  ///  the JSON event; on a <c>content_block_delta</c> / <c>text_delta</c> it
  ///  appends the token to the running text and invokes the token callback. The
  ///  full decoded body is also kept so a non-SSE error response (HTTP >= 400
  ///  returns a plain JSON error, not a stream) can be reported.
  /// </summary>
  /// <summary>
  ///  The sink of the Anthropic stream: the machinery is the shared one, what
  ///  is Anthropic's is the shape of the events - a content_block_delta
  ///  carrying a text_delta, and an error event.
  /// </summary>
  TKXAnthropicStream = class(TKXChatSSEStream)
  protected
    procedure ProcessLine(const ALine: string); override;
  end;
{ TKXAnthropicStream }










procedure TKXAnthropicStream.ProcessLine(const ALine: string);
var
  LData: string;
  LRoot, LDelta, LErr: TJSONObject;
  LType: string;
begin
  // Only SSE payload lines matter; ignore "event:" lines and blank separators.
  if not ALine.StartsWith('data:') then
    Exit;
  LData := Trim(System.Copy(ALine, 6, MaxInt)); // after 'data:'
  if (LData = '') or (LData = '[DONE]') then
    Exit;

  try
    LRoot := TJSONObject.ParseJSONValue(LData) as TJSONObject;
  except
    LRoot := nil; // ignore a malformed fragment rather than fail the whole reply
  end;
  if LRoot = nil then
    Exit;
  try
    LType := LRoot.GetValue<string>('type', '');
    if LType = 'content_block_delta' then
    begin
      LDelta := LRoot.GetValue('delta') as TJSONObject;
      if (LDelta <> nil) and (LDelta.GetValue<string>('type', '') = 'text_delta') then
      begin
        Emit(LDelta.GetValue<string>('text', ''));
      end;
    end
    else if LType = 'error' then
    begin
      LErr := LRoot.GetValue('error') as TJSONObject;
      if LErr <> nil then
        Fail(LErr.GetValue<string>('message', _('The AI provider returned an error.')))
      else
        Fail(_('The AI provider returned an error.'));
    end;
  finally
    LRoot.Free;
  end;
end;

{ Helpers }



// The content of the user turn the attachments belong to: a document block per
// PDF, an image block per picture, and the text last - the order Anthropic
// recommends, because a question read after its documents is answered against
// them. A text attachment is not a block: it was decoded when it arrived and is
// already part of that text. The caller owns the array.
function BuildUserContent(const AText: string;
  const AAttachments: TArray<TKXChatAttachment>): TJSONArray;
var
  LBlock, LSource: TJSONObject;
  I: Integer;
begin
  Result := TJSONArray.Create;
  try
    for I := Low(AAttachments) to High(AAttachments) do
    begin
      if (AAttachments[I].Kind = cakText) or (Length(AAttachments[I].Data) = 0) then
        Continue;
      LSource := TJSONObject.Create;
      LSource.AddPair('type', 'base64');
      LSource.AddPair('media_type', AAttachments[I].MediaType);
      LSource.AddPair('data', AAttachments[I].Base64);
      LBlock := TJSONObject.Create;
      if AAttachments[I].Kind = cakImage then
        LBlock.AddPair('type', 'image')
      else
      begin
        LBlock.AddPair('type', 'document');
        // Not part of the API for an image, and useful on a document: the model
        // quotes the name back when it says where a value came from, and with
        // two invoices attached that is the only way the user tells the two
        // answers apart.
        LBlock.AddPair('title', AAttachments[I].FileName);
      end;
      LBlock.AddPair('source', LSource);
      Result.AddElement(LBlock);
    end;

    LBlock := TJSONObject.Create;
    LBlock.AddPair('type', 'text');
    LBlock.AddPair('text', KXChatQuestionWithText(AText, AAttachments));
    Result.AddElement(LBlock);
  except
    Result.Free;
    raise;
  end;
end;


// Extracts a human-readable message from a non-2xx Anthropic response body.
function ExtractApiError(const ARaw: string; const AStatus: Integer;
  const AStatusText: string): string;
var
  LRoot, LErr: TJSONObject;
begin
  Result := '';
  if Trim(ARaw) <> '' then
  begin
    try
      LRoot := TJSONObject.ParseJSONValue(Trim(ARaw)) as TJSONObject;
    except
      LRoot := nil;
    end;
    if LRoot <> nil then
      try
        LErr := LRoot.GetValue('error') as TJSONObject;
        if LErr <> nil then
          Result := LErr.GetValue<string>('message', '');
      finally
        LRoot.Free;
      end;
  end;
  if Result = '' then
    Result := Format(_('Claude API error (HTTP %d %s).'), [AStatus, AStatusText]);
end;

{ TKClaudeProviderConfig }

constructor TKClaudeProviderConfig.Create(const AConfig: TEFTree;
  const AProfile: string);
const
  PFX = 'Claude/';
begin
  inherited Create;
  // Every value is read through the profile: HelpChat/Profiles/<p>/Claude/X
  // when that node exists, HelpChat/Claude/X otherwise. An assistant may
  // therefore be answered by another model, with another key and another
  // endpoint, without a second copy of everything else.
  // ApiKey: macro-expanded (so %ENV(...)% works), env-var fallback when empty.
  FApiKey := Trim(KXChatSetting(AProfile, PFX + 'ApiKey'));
  if FApiKey = '' then
    FApiKey := Trim(GetEnvironmentVariable('ANTHROPIC_API_KEY'));
  FModel := KXChatSettingRaw(AProfile, PFX + 'Model', KX_CLAUDE_DEF_MODEL);
  FMaxTokens := KXChatSettingInteger(AProfile, PFX + 'MaxTokens', KX_CLAUDE_DEF_MAXTOKENS);
  FGroundingMaxPages := KXChatSettingInteger(AProfile, PFX + 'GroundingMaxPages', KX_CLAUDE_DEF_GROUNDING);
  // Raw override; '' means the provider applies its localized default prompt.
  FSystemPrompt := KXChatSetting(AProfile, PFX + 'SystemPrompt');
  FBaseUrl := KXChatSettingRaw(AProfile, PFX + 'BaseUrl', KX_CLAUDE_DEF_BASEURL);
  if FBaseUrl.EndsWith('/') then
    FBaseUrl := FBaseUrl.Substring(0, FBaseUrl.Length - 1);
  FVersion := KXChatSettingRaw(AProfile, PFX + 'Version', KX_CLAUDE_DEF_VERSION);
  FConnectTimeoutMs := KXChatSettingInteger(AProfile, PFX + 'ConnectTimeoutMs', KX_CLAUDE_DEF_CONNECTTIMEOUTMS);
  FResponseTimeoutMs := KXChatSettingInteger(AProfile, PFX + 'ResponseTimeoutMs', KX_CLAUDE_DEF_RESPONSETIMEOUTMS);
end;

{ TKXClaudeProvider }

constructor TKXClaudeProvider.Create;
begin
  inherited Create;
  FConfig := TKClaudeProviderConfig.Create(TKConfig.Instance.Config);
end;

procedure TKXClaudeProvider.Configure(const AProfile: string);
begin
  inherited;
  // Read once, but read again when it turns out this instance answers for one
  // of the declared assistants: its model, its key and its endpoint may be its
  // own. Nothing has been asked of the provider yet at this point.
  if AProfile <> '' then
  begin
    FreeAndNil(FConfig);
    FConfig := TKClaudeProviderConfig.Create(TKConfig.Instance.Config, AProfile);
  end;
end;

destructor TKXClaudeProvider.Destroy;
begin
  FConfig.Free;
  inherited;
end;

function TKXClaudeProvider.GetName: string;
begin
  Result := KX_CHAT_PROVIDER_CLAUDE;
end;

function TKXClaudeProvider.SupportsStreaming: Boolean;
begin
  Result := True;
end;


function TKXClaudeProvider.CompleteText(const APrompt: string;
  const AMaxTokens: Integer; const ACancel: IKXChatCancelToken): string;
var
  LClient: THTTPClient;
  LSource: TStringStream;
  LHeaders: TNetHeaders;
  LResponse: IHTTPResponse;
  LRoot, LMsg: TJSONObject;
  LMessages: TJSONArray;
  LBody, LText: string;
  LContent: TJSONArray;
begin
  Result := '';
  if (Trim(APrompt) = '') or (FConfig.ApiKey = '') then
    Exit;
  if Assigned(ACancel) and ACancel.IsCancelled then
    Exit;

  // Nothing here reaches the user, and nothing here may cost the user the
  // answer: whatever goes wrong - the network, the key, a body that is not what
  // we expect - leaves the result empty and the caller carries on without it.
  try
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('model', FConfig.Model);
      LRoot.AddPair('max_tokens', TJSONNumber.Create(AMaxTokens));
      // The same question must give the same terms: this is a lookup, not a
      // piece of writing.
      LRoot.AddPair('temperature', TJSONNumber.Create(0));
      LMessages := TJSONArray.Create;
      LMsg := TJSONObject.Create;
      LMsg.AddPair('role', 'user');
      LMsg.AddPair('content', APrompt);
      LMessages.AddElement(LMsg);
      LRoot.AddPair('messages', LMessages);
      LBody := LRoot.ToJSON;
    finally
      LRoot.Free;
    end;

    LClient := THTTPClient.Create;
    LSource := TStringStream.Create(LBody, TEncoding.UTF8);
    try
      LClient.ConnectionTimeout := FConfig.ConnectTimeoutMs;
      LClient.ResponseTimeout := FConfig.ResponseTimeoutMs;
      LHeaders := [
        TNetHeader.Create('x-api-key', FConfig.ApiKey),
        TNetHeader.Create('anthropic-version', FConfig.Version),
        TNetHeader.Create('content-type', 'application/json')
      ];
      LResponse := LClient.Post(FConfig.BaseUrl + '/v1/messages', LSource, nil, LHeaders);
      if LResponse.StatusCode >= 400 then
        Exit;

      LRoot := TJSONObject.ParseJSONValue(LResponse.ContentAsString(TEncoding.UTF8)) as TJSONObject;
      if not Assigned(LRoot) then
        Exit;
      try
        // { "content": [ { "type": "text", "text": "..." } ], ... }
        if LRoot.TryGetValue<TJSONArray>('content', LContent) and (LContent.Count > 0) and
          (LContent.Items[0] is TJSONObject) and
          TJSONObject(LContent.Items[0]).TryGetValue<string>('text', LText)
        then
          Result := LText;
      finally
        LRoot.Free;
      end;
    finally
      LSource.Free;
      LClient.Free;
    end;
  except
    on E: Exception do
    begin
      TEFLogger.Instance.Log('Help Chat: the search terms were not obtained: ' +
        E.Message, TEFLogger.LOG_DETAILED);
      Result := '';
    end;
  end;
end;


function TKXClaudeProvider.Generate(const AHistory: TArray<TKXChatMessage>;
  const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc;
  const ACancel: IKXChatCancelToken): string;
var
  LSystem, LBody, LTerms: string;
  LGrounded: TArray<TKXHelpPage>;
  LClient: THTTPClient;
  LSource: TStringStream;
  LStream: TKXAnthropicStream;
  LHeaders: TNetHeaders;
  LResponse: IHTTPResponse;
  LRoot, LMsg: TJSONObject;
  LMessages: TJSONArray;
  I, LLastUser: Integer;
begin
  // FConfig was read once at construction (see Create); no per-request tree lookups.
  if FConfig.ApiKey = '' then
    raise Exception.Create(_('The Claude help provider is not configured: set ' +
      'HelpChat/Claude/ApiKey in Config.yaml (or the ANTHROPIC_API_KEY environment variable).'));

  // Asked before the prompt is built, because the prompt carries the pages the
  // terms find. It is a request of its own: if it fails, or is not due, the
  // search runs as it did before.
  LTerms := KXChatSearchTerms(Self, AHistory, AContext, ACancel);

  LSystem := KXChatBuildSystemPrompt(AHistory, AContext, FConfig.SystemPrompt,
    FConfig.GroundingMaxPages, LTerms, LGrounded);

  // Build the request body with System.JSON so all content is correctly escaped.
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('model', FConfig.Model);
    LRoot.AddPair('max_tokens', TJSONNumber.Create(FConfig.MaxTokens));
    LRoot.AddPair('stream', TJSONBool.Create(True));
    if LSystem <> '' then
      LRoot.AddPair('system', LSystem);

    // Which turn carries the attachments: the last user one, which is the
    // question being asked. They belong to the conversation and go up again
    // with every later question - that is what makes "and in the second
    // invoice?" answerable - but they travel once per request, on that turn.
    LLastUser := -1;
    if Length(AContext.Attachments) > 0 then
      for I := High(AHistory) downto Low(AHistory) do
        if (AHistory[I].Role = crUser) and (Trim(AHistory[I].Content) <> '') then
        begin
          LLastUser := I;
          Break;
        end;

    LMessages := TJSONArray.Create;
    for I := Low(AHistory) to High(AHistory) do
    begin
      // Fold system messages into the top-level system field; skip empties.
      if (AHistory[I].Role = crSystem) or (Trim(AHistory[I].Content) = '') then
        Continue;
      LMsg := TJSONObject.Create;
      if AHistory[I].Role = crUser then
        LMsg.AddPair('role', 'user')
      else
        LMsg.AddPair('role', 'assistant');
      if I = LLastUser then
        LMsg.AddPair('content', BuildUserContent(AHistory[I].Content, AContext.Attachments))
      else
        LMsg.AddPair('content', AHistory[I].Content);
      LMessages.AddElement(LMsg);
    end;
    // The API requires a non-empty messages array starting with a user turn; our
    // history always ends with the current user question, but guard anyway.
    if LMessages.Count = 0 then
    begin
      LMsg := TJSONObject.Create;
      LMsg.AddPair('role', 'user');
      LMsg.AddPair('content', KXChatLastUserMessage(AHistory));
      LMessages.AddElement(LMsg);
    end;
    LRoot.AddPair('messages', LMessages);

    LBody := LRoot.ToJSON;
  finally
    LRoot.Free; // frees the whole tree (messages + message objects)
  end;

  LClient := THTTPClient.Create;
  LSource := TStringStream.Create(LBody, TEncoding.UTF8);
  LStream := TKXAnthropicStream.Create(AOnToken, ACancel);
  try
    LClient.ConnectionTimeout := FConfig.ConnectTimeoutMs;
    LClient.ResponseTimeout := FConfig.ResponseTimeoutMs;

    LHeaders := [
      TNetHeader.Create('x-api-key', FConfig.ApiKey),
      TNetHeader.Create('anthropic-version', FConfig.Version),
      TNetHeader.Create('content-type', 'application/json'),
      TNetHeader.Create('accept', 'text/event-stream')
    ];

    // The response body is streamed into LStream, which parses the SSE tokens
    // and forwards them via AOnToken as they arrive.
    try
      LResponse := LClient.Post(FConfig.BaseUrl + '/v1/messages', LSource, LStream, LHeaders);
    except
      // The HTTP layer may wrap what the destination stream raised: when the
      // token is the reason, say so plainly, whatever came out of it.
      if Assigned(ACancel) and ACancel.IsCancelled then
        raise EKXChatCancelled.Create('cancelled');
      raise;
    end;
    LStream.Finish;

    if LResponse.StatusCode >= 400 then
      raise Exception.Create(ExtractApiError(LStream.Raw, LResponse.StatusCode, LResponse.StatusText));
    if LStream.Error <> '' then
      raise Exception.Create(LStream.Error);

    Result := LStream.Text;
    // The model was asked to cite; when it names a page without linking it, the
    // line is added here from the pages that were actually injected.
    if Trim(Result) <> '' then
      Result := Result + KXChatSourcesLine(Result, LGrounded);
    if Trim(Result) = '' then
      Result := _('The assistant did not return any content.');
  finally
    LStream.Free;
    LSource.Free;
    LClient.Free;
  end;
end;

initialization
  TKXChatProviderRegistry.RegisterProvider(KX_CHAT_PROVIDER_CLAUDE, TKXClaudeProvider);

finalization
  if TKXChatProviderRegistry.IsRegistered(KX_CHAT_PROVIDER_CLAUDE) then
    TKXChatProviderRegistry.UnregisterProvider(KX_CHAT_PROVIDER_CLAUDE);

end.
