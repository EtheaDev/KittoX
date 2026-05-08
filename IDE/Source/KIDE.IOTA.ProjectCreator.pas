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
unit KIDE.IOTA.ProjectCreator;

// The KittoXIDE plugin no longer implements an IOTAProjectCreator. The template
// engine has already written every .dpr/.dproj/.pas file to disk by the time
// the wizard returns; the IDE plugin asks the IDE to OPEN the existing .dproj
// via IOTAActionServices.OpenProject (see KIDE.IOTA.ProjectWizard.Execute).
//
// All that remains here are two helpers that map the chosen deployment mode
// to the corresponding filenames produced by TProjectTemplate.

interface

uses
  KIDE.ProjectTemplate;

/// <summary>Returns the absolute .dpr path for the given deployment mode
/// (Standalone / Desktop / ISAPI / Apache).</summary>
function GetDprFileNameForDeployMode(const ATemplate: TProjectTemplate;
  const ADeployMode: string): string;

/// <summary>Returns the absolute .dproj path matching GetDprFileNameForDeployMode.</summary>
function GetDprojFileNameForDeployMode(const ATemplate: TProjectTemplate;
  const ADeployMode: string): string;

implementation

uses
  System.SysUtils,
  System.IOUtils;

function ProjectBaseName(const ATemplate: TProjectTemplate;
  const ADeployMode: string): string;
begin
  // Mirrors the deployment-variant filenames in TProjectTemplate.CreateProject.
  if SameText(ADeployMode, 'Apache') then
    Result := 'mod_' + LowerCase(ATemplate.ProjectName)
  else if SameText(ADeployMode, 'ISAPI') then
    Result := ATemplate.ProjectName + 'ISAPI'
  else if SameText(ADeployMode, 'Desktop') then
    Result := ATemplate.ProjectName + 'Desktop'
  else // 'Standalone' or empty default
    Result := ATemplate.ProjectName;
end;

function ProjectsFolder(const ATemplate: TProjectTemplate): string;
begin
  // KittoX templates ship .dpr/.dproj under <ProjectDirectory>\Projects\.
  Result := TPath.Combine(ATemplate.ProjectDirectory, 'Projects');
end;

function GetDprFileNameForDeployMode(const ATemplate: TProjectTemplate;
  const ADeployMode: string): string;
begin
  Result := TPath.Combine(ProjectsFolder(ATemplate),
    ProjectBaseName(ATemplate, ADeployMode) + '.dpr');
end;

function GetDprojFileNameForDeployMode(const ATemplate: TProjectTemplate;
  const ADeployMode: string): string;
begin
  Result := TPath.Combine(ProjectsFolder(ATemplate),
    ProjectBaseName(ATemplate, ADeployMode) + '.dproj');
end;

end.
