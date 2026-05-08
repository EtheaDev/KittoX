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
unit KIDE.ProjectTemplateFrameUnit;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Actions,
  System.ImageList,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.ComCtrls,
  Vcl.ActnList,
  Vcl.ImgList,
  KIDE.BaseFrameUnit;

type
  TProjectTemplateFrame = class(TBaseFrame)
    ImageList: TImageList;
    ActionList: TActionList;
    ListView: TListView;
    procedure ListViewDblClick(Sender: TObject);
    procedure ListViewSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
  private
    FOnDblClick: TNotifyEvent;
    FOnChange: TNotifyEvent;
    function GetCurrentTemplateName: string;
    procedure DoChange;
    procedure DoDblClick;
  public
    property CurrentTemplateName: string read GetCurrentTemplateName;
    procedure UpdateList(const ATemplatesPath, ADefaultTemplateName: string);
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
  end;

implementation

{$R *.dfm}

uses
  System.Types,
  System.StrUtils,
  EF.Sys.Windows,
  KIDE.Project,
  KIDE.Config;

{ TProjectTemplateFrame }

function TProjectTemplateFrame.GetCurrentTemplateName: string;
begin
  if Assigned(ListView.Selected) then
    Result := ListView.Selected.Caption
  else
    Result := '';
end;

procedure TProjectTemplateFrame.ListViewDblClick(Sender: TObject);
begin
  inherited;
  DoDblClick;
end;

procedure TProjectTemplateFrame.ListViewSelectItem(Sender: TObject;
  Item: TListItem; Selected: Boolean);
begin
  inherited;
  DoChange;
end;

procedure TProjectTemplateFrame.UpdateList(const ATemplatesPath, ADefaultTemplateName: string);
var
  LItem: TListItem;
  LPath: string;
begin
  ListView.Clear;
  if ATemplatesPath <> '' then
    LPath := ATemplatesPath
  else
    LPath := TKideConfig.Instance.TemplatePath;
  // Avoid hitting EF.Sys.Windows.EnumDirectories with a non-existing path
  // (which asserts). When the chosen ProjectTemplates folder is missing, we
  // simply present an empty list and let CanGoForward / validation handle it.
  if not DirectoryExists(LPath) then
    Exit;
  EnumDirectories(LPath,
    procedure (ADirectory: string)
    begin
      LItem := ListView.Items.Add;
      LItem.Caption := ADirectory;
      { TODO : Use a different image for each template. }
      LItem.ImageIndex := 0;
    end
  );
  if ListView.Items.Count > 0 then
  begin
    ListView.Selected := ListView.FindCaption(0,
      IfThen(ADefaultTemplateName <> '', ADefaultTemplateName, 'Basic'),
        False, True, False);
    if ListView.Selected = nil then
    begin
      ListView.Selected := ListView.Items[0];
      ListView.ItemFocused := ListView.Selected;
    end;
    if ListView.CanFocus then
      ListView.SetFocus;
  end;
  DoChange;
end;

procedure TProjectTemplateFrame.DoChange;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TProjectTemplateFrame.DoDblClick;
begin
  if Assigned(FOnDblClick) then
    FOnDblClick(Self);
end;

end.
