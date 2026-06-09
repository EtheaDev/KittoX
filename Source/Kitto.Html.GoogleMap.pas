{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   This file is part of KittoX Enterprise Edition.
   Licensed under the AGPL-3.0 or Ethea Commercial License.
   See LICENSE-ENTERPRISE for details.
-------------------------------------------------------------------------------}

/// <summary>
///  KittoX GoogleMap controller: renders a Google Maps view with optional
///  data grid sidebar. Supports geocoding-based markers from model data,
///  static markers from YAML, and routing via Google Directions API.
///  Inspired by TEdgeGoogleMapViewer (DelphiGoogleMap project).
/// </summary>
unit Kitto.Html.GoogleMap;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Html.DataPanel,
  Kitto.Html.Controller,
  Kitto.Metadata.DataView,
  EF.YAML.Attributes;

type
  {$RTTI EXPLICIT PROPERTIES([vcPublic])}
  TKXGoogleMapController = class(TKXDataPanelController)
  strict private
    FViewName: string;
    function GetApiKey: string;
    function GetCenterLatitude: Double;
    function GetCenterLongitude: Double;
    function GetCenterAddress: string;
    function GetZoom: Integer;
    function GetMapTypeId: string;
    function GetMapHeight: Integer;
    function GetAddressFields: string;
    function GetTitleField: string;
    function GetInfoFields: string;
    function GetSidebarPosition: string;
    function GetSidebarWidth: Integer;
    function GetMapControlZoom: Boolean;
    function GetMapControlMapType: Boolean;
    function GetMapControlFullScreen: Boolean;
    function GetMapControlStreetView: Boolean;
    function GetMapViewTraffic: Boolean;
    function GetMapViewBicycling: Boolean;
    function GetMapViewMarkers: Boolean;
    function GetMapBoolean(const APath: string; ADefault: Boolean): Boolean;
    function BuildMapConfig(AStore: TKViewTableStore): string;
    function BuildMapToolbar: string;
    function BuildToggleButton(const AFeature, AIconName, ALabel: string): string;
    function BuildControlCheckbox(const AControl, ALabel: string): string;
  strict protected
    function GetDefaultIsModal: Boolean; override;
    function GetPanelCssClass: string; override;
    function IsActionSupported(const AActionName: string): Boolean; override;
    procedure DoDisplay; override;
    function RenderContent: string; override;
  public
    /// <summary>Escapes a string for JSON output (adds surrounding double quotes).</summary>
    class function JSONStr(const AValue: string): string;

    /// <summary>
    ///  Builds a JSON array of marker objects from a store.
    ///  Each marker has address (concatenated from AddressFields), title, and info.
    ///  Public class function for reuse by the map-data AJAX endpoint.
    /// </summary>
    class function BuildMarkersJsonFromStore(
      AStore: TKViewTableStore;
      const AAddressFields, ATitleField, AInfoFields: string): string;

    /// <summary>
    ///  Builds grid table rows (tbody content) for the sidebar.
    ///  Public class function for reuse by the map-data endpoint.
    /// </summary>
    class function BuildGridRows(AStore: TKViewTableStore;
      AViewTable: TKViewTable): string;

    [YamlNode('GoogleMap/ApiKey', 'Google Maps JavaScript API key (overrides Config.yaml)')]
    property ApiKey: string read GetApiKey;
    [YamlNode('GoogleMap/Center/Latitude', '0', 'Map center latitude')]
    property CenterLatitude: Double read GetCenterLatitude;
    [YamlNode('GoogleMap/Center/Longitude', '0', 'Map center longitude')]
    property CenterLongitude: Double read GetCenterLongitude;
    [YamlNode('GoogleMap/Center/Address', '', 'Map center by address (geocoded)')]
    property CenterAddress: string read GetCenterAddress;
    [YamlNode('GoogleMap/Zoom', '12', 'Initial zoom level (1-20)')]
    property Zoom: Integer read GetZoom;
    [YamlNode('GoogleMap/MapTypeId', 'ROADMAP', 'Map type: ROADMAP, SATELLITE, HYBRID, TERRAIN')]
    property MapTypeId: string read GetMapTypeId;
    [YamlNode('GoogleMap/Height', '0', 'Map height in px (0 = fill container)')]
    property MapHeight: Integer read GetMapHeight;
    [YamlNode('GoogleMap/AddressFields', '', 'Comma-separated model fields for geocoding address')]
    property AddressFields: string read GetAddressFields;
    [YamlNode('GoogleMap/TitleField', '', 'Model field for marker title')]
    property TitleField: string read GetTitleField;
    [YamlNode('GoogleMap/InfoFields', '', 'Comma-separated model fields for InfoWindow content')]
    property InfoFields: string read GetInfoFields;
    [YamlNode('GoogleMap/SidebarPosition', 'West', 'Sidebar position: West or East')]
    property SidebarPosition: string read GetSidebarPosition;
    [YamlNode('GoogleMap/SidebarWidth', '400', 'Sidebar width in pixels')]
    property SidebarWidth: Integer read GetSidebarWidth;
    [YamlNode('GoogleMap/MapControls/Zoom', 'False', 'Show zoom control on map')]
    property MapControlZoom: Boolean read GetMapControlZoom;
    [YamlNode('GoogleMap/MapControls/MapType', 'False', 'Show map type control')]
    property MapControlMapType: Boolean read GetMapControlMapType;
    [YamlNode('GoogleMap/MapControls/FullScreen', 'False', 'Show fullscreen control')]
    property MapControlFullScreen: Boolean read GetMapControlFullScreen;
    [YamlNode('GoogleMap/MapControls/StreetView', 'True', 'Show street view control')]
    property MapControlStreetView: Boolean read GetMapControlStreetView;
    [YamlNode('GoogleMap/MapView/Traffic', 'True', 'Show traffic layer')]
    property MapViewTraffic: Boolean read GetMapViewTraffic;
    [YamlNode('GoogleMap/MapView/Bicycling', 'True', 'Show bicycling layer')]
    property MapViewBicycling: Boolean read GetMapViewBicycling;
    [YamlNode('GoogleMap/MapView/Markers', 'False', 'Show markers')]
    property MapViewMarkers: Boolean read GetMapViewMarkers;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.NetEncoding,
  EF.Tree,
  EF.Localization,
  Kitto.Config,
  Kitto.Html.Base,
  Kitto.Html.Utils,
  Kitto.Web.Routing.Scripts;

