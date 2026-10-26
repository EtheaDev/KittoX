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
///  Bridges the KittoX tool controllers to the background job runner. The data
///  store is always built on the request thread (via
///  <see cref="TKXToolExecutor.BuildStore" />) where the auth/ACL context
///  (TKAuthenticator/TKAccessController.Current, per-thread) is available;
///  <see cref="TKXToolExecutor.RunToolWithStore" /> then runs the tool against an
///  already-built store, so a background <see cref="TKXToolJob" /> can execute it
///  on a worker thread — which has no request context — writing the artifact to
///  the job directory instead of the HTTP response. This deliberately avoids
///  rebuilding the store (and thus re-checking field ACL) on the worker, which
///  would dereference the nil per-request Current authenticator/access controller.
/// </summary>
unit Kitto.Notification.ToolJob;

{$I Kitto.Defines.inc}

interface

uses
  Kitto.Metadata.DataView,
  Kitto.Notification.Jobs;

type
  /// <summary>Shared executor: builds a tool's data store (request thread) and
  /// runs the tool against a given store (request or worker thread).</summary>
  TKXToolExecutor = class
  public
    /// <summary>Creates and loads the data store for the given view with the
    /// given load filter (record-key WHERE clause or grid filter expression).
    /// MUST be called on the request thread: TKViewTable.CreateStore sets up the
    /// fields and checks field-level ACL, which needs the per-request auth
    /// context. The caller owns the returned store.</summary>
    class function BuildStore(const AViewName, ALoadFilter: string): TKViewTableStore; static;
    /// <summary>
    ///  Runs a tool view against an already-built store. When ABackgroundDir is
    ///  empty the tool runs foreground (produces its own HTTP response); otherwise
    ///  the tool must be a download-file controller and its artifact is written
    ///  into ABackgroundDir (safe on a worker thread — no HTTP response, no store
    ///  rebuild). The store is not freed here (the caller owns it).
    /// </summary>
    class procedure RunToolWithStore(const AViewName, AToolName: string;
      const AStore: TKViewTableStore; const ABackgroundDir: string;
      out AResultPath, AResultFile, AContentType: string); static;
    /// <summary>Foreground convenience: builds the store on the calling (request)
    /// thread and runs the tool, then frees the store.</summary>
    class procedure ExecuteToolCore(const AViewName, AToolName, ALoadFilter,
      ABackgroundDir: string; out AResultPath, AResultFile, AContentType: string); static;
  end;

  /// <summary>
  ///  Background job that runs a KittoX download tool (Export, Report, MergePDF…)
  ///  on a worker thread and declares the produced file as the job result. The
  ///  store is built (and ACL-checked) on the request thread at submit time and
  ///  its ownership is transferred to the job.
  /// </summary>
  TKXToolJob = class(TKXJob)
  strict private
    FViewName: string;
    FToolName: string;
    FStore: TKViewTableStore;
  public
    /// <summary>Creates the job; ownership of AStore is transferred to the job.</summary>
    constructor Create(const AViewName, AToolName: string; const AStore: TKViewTableStore);
    destructor Destroy; override;
    procedure Execute(const AContext: TKXJobContext); override;
  end;

implementation

uses
  System.SysUtils,
  EF.Tree,
  EF.Localization,
  Kitto.Types,
  Kitto.Config,
  Kitto.Metadata.Views,
  Kitto.Html.Base,
  Kitto.Html.Controller,
  Kitto.Html.Files;

{ TKXToolExecutor }

class function TKXToolExecutor.BuildStore(const AViewName, ALoadFilter: string): TKViewTableStore;
var
  LView: TKView;
  LViewTable: TKViewTable;
begin
  LView := TKConfig.Instance.Views.FindView(AViewName);
  if not (LView is TKDataView) then
    raise EKError.CreateFmt(_('Tool: data view "%s" not found.'), [AViewName]);
  LViewTable := TKDataView(LView).MainTable;
  if not Assigned(LViewTable) then
    raise EKError.CreateFmt(_('Tool: view "%s" has no main table.'), [AViewName]);
  Result := LViewTable.CreateStore;
  try
    Result.Load(ALoadFilter, '', 0, 0);
  except
    Result.Free;
    raise;
  end;
