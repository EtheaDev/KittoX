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
///  Static file serving maps a URL under the resource base to a local file.
///  The mapping is reached before any authentication filter, so it must never
///  resolve outside the configured local directory: a URL carrying '..' or an
///  absolute path would otherwise read any file the server process can (the
///  application Config.yaml holds the database credentials and the JWT key).
///
///  ComputeLocalFileName is where that decision is made; it is protected, so a
///  tiny subclass exposes it. No web server, request or response is needed.
/// </summary>
unit Kitto.WebRoutesTests;

interface

uses
  DUnitX.TestFramework,
  Kitto.Web.Routes;

type
  /// <summary>Exposes the protected mapping for testing.</summary>
  TTestableStaticRoute = class(TKBaseStaticWebRoute)
  public
    function Map(const ALocalPath, AURLPath, AURLDocument: string): string;
  end;

  [TestFixture]
  TKStaticRouteContainmentTests = class
  strict private
    FRoute: TTestableStaticRoute;
    FBase: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    /// <summary>A normal asset under the base resolves to a path inside it.</summary>
    [Test]
    procedure AFileUnderTheBaseIsMapped;

    /// <summary>A nested asset resolves, still under the base.</summary>
    [Test]
    procedure ANestedFileUnderTheBaseIsMapped;

    /// <summary>'..' segments that climb out of the base are refused.</summary>
    [Test]
    procedure ADotDotEscapeIsRefused;

    /// <summary>An absolute path in the URL portion is refused.</summary>
    [Test]
    procedure AnAbsolutePathIsRefused;

    /// <summary>An absolute path in the document portion is refused.</summary>
    [Test]
    procedure AnAbsoluteDocumentIsRefused;

    /// <summary>A sibling directory whose name differs only in case is the
    /// same directory on Windows and another one on Linux: the check must
    /// follow the file system, not ignore case everywhere.</summary>
    [Test]
    procedure ADirectoryDifferingOnlyInCaseFollowsTheFileSystem;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

{ TTestableStaticRoute }

function TTestableStaticRoute.Map(const ALocalPath, AURLPath,
  AURLDocument: string): string;
begin
  Result := ComputeLocalFileName(ALocalPath, AURLPath, AURLDocument);
end;

{ TKStaticRouteContainmentTests }

procedure TKStaticRouteContainmentTests.Setup;
begin
  FRoute := TTestableStaticRoute.Create;
  // A concrete existing directory so GetFullPath has something real to
  // canonicalise; the file need not exist for the mapping decision.
  FBase := TPath.Combine(TPath.GetTempPath, 'kx-routes-test-resources');
  TDirectory.CreateDirectory(FBase);
end;

procedure TKStaticRouteContainmentTests.TearDown;
begin
  FRoute.Free;
  if TDirectory.Exists(FBase) then
    TDirectory.Delete(FBase, True);
end;

procedure TKStaticRouteContainmentTests.AFileUnderTheBaseIsMapped;
var
  LResult: string;
begin
  LResult := FRoute.Map(FBase, '', 'kittox.css');
  Assert.AreEqual(TPath.Combine(FBase, 'kittox.css'), LResult);
end;

procedure TKStaticRouteContainmentTests.ANestedFileUnderTheBaseIsMapped;
var
  LResult: string;
begin
  LResult := FRoute.Map(FBase, 'js/', 'kxgrid.js');
  Assert.AreEqual(
    TPath.Combine(TPath.Combine(FBase, 'js'), 'kxgrid.js'), LResult);
end;

procedure TKStaticRouteContainmentTests.ADotDotEscapeIsRefused;
var
  LResult: string;
begin
  // /res/../Metadata/Config.yaml  →  the sibling Metadata directory.
  LResult := FRoute.Map(FBase, '../Metadata/', 'Config.yaml');
  Assert.AreEqual('', LResult,
    'A path escaping the resource directory with '#39'..'#39' was mapped');
end;

procedure TKStaticRouteContainmentTests.AnAbsolutePathIsRefused;
var
  LResult: string;
begin
  // An absolute path of the platform: on Linux "C:/Windows/" is just a
  // relative directory named "C:", legitimately under the base.
  LResult := FRoute.Map(FBase, {$IFDEF MSWINDOWS}'C:/Windows/', 'win.ini'{$ELSE}'/etc/', 'passwd'{$ENDIF});
  Assert.AreEqual('', LResult, 'An absolute URL path was mapped');
end;

procedure TKStaticRouteContainmentTests.AnAbsoluteDocumentIsRefused;
var
  LResult: string;
begin
  LResult := FRoute.Map(FBase, '', {$IFDEF MSWINDOWS}'C:\Windows\win.ini'{$ELSE}'/etc/passwd'{$ENDIF});
  Assert.AreEqual('', LResult, 'An absolute document was mapped');
end;

procedure TKStaticRouteContainmentTests.ADirectoryDifferingOnlyInCaseFollowsTheFileSystem;
var
  LSibling: string;
  LResult: string;
begin
  LSibling := ExtractFileName(FBase).ToUpper;
  LResult := FRoute.Map(FBase, '../' + LSibling + '/', 'secret.txt');
  {$IFDEF MSWINDOWS}
  Assert.AreNotEqual('', LResult,
    'On Windows the upper-case name is the base directory itself');
  {$ELSE}
  Assert.AreEqual('', LResult,
    'A sibling directory differing only in case was taken for the base');
  {$ENDIF}
end;

initialization
  TDUnitX.RegisterTestFixture(TKStaticRouteContainmentTests);

end.
