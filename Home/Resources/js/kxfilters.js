/*!
  kxfilters.js — part of KittoX. Copyright 2012-2026 Ethea S.r.l.
  Licensed under the Apache License, Version 2.0 — http://www.apache.org/licenses/LICENSE-2.0
*/
/**
 * KittoX ButtonList filter toggle support.
 * Manages toggle buttons that update a hidden input with comma-separated
 * selected keys, then triggers an HTMX change event for live filtering.
 */
function kxFilterBtn(btn) {
  var container = btn.closest('.kx-filter-buttonlist');
  var isSingle = container.dataset.single === 'true';

  if (isSingle) {
    // Single-select: deactivate all others first
    container.querySelectorAll('.kx-filter-btn.kx-active').forEach(function(b) {
      if (b !== btn) b.classList.remove('kx-active');
    });
  }
  btn.classList.toggle('kx-active');

  // Collect selected keys
  var keys = [];
  container.querySelectorAll('.kx-filter-btn.kx-active').forEach(function(b) {
    keys.push(b.dataset.key);
  });

  // Update the hidden input (next sibling of the button container)
  var input = container.nextElementSibling;
  if (input && input.name && input.name.indexOf('f_') === 0) {
    input.value = keys.join(',');
    input.dispatchEvent(new Event('change', {bubbles: true}));
  }
}
