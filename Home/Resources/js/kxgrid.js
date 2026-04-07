/**
 * kxGrid — Row selection and CRUD action helpers for KittoX List controller.
 * Manages row selection state, button enable/disable, and delete confirmation.
 */
var KX_CLOSE_ICON = '<svg xmlns="http://www.w3.org/2000/svg" width="1.2em" height="1.2em" fill="currentColor" viewBox="0 0 16 16"><path d="M2.146 2.854a.5.5 0 1 1 .708-.708L8 7.293l5.146-5.147a.5.5 0 0 1 .708.708L8.707 8l5.147 5.146a.5.5 0 0 1-.708.708L8 8.707l-5.146 5.147a.5.5 0 0 1-.708-.708L7.293 8z"/></svg>';

/**
 * kxApp — Central application-level helpers.
 * Provides a single entry point for opening views from menus (TreePanel, TilePanel).
 * The view decides how to display itself; the menu only requests the open.
 */
var kxApp = {
  /**
   * Opens a view from a menu item. Decides how to display based on context:
   * - Desktop with central TabPanel: opens in a tab (via kxTabs)
   * - Mobile or no TabPanel: appends to body as dialog overlay (CSS forces fullscreen on mobile)
   * @param {HTMLElement} el - The menu element with data-view and data-label attributes.
   */
  openView: function(el) {
    var viewName = el.getAttribute('data-view');
    var label = el.getAttribute('data-label') || viewName;
    // Desktop: if a central TabPanel exists, open in a tab
    if (document.getElementById('kx-center-tabs')) {
      if (typeof kxTabs !== 'undefined') {
        var iconEl = el.querySelector('.kx-icon, .kx-icon-img');
        var iconHtml = iconEl ? iconEl.outerHTML : '';
        kxTabs.open(viewName, label, iconHtml);
      }
    } else {
      // Mobile or no TabPanel: fetch and append to body.
      // Server renders as dialog overlay; body.kx-mobile CSS forces fullscreen.
      htmx.ajax('GET', 'kx/view/' + viewName, {target: 'body', swap: 'beforeend'});
    }
  }
};

/**
 * Makes a .kx-msgbox-dialog draggable by its .kx-msgbox-header.
 * @param {HTMLElement} dialog - The .kx-msgbox-dialog element.
 */
function kxMakeDraggable(dialog) {
  var header = dialog.querySelector('.kx-msgbox-header');
  if (!header || dialog.dataset.draggable) return;
  dialog.dataset.draggable = '1';
  var startX, startY, origLeft, origTop;
  header.addEventListener('mousedown', function(e) {
    if (e.target.closest('button')) return;
    e.preventDefault();
    var rect = dialog.getBoundingClientRect();
    // Switch from flex-centered to absolute positioning on first drag
    if (!dialog.style.left) {
      dialog.style.position = 'absolute';
      dialog.style.left = rect.left + 'px';
      dialog.style.top = rect.top + 'px';
      dialog.style.margin = '0';
    }
    startX = e.clientX;
    startY = e.clientY;
    origLeft = parseInt(dialog.style.left, 10);
    origTop = parseInt(dialog.style.top, 10);
    function onMove(ev) {
      dialog.style.left = (origLeft + ev.clientX - startX) + 'px';
      dialog.style.top = (origTop + ev.clientY - startY) + 'px';
    }
    function onUp() {
      document.removeEventListener('mousemove', onMove);
      document.removeEventListener('mouseup', onUp);
    }
    document.addEventListener('mousemove', onMove);
    document.addEventListener('mouseup', onUp);
  });
}

// Auto-enable drag on server-injected msgbox dialogs (e.g. error responses via HTMX).
// Deferred to DOMContentLoaded because kxgrid.js loads in <head> before body exists.
document.addEventListener('DOMContentLoaded', function() {
  new MutationObserver(function(mutations) {
    mutations.forEach(function(m) {
      m.addedNodes.forEach(function(node) {
        if (node.nodeType === 1 && node.querySelector) {
          var dlg = node.classList && node.classList.contains('kx-msgbox-dialog')
            ? node : node.querySelector('.kx-msgbox-dialog');
          if (dlg) kxMakeDraggable(dlg);
        }
      });
    });
  }).observe(document.body, { childList: true, subtree: true });
});

/**
 * Wrapper around fetch() that applies the HTMX-configured timeout via AbortController.
 * On timeout, shows a Retry/Reset dialog. Retry re-issues the same request and
 * feeds the result back into the original promise chain transparently.
 */
function kxFetchWithTimeout(url, options) {
  var timeout = (typeof htmx !== 'undefined' && htmx.config.timeout) || 100000;
  var controller = new AbortController();
  var timeoutId = setTimeout(function() { controller.abort(); }, timeout);
  var fetchOpts = Object.assign({}, options || {}, { signal: controller.signal });
  return fetch(url, fetchOpts)
    .then(function(response) {
      clearTimeout(timeoutId);
      return response;
    })
    .catch(function(err) {
      clearTimeout(timeoutId);
      if (err.name === 'AbortError') {
        return new Promise(function(resolve, reject) {
          var S = window.KX_STRINGS || {};
          kxGrid.showConfirm(
            S.errorTitle || 'Error',
            S.serverNotResponding || 'Server is not responding',
            S.retry || 'Retry',
            S.reset || 'Reset',
            function() { kxFetchWithTimeout(url, options).then(resolve, reject); },
            function() { window.location.reload(); }
          );
        });
      }
      throw err;
    });
}

/**
 * Draggable dialog support — event delegation on document.
 * Drag starts on mousedown on .kx-dialog-header, moves the .kx-dialog via
 * absolute positioning within the .kx-dialog-overlay.
 */
(function() {
  var drag = null; // { dlg, startX, startY, origX, origY }

  document.addEventListener('mousedown', function(e) {
    var header = e.target.closest('.kx-dialog-header');
    if (!header) return;
    // Don't drag when clicking close button
    if (e.target.closest('.kx-dialog-close-btn')) return;
    var dlg = header.closest('.kx-dialog');
    if (!dlg) return;

    // On first drag, switch from CSS-centered (transform) to absolute pixel position
    var ct = getComputedStyle(dlg).transform;
    if (ct && ct !== 'none') {
      var rect = dlg.getBoundingClientRect();
      var overlay = dlg.parentElement;
      var oRect = overlay.getBoundingClientRect();
      dlg.style.left = (rect.left - oRect.left) + 'px';
      dlg.style.top = (rect.top - oRect.top) + 'px';
      dlg.style.transform = 'none';
    }

    drag = {
      dlg: dlg,
      startX: e.clientX,
      startY: e.clientY,
      origX: parseInt(dlg.style.left, 10) || 0,
      origY: parseInt(dlg.style.top, 10) || 0
    };
    e.preventDefault();
  });

  document.addEventListener('mousemove', function(e) {
    if (!drag) return;
    var dx = e.clientX - drag.startX;
    var dy = e.clientY - drag.startY;
    drag.dlg.style.left = (drag.origX + dx) + 'px';
    drag.dlg.style.top = (drag.origY + dy) + 'px';
  });

  document.addEventListener('mouseup', function() {
    drag = null;
  });
})();

