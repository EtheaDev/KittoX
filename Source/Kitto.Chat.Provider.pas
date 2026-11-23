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
///  Provider abstraction for the KittoX in-app help chat. A provider turns the
///  conversation history (plus an optional context: the view the user is on)
///  into an assistant reply. v1 ships a stub provider that returns an honest
///  placeholder; real back-ends (a DocuWiki-grounded Claude provider, a static
///  FAQ matcher, a local LLM) implement the same <see cref="IKXChatProvider" />
///  interface and register themselves in <see cref="TKXChatProviderRegistry" />,
///  so the active provider is selected by name from <c>HelpChat/Provider</c> in
///  Config.yaml with no code change on the call site.
/// </summary>
unit Kitto.Chat.Provider;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Chat.Attachments;

const
  // Help Chat root default values — single source of truth for the whole chat
  // domain (this unit is the chat-domain base): the config-class getters below,
  // the [YamlNode] attributes, the runtime readers in Kitto.Chat.* /
  // Kitto.Web.Handler.Chat and the KIDE Config designer frame.
  KX_HELPCHAT_DEF_POOLSIZE = 2;
  KX_HELPCHAT_DEF_MSGMAXLEN = 4000;
  KX_HELPCHAT_DEF_HISTMAXMSG = 50;
  KX_HELPCHAT_DEF_MAXSTORED = 200;
  KX_HELPCHAT_DEF_GREETING = 'Hi! Ask me anything about how to use the application.';
  KX_HELPCHAT_DEF_ASSISTANTNAME = 'Help';
  KX_HELPCHAT_DEF_TRANSLATESEARCH = True;
  // The line of search terms is a query, not prose: what comes back from the
  // model is cut to this, which is already more words than a search can use.
  KX_HELPCHAT_SEARCHTERMS_MAXCHARS = 200;
  // And the model is not allowed to write more than this many tokens of it. A
  // cap is not a saving here, it is a guard: asked for a line of words, a model
  // that starts explaining itself instead must stop early.
  KX_HELPCHAT_SEARCHTERMS_TOKENS = 150;

