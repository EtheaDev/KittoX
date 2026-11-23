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
///  The second AI provider of the help chat (<c>openai</c>): it speaks
///  <b>Chat Completions</b>, which is not one service but the shape most of
///  them answer to - OpenAI itself, Azure OpenAI, and everything that calls
///  itself OpenAI-compatible, from a local Ollama or LM Studio to vLLM, Groq
///  or OpenRouter. One implementation, one <c>BaseUrl</c> to change.
///  <para>Everything that is not the shape of these bytes - the system prompt,
///  the identity, the documentation excerpts, the search terms, the line of
///  sources, the sink that cuts a stream into lines - is shared with the other
///  providers (<see cref="Kitto.Chat.Prompt" />,
///  <see cref="Kitto.Chat.Stream" />). What is here is: the body of the
///  request, the content parts of an attachment, and how a delta arrives.</para>
/// </summary>
unit Kitto.Chat.Provider.OpenAI;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree
  , EF.YAML.Attributes
  , Kitto.Chat.Provider
  , Kitto.Chat.Stream
  ;

const
  /// <summary>Default model. It is only a default: a service that is merely
  /// compatible has model names of its own, and so does a local one.</summary>
  KX_OPENAI_DEF_MODEL = 'gpt-6-luna';
  /// <summary>Default endpoint: OpenAI itself. Any compatible service is one
  /// BaseUrl away.</summary>
  KX_OPENAI_DEF_BASEURL = 'https://api.openai.com/v1';
  /// <summary>Default cap on the length of a reply.</summary>
  KX_OPENAI_DEF_MAXTOKENS = 1024;
  /// <summary>Default number of documentation pages injected in the prompt.</summary>
  KX_OPENAI_DEF_GROUNDING = 3;
  /// <summary>Name of the parameter that caps the reply. OpenAI renamed it and
  /// its newest models refuse the old one; most compatible services still only
  /// know <c>max_tokens</c>, which is why this is a setting and not a
  /// constant.</summary>
  KX_OPENAI_DEF_TOKENSPARAM = 'max_completion_tokens';
  KX_OPENAI_DEF_CONNECTTIMEOUTMS = 10000;
  KX_OPENAI_DEF_RESPONSETIMEOUTMS = 120000;