var kxGrid = {

  /**
   * Prepares sort state before HTMX fires the column-header request.
   * Updates hidden sort/dir inputs and toggles CSS classes immediately.
   */
  prepareSort: function(th, viewName) {
    var field = th.dataset.field;
    var stateDiv = document.getElementById('kx-list-state-' + viewName);
    if (!stateDiv) return;
    var sortInput = stateDiv.querySelector('input[name="sort"]');
    var dirInput = stateDiv.querySelector('input[name="dir"]');
    if (!sortInput || !dirInput) return;

    if (sortInput.value === field) {
      dirInput.value = dirInput.value === 'asc' ? 'desc' : 'asc';
    } else {
      sortInput.value = field;
      dirInput.value = 'asc';
    }

    this.updateSortIndicators(viewName);
  },

  /**
   * Updates sort arrow CSS classes on column headers to match hidden state.
   */
  updateSortIndicators: function(viewName) {
    var stateDiv = document.getElementById('kx-list-state-' + viewName);
    if (!stateDiv) return;
    var sortEl = stateDiv.querySelector('input[name="sort"]');
    var dirEl = stateDiv.querySelector('input[name="dir"]');
    var sort = sortEl ? sortEl.value : '';
    var dir = dirEl ? dirEl.value : 'asc';

    var thead = document.getElementById('kx-list-head-' + viewName);
    if (!thead) return;

    thead.querySelectorAll('th.kx-col-sortable').forEach(function(t) {
      t.classList.remove('kx-sort-asc', 'kx-sort-desc');
      if (t.dataset.field === sort) {
        t.classList.add(dir === 'desc' ? 'kx-sort-desc' : 'kx-sort-asc');
      }
    });
  },

  /**
   * Applies RowClassProvider to all rows in a grid.
   * Reads the JS function from tbody data-row-class-provider attribute,
   * evaluates it, and calls it for each row with a Kitto1-compatible
   * record object ({ get: function(fieldName) {...}, data: {...} }).
   */
  applyRowClasses: function(viewName) {
    var tbody = document.getElementById('kx-list-body-' + viewName);
    if (!tbody) return;
    var provider = tbody.dataset.rowClassProvider;
    if (!provider) return;

    var fn;
    try {
      fn = new Function('return (' + provider + ')')();
    } catch(e) { return; }

    tbody.querySelectorAll('tr[data-fields]').forEach(function(tr) {
      var fields;
      try { fields = JSON.parse(tr.dataset.fields); } catch(e) { return; }
      var record = {
        get: function(name) { return fields[name]; },
        data: fields
      };
      var cls = fn(record);
      if (cls) {
        tr.classList.add('kx-custom-row');
        cls.split(/\s+/).forEach(function(c) { if (c) tr.classList.add(c); });
      }
    });
  },

  /**
   * Handles row click: toggles selection, updates hidden key input,
   * enables/disables toolbar buttons requiring selection.
   */
  select: function(row, viewName) {
    var container = row.closest('[id^="kx-list-body-"]');
    if (!container) return;
    var prev = container.querySelector('.kx-row-selected');
    if (prev === row) return; // already selected, keep it
    if (prev) prev.classList.remove('kx-row-selected');
    row.classList.add('kx-row-selected');
    document.getElementById('kx-selected-key-' + viewName).value = row.dataset.key;
    kxGrid.updateButtons(viewName, true);
  },

  /**
   * Handles double-click on a grid data row.
   * Reads the operation (edit/view) from the tbody data-dblclick attribute.
   */
  rowDblClick: function(row, viewName) {
    var container = row.closest('[data-dblclick]');
    if (!container) return;
    var op = container.dataset.dblclick;
    if (container.dataset.detailView) {
      kxForm.openDetailForm(
        container.dataset.detailView, op,
        container.dataset.aliasView,
        parseInt(container.dataset.detailIndex, 10),
        container.dataset.masterView,
        container.dataset.masterKey,
        container.dataset.fkField || ''
      );
    } else {
      kxGrid.openForm(viewName, op);
    }
  },

  /**
   * Enables or disables all toolbar buttons that require a row selection.
   */
  updateButtons: function(viewName, enabled) {
    var toolbar = document.getElementById('kx-list-toolbar-' + viewName);
    if (!toolbar) return;
    // Search toolbar and its parent dialog body for selection-dependent buttons
    // (in lookup mode, Select button is in the footer, not the toolbar)
    var scope = toolbar.closest('.kx-dialog-body') || toolbar;
    scope.querySelectorAll('.kx-requires-selection').forEach(function(btn) {
      btn.disabled = !enabled;
    });
  },

  /**
   * Clears row selection and disables selection-dependent buttons.
   * Called automatically after HTMX swaps new tbody content.
   */
  clearSelection: function(viewName) {
    var keyInput = document.getElementById('kx-selected-key-' + viewName);
    if (keyInput) keyInput.value = '';
    kxGrid.updateButtons(viewName, false);
  },

  /**
   * Returns the current selected record key string (URL-encoded field=value pairs).
   */
  getSelectedKey: function(viewName) {
    var input = document.getElementById('kx-selected-key-' + viewName);
    return input ? input.value : '';
  },

  /**
   * Collects current filter and state values for a view, to be sent with requests.
   */
  collectValues: function(viewName, extra) {
    var values = extra || {};
    // State values (limit, sort, dir)
    var stateDiv = document.getElementById('kx-list-state-' + viewName);
    if (stateDiv) {
      stateDiv.querySelectorAll('input').forEach(function(inp) {
        if (inp.name) values[inp.name] = inp.value;
      });
    }
    // Filter values (f_0, f_1, ...)
    var filterForm = document.getElementById('kx-filter-form-' + viewName);
    if (filterForm) {
      filterForm.querySelectorAll('input, select').forEach(function(inp) {
        if (inp.name) {
          if (inp.type === 'checkbox')
            values[inp.name] = inp.checked ? inp.value : '';
          else
            values[inp.name] = inp.value;
        }
      });
    }
    return values;
  },

  /**
   * Shows a modal confirmation dialog (replaces browser confirm()).
   * @param {string} title - Dialog header text (e.g. "Confirm")
   * @param {string} message - Body text (HTML-encoded by caller)
   * @param {string} yesLabel - Yes button label
   * @param {string} noLabel - No button label
   * @param {function} onYes - Callback when user clicks Yes
   */
  showConfirm: function(title, message, yesLabel, noLabel, onYes, onNo) {
    // Detect mode: error from title, then confirm (two buttons) vs info (one button).
    var isConfirm = noLabel && noLabel.length > 0;
    var mode = /error|errore/i.test(title) ? 'error' : (isConfirm ? 'confirm' : 'info');
    var overlay = document.createElement('div');
    overlay.className = 'kx-msgbox-overlay';
    overlay.innerHTML =
      '<div class="kx-msgbox-dialog kx-msgbox-' + mode + '" onclick="event.stopPropagation()">' +
        '<div class="kx-msgbox-header kx-msgbox-' + mode + '">' +
          '<div class="kx-msgbox-icon kx-msgbox-icon-' + mode + '"></div>' +
          '<span>' + title + '</span>' +
          '<button class="kx-msgbox-close">' + KX_CLOSE_ICON + '</button>' +
        '</div>' +
        '<div class="kx-msgbox-body">' + message + '</div>' +
        '<div class="kx-msgbox-footer">' +
          '<button class="kx-msgbox-btn-yes">' + yesLabel + '</button>' +
          (isConfirm ? '<button class="kx-msgbox-btn-no">' + noLabel + '</button>' : '') +
        '</div>' +
      '</div>';
    // Close on overlay click
    overlay.addEventListener('click', function(e) {
      if (e.target === overlay) overlay.remove();
    });
    // Close button
    overlay.querySelector('.kx-msgbox-close').addEventListener('click', function() {
      overlay.remove();
    });
    // No button (only present for confirm dialogs)
    var noBtn = overlay.querySelector('.kx-msgbox-btn-no');
    if (noBtn) {
      noBtn.addEventListener('click', function() {
        overlay.remove();
        if (onNo) onNo();
      });
    }
    // Yes/OK button
    overlay.querySelector('.kx-msgbox-btn-yes').addEventListener('click', function() {
      overlay.remove();
      if (onYes) onYes();
    });
    document.body.appendChild(overlay);
    kxMakeDraggable(overlay.querySelector('.kx-msgbox-dialog'));
  },

  /**
   * Shows a brief toast notification at the bottom of the screen.
   * Auto-dismisses after 3 seconds.
   */
  showToast: function(title, message) {
    var toast = document.createElement('div');
    toast.className = 'kx-toast';
    toast.innerHTML = '<div class="kx-toast-title">' + (title || '') + '</div>' +
      '<div class="kx-toast-message">' + (message || '') + '</div>';
    document.body.appendChild(toast);
    // Trigger reflow then add visible class for animation
    toast.offsetHeight;
    toast.classList.add('kx-toast-visible');
    setTimeout(function() {
      toast.classList.remove('kx-toast-visible');
      setTimeout(function() { toast.remove(); }, 300);
    }, 3000);
  },

  /**
   * Deletes the selected record after user confirmation via modal dialog.
   * Sends POST to kx/view/{ViewName}/delete with key + current state/filter values.
   * Server returns refreshed grid data (rows + OOB pager/state).
   */
  deleteRecord: function(viewName, title, confirmMsg, yesLabel, noLabel) {
    var key = kxGrid.getSelectedKey(viewName);
    if (!key) return;

    kxGrid.showConfirm(title, confirmMsg, yesLabel, noLabel, function() {
      var values = kxGrid.collectValues(viewName, { key: key, start: '0' });
      htmx.ajax('POST', 'kx/view/' + viewName + '/delete', {
        target: '#kx-list-body-' + viewName,
        swap: 'innerHTML',
        values: values,
        headers: { 'X-KittoX': 'true' }
      }).then(function() {
        // Only show toast if no error dialog appeared
        if (!document.querySelector('.kx-msgbox-overlay'))
          kxGrid.showToast(window.KX_STRINGS.appTitle || '', window.KX_STRINGS.dataDeleted || 'Data deleted');
      });
    });
  },

  /**
   * Opens the Form controller for the given operation.
   * For 'add', no selection is required. For 'edit'/'view'/'dup', uses selected key.
   * Fetches form HTML from server and inserts as dialog overlay.
   */
  openForm: function(viewName, op, explicitKey, extraParams) {
    var key = '';
    if (typeof explicitKey === 'string' && explicitKey) {
      key = explicitKey;
    } else if (op !== 'add') {
      key = kxGrid.getSelectedKey(viewName);
      if (!key) return;
    }
    var url = 'kx/view/' + viewName + '/form?op=' + op;
    if (key) url += '&key=' + encodeURIComponent(key);
    if (extraParams) url += '&' + extraParams;
    var loadingEl = document.getElementById('kx-loading');
    if (loadingEl) loadingEl.classList.add('kx-busy');
    kxFetchWithTimeout(url, { headers: { 'X-KittoX': 'true' } })
      .then(function(r) { return r.text(); })
      .then(function(html) {
        var div = document.createElement('div');
        div.innerHTML = html;
        if (div.firstElementChild) {
          var el = div.firstElementChild;
          document.body.appendChild(el);
          // Execute inline scripts (e.g. detail tab loading)
          el.querySelectorAll('script').forEach(function(script) {
            var s = document.createElement('script');
            s.textContent = script.textContent;
            document.head.appendChild(s);
            document.head.removeChild(s);
          });
          // Initialize SunEditor on HTMLMemo fields
          kxForm.initHtmlEditors(viewName);
        }
      })
      .catch(function(err) {
        kxGrid.showConfirm('Error', err.message, 'OK', '', null);
      })
      .finally(function() {
        if (loadingEl) loadingEl.classList.remove('kx-busy');
      });
  },

  /**
   * Refreshes the grid data by re-fetching from the server.
   * Sends current filter and state values; resets to first page.
   */
  refreshData: function(viewName) {
    var values = kxGrid.collectValues(viewName, { start: '0' });
    htmx.ajax('POST', 'kx/view/' + viewName + '/data', {
      target: '#kx-list-body-' + viewName,
      swap: 'innerHTML',
      values: values,
      headers: { 'X-KittoX': 'true' }
    });
  },

  /**
   * Toggles visibility of a group's data rows and swaps the header icon.
   * Used by GroupingList controller for collapsible group headers.
   * @param {string} viewName - View name
   * @param {number} groupIndex - Zero-based group index
   */
  toggleGroup: function(viewName, groupIndex) {
    var rows = document.querySelectorAll('.kx-grp-' + viewName + '-' + groupIndex);
    var header = document.getElementById('kx-grp-hdr-' + viewName + '-' + groupIndex);
    if (!header || rows.length === 0) return;
    var icon = header.querySelector('.kx-group-toggle');
    var visible = rows[0].style.display !== 'none';
    rows.forEach(function(r) { r.style.display = visible ? 'none' : ''; });
    if (icon) icon.innerHTML = visible ? '&#x25B6;' : '&#x25BC;';
  },

  /**
   * Executes a ToolView action from a toolbar button.
   * Reads configuration from data-* attributes on the button element:
   *   data-view: view name
   *   data-tool: tool node name
   *   data-requiresel: "true" if selection is required
   *   data-confirm: optional confirmation message (HTML)
   *   data-autorefresh: "All" or "Current" to refresh grid after execution
   *   data-upload: "true" for upload tools (opens file picker)
   *   data-accept: file accept filter (e.g. ".jpg,.png")
   *
   * For download tools: uses fetch() + blob to trigger file save dialog.
   * For upload tools: opens a file picker, then sends multipart/form-data.
   * For other tools: sends POST and handles response.
   */
  executeTool: function(btn) {
    var viewName = btn.dataset.view;
    var toolName = btn.dataset.tool;
    var requireSel = btn.dataset.requiresel === 'true';
    var confirmMsg = btn.dataset.confirm || '';
    var autoRefresh = btn.dataset.autorefresh || '';
    var isUpload = btn.dataset.upload === 'true';
    var acceptFilter = btn.dataset.accept || '';

    // Check selection if required
    if (requireSel) {
      var key = kxGrid.getSelectedKey(viewName);
      if (!key) return;
    }

    function doExecute(file) {
      var url = 'kx/view/' + viewName + '/tool/' + toolName;
      var body;
      var headers = {};
      var loadingEl = document.getElementById('kx-loading');

      if (isUpload && file) {
        // Upload: multipart/form-data with file
        body = new FormData();
        body.append('file', file);
        var vals = kxGrid.collectValues(viewName, {});
        if (requireSel) vals.key = kxGrid.getSelectedKey(viewName);
        for (var k in vals) body.append(k, vals[k]);
        // Don't set Content-Type; browser sets multipart boundary automatically
        headers['X-KittoX'] = 'true';
      } else {
        // Regular tool: URL-encoded form data
        var values = kxGrid.collectValues(viewName, {});
        if (requireSel) values.key = kxGrid.getSelectedKey(viewName);
        body = new URLSearchParams();
        for (var k in values) body.append(k, values[k]);
        headers['Content-Type'] = 'application/x-www-form-urlencoded';
        headers['X-KittoX'] = 'true';
      }

      // Show loading overlay
      if (loadingEl) loadingEl.classList.add('kx-busy');

      kxFetchWithTimeout(url, {
        method: 'POST',
        body: body,
        headers: headers
      }).then(function(response) {
        if (!response.ok) {
          return response.text().then(function(text) {
            throw new Error(text || 'Tool execution failed (HTTP ' + response.status + ')');
          });
        }
        var disposition = response.headers.get('Content-Disposition');
        if (disposition && disposition.indexOf('attachment') !== -1) {
          // Download file via blob
          var filenameMatch = disposition.match(/filename[^;=\n]*=["']?([^"';\n]*)["']?/);
          var filename = filenameMatch ? filenameMatch[1] : 'download';
          return response.blob().then(function(blob) {
            var blobUrl = URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = blobUrl;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(blobUrl);
            if (autoRefresh) kxGrid.refreshData(viewName);
          });
        } else {
          // Non-download tool: check for HTML response (error dialog or toast)
          return response.text().then(function(html) {
            if (html && html.trim()) {
              var div = document.createElement('div');
              div.innerHTML = html;
              if (div.firstElementChild)
                document.body.appendChild(div.firstElementChild);
            }
            if (autoRefresh) kxGrid.refreshData(viewName);
          });
        }
      }).catch(function(err) {
        kxGrid.showConfirm('Error', err.message || 'Tool execution error', 'OK', '', null);
      }).finally(function() {
        // Hide loading overlay
        if (loadingEl) loadingEl.classList.remove('kx-busy');
      });
    }

    function startExecution() {
      if (isUpload) {
        // Open file picker, then execute with selected file
        var input = document.createElement('input');
        input.type = 'file';
        if (acceptFilter) input.accept = acceptFilter;
        input.onchange = function() {
          if (input.files && input.files[0]) {
            doExecute(input.files[0]);
          }
        };
        input.click();
      } else {
        doExecute(null);
      }
    }

    if (confirmMsg) {
      kxGrid.showConfirm('Confirm', confirmMsg, 'Yes', 'No', startExecution);
    } else {
      startExecution();
    }
  }
};

