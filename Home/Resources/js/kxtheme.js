/*!
  kxtheme.js — part of KittoX. Copyright 2012-2026 Ethea S.r.l.
  Licensed under the Apache License, Version 2.0 — http://www.apache.org/licenses/LICENSE-2.0
*/
// kxtheme.js — user-selectable theme (Light / Dark / Auto) with localStorage
// persistence keyed per KittoX application. Companion of the inline boot
// script emitted in <head> by TKWebApplication.RenderHTMLHead which runs
// FIRST, before CSS paints, to avoid theme flash (FOUC).
//
// Public API:
//   kxTheme.get(appName)          → 'light' | 'dark' | 'auto'
//   kxTheme.set(appName, mode)    → persists + applies; dispatches 'kx-theme-changed'
//   kxTheme.init(appName)         → re-applies the saved value (idempotent)
//
// Storage key: 'kx_theme:<AppName>' — per-app scope so two KittoX apps in
// the same browser keep independent preferences.
(function (g) {
  'use strict';

  function storageKey(appName) {
    return 'kx_theme:' + (appName || '_default');
  }

  function applyAttr(mode) {
    var h = document.documentElement;
    if (mode === 'light' || mode === 'dark') {
      h.setAttribute('data-theme', mode);
    } else {
      // 'auto' or any unknown value → remove attribute and let the CSS
      // @media(prefers-color-scheme:dark) rule pick the OS preference.
      h.removeAttribute('data-theme');
    }
  }

  function normalize(mode) {
    return (mode === 'light' || mode === 'dark') ? mode : 'auto';
  }

  g.kxTheme = {
    get: function (appName) {
      try { return normalize(localStorage.getItem(storageKey(appName))); }
      catch (e) { return 'auto'; }
    },

    set: function (appName, mode) {
      mode = normalize(mode);
      try {
        if (mode === 'auto') localStorage.removeItem(storageKey(appName));
        else localStorage.setItem(storageKey(appName), mode);
      } catch (e) { /* private browsing / quota — apply DOM anyway */ }
      applyAttr(mode);
      // Notify listeners (e.g. icons that toggle "active" state).
      var ev = new CustomEvent('kx-theme-changed', {
        detail: { mode: mode, appName: appName }
      });
      g.dispatchEvent(ev);
    },

    init: function (appName) {
      applyAttr(this.get(appName));
    }
  };
})(window);
