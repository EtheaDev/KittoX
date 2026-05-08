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
unit KIDE.ProjectTemplate;

{$R 'Template_Empty.res'}
{$R 'Template_Basic.res'}
interface

uses
  System.SysUtils,
  Generics.Collections,
  EF.Tree;

type
  TProjectTemplate = class
  private
    FTemplateName: string;
    FTemplateDirectory: string;
    FOptions: TEFTree;
    FProjectDirectory: string;
    FProjectName: string;
    FProjectGuid: string;
    FModuleSources: TDictionary<string, string>;
    procedure SetOptions(const AValue: TEFTree);
    procedure CheckRemoveDelphiVersionFiles(const ADelphiVersion: string);
    procedure CheckRemoveDeploymentFiles(const ADeploymentKey, AFileBaseSuffixOrName: string);
    function ReplaceUseKittoBooleanMacro(const AString, AOptionName,
      AUnitName: string): string;
    function ReplaceUseKittoStringMacro(const AString, AOptionName,
      AUnitFormat: string): string;
    function ExpandMacros(const AFileName: string; const AEncoding: TEncoding): string;
    procedure SetProjectName(const AValue: string);
    function ProcessConfigTemplate(const AFileName: string): string;
    function GetResourceName(const APathName: string): string;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
    function GetSupportFileName(const AFileName: string): string;
    property TemplateDirectory: string read FTemplateDirectory write FTemplateDirectory;
    property Options: TEFTree read FOptions write SetOptions;
    property ProjectDirectory: string read FProjectDirectory write FProjectDirectory;
    property ProjectName: string read FProjectName write SetProjectName;
    property ProjectGuid: string read FProjectGuid;
    procedure CreateProject;
    function GetProjectSource: string;
    function GetModuleSource(const APathName: string): string;
  end;

implementation

uses
  System.StrUtils,
  Winapi.ActiveX,  // CoCreateGuid for fresh per-dproj GUIDs
  EF.Sys.Windows,
  EF.StrUtils,
  EF.YAML;

{ TProjectTemplate }

procedure TProjectTemplate.AfterConstruction;
begin
  inherited;
  FOptions := TEFNode.Create;
  FModuleSources := TDictionary<string, string>.Create;
end;

procedure TProjectTemplate.CheckRemoveDelphiVersionFiles(const ADelphiVersion: string);
begin
  if not Options.GetBoolean(ADelphiVersion) then
  begin
    DeleteTree(IncludeTrailingPathDelimiter(ProjectDirectory) + 'Projects' + PathDelim + ADelphiVersion);
    DeleteTree(IncludeTrailingPathDelimiter(ProjectDirectory) + 'Lib' + PathDelim + ADelphiVersion);
  end;
end;

function TProjectTemplate.ReplaceUseKittoBooleanMacro(const AString, AOptionName, AUnitName: string): string;
begin
  if Options.GetBoolean(AOptionName) then
    Result := ReplaceText(AString, '{' + AOptionName + '}', AUnitName)
  else
    Result := ReplaceText(AString, '{' + AOptionName + '}', '// ' + AUnitName);
end;

function TProjectTemplate.ReplaceUseKittoStringMacro(const AString, AOptionName, AUnitFormat: string): string;
var
  LOption: string;
  LReplace: string;
begin
  LOption := Options.GetString(AOptionName);
  if LOption = '' then
    LReplace := ''
  else
    LReplace := Format(AUnitFormat, [LOption]);
  Result := ReplaceText(AString, '{' + AOptionName + '}', LReplace);
end;

function TProjectTemplate.ExpandMacros(const AFileName: string; const AEncoding: TEncoding): string;
var
  LAuth: string;
  LUseJWT: Boolean;
  LAuthUses: string;
  LGuid: TGUID;
  LFreshGuid: string;
