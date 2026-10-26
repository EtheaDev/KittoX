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
unit KIDE.MainDataModuleUnit;

interface

uses
  System.SysUtils,
  System.Classes,
  {$IFDEF MADEXCEPT}
  madExcept,
  {$ENDIF}
  System.ImageList,
  Vcl.ImgList,
  Vcl.Controls, Vcl.BaseImageCollection,
  Vcl.ImageCollection
  ;

const
  FOLDER_PICTURE = 'Folder';
  CONFIG_PICTURE = 'Config';
  VIEW_PICTURE = 'View';
  PREVIEW_PICTURE = 'Preview';
  MODEL_PICTURE = 'Model';
  MODEL_WIZARD_PICTURE = 'Model-wizard';
  LAYOUT_PICTURE = 'Layout';
  LANGUAGES_PICTURE = 'Languages';
  EDIT_FILE = 'Edit';
  VALIDATE_PICTURE = 'Validate';
  NEW_MODEL_PICTURE = 'New-model';
  DATA_WIZARD_PICTURE = 'Data-wizard';
  VIEW_WIZARD_PICTURE = 'View-wizard';
  NEW_VIEW_PICTURE = 'New-view';
  NEW_LAYOUT_PICTURE = 'New-layout';
  FIELD_PICTURE = 'Field';
  FIELD_PK_PICTURE = 'Field-pk';
  FIELD_REF_PICTURE = 'Field-reference';
  DESIGN_PICTURE = 'Design';
  GENERIC_PICTURE = 'Generic';
  LABEL_PICTURE = 'Label';
  MEMO_FIELD_PICTURE = 'Field-memo';
  DATA_FIELD_PICTURE = 'Field-datetime';
  DATETIME_FIELD = 'Field-datetime';
  TIME_FIELD_PICTURE = 'Field-time';
  STRING_FIELD_PICTURE = 'Field-string';
  INTEGER_FIELD_PICTURE = 'Field-integer';
  BOOLEAN_FIELD_PICTURE = 'Field-boolean';
  NUMERIC_FIELD_PICTURE = 'Field-numeric';
  WIDTH_PICTURE = 'Width';
  EYE_PICTURE = 'Eye';
  EXPRESSION_PICTURE = 'Expression';
  HINT_PICTURE = 'Hint';
  RANGE_FROM_PICTURE = 'Range-from';
  RANGE_TO_PICTURE = 'Range-to';
  DATABASE_PICTURE = 'Database';
  DB_CONNECTION_PICTURE = 'database-connection';
  DB_ADO_PICTURE = 'database_ADO';
  DB_DBX_PICTURE = 'database_DbExpress';
  DB_FD_PICTURE = 'database_FireDAC';
  ADD_CHILD = 'Add-child';
  DELETE_NODE = 'Delete-node';
  NEW_CONFIG_PICTURE = 'New-config';
  NEW_PROJECT_PICTURE = 'New-project';
  CLOSE_PROJECT_PICTURE = 'Close-project';
  FASTCGI_PICTURE = 'Fastcgi';
  EDIT_STYLE = 'Edit-style';
  EDIT_SCRIPT = 'Edit-script';
  FILE_TXT = 'File-txt';
  FILE_HTML = 'File-html';
  FILE_IMAGE = 'File-image';
  FILE_UNKNOWN = 'File-unknown';
  FILE_CSS = 'File-css';
  FILE_JS = 'File-js';
  FILE_SVG = 'File-svg';
  FILE_JSON = 'File-json';
  COLOR_PALETTE = 'Color-palette';
  IMAGE_UNDO = 'Undo';
  KIDE_ICON = 'Kide';
  HOME_VIEW = 'Home';
  MAINMENU_VIEW = 'View-mainmenu';
  FORM_VIEW = 'View-form';
  LIST_VIEW = 'View-list';
  TREE_VIEW = 'View-tree';
  LAYOUT_FORM = 'Layout-form';
  LAYOUT_GRID = 'Layout-grid';
  HELP_PICTURE = 'Help';
  BULB_PICTURE = 'Bulb';
  DELETE_CONFIG_PICTURE = 'Delete-config';
  DELETE_MODEL_PICTURE = 'Delete-model';
  DELETE_VIEW_PICTURE = 'Delete-view';
  DELETE_LAYOUT_PICTURE = 'Delete-layout';
  IMAGE_BRICK = 'Brick';
  AUTH_PICTURE = 'Auth';
  UAC_PICTURE = 'Uac';
  EXT_PICTURE = 'Ext';
  WEB_PICTURE = 'Web';
  KEY_PICTURE = 'key';
  INFO_PICTURE = 'info';
  ASSISTANT_PICTURE = 'assistant';
  MAIL_PICTURE = 'Mail';
  ACCESSCONTROL_PICTURE = 'AccessControl';
  TEMPLATE_PICTURE = 'template';
  CALCULATOR_PICTURE = 'calculator';
  GOOGLEMAPS_PICTURE = 'GoogleMaps';
  ENGINE_PICTURE = 'Engine';
  EXTERNAL_EDITOR = 'external-editor';
  MSG_INFO = 'MsgInfo';
  MSG_WARNING = 'MsgWarning';
  MSG_ERROR = 'MsgError';
  // Bandiere per lingua: il nome dell'item e' il codice lingua gettext usato da
  // KittoX (vedi TKXLanguageCatalog in Kitto.Html.LanguageSwitcher).
  LANGUAGE_EN_PICTURE = 'en';
  LANGUAGE_IT_PICTURE = 'it';
  LANGUAGE_DE_PICTURE = 'de';
  LANGUAGE_ES_PICTURE = 'es';
  LANGUAGE_PT_PICTURE = 'pt';

