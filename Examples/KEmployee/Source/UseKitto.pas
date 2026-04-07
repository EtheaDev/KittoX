unit UseKitto;

{$I Kitto.Defines.inc}

interface

uses
  //Core Kitto Units
  Kitto.Html.All,
  Kitto.Web.Enterprise,
  {$IFDEF MSWINDOWS}
  // EF.DB.ADO,
  EF.DB.DBX,
  Data.DBXFirebird,
  {$ENDIF}
  EF.DB.FD,
  // Kitto.AccessControl.DB,
  // Kitto.Auth.DB,
  // Kitto.Auth.DBServer,
  // Kitto.Auth.OSDB,
  Kitto.Auth.TextFile,
  Kitto.Tool.ADO, //For Excel export
  // Kitto.Localization.dxgettext, //Commented to enable per-session localization
  Kitto.Metadata.ModelImplementation,
  Kitto.Metadata.ViewBuilders
  ;

implementation

end.
