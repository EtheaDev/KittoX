# KittoX Licensing

## Overview

KittoX uses an **Open Core** licensing model:

| Component | License | Commercial use |
|-----------|---------|---------------|
| **KittoX Core** | Apache 2.0 | Free for any use |
| **KittoX Enterprise Modules** | AGPL-3.0 / Commercial | Free for open-source apps; commercial license required for closed-source apps |
| **KIDEX** (Visual IDE) | Commercial only | License required |

## KittoX Core (Apache 2.0)

All source files under `Source/` are licensed under the Apache License 2.0 **except**
those explicitly marked as Enterprise modules (see below).

The Apache 2.0 license permits:
- Commercial and non-commercial use
- Modification and distribution
- Private use without source disclosure
- Sublicensing

See [LICENSE](LICENSE) for the full text.

### Core includes

- All `Kitto.Html.*` controllers (List, Form, Wizard, FlexPanel, TreePanel, TabPanel, etc.)
- All `Kitto.Web.Routing.*` infrastructure (attribute-based routing, dependency injection)
- All `EF.*` foundation classes (database, YAML, trees, logging)
- All `Kitto.Auth.*` authenticators (DB, TextFile, OSDB, DBServer)
- All `Kitto.AccessControl.*` access controllers
- All `Kitto.Tool.*` standard tools (Export, SQL, ADO, Indy)
- Web server infrastructure (Indy standalone, ISAPI, Apache module)
- HTMX + AlpineJS client-side framework

## KittoX Enterprise Modules (AGPL-3.0 / Commercial)

Enterprise modules are source files whose header contains:

```
This file is part of KittoX Enterprise Edition.
Licensed under the AGPL-3.0 or Ethea Commercial License.
See LICENSE-ENTERPRISE for details.
```

### AGPL-3.0 (free for open-source)

You may use Enterprise modules at no cost if your application:
- Is released under a license compatible with AGPL-3.0
- Makes its complete source code available to all users
- Includes the AGPL-3.0 license notice

**Important**: The AGPL requires source disclosure even for web applications
accessed over a network (SaaS). If users interact with your application via
a browser, you must provide them access to the source code.

### Ethea Commercial License (for closed-source apps)

If your application is proprietary or closed-source, you must purchase a
commercial license from Ethea S.r.l. The commercial license:
- Removes all AGPL copyleft requirements
- Permits distribution without source disclosure
- Includes priority support
- Is perpetual for the purchased version

Contact: **info@ethea.it**

### Enterprise modules list

| Module | Unit(s) | Description |
|--------|---------|-------------|
| ChartPanel | `Kitto.Html.ChartPanel`, `Kitto.Web.Handler.Chart` | Chart.js charts (bar, line, pie, doughnut) |
| CalendarPanel | `Kitto.Html.CalendarPanel`, `Kitto.Web.Handler.Calendar` | Event Calendar with drag & drop |
| GoogleMap | `Kitto.Html.GoogleMap`, `Kitto.Web.Handler.Map` | Google Maps with markers |
| Dashboard | `Kitto.Html.Dashboard` | Dashboard with auto-refresh |
| Enterprise umbrella | `Kitto.Web.Enterprise` | Includes all enterprise modules |

## KIDEX (Commercial only)

KIDEX is the visual IDE for designing KittoX applications. It is **not**
included in the GitHub repository and is available only with a commercial license.

## How to use

### Open-source application

```pascal
// UseKitto.pas
uses
  Kitto.Html.All,          // Core (Apache 2.0) - always free
  Kitto.Web.Enterprise,    // Enterprise (AGPL-3.0) - free if your app is open-source
  Kitto.Auth.DB;
```

Your application must be released under AGPL-3.0 or a compatible license.

### Commercial application

Purchase a commercial license from Ethea, then use the same code:

```pascal
// UseKitto.pas
uses
  Kitto.Html.All,          // Core (Apache 2.0) - always free
  Kitto.Web.Enterprise,    // Enterprise (Commercial license from Ethea)
  Kitto.Auth.DB;
```

### Core-only application (no enterprise features)

```pascal
// UseKitto.pas
uses
  Kitto.Html.All,          // Core (Apache 2.0) - always free
  Kitto.Auth.DB;
```

No Chart, Calendar, Map, or Dashboard features. No license required beyond Apache 2.0.

## Questions

For licensing inquiries: **info@ethea.it** | https://www.ethea.it
