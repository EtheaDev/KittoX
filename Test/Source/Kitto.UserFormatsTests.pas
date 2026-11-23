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
unit Kitto.UserFormatsTests;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework;

type
  /// <summary>
  ///  The reader of the UserFormats node: both the short keys (Decimal,
  ///  Thousand) and the long ones (DecimalSeparator, ThousandSeparator) are
  ///  declared, so both must be read.
  /// </summary>
  [TestFixture]
  TKUserFormatsReaderTests = class
  public
    [Test]
    procedure ShortKeys_AreRead;

    /// <summary>
    ///  The long keys were declared as aliases (and used by the
    ///  SportClubManager example) but ReadConfig read only the short ones, so
    ///  a Config.yaml written with the long keys kept the OS separators.
    /// </summary>
    [Test]
    procedure LongKeys_AreRead;

    [Test]
    procedure ShortKey_WinsOverLongKey;
  end;

  /// <summary>
  ///  TKConfig.UserFormatSettings built from the UserFormats node of a real
  ///  Config.yaml (written to a temp folder): what grids, forms and templates
  ///  use to show dates, times and numbers.
  /// </summary>
  [TestFixture]
  TKConfigUserFormatsTests = class
  strict private
    FTempPath: string;
    FConfigFileName: string;
    FSavedFormatSettings: TFormatSettings;
    procedure WriteConfig(const AUserFormats: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure DateAndTime_FollowUserFormats;

    /// <summary>
    ///  A config reload (InvalidateConfig) refreshed the UserFormats reader but
    ///  not UserFormatSettings, which kept the date format read the first time.
    /// </summary>
    [Test]
    procedure DateFormat_FollowsConfigReload;

    [Test]
    procedure NumberSeparators_FromShortKeys;

    [Test]
    procedure NumberSeparators_FromLongKeys;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  EF.Tree,
  Kitto.Config,
  Kitto.Config.UserFormats,
  Kitto.TestUtils;

type
  /// <summary>A TKConfig that reads the given file instead of the Home's Config.yaml.</summary>
  TKTestConfig = class(TKConfig)
  strict protected
    function GetConfigFileName: string; override;
  public
    class var FileName: string;
  end;

function TKTestConfig.GetConfigFileName: string;
begin
  Result := FileName;
end;

function NewReader(const ASetup: TProc<TEFTree>): TKUserFormatsConfig;
var
  LNode: TEFTree;
begin
  LNode := TEFTree.Create;
  try
    ASetup(LNode);
    Result := TKUserFormatsConfig.Create(LNode);
  finally
    LNode.Free;
  end;
end;

{ TKUserFormatsReaderTests }

procedure TKUserFormatsReaderTests.ShortKeys_AreRead;
var
  LReader: TKUserFormatsConfig;
begin
  LReader := NewReader(
    procedure (ANode: TEFTree)
    begin
      ANode.SetString('Decimal', ',');
      ANode.SetString('Thousand', '.');
    end);
  try
    Assert.AreEqual(',', LReader.Decimal);
    Assert.AreEqual('.', LReader.Thousand);
  finally
    LReader.Free;
  end;
end;

procedure TKUserFormatsReaderTests.LongKeys_AreRead;
var
  LReader: TKUserFormatsConfig;
begin
  LReader := NewReader(
    procedure (ANode: TEFTree)
    begin
      ANode.SetString('DecimalSeparator', ',');
      ANode.SetString('ThousandSeparator', '.');
    end);
  try
    Assert.AreEqual(',', LReader.Decimal, 'Decimal from DecimalSeparator');
    Assert.AreEqual('.', LReader.Thousand, 'Thousand from ThousandSeparator');
    Assert.AreEqual(',', LReader.DecimalSeparator);
    Assert.AreEqual('.', LReader.ThousandSeparator);
  finally
    LReader.Free;
  end;
end;

procedure TKUserFormatsReaderTests.ShortKey_WinsOverLongKey;
var
  LReader: TKUserFormatsConfig;
begin
  LReader := NewReader(
    procedure (ANode: TEFTree)
    begin
      ANode.SetString('Decimal', ',');
      ANode.SetString('DecimalSeparator', '.');
      ANode.SetString('Thousand', '.');
      ANode.SetString('ThousandSeparator', ',');
    end);
  try
    Assert.AreEqual(',', LReader.Decimal);
    Assert.AreEqual('.', LReader.Thousand);
  finally
    LReader.Free;
  end;
end;

{ TKConfigUserFormatsTests }

procedure TKConfigUserFormatsTests.Setup;
begin
  // TKConfig also sets the global FormatSettings: put it back afterwards.
  FSavedFormatSettings := FormatSettings;
  FTempPath := TKTestUtils.CreateTempPath;
  FConfigFileName := TPath.Combine(FTempPath, 'Config.yaml');
  TKTestConfig.FileName := FConfigFileName;
end;

procedure TKConfigUserFormatsTests.TearDown;
begin
  FormatSettings := FSavedFormatSettings;
  TKTestConfig.FileName := '';
  TKTestUtils.RemoveTempPath(FTempPath);
end;

procedure TKConfigUserFormatsTests.WriteConfig(const AUserFormats: string);
begin
  TFile.WriteAllText(FConfigFileName,
    'AppTitle: UserFormatsTest' + sLineBreak +
    'UserFormats:' + sLineBreak + AUserFormats, TEncoding.UTF8);
end;

procedure TKConfigUserFormatsTests.DateAndTime_FollowUserFormats;
var
  LConfig: TKConfig;
begin
  WriteConfig(
    '  Date: dd/mm/yyyy' + sLineBreak +
    '  Time: hh:mm' + sLineBreak);
  LConfig := TKTestConfig.Create;
  try
    Assert.AreEqual('08/06/2021', DateToStr(EncodeDate(2021, 6, 8), LConfig.UserFormatSettings));
    // UserFormats/Time is the SHORT time format ('t'); TimeToStr would use the long one.
    Assert.AreEqual('14:05', FormatDateTime('t', EncodeTime(14, 5, 0, 0), LConfig.UserFormatSettings));
  finally
    LConfig.Free;
  end;
end;

procedure TKConfigUserFormatsTests.DateFormat_FollowsConfigReload;
var
  LConfig: TKConfig;
begin
  WriteConfig('  Date: dd/mm/yyyy' + sLineBreak);
  LConfig := TKTestConfig.Create;
  try
    Assert.AreEqual('08/06/2021', DateToStr(EncodeDate(2021, 6, 8), LConfig.UserFormatSettings));

    WriteConfig('  Date: dd.mm.yyyy' + sLineBreak);
    LConfig.InvalidateConfig;
    Assert.AreEqual('08.06.2021', DateToStr(EncodeDate(2021, 6, 8), LConfig.UserFormatSettings),
      'date format after the config reload');
  finally
    LConfig.Free;
  end;
end;

procedure TKConfigUserFormatsTests.NumberSeparators_FromShortKeys;
var
  LConfig: TKConfig;
begin
  // Separators that no common OS locale uses together, so the test cannot
  // pass by inheriting them from the machine it runs on.
  WriteConfig(
    '  Decimal: "."' + sLineBreak +
    '  Thousand: "''"' + sLineBreak);
  LConfig := TKTestConfig.Create;
  try
    Assert.AreEqual('15''068.00', FormatFloat(',0.00', 15068, LConfig.UserFormatSettings));
  finally
    LConfig.Free;
  end;
end;

procedure TKConfigUserFormatsTests.NumberSeparators_FromLongKeys;
var
  LConfig: TKConfig;
begin
  // Same separators as NumberSeparators_FromShortKeys, through the long keys.
  WriteConfig(
    '  DecimalSeparator: "."' + sLineBreak +
    '  ThousandSeparator: "''"' + sLineBreak);
  LConfig := TKTestConfig.Create;
  try
    Assert.AreEqual('15''068.00', FormatFloat(',0.00', 15068, LConfig.UserFormatSettings));
  finally
    LConfig.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TKUserFormatsReaderTests);
  TDUnitX.RegisterTestFixture(TKConfigUserFormatsTests);

end.
