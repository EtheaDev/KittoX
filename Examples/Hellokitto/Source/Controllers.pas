unit Controllers;

interface

uses
  Kitto.Html.Controller, Kitto.Html.Tools;

type
  TURLToolController = class(TKXDataToolController)
  protected
    procedure ExecuteTool; override;
  end;

  TTestToolController = class(TKXDataToolController)
  protected
    procedure ExecuteTool; override;
  end;

implementation

uses
  System.SysUtils
  , System.IOUtils
  , System.Classes
  , Kitto.Config
  , Kitto.Web.Application
  , Kitto.Web.Request
  ;

{ TTestToolController }

procedure TTestToolController.ExecuteTool;
const
  LTestFileName = 'test.pdf';
var
  LFileName: TFileName;
  LStream: TFileStream;
begin
  inherited;
  LFileName := TPath.Combine(TKConfig.SystemHomePath, 'Resources');
  LFileName := TPath.Combine(LFileName, LTestFileName);
  try
    TKWebApplication.Current.DownloadStream(LStream, LTestFileName);
  finally
    FreeAndNil(LStream);
  end;
end;

{ TURLToolController }

procedure TURLToolController.ExecuteTool;
var
  LAddr: string;
begin
  inherited;
  LAddr := TKWebRequest.Current.RemoteAddr;
  if LAddr = '127.0.0.1' then
    TKWebApplication.Current.Navigate('http://www.ethea.it')
  else
    TKWebApplication.Current.Navigate('https://htmx.org');
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('TestTool', TTestToolController);
  TKXControllerRegistry.Instance.RegisterClass('URLTool', TURLToolController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('TestTool');
  TKXControllerRegistry.Instance.UnregisterClass('URLTool');

end.