type
  TIconsStyle = (it16Color, it18Black, it24Black);

  TMainDataModule = class(TDataModule)
    ImageCollection: TImageCollection;
    procedure DataModuleCreate(Sender: TObject);
  private
    FIconsStyle: TIconsStyle;
    procedure SetIconsStyle(AIconsStyle: TIconsStyle);
    procedure UpdateIconsStyle;
  public
{$IFDEF MADEXCEPT}
    procedure ShowMadExcept(const exceptIntf: IMEException;
      var handled: boolean);
{$ENDIF}
    property IconsStyle: TIconsStyle read FIconsStyle write SetIconsStyle;

  end;

var
  MainDataModule: TMainDataModule;

function GetFileImageName(const AExt: string): string;
/// <summary>Nome dell'icona-bandiera per un id lingua ('it', 'it_IT', 'pt-BR').
/// Le lingue senza bandiera propria e l'id vuoto ricadono su LANGUAGES_PICTURE.</summary>
function GetLanguageImageName(const ALanguageId: string): string;

/// <summary>
///  Restituisce il data module, creandolo se non l'ha fatto nessuno.
///  KIDEX lo crea dal .dpr; nel package design-time non lo crea nessuno, e i
///  riferimenti nei DFM della forma
///  'ImageCollection = MainDataModule.ImageCollection' non hanno allora una
///  radice su cui risolversi: restano nil in silenzio, la TVirtualImageList
///  resta vuota e la form si apre senza icone. Va chiamata PRIMA di creare
///  qualunque form o frame che ne contenga una.
/// </summary>
function EnsureMainDataModule: TMainDataModule;

implementation

{$R *.dfm}

uses
  System.StrUtils,
  Vcl.Forms,
  KIDE.MRUOptions;

{$IFDEF MADEXCEPT}
const
  EDATABASEERRORDESC = 'Error accessing database';
  EFILERERROR = 'Error in input/output file operation';
  EGENERICERROR = 'Error';
  EACCESSVIOLDESC = 'Unexpected fatal error in application';
  ERR_ACCES_VIOL_DESC = 'Unexpected error.'+sLineBreak+sLineBreak+'%s'+sLineBreak+sLineBreak+
                        'It is reccomended to exit and reexecute the program.'+sLineBreak+
                        'If this error persists, please contact our technical support.';

function GetErrorClassNameDesc(const ExceptionClassName : string;
  IsAccessViolation: boolean) : string;
begin
  Result := '';
  if pos('Database', ExceptionClassName) > 0 then
    Result := EDATABASEERRORDESC
  else if pos('FilerError', ExceptionClassName) > 0 then
    Result := EFILERERROR
  else if IsAccessViolation then
    Result := EACCESSVIOLDESC
  else
    Result := EGENERICERROR;
end;

procedure TMainDataModule.ShowMadExcept(const exceptIntf: IMEException;
  var handled: boolean);
var
  LClassDesc, LClassName, LErrorDesc, LErrorMsg: string;
  LTerminateVisible: boolean;
  LErrorIcon, LHelpContext: integer;
  LUnespectedError: boolean;