begin
  Result := TextFileToString(AFileName, AEncoding);
  Result := ReplaceText(Result, '{ProjectName}', ProjectName);
  // {ProjectNameLower} for filenames and identifiers that must be
  // lowercase (Apache `mod_<name>` library, `library mod_<name>;`,
  // `name '<name>_module'` export).
  Result := ReplaceText(Result, '{ProjectNameLower}', LowerCase(ProjectName));
  // .dproj files get a fresh GUID per file so the four generated
  // deployment variants (Standalone/Desktop/ISAPI/Apache) do not
  // collide in the IDE's project group / msbuild graph.
  if SameText(ExtractFileExt(AFileName), '.dproj') and
     Succeeded(CoCreateGuid(LGuid)) then
  begin
    LFreshGuid := GUIDToString(LGuid);
    Result := ReplaceText(Result, '{ProjectGuid}', LFreshGuid);
  end
  else
    Result := ReplaceText(Result, '{ProjectGuid}', ProjectGuid);
  Result := ReplaceText(Result, '{AppTitle}', Options.GetString('AppTitle'));

  if SameText(ExtractFileFormat(AFileName), 'pas') then
  begin
    Result := ReplaceUseKittoBooleanMacro(Result, 'DB/ADO', 'EF.DB.ADO');
    Result := ReplaceUseKittoBooleanMacro(Result, 'DB/DBX', 'EF.DB.DBX');
    Result := ReplaceUseKittoBooleanMacro(Result, 'DB/FD', 'EF.DB.FD');

    // {Auth} expands to the Kitto.Auth.* unit(s) needed at runtime.
    // Special-cased here because UseJWT is a separate Options field
    // but it affects the same `{Auth}` placeholder: when JWT envelope
    // is enabled, both the storage authenticator (Kitto.Auth.<X>) AND
    // the JWT envelope authenticator (Kitto.Auth.JWT) must be linked.
    LAuth := Options.GetString('Auth');
    LUseJWT := Options.GetBoolean('UseJWT');
    if LAuth = '' then
      LAuthUses := ''
    else if LUseJWT then
      LAuthUses := sLineBreak + '  Kitto.Auth.' + LAuth + ',' +
                   sLineBreak + '  Kitto.Auth.JWT,'
    else
      LAuthUses := sLineBreak + '  Kitto.Auth.' + LAuth + ',';
    Result := ReplaceText(Result, '{Auth}', LAuthUses);

    Result := ReplaceUseKittoStringMacro(Result, 'AC', sLineBreak + '  Kitto.AccessControl.%s,');
  end
  else if SameText(ExtractFileFormat(AFileName), 'dproj') then
    Result := ReplaceText(Result, '{KittoPath}', Options.GetString('SearchPath'));

  StringToTextFile(Result, AFileName, AEncoding);
end;

