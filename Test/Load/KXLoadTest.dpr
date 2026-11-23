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

/// The load generator: N threads asking the same URL for S seconds, over
/// connections they keep open, and what comes out is requests per second and
/// the latency at the percentiles that matter.
///
///   KXLoadTest --url=http://localhost:8099/hellokittox/ --concurrency=32
///              --seconds=10 [--warmup=2] [--label=home] [--session]
///              [--cookie=<value>] [--header=<Name: value>]
///              [--csv=results.csv]
///
/// **--cookie** sends that Cookie header as it is, and asks for nothing first.
/// It is for an application with a login: the script logs in, which this
/// program does not do, and hands over session and token (run_load_jwt.ps1).
/// It is also how two runs are put in the SAME session - a home being
/// reloaded and a view being read, which is two tabs.
/// **--header** adds one request header. A view of a KittoX application wants
/// "X-KittoX: true", or it takes the request for somebody typing the address
/// and sends it back to the home page.
///
/// **--session** does one request first, keeps the session cookie and sends it
/// on every later one. Without it every request opens a session of its own,
/// which measures the cost of creating sessions rather than the cost of
/// serving pages - a real thing to measure, but a different one.
///
/// Why a program of our own rather than a tool: it has to speak the session
/// cookie, it has to run on a machine with nothing installed on it, and it has
/// to be in the repository, so that a measurement can be repeated a year from
/// now and compared with this one.
program KXLoadTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Net.HttpClient,
  System.Net.URLClient;

type
  TWorkerResult = record
    Requests: Int64;
    Errors: Int64;
    Bytes: Int64;
    Latencies: TArray<Double>;  // milliseconds
    /// <summary>What the failures were: the status codes that came back, and
    /// the text of the first exception. Counting failures without naming them
    /// leaves a measurement nobody can trust.</summary>
    Statuses: TArray<Integer>;
    FirstError: string;
  end;

var
  /// What every worker reads. Globals on purpose: a worker is an anonymous
  /// method, and these are the values it has to see.
  GUrl: string;
  GCookie: string;
  GHeaderName, GHeaderValue: string;
  GWarmup: Integer;
  GSeconds: Integer;
  GDeadline: TStopwatch;
  GResults: TArray<TWorkerResult>;

function Arg(const AName, ADefault: string): string;
var
  I: Integer;
  LPrefix: string;
begin
  LPrefix := '--' + AName + '=';
  for I := 1 to ParamCount do
    if ParamStr(I).StartsWith(LPrefix, True) then
      Exit(ParamStr(I).Substring(LPrefix.Length));
  Result := ADefault;
end;

function HasFlag(const AName: string): Boolean;
var
  I: Integer;
begin
  for I := 1 to ParamCount do
    if SameText(ParamStr(I), '--' + AName) then
      Exit(True);
  Result := False;
end;

/// The session cookie of the application, from the first answer: without it
/// every request would open a session, and the measurement would be about
/// opening sessions.
function GrabCookie(const AUrl: string): string;
var
  LClient: THTTPClient;
  LResponse: IHTTPResponse;
  I: Integer;
begin
  Result := '';
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := 10000;
    LClient.ResponseTimeout := 30000;
    LResponse := LClient.Get(AUrl);
    // From the cookies the client has already separated, and not from the
    // header: several Set-Cookie travel in one line, and the comma inside
    // "expires=Wed, 18 Nov 2026" is not a separator - splitting on it was the
    // first thing this program got wrong.
    for I := 0 to LResponse.Cookies.Count - 1 do
      if not SameText(LResponse.Cookies[I].Name, 'kx_token') and
        (LResponse.Cookies[I].Value <> '') then
        Exit(LResponse.Cookies[I].Name + '=' + LResponse.Cookies[I].Value);
  finally
    LClient.Free;
  end;
end;

function Percentile(const ASorted: TArray<Double>; const AFraction: Double): Double;
var
  LIndex: Integer;
begin
  if Length(ASorted) = 0 then
    Exit(0);
  LIndex := Floor(AFraction * (Length(ASorted) - 1));
  Result := ASorted[EnsureRange(LIndex, 0, High(ASorted))];
end;