type
  /// <summary>
  ///  Settings of the <c>openai</c> provider. A plain reader, bound to its YAML
  ///  node by the class-level attribute so KIDE finds it by scanning the linked
  ///  types; every value is read through the profile, so one assistant may be
  ///  answered by a model and another by a different one.
  /// </summary>
  /// <example>
  ///  HelpChat:
  ///    Provider: openai
  ///    OpenAI:
  ///      ApiKey: %ENV(OPENAI_API_KEY)%
  ///      Model: gpt-6-luna
  ///      BaseUrl: https://api.openai.com/v1
  /// </example>
  [YamlConfigNode('HelpChat/OpenAI')]
  TKOpenAIProviderConfig = class
  private
    FApiKey: string;
    FModel: string;
    FMaxTokens: Integer;
    FGroundingMaxPages: Integer;
    FSystemPrompt: string;
    FBaseUrl: string;
    FTokensParam: string;
    FReasoningEffort: string;
    FConnectTimeoutMs: Integer;
    FResponseTimeoutMs: Integer;
  public
    constructor Create(const AConfig: TEFTree; const AProfile: string = '');

    [YamlNode('ApiKey', 'API key of the service (macro-expanded; falls back to the OPENAI_API_KEY environment variable). A local service usually needs none')]
    property ApiKey: string read FApiKey;

    [YamlNode('Model', KX_OPENAI_DEF_MODEL, 'Model that answers')]
    property Model: string read FModel;

    [YamlNode('BaseUrl', KX_OPENAI_DEF_BASEURL, 'Endpoint of the service, up to and including /v1: this is what points the provider at a compatible service instead of OpenAI')]
    property BaseUrl: string read FBaseUrl;

    [YamlNode('MaxTokens', KX_OPENAI_DEF_MAXTOKENS, 'Cap on the length of a reply')]
    property MaxTokens: Integer read FMaxTokens;

    [YamlNode('TokensParam', KX_OPENAI_DEF_TOKENSPARAM, 'Name of the parameter that carries MaxTokens: max_completion_tokens for OpenAI today, max_tokens for most compatible services')]
    property TokensParam: string read FTokensParam;

    [YamlNode('ReasoningEffort', 'Sent as reasoning_effort when set (none, low, medium, high): a reasoning model spends a long time on a line of search terms. Empty: the parameter is not sent at all, which is what a service that does not know it needs')]
    property ReasoningEffort: string read FReasoningEffort;

    [YamlNode('GroundingMaxPages', KX_OPENAI_DEF_GROUNDING, 'Documentation pages injected in the prompt (0 = no grounding)')]
    property GroundingMaxPages: Integer read FGroundingMaxPages;

    [YamlNode('SystemPrompt', 'Replaces the built-in system prompt. Empty: the built-in one')]
    property SystemPrompt: string read FSystemPrompt;

    [YamlNode('ConnectTimeoutMs', KX_OPENAI_DEF_CONNECTTIMEOUTMS, 'Connection timeout in milliseconds')]
    property ConnectTimeoutMs: Integer read FConnectTimeoutMs;

    [YamlNode('ResponseTimeoutMs', KX_OPENAI_DEF_RESPONSETIMEOUTMS, 'Response timeout in milliseconds')]
    property ResponseTimeoutMs: Integer read FResponseTimeoutMs;
  end;

  /// <summary>
  ///  Answers through a Chat Completions endpoint, streaming the reply as it
  ///  is produced (name <c>openai</c>).
  /// </summary>
  TKXOpenAIProvider = class(TKXChatProviderBase)
  private
    FConfig: TKOpenAIProviderConfig;
  public
    constructor Create; override;
    destructor Destroy; override;
    function GetName: string; override;
    function SupportsStreaming: Boolean; override;
    function SupportsDocuments: Boolean; override;
    function CompleteText(const APrompt: string; const AMaxTokens: Integer;
      const ACancel: IKXChatCancelToken): string; override;
    procedure Configure(const AProfile: string); override;
    function Generate(const AHistory: TArray<TKXChatMessage>;
      const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc;
      const ACancel: IKXChatCancelToken): string; override;
  end;

const
  /// <summary>Name under which this provider registers.</summary>
  KX_CHAT_PROVIDER_OPENAI = 'openai';

implementation

uses
  System.SysUtils
  , System.Classes
  , System.Generics.Collections
  , System.JSON
  , System.Net.HttpClient
  , System.Net.URLClient
  , EF.Localization
  , EF.Logger
  , Kitto.Config
  , Kitto.Chat.Attachments
  , Kitto.Chat.Prompt
  , Kitto.Chat.DocSearch
  ;

type
  /// <summary>
  ///  The sink of a Chat Completions stream: lines of <c>data:</c>, a JSON
  ///  object each, with the piece of text in <c>choices[0].delta.content</c>,
  ///  and <c>[DONE]</c> at the end. An error arrives as an <c>error</c> object
  ///  in the same shape.
  /// </summary>
  TKXOpenAIStream = class(TKXChatSSEStream)
  protected
    procedure ProcessLine(const ALine: string); override;
  end;

{ TKXOpenAIStream }

procedure TKXOpenAIStream.ProcessLine(const ALine: string);
var
  LData: string;
  LRoot, LChoice, LDelta, LErr: TJSONObject;
  LChoices: TJSONArray;
begin
  if not ALine.StartsWith('data:') then
    Exit;
  LData := Trim(System.Copy(ALine, 6, MaxInt));
  if (LData = '') or (LData = '[DONE]') then
    Exit;

  try
    LRoot := TJSONObject.ParseJSONValue(LData) as TJSONObject;
  except
    LRoot := nil; // a malformed fragment is ignored, not fatal to the reply
  end;
  if LRoot = nil then
    Exit;
  try
    // An error may arrive in the middle of a stream that started fine.
    if LRoot.TryGetValue<TJSONObject>('error', LErr) then
    begin
      Fail(LErr.GetValue<string>('message', _('The AI provider returned an error.')));
      Exit;
    end;
    if not LRoot.TryGetValue<TJSONArray>('choices', LChoices) then
      Exit;
    if LChoices.Count = 0 then
      Exit;
    if not (LChoices.Items[0] is TJSONObject) then
      Exit;
    LChoice := TJSONObject(LChoices.Items[0]);
    // delta while streaming; a service that answers in one go puts it in
    // message instead, and both are accepted.
    if not LChoice.TryGetValue<TJSONObject>('delta', LDelta) then
      if not LChoice.TryGetValue<TJSONObject>('message', LDelta) then
        Exit;
    Emit(LDelta.GetValue<string>('content', ''));
  finally
    LRoot.Free;
  end;
