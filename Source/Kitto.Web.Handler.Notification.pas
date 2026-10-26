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
///  Attribute-routed endpoints for the notification center and background-job
///  results: the notifications partial (polled by the bell), the artifact
///  download, and job removal (cancel a running job / delete a completed one /
///  dismiss a failed one). The badge count equals the number of jobs currently
///  in the list; a job leaves the list — deleting its artifact — when it is
///  downloaded, cancelled, deleted or dismissed.
/// </summary>
unit Kitto.Web.Handler.Notification;

{$I Kitto.Defines.inc}
{$RTTI EXPLICIT METHODS([vcPublic, vcPublished]) PROPERTIES([vcPublic, vcPublished])}

interface

uses
  Kitto.Web.Routing.Attributes;

type
  /// <summary>Serves the notification-center partial, job artifact downloads and
  /// job removal.</summary>
  [TKXPath('/kx')]
  TKXNotificationHandler = class
  public
    /// <summary>Returns the HTML fragment with the current user's jobs (running
    /// with a percentage and Cancel, completed with Download and Delete, failed
    /// with Remove) plus a data-count for the bell badge. Polled by htmx. Also
    /// runs the retention cleanup of forgotten jobs.</summary>
    [TKXPath('/notifications')]
    [TKXGET]
    procedure HandleNotifications;

    /// <summary>Streams the artifact produced by a completed job to the client,
    /// then removes the job from the list and deletes its artifact (downloading
    /// takes it out of the list). [TKXNavigable]: reachable by the top-level
    /// browser navigation of the download link, still requiring the auth cookie.</summary>
    [TKXPath('/job/{JobId}/download')]
    [TKXGET]
    [TKXNavigable]
    procedure HandleJobDownload([TKXPathParam('JobId')] const AJobId: string);

    /// <summary>Removes a job from the list — stopping it if running — and deletes
    /// its artifact. Serves Cancel (running/queued), Delete (completed) and
    /// Remove (failed). Returns the refreshed notifications partial.</summary>
    [TKXPath('/job/{JobId}/remove')]
    [TKXPOST]
    procedure HandleJobRemove([TKXPathParam('JobId')] const AJobId: string);

    /// <summary>Removes every job of the current user in one go (the "clear all"
    /// trash in the panel header), deleting their artifacts, and returns the
    /// refreshed (empty) notifications partial.</summary>
    [TKXPath('/notifications/clear')]
    [TKXPOST]
    procedure HandleClearAll;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.NetEncoding,
  EF.Localization,
  Kitto.Auth,
  Kitto.Config,
  Kitto.Config.Server,
  Kitto.Web.Application,
  Kitto.Web.Response,
  Kitto.Html.Utils,
  Kitto.Notification.Types,
  Kitto.Notification.Jobs,
  Kitto.Web.Routing.Registry;

function StatusToClass(const AStatus: TKXJobStatus): string;
begin
  case AStatus of
    jsPending:   Result := 'pending';
    jsRunning:   Result := 'running';
    jsCompleted:   Result := 'completed';
    jsFailed:      Result := 'failed';
    jsCancelled:   Result := 'cancelled';
    jsInterrupted: Result := 'interrupted';
  else
    Result := 'unknown';
  end;
end;

function Enc(const AText: string): string;
begin
  Result := TNetEncoding.HTML.Encode(AText);
end;

// Small "remove/cancel" button posting to the remove endpoint. Uses the themed
// Material SVG "close" icon (theme-adaptive via CSS mask), like the rest of the UI.
function RemoveButton(const AJobId, ATitle: string): string;
begin
  Result := '<button type="button" class="kx-notif-btn" data-action="remove" data-jobid="' +
    AJobId + '" title="' + Enc(ATitle) + '">' + GetIconHTML('close', isSmall) + '</button>';
end;

function RenderNotificationsPartial: string;
var
  LUser: string;
  LJobs: TArray<TKXJobInfo>;
  LInfo: TKXJobInfo;
  LId, LHtml, LActions: string;
