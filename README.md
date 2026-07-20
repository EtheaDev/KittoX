# Kitto<sup>x</sup> - A framework for creating data-driven web applications with Delphi and HTMX
[![Core License](https://img.shields.io/badge/Core-Apache%202.0-yellowgreen.svg)](https://opensource.org/licenses/Apache-2.0)
[![Enterprise License](https://img.shields.io/badge/Enterprise-AGPL--3.0%20%2F%20Commercial-blue.svg)](KittoLicensing)

**Latest Version 4.0.10 - 20 Jul 2026**

![KittoX_logo.png](./images/kittoX_logo_200.png)

**Kitto<sup>x</sup>** allows to create **Rich Internet Applications** based on a data model that can be mapped onto any database. The client-side part uses **HTMX** (through webbroker technology) to create a fully **AJAX** application, allowing you to build standard and advanced data-manipulating forms in a fraction of the time.

**Kitto<sup>x</sup>** is aimed at **Delphi** developers that need to create web or mobile applications without delving into the intricacies of HTML, CSS or Javascript, yet it allows access to the bare metal if required.

**Kitto<sup>x</sup>** includes a **database-agnostic** data-access layer, allowing to create applications that work on any database engine and port applications between database engines.

A **Kitto<sup>x</sup>** application is described as a set of easily maintained **YAML** files, keeping definitions abstract and declarative and allowing for future extensions. Business rules are enforced either declaratively or through small javascript fragments on the client, or in Delphi code on the server.

---

## Full documentation

- [Documentation site](https://ethea.it/docs/kittox/) with 50+ pages
- Pages for all controllers, filters, data concepts, how-to guides, FAQ
- Three example applications: HelloKitto, TasKitto, KEmployee

---

## Enterprise Edition ##

Beyond the Apache 2.0 Core, **Kitto<sup>x</sup>** ships with Enterprise modules and developer tools under commercial license:

- **Enterprise components** &mdash; interactive Charts (Chart.js), Calendars (EventCalendar), Google Maps with geocoding and markers, Dashboards and FlexPanels &mdash; all driven by YAML metadata, no client-side coding required.

- **KIDE<sup>x</sup>** &mdash; the visual IDE for designing **Kitto<sup>x</sup>** applications. Tree-based YAML editor with **RTTI-based property discovery**, database reverse engineering (FireDAC / DBExpress / ADO), a New Project Wizard that scaffolds complete apps for up to 4 deployment modes (Standalone .exe / Desktop .exe / ISAPI .dll / Apache .dll), and an integrated HTTP server for live preview. Ships with a RAD Studio design-time package (`KittoXIDE.bpl`) that integrates the same wizard under **File &gt; New &gt; Other &gt; KittoX Projects** and adds a YAML syntax highlighter to the IDE editor.

- **MCP-KittoX** &mdash; standalone Model Context Protocol server (`MCPKittoX.exe`) that exposes KIDE<sup>x</sup> functionality to AI agents (Claude Desktop / Code, Codex, LM Studio, any MCP-compatible client). Agents can scaffold complete **Kitto<sup>x</sup>** apps and reverse-engineer Models from a live database conversationally; metadata validation, locale refresh and view scaffolding tools are on the next-phases roadmap. Bundled with KIDE<sup>x</sup>: a single OnGuard registration unlocks both.

[Contact Ethea](https://ethea.it/supporto/) for commercial license details, or see the [Enterprise Edition](https://ethea.it/docs/kittox/KittoEnt.html) page on the documentation site.

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

## 20 Jul 2026: ver. 4.0.10 Beta

### Oracle & Database
- **Oracle is now a fully supported backend**: new DDL + Data scripts for the HelloKitto and TasKitto examples (Oracle XE 21c), plus `TasKitto_Oracle_ShiftDates.sql` to re-center the demo dashboard dates
- **Oracle SQL dialect fixes**: corrected the top-N pagination off-by-one (Oracle `ROWNUM` is 1-based — single-row fetches previously returned 0 rows, full pages were short by one) and reintroduced the portable **`%DB.CONCAT%`** macro (`||` on Oracle/PostgreSQL/Firebird, `+` on SQL Server); new **`%DB.FROM_DUAL%`** and **`%DB.CURRENT_DATE%`** macros make hand-written YAML SQL portable across all five dialects
- **FireDAC Oracle** wired up in the examples: the `Ora` driver is registered in `UseKitto.pas` and a ready-to-use `FireDAC_Oracle` connection block ships (commented) in `Config.yaml`
- **New optional ODAC backend** (`EF.DB.ODAC`, ClassId `ODAC`): an alternative Oracle path built on Devart ODAC, modelled on the FireDAC adapter (connection, commands, queries, transactions, metadata introspection via the Oracle data dictionary). It reuses the existing Oracle dialect and is **not** in the core package (commercial dependency) — enable it per-app by referencing the unit; the examples ship it defined-but-disabled so they still compile without ODAC installed
- Fix **`ftUnknown` parameter binding under MS ODBC Driver 17/18**: with `DirectExecute` the driver no longer infers untyped parameter types (as SQL Server Native Client 11 did), which rejected optional/unassigned columns — now bound safely
- New `KittoX_Oracle.md` documenting the full Oracle setup; a note in every `UseKitto.pas` clarifies that the client/server FireDAC/DBExpress drivers require Delphi Enterprise/Architect (Professional ships only local/embedded drivers)

### Routing (attribute-based refactor complete)
- The whole `kx/*` request surface is now **attribute-routed**: after the auth family in 4.0.9, this release migrates the entire **view domain** (`view`, `data`, `form`, `save`, `delete`) and **all ancillary endpoints** (`lookup`, `tool`, `blob`, `upload`, `notify`, master-detail `detail/{i}/data|save|delete`, `wizard-finish`) into typed handlers running under a single shared request-filter chain (error → JWT auth → navigation guard → authorization)
- Legacy `TKWebApplication.DoHandleRequest` now serves **only** the Home page (`/`); **zero** `IsKX*Request` matchers remain (down from ~24) — the monolithic dispatcher is gone
- New **`TKXResourceRegistry.RegisterOverride`** API: an application can subclass a framework handler and override a single endpoint or hook (e.g. a custom `save`) **without forking** the whole route — register the subclass and it replaces the default for its base path

### Security
- **Navigation guard**: direct browser navigation to an internal `kx/*` fragment endpoint (e.g. pasting `.../kx/view/SomeChart` in the address bar) is now **rejected and redirected** to login / home. Only in-app HTMX requests are served the partial; typing a fragment URL no longer leaks a bare HTML partial (when logged in) nor returns a bald `404` (when not)

### Master-Detail & Forms
- **`{MasterRecord.*}` macros now resolve in detail-form lookup filters**: the detail store is linked to the session master record, so dependent lookups populate correctly instead of coming up empty
- **Dedicated lookup grids apply the calling field's `LookupFilter`** (including `{MasterRecord.*}`), with search/paging state preserved
- **Detail-record rules fire on save**: `HandleDetailSave` now applies each field's `AfterFieldChange` rules (calculated fields — avoids NOT NULL violations) and `ApplyBeforeRules` (rules that roll detail values up into the master, e.g. totals)
- **Reference caption & AutoAddFields resolve on newly-added in-memory records**: the derived-values cascade (previously skipped because populate runs with notifications off) now runs via `RefreshDerivedReferenceValues`, so a reference column is filled immediately instead of staying blank until reloaded from the DB

### UI
- **Mobile dashboard fix**: cards in a maximized-dialog dashboard (`Controller: Dashboard` / FlexPanel) no longer overflow the screen width and the panel now scrolls vertically, so cards below the fold are reachable

### Documentation
- Framework **public-API XMLDoc coverage raised from ~32% to ~74%**, spanning the routing namespace, the in-memory store, the metadata system, the web engine/server, the HTML<sup>x</sup> controllers, `EF.DB`, the config/rules/SQL core, the tool controllers and the third-party integration shims — surfaced in KIDE<sup>x</sup> through `[YamlNode]` descriptions

## 06 Jul 2026: ver. 4.0.9 Beta

### Bug fixes
- **Double URL-decode of request values** — form/query values were URL-decoded twice (a second decode over already-decoded text), silently corrupting any value containing `%`, `+` or (on some RTL versions) `?`: passwords (login failing), saved form fields (e.g. `50%`, `C++`), search/filter terms and record keys. Values are now decoded exactly once

### Routing
- The authentication family (`kx/login`, `kx/logout`, `kx/resetpassword`, `kx/changepassword`) migrated to the **attribute-based router** — first core group to "bring its own routing" (the login page is still served by `Home()` at `/`, unchanged)
- Attribute-routed requests now run inside the full per-request context (authenticator, macro engine, and — for `Auth: JWT` — a session hydrated from the verified token)

### Tooling
- `Examples/build_Examples.cmd` now accepts command-line arguments to build a single example / deploy mode / config, e.g. `build_Examples.cmd TasKitto Desktop Debug` (the interactive menu is kept when run with no arguments)

## 08 Jun 2026: ver. 4.0.8 Beta

### Theming
- **User-selectable theme**: set `Theme/UserSelection: True` and drop a `Controller: ThemeSwitcher` anywhere in the GUI — the end user picks Light / Auto / Dark live, persisted per-app in `localStorage`, FOUC-safe boot, no page reload
- **`Theme` is now a structured config block** discoverable by KIDE<sup>x</sup>: `Theme/Mode` (Auto/Light/Dark), shared font/icon settings, and per-mode `Light:`/`Dark:` palettes (each with its own `Primary-Color`) — replaces the old flat `Theme: <mode>` value (existing configs still load)

### Login
- Full-width footer and side-panel layout refinements; optional per-section theme switcher

### KIDE<sup>x</sup>
- Boolean `[YamlNode]` defaults now carry the inverse of the runtime default, so the "Add node" menu writes the meaningful value instead of a no-op

### MCP-KittoX
- Many new tools added — full CRUD on Models / Views / Layouts, database introspection (connections, tables, columns), config read/update, locale (`.po`) reading, metadata validation, and grid/list view scaffolding (40+ tools total, up from 16)

## 18 May 2026: ver. 4.0.7 Beta

- `Controller/AutoOpen` and `Controller/PagingTools` based on model's `IsLarge` flag
- A Reference field whose target Model has `IsLarge: True` renders as a searchable lookup popup

### JWT / ACL hardening
- `Auth: JWT` no longer emits the legacy `<AppName>` session-id cookie nor `kx_db` — the JWT `sid` and `db` claims carry the same info
- Server-side ACL enforcement on every `HandleKX*` route (view/data/save/delete/form/lookup/blob/upload/tool/detail*/wizard)
- New auth gate in `DoHandleRequest` returns 404 on protected routes for unauthenticated requests (public views excluded)
- Toolbar Add/Edit/Delete/Dup stay `disabled` for ACL-denied users
- Per-thread JWT context cache uses `TObjectDictionary<TThreadID, ...>`

### IDE / wizard
- New **RAD Studio IDE plugin gallery**: `KittoXIDE.bpl` registers 4 entries under **File > New > Other > KittoX Projects** (Standalone .exe / Desktop .exe / ISAPI .dll / Apache .dll)
- **Three paths** to scaffold a new app: KIDEX standalone, the new IDE gallery, and `MCP-KittoX project_create_app`
- New project default: `Auth: TextFile` with a ready-to-use `Home/FileAuthenticator.txt` (admin/admin demo accounts) so the generated app authenticates out of the box, no users table required. JWT envelope kept as default. `AccessControl` default switched to `Null` to avoid deny-all post-login on a brand-new project. `DB.FD.yaml` template now sets `ODBCAdvanced: TrustServerCertificate=yes` so SQL Server ODBC Driver 17/18 connects on first try
- Model Wizard `Beautify names` option now also handles DB names with spaces (Northwind-style: `Quarterly Orders` → `QuarterlyOrders`, `Sales by Category` → `SalesByCategory`); the original name is preserved in `PhysicalName` for the SQL layer
- Model Wizard — new editable **`DisplayLabel`** and **`Hint`** fields on every Add/Update Field action: auto-populated from the database's native column comment when present (MSSQL `MS_Description`, PostgreSQL `pg_description`, Firebird `RDB$DESCRIPTION`, MySQL `COLUMN_COMMENT`, Oracle `USER_COL_COMMENTS`), fully editable before Apply
- Action "New TreeView..." on the Views folder is now **idempotent**: pointing it at an existing `MainMenu.yaml` merges the Models that aren't yet referenced under the `Folder: Menu` block, preserving every hand-edited entry, instead of raising a duplicate-object error

### MCP-KittoX
- New tool **`models_create_from_db`** — the headless equivalent of the Model Wizard. AI agents can reverse-engineer Models from a database connection conversationally: defaults to `dry_run: true` (preview only); pass `dry_run: false` to commit. Output is byte-identical to what the visual wizard writes. `DisplayLabel` auto-populated from the database's native column comments; optional `field_descriptions` array lets the agent inject labels from a non-DB source (CSV, glossary, prior YAML) with per-property override precedence
- New tools **`models_list` / `models_read` / `views_list` / `views_read` / `resources_list` / `resources_read`** — enumerate and read project metadata and static resources headlessly
- New tool **`menu_generate_main_menu`** — create or refresh `MainMenu.yaml` with one entry per Model under a top-level `Folder: Menu`; idempotent (existing entries preserved, only missing Models appended)
- **Database column comments** are now auto-fetched for all 5 supported engines (MSSQL, PostgreSQL, Firebird, MySQL, Oracle) and flow into both the KIDEX wizard and the MCP tool
- 16 tools now implemented (was 9)
- Better error reporting from MCP tools: errors are now propagated verbatim to the JSON-RPC client (class name + message) instead of being replaced by a generic fallback

### Setup / tooling
- Setup installer ships `MCPKittoX.exe` alongside `KIDEX.exe` sharing OnGuard license
- `Tools/SetVersion.ps1` now also bumps the 12 dprojs of the 3 official examples (HelloKitto, TasKitto, KEmployee — 4 deployment variants each), and inserts `<VerInfo_Release>` and other VerInfo tags when the .dproj has them stripped (Delphi removes VerInfo tags whose value is 0)

## 01 May 2026: ver. 4.0.6 Beta
- New `Auth: JWT` wrapper authenticator (signed `kx_token` cookie, sliding expiration, programmatic key registration)
- New `AccessControl: JWT` reading grants from `kx_acl` claim snapshotted at login, with optional DB fallback
- Updated examples to JWT Auth (TasKitto / HelloKitto / KEmployee)
- Updated TasKitto example with three-tier ACL (`admin` / `user` / `viewer`)
- Multi-database support on TasKitto and HelloKitto: SQL Server / PostgreSQL / Firebird
- Cross-dialect macros: `%DB.TRUE%` / `%DB.FALSE%`, `%DB.DATEDIFF`, `%DB.DATETIME_FROM`
- Login form with optional "Environment" combo for multi-database apps (`Auth/DatabaseChoices`)
- Native boolean types on the three sample DBs (`BIT` / `BOOLEAN`); Firebird setup is now SQL-script-only
- Firebird Activity Dashboard views translated from the SQL Server originals
- TasKitto SQL Server DDL split (tables / views in separate scripts because of T-SQL batch rules)
- New `Tools/SetVersion.ps1`: one-shot version bump across constant, dproj, README and Inno Setup
- New `Projects/BuildAllPackagesD{10_4,11,12,13}.ps1` wrappers: rebuild Core + Enterprise per Delphi version
- YAML metadata files included in every `.dproj` (visible in Project Manager, KIDEX highlighting)
- `EF.Logger.TextFile` active out-of-the-box for the standalone Indy hosts

## 23 Apr 2026: ver. 4.0.5 Beta

- Architectural refactor: DB connection ownership unified in `TKConfig`
- New API `TKConfig.DatabaseFor(Name)` and `TKConfig.CreateStandaloneDBConnection(Name)`
- `CreateDBConnection` moved from `public` to `protected`
- `ClearDatabase` / `DestroyInstance` now clear both `FDatabase` and `FDatabases`
- New `InDBConnection` / `InDBTransaction` helpers

## 22 Apr 2026: ver. 4.0.4 Beta
- Manual column resize in grids
- Tooltip on truncated grid cells (only when actually truncated)
- Fix: in-memory lookup popup closing on resize
- Tooltip on TreePanel menu nodes
- Multi-column sort in grids
- Multi-page form validation
- Edit-mode accent border for combobox and other non-text-editable fields
- SunEditor readonly rendering
- Checkbox styled like other form inputs
- DetailTables Style (Tabs/Bottom/Popup)
- Added CSS `.disabled` class

## 23 Apr 2026: ver. 4.0.3 Beta
- Editing-mode field borders
- Form toolbar anchoring
- DateTime field fixes
- Fixed KittoEmailSenderSrvc
- Grid keyboard navigation
- SunEditor theming and resize
- Dialog focus
- DetailTables Style (Tabs/Bottom/Popup)
- ExportExcel / ExportFlexCel
- Fixed Date/time filters SQL conversion
- Date/time filter trigger
- Error dialog consistency
- `Controller: Window` restored backward-compatibility

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
