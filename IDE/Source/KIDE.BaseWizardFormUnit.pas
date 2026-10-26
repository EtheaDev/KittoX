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
unit KIDE.BaseWizardFormUnit;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Actions,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  {$IFDEF KIDEGUI}Vcl.StyledTaskDialog,{$ENDIF}
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.ActnList,
  Vcl.ExtCtrls,
  KIDE.BaseFormUnit
  {$IFDEF KIDEGUI}, Vcl.StyledComponentsHooks{$ENDIF};

type
  TBaseWizardForm = class(TBaseForm)
    PageControl: TPageControl;
    BackButton: TButton;
    ForwardButton: TButton;
    ActionList: TActionList;
    BackAction: TAction;
    ForwardAction: TAction;
    ButtonPanel: TPanel;
    TitlePanel: TPanel;
    procedure BackActionUpdate(Sender: TObject);
    procedure ForwardActionUpdate(Sender: TObject);
    procedure BackActionExecute(Sender: TObject);
    procedure ForwardActionExecute(Sender: TObject);
    procedure RefreshForwardButton;
    procedure FormShow(Sender: TObject);
  private
    function GetPageTitle: string;
    procedure SetPageTitle(const AValue: string);
    function GetPageIndex: Integer;
  protected
    {
      Called when the form is shown.
    }
    procedure InitWizard; virtual;
    {
      Called when the user is about to leave page ACurrentPageIndex and going
      to page ANewPageIndex.
    }
    procedure BeforeLeavePage(const ACurrentPageIndex, ANewPageIndex: Integer;
      const AGoingForward: Boolean); virtual;
    {
      Called when the user is about to enter page ANewPageIndex and coming
      from page ACurrentPageIndex.
    }
    procedure BeforeEnterPage(const ANewPageIndex, ACurrentPageIndex: Integer;
      const AGoingForward: Boolean); virtual;
    {
      Called when the user has left page AOldPageIndex to go to page ACurrentPageIndex.
    }
    procedure AfterLeavePage(const AOldPageIndex, ACurrentPageIndex: Integer;
      const AGoingForward: Boolean); virtual;
    {
      Called when the user has entered page ACurrentPageIndex coming from
      page AOldPageIndex.
    }
    procedure AfterEnterPage(const ACurrentPageIndex, AOldPageIndex: Integer;
      const AGoingForward: Boolean); virtual;
    {
      Called to decide whether to enable the Back button or not. By default, it
      is enabled unless on the first page (in which case it is also invisible).
    }
    function CanGoBack: Boolean; virtual;
    {
      Called to decide whether to enable the Forward button or not. By default,
      it is always enabled (when on the last page, it will close the form).
    }
    function CanGoForward: Boolean; virtual;

    property PageTitle: string read GetPageTitle write SetPageTitle;

    property PageIndex: Integer read GetPageIndex;

    procedure FinishWizard; virtual;
    {
      Catches Esc (which a wizard, having no Cancel button, would otherwise
      ignore) and closes the form through CloseQuery, so it asks for confirmation
      just like the X button.
    }
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    function CloseQuery: Boolean; override;
  end;

implementation

{$R *.dfm}

uses
  EF.Tree,
  EF.Localization,
  Kide.Config,
  KIDE.MRUOptions;

function TBaseWizardForm.CanGoBack: Boolean;
begin
  Result := PageControl.ActivePageIndex > 0;
end;

function TBaseWizardForm.CanGoForward: Boolean;
begin
  Result := True;
end;

procedure TBaseWizardForm.BackActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := CanGoBack;
end;

procedure TBaseWizardForm.AfterEnterPage(const ACurrentPageIndex, AOldPageIndex: Integer;
  const AGoingForward: Boolean);
begin
  BackAction.Visible := ACurrentPageIndex > 0;
end;

procedure TBaseWizardForm.AfterLeavePage(const AOldPageIndex, ACurrentPageIndex: Integer;
  const AGoingForward: Boolean);
begin
end;

procedure TBaseWizardForm.BeforeEnterPage(const ANewPageIndex, ACurrentPageIndex: Integer;
  const AGoingForward: Boolean);
begin
end;

procedure TBaseWizardForm.BeforeLeavePage(const ACurrentPageIndex, ANewPageIndex: Integer;
  const AGoingForward: Boolean);
begin
end;

constructor TBaseWizardForm.Create(AOwner: TComponent);
begin
  inherited;
  ForwardAction.Caption := _('Next >>');
  BackAction.Caption := _('<< Previous');
  // Let the form see Esc before the focused control (a wizard has no Cancel
  // button, so Esc would otherwise be ignored).
  KeyPreview := True;
  // The MRU remembers where the wizard was closed, and FormShow restores
  // it - but poMainFormCenter centres the window right AFTER OnShow
  // (TCustomForm.CMShowingChanged), undoing that Left/Top: every wizard
  // reopened centred, and the stored position was never used. With a
  // position to restore, use poDesigned so the centring does not run. It
  // must be decided here, before the window exists: changing Position
  // recreates the window, which OnShow forbids ("Cannot change Visible in
  // OnShow or OnHide"). The first opening, with nothing stored, stays centred.
  if Assigned(TMRUOptions.Instance.FindNode(Name + '/Left')) then
    Position := poDesigned;
