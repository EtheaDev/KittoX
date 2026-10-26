{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------}

unit UseKitto;

interface

uses
  //Core Kitto Units
  Kitto.Html.All
  //Kitto Enterprise components
  , Kitto.Web.Enterprise
  //Activates Logger
  , EF.Logger.TextFile
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
  //ADO Support
  , EF.DB.ADO
  //DbExpress Support
  , EF.DB.DBX
  , Data.DBXMSSQL
  , Data.DBXFirebird
  , Data.DBXOracle
  //FireDac base support
  , EF.DB.FD
  //FireDac support for MS-SQL
  , FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLMeta
  //FireDac support for Firebird
  , FireDAC.Phys.IBBase, FireDAC.Phys.FB
  //FireDac support for PostgreSQL
  , FireDAC.Phys.PG, FireDAC.Phys.PGWrapper
  //FireDac support for Oracle
  , FireDAC.Phys.Oracle, FireDAC.Phys.OracleMeta
  // Oracle via Devart ODAC (optional) — alternative to FireDAC.Phys.Oracle above.
  //, EF.DB.ODAC //ODAC support for Oracle (Devart)

  // Opt-in REST/JSON API under /api/v4/{ViewName} (see Kitto.Web.Rest).
  , Kitto.Web.Rest
  // Activates the file logger endpoint declared in Config.yaml under
  // Log/TextFile (auto-registered via the unit's initialization). Standalone
  // Indy hosts must include this unit explicitly — the WebBroker bridge for
  // ISAPI/Apache pulls it in on its own.
  , Kitto.Auth.DB
  // , Kitto.Auth.DBServer
  // , Kitto.Auth.OSDB
  // , Kitto.Auth.TextFile
  // JWT authenticator (Auth: JWT) — registered as 'JWT' on init.
  , Kitto.Auth.JWT
  //, Kitto.AccessControl.DB

  //For Excel/Import export via ADO: requires Microsoft.ACE.OLEDB.12.0 installed
  , Kitto.Tool.ADO
  //Debenu Quick PDF Engine + Tool: requires Debenu Quick PDF (only 32bit)
  , Kitto.Tool.DebenuQuickPDF

  // Optional feature subsystems (opt-in, gated by Config.yaml; NOT part of
  // Kitto.Html.All). If a feature is Enabled in Config but its unit is missing
  // here, the core raises a clear startup error naming the unit to add.
  // Help Chat (HelpChat/Enabled) — endpoints plus the provider in use:
  , Kitto.Web.Handler.Chat
  //, Kitto.Chat.DocSearch          // provider 'docsearch' (offline docs search)
  , Kitto.Chat.Provider.Claude    // provider 'claude' (Anthropic AI, streaming)
  //ReportBuilder engine + 'ReportBuilderTool' controller: requires ReportBuilder
  //, Kitto.ReportBuilder
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
