{ -------------------------------------------------------------------------------
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
  ------------------------------------------------------------------------------- }

{ -------------------------------------------------------------------------------
  Based on code by David Hoyle
  http://www.davidghoyle.co.uk/
  ------------------------------------------------------------------------------- }
unit KIDE.IOTA.ProjectWizard;

interface

uses
  ToolsAPI;

type
  TIOTAProjectWizard = class(
    TNotifierObject
    , IOTAWizard
    , IOTARepositoryWizard
    , IOTARepositoryWizard60
    , IOTARepositoryWizard80
    , IOTAProjectWizard
    , IOTAProjectWizard100
  )
  strict protected
    // Deployment mode pre-selected by this gallery entry (Standalone, Desktop,
    // ISAPI, Apache). Passed to the wizard form so its Deploy page shows
    // exactly that one ticked, and used to pick the right .dproj file to open.
    function GetDeployMode: string; virtual; abstract;
  public
    const
      GALLERY_PAGE = 'KittoX Projects';
      ID_STRING = 'KittoX';
    constructor Create;

    // IOTAWizard
    procedure Execute;
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;
    function GetIDString: string; virtual; abstract;
    function GetName: string; virtual; abstract;
    function GetState: TWizardState;

    // IOTARepositoryWizard
    function GetAuthor: string;
    function GetComment: string; virtual; abstract;
    function GetGlyph: {$if compilerversion < 35}Cardinal{$else}THandle{$endif};
    function GetPage: string;

    // IOTARepositoryWizard60
    function GetDesigner: string;

    // IOTARepositoryWizard80
    function GetGalleryCategory: IOTAGalleryCategory;
    function GetPersonality: string;

    // IOTAProjectWizard100
    function IsVisible(Project: IOTAProject): Boolean;
  end;

  // Standalone Windows App / Service (.exe) — embedded Indy HTTP server.
  TStandaloneIOTAProjectWizard = class(TIOTAProjectWizard)
  strict protected
    function GetDeployMode: string; override;
  public
    function GetName: string; override;
    function GetIDString: string; override;
    function GetComment: string; override;
  end;

  // Windows Desktop App (.exe) — Indy server + embedded WebView2 form.
  TDesktopIOTAProjectWizard = class(TIOTAProjectWizard)
  strict protected
    function GetDeployMode: string; override;
  public
    function GetName: string; override;
    function GetIDString: string; override;
    function GetComment: string; override;
  end;

  // ISAPI Module (.dll) — IIS-hosted via Web.Win.ISAPIApp + WebBroker.
  TIsapiIOTAProjectWizard = class(TIOTAProjectWizard)
  strict protected
    function GetDeployMode: string; override;
  public
    function GetName: string; override;
    function GetIDString: string; override;
    function GetComment: string; override;
  end;

  // Apache Module (.dll) — Apache-hosted via Web.ApacheApp + WebBroker.
  TApacheIOTAProjectWizard = class(TIOTAProjectWizard)
  strict protected
    function GetDeployMode: string; override;
  public
    function GetName: string; override;
    function GetIDString: string; override;
    function GetComment: string; override;
  end;

implementation

uses
  WinApi.Windows
  , System.SysUtils
  , Vcl.Dialogs
  , KIDE.NewProjectWizardFormUnit
  , KIDE.ProjectTemplate
  , KIDE.IOTA.ProjectCreator
  ;

{ TIOTAProjectWizard }

constructor TIOTAProjectWizard.Create;
var
  LCategoryServices: IOTAGalleryCategoryManager;
begin
  inherited Create;
  LCategoryServices := BorlandIDEServices as IOTAGalleryCategoryManager;
  LCategoryServices.AddCategory(LCategoryServices.FindCategory(sCategoryDelphiNew), ID_STRING, GALLERY_PAGE);
end;

procedure TIOTAProjectWizard.Execute;
var
  LProjectTemplate: TProjectTemplate;
  LDprojPath: string;
begin
  if TNewProjectWizardForm.ShowDialog(LProjectTemplate, GetDeployMode) then
  begin
    try
      // The wizard's PAGE_PROJECT BeforeLeavePage already wrote every .dpr,
      // .dproj, .pas and resource for the selected deployments to disk via
      // FTemplate.CreateProject. We just need the IDE to OPEN the .dproj
      // that matches the deployment picked in the gallery — no IOTA project
      // creator dance (which fights with the IDE's MSBProject construction
      // and crashes inside TBaseDelphiProject.Create / DocModul.ValidateIdent).
      LDprojPath := GetDprojFileNameForDeployMode(LProjectTemplate, GetDeployMode);
      if FileExists(LDprojPath) then
        (BorlandIDEServices as IOTAActionServices).OpenProject(LDprojPath, True)
      else
        ShowMessageFmt('Generated .dproj not found: %s', [LDprojPath]);
    finally
      FreeAndNIl(LProjectTemplate);
    end;
  end;