function TProjectTemplate.GetSupportFileName(const AFileName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(TemplateDirectory) + '_Support' + PathDelim + AFileName;
end;

function TProjectTemplate.ProcessConfigTemplate(const AFileName: string): string;
const
  DB_NAMES: array[0..3] of string = ('Main', 'Other1', 'Other2', 'Other3');
var
  LTree: TEFTree;
  LDBNameIndex: Integer;
  LAuth: string;
  LAC: string;
  LUseJWT: Boolean;
  LAuthNode: TEFNode;
  LInnerNode: TEFNode;

  procedure AddDatabaseNode(const AProviderName: string);
  var
    LChildNode: TEFNode;
  begin
    LChildNode := LTree.GetNode('Databases').AddChild(DB_NAMES[LDBNameIndex], AProviderName);
    LChildNode.AddChild('Connection').LoadFromYamlFile(GetSupportFileName('DB.' + AProviderName + '.yaml'));
    Inc(LDBNameIndex);
  end;

begin
  LTree := TEFYAMLReader.LoadTree(AFileName);
  try
    if Options.GetBoolean('DB/ADO') or Options.GetBoolean('DB/DBX') or Options.GetBoolean('DB/FD') then
    begin
      LDBNameIndex := 0;
      if Options.GetBoolean('DB/ADO') then
        AddDatabaseNode('ADO');
      if Options.GetBoolean('DB/DBX') then
        AddDatabaseNode('DBX');
      if Options.GetBoolean('DB/FD') then
        AddDatabaseNode('FD');
    end
    else
    begin
      LTree.DeleteNode('DefaultDatabaseName');
      LTree.DeleteNode('Databases');
    end;

    LAuth := Options.GetString('Auth');
    LUseJWT := Options.GetBoolean('UseJWT');

    // Three Auth code paths:
    //   * UseJWT=True  -> Auth: JWT, Inner: <LAuth>  (recommended)
    //   * UseJWT=False -> Auth: <LAuth>              (legacy / no envelope)
    //   * LAuth empty  -> leave whatever the template's Config.yaml has
    if LUseJWT and (LAuth <> '') then
    begin
      LAuthNode := LTree.SetString('Auth', 'JWT');
      // Load the JWT envelope skeleton from Auth.JWT.yaml (Inner defaults
      // to DB with its standard sub-fields).
      LAuthNode.LoadFromYamlFile(GetSupportFileName('Auth.JWT.yaml'));
      // Patch the Inner storage choice if the user picked something
      // other than DB. We re-load Auth.<X>.yaml directly into the Inner
      // node so the sub-fields shipped with that storage (TextFile's
      // IsClearPassword/Passpartout, OSDB's connection settings, etc.)
      // are merged in. The YAML loader overwrites the receiver's name
      // with the file's root key (`Auth`) — we restore it to `Inner`
      // afterwards so the structural meaning is preserved.
      LInnerNode := LAuthNode.FindNode('Inner');
      if Assigned(LInnerNode) and not SameText(LAuth, 'DB') then
      begin
        LInnerNode.LoadFromYamlFile(GetSupportFileName('Auth.' + LAuth + '.yaml'));
        LInnerNode.Name := 'Inner';
      end;
    end
    else if LAuth <> '' then
    begin
      LTree.SetString('Auth', LAuth).LoadFromYamlFile(
        GetSupportFileName('Auth.' + LAuth + '.yaml'));
    end;

    LAC := Options.GetString('AC');
    if LAC <> '' then
      LTree.SetString('AccessControl', LAC).LoadFromYamlFile(
        GetSupportFileName('AC.' + LAC + '.yaml'));

    LTree.SetString('HTML/Theme', Options.GetString('HTML/Theme'));
    LTree.SetString('LanguageId', Options.GetString('LanguageId'));
    LTree.SetString('Server/Port', Options.GetString('Server/Port'));
    LTree.SetString('Server/ThreadPoolSize', Options.GetString('Server/ThreadPoolSize'));
    LTree.SetString('Server/SessionTimeOut', Options.GetString('Server/SessionTimeOut'));

    TEFYAMLWriter.SaveTree(LTree, AFileName);
    Result := ExpandMacros(AFileName, TEncoding.UTF8);
  finally
    FreeAndNil(LTree);
  end;
end;

function TProjectTemplate.GetResourceName(const APathName: string): string;
begin
  Assert(FTemplateName <> '');

  Result := (FTemplateName + '_' + APathName).Replace(PathDelim, '_').Replace('.', '_').ToUpper;
end;

function TProjectTemplate.GetProjectSource: string;
begin
  Result := GetModuleSource('Source\Project.dpr');
end;

function TProjectTemplate.GetModuleSource(const APathName: string): string;
var
  LResourceName: string;
  LBytes: TBytes;
begin
  Result := '';
  LResourceName := GetResourceName(APathName);
  if not FModuleSources.ContainsKey(LResourceName) then
  begin
    LBytes := GetRCDATAResourceBytes(HInstance, LResourceName);
    if Assigned(LBytes) then
    begin
      Result := TEncoding.UTF8.GetString(LBytes);
      if SameText(ExtractFileName(APathName), 'Config.yaml') then
        Result := ProcessConfigTemplate(Result)
      else
        Result := ExpandMacros(Result, TEncoding.UTF8);
      FModuleSources.Add(LResourceName, Result);
    end;
  end
  else
    Result :=  FModuleSources[LResourceName];
end;

procedure TProjectTemplate.CreateProject;
begin
  Assert(ProjectName <> '');
  Assert(ProjectDirectory <> '');
  Assert(TemplateDirectory <> '');

  if not DirectoryExists(TemplateDirectory) then
    raise Exception.CreateFmt('Project template directory %s not found.', [TemplateDirectory]);

  CopyAllFilesAndFolders(TemplateDirectory, ProjectDirectory,
    // before each file
    procedure (const ASourceFileName: string; var ADestinationFileName: string; var AAllow: Boolean)
    begin
      AAllow := not ContainsText(ExtractFilePath(ADestinationFileName), '_Support');
      if AAllow then
      begin
        // Expand template-level macros in file names. {ProjectNameLower}
        // resolved BEFORE {ProjectName} because the latter is a substring
        // of the former and a naive Replace would corrupt it.
        ADestinationFileName := ReplaceText(ADestinationFileName, '{ProjectNameLower}', LowerCase(ProjectName));
        ADestinationFileName := ReplaceText(ADestinationFileName, '{ProjectName}', ProjectName);
      end;
    end,
    // after each file
    procedure (const ASourceFileName, ADestinationFileName: string)
    begin
      if SameText(ExtractFileExt(ADestinationFileName), '.dproj') then
        ExpandMacros(ADestinationFileName, TEncoding.UTF8)
      else if MatchText(ExtractFileExt(ADestinationFileName), ['.dpr', '.pas']) then
        ExpandMacros(ADestinationFileName, TEncoding.ANSI)
      else if MatchText(ExtractFileName(ADestinationFileName), ['Config.yaml']) then
        ProcessConfigTemplate(ADestinationFileName)
      else if MatchText(ExtractFileExt(ADestinationFileName), ['.yaml']) then
        ExpandMacros(ADestinationFileName, TEncoding.UTF8);
    end
  );
  // Legacy multi-Delphi-version directory cleanup (no-op for KittoX
  // templates that ship a single Win64 dproj per deployment, but kept
  // for backward compat with templates that still have D{N}/ subdirs).
  CheckRemoveDelphiVersionFiles('D10_4');
  CheckRemoveDelphiVersionFiles('D11');
  CheckRemoveDelphiVersionFiles('D12');
  CheckRemoveDelphiVersionFiles('D13');

  // Deployment selection: remove .dpr/.dproj/.res for the deployment
  // variants the user did not request. Default Options key is True for
  // Standalone, False for the others.
  CheckRemoveDeploymentFiles('Standalone', '');                    // <ProjectName>.dpr/.dproj
  CheckRemoveDeploymentFiles('Desktop',    'Desktop');             // <ProjectName>Desktop.dpr/.dproj
  CheckRemoveDeploymentFiles('ISAPI',      'ISAPI');               // <ProjectName>ISAPI.dpr/.dproj
  CheckRemoveDeploymentFiles('Apache',     'mod_' + LowerCase(ProjectName)); // mod_<lower>.dpr/.dproj

  DeleteTree(IncludeTrailingPathDelimiter(ProjectDirectory) + '_Support');
end;

procedure TProjectTemplate.CheckRemoveDeploymentFiles(
  const ADeploymentKey, AFileBaseSuffixOrName: string);

  // For Standalone/Desktop/ISAPI the basename is `<ProjectName><Suffix>`;
  // for Apache the basename is `mod_<lower>` (no <ProjectName> prefix).
  function FileBase: string;
  begin
    if ADeploymentKey = 'Apache' then
      Result := AFileBaseSuffixOrName
    else
      Result := ProjectName + AFileBaseSuffixOrName;
  end;

var
  LProjectsDir: string;
  LExt: string;
const
  CExtensions: array[0..2] of string = ('.dpr', '.dproj', '.res');
begin
  if Options.GetBoolean('Deploy/' + ADeploymentKey, ADeploymentKey = 'Standalone') then
    Exit;
  LProjectsDir := IncludeTrailingPathDelimiter(ProjectDirectory) + 'Projects' + PathDelim;
  for LExt in CExtensions do
    if FileExists(LProjectsDir + FileBase + LExt) then
      DeleteFile(LProjectsDir + FileBase + LExt);
end;

destructor TProjectTemplate.Destroy;
begin
  FreeAndNil(FModuleSources);
  FreeAndNil(FOptions);
  inherited;
end;

procedure TProjectTemplate.SetOptions(const AValue: TEFTree);
begin
  FOptions.Assign(AValue);
end;

procedure TProjectTemplate.SetProjectName(const AValue: string);
begin
  FProjectName := AValue;
  FProjectGuid := CreateGuidStr;
end;

end.
