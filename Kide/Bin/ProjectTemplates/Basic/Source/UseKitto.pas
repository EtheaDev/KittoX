unit UseKitto;

interface

uses
  {DB/ADO},
  {DB/FD},
  {DB/DBX},{AC}{Auth}
  Kitto.Metadata.ModelImplementation,
  Kitto.Metadata.ViewBuilders,
  // Activates the file logger endpoint declared in Config.yaml under
  // Log/TextFile (auto-registered via the unit's initialization).
  EF.Logger.TextFile,
  Kitto.Html.All
  ;

implementation

uses
  System.SysUtils,
  Kitto.Web.JWT,
  JOSE.Core.JWA;

initialization
{$WARN SYMBOL_PLATFORM OFF}
  // Surface memory leaks during development.
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
{$WARN SYMBOL_PLATFORM ON}

  // JWT signing key — registered programmatically so all .dpr variants
  // (Standalone, ISAPI, Desktop, Apache) of this app share the same key
  // without each having to set an environment variable. The first
  // argument is matched (case-insensitive) against TKConfig.AppName, so
  // this provider is used only by this app even if other JWT-enabled
  // apps run in the same process.
  // FOR PRODUCTION replace this literal with a load from a vault, env
  // var, or platform secret manager. The registered provider always
  // takes precedence over any Auth/SigningKey value in Config.yaml.
  TKJWTSigningKeyRegistry.Instance.RegisterProvider('{ProjectName}',
    function: TKJWTSigningKey
    begin
      Result.Algorithm := TJOSEAlgorithmId.HS256;
      Result.PrivateKey := TEncoding.UTF8.GetBytes(
        '{ProjectName}-dev-hs256-key-CHANGE-ME-IN-PRODUCTION');
    end);

end.
