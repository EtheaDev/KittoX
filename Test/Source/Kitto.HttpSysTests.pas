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
///  The HTTP.sys host reads a request out of a structure the kernel filled:
///  pointers into a buffer, lengths in bytes, two tables of headers. That kind
///  of code does not fail loudly - it reads one field short and serves the
///  wrong page - so here a request is built by hand, exactly as the kernel
///  lays it out, and read back.
///  <para>No listening, no port, no privileges: what is tested is the reading,
///  which is where this host can quietly be wrong.</para>
/// </summary>
unit Kitto.HttpSysTests;

interface

{$IFDEF MSWINDOWS}

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TKHttpSysTests = class
  public
    /// <summary>Method, path and query string, as the kernel cooked them.</summary>
    [Test]
    procedure Request_ReadsTheVerbThePathAndTheQuery;
    /// <summary>A header the kernel knows by name and one it does not - which
    /// is the one every request of KittoX carries.</summary>
    [Test]
    procedure Request_ReadsBothTablesOfHeaders;
    /// <summary>The body, as bytes and as a length.</summary>
    [Test]
    procedure Request_CarriesTheBody;
    /// <summary>A verb the kernel does not know travels as text.</summary>
    [Test]
    procedure Request_ReadsAnUnknownVerb;
    /// <summary>The reason phrase of the status codes an application
    /// produces.</summary>
    [Test]
    procedure Reason_NamesTheCommonCodes;
    /// <summary>An error that stops the host from starting has to say what to
    /// do about it: a missing URL reservation is the first run of every
    /// installation.</summary>
    [Test]
    procedure ErrorText_TellsWhatToDoAboutAccessDenied;
  end;

