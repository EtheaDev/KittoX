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
///  TemplatePro integration for KittoX.
///  Provides template loading with 3-level fallback lookup and rendering.
/// </summary>
unit Kitto.Html.TemplateEngine;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Kitto.TemplatePro,
  Kitto.Config;

type
  /// <summary>
  ///  Wraps TemplatePro compilation and rendering, with a 3-level template lookup:
  ///   1. App/Home/Metadata/Views/Templates/{ViewName}.html
  ///   2. App/Home/Templates/{ControllerType}.html
  ///   3. Kitto/Home/Templates/{ControllerType}.html (system home)
  /// </summary>
  TKXTemplateEngine = class
  strict private
    class var FInstance: TKXTemplateEngine;
    class function GetInstance: TKXTemplateEngine; static;
  public
    class destructor Destroy;
    class property Instance: TKXTemplateEngine read GetInstance;

    /// <summary>
    ///  Finds a template file using the 3-level fallback lookup.
    ///  Returns the full path of the first matching file, or '' if not found.
    /// </summary>
    function FindTemplatePath(const AViewName, AControllerType: string): string;

    /// <summary>
    ///  Finds and compiles a template, calls ASetData to bind data,
    ///  then renders and returns the resulting HTML string.
    /// </summary>
    function Render(const ATemplatePath: string;
      const ASetData: TProc<ITProCompiledTemplate>): string;

    /// <summary>
    ///  Compiles a template from a string, calls ASetData to bind data,
    ///  then renders and returns the resulting HTML string.
    /// </summary>
    function RenderString(const ATemplate: string;
      const ASetData: TProc<ITProCompiledTemplate>): string;

    /// <summary>
    ///  Finds the template by view/controller name, compiles it,
    ///  calls ASetData, and renders. Raises an exception if not found.
    /// </summary>
    function RenderTemplate(const AViewName, AControllerType: string;
      const ASetData: TProc<ITProCompiledTemplate>): string;
  end;

implementation

uses
  System.IOUtils;

{ TKXTemplateEngine }

class destructor TKXTemplateEngine.Destroy;
begin
  FreeAndNil(FInstance);
end;

class function TKXTemplateEngine.GetInstance: TKXTemplateEngine;
begin
  if FInstance = nil then
    FInstance := TKXTemplateEngine.Create;
  Result := FInstance;
end;

function TKXTemplateEngine.FindTemplatePath(const AViewName, AControllerType: string): string;
var
  LPath: string;
begin
  // Level 1: App/Home/Metadata/Views/Templates/{ViewName}.html
  if AViewName <> '' then
  begin
    LPath := TKConfig.GetMetadataPath + 'Views' + PathDelim + 'Templates' + PathDelim + AViewName + '.html';
    if FileExists(LPath) then
      Exit(LPath);
  end;

  // Level 2: App/Home/Templates/{ControllerType}.html
  if AControllerType <> '' then
  begin
    LPath := TKConfig.AppHomePath + 'Templates' + PathDelim + AControllerType + '.html';
    if FileExists(LPath) then
      Exit(LPath);
  end;

  // Level 3: Kitto/Home/Templates/{ControllerType}.html (system home)
  if AControllerType <> '' then
  begin
    LPath := TKConfig.SystemHomePath + 'Templates' + PathDelim + AControllerType + '.html';
    if FileExists(LPath) then
      Exit(LPath);
  end;

  Result := '';
end;

function TKXTemplateEngine.Render(const ATemplatePath: string;
  const ASetData: TProc<ITProCompiledTemplate>): string;
var
  LCompiler: TTProCompiler;
  LTemplate: ITProCompiledTemplate;
  LContent: string;
  LRefPath: string;
begin
  LCompiler := TTProCompiler.Create;
  try
    LContent := TFile.ReadAllText(ATemplatePath);
    LRefPath := TPath.GetDirectoryName(ATemplatePath);
    LTemplate := LCompiler.Compile(LContent, LRefPath);
  finally
    LCompiler.Free;
  end;
  if Assigned(ASetData) then
    ASetData(LTemplate);
  Result := LTemplate.Render;
end;

function TKXTemplateEngine.RenderString(const ATemplate: string;
  const ASetData: TProc<ITProCompiledTemplate>): string;
var
  LCompiler: TTProCompiler;
  LTemplate: ITProCompiledTemplate;
begin
  LCompiler := TTProCompiler.Create;
  try
    LTemplate := LCompiler.Compile(ATemplate);
  finally
    LCompiler.Free;
  end;
  if Assigned(ASetData) then
    ASetData(LTemplate);
  Result := LTemplate.Render;
end;

function TKXTemplateEngine.RenderTemplate(const AViewName, AControllerType: string;
  const ASetData: TProc<ITProCompiledTemplate>): string;
var
  LPath: string;
begin
  LPath := FindTemplatePath(AViewName, AControllerType);
  if LPath = '' then
    raise Exception.CreateFmt('Template not found for view "%s", controller "%s"', [AViewName, AControllerType]);
  Result := Render(LPath, ASetData);
end;

end.