type
  /// <summary>
  ///  What the user may attach to a question. Off by default: what is attached
  ///  leaves the server and reaches the provider, which is the application's
  ///  decision to make and not the framework's.
  ///  <para>A plain reader like the provider ones, bound to its YAML node by
  ///  the class-level attribute so KIDE finds it by scanning: the parent config
  ///  class does not reference it by type.</para>
  /// </summary>
  /// <example>
  ///  HelpChat:
  ///    Attachments:
  ///      Enabled: True
  ///      MaxCount: 5
  ///      MaxSizeKB: 8192
  ///      MaxTotalKB: 20480
  ///      ImageMaxKB: 3600
  /// </example>
  [YamlConfigNode('HelpChat/Attachments')]
  TKHelpChatAttachmentsConfig = class(TEFNode)
  private
    function GetEnabled: Boolean;
    function GetMaxCount: Integer;
    function GetMaxSizeKB: Integer;
    function GetMaxTotalKB: Integer;
    function GetImageMaxKB: Integer;
  public
    [YamlNode('Enabled', 'False', 'Let the user attach files to a question (PDF, pictures, text). What is attached reaches the provider')]
    property Enabled: Boolean read GetEnabled;

    [YamlNode('MaxCount', KX_CHAT_DEF_ATTACH_MAXCOUNT, 'Files a conversation may hold at a time (0 = no limit)')]
    property MaxCount: Integer read GetMaxCount;

    [YamlNode('MaxSizeKB', KX_CHAT_DEF_ATTACH_MAXSIZEKB, 'Largest single file, in KB (0 = no limit)')]
    property MaxSizeKB: Integer read GetMaxSizeKB;

    [YamlNode('MaxTotalKB', KX_CHAT_DEF_ATTACH_MAXTOTALKB, 'Largest total per conversation, in KB (0 = no limit). What travels is a third larger: base64')]
    property MaxTotalKB: Integer read GetMaxTotalKB;

    [YamlNode('ImageMaxKB', KX_CHAT_DEF_ATTACH_IMAGEMAXKB, 'Largest picture, in KB: the services refuse a larger one, and a refused picture would fail every later question of the conversation')]
    property ImageMaxKB: Integer read GetImageMaxKB;
  end;

  /// <summary>
  ///  Help Chat assistant settings (bubble, bottom-right). Opt-in. Root config of
  ///  the chat domain; each provider adds its own [YamlConfigNode('HelpChat/&lt;X&gt;')]
  ///  reader in its own unit (e.g. TKClaudeProviderConfig). The class-level
  ///  [YamlConfigNode('HelpChat')] binds this class to the YAML node so KIDE
  ///  discovers it via RTTI, without TKConfig referencing it by type.
  ///  YAML path: HelpChat
  /// </summary>
  /// <example>
  ///  HelpChat:
  ///    Enabled: True
  ///    Provider: docsearch
  /// </example>
  [YamlConfigNode('HelpChat')]
  TKHelpChatConfig = class(TEFNode)
  private
    function GetEnabled: Boolean;
    function GetProvider: string;
    function GetPoolSize: Integer;
    function GetMessageMaxLength: Integer;
    function GetHistoryMaxMessages: Integer;
    function GetMaxStoredMessages: Integer;
    function GetGreeting: string;
    function GetAssistantName: string;
    function GetExpertise: string;
    function GetDocLanguage: string;
    function GetTranslateSearch: Boolean;
    function GetSearchTermsPrompt: string;
    function GetDocIndex: string;
    function GetDocBaseUrl: string;
  public
    [YamlNode('Enabled', 'False', 'Enable the in-app Help Chat assistant (bubble, bottom-right)')]
    property Enabled: Boolean read GetEnabled;

    [YamlNode('Provider', 'stub', 'Chat provider id (e.g. stub, docsearch, claude)')]
    [YamlEnumValue('stub', 'Canned/echo provider for testing')]
    [YamlEnumValue('docsearch', 'Documentation search provider')]
    [YamlEnumValue('claude', 'Anthropic Claude provider')]
    [YamlEnumValue('openai', 'OpenAI-compatible provider (OpenAI, Azure, Ollama, LM Studio, vLLM, Groq...)')]
    // Open: the provider id is a pluggable registry, so a custom one is allowed.
    [YamlEnumOpen]
    property Provider: string read GetProvider;

    [YamlNode('PoolSize', KX_HELPCHAT_DEF_POOLSIZE, 'Number of worker threads for the chat runner')]
    property PoolSize: Integer read GetPoolSize;

    [YamlNode('MessageMaxLength', KX_HELPCHAT_DEF_MSGMAXLEN, 'Maximum length in characters of a user message')]
    property MessageMaxLength: Integer read GetMessageMaxLength;

    [YamlNode('HistoryMaxMessages', KX_HELPCHAT_DEF_HISTMAXMSG, 'Maximum number of messages kept in the conversation history')]
    property HistoryMaxMessages: Integer read GetHistoryMaxMessages;

    [YamlNode('MaxStoredMessages', KX_HELPCHAT_DEF_MAXSTORED, 'Maximum number of messages kept in memory per user (oldest completed ones are dropped)')]
    property MaxStoredMessages: Integer read GetMaxStoredMessages;

    [YamlNode('Greeting', KX_HELPCHAT_DEF_GREETING, 'Initial assistant greeting message shown when the chat opens', True)]
    property Greeting: string read GetGreeting;

    [YamlNode('AssistantName', KX_HELPCHAT_DEF_ASSISTANTNAME, 'Name the assistant answers to: it opens the system prompt, so the model introduces itself by it instead of improvising one', True)]
    property AssistantName: string read GetAssistantName;

    [YamlNode('Expertise', 'Field the assistant is an expert of (e.g. "accounting and invoicing"): it opens the system prompt and lets the model explain the concepts the manual takes for granted', True)]
    property Expertise: string read GetExpertise;

    [YamlNode('DocLanguage', 'Language the documentation is written in, as a code (en, it) or an English name (English): set it when the manual, and the screens it names, are not in the language the user reads the answers in. Empty: no rule')]
    property DocLanguage: string read GetDocLanguage;

    [YamlNode('TranslateSearch', 'True', 'When DocLanguage is set and differs from the language of the chat, ask the model for a line of search terms in the language of the manual and search with those too. One short extra request per question')]
    property TranslateSearch: Boolean read GetTranslateSearch;

    [YamlNode('SearchTermsPrompt', 'Overrides the prompt that turns the question into search terms (%0:s = language of the manual; the questions are appended below it). Empty: the built-in one')]
    property SearchTermsPrompt: string read GetSearchTermsPrompt;

    [YamlNode('DocIndex', 'Path to the documentation index JSON (docsearch / Claude grounding)')]
    property DocIndex: string read GetDocIndex;

    [YamlNode('DocBaseUrl', 'Base URL prefix for documentation links (docsearch / Claude grounding)')]
    property DocBaseUrl: string read GetDocBaseUrl;
  end;

  /// <summary>Author of a chat message.</summary>
  TKXChatRole = (crUser, crAssistant, crSystem);

  /// <summary>
  ///  A single chat message. A plain value record (strings + enums) so it can be
  ///  copied into the per-user store and passed to a worker thread without any
  ///  ownership concern. Assistant messages produced asynchronously start with
  ///  <c>Pending = True</c> and are later completed (or marked <c>IsError</c>).
  /// </summary>
  TKXChatMessage = record
    /// <summary>URL-safe id (used by the poll endpoint to fetch this message).</summary>
    Id: string;
    Role: TKXChatRole;
    Content: string;
    Created: TDateTime;
    /// <summary>True while an assistant reply is still being produced by the runner.</summary>
    Pending: Boolean;
    /// <summary>True when the assistant reply ended in an error (Content is the message).</summary>
    IsError: Boolean;
  end;

  /// <summary>
  ///  Optional context passed to the provider: who is asking and, if the chat was
  ///  opened from a specific screen, which view (its name and display label). A
  ///  DocuWiki/RAG provider uses <c>ViewName</c> to fetch the matching help page.
  /// </summary>
  TKXChatContext = record
    UserName: string;
    ViewName: string;
    ViewLabel: string;
    /// <summary>Controller type of the view the chat was opened from (e.g. List,
    /// Form). Used by the doc-search provider to anchor the answer to the right
    /// framework documentation page when the help is opened contextually.</summary>
    ControllerType: string;
    /// <summary>Code of the interface language of the session the question was
    /// asked from ('it', 'en'), read on the request thread and carried here
    /// because the reply is produced on a worker, where there is no session to
    /// ask. Empty: no language rule is added to the prompt.</summary>
    Language: string;
    /// <summary>What the user attached to the conversation, copied on the
    /// request thread. A copy and not the live list: the user may remove a file
    /// while the reply is being written, and a request answers against what it
    /// was given. Empty when attachments are off or none were attached.
    /// <para>They belong to the <b>conversation</b>, not to one question: the
    /// same files travel with every later question until they are removed or
    /// the conversation is cleared. That is what makes "and in the second
    /// invoice?" answerable.</para></summary>
    Attachments: TArray<TKXChatAttachment>;
    /// <summary>Which assistant is answering: the name of a node under
    /// <c>HelpChat/Profiles</c>, or empty for the one at the root. Resolved on
    /// the request thread from the screen the chat was opened from, and carried
    /// here because every setting that says who the assistant is - its name,
    /// its field, the areas of the manual it reads, even which provider and
    /// which model answer - is read through it.</summary>
    Profile: string;
  end;

  /// <summary>Callback invoked by a streaming provider for each produced token.</summary>
  TKXChatTokenProc = reference to procedure(const AToken: string);

  /// <summary>
  ///  Cooperative cancellation of a reply being produced. The runner creates one
  ///  per request and hands it to the provider, which checks it between one read
  ///  of the response stream and the next: a provider that ignores it simply
  ///  cannot be stopped. Also raised at shutdown, so closing the process does not
  ///  wait for an HTTP round-trip that can last as long as the response timeout.
  /// </summary>
  IKXChatCancelToken = interface
    ['{01A29637-AE23-4352-AFB6-F3EF2C277658}']
    /// <summary>True once cancellation has been requested.</summary>
    function IsCancelled: Boolean;
    /// <summary>Requests cancellation. Idempotent, callable from any thread.</summary>
    procedure Cancel;
  end;

  /// <summary>Default cancel token: a flag set and read through interlocked
  /// access, so the worker and the thread asking for cancellation need no lock.</summary>
  TKXChatCancelToken = class(TInterfacedObject, IKXChatCancelToken)
  strict private
    FCancelled: Integer;
  public
    function IsCancelled: Boolean;
    procedure Cancel;
  end;

  /// <summary>Raised by a provider that stopped because its token was cancelled.
  /// The runner keeps whatever was already streamed instead of turning it into an
  /// error bubble: a cancelled answer is a short answer, not a failed one.</summary>
  EKXChatCancelled = class(Exception);

  /// <summary>
  ///  Contract every chat back-end implements. <c>Generate</c> returns the full
  ///  assistant reply; a streaming provider (<c>SupportsStreaming = True</c>)
  ///  additionally calls <c>AOnToken</c> for each token as it is produced (the
  ///  returned string is their concatenation, convenient for persistence).
  /// </summary>
  IKXChatProvider = interface
    ['{0E4F35B3-24BF-4518-A414-0E6A975FFB0F}']
    /// <summary>The registered provider name (matches HelpChat/Provider).</summary>
    function GetName: string;
    /// <summary>True if the provider emits tokens incrementally via AOnToken.</summary>
    function SupportsStreaming: Boolean;
    /// <summary>True if the provider can take user attachments (documents and
    /// images) along with the question. False here means the chat tells the user
    /// so instead of silently dropping the file.</summary>
    function SupportsDocuments: Boolean;
    /// <summary>Produces the assistant reply for the given history and context.
    /// <c>ACancel</c> is never nil: a long-running provider checks it and raises
    /// <see cref="EKXChatCancelled" />, keeping what it has already streamed.</summary>
    function Generate(const AHistory: TArray<TKXChatMessage>;
      const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc;
      const ACancel: IKXChatCancelToken): string;
  end;

  /// <summary>Convenience base class for providers: reference-counted, non-streaming
  /// by default. Descendants override <c>GetName</c> and <c>Generate</c>.</summary>
  TKXChatProviderBase = class abstract (TInterfacedObject, IKXChatProvider)
  strict private
    FProfile: string;
  public
    /// <summary>Virtual so providers instantiated polymorphically via the
    /// registry (LClass.Create) can override it to read their config once at
    /// creation time (providers are short-lived, one per chat request).</summary>
    constructor Create; virtual;
    function GetName: string; virtual; abstract;
    function SupportsStreaming: Boolean; virtual;
    function SupportsDocuments: Boolean; virtual;
    function Generate(const AHistory: TArray<TKXChatMessage>;
      const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc;
      const ACancel: IKXChatCancelToken): string; virtual; abstract;

    /// <summary>
    ///  One short completion asked for the machinery of the chat rather than
    ///  for the user: today the line of search terms of
    ///  <see cref="KXChatComposeSearchTermsPrompt" />. No streaming, a few
    ///  tokens, and the answer is a value - nothing of it reaches the user.
    ///  <para>Empty by default, and empty is a legitimate answer: a provider
    ///  that has no model behind it (stub, docsearch) or that must not pay for
    ///  a second request simply does not implement it, and the caller carries
    ///  on with what it had. For the same reason an implementation must
    ///  <b>not</b> raise: what fails here costs the terms, never the reply.</para>
    /// </summary>
    function CompleteText(const APrompt: string; const AMaxTokens: Integer;
      const ACancel: IKXChatCancelToken): string; virtual;

    /// <summary>
    ///  Tells the provider which assistant it is answering for, right after it
    ///  was created and before anything is asked of it. A provider that reads
    ///  its configuration once - which is what they do, they are created one
    ///  per request - reads it again here, through the profile: a profile may
    ///  name its own model, its own key and its own endpoint.
    ///  <para>The default keeps the name for whoever wants it. It is not in the
    ///  constructor because the registry creates providers polymorphically.</para>
    /// </summary>
    procedure Configure(const AProfile: string); virtual;

    /// <summary>The assistant this instance answers for; empty for the one at
    /// the root of <c>HelpChat</c>.</summary>
    property Profile: string read FProfile;
  end;

  TKXChatProviderClass = class of TKXChatProviderBase;

  /// <summary>
  ///  Process-global registry of chat providers, keyed by name. Providers
  ///  self-register in their unit's initialization section; the active one is
  ///  created on demand from the name configured in <c>HelpChat/Provider</c>.
  /// </summary>
  TKXChatProviderRegistry = class
  strict private
    class var FProviders: TDictionary<string, TKXChatProviderClass>;
    class var FLock: TObject;
  public
    class constructor Create;
    class destructor Destroy;
    /// <summary>Registers a provider class under a (case-insensitive) name.</summary>
    class procedure RegisterProvider(const AName: string; const AClass: TKXChatProviderClass);
    /// <summary>Removes a previously registered provider.</summary>
    class procedure UnregisterProvider(const AName: string);
    /// <summary>True if a provider is registered under the given name.</summary>
    class function IsRegistered(const AName: string): Boolean;
    /// <summary>Instantiates the named provider, or the stub provider if the name
    /// is empty/unknown (so the chat always has a working back-end).</summary>
    class function CreateProvider(const AName: string;
      const AProfile: string = ''): IKXChatProvider;
    /// <summary>The names of all registered providers.</summary>
    class function ProviderNames: TArray<string>;
  end;

  /// <summary>
  ///  Default provider (<c>stub</c>): returns a fixed, honest placeholder reply.
  ///  It validates the whole UI/async pipeline end-to-end without any external
  ///  dependency or API key, and is the fallback whenever the configured
  ///  provider name is missing or unknown.
  /// </summary>
  TKXChatStubProvider = class(TKXChatProviderBase)
  public
    function GetName: string; override;
    function Generate(const AHistory: TArray<TKXChatMessage>;
      const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc;
      const ACancel: IKXChatCancelToken): string; override;
  end;

