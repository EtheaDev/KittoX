/*!
 * kxlang.js — KittoX interface-language switcher
 * Copyright 2012-2026 Ethea S.r.l. — Apache License 2.0
 *
 * Companion of the LanguageSwitcher controller (Kitto.Html.LanguageSwitcher).
 * The flag dropdown's options call kxLang.set('<code>'), which posts to the
 * anonymous endpoint kx/setlang/<code> and, on success, reloads the current
 * page so the whole UI (login or home) re-renders in the chosen language via
 * the per-session gettext instance.
 *
 * Language is a SERVER-side per-session setting (unlike the theme, which is a
 * client-side localStorage preference), hence the round-trip + reload.
 */
(function (g) {
  'use strict';

  function reportError(onRetry) {
    // Surface the same [Retry]/[Reset] dialog other user-initiated actions use
    // when it is available; otherwise fall back to a plain reload attempt.
    if (typeof g.kxReportRequestError === 'function') {
      g.kxReportRequestError(undefined, onRetry);
    }
  }

  // The flag dropdown is a native <details>: it opens and closes on its own
  // summary, but nothing else closes it. Close every open switcher when the
  // user clicks (or taps) anywhere outside it, or presses Escape.
  function closeOpenSwitchers(except) {
    document.querySelectorAll('details.kx-lang-switcher[open]').forEach(function (d) {
      if (d !== except) { d.removeAttribute('open'); }
    });
  }
  document.addEventListener('pointerdown', function (ev) {
    var inside = ev.target && ev.target.closest ? ev.target.closest('details.kx-lang-switcher') : null;
    closeOpenSwitchers(inside);
  }, true);
  document.addEventListener('keydown', function (ev) {
    if (ev.key === 'Escape') { closeOpenSwitchers(null); }
  });

  g.kxLang = {
    // code: a language id offered by the switcher ('it','en','de','es','pt',...)
    set: function (code) {
      if (!code) { return; }
      fetch('kx/setlang/' + encodeURIComponent(code), {
        method: 'POST',
        headers: { 'X-KittoX': 'true' },
        credentials: 'same-origin'
      })
        .then(function (r) {
          if (!r.ok) { reportError(function () { g.kxLang.set(code); }); return; }
          // Re-render everything in the new language.
          g.location.reload();
        })
        .catch(function () { reportError(function () { g.kxLang.set(code); }); });
    }
  };
})(window);
