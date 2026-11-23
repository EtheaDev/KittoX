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

unit Kitto.Vcl.MainForm;

{$I Kitto.Defines.inc}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  System.Actions,
  System.ImageList,
  IdCustomHTTPServer,
  Vcl.Themes,
  Vcl.Styles,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ComCtrls,
  Vcl.ToolWin,
  Vcl.Imaging.pngimage,
  Vcl.ActnList,
  Vcl.StdCtrls,
  Vcl.Buttons,
  Vcl.ExtCtrls,
  Vcl.ImgList,
  Vcl.Tabs,
  Vcl.Grids,
  Kitto.Config,
  EF.Logger,
  Kitto.Types,
  Kitto.Web.Host,
  Kitto.Web.Application,
  Kitto.Web.Session,
  Kitto.Web.Engine;

type
  /// <summary>
  ///  Log endpoint feeding the VCL log memo. DoLog is called on ANY thread (the
  ///  Indy worker that logs), so it only ENQUEUES the message under a lock — the
  ///  VCL is not thread-safe and touching the memo off the main thread corrupts
  ///  it. The MainForm drains the queue onto the memo from a TTimer, i.e. on the
  ///  main thread (async, non-blocking producer). Pattern à la LoggerPro.
  /// </summary>
  TKMainFormLogEndpoint = class(TEFLogEndpoint)
  private
    FLock: TCriticalSection;
    FPending: TStringList;
  protected
    procedure DoLog(const AString: string); override;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
    /// <summary>Moves the messages accumulated so far into ADest and clears the
    /// queue. Call on the main thread (from the flush timer).</summary>
    procedure TakePending(const ADest: TStrings);
  end;

  TKMainForm = class(TForm)
    ActionList: TActionList;
    StartAction: TAction;
    StopAction: TAction;
    PageControl: TPageControl;
    HomeTabSheet: TTabSheet;
    SessionCountLabel: TLabel;
    RestartAction: TAction;
    ConfigFileNameComboBox: TComboBox;
    ConfigLinkLabel: TLabel;
    StartSpeedButton: TSpeedButton;
    StopSpeedButton: TSpeedButton;
    ImageList: TImageList;
    LogMemo: TMemo;
    ControlPanel: TPanel;
    AppTitleLabel: TLabel;
    OpenConfigDialog: TOpenDialog;
    SpeedButton1: TSpeedButton;
    HomeURLLabel: TLabel;
    AppIcon: TImage;
    MainTabSet: TTabSet;
    SessionPanel: TPanel;
    SessionToolPanel: TPanel;
    RefreshButton: TButton;
    SessionListView: TListView;
    SessionListRefreshTimer: TTimer;
    APIURLLabel: TLabel;
    procedure StartActionUpdate(Sender: TObject);
    procedure StopActionUpdate(Sender: TObject);
    procedure StartActionExecute(Sender: TObject);
    procedure StopActionExecute(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure RestartActionUpdate(Sender: TObject);
    procedure RestartActionExecute(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ConfigFileNameComboBoxChange(Sender: TObject);
    procedure ConfigLinkLabelClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure HomeURLLabelClick(Sender: TObject);
    procedure APIURLLabelClick(Sender: TObject);
    procedure MainTabSetChange(Sender: TObject; NewTab: Integer; var AllowChange: Boolean);
    procedure RefreshButtonClick(Sender: TObject);
    procedure SessionListViewEdited(Sender: TObject; Item: TListItem; var S: string);
    procedure SessionListViewInfoTip(Sender: TObject; Item: TListItem; var InfoTip: string);
    procedure SessionListRefreshTimerTimer(Sender: TObject);
  private
    FServer: TKWebHost;
    FApplication: TKWebApplication;
    FRestart: Boolean;
    FLogEndPoint: TKMainFormLogEndpoint;
    FLogFlushTimer: TTimer;
    procedure LogFlushTimerTimer(Sender: TObject);
    procedure ShowTabGUI(const AIndex: Integer);
    procedure UpdateSessionInfo;
    procedure SessionListUpdateHandler(AEngine: TKWebEngine;
      ASessionId: string);
    procedure RecreateServer;
    const
      TAB_LOG = 0;
      TAB_SESSIONS = 1;
    function IsStarted: Boolean;
    procedure FillConfigFileNameCombo;
    procedure SetConfig(const AFileName: string);
    procedure SelectConfigFile;
    procedure DisplayHomeURL(const AHomeURL: string);
    /// <summary>Shows the first server link published via TKXServerLinkRegistry
    /// (e.g. the REST Swagger UI), expanding '{apibase}' with the configured
    /// RestBasePath; hides APIURLLabel when no link is registered.</summary>
    procedure DisplayAPIURL(const AHomeURL: string);
    function HasConfigFileName: Boolean;
    procedure DoLog(const AString: string);
  end;

var
  KMainForm: TKMainForm;

implementation

{$R *.dfm}

uses
  System.Math,
  System.StrUtils,
  System.DateUtils,
  System.UITypes,
  EF.Sys,
  EF.Sys.Windows,
  EF.Shell,
  EF.Localization,
  Kitto.Web.Routing.Registry;

const
  // Index of the trailing SubItem that carries the session id in the session
  // list. There is no column for it, so it is not displayed.
  SESSION_ID_SUBITEM = 5;

{ TKMainForm }

procedure TKMainForm.RefreshButtonClick(Sender: TObject);
begin
  UpdateSessionInfo;
end;

procedure TKMainForm.ConfigLinkLabelClick(Sender: TObject);
begin
  SelectConfigFile;
end;

procedure TKMainForm.SelectConfigFile;
begin
  OpenConfigDialog.InitialDir := TKConfig.AppHomePath;
  if OpenConfigDialog.Execute then
  begin
    // The Home is the parent directory of the Metadata directory.
    TKConfig.AppHomePath := ExtractFilePath(OpenConfigDialog.FileName) + '..';
    Caption := TKConfig.AppHomePath;
    FillConfigFileNameCombo;
    SetConfig(ExtractFileName(OpenConfigDialog.FileName));
  end;
end;

procedure TKMainForm.SessionListRefreshTimerTimer(Sender: TObject);
begin
  UpdateSessionInfo;
end;

procedure TKMainForm.SessionListViewEdited(Sender: TObject; Item: TListItem;
  var S: string);
begin
  // Renamed BY ID, under the sessions lock. The session may have expired and
  // been freed since the list was drawn, so the item must not carry a pointer
  // to it — see the comment in UpdateSessionInfo.
  if Assigned(Item) and (Item.SubItems.Count > SESSION_ID_SUBITEM) and IsStarted then
    FServer.Engine.SetSessionDisplayName(Item.SubItems[SESSION_ID_SUBITEM], S);
end;

procedure TKMainForm.SessionListViewInfoTip(Sender: TObject; Item: TListItem; var InfoTip: string);
begin
  // Straight from the values already copied into the item: no session object is
  // touched, so a session freed meanwhile cannot crash the hint.
  if Assigned(Item) and (Item.SubItems.Count > SESSION_ID_SUBITEM) then
    InfoTip :=
      'User Agent: ' + Item.SubItems[4] + sLineBreak +
      'Client Address: ' + Item.SubItems[3] + sLineBreak +
      'Last Request: ' + Item.SubItems[1];
end;

procedure TKMainForm.DoLog(const AString: string);
begin
  // Direct GUI-local log lines (always on the main thread). Framework log lines
  // from worker threads go through TKMainFormLogEndpoint's queue + the flush timer.
  LogMemo.Lines.Add(AString);
end;

procedure TKMainForm.LogFlushTimerTimer(Sender: TObject);
const
  MAX_LOG_LINES = 5000;
begin
  if not Assigned(FLogEndPoint) then
    Exit;
  LogMemo.Lines.BeginUpdate;
  try
    FLogEndPoint.TakePending(LogMemo.Lines);
    // Keep the memo bounded during a long-running session.
    while LogMemo.Lines.Count > MAX_LOG_LINES do
      LogMemo.Lines.Delete(0);
  finally
    LogMemo.Lines.EndUpdate;
  end;
end;

procedure TKMainForm.StopActionExecute(Sender: TObject);
begin
  if IsStarted then
  begin
    DoLog(_('Stopping listener...'));
    FServer.Active := False;
    DoLog(_('Listener stopped'));
    HomeURLLabel.Visible := False;
    APIURLLabel.Visible := False;
    while IsStarted do
      Vcl.Forms.Application.ProcessMessages;
    if FRestart then
    begin
      FRestart := False;
      StartAction.Execute;
    end;
  end;
  UpdateSessionInfo;
end;

procedure TKMainForm.StopActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := IsStarted;
end;

procedure TKMainForm.MainTabSetChange(Sender: TObject; NewTab: Integer;
  var AllowChange: Boolean);
begin
  ShowTabGUI(NewTab);
  UpdateSessionInfo;
  SessionListRefreshTimer.Enabled := MainTabSet.TabIndex = TAB_SESSIONS;
end;

procedure TKMainForm.ShowTabGUI(const AIndex: Integer);
begin
  case AIndex of
    TAB_LOG:
      LogMemo.BringToFront;

    TAB_SESSIONS:
    begin
      UpdateSessionInfo;
      SessionPanel.BringToFront;
    end;
  end;
end;

procedure TKMainForm.RestartActionExecute(Sender: TObject);
begin
  FRestart := True;
  StopAction.Execute;
end;

procedure TKMainForm.RestartActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := IsStarted;
end;

procedure TKMainForm.UpdateSessionInfo;

  procedure UpdateCount(const ACount: Integer);
  begin
    SessionCountLabel.Caption := Format('Active Sessions: %d', [ACount]);
  end;

  procedure AddItem(const ACaption: string);
  var
    LItem: TListItem;
  begin
    LItem := SessionListView.Items.Add;
    LItem.Caption := ACaption;
  end;

  function FormatStamp(const AValue: TDateTime): string;
  begin
    if AValue = 0 then
      Result := '-'
    else if DateOf(AValue) = Date then
      Result := TimeToStr(TimeOf(AValue))
    else
      Result := DateTimeToStr(AValue);
  end;

var
  LInfos: TArray<TKWebSessionInfo>;
  LInfo: TKWebSessionInfo;
  LItem: TListItem;
begin
  // Built from COPIED values, never from session objects. The cleanup thread
  // frees expired sessions, so a TKWebSession pointer read on this (GUI) thread
  // after the sessions lock was released is a dangling one — which is what
  // produced access violations here, as Windows exception dialogs that the
  // request pipeline and the log never saw. GetSessionInfos copies everything
  // under the lock; the session id travels in a trailing SubItem with no column
  // of its own (so it does not show) and is all the InfoTip and rename handlers
  // need.
  SessionListView.Clear;
  if not IsStarted then
  begin
    AddItem(_('Inactive'));
    UpdateCount(0);
    Exit;
  end;

  LInfos := FServer.Engine.GetSessionInfos;
  UpdateCount(Length(LInfos));
  if Length(LInfos) = 0 then
  begin
    AddItem(_('None'));
    Exit;
  end;

  for LInfo in LInfos do
  begin
    LItem := SessionListView.Items.Add;
    LItem.Caption := LInfo.DisplayName;
    LItem.SubItems.Add(FormatStamp(LInfo.CreationDateTime));   // Start Time
    LItem.SubItems.Add(FormatStamp(LInfo.LastRequestDateTime)); // Last Req
    LItem.SubItems.Add(LInfo.UserName);                         // User
    LItem.SubItems.Add(LInfo.ClientAddress);                    // Origin
    LItem.SubItems.Add(LInfo.UserAgent);                        // User Agent
    LItem.SubItems.Add(LInfo.Id);                               // SESSION_ID_SUBITEM
  end;
end;

function TKMainForm.HasConfigFileName: Boolean;
begin
  Result := ConfigFileNameComboBox.Text <> '';
end;

procedure TKMainForm.HomeURLLabelClick(Sender: TObject);
begin
  OpenDocument(HomeURLLabel.Caption);
end;

function TKMainForm.IsStarted: Boolean;
begin
  Result := Assigned(FServer) and FServer.Active;
end;

procedure TKMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  StopAction.Execute;
end;

procedure TKMainForm.SessionListUpdateHandler(AEngine: TKWebEngine; ASessionId: string);
begin
  UpdateSessionInfo;
end;

procedure TKMainForm.FormCreate(Sender: TObject);
var
  LDefaultConfig: string;
begin
  //Bold Title label
  AppTitleLabel.Font.Style := AppTitleLabel.Font.Style + [fsBold];
  //Read command line param -config
  LDefaultConfig := ChangeFileExt(GetCmdLineParamValue('Config', TKConfig.BaseConfigFileName),'.yaml');
  if LDefaultConfig <> '' then
    TKConfig.BaseConfigFileName := LDefaultConfig;

  RecreateServer;

  FLogEndPoint := TKMainFormLogEndpoint.Create;
  // Drain the endpoint's queue onto the memo on the main thread.
  FLogFlushTimer := TTimer.Create(Self);
  FLogFlushTimer.Interval := 150;
  FLogFlushTimer.OnTimer := LogFlushTimerTimer;
  FLogFlushTimer.Enabled := True;

  UpdateSessionInfo;
end;

procedure TKMainForm.FormDestroy(Sender: TObject);
begin
  FServer.Active := False;
  SessionListView.Clear;
  // Stop the flush timer before freeing the endpoint, so no timer tick touches a
  // freed endpoint; then free the endpoint (which detaches from TEFLogger).
  FreeAndNil(FLogFlushTimer);
  FreeAndNil(FServer);
  FreeAndNil(FLogEndPoint);
end;

procedure TKMainForm.FormShow(Sender: TObject);
begin
  ShowTabGUI(TAB_LOG);
  Caption := TKConfig.AppHomePath;
  DoLog(Format(_('Build date: %s'), [DateTimeToStr(GetFileDateTime(ParamStr(0)))]));
  FillConfigFileNameCombo;
  if HasConfigFileName then
    StartAction.Execute
  else
    SelectConfigFile;
end;

procedure TKMainForm.ConfigFileNameComboBoxChange(Sender: TObject);
begin
  SetConfig(ConfigFileNameComboBox.Text);
end;

procedure TKMainForm.SetConfig(const AFileName: string);
var
  LWasStarted: Boolean;
  LAppIconFileName: string;
begin
  LWasStarted := IsStarted;
  if LWasStarted then
    StopAction.Execute;
  ConfigFileNameComboBox.ItemIndex := ConfigFileNameComboBox.Items.IndexOf(AFileName);
  TKConfig.BaseConfigFileName := AFileName;
  FApplication.ReloadConfig;
  AppTitleLabel.Caption := Format(_('Application: %s'), [_(FApplication.Config.AppTitle)]);
  LAppIconFileName := FApplication.FindResourcePathName(FApplication.Config.AppIcon + '.png');
  if LAppIconFileName <> '' then
    AppIcon.Picture.LoadFromFile(LAppIconFileName)
  else
    AppIcon.Picture.Bitmap := nil;
  StartAction.Update;
  if LWasStarted then
    StartAction.Execute;
end;

procedure TKMainForm.DisplayHomeURL(const AHomeURL: string);
begin
  DoLog(Format(_('Home URL: %s'), [AHomeURL]));
  HomeURLLabel.Caption := AHomeURL;
  HomeURLLabel.Visible := True;
end;

procedure TKMainForm.DisplayAPIURL(const AHomeURL: string);
var
  LLinks: TArray<TKXServerLink>;
  LSub, LFull: string;
begin
  // The REST/Swagger support is opt-in: it publishes a server link via
  // TKXServerLinkRegistry (core), so the form neither depends on the REST unit
  // nor hardcodes any '/api/v4' string. No link registered → hide the label.
  LLinks := TKXServerLinkRegistry.Links;
  if Length(LLinks) = 0 then
  begin
    APIURLLabel.Visible := False;
    Exit;
  end;
  // Expand the '{apibase}' placeholder with the app's configured REST base path,
  // then append it to the home URL (which ends with '/').
  LSub := ReplaceStr(LLinks[0].PathTemplate, '{apibase}', FApplication.Config.RestBasePath);
  LFull := AHomeURL;
  if (LFull <> '') and (LFull[Length(LFull)] = '/') then
    LFull := Copy(LFull, 1, Length(LFull) - 1);
  LFull := LFull + LSub;
  APIURLLabel.Caption := LFull;
  APIURLLabel.OnClick := APIURLLabelClick;
  APIURLLabel.Visible := True;
  DoLog(Format('%s: %s', [LLinks[0].Caption, LFull]));
end;

procedure TKMainForm.APIURLLabelClick(Sender: TObject);
begin
  OpenDocument(APIURLLabel.Caption);
end;

procedure TKMainForm.FillConfigFileNameCombo;
var
  LConfigIndex: Integer;
  LConfigFileName: string;
begin
  FindAllFiles('yaml', TKConfig.GetMetadataPath, ConfigFileNameComboBox.Items, False, False);
  if ConfigFileNameComboBox.Items.Count > 0 then
  begin
    LConfigFileName := TKConfig.BaseConfigFileName;
    LConfigIndex := ConfigFileNameComboBox.Items.IndexOf(LConfigFileName);
    if LConfigIndex <> -1 then
    begin
      ConfigFileNameComboBox.ItemIndex := LConfigIndex;
      ConfigFileNameComboBoxChange(ConfigFileNameComboBox);
    end
    else
    begin
      ConfigFileNameComboBox.ItemIndex := 0;
      ConfigFileNameComboBoxChange(ConfigFileNameComboBox);
    end;
  end;
end;

procedure TKMainForm.StartActionExecute(Sender: TObject);
begin
  RecreateServer;
  FServer.Active := True;
  SessionCountLabel.Visible := True;
  DoLog(_('Listener started'));
  var LHomeURL: string := FApplication.GetHomeURL(FServer.DefaultPort);
  DisplayHomeURL(LHomeURL);
  DisplayAPIURL(LHomeURL);
  UpdateSessionInfo;
end;

procedure TKMainForm.StartActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := HasConfigFileName and not IsStarted;
end;

procedure TKMainForm.RecreateServer;
begin
  FreeAndNil(FServer);

  FServer := TKWebHost.CreateDefault;
  FServer.Engine.OnSessionStart := SessionListUpdateHandler;
  FServer.Engine.OnSessionEnd := SessionListUpdateHandler;
  FApplication := FServer.Engine.AddRoute(TKWebApplication.Create) as TKWebApplication;
  FServer.Setup(FApplication.Config);
end;

{ TKMainFormLogEndpoint }

procedure TKMainFormLogEndpoint.AfterConstruction;
begin
  // Create the queue BEFORE inherited (which attaches to TEFLogger and may start
  // receiving DoLog from other threads immediately).
  FLock := TCriticalSection.Create;
  FPending := TStringList.Create;
  inherited;
end;

destructor TKMainFormLogEndpoint.Destroy;
begin
  inherited; // detaches from TEFLogger: no more DoLog after this
  FreeAndNil(FPending);
  FreeAndNil(FLock);
end;

procedure TKMainFormLogEndpoint.DoLog(const AString: string);
begin
  // Any thread: just enqueue; the GUI timer flushes to the memo on the main thread.
  FLock.Enter;
  try
    FPending.Add(AString);
  finally
    FLock.Leave;
  end;
end;

procedure TKMainFormLogEndpoint.TakePending(const ADest: TStrings);
begin
  FLock.Enter;
  try
    if FPending.Count > 0 then
    begin
      ADest.AddStrings(FPending);
      FPending.Clear;
    end;
  finally
    FLock.Leave;
  end;
end;

end.
