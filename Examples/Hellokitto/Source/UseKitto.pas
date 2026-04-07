unit UseKitto;

interface

uses
  Data.DBXMSSQL,
  Data.DBXFirebird,
  EF.DB.ADO,
  EF.DB.DBX,
  EF.DB.FD, //FireDac support
  FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLMeta, //FireDac support for MS-SQL
  FireDAC.Phys.IBBase, FireDAC.Phys.FB, //FireDac support for Firebird
  //Global Kittox uses
  Kitto.Html.All,
  Kitto.Web.Enterprise
  // Kitto.AccessControl.DB,
  , Kitto.Auth.DB
  // Kitto.Auth.DBServer,
  // Kitto.Auth.OSDB,
  // Kitto.Auth.TextFile,
  , Kitto.Tool.ADO //For Excel/Import export
  , Kitto.Tool.DebenuQuickPDF //For PDF Merge
  //, Kitto.Ext.ReportBuilderTools //Tool for Reportbuilder
  //, Kitto.Ext.FOPTools //For FOP Engine
  // Kitto.Localization.dxgettext, //Commented to enable per-session localization
  ;

implementation

initialization
{$WARN SYMBOL_PLATFORM OFF}
  // check memory leaks at the end of the app
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
{$WARN SYMBOL_PLATFORM ON}

end.
