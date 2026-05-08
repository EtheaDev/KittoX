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
{   Il contenuto di questo file � protetto dalle leggi              }
{   internazionali sul Copyright. Sono vietate la riproduzione, il  }
{   reverse-engineering e la distribuzione non autorizzate di tutto }
{   o parte del codice contenuto in questo file. Ogni infrazione    }
{   sar� perseguita civilmente e penalmente a termini di legge.     }
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
unit KIDE.BaseFormUnit;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs;

type
  TBaseForm = class(TForm)
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
  strict protected
    procedure StorePositionAndSize;
    procedure RestorePositionAndSize;
    function GetMRURootKeyName: string; virtual;
  public
    procedure CreateParams(var Params: TCreateParams); override;
  end;

implementation

{$R *.dfm}

uses
  KIDE.MRUOptions,
  KIDE.Controls;

procedure TBaseForm.CreateParams(var Params: TCreateParams);
begin
  inherited;
end;

procedure TBaseForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  StorePositionAndSize;
end;

procedure TBaseForm.StorePositionAndSize;
begin
  TMRUOptions.Instance.SetInteger(GetMRURootKeyName + '/WindowState', Ord(WindowState));
  if WindowState = wsNormal then
  begin
    // Save unscaled values so MRU is always relative to 96 DPI
    TMRUOptions.Instance.SetInteger(GetMRURootKeyName + '/Left', UnscaledValue(Self, Left));
    TMRUOptions.Instance.SetInteger(GetMRURootKeyName + '/Top', UnscaledValue(Self, Top));
    TMRUOptions.Instance.SetInteger(GetMRURootKeyName + '/Width', UnscaledValue(Self, Width));
    TMRUOptions.Instance.SetInteger(GetMRURootKeyName + '/Height', UnscaledValue(Self, Height));
  end;
  TMRUOptions.Instance.Save;
end;

procedure TBaseForm.FormShow(Sender: TObject);
begin
  RestorePositionAndSize;
end;

procedure TBaseForm.RestorePositionAndSize;
var
  LWindowState: TWindowState;
begin
  LWindowState := TWindowState(TMRUOptions.Instance.GetInteger(GetMRURootKeyName + '/WindowState', Ord(wsMaximized)));
  if LWindowState in [wsNormal, wsMaximized] then
    WindowState := LWindowState
  else
    WindowState := wsNormal;
  if WindowState = wsNormal then
  begin
    // MRU stores unscaled (96 DPI) values — scale them for current DPI
    Left := ScaledValue(Self, TMRUOptions.Instance.GetInteger(GetMRURootKeyName + '/Left', UnscaledValue(Self, Left)));
    Top := ScaledValue(Self, TMRUOptions.Instance.GetInteger(GetMRURootKeyName + '/Top', UnscaledValue(Self, Top)));
    Width := ScaledValue(Self, TMRUOptions.Instance.GetInteger(GetMRURootKeyName + '/Width', UnscaledValue(Self, Width)));
    Height := ScaledValue(Self, TMRUOptions.Instance.GetInteger(GetMRURootKeyName + '/Height', UnscaledValue(Self, Height)));
  end;
end;

function TBaseForm.GetMRURootKeyName: string;
begin
  Result := Name;
end;

end.