/// <summary>
///  A value of the application as it may enter the system prompt: one line, no
///  control characters, no double quotes (the prompt quotes it), at most
///  <c>AMaxChars</c> characters, with '...' in place of what is cut.
///  <para>Not everything that reaches the prompt is written by the developer:
///  the screen context travels in the request, so the screen label and the
///  controller type are whatever the client posted, and a value that can carry
///  a line break can be made to read like a line of the instructions.</para>
/// </summary>
function KXChatPromptField(const AValue: string; const AMaxChars: Integer = 80): string;

/// <summary>
///  Now, as the system prompt says it: weekday, date and time in the invariant
///  format followed by the offset from UTC - 'Saturday, 15 November 2026, 18:04
///  (UTC+01:00)'.
///  <para>It is the clock of the <b>server</b>, which in a web application is
///  not the clock of whoever is asking. The offset is there so that the instant
///  is unambiguous, and the sentence that carries it says whose clock it is.
///  The zone of the browser is not asked for - that would be a change to the
///  client; when it is asked for, this is the one place to change.</para>
/// </summary>
function KXChatNowText: string;

/// <summary>
///  The opening of the system prompt: who the assistant is and when it is
///  answering. Without it the model has no name of its own - it improvises one,
///  differently each time - and no today: a question about what is due this week
///  is answered from a date it invents, or not answered at all.
///  <para>Either part may be left out and an empty one is skipped; both empty
///  gives an empty string, and the prompt opens with the field of expertise as
///  it did before.</para>
/// </summary>
function KXChatComposeIdentity(const AAssistantName, ANowText: string): string;

