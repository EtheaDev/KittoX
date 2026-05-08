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
unit KIDE.Controls;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms;

function ScaledValue(const AForm: TForm; const AValue: Integer): Integer; overload;
function ScaledValue(const AFrame: TFrame; const AValue: Integer): Integer; overload;
function ScaledValue(const AControl: TWinControl; const AValue: Integer): Integer; overload;
function UnscaledValue(const AForm: TForm; const AValue: Integer): Integer; overload;
function UnscaledValue(const AFrame: TFrame; const AValue: Integer): Integer; overload;
function UnscaledValue(const AControl: TWinControl; const AValue: Integer): Integer; overload;
/// <summary>Suspends painting on a control (WM_SETREDRAW off).
/// Call EndControlUpdate to resume and repaint.</summary>
procedure BeginControlUpdate(const AControl: TWinControl);
/// <summary>Resumes painting on a control and forces a full repaint.</summary>
procedure EndControlUpdate(const AControl: TWinControl);

implementation

uses
  Winapi.Windows,
  Winapi.Messages;

function ScaledValue(const AForm: TForm; const AValue: Integer): Integer;
begin
  Result := Round(AValue * AForm.ScaleFactor);
end;

function ScaledValue(const AFrame: TFrame; const AValue: Integer): Integer;
var
  LForm: TCustomForm;
begin
  LForm := GetParentForm(AFrame);
  if Assigned(LForm) and (LForm is TForm) then
    Result := ScaledValue(LForm, AValue)
  else
    Result := AValue;
end;

function UnscaledValue(const AForm: TForm; const AValue: Integer): Integer;
begin
  Result := Round(AValue / AForm.ScaleFactor);
end;

function UnscaledValue(const AFrame: TFrame; const AValue: Integer): Integer;
var
  LForm: TCustomForm;
begin
  LForm := GetParentForm(AFrame);
  if Assigned(LForm) and (LForm is TForm) then
    Result := UnscaledValue(TForm(LForm), AValue)
  else
    Result := AValue;
end;

function ScaledValue(const AControl: TWinControl; const AValue: Integer): Integer;
var
  LForm: TCustomForm;
begin
  LForm := GetParentForm(AControl);
  if Assigned(LForm) and (LForm is TForm) then
    Result := ScaledValue(TForm(LForm), AValue)
  else
    Result := AValue;
end;

function UnscaledValue(const AControl: TWinControl; const AValue: Integer): Integer;
var
  LForm: TCustomForm;
begin
  LForm := GetParentForm(AControl);
  if Assigned(LForm) and (LForm is TForm) then
    Result := UnscaledValue(TForm(LForm), AValue)
  else
    Result := AValue;
end;

var
  _LockCount: Integer = 0;
  _LockHandle: HWND = 0;

procedure BeginControlUpdate(const AControl: TWinControl);
var
  LForm: TCustomForm;
begin
  Inc(_LockCount);
  if _LockCount = 1 then
  begin
    // LockWindowUpdate works on one window at a time — use the top-level form
    LForm := GetParentForm(AControl);
    if Assigned(LForm) and LForm.HandleAllocated then
      _LockHandle := LForm.Handle
    else if AControl.HandleAllocated then
      _LockHandle := AControl.Handle
    else
    begin
      _LockHandle := 0;
      Exit;
    end;
    LockWindowUpdate(_LockHandle);
  end;
end;

procedure EndControlUpdate(const AControl: TWinControl);
begin
  if _LockCount > 0 then
    Dec(_LockCount);
  if (_LockCount = 0) and (_LockHandle <> 0) then
  begin
    LockWindowUpdate(0);
    _LockHandle := 0;
  end;
end;

end.

