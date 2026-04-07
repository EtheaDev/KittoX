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

/// <summary>
///   Activation engine for attribute-based routing. Matches incoming URLs
///   against registered resource methods, fills parameters via RTTI, and
///   invokes the handler. Created per-request.
/// </summary>
unit Kitto.Web.Routing.Activation;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Rtti,
  Kitto.Web.URL,
  Kitto.Web.Routing.Registry,
  Kitto.Web.Routing.Injection;

type
  /// <summary>
  ///   Per-request activation context. Holds the matched resource/method,
  ///   extracted path parameters, and method argument values.
  ///   Implements IKXActivationContext for injection providers.
  /// </summary>
  TKXActivation = class(TInterfacedObject, IKXActivationContext)
  private
    FURL: TKWebURL;
    FAppPath: string;
    FHttpMethod: string;
    FPathParams: TDictionary<string, string>;
    FMatchedResource: TKXResourceInfo;
    FMatchedMethod: TKXMethodInfo;
    FResourceInstance: TObject;
    FMethodArgs: TArray<TValue>;

    function GetURLTokens: TArray<string>;
    function TryMatchMethod(AMethodInfo: TKXMethodInfo;
      const AURLTokens: TArray<string>): Boolean;
    procedure FillMethodParameters;
    function ResolveParamValue(const AParamInfo: TKXParamInfo): TValue;
    function ConvertStringToValue(const AStr: string;
      AParamType: TRttiType): TValue;
  public
    constructor Create(const AURL: TKWebURL; const AAppPath, AHttpMethod: string);
    destructor Destroy; override;

    /// <summary>Extracted path parameter values (e.g., 'ViewName' -> 'Parties').</summary>
    property PathParams: TDictionary<string, string> read FPathParams;

    /// <summary>IKXActivationContext implementation.</summary>
    function GetPathParam(const AName: string): string;

    /// <summary>
    ///   Tries to match the URL against all registered resources.
    ///   Returns True and populates MatchedResource/MatchedMethod if found.
    /// </summary>
    function TryMatch: Boolean;

    /// <summary>
    ///   Invokes the matched handler method. Call only after TryMatch returns True.
    ///   Creates the resource instance, fills parameters, invokes, and frees.
    /// </summary>
    procedure Invoke;
  end;

implementation

uses
  System.StrUtils,
  System.TypInfo,
  Kitto.Web.Request;

{ TKXActivation }

constructor TKXActivation.Create(const AURL: TKWebURL;
  const AAppPath, AHttpMethod: string);
begin
  inherited Create;
  FURL := AURL;
  FAppPath := AAppPath;
  FHttpMethod := AHttpMethod;
  FPathParams := TDictionary<string, string>.Create;
end;

destructor TKXActivation.Destroy;
begin
  FreeAndNil(FPathParams);
  inherited;
end;

function TKXActivation.GetPathParam(const AName: string): string;
begin
  if not FPathParams.TryGetValue(AName, Result) then
    Result := '';
end;

function TKXActivation.GetURLTokens: TArray<string>;
var
  LFullPath, LRelPath: string;
  LList: TArray<string>;
  I, LCount: Integer;
begin
  // Build full request path and strip the application base path prefix
  LFullPath := FURL.Path + FURL.Document;
  if StartsText(FAppPath + '/', LFullPath) then
    LRelPath := Copy(LFullPath, Length(FAppPath) + 1, MaxInt)
  else if SameText(FAppPath, LFullPath) then
    LRelPath := '/'
  else
    LRelPath := LFullPath;

  // Strip leading/trailing slashes and split
  if (LRelPath <> '') and (LRelPath[1] = '/') then
    LRelPath := Copy(LRelPath, 2, MaxInt);
  if (LRelPath <> '') and (LRelPath[Length(LRelPath)] = '/') then
    LRelPath := Copy(LRelPath, 1, Length(LRelPath) - 1);
  if LRelPath = '' then
  begin
    Result := nil;
    Exit;
  end;
  LList := LRelPath.Split(['/']);
  // Filter empty tokens
  LCount := 0;
  for I := 0 to Length(LList) - 1 do
    if LList[I] <> '' then
      Inc(LCount);
  SetLength(Result, LCount);
  LCount := 0;
  for I := 0 to Length(LList) - 1 do
    if LList[I] <> '' then
    begin
      Result[LCount] := LList[I];
      Inc(LCount);
    end;
end;

function TKXActivation.TryMatchMethod(AMethodInfo: TKXMethodInfo;
  const AURLTokens: TArray<string>): Boolean;
var
  LTemplateTokens: TArray<string>;
  I: Integer;
  LToken: string;