/// <summary>
///  Assembles the system prompt of an AI provider: the **identity** (who it is
///  and when), then the **field of expertise**, then the rules, then the rule
///  that governs the field.
///  <para>The order is not a preference and the third piece is not optional. The
///  rules tell the model to answer only from the documentation excerpts, and
///  they win: in the sibling desktop project, where this was measured across
///  several models, declaring a field without that closing rule changed nothing
///  at all. With it, the capable models answered three to five more of twelve
///  questions the manual does not cover — what VAT is, what a pipeline is —
///  while inventing no more features of the application than before.</para>
///  <para>An empty expertise leaves the rules alone: an assistant without a
///  declared field explains the application and nothing else.</para>
/// </summary>
function KXChatComposeSystemPrompt(const AIdentity, AExpertise, ARules: string): string;

/// <summary>
///  English name of a language the prompt can name - 'it' gives 'Italian' - so
///  that the rule about the language of the chat says it in the language the
///  model reads the rest of the prompt in. An English name already written as
///  such is returned as it is, so a configuration may carry either.
///  <para>A code nobody here knows gives an empty string, and the caller leaves
///  the rule out: a rule that says to answer in "nl" is worse than no rule.</para>
/// </summary>
function KXChatLanguageName(const ACodeOrName: string): string;

/// <summary>
///  The rule about the language, appended to the system prompt: the chat speaks
///  <c>AChatLanguage</c>, and the answer is written in it. Both are English
///  names (see <see cref="KXChatLanguageName" />), and an empty chat language
///  gives an empty rule.
///  <para>The language of the question does <b>not</b> override it. It did, and
///  the sibling project dropped that clause: the user picks the language from
///  the flag in the header, and a rule that a few words typed in another
///  language can overturn makes the flag mean nothing. It is also what the
///  search terms assume, since they are asked for in the language of the manual
///  on the strength of the language of the chat.</para>
///  <para>When <c>ADocLanguage</c> is given and differs, a second sentence says
///  that the manual is written in another language: the explanation is
///  translated, the names of screens, menus, buttons and fields are not - a
///  translated caption is a caption the user cannot find on the screen. It is
///  for an application whose screens are not translated, which is why nothing
///  is assumed and it is a setting (<c>HelpChat/DocLanguage</c>).</para>
/// </summary>
function KXChatComposeLanguageRule(const AChatLanguage, ADocLanguage: string): string;

/// <summary>
///  A list of areas of the manual - written with commas, semicolons or spaces -
///  in the form belonging is tested in: lowercase, no blanks, each name between
///  two commas (<c>,invoices,vat,</c>). Empty in, empty out.
/// </summary>
function KXChatNormalizeAreas(const AAreas: string): string;

/// <summary>
///  True when a page may be read by an assistant: when the page declares no
///  area of its own - a page of no area is <b>everybody's</b>, which is what
///  keeps a manual with no areas at all working exactly as before - when the
///  assistant declares none, or when the two have at least one in common.
///  <para>Both arguments are in the normalized form of
///  <see cref="KXChatNormalizeAreas" />.</para>
/// </summary>
function KXChatAreaMatches(const APageAreas, AAssistantAreas: string): Boolean;

/// <summary>
///  The names of the assistants the configuration declares, in the order they
///  are written under <c>HelpChat/Profiles</c>. Empty when there is only the
///  one at the root, which is the usual case and costs nothing.
/// </summary>
function KXChatProfileNames: TArray<string>;

/// <summary>
///  True when <c>AProfile</c> is empty - the assistant at the root - or names
///  one that is declared. Anything else is not an error to report: it is a
///  value from the outside, and it falls back to the root.
/// </summary>
function KXChatIsProfile(const AProfile: string): Boolean;

/// <summary>
///  The full path of a Help Chat setting for one assistant:
///  <c>HelpChat/Profiles/&lt;AProfile&gt;/&lt;ARelativePath&gt;</c> when that node
///  exists, else <c>HelpChat/&lt;ARelativePath&gt;</c>.
///  <para>What decides is whether the node <b>exists</b>, not whether it has a
///  value: a profile that does not name a model must read the one at the root,
///  while a profile that names an empty one means empty. The whole tree works
///  this way, down to the provider sub-nodes
///  (<c>Profiles/Sales/Claude/Model</c>), so an assistant may be answered by
///  another model, with another key, without a second copy of everything
///  else.</para>
/// </summary>
function KXChatSettingPath(const AProfile, ARelativePath: string): string;

