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
///  Standard tool controllers (DisplayView, URL, FilteredURL) for KittoX.
///  Replaces Kitto.Ext.StandardControllers.
/// </summary>
unit Kitto.Tool.Standard;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Metadata.Views,
  Kitto.Html.Base,
  Kitto.Html.Tools;

type
  /// <summary>
  ///  Opens a view through TKWebApplication.DisplayView. Useful to add a
  ///  view to a panel's toolbar with customized properties (such as
  ///  DisplayLabel or ImageName).
  ///  Equivalent to TKExtDisplayViewController.
  /// </summary>
  TKXDisplayViewController = class(TKXToolController)
  private
    FTargetView: TKView;
    function GetTargetView: TKView;
  protected
    property TargetView: TKView read GetTargetView;
    procedure ExecuteTool; override;
  end;

  /// <summary>
  ///  Base class for URL controllers.
  ///  Equivalent to TKExtURLControllerBase.
  /// </summary>
  TKXURLControllerBase = class(TKXDataToolController)
  protected
    function GetURL: string; virtual; abstract;
    procedure ExecuteTool; override;
  end;

  /// <summary>
  ///  Navigates to a specified URL in a different browser window/tab.
  ///  Equivalent to TKExtURLController.
  /// </summary>
  TKXURLController = class(TKXURLControllerBase)
  protected
    function GetURL: string; override;
  end;

  /// <summary>
  ///  Navigates to a specified URL filtered by request headers.
  ///  Equivalent to TKExtFilteredURLController.
  /// </summary>
  TKXFilteredURLController = class(TKXURLControllerBase)
  protected
    function GetURL: string; override;
  end;

implementation

uses
  EF.Sys,
  EF.Tree,
  EF.RegEx,
  Kitto.Metadata.DataView,
  Kitto.Web.Request,
  Kitto.Web.Application,
  Kitto.Html.Controller;

{ TKXURLControllerBase }

procedure TKXURLControllerBase.ExecuteTool;
var
  LURL: string;
begin
  inherited;
  LURL := GetURL;
  if LURL <> '' then
    TKWebApplication.Current.Navigate(LURL);
end;

{ TKXURLController }

function TKXURLController.GetURL: string;
begin
  Result := Config.GetExpandedString('TargetURL');
end;

{ TKXFilteredURLController }

function TKXFilteredURLController.GetURL: string;
var
  LFilters: TEFNode;
  I: Integer;
  LHeader: string;
  LPattern: string;
  LTargetURL: string;
begin
  Result := '';
  LFilters := Config.FindNode('Filters');
  if Assigned(LFilters) and (LFilters.ChildCount > 0) then
  begin
    for I := 0 to LFilters.ChildCount - 1 do
    begin
      LHeader := TKWebRequest.Current.GetHeaderField(LFilters.Children[I].GetExpandedString('Header'));
      LPattern := LFilters.Children[I].GetExpandedString('Pattern');
      LTargetURL := LFilters.Children[I].GetExpandedString('TargetURL');
      if StrMatchesPatternOrRegex(LHeader, LPattern) then
      begin
        Result := LTargetURL;
        Break;
      end;
    end;
    if Result = '' then
      Result := Config.GetExpandedString('DefaultURL');
  end;
end;

{ TKXDisplayViewController }

procedure TKXDisplayViewController.ExecuteTool;
begin
  inherited;
  TKWebApplication.Current.DisplayView(TargetView);
end;

function TKXDisplayViewController.GetTargetView: TKView;
begin
  if not Assigned(FTargetView) then
    FTargetView := TKWebApplication.Current.Config.Views.FindViewByNode(View.FindNode('Controller/View'));
  Result := FTargetView;
  Assert(Assigned(Result));
end;

initialization
  TKXControllerRegistry.Instance.RegisterClass('DisplayView', TKXDisplayViewController);
  TKXControllerRegistry.Instance.RegisterClass('URL', TKXURLController);
  TKXControllerRegistry.Instance.RegisterClass('FilteredURL', TKXFilteredURLController);

finalization
  TKXControllerRegistry.Instance.UnregisterClass('DisplayView');
  TKXControllerRegistry.Instance.UnregisterClass('URL');
  TKXControllerRegistry.Instance.UnregisterClass('FilteredURL');

end.