end;

procedure TBaseWizardForm.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited;
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    Key := 0;
    Close; // routes through CloseQuery -> confirmation, same as the X button
  end;
end;

function TBaseWizardForm.CloseQuery: Boolean;
begin
  Result := inherited CloseQuery;
  if not Result then
    Exit;
  // Finishing the wizard (Forward on the last page) sets ModalResult := mrOk and
  // closes without asking. Any other close — the X button, or a Cancel — leaves
  // ModalResult <> mrOk: confirm, so the user does not lose the wizard's work by
  // accidentally closing the window (this fires on any page, last one included).
  if ModalResult <> mrOk then
    Result := {$IFDEF KIDEGUI}StyledMessageDlg{$ELSE}MessageDlg{$ENDIF}(_('Close the wizard without finishing? Any changes will be lost.'),
      mtConfirmation, [mbYes, mbNo], 0) = mrYes;
end;

procedure TBaseWizardForm.BackActionExecute(Sender: TObject);
begin
  BeforeLeavePage(PageControl.ActivePageIndex, PageControl.ActivePageIndex - 1, False);
  BeforeEnterPage(PageControl.ActivePageIndex - 1, PageControl.ActivePageIndex, False);
  PageControl.SelectNextPage(False, False);
  AfterLeavePage(PageControl.ActivePageIndex + 1, PageControl.ActivePageIndex, False);
  AfterEnterPage(PageControl.ActivePageIndex, PageControl.ActivePageIndex + 1, False);
  RefreshForwardButton;
end;

// The caption of the forward button ("Next >>" or "Finish") follows the page
// through ForwardActionUpdate, but the styled button KIDEX draws (every TButton
// is a TStyledButton) does not repaint when only its text changes: coming back
// from the last page it kept saying "Finish" until something else - the mouse
// over it, a change of Enabled - made it redraw. Set the caption at once and
// repaint, so that the page change and the button agree without waiting.
procedure TBaseWizardForm.RefreshForwardButton;
begin
  ForwardActionUpdate(ForwardAction);
  ForwardButton.Invalidate;
end;

procedure TBaseWizardForm.ForwardActionUpdate(Sender: TObject);
begin
  (Sender as TAction).Enabled := CanGoForward;
  if PageControl.ActivePageIndex = PageControl.PageCount - 1 then
    (Sender as TAction).Caption := _('Finish')
  else
    (Sender as TAction).Caption := _('Next >>');
end;

function TBaseWizardForm.GetPageIndex: Integer;
begin
  Result := PageControl.ActivePageIndex;
end;

function TBaseWizardForm.GetPageTitle: string;
begin
  Result := TitlePanel.Caption;
end;

procedure TBaseWizardForm.ForwardActionExecute(Sender: TObject);
begin
  if PageControl.ActivePageIndex = PageControl.PageCount - 1 then
  begin
    FinishWizard;
    ModalResult := mrOk;
  end
  else
  begin
    BeforeLeavePage(PageControl.ActivePageIndex, PageControl.ActivePageIndex + 1, True);
    BeforeEnterPage(PageControl.ActivePageIndex + 1, PageControl.ActivePageIndex, True);
    PageControl.SelectNextPage(True, False);
    AfterLeavePage(PageControl.ActivePageIndex - 1, PageControl.ActivePageIndex, True);
    AfterEnterPage(PageControl.ActivePageIndex, PageControl.ActivePageIndex - 1, True);
    RefreshForwardButton;
  end;
end;

procedure TBaseWizardForm.FinishWizard;
begin
  BeforeLeavePage(PageControl.ActivePageIndex, -1, True);
  AfterLeavePage(PageControl.ActivePageIndex, -1, True);
end;

procedure TBaseWizardForm.FormShow(Sender: TObject);
var
  LNode: TEFNode;
begin
  // Establish the wizard's default size BEFORE inherited: RestorePositionAndSize
  // uses the current Width/Height as the fallback when no size is stored in the
  // MRU, and overrides them with the remembered size when it is. Setting the
  // size here (instead of in InitWizard, which runs AFTER inherited) stops the
  // restored size from being clobbered — previously the wizard always reopened
  // at the default size while Left/Top were correctly remembered.
  LNode := TKideConfig.Instance.Config.GetNode(Self.Name+'/Size', True);
  Width := LNode.GetValue('Width', 900);
  Height := LNode.GetValue('Height', 700);
  inherited; // restores Left/Top/Width/Height from the MRU
  if Position = poDesigned then
    MakeFullyVisible; // a position saved on a monitor that is gone
  InitWizard;
end;

procedure TBaseWizardForm.InitWizard;
var
  I: Integer;
begin
  for I := 0 to PageControl.PageCount - 1 do
    PageControl.Pages[I].TabVisible := False;

  BeforeEnterPage(0, -1, True);
  PageControl.ActivePageIndex := 0;
  AfterEnterPage(0, -1, True);
end;

procedure TBaseWizardForm.SetPageTitle(const AValue: string);
begin
  TitlePanel.Caption := AValue;
  TitlePanel.Update;
end;

end.
