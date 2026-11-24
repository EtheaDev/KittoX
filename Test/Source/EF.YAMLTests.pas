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
///  Reader and writer tests, on the Data\Test.yaml fixture. Replaces the older
///  DUnit unit of the same purpose, whose fixture file had gone missing.
/// </summary>
unit EF.YAMLTests;

interface

uses
  DUnitX.TestFramework,
  EF.YAML;

type
  [TestFixture]
  TEFYAMLTests = class
  strict private
    FReader: TEFYAMLReader;
    FWriter: TEFYAMLWriter;
    FTempPath: string;
    function FixtureFileName: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Read_ReturnsOneNodePerTopLevelKey;
    [Test]
    procedure Read_KeepsColonsInNamesAndValues;

    /// <summary>
    ///  The name ends at the FIRST colon: 'A:Node:With:Colons: value' declares
    ///  a node named 'A'. The DUnit test that preceded this one expected the
    ///  whole 'A:Node:With:Colons' as the name, but it could never run - its
    ///  fixture was missing from the repository - and the intended behaviour is
    ///  the one pinned down here.
    /// </summary>
    [Test]
    procedure Read_WithColonsInTheName_SplitsOnTheFirstColon;

    /// <summary>
    ///  KNOWN DEFECT (review 4.1). A folded value ('>') spanning several lines
    ///  is written back on a single line. The value survives - that is what
    ///  folding means in YAML - but the file is reformatted, and metadata files
    ///  are edited by hand too: rewriting one from KIDE produces a diff nobody
    ///  asked for. The writer must restore the original line breaks.
    /// </summary>
    [Test]
    procedure WriteFoldedValue_KeepsTheOriginalLineBreaks;
    [Test]
    procedure Read_KeepsDoubleQuotesInValues;
    [Test]
    procedure Read_NestsSubNodesUnderTheirParent;
    [Test]
    procedure Read_RecordsTheFoldedValueAttribute;
    [Test]
    procedure Read_AttachesCommentsToTheNodeBelow;

    /// <summary>
    ///  A comment indented under a block, but followed by a node at a shallower
    ///  level (the comment belongs to the block above, the node dedents past
    ///  it), must keep its own indentation on write. The annotation is attached
    ///  to the following node, so re-indenting it to that node's column moved
    ///  the comment out to column 0 - the defect a KIDE save exposed on
    ///  TasKitto's Config.yaml.
    /// </summary>
    [Test]
    procedure WriteIndentedCommentBeforeADedentedNode_KeepsItsIndentation;

    /// <summary>
    ///  A blank line INSIDE a '|' block scalar is an empty line of the value,
    ///  not the end of the block. It used to be pulled out of the value and
    ///  re-emitted as an annotation of the next node, so a save moved it past
    ///  the following lines of the block.
    /// </summary>
    [Test]
    procedure WriteBlankLineInsideABlockScalar_KeepsItInPlace;

    /// <summary>Reading then writing must give back the very same file: the
    /// metadata editors rewrite files that a human also edits by hand, so any
    /// reformatting shows up as spurious changes.</summary>
    [Test]
    procedure ReadThenWrite_ReproducesTheFileVerbatim;

    [Test]
    procedure ReadThenCloneThenWrite_ReproducesTheFileVerbatim;

    /// <summary>
    ///  KNOWN DEFECT (review 4.1, finding 32). TreeAsString subtracts the
    ///  preamble length from the stream size without checking that anything
    ///  was written: on a tree with no children the length goes negative.
    ///  KIDE hits this by comparing the YAML of an object being edited.
    /// </summary>
    [Test]
    procedure TreeAsString_OnEmptyTree_ReturnsEmptyString;

    /// <summary>
    ///  Nesting depth used to be read off a list that accumulated every
    ///  indentation width seen in the file, so a branch that skipped a width
    ///  another branch had recorded got the wrong number of pops: the node was
    ///  attached to the wrong parent, with no error whatsoever. On a metadata
    ///  file that means a Controller or Rules block silently leaves its
    ///  container and stops being read.
    /// </summary>
    [Test]
    procedure Read_WhenBranchesUseDifferentIndentations_KeepsEachNodeUnderItsParent;

    /// <summary>An indentation that matches no open level is a mistake, and
    /// must be reported rather than guessed at.</summary>
    [Test]
    procedure Read_WithMisalignedIndentation_Raises;

    /// <summary>
    ///  One reader reads the whole metadata catalogue -- Kitto.Metadata creates
    ///  a single TEFYAMLReader and calls LoadTreeFromFile on it for every file
    ///  -- so what one file leaves in the parser is what the next one starts
    ///  with. Reset clears the indents, the annotations and the positions, but
    ///  used to leave FNextValueType alone: a file whose last value is a
    ///  multi-line block ('|' or '>') left the parser expecting more of that
    ///  block, and the first line of the next file was swallowed as a
    ///  continuation of it if it happened to be indented.
    ///
    ///  The visible outcome is a file that parses differently depending on
    ///  which file was read before it, which is the hardest kind of defect to
    ///  reproduce from a bug report.
    /// </summary>
    [Test]
    procedure Read_AfterAFileEndingInAMultiLineValue_StartsTheNextFileClean;

    /// <summary>
    ///  A line with nothing before its colon is a syntax error and has to be
    ///  reported as one. It used to travel on to TEFTree.AddChild, which caught
    ///  it with an Assert -- and an Assert is not a validation mechanism: with
    ///  assertions compiled out, as they are in Release since EF.Defines.inc
    ///  stopped forcing {$C+}, the tree gained a node with no name and the file
    ///  was reported as loaded successfully.
    /// </summary>
    [Test]
    [TestCase('nothing at all before the colon', ': a value')]
    [TestCase('only spaces before the colon', '   : a value')]
    [TestCase('a bare colon', ':')]
    procedure Read_WithAnEmptyNodeName_Raises(const ALine: string);
    /// <summary>
    ///  A file that is not there is a fact about the world, not a broken
    ///  promise from the caller, so it is an exception in every build and not
    ///  an assertion that Release compiles away.
    /// </summary>
    [Test]
    procedure LoadTree_OnAMissingFile_Raises;
  end;

  /// <summary>
  ///  Tests for the enumeration attributes KIDE reads to build its combo boxes.
  /// </summary>
  [TestFixture]
  TYamlEnumAttributeTests = class
  public
    /// <summary>
    ///  The mapping is positional: the Nth YamlEnumValue attribute describes
    ///  the Nth value of the enumeration. Pinned here because nothing in the
    ///  attribute itself says which value it belongs to.
    /// </summary>
    [Test]
    procedure GetYamlEnumValues_MapsEachAttributeToTheValueInThatPosition;
    /// <summary>
    ///  And when the counts do not line up the mapping cannot be right, so it
    ///  is refused instead of shifting every value after the gap. Adding a
    ///  value to an enumeration and forgetting its attribute is the way that
    ///  happens; this is what catches it.
    /// </summary>
    [Test]
    procedure GetYamlEnumValues_WithFewerAttributesThanValues_Raises;
    [Test]
    procedure GetYamlEnumValues_OnATypeThatIsNotAnEnum_ReturnsNothing;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.TypInfo,
  EF.YAML.Attributes,
  EF.YAML.AttributeUtils,
  EF.Tree,
  EF.Types,
  Kitto.TestUtils;

