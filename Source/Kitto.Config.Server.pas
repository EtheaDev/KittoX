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
///  Typed config readers for the HTTP server domain (Config.yaml node
///  <c>Server</c> and its sub-nodes <c>Jobs</c> and <c>CORS</c>). Part of the
///  per-domain organization of the config metadata (replacing the monolithic
///  Kitto.Metadata.SubNodes / SubNodes2). Each class reads its subtree once into
///  typed fields (see TKConfigReader) AND carries the [YamlNode]/[YamlSubNode]
///  attributes that KIDE reads via RTTI to drive the Config editor.
/// </summary>
unit Kitto.Config.Server;

{$I Kitto.Defines.inc}

interface

uses
  EF.Tree,
  EF.YAML.Attributes,
  Kitto.Config.Reader;

type
  /// <summary>
  ///  Background job runner settings (Notification Center / background tools).
  ///  YAML path: Server/Jobs
  /// </summary>
  /// <example>
  ///  Server:
  ///    Jobs:
  ///      PoolSize: 4
  /// </example>
  TKJobsConfig = class(TKConfigReader)
  private
    FPoolSize: Integer;
    FArtifactRetentionHours: Integer;
    FDirectory: string;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('PoolSize', '4', 'Number of worker threads for background tool jobs')]
    property PoolSize: Integer read FPoolSize;

    [YamlNode('ArtifactRetentionHours', '24', 'Hours a produced job artifact is kept before automatic cleanup')]
    property ArtifactRetentionHours: Integer read FArtifactRetentionHours;

    [YamlNode('Directory', 'Directory where background job artifacts are stored. Empty = default temp/app path')]
    property Directory: string read FDirectory;
  end;

  /// <summary>
  ///  CORS settings for the REST API (/api/v4). Absent/empty AllowedOrigins
  ///  disables CORS.
  ///  YAML path: Server/CORS
  /// </summary>
  /// <example>
  ///  Server:
  ///    CORS:
  ///      AllowedOrigins: https://app.example.com, http://localhost:9999
  ///      AllowCredentials: True
  /// </example>
  TKCORSConfig = class(TKConfigReader)
  private
    FAllowedOrigins: string;
    FAllowCredentials: Boolean;
  protected
    procedure ReadConfig; override;
  public
    [YamlNode('AllowedOrigins', 'Comma-separated list of allowed origins, or * for any. Absent/empty disables CORS')]
    property AllowedOrigins: string read FAllowedOrigins;

    [YamlNode('AllowCredentials', 'False', 'Emit Access-Control-Allow-Credentials: true')]
    property AllowCredentials: Boolean read FAllowCredentials;
  end;

  /// <summary>
  ///  Server settings from Config.yaml.
  ///  YAML path: Server
  /// </summary>
  TKServerConfig = class(TKConfigReader)
  private
    FEngine: string;
    FPort: Integer;
    FSessionTimeOut: Integer;
    FThreadPoolSize: Integer;
    FBindAddress: string;
    FJobs: TKJobsConfig;
    FCORS: TKCORSConfig;
  protected
    procedure ReadConfig; override;
  public
    destructor Destroy; override;

    [YamlNode('Engine', 'indy', 'HTTP stack of a stand-alone application (ignored under IIS or Apache, which bring their own)')]
    [YamlEnumValue('indy', 'The stack KittoX has always used: works everywhere, needs no privileges')]
    [YamlEnumValue('httpsys', 'The kernel-mode stack of Windows, the one IIS sits on: TLS bound with netsh from the certificate store, several processes sharing one port, requests queued while the application restarts. A URL other than localhost needs a reservation (netsh http add urlacl)')]
    property Engine: string read FEngine;

    [YamlNode('Port', '8080', 'HTTP server port')]
    property Port: Integer read FPort;

    [YamlNode('SessionTimeOut', '10', 'Session timeout in minutes. Older position, read only when Engine/Session/TimeOut is missing: prefer that one')]
    property SessionTimeOut: Integer read FSessionTimeOut;

    [YamlNode('ThreadPoolSize', '20', 'Number of threads in the server pool')]
    property ThreadPoolSize: Integer read FThreadPoolSize;

    [YamlNode('BindAddress', 'Bind to specific interface (e.g. 127.0.0.1 for loopback only). Empty = all interfaces')]
    property BindAddress: string read FBindAddress;

    [YamlSubNode('Jobs', TKJobsConfig, 'Background job runner settings (Notification Center)')]
    property Jobs: TKJobsConfig read FJobs;

    [YamlSubNode('CORS', TKCORSConfig, 'CORS settings for the REST API (/api/v4)')]
    property CORS: TKCORSConfig read FCORS;
  end;

implementation

{ TKJobsConfig }

procedure TKJobsConfig.ReadConfig;
begin
  FPoolSize := GetInteger('PoolSize', 4);
  FArtifactRetentionHours := GetInteger('ArtifactRetentionHours', 24);
  FDirectory := GetExpandedString('Directory'); // may contain %APP_PATH% etc.
end;

{ TKCORSConfig }

procedure TKCORSConfig.ReadConfig;
begin
  FAllowedOrigins := GetExpandedString('AllowedOrigins'); // may contain macros
  FAllowCredentials := GetBoolean('AllowCredentials');
end;

{ TKServerConfig }

procedure TKServerConfig.ReadConfig;
begin
  FEngine := GetString('Engine', 'indy');
  FPort := GetInteger('Port', 8080);
  FSessionTimeOut := GetInteger('SessionTimeOut', 10);
  FThreadPoolSize := GetInteger('ThreadPoolSize', 20);
  FBindAddress := GetString('BindAddress');
  // Nested readers: bound to the Jobs/CORS subtrees (nil-safe when absent).
  if FJobs = nil then
    FJobs := TKJobsConfig.Create(SubNode('Jobs'))
  else
    FJobs.Refresh(SubNode('Jobs'));
  if FCORS = nil then
    FCORS := TKCORSConfig.Create(SubNode('CORS'))
  else
    FCORS.Refresh(SubNode('CORS'));
end;

destructor TKServerConfig.Destroy;
begin
  FJobs.Free;
  FCORS.Free;
  inherited;
end;

end.