end;

class procedure TKXToolExecutor.RunToolWithStore(const AViewName, AToolName: string;
  const AStore: TKViewTableStore; const ABackgroundDir: string;
  out AResultPath, AResultFile, AContentType: string);
var
  LConfig: TKConfig;
  LView: TKView;
  LViewTable: TKViewTable;
  LToolViewsNode, LToolNode: TEFNode;
  LToolView: TKView;
  LToolController: IKXController;
  LObj: TObject;
begin
  AResultPath := '';
  AResultFile := '';
  AContentType := '';

  LConfig := TKConfig.Instance;
  LView := LConfig.Views.FindView(AViewName);
  if not (LView is TKDataView) then
    raise EKError.CreateFmt(_('Tool: data view "%s" not found.'), [AViewName]);
  LViewTable := TKDataView(LView).MainTable;
  if not Assigned(LViewTable) then
    raise EKError.CreateFmt(_('Tool: view "%s" has no main table.'), [AViewName]);

  LToolNode := nil;
  LToolViewsNode := LViewTable.FindNode('Controller/ToolViews');
  if Assigned(LToolViewsNode) then
    LToolNode := LToolViewsNode.FindNode(AToolName);
  if not Assigned(LToolNode) then
  begin
    LToolViewsNode := LViewTable.FindNode('EditController/ToolViews');
    if Assigned(LToolViewsNode) then
      LToolNode := LToolViewsNode.FindNode(AToolName);
  end;
  if not Assigned(LToolNode) then
    raise EKError.CreateFmt(_('Tool "%s" not found in view "%s".'), [AToolName, AViewName]);

  LToolView := LConfig.Views.ViewByNode(LToolNode);
  LToolController := TKXControllerFactory.Instance.CreateController(LToolView);
  try
    LToolController.Config.SetObject('Sys/ServerStore', AStore);
    LToolController.Config.SetObject('Sys/ViewTable', LViewTable);
    if AStore.RecordCount > 0 then
      LToolController.Config.SetObject('Sys/Record', AStore.Records[0]);

    if ABackgroundDir = '' then
      // Foreground: the tool writes its own HTTP response (e.g. a file download).
      LToolController.Display
    else
    begin
      // Background: only download-file tools are supported in this version.
      LObj := LToolController.AsObject;
      if LObj is TKXDownloadFileController then
        TKXDownloadFileController(LObj).ExecuteToFile(ABackgroundDir,
          AResultPath, AResultFile, AContentType)
      else
        raise EKError.Create(_('RunMode: Background is supported only for download-file tools in this version.'));
    end;
  finally
    LToolController.Config.SetObject('Sys/ServerStore', nil);
    LToolController.Config.SetObject('Sys/ViewTable', nil);
    LToolController.Config.SetObject('Sys/Record', nil);
  end;
end;

class procedure TKXToolExecutor.ExecuteToolCore(const AViewName, AToolName, ALoadFilter,
  ABackgroundDir: string; out AResultPath, AResultFile, AContentType: string);
var
  LStore: TKViewTableStore;
begin
  LStore := BuildStore(AViewName, ALoadFilter);
  try
    RunToolWithStore(AViewName, AToolName, LStore, ABackgroundDir,
      AResultPath, AResultFile, AContentType);
  finally
    FreeAndNil(LStore);
  end;
end;

{ TKXToolJob }

constructor TKXToolJob.Create(const AViewName, AToolName: string; const AStore: TKViewTableStore);
begin
  inherited Create;
  FViewName := AViewName;
  FToolName := AToolName;
  FStore := AStore; // ownership transferred to the job
end;

destructor TKXToolJob.Destroy;
begin
  FreeAndNil(FStore);
  inherited;
end;

procedure TKXToolJob.Execute(const AContext: TKXJobContext);
var
  LPath, LFile, LContentType: string;
begin
  TKXToolExecutor.RunToolWithStore(FViewName, FToolName, FStore,
    AContext.ArtifactDir, LPath, LFile, LContentType);
  if LPath = '' then
    raise EKError.Create(_('The tool did not produce any file.'));
  AContext.SetResultFile(LPath, LFile, LContentType);
end;

end.