{ TEFYAMLTests }

procedure TEFYAMLTests.Setup;
begin
  FReader := TEFYAMLReader.Create;
  FWriter := TEFYAMLWriter.Create;
  FTempPath := TKTestUtils.CreateTempPath;
end;

procedure TEFYAMLTests.TearDown;
begin
  FreeAndNil(FReader);
  FreeAndNil(FWriter);
  TKTestUtils.RemoveTempPath(FTempPath);
end;

function TEFYAMLTests.FixtureFileName: string;
begin
  Result := TKTestUtils.DataFile('Test.yaml');
end;

procedure TEFYAMLTests.Read_ReturnsOneNodePerTopLevelKey;
var
  LTree: TEFTree;
begin
  LTree := TEFTree.Create;
  try
    FReader.LoadTreeFromFile(LTree, FixtureFileName);
    Assert.AreEqual(6, LTree.ChildCount);
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.Read_KeepsColonsInNamesAndValues;
var
  LTree: TEFTree;
begin
  LTree := TEFTree.Create;
  try
    FReader.LoadTreeFromFile(LTree, FixtureFileName);
    // Only the first colon separates name from value: the others belong to the
    // value and must survive untouched.
    Assert.AreEqual('ANodeWithColonsInTheValue', LTree.Children[1].Name);
    Assert.AreEqual('A:Value:With:Colons', LTree.Children[1].AsString);
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.Read_WithColonsInTheName_SplitsOnTheFirstColon;
var
  LTree: TEFTree;
