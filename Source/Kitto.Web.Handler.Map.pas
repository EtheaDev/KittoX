{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   This file is part of KittoX Enterprise Edition.
   Licensed under the AGPL-3.0 or Ethea Commercial License.
   See LICENSE-ENTERPRISE for details.
-------------------------------------------------------------------------------}

unit Kitto.Web.Handler.Map;

{$I Kitto.Defines.inc}
{$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}

interface

uses
  Kitto.Web.Routing.Attributes,
  Kitto.Metadata.DataView;

type
  [TKXPath('/kx/view/{ViewName}')]
  TKXMapHandler = class
  public
    [TKXPath('/map-data')]
    [TKXGET]
    procedure HandleMapData(
      [TKXPathParam('ViewName')] const AViewName: string;
      [TKXContext] ADataView: TKDataView);
  end;

implementation

uses
  System.SysUtils,
  EF.Tree,
  Kitto.Metadata.Views,
  Kitto.Store,
  Kitto.Web.Response,
  Kitto.Html.GoogleMap,
  Kitto.Web.Routing.Registry;

procedure TKXMapHandler.HandleMapData(const AViewName: string;
  ADataView: TKDataView);
var
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LControllerNode, LMapNode, LCenterNode: TEFNode;
  LAddressFields, LTitleField, LInfoFields: string;
  LMarkersJson, LGridHtml, LJson: string;
begin
  Assert(Assigned(ADataView), 'ADataView Assigned');
  Assert(Assigned(ADataView.MainTable), 'ADataView.MainTable Assigned');

  LViewTable := ADataView.MainTable;

  LControllerNode := ADataView.FindNode('Controller');
  if not Assigned(LControllerNode) then
    Exit;

  LMapNode := LControllerNode.FindNode('GoogleMap');
  if not Assigned(LMapNode) then
  begin
    LCenterNode := LControllerNode.FindNode('CenterController');
    if Assigned(LCenterNode) then
      LMapNode := LCenterNode.FindNode('GoogleMap');
  end;
  if not Assigned(LMapNode) then
    Exit;

  LAddressFields := LMapNode.GetString('AddressFields', '');
  LTitleField := LMapNode.GetString('TitleField', '');
  LInfoFields := LMapNode.GetString('InfoFields', '');
  if LAddressFields = '' then
    Exit;

  LStore := LViewTable.CreateStore;
  try
    LStore.Load('', '', 0, 0);

    LMarkersJson := TKXGoogleMapController.BuildMarkersJsonFromStore(
      LStore, LAddressFields, LTitleField, LInfoFields);
    LGridHtml := TKXGoogleMapController.BuildGridRows(LStore, LViewTable);
    LGridHtml := TKXGoogleMapController.JSONStr(LGridHtml);

    LJson := '{"markers": ' + LMarkersJson + ', "gridHtml": ' + LGridHtml + '}';

    TKWebResponse.Current.Items.Clear;
    TKWebResponse.Current.Items.AddHTML(LJson);
    TKWebResponse.Current.ContentType := 'application/json; charset=utf-8';
  finally
    FreeAndNil(LStore);
  end;
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXMapHandler);

finalization
  TKXResourceRegistry.Instance.UnregisterResource(TKXMapHandler);

end.
