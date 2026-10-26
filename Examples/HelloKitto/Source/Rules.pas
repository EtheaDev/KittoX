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

unit Rules;

interface

uses
  Kitto.Rules, KItto.Store;

type
  TCheckDuplicateInvitations = class(TKRuleImpl)
  public
    procedure BeforeAdd(const ARecord: TKRecord); override;
  end;

implementation

uses
  EF.Localization,
  Kitto.Metadata.DataView;

{ TCheckDuplicateInvitations }

procedure TCheckDuplicateInvitations.BeforeAdd(const ARecord: TKRecord);
begin
  if ARecord.Store.Count('INVITEE_ID', ARecord.FieldByName('INVITEE_ID').Value) > 1 then
    RaiseError(_('Cannot invite the same girl twice.'));
end;

initialization
  TKRuleImplRegistry.Instance.RegisterClass(TCheckDuplicateInvitations.GetClassId, TCheckDuplicateInvitations);

finalization
  TKRuleImplRegistry.Instance.UnregisterClass(TCheckDuplicateInvitations.GetClassId);

end.
