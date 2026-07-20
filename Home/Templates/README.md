<!--
  Copyright 2012-2026 Ethea S.r.l. — Licensed under the Apache License, Version 2.0.
  http://www.apache.org/licenses/LICENSE-2.0
-->
# KittoX HTML templates

This folder holds the **structural templates** of KittoX: the HTML that *frames*
a page — the page skeleton, the border layout, the tab container, the tree menu,
the status bar and the login dialog. They are rendered server-side with
**TemplatePro**; the Delphi controllers fill them with data.

> The data-heavy HTML (grid rows/cells, form fields) is **not** here — it is
> still generated in Delphi. Only the page structure (the frame) is templated.

## The templates

| File | Controller type | Rendered by | Injected variables |
|------|-----------------|-------------|--------------------|
| `_Page.html` | *(page)* | `TKWebApplication.ServeHomePage` | `lang`, `charset`, `appTitle`, `bodyClass`, `ajaxTimeout`, `resPath`, `themeAttr$`, `themeBoot$`, `themeStyle$`, `iconLink$`, `dynamicStyles$`, `dynamicScripts$`, `homeContent$`, `msg*`/`btn*` |
| `BorderPanel.html` | `BorderPanel` | `TKXBorderPanelController` | `htmlId`, `north/west/center/east/southContent$` |
| `TabPanel.html` | `TabPanel` | `TKXTabPanelController` | `htmlId`, `tabHeaderHtml$`, `tabBodies$` |
| `TreePanel.html` | `TreePanel` | `TKXTreePanelController` | `htmlId`, `title`, `treeContent$` |
| `StatusBar.html` | `StatusBar` | `TKXStatusBarController` | `htmlId`, `iconHtml$`, `text$` |
| `Login.html` | `Login` | `TKXLoginController` | `htmlId`, `title`, `dialogStyle$`, region contents `$`, `fieldsContent$`, `linksContent$`, `loginIconHtml$`, `buttonStyleAttr$`, `loginLabel`, `loggingInLabel`, `scriptContent$` |

Each template carries a self-contained header (a `{{# … #}}` comment) that lists
its own variables — open the file to see the authoritative contract.

## Syntax (TemplatePro)

| Token | Meaning |
|-------|---------|
| `{{:name}}` | insert value, **HTML-escaped** |
| `{{:name$}}` | insert value as **raw HTML** (already-rendered markup) |
| `{{if name}}…{{endif}}` | conditional block |
| `{{# … #}}` | **comment**, stripped at compile time (never sent to the browser) |

The `$` suffix marks a variable that already contains HTML (e.g. a rendered
child region); everything else is escaped. This is why the copyright/contract
header uses `{{# #}}`: it disappears from the output.

## Overriding a template

The engine (`TKXTemplateEngine.FindTemplatePath`) resolves a template with a
**3-level lookup — first match wins**:

1. `‹App›/Home/Metadata/Views/Templates/‹ViewName›.html` — per **view** override
2. `‹App›/Home/Templates/‹ControllerType›.html` — per **application** override
3. `‹Kitto›/Home/Templates/‹ControllerType›.html` — the **system default** (this folder)

To customize, **copy** the system default into your application's
`Home/Templates` (level 2) or, for a single view, into
`Home/Metadata/Views/Templates` (level 1), and edit the copy. Keep the same file
name. Preserve the variables and the CSS classes / element ids the companion
`kx*.js` relies on (e.g. `kx-login-status`, `kx-center-tabs`), otherwise the
client-side behavior breaks.

### Notes

- **Do not** put these templates under `Home/Resources`: that folder is served
  statically over HTTP (`/res/*`). Templates live in `Home/Templates`, which is
  **not** web-servable — server-side only.
- **Fallback**: if no override exists, the system default is used, so an app ships
  and runs with zero template files.
- **Upgrade drift**: an override is a *frozen copy*. When a KittoX release improves
  the default template (new features, fixes, HTMX API changes), your copy will not
  receive them automatically — re-diff your overrides against the new defaults on
  upgrade.