/**
 * kxForm — Form dialog helpers for KittoX Form controller.
 * Handles save (POST), cancel (close), and server response processing.
 */
var kxForm = {

  /** Registry of active SunEditor instances keyed by textarea name */
  _htmlEditors: {},

  /**
   * Initializes SunEditor on all .kx-html-editor textareas inside a form.
   * Called after the form dialog HTML is inserted into the DOM.
   */
  initHtmlEditors: function(viewName) {
    if (typeof SUNEDITOR === 'undefined') return;
    var form = document.getElementById('kx-form-' + viewName);
    if (!form) return;
    form.querySelectorAll('textarea.kx-html-editor').forEach(function(ta) {
      if (kxForm._htmlEditors[ta.name]) return; // already initialized
      var isReadOnly = ta.hasAttribute('readonly') || ta.hasAttribute('disabled');
      // Build toolbar from data attributes (HTMLEditor YAML options)
      var buttons = [];
      if (!isReadOnly) {
        if (!ta.dataset.noFont) buttons.push(['font', 'fontSize']);
        else if (!ta.dataset.noFontsize) buttons.push(['fontSize']);
        if (!ta.dataset.noFormat) buttons.push(['bold', 'italic', 'underline', 'strike']);
        if (!ta.dataset.noColors) buttons.push(['fontColor', 'hiliteColor']);
        if (!ta.dataset.noAlign) buttons.push(['align']);
        if (!ta.dataset.noLinks) buttons.push(['link']);
        if (!ta.dataset.noLists) buttons.push(['list']);
        if (!ta.dataset.noSource) buttons.push(['codeView']);
      }
      // Read width from data attribute (ch units, set by Delphi from DisplayWidth)
      var editorWidth = ta.dataset.editorWidth;
      // Calculate editor height: rows * 16 * heightFactor (from Defaults/Layout/Char_Height_Factor).
      // Default factor is 1.0; Kitto1-compatible apps use ~0.8 to match LinesToPixels formula.
      // SunEditor height = editing area only, so subtract toolbar (~40px) + status bar (~25px).
      var rows = parseInt(ta.getAttribute('rows'), 10) || 5;
      var heightFactor = parseFloat(ta.dataset.heightFactor) || 1;
      var totalHeight = Math.round(rows * 16 * heightFactor);
      var editorHeight = Math.max(totalHeight - 65, 50) + 'px';
      var fieldName = ta.name;
      var editor = SUNEDITOR.create(ta, {
        buttonList: buttons,
        defaultTag: 'div',
        height: editorHeight,
        width: editorWidth ? editorWidth + 'ch' : '100%',
        tabDisable: true
      });
      if (isReadOnly) {
        editor.disable();
      }
      // Remove name from original textarea so it won't be serialized by form;
      // syncHtmlEditors will create a hidden input with the correct value.
      ta.removeAttribute('name');
      ta.dataset.fieldName = fieldName;
      kxForm._htmlEditors[fieldName] = editor;
    });
  },

  /**
   * Syncs SunEditor content back into the underlying textarea elements
   * so that the form serialization picks up the HTML content.
   */
  syncHtmlEditors: function(viewName) {
    var form = document.getElementById('kx-form-' + viewName);
    if (!form) return;
    // SunEditor may move the original textarea; use our registry to sync
    Object.keys(kxForm._htmlEditors).forEach(function(name) {
      var editor = kxForm._htmlEditors[name];
      if (!editor) return;
      var content = editor.getContents();
      // Ensure a hidden input inside the form carries the value
      var hidden = form.querySelector('input[type="hidden"][name="' + name + '"]');
      if (!hidden) {
        hidden = document.createElement('input');
        hidden.type = 'hidden';
        hidden.name = name;
        form.appendChild(hidden);
      }
      hidden.value = content;
    });
  },

  /**
   * Destroys SunEditor instances for a form (cleanup on close).
   */
  destroyHtmlEditors: function(viewName) {
    var form = document.getElementById('kx-form-' + viewName);
    if (!form) return;
    form.querySelectorAll('textarea.kx-html-editor').forEach(function(ta) {
      var key = ta.dataset.fieldName || ta.name;
      var editor = kxForm._htmlEditors[key];
      if (editor) {
        editor.destroy();
        delete kxForm._htmlEditors[key];
      }
    });
  },

  /**
   * Saves form data by POSTing to the server.
   * Collects all inputs from the form, sends as URL-encoded form data.
   * On success: server returns a script tag that calls onSaveSuccess.
   * On error: server returns an error dialog overlay.
   */
  save: function(viewName, op) {
    // If this form was opened from a detail grid context, redirect to saveDetail
    // (detail records save to in-memory store, not to DB)
    var detailCtx = kxForm._detailContext[viewName];
    if (detailCtx) {
      kxForm.saveDetail(viewName, detailCtx.masterView, detailCtx.tabIndex, op);
      return;
    }

    // Detail form (has detail tables): Save goes to SaveCache (no DB persist)
    // unless _saveAll is set (Save All button triggers full DB persist)
    var form = document.getElementById('kx-form-' + viewName);
    var saveAllInput = form ? form.querySelector('input[name="_saveAll"]') : null;
    if (form && form.dataset.hasDetails === 'true' && !(saveAllInput && saveAllInput.value === 'true')) {
      kxForm.saveCache(viewName, op);
      return;
    }

    if (!form) return;

    // Sync HTML editors before collecting form data
    kxForm.syncHtmlEditors(viewName);

    // Browser validation for required fields
    // Prevent double-click / concurrent saves
    var saveBtn = form.querySelector('.kx-form-btn-save');
    if (saveBtn && saveBtn.disabled) return;
    if (saveBtn) saveBtn.disabled = true;

    var inputs = form.querySelectorAll('input[required], select[required], textarea[required]');
    for (var i = 0; i < inputs.length; i++) {
      if (!inputs[i].value && inputs[i].type !== 'checkbox') {
        // If the invalid field is on a hidden page, switch to that page first
        var page = inputs[i].closest('.kx-form-page');
        if (page && page.style.display === 'none') {
          var pageId = page.id; // e.g. "kx-form-page-Dolls-1"
          var allPages = form.querySelectorAll('.kx-form-page');
          for (var p = 0; p < allPages.length; p++) {
            if (allPages[p] === page) {
              kxForm.switchPage(viewName, p);
              break;
            }
          }
        }
        inputs[i].focus();
        inputs[i].reportValidity();
        if (saveBtn) saveBtn.disabled = false;
        return;
      }
    }

    // Check if any file inputs have files selected (for IsPicture blob upload)
    var fileInputs = form.querySelectorAll('input[type="file"]');
    var hasFiles = false;
    fileInputs.forEach(function(fi) { if (fi.files.length > 0) hasFiles = true; });

    var body, headers;
    if (hasFiles) {
      body = new FormData();
      form.querySelectorAll('input, select, textarea').forEach(function(inp) {
        if (!inp.name) return;
        if (inp.type === 'file') {
          if (inp.files.length > 0) body.append(inp.name, inp.files[0]);
        } else if (inp.type === 'checkbox') {
          body.append(inp.name, inp.checked ? 'true' : 'false');
        } else {
          body.append(inp.name, inp.value);
        }
      });
      // Browser sets Content-Type with multipart boundary automatically
      headers = { 'X-KittoX': 'true' };
    } else {
      body = new URLSearchParams();
      form.querySelectorAll('input, select, textarea').forEach(function(inp) {
        if (!inp.name) return;
        if (inp.type === 'file') return; // skip empty file inputs
        if (inp.type === 'checkbox') {
          body.append(inp.name, inp.checked ? 'true' : 'false');
        } else {
          body.append(inp.name, inp.value);
        }
      });
      headers = { 'Content-Type': 'application/x-www-form-urlencoded', 'X-KittoX': 'true' };
    }

    var loadingEl = document.getElementById('kx-loading');
    if (loadingEl) loadingEl.classList.add('kx-busy');

    kxFetchWithTimeout('kx/view/' + viewName + '/save', {
      method: 'POST',
      body: body,
      headers: headers
    })
    .then(function(r) { return r.text(); })
    .then(function(html) {
      if (html && html.trim()) {
        var div = document.createElement('div');
        div.innerHTML = html;
        // Execute any inline scripts returned by the server
        div.querySelectorAll('script').forEach(function(script) {
          var s = document.createElement('script');
          s.textContent = script.textContent;
          document.head.appendChild(s);
          document.head.removeChild(s);
        });
        // Append non-script elements (e.g. error dialogs)
        while (div.firstElementChild) {
          if (div.firstElementChild.tagName !== 'SCRIPT')
            document.body.appendChild(div.firstElementChild);
          else
            div.removeChild(div.firstElementChild);
        }
      }
    })
    .catch(function(err) {
      kxGrid.showConfirm('Error', err.message || 'Save failed', 'OK', '', null);
    })
    .finally(function() {
      if (loadingEl) loadingEl.classList.remove('kx-busy');
      if (saveBtn) saveBtn.disabled = false;
    });
  },

  /**
   * Closes the form dialog without saving.
   */
  cancel: function(viewName) {
    kxForm.destroyHtmlEditors(viewName);
    // Modal form overlay has priority (grid and modal share the same viewName)
    var overlay = document.getElementById('kx-form-overlay-' + viewName);
    if (overlay) {
      overlay.remove();
    } else if (typeof kxTabs !== 'undefined' && document.getElementById('kx-tab-pane-' + viewName)) {
      // Standalone form in tab: close the tab
      kxTabs.close(viewName);
    } else {
      var el = document.getElementById('kx-' + viewName);
      if (el) el.remove();
    }
    // Notify server to release session store (fire-and-forget)
    fetch('kx/view/' + viewName + '/form-close', {
      method: 'POST', headers: { 'X-KittoX': 'true' }
    }).catch(function() {});
    // Clean up any detail context (set when opening from detail grid)
    delete kxForm._detailContext[viewName];
  },

  /**
   * Called by server response script after successful save.
   * Closes form dialog and refreshes the grid.
   */
  onSaveSuccess: function(viewName) {
    kxForm.destroyHtmlEditors(viewName);
    // Modal form overlay has priority (grid and modal share the same viewName)
    var overlay = document.getElementById('kx-form-overlay-' + viewName);
    if (overlay) {
      overlay.remove();
    } else if (typeof kxTabs !== 'undefined' && document.getElementById('kx-tab-pane-' + viewName)) {
      // Standalone form in tab: close the tab
      kxTabs.close(viewName);
    } else {
      var el = document.getElementById('kx-' + viewName);
      if (el) el.remove();
    }
    // Show toast notification
    kxGrid.showToast(window.KX_STRINGS.appTitle || '', window.KX_STRINGS.dataSaved || 'Data saved');
    // Check if this form was opened from a detail grid context
    var ctx = kxForm._detailContext[viewName];
    if (ctx) {
      // Reload the detail tab that spawned this form
      kxForm.loadDetailTab(ctx.masterView, ctx.tabIndex, ctx.masterKey);
      delete kxForm._detailContext[viewName];
    } else if (typeof kxCalendar !== 'undefined' && kxCalendar._instances[viewName]) {
      kxCalendar.refresh(viewName);
    } else {
      kxGrid.refreshData(viewName);
    }
  },

  /**
   * Called by server after saving master only (detail changes still pending).
   * Shows toast, enables Save All button, keeps form open.
   */
  onSaveMasterOnly: function(viewName) {
    kxGrid.showToast(window.KX_STRINGS.appTitle || '', window.KX_STRINGS.dataSaved || 'Data saved');
    // Enable the Save All button
    var form = document.getElementById('kx-form-' + viewName);
    if (form) {
      var saveAllBtn = form.querySelector('.kx-form-btn-saveall');
      if (saveAllBtn) saveAllBtn.disabled = false;
      // Re-enable save button
      var saveBtn = form.querySelector('.kx-form-btn-save');
      if (saveBtn) saveBtn.disabled = false;
    }
  },

  /**
   * Saves form data to the server-side session store (no DB persist).
   * Used by detail forms: Save updates the in-memory store, then switches to ViewMode.
   */
  saveCache: function(viewName, op) {
    var form = document.getElementById('kx-form-' + viewName);
    if (!form) return;

    kxForm.syncHtmlEditors(viewName);

    var saveBtn = form.querySelector('.kx-form-btn-save');
    if (saveBtn && saveBtn.disabled) return;
    if (saveBtn) saveBtn.disabled = true;

    // Browser validation
    var inputs = form.querySelectorAll('input[required], select[required], textarea[required]');
    for (var i = 0; i < inputs.length; i++) {
      if (!inputs[i].value && inputs[i].type !== 'checkbox') {
        inputs[i].focus();
        inputs[i].reportValidity();
        if (saveBtn) saveBtn.disabled = false;
        return;
      }
    }

    var body = new URLSearchParams();
    form.querySelectorAll('input, select, textarea').forEach(function(inp) {
      if (!inp.name) return;
      if (inp.type === 'file') return;
      if (inp.type === 'checkbox') body.append(inp.name, inp.checked ? 'true' : 'false');
      else body.append(inp.name, inp.value);
    });

    var loadingEl = document.getElementById('kx-loading');
    if (loadingEl) loadingEl.classList.add('kx-busy');

    kxFetchWithTimeout('kx/view/' + viewName + '/save-cache', {
      method: 'POST',
      body: body,
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-KittoX': 'true' }
    })
    .then(function(r) { return r.text(); })
    .then(function(html) {
      if (html && html.trim()) {
        var div = document.createElement('div');
        div.innerHTML = html;
        div.querySelectorAll('script').forEach(function(script) {
          var s = document.createElement('script');
          s.textContent = script.textContent;
          document.head.appendChild(s);
          document.head.removeChild(s);
        });
        while (div.firstElementChild) {
          if (div.firstElementChild.tagName !== 'SCRIPT')
            document.body.appendChild(div.firstElementChild);
          else
            div.removeChild(div.firstElementChild);
        }
      }
    })
    .catch(function(err) {
      kxGrid.showConfirm('Error', err.message || 'Save cache failed', 'OK', '', null);
    })
    .finally(function() {
      if (loadingEl) loadingEl.classList.remove('kx-busy');
      if (saveBtn) saveBtn.disabled = false;
    });
  },

  /**
   * Called by server after successful save-cache (in-memory, no DB).
   * Switches form to ViewMode, marks pending changes, enables Save All.
   */
  onSaveCacheSuccess: function(viewName) {
    var form = document.getElementById('kx-form-' + viewName);
    if (form) {
      form.dataset.hasPending = 'true';
      // Enable Save All button (rendered disabled by server)
      var saveAllBtn = form.querySelector('.kx-form-btn-saveall');
      if (saveAllBtn) saveAllBtn.disabled = false;
    }
    // Switch to ViewMode (shows Edit + Save All + Close, hides Save + Cancel)
    kxForm.setMode(viewName, 'view');
    // Re-enable save button for next edit cycle
    if (form) {
      var saveBtn = form.querySelector('.kx-form-btn-save');
      if (saveBtn) saveBtn.disabled = false;
    }
  },

  /**
   * Saves form data with a _clone flag.
   * After successful save, the server returns onCloneSuccess instead of onSaveSuccess.
   */
  saveAndClone: function(viewName, op) {
    var form = document.getElementById('kx-form-' + viewName);
    if (!form) return;
    // Inject or update the _clone hidden input
    var cloneInput = form.querySelector('input[name="_clone"]');
    if (!cloneInput) {
      cloneInput = document.createElement('input');
      cloneInput.type = 'hidden';
      cloneInput.name = '_clone';
      form.appendChild(cloneInput);
    }
    cloneInput.value = 'true';
    // Trigger the normal save flow (which will pick up _clone from form inputs)
    kxForm.save(viewName, op);
  },

  /**
   * Saves the master record plus all pending detail changes in one transaction.
   * Injects a _saveAll=true hidden field and triggers the normal save flow.
   */
  saveAll: function(viewName, op) {
    var form = document.getElementById('kx-form-' + viewName);
    if (!form) return;
    var saveAllInput = form.querySelector('input[name="_saveAll"]');
    if (!saveAllInput) {
      saveAllInput = document.createElement('input');
      saveAllInput.type = 'hidden';
      saveAllInput.name = '_saveAll';
      form.appendChild(saveAllInput);
    }
    saveAllInput.value = 'true';
    kxForm.save(viewName, op);
  },

  /**
   * Called by server after save with _clone flag.
   * Refreshes grid, resets form to add mode, clears key fields, keeps other values.
   */
  onCloneSuccess: function(viewName) {
    // Refresh underlying grid/calendar
    if (typeof kxCalendar !== 'undefined' && kxCalendar._instances[viewName]) {
      kxCalendar.refresh(viewName);
    } else {
      kxGrid.refreshData(viewName);
    }
    var form = document.getElementById('kx-form-' + viewName);
    if (form) {
      // Switch to add mode
      var opInput = form.querySelector('input[name="_op"]');
      if (opInput) opInput.value = 'add';
      var keyInput = form.querySelector('input[name="_key"]');
      if (keyInput) keyInput.value = '';
      // Remove _clone flag so next normal Save works as expected
      var cloneInput = form.querySelector('input[name="_clone"]');
      if (cloneInput) cloneInput.remove();
      // Clear key fields (keep non-key values for the clone)
      form.querySelectorAll('[data-iskey="true"]').forEach(function(inp) {
        inp.value = '';
      });
      // Re-enable save button
      var saveBtn = form.querySelector('.kx-form-btn-save');
      if (saveBtn) saveBtn.disabled = false;
      // Focus first editable field
      var first = form.querySelector('input:not([type="hidden"]):not([disabled]), select:not([disabled]), textarea:not([disabled])');
      if (first) first.focus();
    }
  },

  /**
   * Called by server after save with _keepopen flag.
   * Refreshes grid, clears ALL form fields, resets to add mode for next entry.
   */
  onSaveKeepOpen: function(viewName) {
    // Refresh underlying grid/calendar
    if (typeof kxCalendar !== 'undefined' && kxCalendar._instances[viewName]) {
      kxCalendar.refresh(viewName);
    } else {
      kxGrid.refreshData(viewName);
    }
    var form = document.getElementById('kx-form-' + viewName);
    if (form) {
      var opInput = form.querySelector('input[name="_op"]');
      if (opInput) opInput.value = 'add';
      var keyInput = form.querySelector('input[name="_key"]');
      if (keyInput) keyInput.value = '';
      // Clear all visible form inputs
      form.querySelectorAll('input:not([type="hidden"]), select, textarea').forEach(function(inp) {
        if (inp.type === 'checkbox') inp.checked = false;
        else inp.value = '';
      });
      // Re-enable save button
      var saveBtn = form.querySelector('.kx-form-btn-save');
      if (saveBtn) saveBtn.disabled = false;
      // Focus first editable field
      var first = form.querySelector('input:not([type="hidden"]):not([disabled]), select:not([disabled]), textarea:not([disabled])');
      if (first) first.focus();
    }
  },

  /**
   * Saves a detail form to the in-memory session store (not to DB).
   * Posts to kx/view/{masterView}/detail/{detailIndex}/save.
   */
  saveDetail: function(detailView, masterView, detailIndex, op) {
    var form = document.getElementById('kx-form-' + detailView);
    if (!form) return;

    kxForm.syncHtmlEditors(detailView);

    var saveBtn = form.querySelector('.kx-form-btn-save');
    if (saveBtn && saveBtn.disabled) return;
    if (saveBtn) saveBtn.disabled = true;

    // Browser validation
    var inputs = form.querySelectorAll('input[required], select[required], textarea[required]');
    for (var i = 0; i < inputs.length; i++) {
      if (!inputs[i].value && inputs[i].type !== 'checkbox') {
        inputs[i].focus();
        inputs[i].reportValidity();
        if (saveBtn) saveBtn.disabled = false;
        return;
      }
    }

    var body = new URLSearchParams();
    form.querySelectorAll('input, select, textarea').forEach(function(inp) {
      if (!inp.name) return;
      if (inp.type === 'file') return;
      if (inp.type === 'checkbox') {
        body.append(inp.name, inp.checked ? 'true' : 'false');
      } else {
        body.append(inp.name, inp.value);
      }
    });
    body.append('_detailView', detailView);
    var ctx = kxForm._detailContext[detailView];
    if (ctx && ctx.masterKey) body.append('_masterKey', ctx.masterKey);

    var loadingEl = document.getElementById('kx-loading');
    if (loadingEl) loadingEl.classList.add('kx-busy');

    kxFetchWithTimeout('kx/view/' + masterView + '/detail/' + detailIndex + '/save', {
      method: 'POST',
      body: body,
      headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-KittoX': 'true' }
    })
    .then(function(r) { return r.text(); })
    .then(function(html) {
      if (html && html.trim()) {
        var div = document.createElement('div');
        div.innerHTML = html;
        div.querySelectorAll('script').forEach(function(script) {
          var s = document.createElement('script');
          s.textContent = script.textContent;
          document.head.appendChild(s);
          document.head.removeChild(s);
        });
        while (div.firstElementChild) {
          if (div.firstElementChild.tagName !== 'SCRIPT')
            document.body.appendChild(div.firstElementChild);
          else
            div.removeChild(div.firstElementChild);
        }
      }
    })
    .catch(function(err) {
      kxGrid.showConfirm('Error', err.message || 'Detail save failed', 'OK', '', null);
    })
    .finally(function() {
      if (loadingEl) loadingEl.classList.remove('kx-busy');
      if (saveBtn) saveBtn.disabled = false;
    });
  },

  /**
   * Called by server after successful detail save (in-memory, not DB).
   * Closes detail form modal and reloads detail tab from session store.
   */
  onDetailSaveSuccess: function(detailView, masterView, detailIndex, masterKey) {
    kxForm.destroyHtmlEditors(detailView);
    var overlay = document.getElementById('kx-form-overlay-' + detailView);
    if (overlay) overlay.remove();
    // Reload detail tab from session store
    kxForm.loadDetailTab(masterView, detailIndex, masterKey);
    delete kxForm._detailContext[detailView];
    // Enable Save All on the master form (detail changes are now pending)
    var masterForm = document.getElementById('kx-form-' + masterView);
    if (masterForm) {
      var saveAllBtn = masterForm.querySelector('.kx-form-btn-saveall');
      if (saveAllBtn) saveAllBtn.disabled = false;
    }
  },

  /**
   * Switches a view-mode form to edit mode.
   * Closes the current view overlay and reopens the form in edit mode with the same key.
   */
  /**
   * Switches form between ViewMode and EditMode client-side.
   * Toggles button visibility (kx-btn-viewmode / kx-btn-editmode),
   * enables/disables form fields, updates data-mode attribute.
   */
  setMode: function(viewName, mode) {
    var form = document.getElementById('kx-form-' + viewName);
    if (!form) return;
    var isEdit = (mode === 'edit');

    // Toggle button groups
    form.querySelectorAll('.kx-btn-viewmode').forEach(function(b) {
      b.style.display = isEdit ? 'none' : '';
    });
    form.querySelectorAll('.kx-btn-editmode').forEach(function(b) {
      b.style.display = isEdit ? '' : 'none';
    });
    // Save All (kx-btn-pending): visible in both modes when pending, hidden otherwise
    form.querySelectorAll('.kx-btn-pending').forEach(function(b) {
      b.style.display = (form.dataset.hasPending === 'true') ? '' : 'none';
    });

    // Toggle field disabled state
    form.querySelectorAll('input:not([type=hidden]),select,textarea').forEach(function(inp) {
      // Don't touch fields that were originally readonly (FK fields, etc.)
      if (!inp.dataset.origReadonly) {
        inp.dataset.origReadonly = inp.readOnly ? 'true' : 'false';
      }
      if (inp.dataset.origReadonly === 'true') return;
      inp.disabled = !isEdit;
    });

    // Update mode attribute
    form.dataset.mode = mode;
  },

  /**
   * Cancel in EditMode. For detail forms with pending changes,
   * goes back to ViewMode. Otherwise closes the form.
   */
  cancelEdit: function(viewName) {
    var form = document.getElementById('kx-form-' + viewName);
    if (!form) { kxForm.cancel(viewName); return; }

    var hasDetails = form.dataset.hasDetails === 'true';
    var hasPending = form.dataset.hasPending === 'true';

    if (hasDetails && hasPending) {
      // Detail form with pending changes: go back to ViewMode
      kxForm.setMode(viewName, 'view');
    } else {
      // Simple form or no pending changes: close form
      kxForm.cancel(viewName);
    }
  },

  switchToEdit: function(viewName) {
    // Legacy: reopens form in edit mode via server round-trip.
    // Used by simple forms without detail tables.
    var form = document.getElementById('kx-form-' + viewName);
    var key = form ? form.querySelector('input[name="_key"]').value : '';
    var overlay = document.getElementById('kx-form-overlay-' + viewName)
      || document.getElementById('kx-' + viewName);
    if (overlay) overlay.remove();
    kxGrid.openForm(viewName, 'edit', key);
  },

  /**
   * Deletes the current record from a view-mode form and closes the dialog.
   * Uses the same delete endpoint as the grid, then refreshes the grid.
   */
  deleteAndClose: function(viewName, title, confirmMsg, yesLabel, noLabel) {
    var form = document.getElementById('kx-form-' + viewName);
    var key = form ? form.querySelector('input[name="_key"]').value : '';
    if (!key) return;
    kxGrid.showConfirm(title, confirmMsg, yesLabel, noLabel, function() {
      var values = kxGrid.collectValues(viewName, { key: key, start: '0' });
      htmx.ajax('POST', 'kx/view/' + viewName + '/delete', {
        target: '#kx-list-body-' + viewName,
        swap: 'innerHTML',
        values: values,
        headers: { 'X-KittoX': 'true' }
      });
      kxForm.cancel(viewName);
    });
  },

  /**
   * Opens a lookup for IsLarge reference fields.
   * If the hidden input has data-lookup-view, fetches the referenced model's
   * List view as a modal dialog. Otherwise falls back to in-memory popup.
   * @param {string} viewName - View name
   * @param {string} fieldName - Reference field aliased name (e.g. "EMPLOYEE")
   */
  openLookup: function(viewName, fieldName) {
    var keyInput = document.getElementById('kx-field-' + viewName + '-' + fieldName + '-key');
    if (!keyInput) return;
    var lookupView = keyInput.dataset.lookupView;
    if (!lookupView) {
      // Fallback: use old in-memory popup (for models without IsLookup view)
      kxForm._openLookupPopup(viewName, fieldName, keyInput);
      return;
    }
    var url = 'kx/view/' + lookupView + '/lookup?mode=lookup&cv=' +
      encodeURIComponent(viewName) + '&cf=' + encodeURIComponent(fieldName);
    var loadingEl = document.getElementById('kx-loading');
    if (loadingEl) loadingEl.classList.add('kx-busy');
    kxFetchWithTimeout(url, { headers: { 'X-KittoX': 'true' } })
      .then(function(r) { return r.text(); })
      .then(function(html) {
        var div = document.createElement('div');
        div.innerHTML = html;
        var overlay = div.firstElementChild;
        if (overlay) {
          document.body.appendChild(overlay);
          // Add double-click handler for quick selection
          var alias = 'lkp_' + lookupView;
          var tbody = document.getElementById('kx-list-body-' + alias);
          if (tbody) {
            tbody.addEventListener('dblclick', function(e) {
              var row = e.target.closest('tr[data-key]');
              if (row) {
                kxGrid.select(row, alias);
                kxForm.onLookupSelect(alias);
              }
            });
          }
          // Process any inline HTMX
          htmx.process(overlay);
        }
      })
      .catch(function(err) {
        kxGrid.showConfirm('Error', err.message || 'Failed to open lookup', 'OK', '', null);
      })
      .finally(function() {
        if (loadingEl) loadingEl.classList.remove('kx-busy');
      });
  },

  /**
   * Fallback in-memory lookup popup for IsLarge fields without a dedicated
   * IsLookup view. Reads options from data-options JSON attribute.
   */
  _openLookupPopup: function(viewName, fieldName, keyInput) {
    var options;
    try {
      options = JSON.parse(keyInput.dataset.options || '[]');
    } catch(e) {
      options = [];
    }

    var displayInput = document.getElementById('kx-field-' + viewName + '-' + fieldName + '-display');

    // Build searchable popup overlay
    var overlay = document.createElement('div');
    overlay.className = 'kx-dialog-overlay';

    var popup = document.createElement('div');
    popup.className = 'kx-dialog';
    popup.style.width = '380px';
    popup.style.maxHeight = '460px';

    // Header
    popup.innerHTML =
      '<div class="kx-dialog-header">' +
        '<span class="kx-dialog-title">Search</span>' +
        '<button class="kx-dialog-close-btn">' + KX_CLOSE_ICON + '</button>' +
      '</div>';
    popup.querySelector('.kx-dialog-close-btn').addEventListener('click', function() {
      overlay.remove();
    });

    // Body with search + list
    var body = document.createElement('div');
    body.className = 'kx-dialog-body';
    body.style.overflow = 'auto';
    body.style.padding = '0';

    var searchInput = document.createElement('input');
    searchInput.type = 'text';
    searchInput.className = 'kx-form-input';
    searchInput.placeholder = 'Search...';
    searchInput.style.cssText = 'width:100%;border-radius:0;border-left:none;border-right:none;';
    body.appendChild(searchInput);

    var list = document.createElement('div');
    list.style.cssText = 'overflow:auto;flex:1;max-height:320px;';

    function renderOptions(filter) {
      list.innerHTML = '';
      var lowerFilter = (filter || '').toLowerCase();
      options.forEach(function(opt) {
        if (lowerFilter && opt.c.toLowerCase().indexOf(lowerFilter) === -1) return;
        var item = document.createElement('div');
        item.style.cssText = 'padding:6px 12px;cursor:pointer;';
        item.textContent = opt.c;
        item.dataset.key = opt.k;
        if (opt.k === keyInput.value) {
          item.style.fontWeight = '600';
          item.style.background = 'var(--kx-accent-bg)';
        }
        item.addEventListener('click', function() {
          keyInput.value = opt.k;
          if (displayInput) displayInput.value = opt.c;
          overlay.remove();
        });
        item.addEventListener('mouseenter', function() {
          item.style.background = 'var(--kx-accent-bg)';
        });
        item.addEventListener('mouseleave', function() {
          if (opt.k !== keyInput.value)
            item.style.background = '';
        });
        list.appendChild(item);
      });
    }

    renderOptions('');
    searchInput.addEventListener('input', function() {
      renderOptions(searchInput.value);
    });

    body.appendChild(list);
    popup.appendChild(body);
    overlay.appendChild(popup);

    // Close on overlay click
    overlay.addEventListener('click', function(e) {
      if (e.target === overlay) overlay.remove();
    });

    // Close on Escape key
    searchInput.addEventListener('keydown', function(e) {
      if (e.key === 'Escape') overlay.remove();
    });

    document.body.appendChild(overlay);
    searchInput.focus();
  },

  /**
   * Called when user clicks Select in a lookup dialog or double-clicks a row.
   * Reads the selected key and caption, sets them on the calling form field,
   * and closes the lookup dialog.
   * @param {string} lookupAlias - The aliased view name (e.g. "lkp_Employees")
   */
  onLookupSelect: function(lookupAlias) {
    var keyInput = document.getElementById('kx-selected-key-' + lookupAlias);
    var cvInput = document.getElementById('kx-lookup-cv-' + lookupAlias);
    var cfInput = document.getElementById('kx-lookup-cf-' + lookupAlias);
    if (!keyInput || !cvInput || !cfInput) return;

    var selectedKey = keyInput.value;
    if (!selectedKey) return;

    var callbackView = cvInput.value;
    var callbackField = cfInput.value;

    // Extract the FK value from the key string (e.g. "EMPLOYEE_ID=abc123")
    var fkValue = '';
    var parts = selectedKey.split('&');
    if (parts.length > 0) {
      var pair = parts[0].split('=');
      if (pair.length === 2) fkValue = decodeURIComponent(pair[1]);
    }

    // Read caption from the selected row's data-caption attribute
    var selectedRow = document.querySelector(
      '#kx-list-body-' + lookupAlias + ' .kx-row-selected');
    var caption = selectedRow ? (selectedRow.dataset.caption || '') : '';

    // Set values on the calling form's fields
    var formKeyInput = document.getElementById(
      'kx-field-' + callbackView + '-' + callbackField + '-key');
    var formDisplayInput = document.getElementById(
      'kx-field-' + callbackView + '-' + callbackField + '-display');
    if (formKeyInput) formKeyInput.value = fkValue;
    if (formDisplayInput) formDisplayInput.value = caption;

    // Close the lookup dialog
    kxForm.closeLookup(lookupAlias);
  },

  /**
   * Closes a lookup dialog by removing its overlay element.
   * @param {string} lookupAlias - The aliased view name (e.g. "lkp_Employees")
   */
  closeLookup: function(lookupAlias) {
    var overlay = document.getElementById('kx-' + lookupAlias);
    if (overlay) overlay.remove();
  },

  /**
   * Switches between unified tabs (form pages + detail tabs).
   * @param {string} viewName - View name (used to scope DOM queries)
   * @param {number} tabIndex - Zero-based tab index to activate
   * @param {number} fieldPageCount - Number of form field pages (detail tabs start after this)
   */
  switchTab: function(viewName, tabIndex, fieldPageCount) {
    var form = document.getElementById('kx-form-' + viewName);
    if (!form) return;
    // Lock the form body size so the dialog doesn't shrink when hiding pages
    var body = form.querySelector('.kx-form-body');
    if (body) {
      body.style.minWidth = body.offsetWidth + 'px';
      body.style.minHeight = body.offsetHeight + 'px';
    }
    // Switch active tab button
    form.querySelectorAll('.kx-form-tab').forEach(function(t, i) {
      t.classList.toggle('kx-form-tab-active', i === tabIndex);
    });
    // Hide all pages
    form.querySelectorAll('.kx-form-page').forEach(function(p) { p.style.display = 'none'; });
    if (tabIndex < fieldPageCount) {
      // Form field page
      var page = document.getElementById('kx-form-page-' + viewName + '-' + tabIndex);
      if (page) page.style.display = '';
    } else {
      // Detail page — lazy load if empty
      var detailIdx = tabIndex - fieldPageCount;
      var panel = document.getElementById('kx-detail-' + viewName + '-' + detailIdx);
      if (panel) {
        panel.style.display = '';
        if (!panel.children.length) {
          var keyInput = form.querySelector('input[name="_key"]');
          kxForm.loadDetailTab(viewName, detailIdx, keyInput ? keyInput.value : '');
        }
      }
    }
  },

  /**
   * Backward-compatible alias: switches form field pages only.
   * Used by save validation to show the page containing an invalid field.
   * @param {string} viewName - View name
   * @param {number} pageIndex - Zero-based form page index
   */
  switchPage: function(viewName, pageIndex) {
    var form = document.getElementById('kx-form-' + viewName);
    if (!form) return;
    var n = form.querySelectorAll('.kx-form-page:not(.kx-detail-page)').length;
    kxForm.switchTab(viewName, pageIndex, n);
  },

  /**
   * Loads detail tab content via AJAX (lazy loading).
   * Fetches the detail grid HTML from the server and injects it into the tab panel.
   * @param {string} viewName - Master view name
   * @param {number} tabIndex - Zero-based detail table index
   * @param {string} masterKey - URL-encoded master record key string
   */
  loadDetailTab: function(viewName, tabIndex, masterKey) {
    var panelId = 'kx-detail-' + viewName + '-' + tabIndex;
    var panel = document.getElementById(panelId);
    if (!panel) return;
    // Mark as loading
    panel.innerHTML = '<div style="padding:16px;color:var(--kx-text-muted)">Loading...</div>';
    kxFetchWithTimeout('kx/view/' + viewName + '/detail/' + tabIndex + '/data?key=' + encodeURIComponent(masterKey))
      .then(function(r) { return r.text(); })
      .then(function(html) {
        panel.innerHTML = html;
        // Process any HTMX directives in the loaded content
        if (typeof htmx !== 'undefined') htmx.process(panel);
        // Execute inline scripts
        panel.querySelectorAll('script').forEach(function(script) {
          var s = document.createElement('script');
          s.textContent = script.textContent;
          document.head.appendChild(s);
          document.head.removeChild(s);
        });
      })
      .catch(function(err) {
        panel.innerHTML = '<div style="padding:16px;color:var(--kx-error)">Error loading detail: ' + err.message + '</div>';
      });
  },

  /**
   * Context map: tracks which detail grid context a form was opened from.
   * Used by onSaveSuccess to reload the correct detail tab after saving.
   */
  _detailContext: {},

  /**
   * Opens a form from a detail grid context.
   * Registers detail context for post-save refresh, then opens the form.
   * @param {string} detailView - Real detail view name (e.g. "Phases")
   * @param {string} op - Operation: add, edit, view, dup
   * @param {string} aliasView - Detail grid alias (e.g. "dtl_Projects_0")
   * @param {number} tabIndex - Detail tab index
   * @param {string} masterView - Master view name (e.g. "Projects")
   * @param {string} masterKey - URL-encoded master record key
   * @param {string} fkField - FK field name in detail model (for add pre-fill)
   */
  openDetailForm: function(detailView, op, aliasView, tabIndex, masterView, masterKey, fkField) {
    // Register context for post-save refresh
    kxForm._detailContext[detailView] = {
      masterView: masterView,
      tabIndex: tabIndex,
      masterKey: masterKey
    };
    // Build FK extra params: fkField always (read-only in form), masterKey for add (pre-fill)
    var extra = '';
    if (fkField) {
      extra = 'fkField=' + encodeURIComponent(fkField);
      if (op === 'add' && masterKey) {
        extra += '&masterKey=' + encodeURIComponent(masterKey);
      }
    }
    // Get key from alias grid for edit/view/dup
    var key = '';
    if (op !== 'add') {
      key = kxGrid.getSelectedKey(aliasView);
      if (!key) return;
    }
    kxGrid.openForm(detailView, op, key, extra);
  },

  /**
   * Deletes a record from a detail grid, then reloads the detail tab.
   * @param {string} detailView - Real detail view name
   * @param {string} aliasView - Detail grid alias
   * @param {number} tabIndex - Detail tab index
   * @param {string} masterView - Master view name
   * @param {string} masterKey - Master record key
   * @param {string} confirmTitle - Confirmation dialog title
   * @param {string} confirmMsg - Confirmation message
   * @param {string} yesLabel - Yes button label
   * @param {string} noLabel - No button label
   */
  deleteDetailRecord: function(detailView, aliasView, tabIndex, masterView, masterKey,
    confirmTitle, confirmMsg, yesLabel, noLabel) {
    var key = kxGrid.getSelectedKey(aliasView);
    if (!key) return;
    kxGrid.showConfirm(confirmTitle, confirmMsg, yesLabel, noLabel, function() {
      var loadingEl = document.getElementById('kx-loading');
      if (loadingEl) loadingEl.classList.add('kx-busy');
      // Delete in-memory (mark as rsDeleted in session store, not DB)
      kxFetchWithTimeout('kx/view/' + masterView + '/detail/' + tabIndex + '/delete', {
        method: 'POST',
        body: new URLSearchParams({ key: key }),
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-KittoX': 'true' }
      })
      .then(function(response) {
        if (!response.ok) throw new Error('Delete failed (status ' + response.status + ')');
        // Reload the detail tab from session store
        kxForm.loadDetailTab(masterView, tabIndex, masterKey);
        // Enable Save All on the master form
        var masterForm = document.getElementById('kx-form-' + masterView);
        if (masterForm) {
          var saveAllBtn = masterForm.querySelector('.kx-form-btn-saveall');
          if (saveAllBtn) saveAllBtn.disabled = false;
        }
      })
      .catch(function(err) {
        kxGrid.showConfirm('Error', err.message, 'OK', '', null);
      })
      .finally(function() {
        if (loadingEl) loadingEl.classList.remove('kx-busy');
      });
    });
  },

  /**
   * Opens the file picker for an IsPicture blob field.
   * @param {string} viewName - View name
   * @param {string} fieldName - Blob field name
   */
  uploadPicture: function(viewName, fieldName) {
    document.getElementById('kx-pic-file-' + viewName + '-' + fieldName).click();
  },

  /**
   * Handles file selection for an IsPicture blob field.
   * Shows instant client-side preview via FileReader.
   * @param {string} viewName - View name
   * @param {string} fieldName - Blob field name
   */
  onPictureSelected: function(viewName, fieldName) {
    var fileInput = document.getElementById('kx-pic-file-' + viewName + '-' + fieldName);
    var file = fileInput.files[0];
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function(e) {
      var img = document.getElementById('kx-pic-img-' + viewName + '-' + fieldName);
      img.src = e.target.result;
      img.style.display = '';
      // Reset clear flag
      document.getElementById('kx-pic-clear-' + viewName + '-' + fieldName).value = '';
      // Enable download/clear buttons
      var editor = document.getElementById('kx-pic-' + viewName + '-' + fieldName);
      editor.querySelectorAll('.kx-toolbar-btn').forEach(function(btn) { btn.disabled = false; });
    };
    reader.readAsDataURL(file);
  },

  /**
   * Clears the image preview and sets the clear flag for an IsPicture blob field.
   * @param {string} viewName - View name
   * @param {string} fieldName - Blob field name
   */
  clearPicture: function(viewName, fieldName) {
    var img = document.getElementById('kx-pic-img-' + viewName + '-' + fieldName);
    img.src = '';
    img.style.display = 'none';
    document.getElementById('kx-pic-clear-' + viewName + '-' + fieldName).value = '1';
    document.getElementById('kx-pic-file-' + viewName + '-' + fieldName).value = '';
  },

  /**
   * Downloads the blob image for an IsPicture field (opens in new tab).
   * @param {string} viewName - View name
   * @param {string} fieldName - Blob field name
   */
  downloadPicture: function(viewName, fieldName) {
    var form = document.getElementById('kx-form-' + viewName);
    if (!form) return;
    var keyInput = form.querySelector('input[name="_key"]');
    if (keyInput && keyInput.value) {
      window.open('kx/view/' + viewName + '/blob/' + fieldName +
        '?key=' + encodeURIComponent(keyInput.value) + '&download=1');
    }
  },

  /**
   * Clears the value of an IsLarge reference lookup field.
   * @param {string} viewName - View name
   * @param {string} fieldName - Reference field aliased name (e.g. "EMPLOYEE")
   */
  clearLookup: function(viewName, fieldName) {
    var keyInput = document.getElementById('kx-field-' + viewName + '-' + fieldName + '-key');
    var displayInput = document.getElementById('kx-field-' + viewName + '-' + fieldName + '-display');
    if (keyInput) keyInput.value = '';
    if (displayInput) displayInput.value = '';
  },

  /**
   * On focus: strips the currency symbol so the user edits the raw number.
   * @param {HTMLInputElement} input - The input element
   * @param {string} symbol - Currency symbol (e.g. '€')
   */
  focusCurrency: function(input, symbol) {
    if (!symbol) return;
    var val = input.value.trim();
    if (val.indexOf(symbol) === 0) {
      input.value = val.substring(symbol.length).trim();
    }
  },

  /**
   * On blur: formats with decimal places and prepends the currency symbol.
   * @param {HTMLInputElement} input - The input element
   * @param {string} decSep - Locale decimal separator (',' or '.')
   * @param {number} decimals - Number of decimal places (e.g. 2)
   * @param {string} symbol - Currency symbol (e.g. '€')
   */
  formatCurrency: function(input, decSep, decimals, symbol) {
    var val = input.value.trim();
    if (val === '') return;
    // Strip symbol if still present
    if (symbol && val.indexOf(symbol) === 0) {
      val = val.substring(symbol.length).trim();
    }
    // Normalize to dot decimal separator for parsing
    var normalized = val.replace(decSep === ',' ? /,/ : /\./, '.');
    var num = parseFloat(normalized);
    if (isNaN(num)) return;
    // Format with fixed decimal places
    var formatted = num.toFixed(decimals);
    // Convert back to locale decimal separator
    if (decSep !== '.') {
      formatted = formatted.replace('.', decSep);
    }
    // Prepend currency symbol
    if (symbol) {
      formatted = symbol + ' ' + formatted;
    }
    input.value = formatted;
  }
};

