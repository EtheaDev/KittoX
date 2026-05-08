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

end.
