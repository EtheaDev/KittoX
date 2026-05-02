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
///   JWT-claim-based access controller. Reads grants from the kx_acl claim
///   embedded in the JWT at login time (by TKJWTAuthenticator.BuildAclFromDB)
///   and replays the same matching logic as TKDBAccessController/TKUserPermissionStorage.
///   Falls back to TKDBAccessController when the claim is absent or when
///   FallbackToDB is enabled and a specific resource/mode is not covered by
///   the claim.
///
///   Trade-off: ACL grants are snapshotted at login and cached in the JWT for
///   its lifetime. A grant change applied to the database mid-session is NOT
///   reflected until the user logs in again. Keep TokenLifetime / SlidingThreshold
///   reasonable, or force re-login from an admin tool when grants change.
/// </summary>
unit Kitto.AccessControl.JWT;

{$I Kitto.Defines.inc}

interface

uses
  System.Classes,
  System.SysUtils,
  EF.Tree,
  Kitto.AccessControl,
  Kitto.AccessControl.DB,
  Kitto.Web.JWT;

type
  TKJWTAccessController = class(TKAccessController)
  strict private
    FFallbackToDB: Boolean;
    FFallbackController: TKDBAccessController;
    FFallbackInitialized: Boolean;
    function EnsureFallbackController: TKDBAccessController;
    function EvaluateFromClaim(const AAcl: TKJWTAclArray;
      const AResourceURI, AMode: string): Variant;
  protected
    procedure InternalInit; override;
    function InternalGetAccessGrantValue(const AUserId: string;
      const AResourceURI: string; const AMode: string): Variant; override;
  public
    procedure AfterConstruction; override;
    destructor Destroy; override;
  end;

implementation

uses
  System.Variants,
  EF.RegEx,
  Kitto.Config,
  Kitto.Auth.JWT;

{ TKJWTAccessController }

procedure TKJWTAccessController.AfterConstruction;
begin
  inherited;
  FFallbackToDB := True;
  FFallbackInitialized := False;
  FFallbackController := nil;
end;

destructor TKJWTAccessController.Destroy;
begin
  FreeAndNil(FFallbackController);
  inherited;
end;

procedure TKJWTAccessController.InternalInit;
begin
  inherited;
  FFallbackToDB := Config.GetBoolean('FallbackToDB', True);
end;

function TKJWTAccessController.EnsureFallbackController: TKDBAccessController;
var
  I: Integer;
begin
  // Double-checked locking: many concurrent IsAccessGranted calls can race here
  // when the JWT claim does not cover a (resource, mode) pair, and an unguarded
  // check would create multiple TKDBAccessController instances that leak.
  if FFallbackInitialized then
    Exit(FFallbackController);
  TMonitor.Enter(Self);
  try
    if FFallbackInitialized then
      Exit(FFallbackController);
    if not FFallbackToDB then
    begin
      FFallbackInitialized := True;
      Exit(nil);
    end;

    FFallbackController := TKDBAccessController.Create;
    // Carry over the SQL templates and DatabaseRouter (if any) so the fallback
    // sees the exact same configuration the JWT login-time snapshot used.
    for I := 0 to Config.ChildCount - 1 do
      if Config.Children[I].Name <> 'FallbackToDB' then
        FFallbackController.Config.AddChild(TEFNode.Clone(Config.Children[I]));
    FFallbackController.Init;
    FFallbackInitialized := True;
    Result := FFallbackController;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TKJWTAccessController.EvaluateFromClaim(const AAcl: TKJWTAclArray;
  const AResourceURI, AMode: string): Variant;
var
  I: Integer;
  LPattern, LModes: string;
begin
  // Replicates the matching loop of TKUserPermissionStorage.GetAccessGrantValue:
  //  - macro expand patterns containing %
  //  - StrMatchesPatternOrRegex for pattern (wildcards / REGEX: / negation)
  //  - mode is in the comma-separated ACCESS_MODES of the row
  //  - last match wins, except for standard modes where ACV_FALSE breaks early
  //    (so an explicit deny dominates an inherited allow).
  Result := Null;
  for I := 0 to High(AAcl) do
  begin
    LPattern := AAcl[I].Pattern;
    if Pos('%', LPattern) > 0 then
      TKConfig.Instance.MacroExpansionEngine.Expand(LPattern);
    LModes := AAcl[I].Modes;
    if StrMatchesPatternOrRegex(AResourceURI, LPattern)
      and ((Pos(AMode + ',', LModes) > 0)
        or (Pos(',' + AMode, LModes) > 0)
        or (AMode = LModes)) then
    begin
      Result := AAcl[I].GrantValue;
      if TKAccessController.IsStandardMode(AMode) and (Result = ACV_FALSE) then
        Break;
    end;
  end;
end;

function TKJWTAccessController.InternalGetAccessGrantValue(
  const AUserId, AResourceURI, AMode: string): Variant;
var
  LContext: TKJWTContext;
  LFallback: TKDBAccessController;
begin
  Result := Null;

  // Path 1: a JWT was validated for this request — read the snapshotted ACL.
  if TKJWTAuthenticator.HasContext then
  begin
    LContext := TKJWTAuthenticator.CurrentContext;
    if LContext.HasAcl then
    begin
      Result := EvaluateFromClaim(LContext.Acl, AResourceURI, AMode);
      if not VarIsNull(Result) then
        Exit;
    end;
  end;

  // Path 2: claim missing or no match — optionally consult the DB. When the
  // app uses Auth: JWT but did not opt into kx_acl (Claims/IncludeACL=False),
  // this is the normal evaluation path. When the claim is present but did
  // not cover this specific resource/mode, the fallback fills the gap.
  if FFallbackToDB then
  begin
    LFallback := EnsureFallbackController;
    if Assigned(LFallback) then
      Result := LFallback.GetAccessGrantValue(AUserId, AResourceURI, AMode, Null);
  end;
end;

initialization
  TKAccessControllerRegistry.Instance.RegisterClass('JWT', TKJWTAccessController);

finalization
  TKAccessControllerRegistry.Instance.UnregisterClass('JWT');

end.