begin
  Result := False;
  LTemplateTokens := AMethodInfo.FullPathTokens;

  // Token count must match exactly
  if Length(LTemplateTokens) <> Length(AURLTokens) then
    Exit;

  // Check HTTP method
  if (AMethodInfo.HttpMethod <> '') and
     not SameText(AMethodInfo.HttpMethod, FHttpMethod) then
    Exit;

  // Match token-by-token
  FPathParams.Clear;
  for I := 0 to Length(LTemplateTokens) - 1 do
  begin
    LToken := LTemplateTokens[I];
    if (LToken <> '') and (LToken[1] = '{') and (LToken[Length(LToken)] = '}') then
    begin
      // Parameter token — capture value
      FPathParams.AddOrSetValue(
        Copy(LToken, 2, Length(LToken) - 2),
        AURLTokens[I]);
    end
    else
    begin
      // Literal token — must match case-insensitively
      if not SameText(LToken, AURLTokens[I]) then
        Exit;
    end;
  end;
  Result := True;
end;

function TKXActivation.TryMatch: Boolean;
var
  LURLTokens: TArray<string>;
  LResInfo: TKXResourceInfo;
  LMethodInfo: TKXMethodInfo;
  I, J: Integer;
begin
  Result := False;
  FMatchedResource := nil;
  FMatchedMethod := nil;

  LURLTokens := GetURLTokens;

  // Resources are sorted by specificity (most literal tokens first)
  for I := 0 to TKXResourceRegistry.Instance.Resources.Count - 1 do
  begin
    LResInfo := TKXResourceRegistry.Instance.Resources[I];
    for J := 0 to LResInfo.Methods.Count - 1 do
    begin
      LMethodInfo := LResInfo.Methods[J];
      if TryMatchMethod(LMethodInfo, LURLTokens) then
      begin
        FMatchedResource := LResInfo;
        FMatchedMethod := LMethodInfo;
        Result := True;
        Exit;
      end;
    end;
  end;
end;

function TKXActivation.ConvertStringToValue(const AStr: string;
  AParamType: TRttiType): TValue;
begin
  case AParamType.TypeKind of
    tkInteger:
      Result := TValue.From<Integer>(StrToIntDef(AStr, 0));
    tkInt64:
      Result := TValue.From<Int64>(StrToInt64Def(AStr, 0));
    tkFloat:
      Result := TValue.From<Double>(StrToFloatDef(AStr, 0));
    tkEnumeration:
      if AParamType.Handle = TypeInfo(Boolean) then
        Result := TValue.From<Boolean>(SameText(AStr, 'true') or (AStr = '1'))
      else
        Result := TValue.From<string>(AStr);
  else
    Result := TValue.From<string>(AStr);
  end;
end;

function TKXActivation.ResolveParamValue(const AParamInfo: TKXParamInfo): TValue;
var
  LStrValue: string;
begin
  case AParamInfo.Kind of
    pkPathParam:
    begin
      if FPathParams.TryGetValue(AParamInfo.Name, LStrValue) then
        Result := ConvertStringToValue(LStrValue, AParamInfo.RttiParam.ParamType)
      else
        Result := TValue.Empty;
    end;
    pkQueryParam:
    begin
      LStrValue := TKWebRequest.Current.GetQueryField(AParamInfo.Name);
      Result := ConvertStringToValue(LStrValue, AParamInfo.RttiParam.ParamType);
    end;
    pkFormParam:
    begin
      LStrValue := TKWebRequest.Current.GetField(AParamInfo.Name);
      Result := ConvertStringToValue(LStrValue, AParamInfo.RttiParam.ParamType);
    end;
    pkContext:
    begin
      Result := TKXInjectionRegistry.Instance.Resolve(
        AParamInfo.RttiParam.ParamType, Self as IKXActivationContext);
    end;
  else
    Result := TValue.Empty;
  end;
end;

procedure TKXActivation.FillMethodParameters;
var
  LParams: TArray<TKXParamInfo>;
  I: Integer;
begin
  LParams := FMatchedMethod.Params;
  SetLength(FMethodArgs, Length(LParams));
  for I := 0 to Length(LParams) - 1 do
    FMethodArgs[I] := ResolveParamValue(LParams[I]);
end;

procedure TKXActivation.Invoke;
begin
  Assert(Assigned(FMatchedResource));
  Assert(Assigned(FMatchedMethod));

  FResourceInstance := FMatchedResource.ResourceClass.Create;
  try
    FillMethodParameters;
    FMatchedMethod.RttiMethod.Invoke(FResourceInstance, FMethodArgs);
  finally
    FreeAndNil(FResourceInstance);
  end;
end;

end.
