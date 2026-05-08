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
///
///   Closed-world: if the kx_acl claim is missing, or a (resource, mode) is
///   not covered by any row, the result is "deny" (no fallback to DB). This
///   matches the contract implied by `AccessControl: JWT` in Config.yaml:
///   the claim is the sole source of truth. If the application needs DB-driven
///   ACL evaluation, configure `AccessControl: DB` instead — Auth: JWT can
///   still be used independently for authentication.
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
  Kitto.Web.JWT;

type
  TKJWTAccessController = class(TKAccessController)
  strict private
    function EvaluateFromClaim(const AAcl: TKJWTAclArray;
      const AResourceURI, AMode: string): Variant;
  protected
    function InternalGetAccessGrantValue(const AUserId: string;
      const AResourceURI: string; const AMode: string): Variant; override;
  end;

implementation

uses
  System.Variants,
  EF.RegEx,
  Kitto.Config,
  Kitto.Auth.JWT;

{ TKJWTAccessController }

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
begin
  // Sole evaluation path: a JWT was validated for this request — read the
  // ACL snapshotted at login. Closed-world: missing context, missing claim
  // or unmatched (resource, mode) all yield Null (deny).
  Result := Null;
  if TKJWTAuthenticator.HasContext then
  begin
    LContext := TKJWTAuthenticator.CurrentContext;
    if LContext.HasAcl then
      Result := EvaluateFromClaim(LContext.Acl, AResourceURI, AMode);
  end;
end;

initialization
  TKAccessControllerRegistry.Instance.RegisterClass('JWT', TKJWTAccessController);

finalization
  TKAccessControllerRegistry.Instance.UnregisterClass('JWT');

end.