begin
  LTree := TEFYAMLReader.LoadTreeFromString('A:Node:With:Colons: A value' + sLineBreak);
  try
    Assert.AreEqual('A', LTree.Children[0].Name);
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.WriteFoldedValue_KeepsTheOriginalLineBreaks;
var
  LTree: TEFTree;
  LYaml: string;
begin
  LYaml := 'AFoldedNode: >' + sLineBreak + '  First line.' + sLineBreak + '  Second line.' + sLineBreak;
  LTree := TEFYAMLReader.LoadTreeFromString(LYaml);
  try
    Assert.AreEqual(LYaml, TEFYAMLWriter.TreeAsString(LTree));
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.Read_KeepsDoubleQuotesInValues;
var
  LTree: TEFTree;
begin
  LTree := TEFTree.Create;
  try
    FReader.LoadTreeFromFile(LTree, FixtureFileName);
    Assert.AreEqual('ANodeWithoutColons', LTree.Children[2].Name);
    Assert.AreEqual('A value with "s', LTree.Children[2].AsString);
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.Read_NestsSubNodesUnderTheirParent;
var
  LTree: TEFTree;
begin
  LTree := TEFTree.Create;
  try
    FReader.LoadTreeFromFile(LTree, FixtureFileName);
    Assert.AreEqual(4, LTree.Children[0].ChildCount);
    Assert.AreEqual('Value2', LTree.Children[0].Children[1].AsString);
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.Read_RecordsTheFoldedValueAttribute;
var
  LTree: TEFTree;
begin
  LTree := TEFTree.Create;
  try
    FReader.LoadTreeFromFile(LTree, FixtureFileName);
    Assert.AreEqual('>', LTree.Children[4].ValueAttributes);
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.Read_AttachesCommentsToTheNodeBelow;
var
  LTree: TEFTree;
  LSubNode2: TEFNode;
begin
  LTree := TEFTree.Create;
  try
    FReader.LoadTreeFromFile(LTree, FixtureFileName);
    LSubNode2 := LTree.Children[0].Children[1];
    Assert.AreEqual(2, LSubNode2.AnnotationCount,
      'Both comment lines above the node should be attached to it.');
    // The stored annotation keeps the comment's original indentation (two
    // spaces here), so that the writer can put it back where it was.
    Assert.AreEqual('  # Here comes the second subnode.', LSubNode2.Annotations[1]);
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.WriteIndentedCommentBeforeADedentedNode_KeepsItsIndentation;
var
  LTree: TEFTree;
  LYaml: string;
begin
  // The comment sits at the indentation of Block's children (2 spaces), but the
  // node that follows it - Next - is at column 0. Read then write must give the
  // file back byte for byte, comment indentation included.
  LYaml :=
    'Block:' + sLineBreak +
    '  Child: 1' + sLineBreak +
    '  # a comment that belongs to Block, indented under it' + sLineBreak +
    'Next: 2' + sLineBreak;
  LTree := TEFYAMLReader.LoadTreeFromString(LYaml);
  try
    Assert.AreEqual(LYaml, TEFYAMLWriter.TreeAsString(LTree));
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.WriteBlankLineInsideABlockScalar_KeepsItInPlace;
var
  LTree: TEFTree;
  LYaml: string;
begin
  // The blank line is between two content lines of the block: it is part of the
  // value and must round-trip in place, not migrate after the block.
  LYaml :=
    'Body: |' + sLineBreak +
    '  first line' + sLineBreak +
    '' + sLineBreak +
    '  last line' + sLineBreak;
  LTree := TEFYAMLReader.LoadTreeFromString(LYaml);
  try
    Assert.AreEqual('first line' + sLineBreak + sLineBreak + 'last line',
      LTree.GetString('Body'),
      'The empty line must be kept as an empty line of the value.');
    Assert.AreEqual(LYaml, TEFYAMLWriter.TreeAsString(LTree));
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.ReadThenWrite_ReproducesTheFileVerbatim;
var
  LTree: TEFTree;
  LSavedFileName: string;
