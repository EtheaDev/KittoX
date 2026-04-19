# Kitto<sup>x</sup> - A framework for creating data-driven web applications with Delphi and HTMX
[![Core License](https://img.shields.io/badge/Core-Apache%202.0-yellowgreen.svg)](https://opensource.org/licenses/Apache-2.0)
[![Enterprise License](https://img.shields.io/badge/Enterprise-AGPL--3.0%20%2F%20Commercial-blue.svg)](KittoLicensing)

**Latest Version 4.0.2 - 19 Apr 2026**

![KittoX_logo.png](./images/kittoX_logo_200.png)

**Kitto<sup>x</sup>** allows to create **Rich Internet Applications** based on a data model that can be mapped onto any database. The client-side part uses **HTMX** (through webbroker technology) to create a fully **AJAX** application, allowing you to build standard and advanced data-manipulating forms in a fraction of the time.

**Kitto<sup>x</sup>** uses **HTMX** as its client-side library: the server generates HTML fragments and HTMX handles partial page updates via AJAX, with no need for a heavy JavaScript framework.

**Kitto<sup>x</sup>** is aimed at **Delphi** developers that need to create web or mobile applications without delving into the intricacies of HTML, CSS or Javascript, yet it allows access to the bare metal if required.

**Kitto<sup>x</sup>** includes a **database-agnostic** data-access layer, allowing to create applications that work on any database engine and port applications between database engines.

**Kitto<sup>x</sup>** maintains server-side data stores across HTTP requests, enabling record state tracking, transactional master-detail saving, and blob lazy-loading — ensuring data integrity with atomic database transactions.

A **Kitto<sup>x</sup>** application is described as a set of easily maintained **YAML** files, keeping definitions abstract and declarative and allowing for future extensions. Business rules are enforced either declaratively or through small javascript fragments on the client, or in Delphi code on the server.

![Ethea Logo](./images/Logo-Ethea-200x90.png)

**Kitto** framework was originally designed by _Nando Dessena_ in 2011.

**Kitto<sup>x</sup>** retained some basic concepts but was evolved by _Carlo Barazzetta_ to take advantage of the modern and advanced features provided by HTML and to eliminate the dependency on the ExtJS client library.

The development of **Kitto<sup>x</sup>** is sponsored by [Ethea](http://www.ethea.it/), which uses **Kitto<sup>x</sup>** for projects such as [Sport Club Manager](https://sportclubmanager.it/) application.

### _Happy Kittoing!_

---

## Full documentation

- [Documentation site](https://ethea.it/docs/kittox/) with 50+ pages
- Pages for all controllers, filters, data concepts, how-to guides, FAQ
- Three example applications: HelloKitto, TasKitto, KEmployee

---

## Licensing ##

**Kitto<sup>x</sup>** uses an **Open Core** licensing model:

- **Core** (List, Form, Wizard, FlexPanel, routing, database, auth): [Apache 2.0](https://opensource.org/licenses/Apache-2.0) &mdash; free for any use, commercial or non-commercial.

- **Enterprise Modules** (Chart, Calendar, GoogleMap, Dashboard): [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html) for open-source applications, or Ethea Commercial License for closed-source applications. [Please contact Ethea](https://ethea.it/supporto/) for detailed informations about commercial license.

- **KIDEX** (Visual IDE): commercial license only.

See the [Licensing](https://ethea.it/docs/kittox/KittoLicensing.html) page and [Enterprise Edition](KittoEnt) for full details.

Start [here](https://ethea.it/docs/kittox/Kitto-at-a-glance.html) for further information.

Visit [this site](https://ethea.it/Kitto-Demo/) for online demos.

---

# Release Notes

## 19 Apr 2026: ver. 4.0.2 Beta
- Simplified Apache/IIS deployment: static resources served internally, no RewriteRule needed
- New deployment mode: Windows Service + reverse proxy (nginx/Apache/IIS) with install/uninstall scripts
- Fixed ViewMode to EditMode save bug in master-detail forms
- Implemented Apply*Rules event chain (EditRecord, NewRecord, Duplicate, AfterShowEditWindow)
- Master-detail: "Confirm" button (save-cache) and "Save All" only visible in ViewMode
- HTTP error feedback (htmx:responseError) with Retry/Reset dialog
- Updated Italian localization (.po/.mo) with all KittoX strings
- Extensive documentation updates (deploy, proxy, localization, form state machine, routing)
- Added DDL and DML script for Example databases

## 09 Apr 2026: ver. 4.0.1 Beta
- Fixed Field Rules client-side (ForceUpperCase, ForceCamelCaps, MinValue/MaxValue)
- Fixed PackageGroup
- Fixed modal lookup for Reference fields
- Fixed Example for Apache modules

## 07 Apr 2026: ver. 4.0.0 Beta (first public release)

First public release of **Kitto<sup>x</sup>**, the fourth generation of the Kitto framework. Complete rewrite of the client-side from ExtJS to HTMX + AlpineJS + TemplatePro, with a new modular server architecture.

### Architecture

- **HTMX + AlpineJS client**: server-generated HTML fragments with partial page updates via AJAX. No heavy JavaScript framework.
- **Attribute-Based Routing (RTTI)**: URL routing via Delphi custom attributes, inspired by MARS/WiRL. Resource classes register in `initialization` sections; the framework discovers them via RTTI. Dependency injection for request context (`[TKXContext]`). Dynamic JS/CSS injection via `TKXScriptRegistry`.
- **Open Core licensing**: Core (Apache 2.0), Enterprise modules (AGPL-3.0 / Commercial), KIDEX (Commercial only). Separate packages: `KittoXCore.dpk` and `KittoXEnterprise.dpk`.
- **Server-Side Store**: persistent in-session data stores with record state tracking (`rsNew`, `rsClean`, `rsDirty`, `rsDeleted`), transactional master-detail saving (INSERT/UPDATE/DELETE in a single DB transaction), blob lazy-loading, and store lifecycle management (save/cancel/close/timeout).

### Controllers

- **List** (grid with CRUD toolbar, server-side paging, sorting, column layouts, row colors, grouping)
- **GroupingList** (collapsible group headers)
- **Form** (data-aware editing with field pages, detail tabs, ViewMode/EditMode state machine)
- **Wizard** (multi-step data-aware with Back/Next/Finish, per-step validation)
- **BorderPanel**, **TabPanel**, **FlexPanel**, **TreePanel**, **TilePanel**, **HtmlPanel**, **StatusBar**, **ToolBar**
- **Enterprise**: ChartPanel (Chart.js), CalendarPanel (EventCalendar), GoogleMap (Google Maps JS API), Dashboard (auto-refresh)
- **Card View**: List controller with `TemplateFileName` for custom HTML card layouts with full CRUD
- **Desktop Embedded Mode**: KittoX app inside a WebView2 (TEdgeBrowser) VCL window

### Data & Database

- **Database agnostic**: pluggable via FireDAC (preferred), DBExpress, ADO
- **Master-detail transactional save**: master + all detail stores persisted in one transaction
- **Detail CRUD in memory**: add/edit/delete detail records without DB round-trips until final Save All
- **Record state after Load**: records loaded from DB correctly marked as `rsClean`
- **Server-Side Store cache**: blob lazy-load from session store, store released on save/cancel/close/timeout

### Forms & Editing

- **Form State Machine**: ViewMode (Edit / Save All / Close) and EditMode (Save / Cancel) with CSS-based button toggling
- **Save-cache endpoint**: saves master to memory without DB persistence, enables Save All workflow
- **Detail tables**: lazy-loaded tabs, auto-built views, FK pre-fill on Add, transactional cascading save
- **Unified Editor Factory** (`Kitto.Html.Editors`): centralized HTML input generation shared between Form and FilterPanel
- **Help button**: configurable via `Defaults/Help/HRef` in Config.yaml, appears in forms (first button) and list toolbar (after Refresh)

### Mobile Support

- **Automatic mobile detection**: user agent + screen size cookie
- **Fullscreen dialogs on mobile**: `IsModal` + `Maximized` forced for all fragment views/forms via `AdjustControllerForContext`
- **Panel properties**: `IsModal` (dialog overlay), `Maximized` (fullscreen viewport), `AllowClose` (X button and Close button)
- **Width/Height getters**: return 0 when Maximized is True (original values preserved for restore)
- **`kxApp.openView`**: single JS function for view opening from menus (TreePanel and TilePanel use identical logic)
- **`body.kx-mobile` CSS class**: forces dialog and login fullscreen on mobile devices
- **TilePanel**: tile-based menu controller for mobile home pages, with touch support (`role="button"`, `touch-action: manipulation`)
- **Home view selection**: `HomeTinyView` (phone), `HomeSmallView` (tablet), `HomeView` (desktop)

### UI & UX

- **Toast notifications**: shown after save ("Data saved") and delete ("Data deleted"), auto-dismiss 3 seconds
- **Error handling**: DB errors (EEFDBError) non-fatal with clean messages (driver prefixes stripped). Session-level errors trigger reload.
- **Draggable dialogs**: all message boxes and error dialogs draggable by title bar via `kxMakeDraggable`
- **Refresh button**: in CRUD toolbar (visible by default, hidden with `PreventRefreshing` or on read-only controllers)
- **Column sorting**: click to sort ascending, click again for descending, sort arrows via CSS pseudo-elements
- **Double-click to open**: automatic edit/view form from grid rows
- **Session lost detection**: fatal error dialog with reload on server restart
- **Timeout handling**: configurable `AjaxTimeout` for both HTMX and fetch channels, Retry/Reset dialog

### Filters

- Filter Panel with: `FreeSearch`, `List`, `DynaList`, `ButtonList`, `DynaButtonList`
- `DateSearch`, `TimeSearch`, `DateTimeSearch`, `NumericSearch`, `BooleanSearch`
- Layout with `ColumnBreak` and `LabelWidth`

### Custom Layouts
- Custom Layout for Grid and Form
- Grid Layout with Column position, alignment
- Form Layout "multipage", with collapsible regions

### Authentication & Access Control

- Pluggable authenticators: `DB`, `DBCrypt`, `TextFile`, `DBServer`, `OSDB`, `Null`
- Pluggable access controllers: `DB`, `Null`
- BCrypt password hashing, Google OTP (TOTP) two-factor authentication, QR code generation
- Session abstraction: `IKXSessionProvider` with `TKXCookieSessionProvider` (JWT-ready for future)

### Tools

- CSV export (`ExportCSVTool`), Excel export via ADO (`ExportExcelTool`), SQL tool, file download/upload
- FlexCel integration (commercial, Enterprise edition)
- ReportBuilder integration (commercial, Enterprise edition)
- DebenuQuickPDF for PDF merging

### Deployment

- **Standalone** (VCL desktop or Windows service with embedded Indy HTTP server)
- **Desktop Embedded** (WebView2 inside VCL window)
- **Console** (headless server)
- **IIS** (ISAPI DLL via WebBroker)
- **Apache** (module via WebBroker)

### KIDEX (Visual IDE — Enterprise)

- RTTI-based property discovery (replaced 215 MetadataTemplate YAML files)
- 6 custom YAML attributes: `YamlNode`, `YamlRequiredNode`, `YamlContainer`, `YamlSubNode`, `YamlChildType`, `YamlEnumValue`
- SVG icon support (Material Design Icons)
- Database reverse engineering (model creation from DB schema)
- Project wizard, validators, tree editors

### Examples

- **HelloKitto**: simple party/invitation manager (Parties, Girls, Dolls, Invitations)
- **TasKitto**: activity tracking with dashboard, charts, calendar, projects, customers
- **KEmployee**: employee/customer management with master-detail, card views

### Supported Delphi Versions


Available from Delphi 10.4 to Latest (Win32 or Win64 platforms).

![Supporting Delphi](./images/SupportingDelphi.jpg)

Related links: [www.embarcadero.com](https://www.embarcadero.com/) - [https://learndelphi.org](https://learndelphi.org/)