/**
 * kxChart — Chart.js integration for KittoX ChartPanel controller.
 * Manages Chart.js instances, initialization, refresh, and cleanup.
 */
var kxChart = {
  _instances: {},  // viewName -> Chart instance

  /**
   * Initializes a Chart.js chart on the canvas for the given view.
   * Destroys any previous instance (e.g. when tab is re-opened).
   */
  init: function(viewName, config) {
    var canvas = document.getElementById('kx-chart-canvas-' + viewName);
    if (!canvas) return;
    // Read theme text color from CSS custom properties so charts match the theme
    var textColor = getComputedStyle(document.documentElement)
      .getPropertyValue('--kx-text').trim() || '#333';
    Chart.defaults.color = textColor;
    // Destroy previous instance if it exists
    if (kxChart._instances[viewName]) {
      kxChart._instances[viewName].destroy();
    }
    kxChart._instances[viewName] = new Chart(canvas.getContext('2d'), config);
  },

  /**
   * Refreshes chart data from the server.
   * Fetches updated labels/data via JSON endpoint, updates chart with animation,
   * and refreshes the sidebar grid.
   */
  refresh: function(viewName) {
    var loadingEl = document.getElementById('kx-loading');
    if (loadingEl) loadingEl.classList.add('kx-busy');
    kxFetchWithTimeout('kx/view/' + viewName + '/chart-data', {
      headers: { 'X-KittoX': 'true' }
    })
    .then(function(r) { return r.json(); })
    .then(function(data) {
      var chart = kxChart._instances[viewName];
      if (chart) {
        chart.data.labels = data.labels;
        chart.data.datasets[0].data = data.data;
        chart.update();  // animated transition
      }
      // Update grid sidebar
      var grid = document.getElementById('kx-chart-grid-' + viewName);
      if (grid && data.gridHtml) grid.innerHTML = data.gridHtml;
    })
    .catch(function(err) {
      kxGrid.showConfirm('Error', err.message, 'OK', '', null);
    })
    .finally(function() {
      if (loadingEl) loadingEl.classList.remove('kx-busy');
    });
  },

  /**
   * Destroys a chart instance and releases resources.
   * Called when a tab is closed.
   */
  destroy: function(viewName) {
    if (kxChart._instances[viewName]) {
      kxChart._instances[viewName].destroy();
      delete kxChart._instances[viewName];
    }
  }
};