/// One worker. The index is a parameter and not the variable of the loop: a
/// closure over the loop variable would give every thread the same value, and
/// they would all write into the same slot.
function MakeWorker(const AIndex: Integer): TThread;
begin
  Result := TThread.CreateAnonymousThread(
    procedure
    var
      LClient: THTTPClient;
      LResponse: IHTTPResponse;
      LStream: TMemoryStream;
      LWatch: TStopwatch;
      LLatencies: TList<Double>;
      LStarted: Double;
      LBody: TBytes;
    begin
      LClient := THTTPClient.Create;
      LLatencies := TList<Double>.Create;
      LStream := TMemoryStream.Create;
      try
        LClient.ConnectionTimeout := 10000;
        LClient.ResponseTimeout := 60000;
        // Keep-alive: what is measured is serving requests, not opening
        // connections - and it is what a browser does.
        LClient.CustomHeaders['Connection'] := 'keep-alive';
        // The cookies are the ones given on the command line, and only those.
        // Left to itself the client also keeps what the server sets and sends
        // it back next to the header below: the session cookie twice, in two
        // headers. With a token in the first one that is the end of the login
        // from the second request on, wherever the server reads the last
        // header - every answer a 404, and nothing wrong with the server.
        LClient.AllowCookies := False;
        if GCookie <> '' then
          LClient.CustomHeaders['Cookie'] := GCookie;
        if GHeaderName <> '' then
          LClient.CustomHeaders[GHeaderName] := GHeaderValue;

        while GDeadline.Elapsed.TotalSeconds < (GWarmup + GSeconds) do
        begin
          LStarted := GDeadline.Elapsed.TotalSeconds;
          LStream.Size := 0;
          LWatch := TStopwatch.StartNew;
          try
            LResponse := LClient.Get(GUrl, LStream);
            LWatch.Stop;
            if (LResponse.StatusCode >= 200) and (LResponse.StatusCode < 400) then
            begin
              // What happens during the warm-up is not counted: the first
              // requests pay for the metadata being read and for the pools
              // filling up.
              if LStarted >= GWarmup then
              begin
                Inc(GResults[AIndex].Requests);
                Inc(GResults[AIndex].Bytes, LStream.Size);
                LLatencies.Add(LWatch.Elapsed.TotalMilliseconds);
              end;
            end
            else if LStarted >= GWarmup then
            begin
              Inc(GResults[AIndex].Errors);
              GResults[AIndex].Statuses := GResults[AIndex].Statuses +
                [LResponse.StatusCode];
              // The body of the first failure: KittoX writes the reason into
              // its error page, and that page is the diagnosis. Without it a
              // 500 is a number.
              if GResults[AIndex].FirstError = '' then
              begin
                SetLength(LBody, LStream.Size);
                if LStream.Size > 0 then
                begin
                  LStream.Position := 0;
                  LStream.ReadBuffer(LBody[0], LStream.Size);
                end;
                GResults[AIndex].FirstError := Format('HTTP %d: %s',
                  [LResponse.StatusCode,
                   Copy(TEncoding.UTF8.GetString(LBody), 1, 1500)]);
              end;
            end;
          except
            on E: Exception do
            begin
              LWatch.Stop;
              if LStarted >= GWarmup then
              begin
                Inc(GResults[AIndex].Errors);
                GResults[AIndex].Statuses := GResults[AIndex].Statuses + [0];
                if GResults[AIndex].FirstError = '' then
                  GResults[AIndex].FirstError := E.ClassName + ': ' + E.Message;
              end;
            end;
          end;
        end;
        GResults[AIndex].Latencies := LLatencies.ToArray;
      finally
        LStream.Free;
        LLatencies.Free;
        LClient.Free;
      end;
    end);
end;

var
  LLabel, LCookie, LCsv, LHeader: string;
  LConcurrency, LSeconds, LWarmup: Integer;
  LUseSession: Boolean;
  LThreads: TArray<TThread>;
  LAll: TList<Double>;
  LSorted: TArray<Double>;
  LTotalRequests, LTotalErrors, LTotalBytes: Int64;
  I, LStatus, LCount: Integer;
  LFirstError: string;
  LStatusCount: TDictionary<Integer, Integer>;
  LCsvFile: TextFile;
  LCsvExists: Boolean;

