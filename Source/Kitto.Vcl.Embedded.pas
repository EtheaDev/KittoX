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
///  Desktop embedded mode for KittoX applications. Creates a VCL form with
///  a TEdgeBrowser that loads the KittoX app from an in-process HTTP server
///  on localhost. The result is a native desktop application with no visible
///  browser chrome (no address bar, tabs, or bookmarks).
///  Requires WebView2 Runtime (preinstalled on Windows 10 21H2+ and Windows 11).
///
///  Window properties are read from the Config.yaml "Desktop" node:
///    Desktop:
///      ClientWidth: 1000       # default 1000
///      ClientHeight: 900       # default 900
///      Maximized: False        # default False — if True, starts maximized
///      Resizable: True         # default True — if False, removes sizing border
///      BorderIcons:
///        biSystemMenu: True    # default True
///        biMinimize: True      # default True
///        biMaximize: True      # default True
///        biHelp: False         # default False
///      Position: poScreenCenter  # default poScreenCenter
/// </summary>
unit Kitto.Vcl.Embedded;

{$I Kitto.Defines.inc}

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.Edge,
  Vcl.OleCtrls,
  Kitto.Config,
  Kitto.Web.Server,
  Kitto.Web.Application;

type
  TKEmbeddedForm = class(TForm)
  private
    FServer: TKWebServer;
    FApplication: TKWebApplication;
    FBrowser: TEdgeBrowser;
    FHomeURL: string;
    FNavigatedToHome: Boolean;
    procedure CreateServer;
    procedure StartServer;
    procedure StopServer;
    procedure CreateBrowser;
    procedure ApplyDesktopConfig;
    procedure DoFormCreate(Sender: TObject);
    procedure DoFormShow(Sender: TObject);
    procedure DoFormDestroy(Sender: TObject);
    procedure DoFormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure BrowserCreateWebViewCompleted(Sender: TCustomEdgeBrowser;
      AResult: HRESULT);
    procedure BrowserNavigationCompleted(Sender: TCustomEdgeBrowser;
      IsSuccess: Boolean; WebErrorStatus: TOleEnum);
    procedure BrowserDocumentTitleChanged(Sender: TCustomEdgeBrowser;
      const ADocumentTitle: string);
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
  end;

  TKEmbeddedStart = class
  public
    /// <summary>
    ///  Starts the desktop embedded application.
    ///  AConfigFileName: optional config file name (e.g. 'ConfigDesktop.yaml').
    ///  If empty, looks for 'ConfigDesktop.yaml' in the Metadata folder;
    ///  if not found, falls back to the default Config.yaml resolution.
    /// </summary>
    class procedure Start(const AConfigFileName: string = '');
  end;

implementation

uses
  System.IOUtils,
  System.TypInfo,
  EF.Tree,
  EF.Logger,
  EF.Macros,
  EF.Sys,
  EF.Sys.Windows;

{ TKEmbeddedForm }

constructor TKEmbeddedForm.Create(AOwner: TComponent);
begin
  // Skip DFM resource lookup — redirect to CreateNew
  CreateNew(AOwner);
end;

constructor TKEmbeddedForm.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited CreateNew(AOwner, Dummy);
  OnCreate := DoFormCreate;
  OnShow := DoFormShow;
  OnDestroy := DoFormDestroy;
  OnCloseQuery := DoFormCloseQuery;

  // Sensible defaults before config is loaded
  Position := poScreenCenter;
  ClientWidth := 1000;
  ClientHeight := 900;
  Caption := 'KittoX';
end;

procedure TKEmbeddedForm.DoFormCreate(Sender: TObject);
begin
  CreateServer;
  ApplyDesktopConfig;
  StartServer;
end;

procedure TKEmbeddedForm.DoFormShow(Sender: TObject);
begin
  // Create browser after the form is visible — WebView2 needs a visible
  // parent window to initialize and render correctly.
  OnShow := nil; // run only once
  CreateBrowser;
end;

procedure TKEmbeddedForm.DoFormDestroy(Sender: TObject);
begin
  StopServer;
  FreeAndNil(FServer);
end;

procedure TKEmbeddedForm.DoFormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := True;
end;

procedure TKEmbeddedForm.CreateServer;
begin
  FServer := TKWebServer.Create(nil);
  FApplication := FServer.Engine.AddRoute(TKWebApplication.Create) as TKWebApplication;
  FServer.Setup(FApplication.Config);
end;

procedure TKEmbeddedForm.ApplyDesktopConfig;
var
  LDesktopNode, LBorderNode: TEFNode;
  LIcons: TBorderIcons;
  LPositionStr: string;
  LPositionValue: Integer;