/**
 * kxCalendar — EventCalendar integration for KittoX CalendarPanel controller.
 * Manages EventCalendar instances, event click/date click, and CRUD integration.
 */
var kxCalendar = {
  _instances: {},      // viewName -> EventCalendar instance
  _selectedKey: {},    // viewName -> currently selected event key
  _selectedEl: {},     // viewName -> currently selected DOM element
  _lastClickTime: {},  // viewName -> timestamp of last click (for double-click detection)
  _lastClickKey: {},   // viewName -> key of last clicked event

  /**
   * Initializes an EventCalendar on the container for the given view.
   */
  init: function(viewName, options) {
    var container = document.getElementById('kx-calendar-' + viewName);
    if (!container || typeof EventCalendar === 'undefined') return;

    // Destroy previous instance if it exists
    if (kxCalendar._instances[viewName]) {
      EventCalendar.destroy(kxCalendar._instances[viewName]);
    }
    kxCalendar._selectedKey[viewName] = '';

    var dataUrl = options.dataUrl || '';
    var eventTypes = options.eventTypes || {};

    var ecOptions = {
      view: options.view || 'timeGridWeek',
      headerToolbar: {
        start: 'prev,next today',
        center: 'title',
        end: 'dayGridMonth,timeGridWeek,timeGridDay'
      },
      slotMinTime: options.slotMinTime || '00:00',
      slotMaxTime: options.slotMaxTime || '24:00',
      nowIndicator: true,
      eventStartEditable: false,
      eventDurationEditable: false,
      selectable: false,
      eventSources: [{
        url: dataUrl,
        extraParams: function() {
          return {};
        }
      }],
      eventContent: function(info) {
        var event = info.event;
        var nodes = [];
        // Time
        var timeEl = document.createElement('div');
        timeEl.className = 'ec-event-time';
        timeEl.textContent = info.timeText || '';
        nodes.push(timeEl);
        // Title
        var titleEl = document.createElement('div');
        titleEl.className = 'ec-event-title';
        titleEl.textContent = event.title || '';
        nodes.push(titleEl);
        // Notes (if present)
        var notes = event.extendedProps && event.extendedProps.notes;
        if (notes) {
          var notesEl = document.createElement('div');
          notesEl.className = 'ec-event-notes';
          notesEl.textContent = notes;
          nodes.push(notesEl);
        }
        return { domNodes: nodes };
      },
      eventClick: function(info) {
        kxCalendar.onEventClick(viewName, info, options);
      },
      dateClick: function(info) {
        kxCalendar.onDateClick(viewName, info, options);
      }
    };

    var ec = EventCalendar.create(container, ecOptions);
    kxCalendar._instances[viewName] = ec;
  },

  /**
   * Handles single click on an event — selects it (highlight).
   * Double-click opens the edit/view form.
   */
  onEventClick: function(viewName, info, options) {
    var event = info.event;
    var key = (event.extendedProps && event.extendedProps.key) || '';
    if (!key) return;

    // Highlight the clicked event
    kxCalendar._selectEvent(viewName, info.el, key);

    // Double-click detection: open form on second click within 400ms
    var now = Date.now();
    var last = kxCalendar._lastClickTime[viewName] || 0;
    var lastKey = kxCalendar._lastClickKey[viewName] || '';
    kxCalendar._lastClickTime[viewName] = now;
    kxCalendar._lastClickKey[viewName] = key;

    if (key === lastKey && (now - last) < 400) {
      // Double-click — open form
      kxCalendar._lastClickTime[viewName] = 0; // reset to avoid triple-trigger
      var op = options.allowEdit ? 'edit' : (options.allowView ? 'view' : '');
      if (op) kxCalendar._openForm(viewName, op, key);
    }
  },

  /**
   * Handles click on an empty date cell — opens add form.
   */
  onDateClick: function(viewName, info, options) {
    // Deselect any selected event when clicking empty space
    kxCalendar._selectEvent(viewName, null, '');
    if (!options.allowAdd) return;
    // Pass the clicked date as a query parameter for the form to preset
    kxCalendar._openForm(viewName, 'add', '', info.dateStr || '');
  },

  /**
   * Opens add form (from toolbar button).
   */
  openAddForm: function(viewName) {
    kxCalendar._openForm(viewName, 'add', '');
  },

  /**
   * Opens edit form for the currently selected event (from toolbar button).
   */
  openEditForm: function(viewName) {
    var key = kxCalendar._selectedKey[viewName];
    if (!key) return;
    kxCalendar._openForm(viewName, 'edit', key);
  },

  /**
   * Opens view form for the currently selected event (from toolbar button).
   */
  openViewForm: function(viewName) {
    var key = kxCalendar._selectedKey[viewName];
    if (!key) return;
    kxCalendar._openForm(viewName, 'view', key);
  },

  /**
   * Deletes the currently selected event after confirmation.
   */
  deleteEvent: function(viewName, title, confirmMsg, yesLabel, noLabel) {
    var key = kxCalendar._selectedKey[viewName];
    if (!key) return;

    kxGrid.showConfirm(title, confirmMsg, yesLabel, noLabel, function() {
      var loadingEl = document.getElementById('kx-loading');
      if (loadingEl) loadingEl.classList.add('kx-busy');
      kxFetchWithTimeout('kx/view/' + viewName + '/delete', {
        method: 'POST',
        headers: {
          'X-KittoX': 'true',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: 'key=' + encodeURIComponent(key)
      })
      .then(function() {
        kxCalendar._selectedKey[viewName] = '';
        kxCalendar._updateToolbarButtons(viewName);
        kxCalendar.refresh(viewName);
      })
      .catch(function(err) {
        kxGrid.showConfirm('Error', err.message, 'OK', '', null);
      })
      .finally(function() {
        if (loadingEl) loadingEl.classList.remove('kx-busy');
      });
    });
  },

  /**
   * Internal: opens form dialog with given operation and key.
   */
  _openForm: function(viewName, op, key, dateStr) {
    var url = 'kx/view/' + viewName + '/form?op=' + op;
    if (key) url += '&key=' + encodeURIComponent(key);
    if (dateStr) url += '&date=' + encodeURIComponent(dateStr);
    var loadingEl = document.getElementById('kx-loading');
    if (loadingEl) loadingEl.classList.add('kx-busy');
    kxFetchWithTimeout(url, { headers: { 'X-KittoX': 'true' } })
      .then(function(r) { return r.text(); })
      .then(function(html) {
        var div = document.createElement('div');
        div.innerHTML = html;
        if (div.firstElementChild) {
          document.body.appendChild(div.firstElementChild);
          kxForm.initHtmlEditors(viewName);
        }
      })
      .catch(function(err) {
        kxGrid.showConfirm('Error', err.message, 'OK', '', null);
      })
      .finally(function() {
        if (loadingEl) loadingEl.classList.remove('kx-busy');
      });
  },

  /**
   * Refreshes the calendar by re-fetching events from the server.
   */
  refresh: function(viewName) {
    // Clear selection (DOM elements will be recreated by refetch)
    kxCalendar._selectEvent(viewName, null, '');
    var ec = kxCalendar._instances[viewName];
    if (ec) {
      ec.refetchEvents();
    }
  },

  /**
   * Selects (highlights) an event element. Pass null/empty to deselect.
   */
  _selectEvent: function(viewName, el, key) {
    // Remove previous highlight
    var prevEl = kxCalendar._selectedEl[viewName];
    if (prevEl) prevEl.classList.remove('kx-cal-event-selected');

    // Set new selection
    kxCalendar._selectedKey[viewName] = key;
    kxCalendar._selectedEl[viewName] = el;

    if (el) {
      el.classList.add('kx-cal-event-selected');
      // Bring to front among overlapping events
      el.style.zIndex = '10';
      if (prevEl && prevEl !== el) prevEl.style.zIndex = '';
    } else if (prevEl) {
      prevEl.style.zIndex = '';
    }

    kxCalendar._updateToolbarButtons(viewName);
  },

  /**
   * Updates toolbar button states based on current selection.
   */
  _updateToolbarButtons: function(viewName) {
    var toolbar = document.getElementById('kx-cal-toolbar-' + viewName);
    if (!toolbar) return;
    var hasSelection = !!kxCalendar._selectedKey[viewName];
    var buttons = toolbar.querySelectorAll('.kx-cal-requires-selection');
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].disabled = !hasSelection;
    }
  },

  /**
   * Destroys a calendar instance and releases resources.
   */
  destroy: function(viewName) {
    if (kxCalendar._instances[viewName]) {
      EventCalendar.destroy(kxCalendar._instances[viewName]);
      delete kxCalendar._instances[viewName];
      delete kxCalendar._selectedKey[viewName];
      delete kxCalendar._selectedEl[viewName];
      delete kxCalendar._lastClickTime[viewName];
      delete kxCalendar._lastClickKey[viewName];
    }
  }
};

