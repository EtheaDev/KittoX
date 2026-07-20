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
///  Registry and factory for KittoX HTML controllers.
///  Same pattern as Kitto.JS.Controller but adapted for IKXController.
/// </summary>
unit Kitto.Html.Controller;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  EF.Classes,
  EF.Intf,
  EF.ObserverIntf,
  EF.Tree,
  EF.Types,
  Kitto.Types,
  Kitto.Metadata.Views,
  Kitto.Html.Base;

type
  /// <summary>
  ///  Holds a list of registered KittoX controller classes.
  ///  Classes must implement IKXController.
  /// </summary>
  TKXControllerRegistry = class(TEFRegistry)
  private
    class var FInstance: TKXControllerRegistry;
    class function GetInstance: TKXControllerRegistry; static;
  protected
    procedure BeforeRegisterClass(const AId: string; const AClass: TClass); override;
  public
    class destructor Destroy;
    /// <summary>The singleton controller-class registry.</summary>
    class property Instance: TKXControllerRegistry read GetInstance;
    /// <summary>Registers a controller class under the given id.</summary>
    procedure RegisterClass(const AId: string; const AClass: TKXComponentClass);
    /// <summary>Returns the controller class registered for the given id.</summary>
    function GetClass(const AId: string): TKXComponentClass;
  end;

  /// <summary>
  ///  Creates KittoX controllers by class Id from the registry.
  /// </summary>
  TKXControllerFactory = class
  private
    class var FInstance: TKXControllerFactory;
    class function GetInstance: TKXControllerFactory; static;
  public
    class destructor Destroy;
    /// <summary>The singleton controller factory.</summary>
    class property Instance: TKXControllerFactory read GetInstance;

    /// <summary>
    ///  Creates a controller for the specified view.
    /// </summary>
    function CreateController(const AView: TKView;
      const AContainer: IKXContainer = nil;
      const AConfig: TEFNode = nil;
      const ACustomType: string = ''): IKXController;
  end;

implementation

uses
  EF.Localization,
  Kitto.AccessControl;

{ TKXControllerRegistry }

procedure TKXControllerRegistry.BeforeRegisterClass(const AId: string; const AClass: TClass);
begin
  if not Supports(AClass, IKXController) then
    raise EKError.CreateFmt('Cannot register class %s (Id %s). Class does not support IKXController.', [AClass.ClassName, AId]);
  inherited;
end;

class destructor TKXControllerRegistry.Destroy;
begin
  FreeAndNil(FInstance);
end;

function TKXControllerRegistry.GetClass(const AId: string): TKXComponentClass;
begin
  Result := TKXComponentClass(inherited GetClass(AId));
end;

class function TKXControllerRegistry.GetInstance: TKXControllerRegistry;
begin
  if FInstance = nil then
    FInstance := TKXControllerRegistry.Create;
  Result := FInstance;
end;

procedure TKXControllerRegistry.RegisterClass(const AId: string; const AClass: TKXComponentClass);
begin
  inherited RegisterClass(AId, AClass);
end;

{ TKXControllerFactory }

class destructor TKXControllerFactory.Destroy;
begin
  FreeAndNil(FInstance);
end;

class function TKXControllerFactory.GetInstance: TKXControllerFactory;
begin
  if FInstance = nil then
    FInstance := TKXControllerFactory.Create;
  Result := FInstance;
end;

function TKXControllerFactory.CreateController(const AView: TKView;
  const AContainer: IKXContainer;
  const AConfig: TEFNode;
  const ACustomType: string): IKXController;
var
  LObject: TKXComponent;
  LType: string;

  function GetControllerType: string;
  begin
    Result := ACustomType;
    if Result = '' then
      if Assigned(AConfig) then
        Result := AConfig.AsExpandedString;
    if Result = '' then
      Result := AView.ControllerType;
    if Result = '' then
      raise EKError.CreateFmt('Cannot create controller for view %s. Unspecified type.', [AView.PersistentName]);
  end;

begin
  Assert(AView <> nil);

  LType := GetControllerType;
  LObject := TKXControllerRegistry.Instance.GetClass(LType).Create;
  try
    if not Supports(LObject, IKXController, Result) then
      raise EKError.Create('Object does not support IKXController.');
    LObject := nil; // Interface owns the object now; prevent double-free in except

    if AConfig <> nil then
      Result.Config.Assign(AConfig)
    else
      Result.Config.Assign(AView.FindNode('Controller'));

    Result.View := AView;

    if Assigned(AContainer) then
    begin
      Result.Container := AContainer;
      AContainer.AddController(Result);
    end;
  except
    FreeAndNil(LObject);
    raise;
  end;
end;

end.
