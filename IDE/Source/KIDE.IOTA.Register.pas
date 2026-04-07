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
unit KIDE.IOTA.Register;

interface

procedure Register;

implementation

uses
  System.SysUtils
  , ToolsAPI
  , DesignIntf
  , KIDE.IOTA.ProjectWizard
  , KIDE.YAMLHighlighter
  ;

procedure Register;
begin
//  ForceDemandLoadState(dlDisable);

  // YAML Syntax Highlighter
  RegisterYAMLHighlighter;

  // KittoX projects.
  RegisterPackageWizard(TVclIOTAProjectWizard.Create);
  RegisterPackageWizard(TWindowsServiceIOTAProjectWizard.Create);
  // Kitto files.
  { TODO : Implement if required. }
  //RegisterPackageWizard(TKModelIOTAProjectWizard.Create);
  //RegisterPackageWizard(TKViewIOTAProjectWizard.Create);

end;

end.