end;

{ TKOpenAIProviderConfig }

constructor TKOpenAIProviderConfig.Create(const AConfig: TEFTree;
  const AProfile: string);
const
  PFX = 'OpenAI/';
begin
  inherited Create;
  FApiKey := Trim(KXChatSetting(AProfile, PFX + 'ApiKey'));
  if FApiKey = '' then
    FApiKey := Trim(GetEnvironmentVariable('OPENAI_API_KEY'));
  FModel := KXChatSettingRaw(AProfile, PFX + 'Model', KX_OPENAI_DEF_MODEL);
  FMaxTokens := KXChatSettingInteger(AProfile, PFX + 'MaxTokens', KX_OPENAI_DEF_MAXTOKENS);
  FGroundingMaxPages := KXChatSettingInteger(AProfile, PFX + 'GroundingMaxPages',
    KX_OPENAI_DEF_GROUNDING);
  FSystemPrompt := KXChatSetting(AProfile, PFX + 'SystemPrompt');
  FBaseUrl := KXChatSettingRaw(AProfile, PFX + 'BaseUrl', KX_OPENAI_DEF_BASEURL);
  if FBaseUrl.EndsWith('/') then
    FBaseUrl := FBaseUrl.Substring(0, FBaseUrl.Length - 1);
  FTokensParam := Trim(KXChatSettingRaw(AProfile, PFX + 'TokensParam',
    KX_OPENAI_DEF_TOKENSPARAM));
  if FTokensParam = '' then
    FTokensParam := KX_OPENAI_DEF_TOKENSPARAM;
  FReasoningEffort := Trim(KXChatSettingRaw(AProfile, PFX + 'ReasoningEffort'));
  FConnectTimeoutMs := KXChatSettingInteger(AProfile, PFX + 'ConnectTimeoutMs',
    KX_OPENAI_DEF_CONNECTTIMEOUTMS);
  FResponseTimeoutMs := KXChatSettingInteger(AProfile, PFX + 'ResponseTimeoutMs',
    KX_OPENAI_DEF_RESPONSETIMEOUTMS);
end;

{ helpers }

// The content of the user turn the attachments belong to: an image_url part
// with a data URI per picture, a file part per PDF - the one document Chat
// Completions takes, and it wants the name next to the bytes - and the text
// last. A text attachment is not a part: it was decoded when it arrived and is
// already inside that text.
function BuildUserContent(const AText: string;
  const AAttachments: TArray<TKXChatAttachment>): TJSONArray;
var
  LPart, LInner: TJSONObject;
  I: Integer;
begin
  Result := TJSONArray.Create;
  try
    for I := Low(AAttachments) to High(AAttachments) do
    begin
      if (AAttachments[I].Kind = cakText) or (Length(AAttachments[I].Data) = 0) then
        Continue;
      LPart := TJSONObject.Create;
      LInner := TJSONObject.Create;
      if AAttachments[I].Kind = cakImage then
      begin
        LPart.AddPair('type', 'image_url');
        LInner.AddPair('url', 'data:' + AAttachments[I].MediaType + ';base64,' +
          AAttachments[I].Base64);
        LPart.AddPair('image_url', LInner);
      end
      else
      begin
        LPart.AddPair('type', 'file');
        LInner.AddPair('filename', AAttachments[I].FileName);
        LInner.AddPair('file_data', 'data:' + AAttachments[I].MediaType + ';base64,' +
          AAttachments[I].Base64);
        LPart.AddPair('file', LInner);
      end;
      Result.AddElement(LPart);
    end;

    LPart := TJSONObject.Create;
    LPart.AddPair('type', 'text');
    LPart.AddPair('text', KXChatQuestionWithText(AText, AAttachments));
    Result.AddElement(LPart);
  except
    Result.Free;
    raise;
  end;
