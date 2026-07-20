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
unit Kitto.RB.RapFunc;
{$WARN SYMBOL_PLATFORM OFF}
interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Variants,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  raFunc,
  ppRTTI;

Type
  /// <summary>Base class for Ethea custom functions available in the ReportBuilder RAP scripting engine.</summary>
  TEtheaFunction = class (TraSystemFunction)
  public
    {Override Category to return a new category string}
    /// <summary>Returns the RAP palette category these functions appear under.</summary>
    class function Category: String; override;
  end;

  {Descendants of TEtheaFunction will appear in the Filename category}
  /// <summary>RAP function that expands an image file name to its full resource path.</summary>
  TEFExpandImageFilePathFunction = class (TEtheaFunction)
  public
    /// <summary>Executes the function against the given RAP parameter list.</summary>
    procedure ExecuteFunction(aParams: TraParamList); override;
    /// <summary>Returns the RAP signature (name and parameters) of the function.</summary>
    class function GetSignature: String; override;
  end;

  /// <summary>RAP function that left-pads a string to a given length.</summary>
  TEFPadLFunction = class(TraStringFunction)
  public
    /// <summary>Executes the function against the given RAP parameter list.</summary>
    procedure ExecuteFunction(aParams: TraParamList); override;
    /// <summary>Returns the RAP signature (name and parameters) of the function.</summary>
    class function GetSignature: String; override;
  end;

  /// <summary>RAP function that right-pads a string to a given length.</summary>
  TEFPadRFunction = class(TraStringFunction)
  public
    /// <summary>Executes the function against the given RAP parameter list.</summary>
    procedure ExecuteFunction(aParams: TraParamList); override;
    /// <summary>Returns the RAP signature (name and parameters) of the function.</summary>
    class function GetSignature: String; override;
  end;

/// <summary>Registers the Ethea RAP functions and sets the image search paths used at report runtime.</summary>
procedure UpdateRAPEnvironment(const AApplicationImagesPath, ACoreImagesPath: string);

implementation

uses
  ppRichTx;

var
  ApplicationImagesPath : string;
  CoreImagesPath : string;

procedure UpdateRAPEnvironment(const AApplicationImagesPath, ACoreImagesPath: string);
begin
  //Imposta le path delle immagini
  ApplicationImagesPath := ExcludeTrailingBackslash(AApplicationImagesPath);
  CoreImagesPath := ExcludeTrailingBackslash(ACoreImagesPath);
end;

function ExpandImageFilePath(ImageName: String): String;
begin
  (* Verifico l'esistenza dell'immagine con estensione passata dal programmatore *)
  if FileExists(IncludeTrailingPathDelimiter(CoreImagesPath) + ImageName) then
    Result := IncludeTrailingPathDelimiter(CoreImagesPath) + ImageName
  else if FileExists(IncludeTrailingPathDelimiter(ApplicationImagesPath) + ImageName) then
    Result := IncludeTrailingPathDelimiter(ApplicationImagesPath) + ImageName
  else
    Result := '';
end;

{------------------------------------------------------------------------------}
{ TEtheaFunction.Category }

class function TEtheaFunction.Category: String;
begin
  Result := 'File';
end; {class function Category}

class function TEFExpandImageFilePathFunction.GetSignature: String;
begin
  Result := 'function ExpandImageFilePath( const FileName : string ) : string;';
end; {class function GetSignature}

procedure TEFExpandImageFilePathFunction.ExecuteFunction(aParams: TraParamList);
var
  {include a local var for each parameter and the Result value}
  ParFileName  : String;
  ParResult: String;
begin
  ParResult:= '';
  GetParamValue(0,ParFileName);

  {Call the actual Delphi method and pass the Result to a local var.}
  ParResult := ExpandImageFilePath(ParFileName);

  {Set the last item in the TraParamList as the Result.}
  SetParamValue(1, ParResult);

end; {Procedure ExecuteFunction}

{ TEFPadLFunction }

procedure TEFPadLFunction.ExecuteFunction(aParams: TraParamList);
var
  ParInString: string;
  ParLen: integer;
  ParFill: Char;
  ParResult: String;
begin
  //leggo i parametri
  GetParamValue(0, ParInString);
  GetParamValue(1, ParLen     );
  GetParamValue(2, ParFill    );

  {Call the actual Delphi method and pass the Result to a local var.}
    ParResult := StringOfChar(ParFill,ParLen-Length(ParInString)) + ParInString;

  {Set the last item in the TraParamList as the Result.}
  SetParamValue(3, ParResult);
end;

class function TEFPadLFunction.GetSignature: String;
begin
  Result := 'function PadL(Const InString: String; Len: Integer; FChar: Char): String;';
end;

{ TEFPadRFunction }

procedure TEFPadRFunction.ExecuteFunction(aParams: TraParamList);
var
  ParInString: string;
  ParLen: integer;
  ParFill: Char;
  ParResult: String;
begin
  //leggo i parametri
  GetParamValue(0, ParInString);
  GetParamValue(1, ParLen     );
  GetParamValue(2, ParFill    );

  {Call the actual Delphi method and pass the Result to a local var.}
    ParResult := ParInString + StringOfChar(ParFill,ParLen-Length(ParInString));

  {Set the last item in the TraParamList as the Result.}
  SetParamValue(3, ParResult);
end;

class function TEFPadRFunction.GetSignature: String;
begin
  Result := 'function PadR(Const InString: String; Len: Integer; FChar: Char): String;';
end;


initialization
  ApplicationImagesPath := '';
  CoreImagesPath := '';

  raRegisterFunction('ExpandImageFilePath',TEFExpandImageFilePathFunction);
  raRegisterFunction('PadL', TEFPadLFunction);
  raRegisterFunction('PadR', TEFPadRFunction);

finalization
  raUnRegisterFunction('ExpandImageFilePath');
  raUnRegisterFunction('PadL');
  raUnRegisterFunction('PadR');

end.
