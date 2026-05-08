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

/// <summary>{AppTitle} Apache module</summary>
library mod_{ProjectNameLower};

uses
  {$IFDEF MSWINDOWS}
  Winapi.ActiveX,
  System.Win.ComObj,
  {$ENDIF}
  Web.WebBroker,
  Web.ApacheApp,
  Web.HTTPD24Impl,
  Kitto.WebBroker.WebModule,
  Controllers in '..\Source\Controllers.pas',
  Rules in '..\Source\Rules.pas',
  UseKitto in '..\Source\UseKitto.pas';

{$R *.res}

// httpd.conf entries:
//
(*
 LoadModule {ProjectNameLower}_module modules/mod_{ProjectNameLower}.dll

 <Location /{ProjectNameLower}>
    SetHandler mod_{ProjectNameLower}-handler
 </Location>
*)
//
// Adjust if you rename the project, change the output directory, or
// move to Linux (.so instead of .dll).

var
  GModuleData: TApacheModuleData;
exports
  GModuleData name '{ProjectNameLower}_module';

begin
{$IFDEF MSWINDOWS}
  CoInitFlags := COINIT_MULTITHREADED;
{$ENDIF}
  Web.ApacheApp.InitApplication(@GModuleData);
  Application.Initialize;
  Application.WebModuleClass := WebModuleClass;
  Application.Run;
end.
