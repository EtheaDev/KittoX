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