begin
  LSavedFileName := FTempPath + 'Test_saved.yaml';
  LTree := TEFTree.Create;
  try
    FReader.LoadTreeFromFile(LTree, FixtureFileName);
    FWriter.SaveTreeToFile(LTree, LSavedFileName);
    // The writer ends lines the platform's way (CRLF on Windows, LF on
    // Linux) whatever the fixture on disk uses.
    Assert.AreEqual(AdjustLineBreaks(TFile.ReadAllText(FixtureFileName), DefaultTextLineBreakStyle),
      TFile.ReadAllText(LSavedFileName));
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.ReadThenCloneThenWrite_ReproducesTheFileVerbatim;
var
  LTree, LClone: TEFTree;
  LSavedFileName: string;
begin
  LSavedFileName := FTempPath + 'Test_cloned.yaml';
  LTree := TEFTree.Create;
  try
    FReader.LoadTreeFromFile(LTree, FixtureFileName);
    LClone := TEFTree.Clone(LTree);
    try
      FWriter.SaveTreeToFile(LClone, LSavedFileName);
    finally
      LClone.Free;
    end;
    // The writer ends lines the platform's way (CRLF on Windows, LF on
    // Linux) whatever the fixture on disk uses.
    Assert.AreEqual(AdjustLineBreaks(TFile.ReadAllText(FixtureFileName), DefaultTextLineBreakStyle),
      TFile.ReadAllText(LSavedFileName));
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.TreeAsString_OnEmptyTree_ReturnsEmptyString;
var
  LTree: TEFTree;
  LResult: string;
begin
  LTree := TEFTree.Create;
  try
    LResult := TEFYAMLWriter.TreeAsString(LTree);
    Assert.AreEqual('', LResult);
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.Read_WhenBranchesUseDifferentIndentations_KeepsEachNodeUnderItsParent;
var
  LTree: TEFTree;
  LE: TEFNode;
begin
  // The first branch records an indentation of 4 (C); the second one goes from
  // 2 (F) straight to 6 (G), skipping it. H then comes back to 2: one level up,
  // not two.
  LTree := TEFYAMLReader.LoadTreeFromString(
    'A:' + sLineBreak +
    '  B:' + sLineBreak +
    '    C: 1' + sLineBreak +
    'E:' + sLineBreak +
    '  F:' + sLineBreak +
    '      G: 2' + sLineBreak +
    '  H: 3' + sLineBreak);
  try
    Assert.AreEqual(2, LTree.ChildCount, 'Only A and E are root nodes.');
    LE := LTree.Children[1];
    Assert.AreEqual('E', LE.Name);
    Assert.AreEqual(2, LE.ChildCount,
      'H should be a child of E, next to F - not a root node of its own.');
    Assert.AreEqual('F', LE.Children[0].Name);
    Assert.AreEqual('H', LE.Children[1].Name);
    Assert.AreEqual('3', LE.Children[1].AsString);
    // ...and G stays under F.
    Assert.AreEqual(1, LE.Children[0].ChildCount);
    Assert.AreEqual('G', LE.Children[0].Children[0].Name);
  finally
    LTree.Free;
  end;
end;

procedure TEFYAMLTests.Read_WithAnEmptyNodeName_Raises(const ALine: string);
begin
  Assert.WillRaise(
    procedure
    var
      LTree: TEFTree;
    begin
      LTree := TEFYAMLReader.LoadTreeFromString(ALine + sLineBreak);
      LTree.Free;
    end,
    EEFError,
    'A line with no name before its colon must be reported, not turned into ' +
    'a node without a name.');
end;

procedure TEFYAMLTests.LoadTree_OnAMissingFile_Raises;
var
  LMissing: string;
begin
  LMissing := TPath.Combine(FTempPath, 'there_is_no_such_file.yaml');
  Assert.IsFalse(TFile.Exists(LMissing), 'The file was supposed not to exist.');
  Assert.WillRaise(
    procedure
    var
      LTree: TEFTree;
    begin
      LTree := TEFTree.Create;
      try
        TEFYAMLReader.LoadTree(LTree, LMissing);
      finally
        LTree.Free;
      end;
    end,
    EEFError);
end;

procedure TEFYAMLTests.Read_AfterAFileEndingInAMultiLineValue_StartsTheNextFileClean;
const
  // Ends inside a '|' block, so the parser is left expecting its continuation.
  FIRST_FILE =
    'Config:' + sLineBreak +
    '  Description: |' + sLineBreak +
    '    first line' + sLineBreak +
    '    second line' + sLineBreak;
  // Starts with an INDENTED comment, which is what the stale expectation
  // mistakes for another line of the block above.
  SECOND_FILE =
    '  # an indented comment' + sLineBreak +
    'Node: a value' + sLineBreak;
