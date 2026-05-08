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
  // YAML Syntax Highlighter
  RegisterYAMLHighlighter;

  // KittoX projects — one entry per supported deployment mode under
  // File / New / Other / KittoX Projects. The BDS 37 gallery sorts items
  // alphabetically with no public priority API, so the desired display
  // order is enforced via the "1. " / "2. " / "3. " / "4. " prefix on
  // each wizard's Name (see KIDE.IOTA.ProjectWizard).
  RegisterPackageWizard(TStandaloneIOTAProjectWizard.Create);
  RegisterPackageWizard(TDesktopIOTAProjectWizard.Create);
  RegisterPackageWizard(TIsapiIOTAProjectWizard.Create);
  RegisterPackageWizard(TApacheIOTAProjectWizard.Create);
end;

end.

