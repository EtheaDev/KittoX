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
///  A help-chat reply is untrusted content — it comes from an AI provider — and
///  it is rendered as HTML into the page. The Markdown library in safe mode
///  escapes active elements (script/iframe/object), but it does NOT restrict
///  link targets: <c>[x](javascript:alert(1))</c> is valid CommonMark and comes
///  out as a live anchor. These tests cover the URL allowlist that closes that
///  hole, and check that legitimate links are left alone.
/// </summary>
unit Kitto.ChatHtmlTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TKXChatHtmlSecurityTests = class
  public
    /// <summary>A dangerous link or image target never reaches the fragment,
    /// while the link text and legitimate targets survive.</summary>
    [Test]
    procedure Markdown_BlocksDangerousLinkTargets;
    /// <summary>The allowlist: schemes accepted, schemes refused, and the
    /// normalization (entities, whitespace) that must happen before the check.</summary>
    [Test]
    procedure IsSafeUrl_Rules;
    /// <summary>Only the unsafe attribute is rewritten; everything else,
    /// including text with no attribute at all, is returned unchanged.</summary>
    [Test]
    procedure SanitizeUrls_RewritesOnlyUnsafe;
  end;

implementation

uses
  System.SysUtils, // TStringHelper (ToLower on a string variable)
  Kitto.Web.Handler.Chat;

procedure TKXChatHtmlSecurityTests.Markdown_BlocksDangerousLinkTargets;
var
  LHtml: string;
begin
  LHtml := KXChatMarkdownToSafeHtml('[click](javascript:alert(1))');
  Assert.DoesNotContain(LHtml.ToLower, 'javascript:');
  Assert.Contains(LHtml, 'href="#"');
  Assert.Contains(LHtml, '>click</a>', 'the link text survives');

  LHtml := KXChatMarkdownToSafeHtml('![x](data:text/html;base64,AAAA)');
  Assert.DoesNotContain(LHtml.ToLower, 'data:');

  LHtml := KXChatMarkdownToSafeHtml(
    '[ok](https://docs.example.com/a.html) and [rel](grid/export.html)');
  Assert.Contains(LHtml, 'href="https://docs.example.com/a.html"');
  Assert.Contains(LHtml, 'href="grid/export.html"');
end;

procedure TKXChatHtmlSecurityTests.IsSafeUrl_Rules;
begin
  Assert.IsTrue(KXChatIsSafeUrl('https://a.b/c'));
  Assert.IsTrue(KXChatIsSafeUrl('http://a.b'));
  Assert.IsTrue(KXChatIsSafeUrl('mailto:x@y.z'));
  Assert.IsTrue(KXChatIsSafeUrl('#top'));
  Assert.IsTrue(KXChatIsSafeUrl('/docs/a.html'));
  Assert.IsTrue(KXChatIsSafeUrl('grid/export.html'));
  Assert.IsTrue(KXChatIsSafeUrl('page.html?x=1:2'), 'a colon after the query start is not a scheme');
  Assert.IsTrue(KXChatIsSafeUrl(''));

  Assert.IsFalse(KXChatIsSafeUrl('javascript:alert(1)'));
  Assert.IsFalse(KXChatIsSafeUrl('JavaScript:alert(1)'));
  Assert.IsFalse(KXChatIsSafeUrl(' java'#9'script:alert(1)'), 'whitespace and control chars are stripped first');
  Assert.IsFalse(KXChatIsSafeUrl('java&#115;cript:alert(1)'), 'entities are decoded first');
  Assert.IsFalse(KXChatIsSafeUrl('data:text/html,<b>x</b>'));
  Assert.IsFalse(KXChatIsSafeUrl('vbscript:msgbox'));
  Assert.IsFalse(KXChatIsSafeUrl('file:///C:/x'));
end;

procedure TKXChatHtmlSecurityTests.SanitizeUrls_RewritesOnlyUnsafe;
begin
  Assert.AreEqual('<a href="#">x</a><a href="https://ok">y</a>',
    KXChatSanitizeUrls('<a href="javascript:x()">x</a><a href="https://ok">y</a>'));
  Assert.AreEqual('<img src="#" alt="i">',
    KXChatSanitizeUrls('<img src=''data:image/png;base64,AA'' alt="i">'));
  Assert.AreEqual('<a HREF="#">x</a>',
    KXChatSanitizeUrls('<a HREF="JAVASCRIPT:x">x</a>'), 'the attribute name is matched case-insensitively');
  Assert.AreEqual('plain text', KXChatSanitizeUrls('plain text'));
end;

initialization
  TDUnitX.RegisterTestFixture(TKXChatHtmlSecurityTests);

end.
