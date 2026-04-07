{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   This file is part of KittoX Enterprise Edition.
   Licensed under the AGPL-3.0 or Ethea Commercial License.
   See LICENSE-ENTERPRISE for details.
-------------------------------------------------------------------------------}

/// <summary>
///   Dashboard controller: FlexPanel with a header and optional auto-refresh
///   via HTMX polling. Enterprise module — include Kitto.Web.Enterprise
///   in UseKitto.pas to enable.
/// </summary>
unit Kitto.Html.Dashboard;

{$I Kitto.Defines.inc}

interface

uses
  EF.YAML.Attributes,
  Kitto.Metadata.SubNodes2,
  Kitto.Html.FlexPanel;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXDashboardController = class(TKXFlexPanelController)
  strict private
    FRefreshInterval: Integer;
  strict protected
    function GetPanelCssClass: string; override;
    procedure DoDisplay; override;
    function RenderContent: string; override;
  public
    [YamlNode('RefreshInterval', 'Auto-refresh interval in seconds (0 = disabled)')]
    property RefreshInterval: Integer read FRefreshInterval write FRefreshInterval;
  end;

implementation

uses
  System.SysUtils,
  Kitto.Metadata.Views,
  Kitto.Html.Controller;

{ TKXDashboardController }

procedure TKXDashboardController.DoDisplay;
begin
  inherited;
  FRefreshInterval := Config.GetInteger('RefreshInterval', 0);
end;

function TKXDashboardController.GetPanelCssClass: string;
begin
  Result := 'kx-flex-panel kx-dashboard';
end;

function TKXDashboardController.RenderContent: string;
var
  LItemsHtml: string;
  LRefreshAttr: string;
begin
  LItemsHtml := inherited RenderContent;

  if FRefreshInterval > 0 then
  begin
    LRefreshAttr := Format(
      ' hx-get="kx/view/%s" hx-trigger="every %ds"' +
      ' hx-target="closest .kx-tab-pane" hx-swap="innerHTML"',
      [View.PersistentName, FRefreshInterval]);
    Result := Format('<div id="%s-refresh"%s style="display:none"></div>%s',
      [GetHtmlId, LRefreshAttr, LItemsHtml]);
  end
  else
    Result := LItemsHtml;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('Dashboard', TKXDashboardController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('Dashboard');

end.
