/*!
  kxtabs.js — part of KittoX. Copyright 2012-2026 Ethea S.r.l.
  Licensed under the Apache License, Version 2.0 — http://www.apache.org/licenses/LICENSE-2.0
*/
/**
 * kxTabs — Client-side dynamic tab management for KittoX.
 * Handles tab creation, activation, closing, HTMX content loading,
 * and horizontal scroll when tabs overflow.
 */
if (typeof KX_CLOSE_ICON === 'undefined') var KX_CLOSE_ICON = '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" fill="currentColor" viewBox="0 0 16 16"><path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8z"/></svg>';

var kxTabs = {
  _scrollStep: 150,

  /** Returns the tab strip container (buttons live here). */
  _strip: function() {
    return document.getElementById('kx-tab-strip');
  },

  /**
   * Check if tabs overflow and show/hide scroll buttons accordingly.
   * Called after open, close, and on window resize.
   */
  checkOverflow: function() {
    var header = document.getElementById('kx-tab-header-bar');
    var strip = this._strip();
    if (!header || !strip) return;
    if (strip.scrollWidth > strip.clientWidth) {
      header.classList.add('kx-tab-overflow');
    } else {
      header.classList.remove('kx-tab-overflow');
    }
  },

  /** Scroll the tab strip to the left. */
  scrollLeft: function() {
    var strip = this._strip();
    if (strip) strip.scrollBy({left: -this._scrollStep, behavior: 'smooth'});
  },

  /** Scroll the tab strip to the right. */
  scrollRight: function() {
    var strip = this._strip();
    if (strip) strip.scrollBy({left: this._scrollStep, behavior: 'smooth'});
  },

  /** Scroll to make the given button visible in the strip. */
  _scrollIntoView: function(btn) {
    var strip = this._strip();
    if (!strip || !btn) return;
    var sl = strip.scrollLeft;
    var sw = strip.clientWidth;
    var bl = btn.offsetLeft;
    var bw = btn.offsetWidth;
    if (bl < sl) {
      strip.scrollTo({left: bl, behavior: 'smooth'});
    } else if (bl + bw > sl + sw) {
      strip.scrollTo({left: bl + bw - sw, behavior: 'smooth'});
    }
  },

  /**
   * Open a tab for the given view. If the tab already exists, activate it.
   * Otherwise create a new tab button + pane, then fetch content via htmx.
   */
  open: function(viewName, label, iconHtml) {
    var existing = document.querySelector('.kx-tab-button[data-view="' + viewName + '"]');
    if (existing) { this.activate(viewName); return; }

    var strip = this._strip();
    var content = document.getElementById('kx-center-tabs');
    if (!strip || !content) return;

    // Remove empty-state placeholder if present
    var empty = content.querySelector('.kx-tab-empty');
    if (empty) empty.remove();

    // Create tab button
    var btn = document.createElement('button');
    btn.className = 'kx-tab-button';
    btn.setAttribute('data-view', viewName);
    btn.onclick = function() { kxTabs.activate(viewName); };
    var closeSpan = document.createElement('span');
    closeSpan.className = 'kx-tab-close';
    closeSpan.innerHTML = KX_CLOSE_ICON;
    closeSpan.onclick = function(e) { e.stopPropagation(); kxTabs.close(viewName); };
    btn.innerHTML = (iconHtml || '') + label;
    btn.appendChild(closeSpan);
    strip.appendChild(btn);

    // Create tab pane with loading indicator
    var pane = document.createElement('div');
    pane.className = 'kx-tab-pane';
    pane.id = 'kx-tab-pane-' + viewName;
    pane.style.display = 'none';
    pane.innerHTML = '';
    content.appendChild(pane);

    this.activate(viewName);
    this.checkOverflow();

    // Fetch content via HTMX; detect dialog overlays and move them to body
    var self = this;
    pane.addEventListener('htmx:afterSettle', function() {
      var overlay = pane.querySelector('.kx-dialog-overlay');
      if (overlay) {
        document.body.appendChild(overlay);
        self.close(viewName);
      }
    }, {once: true});
    htmx.ajax('GET', 'kx/view/' + viewName, {target: pane, swap: 'innerHTML'});
  },

  /** Activate the tab for the given view (deactivate all others). */
  activate: function(viewName) {
    var buttons = document.querySelectorAll('.kx-tab-button');
    buttons.forEach(function(b) { b.classList.remove('kx-tab-active'); });
    var panes = document.querySelectorAll('.kx-tab-pane');
    panes.forEach(function(p) { p.style.display = 'none'; });
    var activeBtn = document.querySelector('.kx-tab-button[data-view="' + viewName + '"]');
    if (activeBtn) {
      activeBtn.classList.add('kx-tab-active');
      this._scrollIntoView(activeBtn);
    }
    var activePane = document.getElementById('kx-tab-pane-' + viewName);
    if (activePane) {
      activePane.style.display = '';
      // Lazy-load content for SubView tabs that haven't been loaded yet
      if (activePane.hasAttribute('data-kx-lazy')) {
        activePane.removeAttribute('data-kx-lazy');
        htmx.ajax('GET', 'kx/view/' + viewName, {target: activePane, swap: 'innerHTML'});
      }
    }
  },

  /** Close the tab for the given view. Activates an adjacent tab if the closed one was active. */
  close: function(viewName) {
    var btn = document.querySelector('.kx-tab-button[data-view="' + viewName + '"]');
    var pane = document.getElementById('kx-tab-pane-' + viewName);
    var wasActive = btn && btn.classList.contains('kx-tab-active');
    var nextView = null;
    if (wasActive && btn) {
      var sibling = btn.previousElementSibling || btn.nextElementSibling;
      if (sibling && sibling.classList.contains('kx-tab-button'))
        nextView = sibling.getAttribute('data-view');
    }
    if (btn) btn.remove();
    if (pane) pane.remove();
    // Clean up Chart.js instance if this tab had a chart
    if (typeof kxChart !== 'undefined') kxChart.destroy(viewName);
    // Notify server to release session store (fire-and-forget)
    fetch('kx/view/' + viewName + '/form-close', {
      method: 'POST', headers: { 'X-KittoX': 'true' }
    }).catch(function() {});
    if (nextView) {
      this.activate(nextView);
    } else {
      var remaining = document.querySelectorAll('.kx-tab-button');
      if (remaining.length === 0) {
        var content = document.getElementById('kx-center-tabs');
        if (content) content.innerHTML = '';
      }
    }
    this.checkOverflow();
  },

  /** Called from tree menu links. Reads data-view/data-label and icon from the clicked element. */
  openFromMenu: function(el) {
    var viewName = el.getAttribute('data-view');
    var label = el.getAttribute('data-tab-label') || el.getAttribute('data-label') || viewName;
    var iconEl = el.querySelector('.kx-icon, .kx-icon-img');
    var iconHtml = iconEl ? iconEl.outerHTML : '';
    this.open(viewName, label, iconHtml);
  }
};

// Re-check overflow on window resize and initial load
window.addEventListener('resize', function() { kxTabs.checkOverflow(); });
document.addEventListener('DOMContentLoaded', function() { kxTabs.checkOverflow(); });