end;

function TIOTAProjectWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TIOTAProjectWizard.AfterSave;
begin
end;

procedure TIOTAProjectWizard.BeforeSave;
begin
end;

procedure TIOTAProjectWizard.Destroyed;
begin
end;

procedure TIOTAProjectWizard.Modified;
begin
end;

function TIOTAProjectWizard.GetAuthor: string;
begin
  Result := 'Ethea S.r.l.';
end;

function TIOTAProjectWizard.GetGlyph: {$if compilerversion < 35}Cardinal{$else}THandle{$endif};
begin
  Result := LoadIcon(HInstance, PChar(GetIDString.Replace('.', '')));
end;

function TIOTAProjectWizard.GetPage: string;
begin
  Result := GALLERY_PAGE;
end;

function TIOTAProjectWizard.GetDesigner: string;
begin
  Result := dAny;
end;

function TIOTAProjectWizard.GetGalleryCategory: IOTAGalleryCategory;
begin
  Result := (BorlandIDEServices as IOTAGalleryCategoryManager).FindCategory(ID_STRING);
end;

function TIOTAProjectWizard.GetPersonality: string;
begin
  Result := sDelphiPersonality;
end;

function TIOTAProjectWizard.IsVisible(Project: IOTAProject): Boolean;
begin
  Result := True;
end;

{ TStandaloneIOTAProjectWizard }

function TStandaloneIOTAProjectWizard.GetComment: string;
begin
  Result := 'Creates a new KittoX standalone Windows application (.exe) that ' +
    'auto-detects whether to run as a Windows Service or a VCL desktop GUI. ' +
    'Uses the embedded Indy HTTP server. Recommended for production deployment.';
end;

function TStandaloneIOTAProjectWizard.GetDeployMode: string;
begin
  Result := 'Standalone';
end;

function TStandaloneIOTAProjectWizard.GetIDString: string;
begin
  // The BDS 37 gallery sorts entries alphabetically by IDString (NOT by
  // visible Name). The .1./.2./.3./.4. infix forces the display order
  // Standalone → Desktop → ISAPI → Apache. The infix is invisible to users.
  Result := ID_STRING + '.1.Standalone.Application';
end;

function TStandaloneIOTAProjectWizard.GetName: string;
begin
  Result := 'KittoX Windows App / Service (.exe)';
end;

{ TDesktopIOTAProjectWizard }

function TDesktopIOTAProjectWizard.GetComment: string;
begin
  Result := 'Creates a new KittoX desktop Windows application (.exe) with an ' +
    'embedded WebView2 form pointing at the integrated Indy HTTP server. ' +
    'Useful for standalone single-user desktop deployments.';
end;

function TDesktopIOTAProjectWizard.GetDeployMode: string;
begin
  Result := 'Desktop';
end;

function TDesktopIOTAProjectWizard.GetIDString: string;
begin
  Result := ID_STRING + '.2.Desktop.Application';
end;

function TDesktopIOTAProjectWizard.GetName: string;
begin
  Result := 'KittoX Windows Desktop App (.exe)';
end;

{ TIsapiIOTAProjectWizard }

function TIsapiIOTAProjectWizard.GetComment: string;
begin
  Result := 'Creates a new KittoX ISAPI module (.dll) hosted by IIS via the ' +
    'Web.Win.ISAPIApp + WebBroker bridge. Suitable for IIS deployments.';
end;

function TIsapiIOTAProjectWizard.GetDeployMode: string;
begin
  Result := 'ISAPI';
end;

function TIsapiIOTAProjectWizard.GetIDString: string;
begin
  Result := ID_STRING + '.3.ISAPI.Library';
end;

function TIsapiIOTAProjectWizard.GetName: string;
begin
  Result := 'KittoX ISAPI Module (.dll)';
end;

{ TApacheIOTAProjectWizard }

function TApacheIOTAProjectWizard.GetComment: string;
begin
  Result := 'Creates a new KittoX Apache module (.dll) hosted by Apache via the ' +
    'Web.ApacheApp + WebBroker bridge. Suitable for Apache deployments.';
end;

function TApacheIOTAProjectWizard.GetDeployMode: string;
begin
  Result := 'Apache';
end;

function TApacheIOTAProjectWizard.GetIDString: string;
begin
  Result := ID_STRING + '.4.Apache.Library';
end;

function TApacheIOTAProjectWizard.GetName: string;
begin
  Result := 'KittoX Apache Module (.dll)';
end;

end.