{ TKXGoogleMapController }

function TKXGoogleMapController.GetDefaultIsModal: Boolean;
begin
  Result := False;
end;

function TKXGoogleMapController.GetPanelCssClass: string;
begin
  Result := 'kx-googlemap-panel';
end;

function TKXGoogleMapController.IsActionSupported(const AActionName: string): Boolean;
begin
  // Map is read-only display - no CRUD actions
  Result := False;
end;

procedure TKXGoogleMapController.DoDisplay;
begin
  inherited;
  if Assigned(View) then
    FViewName := View.PersistentName
  else
    FViewName := '';
end;

function TKXGoogleMapController.GetApiKey: string;
begin
  // View-level override, then global Config.yaml
  Result := Config.GetExpandedString('GoogleMap/ApiKey', '');
  if Result = '' then
    Result := Config.GetExpandedString('CenterController/GoogleMap/ApiKey', '');
  if Result = '' then
    Result := TKConfig.Instance.Config.GetExpandedString('GoogleMapsApiKey', '');
end;

function TKXGoogleMapController.GetCenterLatitude: Double;
begin
  Result := Config.GetFloat('GoogleMap/Center/Latitude',
    Config.GetFloat('CenterController/GoogleMap/Center/Latitude', 0));
end;

function TKXGoogleMapController.GetCenterLongitude: Double;
begin
  Result := Config.GetFloat('GoogleMap/Center/Longitude',
    Config.GetFloat('CenterController/GoogleMap/Center/Longitude', 0));
end;

function TKXGoogleMapController.GetCenterAddress: string;
begin
  Result := Config.GetExpandedString('GoogleMap/Center/Address',
    Config.GetExpandedString('CenterController/GoogleMap/Center/Address', ''));
end;

function TKXGoogleMapController.GetZoom: Integer;
begin
  Result := Config.GetInteger('GoogleMap/Zoom',
    Config.GetInteger('CenterController/GoogleMap/Zoom', 12));
end;

function TKXGoogleMapController.GetMapTypeId: string;
begin
  Result := Config.GetString('GoogleMap/MapTypeId',
    Config.GetString('CenterController/GoogleMap/MapTypeId', 'ROADMAP'));
end;

function TKXGoogleMapController.GetMapHeight: Integer;
begin
  Result := Config.GetInteger('GoogleMap/Height',
    Config.GetInteger('CenterController/GoogleMap/Height', 0));
end;

