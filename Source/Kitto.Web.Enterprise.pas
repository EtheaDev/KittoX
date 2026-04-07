{-------------------------------------------------------------------------------
   Copyright 2012-2026 Ethea S.r.l.

   This file is part of KittoX Enterprise Edition.
   Licensed under the AGPL-3.0 or Ethea Commercial License.
   See LICENSE-ENTERPRISE for details.
-------------------------------------------------------------------------------}

/// <summary>
///   Umbrella unit for KittoX Enterprise Edition features.
///   Include this unit in UseKitto.pas to enable enterprise controllers
///   and their attribute-routed handlers (Chart, Calendar, Map, etc.).
/// </summary>
unit Kitto.Web.Enterprise;

{$I Kitto.Defines.inc}

interface

uses
  // Enterprise controllers (UI rendering + script registration)
  Kitto.Html.ChartPanel,
  Kitto.Html.CalendarPanel,
  Kitto.Html.GoogleMap,
  Kitto.Html.Dashboard,
  // Enterprise attribute-routed handlers (data endpoints)
  Kitto.Web.Handler.Chart,
  Kitto.Web.Handler.Calendar,
  Kitto.Web.Handler.Map;

implementation

end.