begin
  //Event-handler per mad Exception: modifica il comportamento di default.
  //Se l'errore è un Access Violation mostra subito il bug report
  //altrimenti mostra l'impostazione predefinita nei settings di madExcept
  LClassDesc := GetErrorClassNameDesc(exceptIntf.ExceptClass,
    LUnespectedError);
  LClassName := exceptIntf.ExceptClass;
  LErrorMsg := exceptIntf.ExceptMessage;

  //Titolo della form di errore
  exceptIntf.TitleBar := LClassDesc;

  LUnespectedError :=
    (exceptIntf.ExceptionRecord.ExceptionCode = $C0000094) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C000008C) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C0000095) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C000008F) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C0000090) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C0000092) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C000008E) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C0000091) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C0000093) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C000008D) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C0000005) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C0000096) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C000013A) or
    (exceptIntf.ExceptionRecord.ExceptionCode = $C00000FD);

  if LUnespectedError then
  begin
    exceptIntf.ExceptMsg := Format(ERR_ACCES_VIOL_DESC, [LErrorMsg]);
    exceptIntf.RestartBtnVisible := True;
    exceptIntf.CloseBtnVisible := True;
    exceptIntf.ShowBtnVisible := True;
  end
  else
  begin
    //Messaggio di errore originale
    exceptIntf.ExceptMsg :=  LErrorMsg;
    //Nasconde i pulsanti restart, close e show bug report
    exceptIntf.RestartBtnVisible := False;
    exceptIntf.CloseBtnVisible := False;
    exceptIntf.ShowBtnVisible := False;
    //Focus su pulsante "continua"
    exceptIntf.FocusedButton := bContinueApplication;
  end;
end;
{$ENDIF}

function EnsureMainDataModule: TMainDataModule;
begin
  if not Assigned(MainDataModule) then
    // Owner NIL di proposito, in entrambi gli host. Se l'owner fosse Application
    // (KIDEX standalone o IDE), Application lo libererebbe alla chiusura E la
    // finalization di questa unit lo libererebbe di nuovo -> double free ->
    // "Invalid pointer operation" in uscita (era il difetto: MainDataModule
    // posseduto da Application + FreeAndNil in finalization). Con owner nil
    // nessun Application lo tocca: l'UNICO punto che lo libera e' la
    // finalization qui sotto, sicuro sia all'uscita sia alla disinstallazione
    // del package design-time.
    MainDataModule := TMainDataModule.Create(nil);
  Result := MainDataModule;
end;

procedure TMainDataModule.DataModuleCreate(Sender: TObject);
begin
  FIconsStyle := TIconsStyle(TMRUOptions.Instance.GetInteger('IconsStyle', Ord(it18Black)));
  UpdateIconsStyle;
end;

procedure TMainDataModule.SetIconsStyle(AIconsStyle: TIconsStyle);
begin
  if FIconsStyle <> AIconsStyle then
  begin
    FIconsStyle := AIconsStyle;
    UpdateIconsStyle;
    TMRUOptions.Instance.SetInteger('IconsStyle', Ord(FIconsStyle));
  end;
end;

procedure TMainDataModule.UpdateIconsStyle;
begin
  ;
end;

function GetLanguageImageName(const ALanguageId: string): string;
var
  LCode: string;
begin
  // Riduce 'it_IT' / 'pt-BR' al codice base, come TKXLanguageCatalog.NormalizeCode.
  LCode := Copy(Trim(ALanguageId), 1, 2);
  if SameText(LCode, 'en') then
    Result := LANGUAGE_EN_PICTURE
  else if SameText(LCode, 'it') then
    Result := LANGUAGE_IT_PICTURE
  else if SameText(LCode, 'de') then
    Result := LANGUAGE_DE_PICTURE
  else if SameText(LCode, 'es') then
    Result := LANGUAGE_ES_PICTURE
  else if SameText(LCode, 'pt') then
    Result := LANGUAGE_PT_PICTURE
  else
    Result := LANGUAGES_PICTURE;
end;

function GetFileImageName(const AExt: string): string;
begin
  if MatchText(AExt, ['js']) then
    Result := FILE_JS
  else if MatchText(AExt, ['htm', 'html']) then
    Result := FILE_HTML
  else if MatchText(AExt, ['svg']) then
    Result := FILE_SVG
  else if MatchText(AExt, ['jpg', 'png', 'gif', 'bmp']) then
    Result := FILE_IMAGE
  else if MatchText(AExt, ['css']) then
    Result := FILE_CSS
  else if MatchText(AExt, ['json']) then
    Result := FILE_JSON
  else if MatchText(AExt, ['txt']) then
    Result := FILE_TXT
  else
    Result := FILE_UNKNOWN;
end;

initialization

finalization
  // MainDataModule is created with NO owner (see EnsureMainDataModule), so no
  // Application ever frees it — this finalization is its single, authoritative
  // free point. Safe both on normal exit (KIDEX or the IDE) and on design-time
  // package uninstall, with no double free.
  FreeAndNil(MainDataModule);

end.