{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

uses
  System.SysUtils
  , System.Classes
  , Winapi.Windows
  , Kitto.Web.HttpSysApi
  , Kitto.Web.HttpSys
  ;

type
  /// <summary>Builds an HTTP_REQUEST the way the kernel does, keeping alive
  /// everything it points into.</summary>
  TRequestBuilder = class
  strict private
    FRequest: HTTP_REQUEST;
    FUrl: WideString;
    FPath: WideString;
    FQuery: WideString;
    FHost: WideString;
    FVerb: AnsiString;
    FUnknown: array of HTTP_UNKNOWN_HEADER;
    FNames: array of AnsiString;
    FValues: array of AnsiString;
  public
    constructor Create;
    procedure SetVerb(const AVerb: HTTP_VERB); overload;
    procedure SetVerb(const AText: string); overload;
    procedure SetUrl(const APath, AQuery, AHost: string);
    procedure AddKnown(const AId: HTTP_HEADER_ID; const AValue: string);
    procedure AddUnknown(const AName, AValue: string);
    function Request: PHTTP_REQUEST;
  end;

{ TRequestBuilder }

constructor TRequestBuilder.Create;
begin
  inherited Create;
  FillChar(FRequest, SizeOf(FRequest), 0);
  FRequest.Base.Version.MajorVersion := 1;
  FRequest.Base.Version.MinorVersion := 1;
  FRequest.Base.Verb := HttpVerbGET;
end;

procedure TRequestBuilder.SetVerb(const AVerb: HTTP_VERB);
begin
  FRequest.Base.Verb := AVerb;
end;

procedure TRequestBuilder.SetVerb(const AText: string);
begin
  FVerb := AnsiString(AText);
  FRequest.Base.Verb := HttpVerbUnknown;
  FRequest.Base.pUnknownVerb := PAnsiChar(FVerb);
  FRequest.Base.UnknownVerbLength := Length(FVerb);
end;

procedure TRequestBuilder.SetUrl(const APath, AQuery, AHost: string);
begin
  FPath := APath;
  FQuery := AQuery;
  FHost := AHost;
  FUrl := 'http://' + AHost + APath + AQuery;
  // Every length of a cooked URL is in BYTES, which is the first thing to get
  // wrong when reading one.
  FRequest.Base.CookedUrl.pFullUrl := PWideChar(FUrl);
  FRequest.Base.CookedUrl.FullUrlLength := Length(FUrl) * SizeOf(WideChar);
  FRequest.Base.CookedUrl.pAbsPath := PWideChar(FPath);
  FRequest.Base.CookedUrl.AbsPathLength := Length(FPath) * SizeOf(WideChar);
  FRequest.Base.CookedUrl.pQueryString := PWideChar(FQuery);
  FRequest.Base.CookedUrl.QueryStringLength := Length(FQuery) * SizeOf(WideChar);
  FRequest.Base.CookedUrl.pHost := PWideChar(FHost);
  FRequest.Base.CookedUrl.HostLength := Length(FHost) * SizeOf(WideChar);
end;

procedure TRequestBuilder.AddKnown(const AId: HTTP_HEADER_ID; const AValue: string);
var
  LIndex: Integer;
begin
  LIndex := Length(FValues);
  SetLength(FValues, LIndex + 1);
  FValues[LIndex] := UTF8Encode(AValue);
  FRequest.Base.Headers.KnownHeaders[Ord(AId)].pRawValue := PAnsiChar(FValues[LIndex]);
  FRequest.Base.Headers.KnownHeaders[Ord(AId)].RawValueLength := Length(FValues[LIndex]);
end;

procedure TRequestBuilder.AddUnknown(const AName, AValue: string);
var
  LIndex: Integer;
begin
  LIndex := Length(FUnknown);
  SetLength(FUnknown, LIndex + 1);
  SetLength(FNames, LIndex + 1);
  SetLength(FValues, Length(FValues) + 1);

  FNames[LIndex] := UTF8Encode(AName);
  FValues[High(FValues)] := UTF8Encode(AValue);

  FUnknown[LIndex].pName := PAnsiChar(FNames[LIndex]);
  FUnknown[LIndex].NameLength := Length(FNames[LIndex]);
  FUnknown[LIndex].pRawValue := PAnsiChar(FValues[High(FValues)]);
  FUnknown[LIndex].RawValueLength := Length(FValues[High(FValues)]);

  FRequest.Base.Headers.UnknownHeaderCount := Length(FUnknown);
  FRequest.Base.Headers.pUnknownHeaders := PHTTP_UNKNOWN_HEADER(@FUnknown[0]);
end;

function TRequestBuilder.Request: PHTTP_REQUEST;
begin
  Result := @FRequest;
end;

{ TKHttpSysTests }

procedure TKHttpSysTests.Request_ReadsTheVerbThePathAndTheQuery;
var
  LBuilder: TRequestBuilder;
  LRequest: TKHttpSysRequest;
begin
  LBuilder := TRequestBuilder.Create;
  try
    LBuilder.SetVerb(HttpVerbPOST);
    LBuilder.SetUrl('/hellokittox/kx/view/Dolls', '?page=2&sort=name', 'localhost:8080');

    LRequest := TKHttpSysRequest.Create(LBuilder.Request, nil);
    try
      Assert.AreEqual('POST', LRequest.Method);
      Assert.AreEqual('/hellokittox/kx/view/Dolls', LRequest.PathInfo);
      // The question mark belongs to the URL, not to what WebBroker calls the
      // query: a leading '?' here would reach the first parameter name.
      Assert.AreEqual('page=2&sort=name', LRequest.Query);
      Assert.AreEqual('localhost:8080', LRequest.Host);
      Assert.AreEqual('HTTP/1.1', LRequest.ProtocolVersion);
      // The fields the base class parses out of the query for us.
      Assert.AreEqual('2', LRequest.QueryFields.Values['page']);
      Assert.AreEqual('name', LRequest.QueryFields.Values['sort']);
    finally
      LRequest.Free;
    end;
  finally
    LBuilder.Free;
  end;
end;

procedure TKHttpSysTests.Request_ReadsBothTablesOfHeaders;
var
  LBuilder: TRequestBuilder;
  LRequest: TKHttpSysRequest;
begin
  LBuilder := TRequestBuilder.Create;
  try
    LBuilder.SetUrl('/app/', '', 'localhost');
    LBuilder.AddKnown(HttpHeaderUserAgent, 'Mozilla/5.0 (KittoX test)');
    LBuilder.AddKnown(HttpHeaderAuthorization, 'Bearer abc.def.ghi');
    LBuilder.AddKnown(HttpHeaderContentType, 'application/x-www-form-urlencoded');
    // The one every request of the client side carries, and the one the kernel
    // does not know by name: if the unknown table is read wrong, every
    // fragment request of the application looks like a navigation.
    LBuilder.AddUnknown('X-KittoX', 'true');
    LBuilder.AddUnknown('X-Requested-With', 'XMLHttpRequest');

    LRequest := TKHttpSysRequest.Create(LBuilder.Request, nil);
    try
      Assert.AreEqual('Mozilla/5.0 (KittoX test)', LRequest.UserAgent);
      Assert.AreEqual('Bearer abc.def.ghi', LRequest.Authorization);
      Assert.AreEqual('application/x-www-form-urlencoded', LRequest.ContentType);
      Assert.AreEqual('true', LRequest.GetFieldByName('X-KittoX'));
      Assert.AreEqual('XMLHttpRequest', LRequest.GetFieldByName('X-Requested-With'));
      Assert.AreEqual('', LRequest.GetFieldByName('X-Not-There'),
        'a header that is not there is empty, not an error');
    finally
      LRequest.Free;
    end;
  finally
    LBuilder.Free;
  end;
end;

procedure TKHttpSysTests.Request_CarriesTheBody;
var
  LBuilder: TRequestBuilder;
  LRequest: TKHttpSysRequest;
  LBody: TBytes;
begin
  LBuilder := TRequestBuilder.Create;
  try
    LBuilder.SetVerb(HttpVerbPOST);
    LBuilder.SetUrl('/app/kx/chat/send', '', 'localhost');
    LBuilder.AddKnown(HttpHeaderContentType, 'application/x-www-form-urlencoded');
    LBody := TEncoding.UTF8.GetBytes('message=ciao&viewName=Dolls');

    LRequest := TKHttpSysRequest.Create(LBuilder.Request, LBody);
    try
      Assert.AreEqual(Int64(Length(LBody)), LRequest.ContentLength);
      Assert.AreEqual('message=ciao&viewName=Dolls', LRequest.Content);
      // And the fields the base class parses out of it, which is how every
      // form of the application arrives.
      Assert.AreEqual('ciao', LRequest.ContentFields.Values['message']);
      Assert.AreEqual('Dolls', LRequest.ContentFields.Values['viewName']);
    finally
      LRequest.Free;
    end;
  finally
    LBuilder.Free;
  end;
end;

procedure TKHttpSysTests.Request_ReadsAnUnknownVerb;
var
  LBuilder: TRequestBuilder;
  LRequest: TKHttpSysRequest;
begin
  LBuilder := TRequestBuilder.Create;
  try
    LBuilder.SetVerb('PATCH');
    LBuilder.SetUrl('/api/v4/Doll/1', '', 'localhost');

    LRequest := TKHttpSysRequest.Create(LBuilder.Request, nil);
    try
      // PATCH is not in the table of the kernel: it arrives as bytes, and a
      // REST endpoint that answers to it needs it read.
      Assert.AreEqual('PATCH', LRequest.Method);
    finally
      LRequest.Free;
    end;
  finally
    LBuilder.Free;
  end;
end;

procedure TKHttpSysTests.Reason_NamesTheCommonCodes;
begin
  Assert.AreEqual('OK', KXHttpSysReasonOf(200));
  Assert.AreEqual('Not Found', KXHttpSysReasonOf(404));
  Assert.AreEqual('Internal Server Error', KXHttpSysReasonOf(500));
  // Anything else answers with its own number rather than with a wrong name.
  Assert.AreEqual('418', KXHttpSysReasonOf(418));
end;

procedure TKHttpSysTests.ErrorText_TellsWhatToDoAboutAccessDenied;
var
  LText: string;
begin
  LText := KXHttpSysErrorText(ERROR_ACCESS_DENIED, 'HttpAddUrlToUrlGroup');
  Assert.IsTrue(LText.Contains('HttpAddUrlToUrlGroup'),
    'what failed: ' + LText);
  Assert.IsTrue(LText.Contains('netsh http add urlacl'),
    'and what to do about it, which is the whole point: ' + LText);

  LText := KXHttpSysErrorText(ERROR_SHARING_VIOLATION, 'HttpAddUrlToUrlGroup');
  Assert.IsTrue(LText.ToLower.Contains('another process'),
    'a port somebody else answers for says so: ' + LText);
end;

initialization
  TDUnitX.RegisterTestFixture(TKHttpSysTests);

{$ENDIF}

end.