begin
  try
    GUrl := Arg('url', 'http://localhost:8099/hellokittox/');
    LConcurrency := Max(1, StrToIntDef(Arg('concurrency', '16'), 16));
    LSeconds := Max(1, StrToIntDef(Arg('seconds', '10'), 10));
    LWarmup := Max(0, StrToIntDef(Arg('warmup', '2'), 2));
    LLabel := Arg('label', 'load');
    LCsv := Arg('csv', '');
    LUseSession := HasFlag('session');
    GWarmup := LWarmup;
    GSeconds := LSeconds;

    LCookie := Arg('cookie', '');
    if (LCookie = '') and LUseSession then
    begin
      LCookie := GrabCookie(GUrl);
      if LCookie = '' then
        WriteLn('WARNING: no session cookie came back; every request opens one.');
    end;
    LHeader := Arg('header', '');
    if LHeader.Contains(':') then
    begin
      GHeaderName := LHeader.Substring(0, LHeader.IndexOf(':')).Trim;
      GHeaderValue := LHeader.Substring(LHeader.IndexOf(':') + 1).Trim;
    end;
    GCookie := LCookie;

    SetLength(GResults, LConcurrency);
    SetLength(LThreads, LConcurrency);

    // One clock for everybody: a worker that starts late must not run longer
    // than the others.
    GDeadline := TStopwatch.StartNew;

    for I := 0 to LConcurrency - 1 do
    begin
      LThreads[I] := MakeWorker(I);
      LThreads[I].FreeOnTerminate := False;
    end;
    for I := 0 to LConcurrency - 1 do
      LThreads[I].Start;
    for I := 0 to LConcurrency - 1 do
    begin
      LThreads[I].WaitFor;
      LThreads[I].Free;
    end;

    LTotalRequests := 0;
    LTotalErrors := 0;
    LTotalBytes := 0;
    LFirstError := '';
    LStatusCount := TDictionary<Integer, Integer>.Create;
    LAll := TList<Double>.Create;
    try
      for I := 0 to LConcurrency - 1 do
      begin
        Inc(LTotalRequests, GResults[I].Requests);
        Inc(LTotalErrors, GResults[I].Errors);
        Inc(LTotalBytes, GResults[I].Bytes);
        LAll.AddRange(GResults[I].Latencies);
        for LStatus in GResults[I].Statuses do
        begin
          LStatusCount.TryGetValue(LStatus, LCount);
          LStatusCount.AddOrSetValue(LStatus, LCount + 1);
        end;
        if (LFirstError = '') and (GResults[I].FirstError <> '') then
          LFirstError := GResults[I].FirstError;
      end;
      LSorted := LAll.ToArray;
      TArray.Sort<Double>(LSorted);
    finally
      LAll.Free;
    end;

    WriteLn(Format('%-12s c=%-4d %8d req  %9.1f req/s  p50 %6.2f  p90 %6.2f  ' +
      'p99 %7.2f ms  err %d  %0.1f MB',
      [LLabel, LConcurrency, LTotalRequests, LTotalRequests / LSeconds,
       Percentile(LSorted, 0.50), Percentile(LSorted, 0.90), Percentile(LSorted, 0.99),
       LTotalErrors, LTotalBytes / (1024 * 1024)]));
    if LTotalErrors > 0 then
    begin
      Write('             failures:');
      for LStatus in LStatusCount.Keys do
        if LStatus = 0 then
          Write(Format(' exception x%d', [LStatusCount[LStatus]]))
        else
          Write(Format(' HTTP %d x%d', [LStatus, LStatusCount[LStatus]]));
      WriteLn;
      if LFirstError <> '' then
        WriteLn('             first: ', LFirstError);
    end;
    Flush(Output);

    if LCsv <> '' then
    begin
      LCsvExists := FileExists(LCsv);
      AssignFile(LCsvFile, LCsv);
      if LCsvExists then
        Append(LCsvFile)
      else
        Rewrite(LCsvFile);
      try
        if not LCsvExists then
          WriteLn(LCsvFile, 'label;concurrency;seconds;requests;rps;p50_ms;p90_ms;p99_ms;errors;bytes');
        // Invariant: a file of measurements is written with the decimal point,
        // whatever the machine thinks, or whoever reads it back reads 127.83 as
        // a hundred and twenty-eight thousand.
        WriteLn(LCsvFile, Format('%s;%d;%d;%d;%.1f;%.3f;%.3f;%.3f;%d;%d',
          [LLabel, LConcurrency, LSeconds, LTotalRequests, LTotalRequests / LSeconds,
           Percentile(LSorted, 0.50), Percentile(LSorted, 0.90), Percentile(LSorted, 0.99),
           LTotalErrors, LTotalBytes], TFormatSettings.Invariant));
      finally
        CloseFile(LCsvFile);
      end;
    end;
    LStatusCount.Free;
  except
    on E: Exception do
    begin
      WriteLn('FAILED: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
