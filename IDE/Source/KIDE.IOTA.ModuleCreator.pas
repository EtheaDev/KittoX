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
unit KIDE.IOTA.ModuleCreator;

interface

uses
  ToolsAPI
  , KIDE.IOTA.Utils
  ;

type
  TIOTAModuleCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator)
  public
    // IOTACreator
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;

    // IOTAModuleCreator
    function GetAncestorName: string;
    function GetImplFileName: string;
    function GetIntfFileName: string;
    function GetFormName: string;
    function GetMainForm: Boolean;
    function GetShowForm: Boolean;
    function GetShowSource: Boolean;
    function NewFormFile(const AFormIdent, AAncestorIdent: string): IOTAFile;
    function NewImplSource(const AModuleIdent, AFormIdent, AAncestorIdent: string): IOTAFile;
    function NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    procedure FormCreated(const FormEditor: IOTAFormEditor);
  end;

implementation

uses
  System.SysUtils
  ;

function TIOTAModuleCreator.GetCreatorType: string;
begin
  Result := sForm;
end;

function TIOTAModuleCreator.GetExisting: Boolean;
begin
  Result := False;
end;

function TIOTAModuleCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TIOTAModuleCreator.GetOwner: IOTAModule;
begin
  Result := FindActiveProject;
end;

function TIOTAModuleCreator.GetUnnamed: Boolean;
begin
  Result := True;
end;

function TIOTAModuleCreator.GetAncestorName: string;
begin
  Result := 'TForm';
end;

function TIOTAModuleCreator.GetImplFileName: string;
begin
  Result := GetCurrentDir + '\MainFormUnit.pas';
end;

function TIOTAModuleCreator.GetIntfFileName: string;
begin
  Result := '';
end;

function TIOTAModuleCreator.GetFormName: string;
begin
  Result := 'MainForm';
end;

function TIOTAModuleCreator.GetMainForm: Boolean;
begin
  Result := True;
end;

function TIOTAModuleCreator.GetShowForm: Boolean;
begin
  Result := True;
end;

function TIOTAModuleCreator.GetShowSource: Boolean;
begin
  Result := True;
end;

function TIOTAModuleCreator.NewFormFile(const AFormIdent, AAncestorIdent: string): IOTAFile;
begin
{ TODO : macros/text replace }
  Result := TKResourceFile.Create('MainForm_dfm');
end;

function TIOTAModuleCreator.NewImplSource(const AModuleIdent, AFormIdent, AAncestorIdent: string): IOTAFile;
begin
{ TODO : macros/text replace }
  Result := TKResourceFile.Create('MainForm_pas');
end;

function TIOTAModuleCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

procedure TIOTAModuleCreator.FormCreated(const FormEditor: IOTAFormEditor);
begin
end;

end.