var
  LReader: TEFYAMLReader;
  LFirst, LSecond: TEFTree;
begin
  LReader := TEFYAMLReader.Create;
  try
    LFirst := TEFTree.Create;
    try
      LReader.LoadTreeFromString(LFirst, FIRST_FILE);
      Assert.AreEqual('first line' + sLineBreak + 'second line',
        LFirst.GetString('Config/Description'),
        'The first file did not parse as expected, so the test proves nothing.');

      LSecond := TEFTree.Create;
      try
        // The same reader, hence the same parser, exactly as the metadata
        // catalogue uses it.
        LReader.LoadTreeFromString(LSecond, SECOND_FILE);
        Assert.AreEqual(1, LSecond.ChildCount,
          'The second file should have one node; the comment is an annotation, ' +
          'not a node, and not a continuation of the previous file''s value.');
        Assert.AreEqual('a value', LSecond.GetString('Node'));
      finally
        LSecond.Free;
      end;
    finally
      LFirst.Free;
    end;
  finally
    LReader.Free;
  end;
end;

procedure TEFYAMLTests.Read_WithMisalignedIndentation_Raises;
begin
  Assert.WillRaise(
    procedure
    var
      LTree: TEFTree;
    begin
      // 3 spaces: neither the level of B (2) nor a deeper one opened anywhere.
      LTree := TEFYAMLReader.LoadTreeFromString(
        'A:' + sLineBreak +
        '    B: 1' + sLineBreak +
        '   C: 2' + sLineBreak);
      LTree.Free;
    end,
    EEFError,
    'An indentation matching no open level must be reported.');
end;

{ TYamlEnumAttributeTests }

type
  // One attribute per value, in order: the shape every enumeration in the
  // framework is declared in.
  [YamlEnumValue('alpha', 'the first one')]
  [YamlEnumValue('beta', 'the second one')]
  [YamlEnumValue('gamma', 'the third one')]
  TKXWellFormedEnum = (wfAlpha, wfBeta, wfGamma);

  // Two attributes, three values: what a declaration looks like after someone
  // has added a value and left the attributes alone.
  [YamlEnumValue('one')]
  [YamlEnumValue('two')]
  TKXShortOfAttributesEnum = (soOne, soTwo, soThree);

procedure TYamlEnumAttributeTests.GetYamlEnumValues_MapsEachAttributeToTheValueInThatPosition;
var
  LValues: TArray<TYamlEnumValueInfo>;
begin
  LValues := TYamlAttributeReader.GetYamlEnumValues(TypeInfo(TKXWellFormedEnum));
  // Length is a NativeInt on this RTL, hence the cast.
  Assert.AreEqual(3, Integer(Length(LValues)));

  Assert.AreEqual(0, LValues[0].OrdinalValue);
  Assert.AreEqual('wfAlpha', LValues[0].EnumName);
  Assert.AreEqual('alpha', LValues[0].YamlValue);
  Assert.AreEqual('the first one', LValues[0].Description);

  Assert.AreEqual(2, LValues[2].OrdinalValue);
  Assert.AreEqual('wfGamma', LValues[2].EnumName);
  Assert.AreEqual('gamma', LValues[2].YamlValue);
end;

procedure TYamlEnumAttributeTests.GetYamlEnumValues_WithFewerAttributesThanValues_Raises;
begin
  Assert.WillRaise(
    procedure
    var
      LValues: TArray<TYamlEnumValueInfo>;
    begin
      LValues := TYamlAttributeReader.GetYamlEnumValues(
        TypeInfo(TKXShortOfAttributesEnum));
    end,
    EEFError,
    'Two attributes for three values cannot describe the enumeration, and ' +
    'saying nothing about it shifts every mapping after the gap.');
end;

procedure TYamlEnumAttributeTests.GetYamlEnumValues_OnATypeThatIsNotAnEnum_ReturnsNothing;
begin
  Assert.AreEqual(0,
    Integer(Length(TYamlAttributeReader.GetYamlEnumValues(TypeInfo(string)))));
end;

initialization
  TDUnitX.RegisterTestFixture(TEFYAMLTests);
  TDUnitX.RegisterTestFixture(TYamlEnumAttributeTests);

end.
