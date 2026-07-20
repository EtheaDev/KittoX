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
///  Wizard rule support for KittoX. Provides a base class for wizard-specific
///  business rules (step navigation, execute, cancel callbacks).
///  Rules are associated to wizard views in a Rules subnode and are
///  registered/invoked by name, like model rules.
///
///  Usage in YAML:
///    Controller: Wizard
///      Rules:
///        MyWizardRules:
///
///  Usage in Delphi:
///    type
///      TMyWizardRules = class(TKXWizardRuleImpl)
///      public
///        procedure BeforeNextStep(const ARecord: TKRecord;
///          const ACurrentStep: Integer; var AAllow: Boolean); override;
///        procedure BeforeExecute(const ARecord: TKRecord); override;
///        procedure AfterExecute(const ARecord: TKRecord); override;
///      end;
///
///    initialization
///      TKXWizardRuleRegistry.Instance.RegisterClass('MyWizardRules', TMyWizardRules);
///    finalization
///      TKXWizardRuleRegistry.Instance.UnregisterClass('MyWizardRules');
/// </summary>
unit Kitto.Rules.Wizard;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  EF.Types,
  EF.Tree,
  Kitto.Store;

type
  EKWizardRuleError = class(Exception);

  /// <summary>
  ///  Base class for wizard rule implementations.
  ///  Override the virtual methods you need. All methods have empty defaults.
  /// </summary>
  TKXWizardRuleImpl = class
  strict private
    FConfig: TEFNode;
  public
    /// <summary>
    ///  The rule's configuration node from YAML (children of the rule name node).
    /// </summary>
    property Config: TEFNode read FConfig write FConfig;

    /// <summary>
    ///  Called before moving to the next step. Set AAllow := False to prevent
    ///  the navigation. Raise an exception to show an error message.
    ///  ACurrentStep is 0-based.
    /// </summary>
    procedure BeforeNextStep(const ARecord: TKRecord;
      const ACurrentStep: Integer; var AAllow: Boolean); virtual;

    /// <summary>
    ///  Called after successfully moving to the next step.
    ///  ANewStep is the step just navigated to (0-based).
    /// </summary>
    procedure AfterNextStep(const ARecord: TKRecord;
      const ANewStep: Integer); virtual;

    /// <summary>
    ///  Called before moving back to the previous step. Set AAllow := False
    ///  to prevent navigation. ACurrentStep is 0-based.
    /// </summary>
    procedure BeforePrevStep(const ARecord: TKRecord;
      const ACurrentStep: Integer; var AAllow: Boolean); virtual;

    /// <summary>
    ///  Called after successfully moving to the previous step.
    ///  ANewStep is the step just navigated to (0-based).
    /// </summary>
    procedure AfterPrevStep(const ARecord: TKRecord;
      const ANewStep: Integer); virtual;

    /// <summary>
    ///  Called before executing the wizard finish (saving the record).
    ///  Raise an exception to prevent the save and show an error.
    ///  The record contains the values from all steps.
    /// </summary>
    procedure BeforeExecute(const ARecord: TKRecord); virtual;

    /// <summary>
    ///  Called after the record has been successfully saved to the database.
    ///  Can perform additional operations (e.g. send notifications,
    ///  create related records). Raise an exception to rollback the
    ///  transaction.
    /// </summary>
    procedure AfterExecute(const ARecord: TKRecord); virtual;

    /// <summary>
    ///  Called before cancelling the wizard. Set AAllow := False to prevent
    ///  cancellation (e.g. show "are you sure?" confirmation).
    /// </summary>
    procedure BeforeCancel(var AAllow: Boolean); virtual;

    /// <summary>
    ///  Called after the wizard has been cancelled. Can perform cleanup.
    /// </summary>
    procedure AfterCancel; virtual;
  end;
  TKXWizardRuleImplClass = class of TKXWizardRuleImpl;

  /// <summary>
  ///  Registry for wizard rule implementation classes.
  ///  Register your classes in initialization sections.
  /// </summary>
  TKXWizardRuleRegistry = class
  strict private
    FClasses: TDictionary<string, TKXWizardRuleImplClass>;
    class var FInstance: TKXWizardRuleRegistry;
    class function GetInstance: TKXWizardRuleRegistry; static;
  public
    constructor Create;
    destructor Destroy; override;
    class destructor ClassDestroy;
    /// <summary>The singleton wizard-rule registry.</summary>
    class property Instance: TKXWizardRuleRegistry read GetInstance;

    /// <summary>Registers a wizard-rule implementation class under the given id.</summary>
    procedure RegisterClass(const AId: string; const AClass: TKXWizardRuleImplClass);
    /// <summary>Removes the wizard-rule implementation class registered under the given id.</summary>
    procedure UnregisterClass(const AId: string);
    /// <summary>Returns True if a wizard-rule class is registered under the given id.</summary>
    function HasClass(const AId: string): Boolean;
    /// <summary>Creates an instance of the wizard-rule class registered under the given id.</summary>
    function CreateObject(const AId: string): TKXWizardRuleImpl;
  end;

