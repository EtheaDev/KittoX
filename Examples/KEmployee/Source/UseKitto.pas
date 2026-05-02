unit UseKitto;

interface

uses
  //Core Kitto Units
  Kitto.Html.All,
  Kitto.Web.Enterprise,
  // Activates the file logger endpoint declared in Config.yaml under
  // Log/TextFile (auto-registered via the unit's initialization). Standalone
  // Indy hosts must include this unit explicitly — the WebBroker bridge for
  // ISAPI/Apache pulls it in on its own.
  EF.Logger.TextFile,
  EF.DB.DBX,
  Data.DBXFirebird,
  EF.DB.FD,
  // Kitto.AccessControl.DB,
  // Kitto.Auth.DB,
  // Kitto.Auth.DBServer,
  // Kitto.Auth.OSDB,
  Kitto.Auth.TextFile,
  // JWT authenticator (Auth: JWT) — registered as 'JWT' on init.
  // KEmployee wraps the simpler TextFile authenticator under Auth/Inner so
  // the session credential travels in a signed JWT cookie instead of a
  // server session id. The text file users (FileAuthenticator.txt in Home/)
  // remain the source of truth for password verification.
  Kitto.Auth.JWT,
  Kitto.Tool.ADO, //For Excel export
  // Kitto.Localization.dxgettext, //Commented to enable per-session localization
  Kitto.Metadata.ModelImplementation,
  Kitto.Metadata.ViewBuilders
  ;

implementation

uses
  System.SysUtils,
  Kitto.Web.JWT,
  JOSE.Core.JWA;

initialization
  // JWT signing key for the KEmployeeX demo — registered programmatically so
  // all .dpr variants (Standalone, ISAPI, Desktop, Apache) share the same key
  // without each having to set an environment variable. The first argument is
  // matched (case-insensitive) against TKConfig.AppName, so this provider is
  // used only by this app even if other JWT-enabled apps run in the same
  // process.
  // FOR PRODUCTION: replace this literal with a load from a vault, env var,
  // or platform secret manager (the registered provider always takes
  // precedence over Auth/SigningKey in Config.yaml).
  TKJWTSigningKeyRegistry.Instance.RegisterProvider('KEmployeeX',
    function: TKJWTSigningKey
    begin
      Result.Algorithm := TJOSEAlgorithmId.HS256;
      Result.PrivateKey := TEncoding.UTF8.GetBytes(
        'kemployee-demo-hs256-shared-key-do-not-use-this-in-prod');
    end);

end.