/// <summary>The value of a setting for one assistant, macro-expanded (so
/// <c>%ENV(...)%</c> works in a key).</summary>
function KXChatSetting(const AProfile, ARelativePath: string;
  const ADefault: string = ''): string;

/// <summary>The value of a setting for one assistant, not expanded: for the
/// texts that are prompts, where a macro is somebody's words and not a value
/// to resolve.</summary>
function KXChatSettingRaw(const AProfile, ARelativePath: string;
  const ADefault: string = ''): string;

/// <summary>The value of a numeric setting for one assistant.</summary>
function KXChatSettingInteger(const AProfile, ARelativePath: string;
  const ADefault: Integer): Integer;

/// <summary>The value of a yes-or-no setting for one assistant.</summary>
function KXChatSettingBoolean(const AProfile, ARelativePath: string;
  const ADefault: Boolean): Boolean;

/// <summary>
///  The key of a conversation: one per assistant, so that asking the expert of
///  one field and the expert of another does not produce a single thread in
///  which the two answer each other's questions. The conversation of the root
///  assistant keeps the key it always had, which is the user: an application
///  that declares no profile sees no change at all.
/// </summary>
function KXChatConversationKey(const AUser, AProfile: string): string;

/// <summary>
///  True when the application lets the user attach files to a question
///  (<c>HelpChat/Attachments/Enabled</c>). Off unless the application says
///  otherwise: what is attached reaches the provider.
/// </summary>
function KXChatAttachmentsEnabled: Boolean;

/// <summary>
///  The limits of <c>HelpChat/Attachments</c>, read from the configuration in
///  one place, so that the endpoint which accepts a file and the page which
///  announces what it accepts cannot disagree. A limit of zero is no limit.
/// </summary>
function KXChatAttachmentLimits: TKXChatAttachmentLimits;

/// <summary>
///  True when the question is worth turning into search terms before the manual
///  is searched: the chat speaks one language and the manual is written in
///  another. Both are English names (see <see cref="KXChatLanguageName" />);
///  either one empty gives False, so nothing is spent when there is nothing to
///  gain.
///  <para>The trigger is the language of the <b>chat</b>, not the language the
///  question happens to be written in: that is what the user chose, and it is
///  what the answer will be written in.</para>
/// </summary>
function KXChatNeedsSearchTerms(const AChatLanguage, ADocLanguage: string): Boolean;

/// <summary>
///  The prompt that asks the model for one line of words to search the manual
///  with, in the language the manual is written in (<c>ADocLanguage</c>, an
///  English name). The question is appended below it, with the previous one
///  when there is one, because a follow-up ("and to cancel it?") carries none
///  of the words that would find the page.
///  <para>The terms are asked for, not translated word by word, and the prompt
///  says so: the manual spells things its own way, and a literal translation of
///  what the user wrote finds the same nothing in the other language.</para>
///  <para><c>AOverride</c> (<c>HelpChat/SearchTermsPrompt</c>) replaces the
///  built-in instruction; it receives the language as <c>%0:s</c> and is used as
///  it is if it names a placeholder that is not passed.</para>
/// </summary>
function KXChatComposeSearchTermsPrompt(const AQuestion, APreviousQuestion,
  ADocLanguage: string; const AOverride: string = ''): string;

/// <summary>
///  What came back from the model, reduced to what a search can use: a leading
///  label ("Search terms:") dropped, one line, blanks collapsed, and cut to
///  <c>KX_HELPCHAT_SEARCHTERMS_MAXCHARS</c>.
///  <para>The label matters more than it looks: left in, it adds its own words
///  to the query, and in a manual that documents a search screen those words
///  score.</para>
/// </summary>
function KXChatCleanSearchTerms(const AText: string): string;

const
  /// <summary>Name of the always-available stub provider.</summary>
  KX_CHAT_PROVIDER_STUB = 'stub';

implementation

uses
  System.DateUtils,
  System.TimeSpan,
  System.SyncObjs,
  EF.Localization,
  Kitto.Config;

{ TKHelpChatConfig }

function TKHelpChatConfig.GetEnabled: Boolean;
begin
  Result := GetBoolean('Enabled');
end;

{ TKHelpChatAttachmentsConfig }

function TKHelpChatAttachmentsConfig.GetEnabled: Boolean;
begin
  Result := GetBoolean('Enabled', KX_CHAT_DEF_ATTACH_ENABLED);
end;

function TKHelpChatAttachmentsConfig.GetMaxCount: Integer;
begin
  Result := GetInteger('MaxCount', KX_CHAT_DEF_ATTACH_MAXCOUNT);
end;

function TKHelpChatAttachmentsConfig.GetMaxSizeKB: Integer;
begin
  Result := GetInteger('MaxSizeKB', KX_CHAT_DEF_ATTACH_MAXSIZEKB);
end;

function TKHelpChatAttachmentsConfig.GetMaxTotalKB: Integer;
begin
  Result := GetInteger('MaxTotalKB', KX_CHAT_DEF_ATTACH_MAXTOTALKB);
end;

function TKHelpChatAttachmentsConfig.GetImageMaxKB: Integer;
begin
  Result := GetInteger('ImageMaxKB', KX_CHAT_DEF_ATTACH_IMAGEMAXKB);
end;

function TKHelpChatConfig.GetProvider: string;
begin
  Result := GetString('Provider', 'stub');
end;

function TKHelpChatConfig.GetPoolSize: Integer;
begin
  Result := GetInteger('PoolSize', KX_HELPCHAT_DEF_POOLSIZE);
end;

function TKHelpChatConfig.GetMessageMaxLength: Integer;
begin
  Result := GetInteger('MessageMaxLength', KX_HELPCHAT_DEF_MSGMAXLEN);
end;

function TKHelpChatConfig.GetHistoryMaxMessages: Integer;
begin
  Result := GetInteger('HistoryMaxMessages', KX_HELPCHAT_DEF_HISTMAXMSG);
end;

function TKHelpChatConfig.GetMaxStoredMessages: Integer;
begin
  Result := GetInteger('MaxStoredMessages', KX_HELPCHAT_DEF_MAXSTORED);