end;

// A human-readable message out of a non-2xx body: { "error": { "message": ... } }
// is what every one of these services answers, and what is not that is reported
// by its status.
function ExtractApiError(const ARaw: string; const AStatus: Integer;
  const AStatusText: string): string;
var
  LRoot, LErr: TJSONObject;
begin
  Result := '';
  if Trim(ARaw) <> '' then
  begin
    try
      LRoot := TJSONObject.ParseJSONValue(ARaw) as TJSONObject;
    except
      LRoot := nil;
    end;
    if LRoot <> nil then
      try
        if LRoot.TryGetValue<TJSONObject>('error', LErr) then
          Result := LErr.GetValue<string>('message', '');
      finally
        LRoot.Free;
      end;
  end;
  if Trim(Result) = '' then
    Result := Format(_('The AI provider answered %d (%s).'), [AStatus, AStatusText]);
end;

{ TKXOpenAIProvider }

constructor TKXOpenAIProvider.Create;
begin
  inherited Create;
  FConfig := TKOpenAIProviderConfig.Create(TKConfig.Instance.Config);
end;

destructor TKXOpenAIProvider.Destroy;
begin
  FConfig.Free;
  inherited;
end;

procedure TKXOpenAIProvider.Configure(const AProfile: string);
begin
  inherited;
  if AProfile <> '' then
  begin
    FreeAndNil(FConfig);
    FConfig := TKOpenAIProviderConfig.Create(TKConfig.Instance.Config, AProfile);
  end;
end;

function TKXOpenAIProvider.GetName: string;
begin
  Result := KX_CHAT_PROVIDER_OPENAI;
end;

function TKXOpenAIProvider.SupportsStreaming: Boolean;
begin
  Result := True;
end;

function TKXOpenAIProvider.SupportsDocuments: Boolean;
begin
  Result := True;
end;

function TKXOpenAIProvider.CompleteText(const APrompt: string;
  const AMaxTokens: Integer; const ACancel: IKXChatCancelToken): string;
var
  LClient: THTTPClient;
  LSource: TStringStream;
  LHeaders: TNetHeaders;
  LResponse: IHTTPResponse;
  LRoot, LMsg, LChoice, LMessage: TJSONObject;
  LMessages, LChoices: TJSONArray;
  LBody: string;
begin
  Result := '';
  if Trim(APrompt) = '' then
    Exit;
  if Assigned(ACancel) and ACancel.IsCancelled then
    Exit;

  // Nothing here reaches the user, and nothing here may cost the user the
  // answer: whatever goes wrong leaves the result empty and the caller carries
  // on without it.
  try
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('model', FConfig.Model);
      LRoot.AddPair(FConfig.TokensParam, TJSONNumber.Create(AMaxTokens));
      LRoot.AddPair('temperature', TJSONNumber.Create(0));
      // A reasoning model takes its time over a line of search terms, and the
      // setting is how an application tells it not to. Sent only when set: a
      // service that does not know the parameter answers 400 to it.
      if FConfig.ReasoningEffort <> '' then
        LRoot.AddPair('reasoning_effort', FConfig.ReasoningEffort);
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
      LHeaders := [TNetHeader.Create('content-type', 'application/json')];
      if FConfig.ApiKey <> '' then
        LHeaders := LHeaders + [TNetHeader.Create('authorization', 'Bearer ' + FConfig.ApiKey)];
      LResponse := LClient.Post(FConfig.BaseUrl + '/chat/completions', LSource, nil, LHeaders);
      if LResponse.StatusCode >= 400 then
        Exit;

      LRoot := TJSONObject.ParseJSONValue(LResponse.ContentAsString(TEncoding.UTF8)) as TJSONObject;
      if not Assigned(LRoot) then
        Exit;
      try
        if LRoot.TryGetValue<TJSONArray>('choices', LChoices) and (LChoices.Count > 0) and
          (LChoices.Items[0] is TJSONObject) then
        begin
          LChoice := TJSONObject(LChoices.Items[0]);
          if LChoice.TryGetValue<TJSONObject>('message', LMessage) then
            Result := LMessage.GetValue<string>('content', '');
        end;
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

