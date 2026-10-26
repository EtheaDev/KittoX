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

/// <summary>HelloKitto Apache module Example</summary>
library mod_hellokitto;

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
  Controllers in '..\Source\Controllers.pas',
  Rules in '..\Source\Rules.pas',
  UseKitto in '..\Source\UseKitto.pas';

{$R *.res}

// httpd.conf entries:
//
(*
 LoadModule hellokitto_module modules/mod_hellokitto.dll

 <Location /xyz>
    SetHandler mod_hellokitto-handler
 </Location>
*)
//
// These entries assume that the output directory for this project is the apache/modules directory.
//
// httpd.conf entries should be different if the project is changed in these ways:
//   1. The TApacheModuleData variable name is changed.
//   2. The project is renamed.
//   3. The output directory is not the apache/modules directory.
//   4. The dynamic library extension depends on a platform. Use .dll on Windows and .so on Linux.
//

// Declare exported variable so that Apache can access this module.
var
  GModuleData: TApacheModuleData;
exports
  GModuleData name 'hellokitto_module';

begin
{$IFDEF MSWINDOWS}
  CoInitFlags := COINIT_MULTITHREADED;
{$ENDIF}
  Web.ApacheApp.InitApplication(@GModuleData);
  Application.Initialize;
  Application.WebModuleClass := WebModuleClass;
  Application.Run;
end.
