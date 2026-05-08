{*******************************************************************}
{                                                                   }
{   KIDE Editor: GUI for Kitto                                      }
{                                                                   }
{   Copyright (c) 2012-2026 Ethea S.r.l.                            }
{   ALL RIGHTS RESERVED / TUTTI I DIRITTI RISERVATI                 }
{                                                                   }
{*******************************************************************}
{                                                                   }
{   The entire contents of this file is protected by                }
{   International Copyright Laws. Unauthorized reproduction,        }
{   reverse-engineering, and distribution of all or any portion of  }
{   the code contained in this file is strictly prohibited and may  }
{   result in severe civil and criminal penalties and will be       }
{   prosecuted to the maximum extent possible under the law.        }
{                                                                   }
{   RESTRICTIONS                                                    }
{                                                                   }
{   THE SOURCE CODE CONTAINED WITHIN THIS FILE AND ALL RELATED      }
{   FILES OR ANY PORTION OF ITS CONTENTS SHALL AT NO TIME BE        }
{   COPIED, TRANSFERRED, SOLD, DISTRIBUTED, OR OTHERWISE MADE       }
{   AVAILABLE TO OTHER INDIVIDUALS WITHOUT EXPRESS WRITTEN CONSENT  }
{   AND PERMISSION FROM ETHEA S.R.L.                                }
{                                                                   }
{   CONSULT THE END USER LICENSE AGREEMENT FOR INFORMATION ON       }
{   ADDITIONAL RESTRICTIONS.                                        }
{                                                                   }
{*******************************************************************}
{                                                                   }
{   Il contenuto di questo file è protetto dalle leggi              }
{   internazionali sul Copyright. Sono vietate la riproduzione, il  }
{   reverse-engineering e la distribuzione non autorizzate di tutto }
{   o parte del codice contenuto in questo file. Ogni infrazione    }
{   sarà perseguita civilmente e penalmente a termini di legge.     }
{                                                                   }
{   RESTRIZIONI                                                     }
{                                                                   }
{   SONO VIETATE, SENZA IL CONSENSO SCRITTO DA PARTE DI             }
{   ETHEA S.R.L., LA COPIA, LA VENDITA, LA DISTRIBUZIONE E IL       }
{   TRASFERIMENTO A TERZI, A QUALUNQUE TITOLO, DEL CODICE SORGENTE  }
{   CONTENUTO IN QUESTO FILE E ALTRI FILE AD ESSO COLLEGATI.        }
{                                                                   }
{   SI FACCIA RIFERIMENTO ALLA LICENZA D'USO PER INFORMAZIONI SU    }
{   EVENTUALI RESTRIZIONI ULTERIORI.                                }
{                                                                   }
{*******************************************************************}
unit KIDE.NewProjectWizardFormUnit;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Actions,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ActnList,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Buttons,
  Vcl.Samples.Spin,
  Vcl.Mask,
  KIDE.BaseWizardFormUnit,
  KIDE.BaseFrameUnit,
  KIDE.ProjectTemplate,
  KIDE.ProjectTemplateFrameUnit
  ;

type
  TNewProjectWizardForm = class(TBaseWizardForm)
    SelectTabSheet: TTabSheet;
    OptionsTabSheet: TTabSheet;
    GoTabSheet: TTabSheet;
    TemplateFrame: TProjectTemplateFrame;
    TemplateSplitter: TSplitter;
    TemplateInfoPanel: TPanel;
    ProjectPathEdit: TLabeledEdit;
    ProjectPathButton: TSpeedButton;
    TemplateInfoRichEdit: TRichEdit;
    ProjectNameEdit: TLabeledEdit;
    DoneTabSheet: TTabSheet;
    ProjectCreatedRichEdit: TRichEdit;
    AppTitleEdit: TLabeledEdit;
    DatabasesGroupBox: TGroupBox;
    DBFDCheckBox: TCheckBox;
    DBADOCheckBox: TCheckBox;
    DBDBXCheckBox: TCheckBox;
    AccessControlGroupBox: TGroupBox;
    AuthenticationtypeLabel: TLabel;
    AuthComboBox: TComboBox;
    UseJWTCheckBox: TCheckBox;
    AccessControltypeLabel: TLabel;
    ACComboBox: TComboBox;
    ServerGroupBox: TGroupBox;
    PortLabel: TLabel;
    ServerPortEdit: TSpinEdit;
    ThreadPoolSizeLabel: TLabel;
    ServerThreadPoolSizeEdit: TSpinEdit;
    SessionTimeOutLabel: TLabel;
    ServerSessionTimeOutEdit: TSpinEdit;
    LanguageGroupBox: TGroupBox;
    LanguageLabel: TLabel;
    LanguageIdComboBox: TComboBox;
    CharsetLabel: TLabel;
    CharsetComboBox: TComboBox;
    AppTypeTabSheet: TTabSheet;
    DeploymentGroupBox: TGroupBox;
    DeployStandaloneCheckBox: TCheckBox;
    DeployDesktopCheckBox: TCheckBox;
    DeployISAPICheckBox: TCheckBox;
    DeployApacheCheckBox: TCheckBox;
    ProjectTemplatesPathEdit: TLabeledEdit;
    ProjectTemplatesPathButton: TSpeedButton;
    procedure FormCreate(Sender: TObject);
    procedure ProjectPathButtonClick(Sender: TObject);
    procedure ProjectNameEditChange(Sender: TObject);
    procedure ProjectPathEditExit(Sender: TObject);
    procedure ProjectTemplatesPathButtonClick(Sender: TObject);
  private
    FTemplate: TProjectTemplate;
    FPreSelectDeployMode: string;
    FProjectTemplatesPath: string;
    function GetDefaultProjectTemplatesPath: string;
    procedure UpdateTemplateList(const ASelectTemplateName: string);
    procedure UpdateTemplateInfo;
    procedure TemplateListDblClick(Sender: TObject);
    procedure TemplateChange(Sender: TObject);
    procedure SaveOptionsMRU;
    function GetKeyBase: string;
    function OptionsValid: Boolean;
    function DeployModeValid: Boolean;
    function ProjectTemplatesPathValid: Boolean;
    procedure LoadOptionsMRU;
    procedure LoadDeployMRU;
    procedure SaveDeployMRU;
    procedure SaveProjectMRU;
    procedure LoadProjectMRU;
    procedure FreeTemplate;
  protected
    procedure AfterEnterPage(const ACurrentPageIndex: Integer;
      const AOldPageIndex: Integer; const AGoingForward: Boolean); override;
    procedure AfterLeavePage(const AOldPageIndex: Integer;
      const ACurrentPageIndex: Integer; const AGoingForward: Boolean); override;
    function CanGoForward: Boolean; override;
    procedure BeforeLeavePage(const ACurrentPageIndex: Integer;
      const ANewPageIndex: Integer; const AGoingForward: Boolean); override;
    procedure InitWizard; override;
  public
    class function ShowDialog(out AProjectFileName: string): Boolean; overload;
    class function ShowDialog(out AProjectTemplate: TProjectTemplate): Boolean; overload;
    class function ShowDialog(out AProjectTemplate: TProjectTemplate;
      const APreSelectDeployMode: string): Boolean; overload;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetProjectFileName: string;
  end;

implementation

{$R *.dfm}

uses
  Vcl.FileCtrl,
  System.IOUtils,
  EF.Localization,
  EF.Sys.Windows,
  EF.StrUtils,
  KIDE.MRUOptions,
  KIDE.Config;

const
  // Visual order is fixed at runtime in FormCreate via TTabSheet.PageIndex,
  // so these match the post-FormCreate page positions, not the dfm order.
  PAGE_DEPLOY_MODE = 0;  // also hosts the ProjectTemplates path picker
  PAGE_TEMPLATE = 1;     // Basic / Empty list, populated from the path above
  PAGE_OPTIONS = 2;
  PAGE_PROJECT = 3;
  PAGE_DONE = 4;

{ TNewProjectWizardForm }

procedure TNewProjectWizardForm.AfterEnterPage(const ACurrentPageIndex,
  AOldPageIndex: Integer; const AGoingForward: Boolean);
begin
  inherited;
  if ACurrentPageIndex = PAGE_TEMPLATE then
  begin
    PageTitle := _('Choose a Project Template');
    if AGoingForward then
      UpdateTemplateList(TMRUOptions.Instance.GetString(GetKeyBase + 'DefaultTemplateName'))
    else
      UpdateTemplateList(TemplateFrame.CurrentTemplateName);
  end
  else if ACurrentPageIndex = PAGE_DEPLOY_MODE then
  begin
    PageTitle := _('Choose Deployment modes and ProjectTemplates folder');
    LoadDeployMRU;
  end
  else if ACurrentPageIndex = PAGE_OPTIONS then
  begin
    PageTitle := _('Set Template Options');
    LoadOptionsMRU;
  end
  else if ACurrentPageIndex = PAGE_PROJECT then
  begin
    PageTitle := _('Select Project Name and Directory');
    LoadProjectMRU;
  end
  else if ACurrentPageIndex = PAGE_DONE then
  begin
    PageTitle := _('Project created successfully');
    ProjectCreatedRichEdit.Lines.LoadFromFile(FTemplate.GetSupportFileName('AfterCreate.rtf'));
  end;
end;

procedure TNewProjectWizardForm.AfterLeavePage(const AOldPageIndex,
  ACurrentPageIndex: Integer; const AGoingForward: Boolean);
begin
  inherited;
  if (AOldPageIndex = PAGE_TEMPLATE) and AGoingForward then
    TMRUOptions.Instance.StoreString(GetKeyBase + 'DefaultTemplateName', TemplateFrame.CurrentTemplateName)
  else if (AOldPageIndex = PAGE_DEPLOY_MODE) and AGoingForward then
    SaveDeployMRU
  else if (AOldPageIndex = PAGE_OPTIONS) and AGoingForward then
    SaveOptionsMRU
  else if (AOldPageIndex = PAGE_PROJECT) and AGoingForward then
    SaveProjectMRU;
end;

procedure TNewProjectWizardForm.BeforeLeavePage(const ACurrentPageIndex,
  ANewPageIndex: Integer; const AGoingForward: Boolean);
begin
  inherited;
  if (ACurrentPageIndex = PAGE_TEMPLATE) and AGoingForward then
  begin
    FTemplate.TemplateDirectory := IncludeTrailingPathDelimiter(FProjectTemplatesPath) + TemplateFrame.CurrentTemplateName;
    if not System.SysUtils.DirectoryExists(FTemplate.TemplateDirectory) then
      raise Exception.CreateFmt('Directory %s not found.', [FTemplate.TemplateDirectory]);
  end
  else if (ACurrentPageIndex = PAGE_DEPLOY_MODE) and AGoingForward then
  begin
    // Capture the ProjectTemplates folder chosen on this page; the next page
    // (template list) enumerates its subfolders to populate Basic/Empty/...
    FProjectTemplatesPath := IncludeTrailingPathDelimiter(ProjectTemplatesPathEdit.Text);
    // Deployment selection: which .dpr/.dproj variants to keep in the
    // generated project. ProjectTemplate deletes the others post-copy.
    FTemplate.Options.SetBoolean('Deploy/Standalone', DeployStandaloneCheckBox.Checked);
    FTemplate.Options.SetBoolean('Deploy/Desktop', DeployDesktopCheckBox.Checked);
    FTemplate.Options.SetBoolean('Deploy/ISAPI', DeployISAPICheckBox.Checked);
    FTemplate.Options.SetBoolean('Deploy/Apache', DeployApacheCheckBox.Checked);
  end
  else if (ACurrentPageIndex = PAGE_OPTIONS) and AGoingForward then
  begin
    // KittoX uses a single .dpr/.dproj per project (Win64), so the
    // wizard no longer collects Delphi version flags. Likewise no
    // SearchPath: it is hardcoded in the template's .dproj.
    FTemplate.Options.SetBoolean('DB/ADO', DBADOCheckBox.Checked);
    FTemplate.Options.SetBoolean('DB/DBX', DBDBXCheckBox.Checked);
    FTemplate.Options.SetBoolean('DB/FD', DBFDCheckBox.Checked);

    FTemplate.Options.SetString('Auth', AuthComboBox.Text);
    // JWT envelope flag: when True, Config.yaml gets `Auth: JWT / Inner:
    // <Auth>` instead of `Auth: <Auth>` directly. Recommended for new
    // KittoX projects (signed cookie + sliding refresh).
    FTemplate.Options.SetBoolean('UseJWT', UseJWTCheckBox.Checked);
    FTemplate.Options.SetString('AC', ACComboBox.Text);
    FTemplate.Options.SetString('LanguageId', LanguageIdComboBox.Text);
    FTemplate.Options.SetString('Charset', CharsetComboBox.Text);
    FTemplate.Options.SetInteger('Server/Port', ServerPortEdit.Value);
    FTemplate.Options.SetInteger('Server/ThreadPoolSize', ServerThreadPoolSizeEdit.Value);
    FTemplate.Options.SetInteger('Server/SessionTimeOut', ServerSessionTimeOutEdit.Value);
  end
  else if (ACurrentPageIndex = PAGE_PROJECT) and AGoingForward then
  begin
    FTemplate.ProjectDirectory := ProjectPathEdit.Text;
    if System.SysUtils.DirectoryExists(FTemplate.ProjectDirectory) and not IsDirectoryEmpty(FTemplate.ProjectDirectory) then
    begin
      if MessageDlg(_('The chosen directory is not empty. Files may be overwritten. Are you sure you want to continue?'), mtWarning, [mbYes, mbNo], 0) <> mrYes then
        Abort;
    end;
    FTemplate.ProjectName := ProjectNameEdit.Text;
    FTemplate.Options.SetString('AppTitle', AppTitleEdit.Text);
    FTemplate.CreateProject;
  end;
end;

function TNewProjectWizardForm.GetKeyBase: string;
begin
  Result := 'NewProjectWizard/';
end;

function TNewProjectWizardForm.GetProjectFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(FTemplate.ProjectDirectory) + 'Home' + PathDelim + FTemplate.ProjectName + '.kproj';
end;

procedure TNewProjectWizardForm.InitWizard;
begin
  inherited;
  // The base TBaseWizardForm hardcodes 900x700 from a Config-tree node that
  // is never persisted, so user resizing has no effect across sessions.
  // Override with TMRUOptions which is actually saved to disk, and use a
  // smaller default that fits the wizard content (470 x 410 px).
  Width := TMRUOptions.Instance.GetInteger(GetKeyBase + 'FormWidth', 484);
  Height := TMRUOptions.Instance.GetInteger(GetKeyBase + 'FormHeight', 453);

  TKideConfig.Instance.Config.GetNode('Authentication/Authenticators').GetChildValues(AuthComboBox.Items);
  TKideConfig.Instance.Config.GetNode('AccessControl/AccessControllers').GetChildValues(ACComboBox.Items);
  TKideConfig.Instance.Config.GetNode('LanguageIds').GetChildValues(LanguageIdComboBox.Items);
  TKideConfig.Instance.Config.GetNode('Charsets').GetChildValues(CharsetComboBox.Items);
end;

function TNewProjectWizardForm.GetDefaultProjectTemplatesPath: string;
var
  LHome: string;
begin
  // Fallback chain for the ProjectTemplates folder shown on PAGE_DEPLOY_MODE
  // when no MRU value exists yet:
  //   1. %KITTOX_HOME%\ProjectTemplates\  if the env var is set
  //   2. TKideConfig.Instance.TemplatePath  (sane for KIDEX standalone)
  LHome := GetEnvironmentVariable('KITTOX_HOME');
  if LHome <> '' then
    Result := IncludeTrailingPathDelimiter(LHome) + 'ProjectTemplates' + PathDelim
  else
    Result := TKideConfig.Instance.TemplatePath;
end;

procedure TNewProjectWizardForm.LoadDeployMRU;
const
  PATH_KEY = 'NewProjectWizard/ProjectTemplatesPath';
  DEPLOY_KEY = 'NewProjectWizard/Deploy/';
begin
  // Page 0 runs before the user picks Basic/Empty, so deploy + path are
  // saved under template-independent keys.
  ProjectTemplatesPathEdit.Text := TMRUOptions.Instance.GetString(PATH_KEY,
    GetDefaultProjectTemplatesPath);
  if FPreSelectDeployMode <> '' then
  begin
    // IDE plugin invocation: a single deployment was picked from the
    // File / New / Other gallery; pre-check only that one and lock the
    // groupbox so the user can't accidentally widen the choice.
    DeployStandaloneCheckBox.Checked := SameText(FPreSelectDeployMode, 'Standalone');
    DeployDesktopCheckBox.Checked := SameText(FPreSelectDeployMode, 'Desktop');
    DeployISAPICheckBox.Checked := SameText(FPreSelectDeployMode, 'ISAPI');
    DeployApacheCheckBox.Checked := SameText(FPreSelectDeployMode, 'Apache');
    DeploymentGroupBox.Enabled := False;
  end
  else
  begin
    // Deployment defaults: only Standalone (.exe) selected by default.
    DeployStandaloneCheckBox.Checked := TMRUOptions.Instance.GetBoolean(DEPLOY_KEY + 'Standalone', True);
    DeployDesktopCheckBox.Checked := TMRUOptions.Instance.GetBoolean(DEPLOY_KEY + 'Desktop', False);
    DeployISAPICheckBox.Checked := TMRUOptions.Instance.GetBoolean(DEPLOY_KEY + 'ISAPI', False);
    DeployApacheCheckBox.Checked := TMRUOptions.Instance.GetBoolean(DEPLOY_KEY + 'Apache', False);
    DeploymentGroupBox.Enabled := True;
  end;
end;

procedure TNewProjectWizardForm.SaveDeployMRU;
const
  PATH_KEY = 'NewProjectWizard/ProjectTemplatesPath';
  DEPLOY_KEY = 'NewProjectWizard/Deploy/';
begin
  TMRUOptions.Instance.SetString(PATH_KEY, ProjectTemplatesPathEdit.Text);
  TMRUOptions.Instance.SetBoolean(DEPLOY_KEY + 'Standalone', DeployStandaloneCheckBox.Checked);
  TMRUOptions.Instance.SetBoolean(DEPLOY_KEY + 'Desktop', DeployDesktopCheckBox.Checked);
  TMRUOptions.Instance.SetBoolean(DEPLOY_KEY + 'ISAPI', DeployISAPICheckBox.Checked);
  TMRUOptions.Instance.SetBoolean(DEPLOY_KEY + 'Apache', DeployApacheCheckBox.Checked);
  TMRUOptions.Instance.Save;
end;

procedure TNewProjectWizardForm.LoadOptionsMRU;
var
  LKeyBase: string;
begin
  LKeyBase := GetKeyBase + TemplateFrame.CurrentTemplateName + '/';
  // Database defaults: only FireDAC
  DBFDCheckBox.Checked := TMRUOptions.Instance.GetBoolean(LKeyBase + 'DB/FD', True);
  DBADOCheckBox.Checked := TMRUOptions.Instance.GetBoolean(LKeyBase + 'DB/ADO', False);
  DBDBXCheckBox.Checked := TMRUOptions.Instance.GetBoolean(LKeyBase + 'DB/DBX', False);
  // Auth, default TextFile — works out of the box against the demo
  // FileAuthenticator.txt shipped with the template; user can switch
  // to DB once a credentials table is set up.
  AuthComboBox.Text := TMRUOptions.Instance.GetString(LKeyBase + 'Auth', 'TextFile');
  // Use JWT, default true
  UseJWTCheckBox.Checked := TMRUOptions.Instance.GetBoolean(LKeyBase + 'UseJWT', True);
  // Access Control, default Null — a brand-new project has no
  // KITTO_PERMISSIONS table yet so JWT closed-world or DB evaluation
  // would deny every request after login. User can switch later.
  ACComboBox.Text := TMRUOptions.Instance.GetString(LKeyBase + 'AC', 'Null');
  // Language, default 'en'
  LanguageIdComboBox.Text := TMRUOptions.Instance.GetString(LKeyBase + 'LanguageId', 'en');
  // Charset, default 'utf-8'
  CharsetComboBox.Text := TMRUOptions.Instance.GetString(LKeyBase + 'Charset', 'utf-8');
  // Server Port, default 8080
  ServerPortEdit.Value := TMRUOptions.Instance.GetInteger(LKeyBase + 'Server/Port', 8080);
  ServerThreadPoolSizeEdit.Value := TMRUOptions.Instance.GetInteger(LKeyBase + 'Server/ThreadPoolSize', 20);
  ServerSessionTimeOutEdit.Value := TMRUOptions.Instance.GetInteger(LKeyBase + 'Server/SessionTimeOut', 10);
end;

procedure TNewProjectWizardForm.SaveOptionsMRU;
var
  LKeyBase: string;
begin
  LKeyBase := GetKeyBase + TemplateFrame.CurrentTemplateName + '/';
  TMRUOptions.Instance.SetBoolean(LKeyBase + 'DB/ADO', DBADOCheckBox.Checked);
  TMRUOptions.Instance.SetBoolean(LKeyBase + 'DB/DBX', DBDBXCheckBox.Checked);
  TMRUOptions.Instance.SetBoolean(LKeyBase + 'DB/FD', DBFDCheckBox.Checked);
  TMRUOptions.Instance.SetString(LKeyBase + 'Auth', AuthComboBox.Text);
  TMRUOptions.Instance.SetBoolean(LKeyBase + 'UseJWT', UseJWTCheckBox.Checked);
  TMRUOptions.Instance.SetString(LKeyBase + 'AC', ACComboBox.Text);
  TMRUOptions.Instance.SetString(LKeyBase + 'LanguageId', LanguageIdComboBox.Text);
  TMRUOptions.Instance.SetString(LKeyBase + 'Charset', CharsetComboBox.Text);
  TMRUOptions.Instance.SetInteger(LKeyBase + 'Server/Port', ServerPortEdit.Value);
  TMRUOptions.Instance.SetInteger(LKeyBase + 'Server/ThreadPoolSize', ServerThreadPoolSizeEdit.Value);
  TMRUOptions.Instance.SetInteger(LKeyBase + 'Server/SessionTimeOut', ServerSessionTimeOutEdit.Value);
  TMRUOptions.Instance.Save;
end;

procedure TNewProjectWizardForm.LoadProjectMRU;
var
  LKeyBase: string;
begin
  LKeyBase := GetKeyBase + TemplateFrame.CurrentTemplateName + '/';
  ProjectPathEdit.Text := TMRUOptions.Instance.GetString(LKeyBase + 'ProjectPath');
  ProjectNameEdit.Text := TMRUOptions.Instance.GetString(LKeyBase + 'ProjectName');
end;

procedure TNewProjectWizardForm.SaveProjectMRU;
var
  LKeyBase: string;
begin
  LKeyBase := GetKeyBase + TemplateFrame.CurrentTemplateName + '/';
  TMRUOptions.Instance.SetString(LKeyBase + 'ProjectPath', ProjectPathEdit.Text);
  TMRUOptions.Instance.SetString(LKeyBase + 'ProjectName', ProjectNameEdit.Text);
  TMRUOptions.Instance.Save;
end;

function TNewProjectWizardForm.CanGoForward: Boolean;
begin
  if PageIndex = PAGE_TEMPLATE then
    Result := TemplateFrame.CurrentTemplateName <> ''
  else if PageIndex = PAGE_DEPLOY_MODE then
    Result := DeployModeValid and ProjectTemplatesPathValid
  else if PageIndex = PAGE_OPTIONS then
    Result := OptionsValid
  else if PageIndex = PAGE_PROJECT then
    Result := (ProjectPathEdit.Text <> '') and (ProjectNameEdit.Text <> '')
  else
    Result := inherited CanGoForward;
end;

function TNewProjectWizardForm.DeployModeValid: Boolean;
begin
  Result :=
    DeployStandaloneCheckBox.Checked or
    DeployDesktopCheckBox.Checked or
    DeployISAPICheckBox.Checked or
    DeployApacheCheckBox.Checked;
end;

function TNewProjectWizardForm.ProjectTemplatesPathValid: Boolean;
begin
  Result := (ProjectTemplatesPathEdit.Text <> '')
    and System.SysUtils.DirectoryExists(ProjectTemplatesPathEdit.Text);
end;

function TNewProjectWizardForm.OptionsValid: Boolean;
begin
  // At least one DB driver should be active to make
  Result := DBFDCheckBox.Checked or
    DBADOCheckBox.Checked or
    DBDBXCheckBox.Checked;
end;

constructor TNewProjectWizardForm.Create(AOwner: TComponent);
begin
  inherited;
  FTemplate := TProjectTemplate.Create;
end;

destructor TNewProjectWizardForm.Destroy;
begin
  // Persist current form size so the next invocation reopens at the same
  // dimensions. InitWizard reads these back via TMRUOptions.
  TMRUOptions.Instance.SetInteger(GetKeyBase + 'FormWidth', Width);
  TMRUOptions.Instance.SetInteger(GetKeyBase + 'FormHeight', Height);
  TMRUOptions.Instance.Save;
  FreeAndNil(FTemplate);
  inherited;
end;

procedure TNewProjectWizardForm.FormCreate(Sender: TObject);
begin
  inherited;
  TemplateFrame.OnChange := TemplateChange;
  TemplateFrame.OnDblClick := TemplateListDblClick;
end;

procedure TNewProjectWizardForm.FreeTemplate;
begin
  FreeAndNil(FTemplate);
end;

procedure TNewProjectWizardForm.TemplateListDblClick(Sender: TObject);
begin
  ForwardAction.Execute;
end;

procedure TNewProjectWizardForm.TemplateChange(Sender: TObject);
begin
  UpdateTemplateInfo;
end;

class function TNewProjectWizardForm.ShowDialog(out AProjectFileName: string): Boolean;
var
  LForm: TNewProjectWizardForm;
begin
  LForm := TNewProjectWizardForm.Create(Application);
  try
    Result := LForm.ShowModal = mrOk;
    if Result then
      AProjectFileName := LForm.GetProjectFileName
    else
      AProjectFileName := '';
  finally
    FreeAndNil(LForm);
  end;
end;

class function TNewProjectWizardForm.ShowDialog(out AProjectTemplate: TProjectTemplate): Boolean;
begin
  Result := ShowDialog(AProjectTemplate, '');
end;

class function TNewProjectWizardForm.ShowDialog(out AProjectTemplate: TProjectTemplate;
  const APreSelectDeployMode: string): Boolean;
var
  LForm: TNewProjectWizardForm;
begin
  AProjectTemplate := nil;
  LForm := TNewProjectWizardForm.Create(Application);
  try
    LForm.FPreSelectDeployMode := APreSelectDeployMode;
    Result := LForm.ShowModal = mrOk;
    if Result then
    begin
      // Transfer ownership of the template to the caller and null out the
      // form's field so its Destroy (called by the FreeAndNil below) does
      // NOT free the object we just handed over. Without this, the IOTA
      // pipeline calling FTemplate.ProjectName during CreateModule hits
      // an access violation on freed memory.
      AProjectTemplate := LForm.FTemplate;
      LForm.FTemplate := nil;
    end
    else
      LForm.FreeTemplate;
  finally
    FreeAndNil(LForm);
  end;
end;

procedure TNewProjectWizardForm.ProjectNameEditChange(Sender: TObject);
begin
  inherited;
  AppTitleEdit.Text := CamelToSpaced(ProjectNameEdit.Text);
end;

procedure TNewProjectWizardForm.ProjectPathButtonClick(Sender: TObject);
var
  LDirectory: string;
begin
  inherited;
  LDirectory := ProjectPathEdit.Text;
  if SelectDirectory(_('Select a directory'), '', LDirectory, [sdNewFolder, sdShowEdit, sdNewUI, sdValidateDir]) then
  begin
    ProjectPathEdit.Text := LDirectory;
    ProjectNameEdit.Text := ExtractFileName(LDirectory);
  end;
end;

procedure TNewProjectWizardForm.ProjectPathEditExit(Sender: TObject);
begin
  inherited;
  if ProjectNameEdit.Text = '' then
  begin
    ProjectNameEdit.Text := ExtractFileName(ProjectPathEdit.Text);
  end;
end;

procedure TNewProjectWizardForm.ProjectTemplatesPathButtonClick(Sender: TObject);
var
  LDirectory: string;
begin
  inherited;
  LDirectory := ProjectTemplatesPathEdit.Text;
  if SelectDirectory(_('Select the ProjectTemplates folder'), '', LDirectory,
       [sdShowEdit, sdNewUI, sdValidateDir]) then
    ProjectTemplatesPathEdit.Text := LDirectory;
end;

procedure TNewProjectWizardForm.UpdateTemplateList(
  const ASelectTemplateName: string);
begin
  TemplateFrame.UpdateList(FProjectTemplatesPath, ASelectTemplateName);
  UpdateTemplateInfo;
end;

procedure TNewProjectWizardForm.UpdateTemplateInfo;
var
  LBase: string;
begin
  TemplateInfoRichEdit.Clear;
  if TemplateFrame.CurrentTemplateName <> '' then
  begin
    // FProjectTemplatesPath is set when leaving PAGE_DEPLOY_MODE; if the user
    // somehow reaches PAGE_TEMPLATE first (programmatic navigation, etc.)
    // fall back to TKideConfig so we don't dereference an empty string.
    if FProjectTemplatesPath <> '' then
      LBase := FProjectTemplatesPath
    else
      LBase := TKideConfig.Instance.TemplatePath;
    FTemplate.TemplateDirectory := IncludeTrailingPathDelimiter(LBase) + TemplateFrame.CurrentTemplateName;
    if FileExists(FTemplate.GetSupportFileName('Info.rtf')) then
      TemplateInfoRichEdit.Lines.LoadFromFile(FTemplate.GetSupportFileName('Info.rtf'));
  end;
end;

end.
