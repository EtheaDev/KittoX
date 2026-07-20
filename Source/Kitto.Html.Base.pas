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
///  Foundation classes for the KittoX HTML rendering pipeline.
///  Defines the base interfaces and component class that replace TJSObject/TJSBase
///  for server-side HTML generation using TemplatePro + HTMX + AlpineJS.
/// </summary>
unit Kitto.Html.Base;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils,
  System.Classes,
  EF.Intf,
  EF.Classes,
  EF.Tree,
  EF.ObserverIntf,
  Kitto.Metadata.Views;

type
  IKXContainer = interface;

  /// <summary>
  ///  Controller interface for KittoX HTML components.
  ///  Replaces IJSController for the HTML rendering pipeline.
  /// </summary>
  IKXController = interface(IEFInterface)
    ['{A1D2E3F4-5678-9ABC-DEF0-112233445566}']
    /// <summary>Prepares the controller for rendering (create sub-objects, read config).</summary>
    procedure Display;
    function GetView: TKView;
    procedure SetView(const AValue: TKView);
    /// <summary>The view this controller renders.</summary>
    property View: TKView read GetView write SetView;
    function GetConfig: TEFComponentConfig;
    /// <summary>The controller's configuration node.</summary>
    property Config: TEFComponentConfig read GetConfig;
    function GetContainer: IKXContainer;
    procedure SetContainer(const AValue: IKXContainer);
    /// <summary>The container hosting this controller, if any.</summary>
    property Container: IKXContainer read GetContainer write SetContainer;
    /// <summary>True if the controller renders synchronously (no async round-trip).</summary>
    function IsSynchronous: Boolean;
    /// <summary>Renders the controller to an HTML string.</summary>
    function Render: string;
  end;

  /// <summary>
  ///  Container interface for KittoX components that host child controllers.
  /// </summary>
  IKXContainer = interface(IEFInterface)
    ['{B2C3D4E5-6789-ABCD-EF01-223344556677}']
    /// <summary>Adds a child controller to be rendered by RenderChildren.</summary>
    procedure AddController(const AController: IKXController);
    /// <summary>Renders all child controllers and returns the concatenated HTML.</summary>
    function RenderChildren: string;
  end;

  TKXComponentClass = class of TKXComponent;

  /// <summary>
  ///  Base class for all KittoX HTML components.
  ///  Inherits from TEFComponent for config/logging support.
  ///  Each component renders to an HTML string via the Render method.
  /// </summary>
  TKXComponent = class(TEFComponent, IKXController)
  strict private
    FView: TKView;
    [unsafe] FContainer: IKXContainer;
    FRefCount: Integer;
    class var FSequence: Integer;
    class function NextSequence: Integer;
  strict protected
    function GetView: TKView;
    procedure SetView(const AValue: TKView);
    function GetContainer: IKXContainer;
    procedure SetContainer(const AValue: IKXContainer);
  public
    // IInterface
    /// <summary>IInterface: queries a supported interface.</summary>
    function QueryInterface(const IID: TGUID; out Obj): HRESULT; stdcall;
    /// <summary>IInterface: increments the reference count.</summary>
    function _AddRef: Integer; stdcall;
    /// <summary>IInterface: decrements the reference count (frees at zero).</summary>
    function _Release: Integer; stdcall;
  public
    /// <summary>Prepares the component for rendering (no-op by default).</summary>
    procedure Display; virtual;
    /// <summary>The view this component renders.</summary>
    property View: TKView read GetView write SetView;
    /// <summary>The container hosting this component, if any.</summary>
    property Container: IKXContainer read GetContainer write SetContainer;
    /// <summary>True if the component renders synchronously.</summary>
    function IsSynchronous: Boolean; virtual;

    /// <summary>
    ///  Returns a unique HTML element id for this component.
    ///  Format: 'kx-{ViewName}' or 'kx-{ControllerType}-{sequence}'.
    /// </summary>
    function GetHtmlId: string; virtual;

    /// <summary>
    ///  Renders this component to an HTML string.
    ///  Must be overridden by concrete subclasses.
    /// </summary>
    function Render: string; virtual; abstract;
  end;

implementation

uses
  EF.StrUtils;

{ TKXComponent }

class function TKXComponent.NextSequence: Integer;
begin
  Inc(FSequence);
  Result := FSequence;
end;

function TKXComponent.QueryInterface(const IID: TGUID; out Obj): HRESULT;
begin
  if GetInterface(IID, Obj) then
    Result := 0
  else
    Result := E_NOINTERFACE;
end;

function TKXComponent._AddRef: Integer;
begin
  Result := AtomicIncrement(FRefCount);
end;

function TKXComponent._Release: Integer;
begin
  Result := AtomicDecrement(FRefCount);
  if Result = 0 then
    Destroy;
end;

function TKXComponent.GetView: TKView;
begin
  Result := FView;
end;

procedure TKXComponent.SetView(const AValue: TKView);
begin
  FView := AValue;
end;

function TKXComponent.GetContainer: IKXContainer;
begin
  Result := FContainer;
end;

procedure TKXComponent.SetContainer(const AValue: IKXContainer);
begin
  FContainer := AValue;
end;

procedure TKXComponent.Display;
begin
  // Default implementation does nothing.
  // Subclasses override to perform setup before Render is called.
end;

function TKXComponent.IsSynchronous: Boolean;
begin
  Result := True;
end;

function TKXComponent.GetHtmlId: string;
begin
  if Assigned(FView) and (FView.PersistentName <> '') then
    Result := 'kx-' + FView.PersistentName
  else
    Result := 'kx-' + StripPrefix(ClassName, 'TKX') + '-' + IntToStr(NextSequence);
end;

end.