function TKXGoogleMapController.GetAddressFields: string;
begin
  Result := Config.GetString('GoogleMap/AddressFields',
    Config.GetString('CenterController/GoogleMap/AddressFields', ''));
end;

function TKXGoogleMapController.GetTitleField: string;
begin
  Result := Config.GetString('GoogleMap/TitleField',
    Config.GetString('CenterController/GoogleMap/TitleField', ''));
end;

function TKXGoogleMapController.GetInfoFields: string;
begin
  Result := Config.GetString('GoogleMap/InfoFields',
    Config.GetString('CenterController/GoogleMap/InfoFields', ''));
end;

function TKXGoogleMapController.GetSidebarPosition: string;
begin
  Result := Config.GetString('GoogleMap/SidebarPosition',
    Config.GetString('CenterController/GoogleMap/SidebarPosition', 'West'));
end;

function TKXGoogleMapController.GetSidebarWidth: Integer;
begin
  Result := Config.GetInteger('GoogleMap/SidebarWidth',
    Config.GetInteger('CenterController/GoogleMap/SidebarWidth', 400));
end;

function TKXGoogleMapController.GetMapControlZoom: Boolean;
begin
  Result := GetMapBoolean('MapControls/Zoom', True);
end;

function TKXGoogleMapController.GetMapControlMapType: Boolean;
begin
  Result := GetMapBoolean('MapControls/MapType', True);
end;

function TKXGoogleMapController.GetMapControlFullScreen: Boolean;
begin
  Result := GetMapBoolean('MapControls/FullScreen', True);
end;

function TKXGoogleMapController.GetMapControlStreetView: Boolean;
begin
  Result := GetMapBoolean('MapControls/StreetView', False);
end;

function TKXGoogleMapController.GetMapViewTraffic: Boolean;
begin
  Result := GetMapBoolean('MapView/Traffic', False);
end;

function TKXGoogleMapController.GetMapViewBicycling: Boolean;
begin
  Result := GetMapBoolean('MapView/Bicycling', False);
end;

function TKXGoogleMapController.GetMapViewMarkers: Boolean;
begin
  Result := GetMapBoolean('MapView/Markers', True);
end;