end;

function TKHelpChatConfig.GetGreeting: string;
begin
  Result := GetString('Greeting', KX_HELPCHAT_DEF_GREETING);
end;

function TKHelpChatConfig.GetAssistantName: string;
begin
  Result := GetString('AssistantName', KX_HELPCHAT_DEF_ASSISTANTNAME);
end;

function TKHelpChatConfig.GetExpertise: string;
begin
  Result := GetString('Expertise');
end;

function TKHelpChatConfig.GetDocLanguage: string;
begin
  Result := GetString('DocLanguage');
end;

function TKHelpChatConfig.GetTranslateSearch: Boolean;
begin
  Result := GetBoolean('TranslateSearch', KX_HELPCHAT_DEF_TRANSLATESEARCH);
end;

function TKHelpChatConfig.GetSearchTermsPrompt: string;
begin
  Result := GetString('SearchTermsPrompt');
end;

function TKHelpChatConfig.GetDocIndex: string;
begin
  Result := GetString('DocIndex');
end;

function TKHelpChatConfig.GetDocBaseUrl: string;
begin
  Result := GetString('DocBaseUrl');
end;

{ TKXChatProviderBase }

constructor TKXChatProviderBase.Create;
begin
  inherited Create;
end;

function TKXChatCancelToken.IsCancelled: Boolean;
begin
  Result := TInterlocked.CompareExchange(FCancelled, 0, 0) <> 0;
end;

procedure TKXChatCancelToken.Cancel;
begin
  TInterlocked.Exchange(FCancelled, 1);
end;

function TKXChatProviderBase.CompleteText(const APrompt: string;
  const AMaxTokens: Integer; const ACancel: IKXChatCancelToken): string;
begin
  Result := '';
end;

function KXChatPromptField(const AValue: string; const AMaxChars: Integer): string;
var
  LSb: TStringBuilder;
  LChar: Char;
  LSpace: Boolean;