function TKXOpenAIProvider.Generate(const AHistory: TArray<TKXChatMessage>;
  const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc;
  const ACancel: IKXChatCancelToken): string;
var
  LSystem, LBody, LTerms: string;
  LGrounded: TArray<TKXHelpPage>;
  LClient: THTTPClient;
  LSource: TStringStream;
  LStream: TKXOpenAIStream;
  LHeaders: TNetHeaders;
  LResponse: IHTTPResponse;
  LRoot, LMsg: TJSONObject;
  LMessages: TJSONArray;
  I, LLastUser: Integer;
begin
  // A key is not always needed: a local service usually has none, and refusing
  // to start without one would make the common local setup impossible.
  if (FConfig.ApiKey = '') and FConfig.BaseUrl.Contains('api.openai.com') then
    raise Exception.Create(_('The OpenAI help provider is not configured: set ' +
      'HelpChat/OpenAI/ApiKey in Config.yaml (or the OPENAI_API_KEY environment variable).'));

  LTerms := KXChatSearchTerms(Self, AHistory, AContext, ACancel);
  LSystem := KXChatBuildSystemPrompt(AHistory, AContext, FConfig.SystemPrompt,
    FConfig.GroundingMaxPages, LTerms, LGrounded);

  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('model', FConfig.Model);
    LRoot.AddPair(FConfig.TokensParam, TJSONNumber.Create(FConfig.MaxTokens));
    LRoot.AddPair('stream', TJSONBool.Create(True));
    if FConfig.ReasoningEffort <> '' then
      LRoot.AddPair('reasoning_effort', FConfig.ReasoningEffort);

    // Which turn carries the attachments: the last user one, the question being
    // asked. They belong to the conversation and go up again with every later
    // question, but they travel once per request, on that turn.
    LLastUser := -1;
    if Length(AContext.Attachments) > 0 then
      for I := High(AHistory) downto Low(AHistory) do
        if (AHistory[I].Role = crUser) and (Trim(AHistory[I].Content) <> '') then
        begin
          LLastUser := I;
          Break;
        end;

    LMessages := TJSONArray.Create;
    // Here the system prompt is a turn of its own, the first one: this is the
    // one real difference from the other API, where it is a field beside the
    // turns.
    if LSystem <> '' then
    begin
      LMsg := TJSONObject.Create;
      LMsg.AddPair('role', 'system');
      LMsg.AddPair('content', LSystem);
      LMessages.AddElement(LMsg);
    end;
    for I := Low(AHistory) to High(AHistory) do
    begin
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
    LRoot.Free;
  end;

  LClient := THTTPClient.Create;
  LSource := TStringStream.Create(LBody, TEncoding.UTF8);
  LStream := TKXOpenAIStream.Create(AOnToken, ACancel);
  try
    LClient.ConnectionTimeout := FConfig.ConnectTimeoutMs;
    LClient.ResponseTimeout := FConfig.ResponseTimeoutMs;

    LHeaders := [
      TNetHeader.Create('content-type', 'application/json'),
      TNetHeader.Create('accept', 'text/event-stream')
    ];
    if FConfig.ApiKey <> '' then
      LHeaders := LHeaders + [TNetHeader.Create('authorization', 'Bearer ' + FConfig.ApiKey)];

    try
      LResponse := LClient.Post(FConfig.BaseUrl + '/chat/completions', LSource, LStream, LHeaders);
    except
      // The HTTP layer may wrap what the destination stream raised: when the
      // token is the reason, say so plainly, whatever came out of it.
      if Assigned(ACancel) and ACancel.IsCancelled then
        raise EKXChatCancelled.Create('cancelled');
      raise;
    end;
    LStream.Finish;

    if LResponse.StatusCode >= 400 then
      raise Exception.Create(ExtractApiError(LStream.Raw, LResponse.StatusCode,
        LResponse.StatusText));
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
  TKXChatProviderRegistry.RegisterProvider(KX_CHAT_PROVIDER_OPENAI, TKXOpenAIProvider);

finalization
  if TKXChatProviderRegistry.IsRegistered(KX_CHAT_PROVIDER_OPENAI) then
    TKXChatProviderRegistry.UnregisterProvider(KX_CHAT_PROVIDER_OPENAI);

end.