class function TKXGoogleMapController.JSONStr(const AValue: string): string;
begin
  Result := StringReplace(AValue, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13#10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\n', [rfReplaceAll]);
  Result := '"' + Result + '"';
end;

class function TKXGoogleMapController.BuildMarkersJsonFromStore(
  AStore: TKViewTableStore;
  const AAddressFields, ATitleField, AInfoFields: string): string;
var
  I, J: Integer;
  LRecord: TKViewTableRecord;
  LRecordField: TKViewTableField;
  LAddrParts, LInfoParts: TArray<string>;
  LAddress, LTitle, LInfo, LPart: string;
  SB: TStringBuilder;
begin
  LAddrParts := AAddressFields.Split([',']);
  LInfoParts := AInfoFields.Split([',']);

  SB := TStringBuilder.Create;
  try
    SB.Append('[');
    for I := 0 to AStore.RecordCount - 1 do
    begin
      LRecord := AStore.Records[I];

      // Build address from fields
      LAddress := '';
      for J := 0 to Length(LAddrParts) - 1 do
      begin
        LPart := Trim(LAddrParts[J]);
        if LPart = '' then
          Continue;
        LRecordField := LRecord.FindField(LPart);
        if Assigned(LRecordField) and not LRecordField.IsNull and
           (Trim(LRecordField.AsString) <> '') then
        begin
          if LAddress <> '' then
            LAddress := LAddress + ', ';
          LAddress := LAddress + Trim(LRecordField.AsString);
        end;
      end;

      // Skip records with no address
      if LAddress = '' then
        Continue;

      // Build title
      LTitle := '';
      if ATitleField <> '' then
      begin
        LRecordField := LRecord.FindField(Trim(ATitleField));
        if Assigned(LRecordField) and not LRecordField.IsNull then
          LTitle := LRecordField.AsString;
      end;

      // Build info HTML: title goes in InfoWindow header, body has remaining fields
      LInfo := '';
      for J := 0 to Length(LInfoParts) - 1 do
      begin
        LPart := Trim(LInfoParts[J]);
        if LPart = '' then
          Continue;
        // Skip the title field to avoid duplication
        if SameText(LPart, Trim(ATitleField)) then
          Continue;
        LRecordField := LRecord.FindField(LPart);
        if Assigned(LRecordField) and not LRecordField.IsNull and
           (Trim(LRecordField.AsString) <> '') then
        begin
          if LInfo <> '' then
            LInfo := LInfo + '<br>';
          LInfo := LInfo + TNetEncoding.HTML.Encode(LRecordField.AsString);
        end;
      end;

      if SB.Length > 1 then
        SB.Append(', ');
      SB.Append('{');
      SB.Append('"address": ').Append(JSONStr(LAddress));
      SB.Append(', "title": ').Append(JSONStr(LTitle));
      SB.Append(', "info": ').Append(JSONStr(LInfo));
      SB.Append(', "idx": ').Append(IntToStr(I));
      SB.Append('}');
    end;
    SB.Append(']');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TKXGoogleMapController.BuildGridRows(
  AStore: TKViewTableStore; AViewTable: TKViewTable): string;
var
  I, J, LColCount: Integer;
  LField: TKViewField;
  LRecord: TKViewTableRecord;
  LRecordField: TKViewTableField;
  LValue, LAlign: string;
  SB: TStringBuilder;
begin
  if AStore.RecordCount = 0 then
  begin
    LColCount := 0;
    for I := 0 to AViewTable.FieldCount - 1 do
      if AViewTable.Fields[I].IsVisible and not AViewTable.Fields[I].IsBlob then
        Inc(LColCount);
    Result := '<tr class="kx-list-empty"><td colspan="' + IntToStr(LColCount) + '">' +
      TNetEncoding.HTML.Encode(_('No records found.')) + '</td></tr>';
    Exit;
  end;

  SB := TStringBuilder.Create;
  try
    for I := 0 to AStore.RecordCount - 1 do
    begin
      LRecord := AStore.Records[I];
      SB.Append('<tr class="kx-googlemap-grid-row" onclick="kxGoogleMap.centerOnMarker(''')
        .Append(AViewTable.View.PersistentName).Append(''', ').Append(IntToStr(I)).Append(')" style="cursor:pointer">');
      for J := 0 to AViewTable.FieldCount - 1 do
      begin
        LField := AViewTable.Fields[J];
        if not LField.IsVisible or LField.IsBlob then
          Continue;
        LAlign := LField.DataType.GetDefaultColumnAlignment;
        LRecordField := LRecord.FindField(LField.AliasedName);
        if Assigned(LRecordField) and not LRecordField.IsNull then
        begin
          LValue := LRecordField.GetAsJSONValue(True, False);
          if SameText(LValue, 'null') then
            LValue := '';
        end
        else
          LValue := '';
        SB.Append('<td style="text-align:').Append(LAlign).Append('">');
        SB.Append(TNetEncoding.HTML.Encode(LValue)).Append('</td>');
      end;
      SB.Append('</tr>');
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXGoogleMapController.GetMapBoolean(const APath: string; ADefault: Boolean): Boolean;
begin
  Result := Config.GetBoolean('GoogleMap/' + APath,
    Config.GetBoolean('CenterController/GoogleMap/' + APath, ADefault));
end;

function TKXGoogleMapController.BuildToggleButton(
  const AFeature, AIconName, ALabel: string): string;
begin
  Result :=
    '<button type="button" class="kx-toolbar-btn" data-toggle="' + AFeature + '"' +
    ' onclick="kxGoogleMap.toggle(''' + FViewName + ''', ''' + AFeature + ''')">' +
    GetIconHTML(AIconName) +
    ' <span class="kx-btn-label">' + TNetEncoding.HTML.Encode(_(ALabel)) + '</span>' +
    '</button>';
end;

function TKXGoogleMapController.BuildControlCheckbox(
  const AControl, ALabel: string): string;
begin
  Result :=
    '<label class="kx-toolbar-checkbox">' +
    '<input type="checkbox" data-control="' + AControl + '"' +
    ' onchange="kxGoogleMap.toggleControl(''' + FViewName + ''', ''' + AControl + ''', this.checked)">' +
    ' ' + TNetEncoding.HTML.Encode(_(ALabel)) +
    '</label>';
end;

function TKXGoogleMapController.BuildMapToolbar: string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    SB.Append('<div class="kx-list-toolbar" id="kx-googlemap-toolbar-').Append(FViewName).Append('">');

    // Refresh button (always present)
    SB.Append('<button type="button" class="kx-toolbar-btn"')
      .Append(' onclick="kxGoogleMap.refresh(''').Append(FViewName).Append(''')">')
      .Append(GetIconHTML('refresh'))
      .Append(' <span class="kx-btn-label">').Append(TNetEncoding.HTML.Encode(_('Refresh'))).Append('</span>')
      .Append('</button>');

    // Separator
    SB.Append('<span class="kx-toolbar-sep"></span>');

    // MapView toggle buttons
    SB.Append(BuildToggleButton('traffic', 'traffic', 'Traffic'));
    SB.Append(BuildToggleButton('bicycling', 'directions_bike', 'Bicycling'));
    SB.Append(BuildToggleButton('markers', 'location_on', 'Markers'));

    // Separator before controls
    SB.Append('<span class="kx-toolbar-sep"></span>');

    // MapControls checkboxes
    SB.Append(BuildControlCheckbox('zoom', 'Zoom'));
    SB.Append(BuildControlCheckbox('mapType', 'Map Type'));
    SB.Append(BuildControlCheckbox('fullScreen', 'Full Screen'));
    SB.Append(BuildControlCheckbox('streetView', 'Street View'));

    SB.Append('</div>');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXGoogleMapController.BuildMapConfig(AStore: TKViewTableStore): string;
var
  LFmt: TFormatSettings;
  LMarkersJson: string;
  SB: TStringBuilder;
begin
  LFmt := TFormatSettings.Create;
  LFmt.DecimalSeparator := '.';
  LFmt.ThousandSeparator := #0;

  // Build markers from store if data-driven
  if Assigned(AStore) and (GetAddressFields <> '') then
    LMarkersJson := BuildMarkersJsonFromStore(AStore, GetAddressFields, GetTitleField, GetInfoFields)
  else
    LMarkersJson := '[]';

  SB := TStringBuilder.Create;
  try
    SB.Append('{');

    // API key
    SB.Append('"apiKey": ').Append(JSONStr(GetApiKey));

    // Center
    SB.Append(', "center": {"lat": ')
      .Append(FormatFloat('0.######', GetCenterLatitude, LFmt))
      .Append(', "lng": ')
      .Append(FormatFloat('0.######', GetCenterLongitude, LFmt))
      .Append('}');

    // Center address
    if GetCenterAddress <> '' then
      SB.Append(', "address": ').Append(JSONStr(GetCenterAddress));

    // Map options
    SB.Append(', "zoom": ').Append(IntToStr(GetZoom));
    SB.Append(', "mapTypeId": ').Append(JSONStr(GetMapTypeId));

    // MapControls (UI controls on the map)
    SB.Append(', "mapControls": {');
    SB.Append('"zoom": ').Append(IfThen(GetMapBoolean('MapControls/Zoom', True), 'true', 'false'));
    SB.Append(', "mapType": ').Append(IfThen(GetMapBoolean('MapControls/MapType', True), 'true', 'false'));
    SB.Append(', "fullScreen": ').Append(IfThen(GetMapBoolean('MapControls/FullScreen', True), 'true', 'false'));
    SB.Append(', "streetView": ').Append(IfThen(GetMapBoolean('MapControls/StreetView', False), 'true', 'false'));
    SB.Append('}');

    // MapView (toggleable layers/features)
    SB.Append(', "mapView": {');
    SB.Append('"traffic": ').Append(IfThen(GetMapBoolean('MapView/Traffic', False), 'true', 'false'));
    SB.Append(', "bicycling": ').Append(IfThen(GetMapBoolean('MapView/Bicycling', False), 'true', 'false'));
    SB.Append(', "markers": ').Append(IfThen(GetMapBoolean('MapView/Markers', True), 'true', 'false'));
    SB.Append('}');

    // Directions panel
    SB.Append(', "showDirectionsPanel": ').Append(IfThen(
      GetMapBoolean('ShowDirectionsPanel', False), 'true', 'false'));

    // Markers
    SB.Append(', "markers": ').Append(LMarkersJson);

    // Routing (optional)
    if Config.FindNode('GoogleMap/Routing') <> nil then
    begin
      SB.Append(', "routing": {');
      SB.Append('"origin": ').Append(JSONStr(
        Config.GetExpandedString('GoogleMap/Routing/Origin', '')));
      SB.Append(', "destination": ').Append(JSONStr(
        Config.GetExpandedString('GoogleMap/Routing/Destination', '')));
      SB.Append(', "mode": ').Append(JSONStr(
        Config.GetString('GoogleMap/Routing/Mode', 'DRIVING')));
      SB.Append('}');
    end;

    SB.Append('}');
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TKXGoogleMapController.RenderContent: string;
var
  LDataView: TKDataView;
  LViewTable: TKViewTable;
  LStore: TKViewTableStore;
  LSidebarWidth, LHeight: Integer;
  LSidebarPos: string;
  LMapConfig, LHeightStyle: string;
  I: Integer;
  LField: TKViewField;
  SB, SBSidebar: TStringBuilder;
  LHasData, LHasSidebar: Boolean;
begin
  Result := '';
  LStore := nil;
  LHasData := Assigned(View) and (View is TKDataView);

  if LHasData then
  begin
    LDataView := TKDataView(View);
    LViewTable := LDataView.MainTable;
    LHasData := Assigned(LViewTable);
  end
  else
    LViewTable := nil;

  // Sidebar config (internal, not WestController/EastController which
  // would conflict with RenderWithRegions in the base class)
  LSidebarPos := GetSidebarPosition;
  LSidebarWidth := GetSidebarWidth;

  // Load data if data-driven
  if LHasData then
  begin
    LStore := LViewTable.CreateStore;
    LStore.Load('', '', 0, 0);
  end;

  try
    // Build map config JSON
    LMapConfig := BuildMapConfig(LStore);

    // Height style
    LHeight := GetMapHeight;
    if LHeight > 0 then
      LHeightStyle := ' style="height:' + IntToStr(LHeight) + 'px"'
    else
      LHeightStyle := '';

    SBSidebar := TStringBuilder.Create;
    SB := TStringBuilder.Create;
    try
      // Build sidebar grid if data-driven
      LHasSidebar := LHasData and Assigned(LStore) and Assigned(LViewTable);
      if LHasSidebar then
      begin
        SBSidebar.Append(BuildMapToolbar);
        SBSidebar.Append('<div class="kx-googlemap-grid"><table class="kx-grid-table"><thead><tr>');
        for I := 0 to LViewTable.FieldCount - 1 do
        begin
          LField := LViewTable.Fields[I];
          if not LField.IsVisible or LField.IsBlob then
            Continue;
          SBSidebar.Append('<th>').Append(TNetEncoding.HTML.Encode(_(LField.DisplayLabel))).Append('</th>');
        end;
        SBSidebar.Append('</tr></thead><tbody id="kx-googlemap-grid-').Append(FViewName).Append('">');
        SBSidebar.Append(BuildGridRows(LStore, LViewTable));
        SBSidebar.Append('</tbody></table></div>');
      end;

      // West sidebar + splitter
      if LHasSidebar and SameText(LSidebarPos, 'West') then
      begin
        SB.Append('<div class="kx-googlemap-sidebar kx-googlemap-sidebar-west" style="width:')
          .Append(IntToStr(LSidebarWidth)).Append('px">');
        SB.Append(SBSidebar.ToString);
        SB.Append('<div class="kx-splitter kx-splitter-h" data-direction="horizontal" data-side="end"></div>');
        SB.Append('</div>');
      end;

      // Map area
      SB.Append('<div class="kx-googlemap-area">');
      SB.Append('<div id="kx-googlemap-').Append(FViewName)
        .Append('" class="kx-googlemap-container"').Append(LHeightStyle).Append('></div>');

      // Directions panel (optional)
      if GetMapBoolean('ShowDirectionsPanel', False) then
        SB.Append('<div id="kx-googlemap-directions-').Append(FViewName)
          .Append('" class="kx-googlemap-directions"></div>');

      SB.Append('</div>'); // close map area

      // East sidebar + splitter
      if LHasSidebar and SameText(LSidebarPos, 'East') then
      begin
        SB.Append('<div class="kx-googlemap-sidebar kx-googlemap-sidebar-east" style="width:')
          .Append(IntToStr(LSidebarWidth)).Append('px">');
        SB.Append('<div class="kx-splitter kx-splitter-h" data-direction="horizontal" data-side="start"></div>');
        SB.Append(SBSidebar.ToString);
        SB.Append('</div>');
      end;

      // Init script
      SB.Append('<script>kxGoogleMap.init(').Append(JSONStr(FViewName))
        .Append(', ').Append(LMapConfig).Append(');</script>');

      Result := SB.ToString;
    finally
      SB.Free;
      SBSidebar.Free;
    end;
  finally
    FreeAndNil(LStore);
  end;
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('GoogleMap', TKXGoogleMapController);
  TKXScriptRegistry.Instance.RegisterScript('/js/kxgooglemap.js');

finalization
  TKXControllerRegistry.Instance.UnregisterClass('GoogleMap');

end.
