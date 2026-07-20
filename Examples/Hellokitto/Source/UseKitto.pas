unit UseKitto;

interface

uses
  // ---------------------------------------------------------------------------
  // DELPHI ENTERPRISE (or ARCHITECT) REQUIRED for the client/server database
  // drivers listed below: the DBExpress Data.DBX* drivers and the FireDAC
  // FireDAC.Phys.* drivers for remote DBMS (MS SQL Server, Oracle, PostgreSQL,
  // MySQL, Firebird...). Access to client/server databases is a feature of the
  // Enterprise and Architect editions only. Delphi PROFESSIONAL ships FireDAC/
  // DBExpress with local/embedded drivers only (SQLite, InterBase ToGo), so on
  // a Professional license these uses do NOT compile (e.g. "unit
  // FireDAC.Phys.MSSQL not found"). A KittoX web app normally connects to a
  // client/server DB, so building this example needs a license upgrade from
  // Professional to Enterprise (or Architect). With Professional you can only
  // target a local DB (SQLite/InterBase) — remove the client/server driver uses
  // accordingly. (ADO/dbGo and the SQLite/InterBase drivers are in Professional.)
  // ---------------------------------------------------------------------------
  Data.DBXMSSQL,
  Data.DBXFirebird,
  EF.DB.ADO,
  EF.DB.DBX,
  EF.DB.FD, //FireDac support
  FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLMeta, //FireDac support for MS-SQL
  FireDAC.Phys.IBBase, FireDAC.Phys.FB, //FireDac support for Firebird
  FireDAC.Phys.PG, FireDAC.Phys.PGWrapper, //FireDac support for PostgreSQL
  FireDAC.Phys.Oracle, FireDAC.Phys.OracleMeta, //FireDac support for Oracle
  // Oracle via Devart ODAC (optional) — alternative to FireDAC.Phys.Oracle above.
  // Left commented out because ODAC is a third-party commercial library that
  // requires ODAC installed + its library path in the project. Uncomment the
  // single EF.DB.ODAC line below to enable the 'ODAC' adapter (see the
  // ODAC_Oracle block in Config.yaml). Unit order in this uses clause does not
  // matter: each EF.DB.* adapter self-registers by ClassId in its own
  // initialization, independently of FireDAC. ODAC: https://www.devart.com/odac/
  // EF.DB.ODAC, //ODAC support for Oracle (Devart)
  //Global Kittox uses
  Kitto.Html.All,
  Kitto.Web.Enterprise,
  // Activates the file logger endpoint declared in Config.yaml under
  // Log/TextFile (auto-registered via the unit's initialization). Standalone
  // Indy hosts must include this unit explicitly — the WebBroker bridge for
  // ISAPI/Apache pulls it in on its own.
  EF.Logger.TextFile
  // Kitto.AccessControl.DB,
  , Kitto.Auth.DB
  // Kitto.Auth.DBServer,
  // Kitto.Auth.OSDB,
  // Kitto.Auth.TextFile,
  // JWT authenticator (Auth: JWT) — registered as 'JWT' on init.
  // HelloKitto wraps the standard DB authenticator under Auth/Inner so the
  // session credential travels in a signed JWT cookie instead of a server
  // session id. No DatabaseChoices on the login page (DefaultDatabaseName
  // drives the dialect): swap PostgreSQL/SQL Server/Firebird by editing
  // Config.yaml only.
  , Kitto.Auth.JWT
  , Kitto.Tool.ADO //For Excel/Import export
  , Kitto.Tool.DebenuQuickPDF //For PDF Merge
  //, Kitto.Ext.ReportBuilderTools //Tool for Reportbuilder
  //, Kitto.Ext.FOPTools //For FOP Engine
  // Kitto.Localization.dxgettext, //Commented to enable per-session localization
  ;

implementation

uses
  System.SysUtils,
  Kitto.Web.JWT,
  JOSE.Core.JWA;

initialization
{$WARN SYMBOL_PLATFORM OFF}
  // check memory leaks at the end of the app
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
{$WARN SYMBOL_PLATFORM ON}

  // JWT signing key for the HelloKittoX demo — registered programmatically so
  // all .dpr variants (Standalone, ISAPI, Desktop, Apache) share the same key
  // without each having to set an environment variable. The first argument is
  // matched (case-insensitive) against TKConfig.AppName, so this provider is
  // used only by this app even if other JWT-enabled apps run in the same
  // process.
  // FOR PRODUCTION: replace this literal with a load from a vault, env var,
  // or platform secret manager (the registered provider always takes
  // precedence over Auth/SigningKey in Config.yaml).
  TKJWTSigningKeyRegistry.Instance.RegisterProvider('HelloKittoX',
    function: TKJWTSigningKey
    begin
      Result.Algorithm := TJOSEAlgorithmId.HS256;
      Result.PrivateKey := TEncoding.UTF8.GetBytes(
        'hellokitto-demo-hs256-shared-key-do-not-use-this-in-prod');
    end);

end.