begin
  LUser := TKAuthenticator.Current.UserName;
  LJobs := TKXJobQueue.Instance.GetUserJobs(LUser);
  LHtml := '';
  for LInfo in LJobs do
  begin
    LId := JobIdToUrl(LInfo.JobId);
    case LInfo.Status of
      jsPending:
        LActions := '<span class="kx-notif-state">' + _('Queued') + '</span>' +
          RemoveButton(LId, _('Cancel'));
      jsRunning:
        LActions := '<span class="kx-notif-state">' + IntToStr(LInfo.Percent) + '%</span>' +
          RemoveButton(LId, _('Cancel'));
      jsCompleted:
        if LInfo.ResultUrl <> '' then
          LActions := '<a class="kx-notif-download" href="' + Enc(LInfo.ResultUrl) +
            '" data-jobid="' + LId + '" title="' + Enc(_('Download')) + '">' + _('Download') + '</a>' +
            RemoveButton(LId, _('Delete'))
        else
          LActions := '<span class="kx-notif-state">' + _('Done') + '</span>' +
            RemoveButton(LId, _('Delete'));
      jsFailed:
        LActions := '<span class="kx-notif-state kx-notif-error" title="' + Enc(LInfo.Error) + '">' +
          _('Failed') + '</span>' + RemoveButton(LId, _('Remove'));
      jsInterrupted:
        LActions := '<span class="kx-notif-state kx-notif-error" title="' +
          Enc(_('The application restarted while this was running; please re-launch it.')) + '">' +
          _('Interrupted') + '</span>' + RemoveButton(LId, _('Remove'));
    else
      LActions := RemoveButton(LId, _('Remove'));
    end;
    LHtml := LHtml +
      '<div class="kx-notif-item kx-notif-' + StatusToClass(LInfo.Status) + '"' +
        ' data-jobid="' + LId + '" data-status="' + StatusToClass(LInfo.Status) + '">' +
        '<span class="kx-notif-title">' + Enc(LInfo.Title) + '</span>' +
        '<span class="kx-notif-actions">' + LActions + '</span>' +
      '</div>';
  end;
  if LHtml = '' then
    LHtml := '<div class="kx-notif-empty">' + _('No operations.') + '</div>';

  // Badge count = number of jobs in the list.
  Result := '<div id="kx-notif-list" data-count="' + IntToStr(Length(LJobs)) + '">' + LHtml + '</div>';
end;

procedure WritePartial(const AHtml: string);
begin
  TKWebResponse.Current.Items.Clear;
  TKWebResponse.Current.Items.AddHTML(AHtml);
  TKWebResponse.Current.ContentType := 'text/html; charset=utf-8';
end;

{ TKXNotificationHandler }

procedure TKXNotificationHandler.HandleNotifications;
begin
  // Retention: drop finished jobs (and their files) older than the configured age.
  TKXJobQueue.Instance.RemoveExpired(
    TKConfig.Instance.Server.Jobs.ArtifactRetentionHours);
  WritePartial(RenderNotificationsPartial);
end;

procedure TKXNotificationHandler.HandleJobRemove(const AJobId: string);
var
  LGuid: TGUID;
  LInfo: TKXJobInfo;
begin
  if TryUrlToJobId(AJobId, LGuid) and TKXJobQueue.Instance.TryGetInfo(LGuid, LInfo)
    and SameText(LInfo.OwnerUser, TKAuthenticator.Current.UserName) then
    TKXJobQueue.Instance.RemoveJob(LGuid);
  WritePartial(RenderNotificationsPartial);
end;

procedure TKXNotificationHandler.HandleClearAll;
var
  LJobs: TArray<TKXJobInfo>;
  LInfo: TKXJobInfo;
begin
  // "Clear all" in the panel header: remove only the finished jobs (completed /
  // failed / cancelled / interrupted), deleting their artifacts. Jobs still
  // pending or running are left untouched so an in-progress operation is never
  // cancelled by a bulk cleanup.
  LJobs := TKXJobQueue.Instance.GetUserJobs(TKAuthenticator.Current.UserName);
  for LInfo in LJobs do
    if LInfo.Status in [jsCompleted, jsFailed, jsCancelled, jsInterrupted] then
      TKXJobQueue.Instance.RemoveJob(LInfo.JobId);
  WritePartial(RenderNotificationsPartial);
end;

procedure TKXNotificationHandler.HandleJobDownload(const AJobId: string);
var
  LGuid: TGUID;
  LInfo: TKXJobInfo;
  LFileStream: TFileStream;
  LMemStream: TMemoryStream;
begin
  if not TryUrlToJobId(AJobId, LGuid) then
    Exit;
  if not TKXJobQueue.Instance.TryGetInfo(LGuid, LInfo) then
    Exit;
  if not SameText(LInfo.OwnerUser, TKAuthenticator.Current.UserName) then
    Exit; // a user can only download their own job artifacts
  if (LInfo.ResultFilePath = '') or not FileExists(LInfo.ResultFilePath) then
    Exit;

  // Read into memory so the file handle is released and the artifact can be
  // deleted; the response takes ownership of the memory stream.
  LMemStream := TMemoryStream.Create;
  LFileStream := TFileStream.Create(LInfo.ResultFilePath, fmOpenRead or fmShareDenyWrite);
  try
    LMemStream.CopyFrom(LFileStream, 0);
  finally
    FreeAndNil(LFileStream);
  end;
  LMemStream.Position := 0;
  TKWebApplication.Current.DownloadStream(LMemStream, LInfo.ResultFileName, LInfo.ResultContentType, False);

  // A downloaded job leaves the list; its artifact is deleted.
  TKXJobQueue.Instance.RemoveJob(LGuid);
end;

initialization
  TKXResourceRegistry.Instance.RegisterResource(TKXNotificationHandler);
  // Signals to the core that the Notification Center subsystem is linked, so the
  // startup guard can tell an app that enabled Notifications but forgot to add
  // this unit to its UseKitto.pas.
  TKXOptionalFeatureRegistry.Declare('Notifications');

finalization
  TKXResourceRegistry.Instance.UnregisterResource(TKXNotificationHandler);

end.
