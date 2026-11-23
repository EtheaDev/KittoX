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
  if (LOption = '') or SameText(LOption, 'Null') then
    LReplace := ''
  else
    LReplace := Format(AUnitFormat, [LOption]);
  Result := ReplaceText(AString, '{' + AOptionName + '}', LReplace);
end;

function TProjectTemplate.ExpandMacros(const AFileName: string; const AEncoding: TEncoding): string;
var
  LAuth: string;
  LAuthUnit: string;
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
    Result := ReplaceUseKittoBooleanMacro(Result, 'DB/ODAC', 'EF.DB.ODAC');

    // {Auth} expands to the Kitto.Auth.* unit(s) needed at runtime.
    // Special-cased here because UseJWT is a separate Options field
    // but it affects the same `{Auth}` placeholder: when the JWT envelope
    // is enabled, both the storage authenticator (Kitto.Auth.<X>) AND
    // the JWT engine unit (Kitto.Auth.JWT) must be linked.
    LAuth := Options.GetString('Auth');
    LUseJWT := Options.GetBoolean('UseJWT');
    // Unit name follows the class id, except DBCrypt which is registered by
    // the Kitto.Auth.DB unit (there is no separate Kitto.Auth.DBCrypt) and
    // Ini, registered by Kitto.Auth.IniFile.
    if SameText(LAuth, 'DBCrypt') then
      LAuthUnit := 'DB'
    else if SameText(LAuth, 'Ini') then
      LAuthUnit := 'IniFile'
    else
      LAuthUnit := LAuth;
    if LAuth = '' then
      LAuthUses := ''
    else if LUseJWT then
      LAuthUses := sLineBreak + '  Kitto.Auth.' + LAuthUnit + ',' +
                   sLineBreak + '  Kitto.Auth.JWT,'
    else
      LAuthUses := sLineBreak + '  Kitto.Auth.' + LAuthUnit + ',';
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
var
  LMainDB: string;
  LTree: TEFTree;
  LDBNameIndex: Integer;
  LAuth: string;
  LAC: string;
  LUseJWT: Boolean;
  LAuthNode: TEFNode;
  LJWTNode: TEFNode;

  procedure AddDatabaseNode(const AProviderName, ADBName: string);
  var
    LChildNode: TEFNode;
  begin
    LChildNode := LTree.GetNode('Databases').AddChild(ADBName, AProviderName);
    LChildNode.AddChild('Connection').LoadFromYamlFile(GetSupportFileName('DB.' + AProviderName + '.yaml'));
    Inc(LDBNameIndex);
  end;

begin
  LTree := TEFYAMLReader.LoadTree(AFileName);
  try
    if Options.GetBoolean('DB/ADO') or
      Options.GetBoolean('DB/DBX') or
      Options.GetBoolean('DB/FD') or
      Options.GetBoolean('DB/ODAC') then
    begin
      LDBNameIndex := 0;
      //Add Main Database
      if Options.GetBoolean('DB/FD') then
      begin
        LMainDB := 'DB/FD';
        AddDatabaseNode('FD', 'Main')
      end
      else if Options.GetBoolean('DB/ODAC') then
      begin
        LMainDB := 'DB/ODAC';
        AddDatabaseNode('ODAC', 'Main');
      end
      else if Options.GetBoolean('DB/ADO') then
      begin
        LMainDB := 'DB/ADO';
        AddDatabaseNode('ADO', 'Main');
      end
      else if Options.GetBoolean('DB/DBX') then
      begin
        LMainDB := 'DB/DBX';
        AddDatabaseNode('DBX', 'Main');
      end;
      //Add Other Databases
      if Options.GetBoolean('DB/FD') and (LMainDB <> 'DB/FD') then
        AddDatabaseNode('FD', 'FireDAC');
      if Options.GetBoolean('DB/ODAC') and (LMainDB <> 'DB/ODAC') then
        AddDatabaseNode('ODAC', 'ODAC');
      if Options.GetBoolean('DB/ADO') and (LMainDB <> 'DB/ADO') then
        AddDatabaseNode('ADO', 'ADO');
      if Options.GetBoolean('DB/DBX') and (LMainDB <> 'DB/DBX') then
        AddDatabaseNode('DBX', 'DBExpress');
    end
    else
    begin
      LTree.DeleteNode('DefaultDatabaseName');
      LTree.DeleteNode('Databases');
    end;

    LAuth := Options.GetString('Auth');
    LUseJWT := Options.GetBoolean('UseJWT');

    // Auth model:
    //   * LAuth empty  -> leave whatever the template's Config.yaml has
    //   * LAuth set    -> Auth: <LAuth> with the storage's own sub-fields
    //                     from Auth.<LAuth>.yaml
    //   * UseJWT=True  -> additionally attach a JWT: sub-node (the optional
    //                     signed-token envelope) from Auth.JWT.yaml, so the
    //                     Kitto.Auth.JWT engine issues/validates a token.
    if LAuth <> '' then
    begin
      LAuthNode := LTree.SetString('Auth', LAuth);
      // LoadFromYamlFile mirrors the file's root node (`Auth: <LAuth>`) onto
      // the receiver, bringing in that storage's sub-fields (TextFile's
      // IsClearPassword/Passepartout, OSDB's connection settings, etc.).
      LAuthNode.LoadFromYamlFile(GetSupportFileName('Auth.' + LAuth + '.yaml'));
      if LUseJWT then
      begin
        // Auth.JWT.yaml has root key `JWT`, so loading it into the child
        // preserves the node name and yields Auth/JWT/<envelope keys>.
        LJWTNode := LAuthNode.AddChild('JWT');
        LJWTNode.LoadFromYamlFile(GetSupportFileName('Auth.JWT.yaml'));
      end;
    end;

    LAC := Options.GetString('AC');
    if LAC <> '' then
      LTree.SetString('AccessControl', LAC).LoadFromYamlFile(
        GetSupportFileName('AC.' + LAC + '.yaml'));

    LTree.SetString('HTML/Theme', Options.GetString('HTML/Theme'));
    LTree.SetString('LanguageId', Options.GetString('LanguageId'));
    LTree.SetString('Server/Port', Options.GetString('Server/Port'));
    LTree.SetString('Server/ThreadPoolSize', Options.GetString('Server/ThreadPoolSize'));
    // The option keeps the name the wizard has always given it; the node is
    // the one the engine reads. Written under Server it was read by nobody,
    // and every generated application ran on the default.
    LTree.SetString('Engine/Session/TimeOut', Options.GetString('Server/SessionTimeOut'));

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
    var
      LFileName: string;
    begin
      AAllow := not ContainsText(ExtractFilePath(ADestinationFileName), '_Support');
      // The template ships a demo user list for both file-based storages;
      // only the one the chosen Auth reads is copied (FileAuthenticator.ini
      // for Ini, FileAuthenticator.txt otherwise, as it has always been).
      LFileName := ExtractFileName(ASourceFileName);
      if SameText(LFileName, 'FileAuthenticator.ini') then
        AAllow := AAllow and SameText(Options.GetString('Auth'), 'Ini')
      else if SameText(LFileName, 'FileAuthenticator.txt') then
        AAllow := AAllow and not SameText(Options.GetString('Auth'), 'Ini');
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