begin
  LSb := TStringBuilder.Create;
  try
    LSpace := True; // so that leading blanks are dropped
    for LChar in AValue do
      if LChar <= ' ' then
      begin
        // A run of blanks and control characters becomes one space: this is what
        // keeps the value on a single line.
        if not LSpace then
          LSb.Append(' ');
        LSpace := True;
      end
      else
      begin
        if LChar = '"' then
          LSb.Append('''')
        else
          LSb.Append(LChar);
        LSpace := False;
      end;
    Result := TrimRight(LSb.ToString);
  finally
    LSb.Free;
  end;
  if (AMaxChars > 0) and (Length(Result) > AMaxChars) then
    Result := Copy(Result, 1, AMaxChars - 3) + '...';
end;

function KXChatNowText: string;
var
  LOffset: TTimeSpan;
  LSign: string;
begin
  LOffset := TTimeZone.Local.UtcOffset;
  if LOffset.Ticks < 0 then
    LSign := '-'
  else
    LSign := '+';
  Result := Format('%s (UTC%s%.2d:%.2d)',
    [FormatDateTime('dddd, d mmmm yyyy, hh:nn', Now, TFormatSettings.Invariant),
     LSign, Abs(LOffset.Hours), Abs(LOffset.Minutes)]);
end;

function KXChatComposeIdentity(const AAssistantName, ANowText: string): string;
var
  LName, LNow: string;
begin
  LName := Trim(AAssistantName);
  LNow := Trim(ANowText);
  Result := '';
  if LName <> '' then
    Result := Format(_('Your name is %s.'), [LName]);
  if LNow <> '' then
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + Format(
      _('Now it is %s, by the clock of the server the application runs on.'), [LNow]);
  end;
end;

function KXChatComposeSystemPrompt(const AIdentity, AExpertise, ARules: string): string;
var
  LIdentity, LExpertise, LRules: string;
begin
  LIdentity := Trim(AIdentity);
  LExpertise := Trim(AExpertise);
  LRules := Trim(ARules);
  // Field, rules, rule governing the field — in this order. See the comment on
  // the declaration for why the third piece cannot be left out.
  if LExpertise = '' then
    Result := LRules
  else
    Result := Format(_('Your field of expertise is %s.'), [LExpertise]) + ' ' + LRules + ' ' +
      _('Use your expertise to understand what the user means and to explain the general ' +
        'concepts and good practice of your field, saying that it is general practice and not ' +
        'something of this application. How to do something in THIS application comes only ' +
        'from the documentation excerpts: never invent a screen, field, button, report, ' +
        'automatic feature or behaviour they do not describe. When the application lacks what ' +
        'the user needs, say so and offer the closest thing it does have. A question outside ' +
        'your field and this application: decline it in one sentence.');
  // Who it is and when opens the prompt, before the field and before the rules.
  if LIdentity <> '' then
  begin
    if Result <> '' then
      Result := LIdentity + ' ' + Result
    else
      Result := LIdentity;
  end;
end;

// Codici che il prompt sa nominare. Non sono stringhe di interfaccia: le legge
// il modello, e il nome di una lingua lo riconosce in inglese.
function KXChatLanguageName(const ACodeOrName: string): string;
const
  // Code, English name. The first six are the languages the switcher offers;
  // the others cost nothing and spare a wrong answer where an application ships
  // a catalog of its own.
  LANGUAGES: array[0..25, 0..1] of string = (
    ('en', 'English'), ('it', 'Italian'), ('de', 'German'), ('es', 'Spanish'),
    ('fr', 'French'), ('pt', 'Portuguese'), ('nl', 'Dutch'), ('da', 'Danish'),
    ('sv', 'Swedish'), ('nb', 'Norwegian'), ('no', 'Norwegian'), ('fi', 'Finnish'),
    ('pl', 'Polish'), ('cs', 'Czech'), ('sk', 'Slovak'), ('hu', 'Hungarian'),
    ('ro', 'Romanian'), ('el', 'Greek'), ('ru', 'Russian'), ('uk', 'Ukrainian'),
    ('tr', 'Turkish'), ('ar', 'Arabic'), ('he', 'Hebrew'), ('zh', 'Chinese'),
    ('ja', 'Japanese'), ('ko', 'Korean'));
var
  LValue: string;
  I, LEnd: Integer;
begin
  Result := '';
  LValue := Trim(ACodeOrName);
  if LValue = '' then
    Exit;
  // 'it_IT', 'pt-BR': the code is what comes before the region.
  LEnd := 1;
  while (LEnd <= Length(LValue)) and CharInSet(LValue[LEnd], ['a'..'z', 'A'..'Z']) do
    Inc(LEnd);
  for I := Low(LANGUAGES) to High(LANGUAGES) do
    if SameText(LANGUAGES[I, 0], Copy(LValue, 1, LEnd - 1)) or
       SameText(LANGUAGES[I, 1], LValue) then
      Exit(LANGUAGES[I, 1]);
end;

function KXChatNormalizeAreas(const AAreas: string): string;
var
  LPart: string;
  LParts: TArray<string>;
begin
  Result := '';
  if Trim(AAreas) = '' then
    Exit;
  LParts := AAreas.ToLower.Split([',', ';', ' ', #9, #13, #10]);
  for LPart in LParts do
    if Trim(LPart) <> '' then
      Result := Result + ',' + Trim(LPart);
  if Result <> '' then
    Result := Result + ',';
end;

function KXChatAreaMatches(const APageAreas, AAssistantAreas: string): Boolean;
var
  LArea: string;
begin
  // A page of no area is everybody's, and an assistant of no area reads the
  // whole manual: either way there is nothing to exclude.
  if (APageAreas = '') or (AAssistantAreas = '') then
    Exit(True);
  for LArea in AAssistantAreas.Split([','], TStringSplitOptions.ExcludeEmpty) do
    if APageAreas.Contains(',' + LArea + ',') then
      Exit(True);
  Result := False;
end;

function KXChatProfileNames: TArray<string>;
var
  LNode: TEFNode;
  I: Integer;
begin
  Result := [];
  LNode := TKConfig.Instance.Config.FindNode('HelpChat/Profiles');
  if not Assigned(LNode) then
    Exit;
  SetLength(Result, LNode.ChildCount);
  for I := 0 to LNode.ChildCount - 1 do
    Result[I] := LNode.Children[I].Name;
end;

function KXChatIsProfile(const AProfile: string): Boolean;
begin
  Result := (AProfile = '') or
    Assigned(TKConfig.Instance.Config.FindNode('HelpChat/Profiles/' + AProfile));
end;

function KXChatSettingPath(const AProfile, ARelativePath: string): string;
var
  LPath: string;
begin
  Result := 'HelpChat/' + ARelativePath;
  if AProfile = '' then
    Exit;
  LPath := 'HelpChat/Profiles/' + AProfile + '/' + ARelativePath;
  // The node, not its value: a profile that says nothing about a setting reads
  // the one at the root, and a profile that says it is empty means empty.
  if Assigned(TKConfig.Instance.Config.FindNode(LPath)) then
    Result := LPath;
end;

function KXChatSetting(const AProfile, ARelativePath, ADefault: string): string;
begin
  Result := TKConfig.Instance.Config.GetExpandedString(
    KXChatSettingPath(AProfile, ARelativePath), ADefault);
end;

function KXChatSettingRaw(const AProfile, ARelativePath, ADefault: string): string;
begin
  Result := TKConfig.Instance.Config.GetString(
    KXChatSettingPath(AProfile, ARelativePath), ADefault);
end;

function KXChatSettingInteger(const AProfile, ARelativePath: string;
  const ADefault: Integer): Integer;
begin
  Result := TKConfig.Instance.Config.GetInteger(
    KXChatSettingPath(AProfile, ARelativePath), ADefault);
end;

function KXChatSettingBoolean(const AProfile, ARelativePath: string;
  const ADefault: Boolean): Boolean;
begin
  Result := TKConfig.Instance.Config.GetBoolean(
    KXChatSettingPath(AProfile, ARelativePath), ADefault);
end;

function KXChatConversationKey(const AUser, AProfile: string): string;
begin
  if AProfile = '' then
    Result := AUser
  else
    // A tab: it cannot be typed into a user name, and the key never leaves the
    // server - it is not an id the client ever sees.
    Result := AUser + #9 + AProfile;
end;

procedure TKXChatProviderBase.Configure(const AProfile: string);
begin
  FProfile := AProfile;
end;

function KXChatAttachmentsEnabled: Boolean;
begin
  Result := TKConfig.Instance.Config.GetBoolean('HelpChat/Attachments/Enabled',
    KX_CHAT_DEF_ATTACH_ENABLED);
end;

function KXChatAttachmentLimits: TKXChatAttachmentLimits;

  function KB(const APath: string; const ADefault: Integer): Int64;
  begin
    Result := TKConfig.Instance.Config.GetInteger('HelpChat/Attachments/' + APath, ADefault);
    if Result < 0 then
      Result := 0;
    Result := Result * 1024;
  end;

begin
  Result.MaxCount := TKConfig.Instance.Config.GetInteger('HelpChat/Attachments/MaxCount',
    KX_CHAT_DEF_ATTACH_MAXCOUNT);
  Result.MaxSizeBytes := KB('MaxSizeKB', KX_CHAT_DEF_ATTACH_MAXSIZEKB);
  Result.MaxTotalBytes := KB('MaxTotalKB', KX_CHAT_DEF_ATTACH_MAXTOTALKB);
  Result.MaxImageBytes := KB('ImageMaxKB', KX_CHAT_DEF_ATTACH_IMAGEMAXKB);
end;

function KXChatNeedsSearchTerms(const AChatLanguage, ADocLanguage: string): Boolean;
var
  LChat, LDoc: string;
begin
  LChat := Trim(AChatLanguage);
  LDoc := Trim(ADocLanguage);
  Result := (LChat <> '') and (LDoc <> '') and not SameText(LChat, LDoc);
end;

function KXChatComposeSearchTermsPrompt(const AQuestion, APreviousQuestion,
  ADocLanguage: string; const AOverride: string): string;
var
  LTemplate, LHead: string;
begin
  Result := '';
  if (Trim(AQuestion) = '') or (Trim(ADocLanguage) = '') then
    Exit;

  LTemplate := Trim(AOverride);
  if LTemplate = '' then
    LTemplate := _('The user of an application asks the question below. Write the words someone ' +
      'would search the manual with to find the answer, in %0:s: the terms only, on one line, ' +
      'separated by spaces, with no sentence, no explanation and no punctuation. Use the words ' +
      'the manual is likely to use rather than a literal translation of the question. If the ' +
      'question continues the previous one, take from it only what the question needs.');
  try
    LHead := Format(LTemplate, [ADocLanguage]);
  except
    // A configured prompt that names a placeholder we do not pass is used as it
    // is: a bad setting must cost the terms, not the answer.
    on EConvertError do
      LHead := LTemplate;
  end;

  Result := LHead + sLineBreak + sLineBreak;
  if Trim(APreviousQuestion) <> '' then
    Result := Result + Format(_('Previous question: %s'), [Trim(APreviousQuestion)]) + sLineBreak;
  Result := Result + Format(_('Question: %s'), [Trim(AQuestion)]);
end;

function KXChatCleanSearchTerms(const AText: string): string;
var
  LColon, LWords: Integer;
  LLabel: string;
begin
  Result := Trim(AText);
  if Result = '' then
    Exit;

  // A leading label, which some models write however plainly they are asked not
  // to: a few words and a colon, near the start. Everything after it is kept.
  LColon := Pos(':', Result);
  if (LColon > 1) and (LColon <= 40) then
  begin
    LLabel := Copy(Result, 1, LColon - 1);
    LWords := Length(LLabel.Split([' '], TStringSplitOptions.ExcludeEmpty));
    if (LWords > 0) and (LWords <= 4) then
      Result := Trim(Copy(Result, LColon + 1, MaxInt));
  end;

  Result := KXChatPromptField(Result, KX_HELPCHAT_SEARCHTERMS_MAXCHARS);
end;

function KXChatComposeLanguageRule(const AChatLanguage, ADocLanguage: string): string;
var
  LChat, LDoc: string;
begin
  LChat := Trim(AChatLanguage);
  LDoc := Trim(ADocLanguage);
  Result := '';
  if LChat = '' then
    Exit;
  Result := Format(_('The language of this chat is %0:s. Reply in %0:s.'), [LChat]);
  // The manual in another language than the one the answer is read in: what is
  // explained gets translated, what is written on the screen does not.
  if (LDoc <> '') and not SameText(LDoc, LChat) then
    Result := Result + ' ' + Format(
      _('The documentation excerpts and the application itself are in %0:s, while the user ' +
        'reads your reply in %1:s. Write the explanation in %1:s, but write the names of ' +
        'screens, menus, buttons, fields and options exactly as the documentation spells ' +
        'them, in %0:s, so that the user finds them on the screen; when it helps, add a ' +
        'translation in brackets the first time a name appears.'), [LDoc, LChat]);
end;

{ TKXChatProviderBase }

function TKXChatProviderBase.SupportsDocuments: Boolean;
begin
  // A provider that can take attachments says so: the chat then shows the clip,
  // and tells the user instead of dropping a file the back-end cannot read.
  Result := False;
end;

function TKXChatProviderBase.SupportsStreaming: Boolean;
begin
  Result := False;
end;

{ TKXChatProviderRegistry }

class constructor TKXChatProviderRegistry.Create;
begin
  FLock := TObject.Create;
  FProviders := TDictionary<string, TKXChatProviderClass>.Create;
end;

class destructor TKXChatProviderRegistry.Destroy;
begin
  FProviders.Free;
  FLock.Free;
end;

class procedure TKXChatProviderRegistry.RegisterProvider(const AName: string;
  const AClass: TKXChatProviderClass);
begin
  TMonitor.Enter(FLock);
  try
    FProviders.AddOrSetValue(AName.ToLower, AClass);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TKXChatProviderRegistry.UnregisterProvider(const AName: string);
begin
  TMonitor.Enter(FLock);
  try
    FProviders.Remove(AName.ToLower);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TKXChatProviderRegistry.IsRegistered(const AName: string): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FProviders.ContainsKey(AName.ToLower);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TKXChatProviderRegistry.CreateProvider(const AName: string;
  const AProfile: string): IKXChatProvider;
var
  LClass: TKXChatProviderClass;
begin
  TMonitor.Enter(FLock);
  try
    // Fall back to the stub whenever the configured provider is missing or
    // unknown, so a chat request never fails for a configuration typo.
    if not FProviders.TryGetValue(AName.ToLower, LClass) then
      if not FProviders.TryGetValue(KX_CHAT_PROVIDER_STUB, LClass) then
        LClass := TKXChatStubProvider;
  finally
    TMonitor.Exit(FLock);
  end;
  Result := LClass.Create;
  // Who it answers for, before anything is asked of it.
  (Result as TKXChatProviderBase).Configure(AProfile);
end;

class function TKXChatProviderRegistry.ProviderNames: TArray<string>;
begin
  TMonitor.Enter(FLock);
  try
    Result := FProviders.Keys.ToArray;
  finally
    TMonitor.Exit(FLock);
  end;
end;

{ TKXChatStubProvider }

function TKXChatStubProvider.GetName: string;
begin
  Result := KX_CHAT_PROVIDER_STUB;
end;

function TKXChatStubProvider.Generate(const AHistory: TArray<TKXChatMessage>;
  const AContext: TKXChatContext; const AOnToken: TKXChatTokenProc;
  const ACancel: IKXChatCancelToken): string;
begin
  // Honest placeholder: validates the pipeline (send -> async worker -> reply)
  // without pretending to answer. A real provider replaces it via Config.yaml.
  Result := _('Sorry, I have no elements to help you on this topic at the moment.');
end;

initialization
  TKXChatProviderRegistry.RegisterProvider(KX_CHAT_PROVIDER_STUB, TKXChatStubProvider);

finalization
  if TKXChatProviderRegistry.IsRegistered(KX_CHAT_PROVIDER_STUB) then
    TKXChatProviderRegistry.UnregisterProvider(KX_CHAT_PROVIDER_STUB);

end.