begin
  LDesktopNode := FApplication.Config.Config.FindNode('Desktop');
  if not Assigned(LDesktopNode) then
    Exit;

  // ClientWidth / ClientHeight
  ClientWidth := LDesktopNode.GetInteger('ClientWidth', ClientWidth);
  ClientHeight := LDesktopNode.GetInteger('ClientHeight', ClientHeight);

  // Maximized
  if LDesktopNode.GetBoolean('Maximized', False) then
    WindowState := wsMaximized;

  // Resizable
  if not LDesktopNode.GetBoolean('Resizable', True) then
    BorderStyle := bsSingle;

  // BorderIcons
  LBorderNode := LDesktopNode.FindNode('BorderIcons');
  if Assigned(LBorderNode) then
  begin
    LIcons := [];
    if LBorderNode.GetBoolean('biSystemMenu', True) then
      Include(LIcons, biSystemMenu);
    if LBorderNode.GetBoolean('biMinimize', True) then
      Include(LIcons, biMinimize);
    if LBorderNode.GetBoolean('biMaximize', True) then
      Include(LIcons, biMaximize);
    if LBorderNode.GetBoolean('biHelp', False) then
      Include(LIcons, biHelp);
    BorderIcons := LIcons;
  end;

  // Position
  LPositionStr := LDesktopNode.GetString('Position');
  if LPositionStr <> '' then
  begin
    LPositionValue := GetEnumValue(TypeInfo(TPosition), LPositionStr);
    if LPositionValue >= 0 then
      Position := TPosition(LPositionValue);
  end;
end;

procedure TKEmbeddedForm.StartServer;
begin
  FServer.Active := True;
  FHomeURL := FApplication.GetHomeURL(FServer.DefaultPort);
  TEFLogger.Instance.Log('Embedded server started: ' + FHomeURL);
end;

procedure TKEmbeddedForm.StopServer;
begin
  if Assigned(FServer) and FServer.Active then
  begin
    FServer.Active := False;
    TEFLogger.Instance.Log('Embedded server stopped');
  end;
end;

procedure TKEmbeddedForm.CreateBrowser;
begin
  FBrowser := TEdgeBrowser.Create(Self);
  FBrowser.UserDataFolder := TPath.Combine(TPath.GetTempPath,
    ChangeFileExt(ExtractFileName(ParamStr(0)), ''));
  FBrowser.Parent := Self;
  FBrowser.Align := alClient;
  FNavigatedToHome := False;
  FBrowser.OnCreateWebViewCompleted := BrowserCreateWebViewCompleted;
  FBrowser.OnNavigationCompleted := BrowserNavigationCompleted;
  FBrowser.OnDocumentTitleChanged := BrowserDocumentTitleChanged;
  // Trigger WebView2 initialization with about:blank;
  // the real navigation to FHomeURL happens in OnNavigationCompleted
  FBrowser.Navigate('about:blank');
end;

procedure TKEmbeddedForm.BrowserCreateWebViewCompleted(
  Sender: TCustomEdgeBrowser; AResult: HRESULT);
begin
  if AResult <> S_OK then
    TEFLogger.Instance.Log('WebView2 initialization failed: ' + IntToHex(AResult));
end;

procedure TKEmbeddedForm.BrowserNavigationCompleted(
  Sender: TCustomEdgeBrowser; IsSuccess: Boolean; WebErrorStatus: TOleEnum);
begin
  // After about:blank completes, navigate to the real app URL (once)
  if not FNavigatedToHome and (FHomeURL <> '') then
  begin
    FNavigatedToHome := True;
    FBrowser.Navigate(FHomeURL);
  end;
end;

procedure TKEmbeddedForm.BrowserDocumentTitleChanged(
  Sender: TCustomEdgeBrowser; const ADocumentTitle: string);
begin
  if ADocumentTitle <> '' then
    Caption := ADocumentTitle;
end;

{ TKEmbeddedStart }

class procedure TKEmbeddedStart.Start(const AConfigFileName: string);
const
  DEFAULT_DESKTOP_CONFIG = 'ConfigDesktop.yaml';
var
  LEmbeddedForm: TKEmbeddedForm;

  procedure ResolveConfigFileName;
  var
    LFileName: string;
  begin
    // 1. Explicit parameter
    if AConfigFileName <> '' then
      LFileName := AConfigFileName
    // 2. Command-line -c switch
    else
    begin
      LFileName := GetCmdLineParamValue('c');
      // 3. Default ConfigDesktop.yaml if it exists
      if LFileName = '' then
      begin
        if FileExists(TPath.Combine(TKConfig.GetMetadataPath, DEFAULT_DESKTOP_CONFIG)) then
          LFileName := DEFAULT_DESKTOP_CONFIG;
        // 4. Otherwise leave empty — TKConfig falls back to its own resolution (Config.yaml)
      end;
    end;
    if LFileName <> '' then
      TKConfig.BaseConfigFileName := LFileName;
  end;

  procedure Configure;
  var
    LConfig: TKConfig;
    LLogNode: TEFNode;
  begin
    ResolveConfigFileName;
    LConfig := TKConfig.Create;
    try
      LLogNode := LConfig.Config.FindNode('Log');
      TEFLogger.Instance.Configure(LLogNode, TEFMacroExpansionEngine.Instance);
    finally
      FreeAndNil(LConfig);
    end;
  end;

begin
  Configure;
  TEFLogger.Instance.Log('Starting as desktop application.');
  Vcl.Forms.Application.Initialize;
  Vcl.Forms.Application.MainFormOnTaskbar := True;
  Vcl.Forms.Application.CreateForm(TKEmbeddedForm, LEmbeddedForm);
  Vcl.Forms.Application.Run;
end;

initialization
  {$WARN SYMBOL_PLATFORM OFF}
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;

end.
