/**
 * kxTiles — Client-side embedded tab management for KittoX TilePanel.
 * Handles view opening in tabs, tab lifecycle, and toggle between
 * tile grid (home) and tab content.
 * The tab header is always visible; tile box and tab content toggle.
 * Reuses kx-tab-* CSS classes from TabPanel; selectors scoped by ID
 * (kx-tile-tab-strip, kx-tile-tab-content) to avoid conflicts.
 */
if (typeof KX_CLOSE_ICON === 'undefined') var KX_CLOSE_ICON = '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" fill="currentColor" viewBox="0 0 16 16"><path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8z"/></svg>';

var kxTiles = {

  /** Show the tile box, hide tab content, mark home button active. */
  showHome: function() {
    var box = document.getElementById('kx-tile-pages');
    var content = document.getElementById('kx-tile-tab-content');
    if (box) box.style.display = '';
    if (content) content.style.display = 'none';

    // Deactivate all view tab buttons, activate home button
    var strip = document.getElementById('kx-tile-tab-strip');
    if (strip) strip.querySelectorAll('.kx-tab-button').forEach(function(b) {
      b.classList.remove('kx-tab-active');
    });
    var content2 = document.getElementById('kx-tile-tab-content');
    if (content2) content2.querySelectorAll('.kx-tab-pane').forEach(function(p) {
      p.style.display = 'none';
    });
    var homeBtn = document.querySelector('.kx-tile-home-btn');
    if (homeBtn) homeBtn.classList.add('kx-tab-active');
  },

  /**
   * Open a view from a tile click. Reads data-view and data-label from the element.
   * Hides tile box, shows tab content, creates a tab if needed.
   */
  openView: function(el) {
    var viewName = el.getAttribute('data-view');
    var label = el.getAttribute('data-label') || viewName;
    if (!viewName) return;

    // Check if tab already exists (scoped to our strip)
    var strip = document.getElementById('kx-tile-tab-strip');
    var existing = strip ? strip.querySelector('.kx-tab-button[data-view="' + viewName + '"]') : null;
    if (existing) {
      this._showTabs();
      this.activateTab(viewName);
      return;
    }

    this._showTabs();

    var content = document.getElementById('kx-tile-tab-content');
    if (!strip || !content) return;

    // Create tab button (same classes as normal TabPanel)
    var btn = document.createElement('button');
    btn.className = 'kx-tab-button';
    btn.setAttribute('data-view', viewName);
    btn.onclick = function() { kxTiles.activateTab(viewName); };
    var closeSpan = document.createElement('span');
    closeSpan.className = 'kx-tab-close';
    closeSpan.innerHTML = KX_CLOSE_ICON;
    closeSpan.onclick = function(e) { e.stopPropagation(); kxTiles.closeTab(viewName); };
    btn.innerHTML = label;
    btn.appendChild(closeSpan);
    strip.appendChild(btn);

    // Create tab pane
    var pane = document.createElement('div');
    pane.className = 'kx-tab-pane';
    pane.id = 'kx-tile-pane-' + viewName;
    pane.style.display = 'none';
    content.appendChild(pane);

    this.activateTab(viewName);

    // Fetch content via HTMX; detect dialog overlays and move them to body
    var self = this;
    pane.addEventListener('htmx:afterSettle', function() {
      var overlay = pane.querySelector('.kx-dialog-overlay');
      if (overlay) {
        document.body.appendChild(overlay);
        self.closeTab(viewName);
      }
    }, {once: true});
    htmx.ajax('GET', 'kx/view/' + viewName, {target: pane, swap: 'innerHTML'});
  },

  /** Activate a specific tab (deactivate all others, deactivate home). */
  activateTab: function(viewName) {
    // Ensure tab content is visible and tile box is hidden
    this._showTabs();

    // Deactivate all view tab buttons (scoped to our strip)
    var strip = document.getElementById('kx-tile-tab-strip');
    if (strip) strip.querySelectorAll('.kx-tab-button').forEach(function(b) {
      b.classList.remove('kx-tab-active');
    });
    var content = document.getElementById('kx-tile-tab-content');
    if (content) content.querySelectorAll('.kx-tab-pane').forEach(function(p) {
      p.style.display = 'none';
    });

    var activeBtn = strip ? strip.querySelector('.kx-tab-button[data-view="' + viewName + '"]') : null;
    if (activeBtn) activeBtn.classList.add('kx-tab-active');
    var activePane = document.getElementById('kx-tile-pane-' + viewName);
    if (activePane) activePane.style.display = '';
  },

  /** Close a tab. If no tabs remain, return to tile home. */
  closeTab: function(viewName) {
    var strip = document.getElementById('kx-tile-tab-strip');
    var btn = strip ? strip.querySelector('.kx-tab-button[data-view="' + viewName + '"]') : null;
    var pane = document.getElementById('kx-tile-pane-' + viewName);
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

    if (nextView) {
      this.activateTab(nextView);
    } else {
      var remaining = strip ? strip.querySelectorAll('.kx-tab-button') : [];
      if (remaining.length === 0) {
        this.showHome();
      }
    }
  },

  /** Internal: hide tile box, show tab content, deactivate home button. */
  _showTabs: function() {
    var wrapper = document.getElementById('kx-tile-tab-wrapper');
    var box = document.getElementById('kx-tile-pages');
    var content = document.getElementById('kx-tile-tab-content');
    if (wrapper) wrapper.style.display = '';
    if (box) box.style.display = 'none';
    if (content) content.style.display = '';
    var homeBtn = document.querySelector('.kx-tile-home-btn');
    if (homeBtn) homeBtn.classList.remove('kx-tab-active');
  }
};
