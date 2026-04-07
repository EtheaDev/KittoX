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

/// <summary>TasKitto Apache module Example</summary>
library mod_taskitto;

uses
  {$IFDEF MSWINDOWS}
  Winapi.ActiveX,
  System.Win.ComObj,
  {$ENDIF }
  //Units for Apache Module
  Web.WebBroker,
  Web.ApacheApp,
  Web.HTTPD24Impl,
  Kitto.WebBroker.WebModule,
  //Units for KittoX application
  UseKitto in '..\Source\UseKitto.pas',
  Rules in '..\Source\Rules.pas',
  Auth in '..\Source\Auth.pas';

{$R *.res}

var
  GModuleData: TApacheModuleData;
exports
  GModuleData name 'taskitto_module';

begin
{$IFDEF MSWINDOWS}
  CoInitFlags := COINIT_MULTITHREADED;
{$ENDIF}
  Web.ApacheApp.InitApplication(@GModuleData);
  Application.Initialize;
  Application.WebModuleClass := WebModuleClass;
  Application.Run;
end.