implementation

{ TKXWizardRuleImpl }

procedure TKXWizardRuleImpl.BeforeNextStep(const ARecord: TKRecord;
  const ACurrentStep: Integer; var AAllow: Boolean);
begin
  // Default: allow
  AAllow := True;
end;

procedure TKXWizardRuleImpl.AfterNextStep(const ARecord: TKRecord;
  const ANewStep: Integer);
begin
  // Default: no-op
end;

procedure TKXWizardRuleImpl.BeforePrevStep(const ARecord: TKRecord;
  const ACurrentStep: Integer; var AAllow: Boolean);
begin
  // Default: allow
  AAllow := True;
end;

procedure TKXWizardRuleImpl.AfterPrevStep(const ARecord: TKRecord;
  const ANewStep: Integer);
begin
  // Default: no-op
end;

procedure TKXWizardRuleImpl.BeforeExecute(const ARecord: TKRecord);
begin
  // Default: no-op
end;

procedure TKXWizardRuleImpl.AfterExecute(const ARecord: TKRecord);
begin
  // Default: no-op
end;

procedure TKXWizardRuleImpl.BeforeCancel(var AAllow: Boolean);
begin
  // Default: allow
  AAllow := True;
end;

procedure TKXWizardRuleImpl.AfterCancel;
begin
  // Default: no-op
end;

{ TKXWizardRuleRegistry }

constructor TKXWizardRuleRegistry.Create;
begin
  inherited Create;
  FClasses := TDictionary<string, TKXWizardRuleImplClass>.Create;
end;

destructor TKXWizardRuleRegistry.Destroy;
begin
  FreeAndNil(FClasses);
  inherited;
end;

class destructor TKXWizardRuleRegistry.ClassDestroy;
begin
  FreeAndNil(FInstance);
end;

class function TKXWizardRuleRegistry.GetInstance: TKXWizardRuleRegistry;
begin
  if not Assigned(FInstance) then
    FInstance := TKXWizardRuleRegistry.Create;
  Result := FInstance;
end;

procedure TKXWizardRuleRegistry.RegisterClass(const AId: string;
  const AClass: TKXWizardRuleImplClass);
begin
  FClasses.AddOrSetValue(AId, AClass);
end;

procedure TKXWizardRuleRegistry.UnregisterClass(const AId: string);
begin
  FClasses.Remove(AId);
end;

function TKXWizardRuleRegistry.HasClass(const AId: string): Boolean;
begin
  Result := FClasses.ContainsKey(AId);
end;

function TKXWizardRuleRegistry.CreateObject(const AId: string): TKXWizardRuleImpl;
var
  LClass: TKXWizardRuleImplClass;
begin
  if not FClasses.TryGetValue(AId, LClass) then
    raise EKWizardRuleError.CreateFmt('Wizard rule "%s" not registered.', [AId]);
  Result := LClass.Create;
end;

end.