// After HTMX settles, force Chart.js to recalculate dimensions.
// Chart.js v4 uses ResizeObserver (not window resize), so we must call .resize()
// directly on each instance after the flex layout has settled.
(document.body || document.documentElement).addEventListener('htmx:afterSettle', function(evt) {
  if (typeof kxChart !== 'undefined' && Object.keys(kxChart._instances).length > 0) {
    setTimeout(function() {
      for (var name in kxChart._instances) {
        if (kxChart._instances[name]) {
          kxChart._instances[name].resize();
        }
      }
    }, 150);
  }
});

// After HTMX swaps new tbody/card content, clear the row selection and disable buttons.
// Also call htmx.process() so HTMX attributes inside card templates get activated.
(document.body || document.documentElement).addEventListener('htmx:afterSwap', function(evt) {
  var target = evt.detail.target;
  if (target && target.id && target.id.indexOf('kx-list-body-') === 0) {
    // Direct tbody swap (sort, page, filter, delete)
    var viewName = target.id.replace('kx-list-body-', '');
    kxGrid.clearSelection(viewName);
    kxGrid.applyRowClasses(viewName);
    htmx.process(target);
  } else if (target) {
    // Initial render: target is tab pane containing the grid; find tbodys inside
    target.querySelectorAll('tbody[data-row-class-provider]').forEach(function(tbody) {
      var viewName = tbody.id.replace('kx-list-body-', '');
      kxGrid.applyRowClasses(viewName);
    });
  }
});

