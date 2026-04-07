/**
 * kxWizard — Step-by-step wizard navigation for KittoX.
 * Works with the TKXWizardController Delphi class.
 */
var kxWizard = {

  // viewName -> { stepCount, current, fieldPages: [[fieldName,...], ...] }
  _state: {},

  /**
   * Initialize wizard state.
   * @param {string} viewName
   * @param {number} stepCount
   * @param {Array<Array<string>>} fieldPages - array of field name arrays per step
   */
  init: function(viewName, stepCount, fieldPages) {
    this._state[viewName] = {
      stepCount: stepCount,
      current: 0,
      fieldPages: fieldPages || []
    };
    this._updateButtons(viewName);
    this._updateStepIndicators(viewName);
  },

  /**
   * Move to next step after validating current step fields.
   */
  next: function(viewName) {
    var st = this._state[viewName];
    if (!st || st.current >= st.stepCount - 1) return;

    // Validate current step's required fields
    if (!this._validateStep(viewName, st.current)) return;

    this._showStep(viewName, st.current + 1);
  },

  /**
   * Move to previous step.
   */
  back: function(viewName) {
    var st = this._state[viewName];
    if (!st || st.current <= 0) return;

    this._showStep(viewName, st.current - 1);
  },

  /**
   * Finish wizard: validate all steps, then POST form data.
   */
  finish: function(viewName) {
    var st = this._state[viewName];
    if (!st) return;

    // Validate ALL steps
    for (var i = 0; i < st.stepCount; i++) {
      if (!this._validateStep(viewName, i)) {
        // Switch to the failing step
        this._showStep(viewName, i);
        return;
      }
    }

    var form = document.getElementById('kx-wizard-' + viewName);
    if (!form) return;

    // Sync HTML editors if any
    if (typeof kxForm !== 'undefined' && kxForm.syncHtmlEditors) {
      kxForm.syncHtmlEditors(viewName);
    }

    // Prevent double-click
    var finishBtn = document.getElementById('kx-wizard-finish-' + viewName);
    if (finishBtn && finishBtn.disabled) return;
    if (finishBtn) finishBtn.disabled = true;

    // Collect form data
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

    var loadingEl = document.getElementById('kx-loading');
    if (loadingEl) loadingEl.classList.add('kx-busy');

    kxFetchWithTimeout('kx/view/' + viewName + '/wizard-finish', {
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
      kxGrid.showConfirm('Error', err.message || 'Wizard finish failed', 'OK', '', null);
    })
    .finally(function() {
      if (loadingEl) loadingEl.classList.remove('kx-busy');
      if (finishBtn) finishBtn.disabled = false;
    });
  },

  /**
   * Close wizard (same as form cancel).
   */
  cancel: function(viewName) {
    if (typeof kxForm !== 'undefined') {
      kxForm.cancel(viewName);
    } else {
      var overlay = document.getElementById('kx-form-overlay-' + viewName)
        || document.getElementById('kx-' + viewName);
      if (overlay) overlay.remove();
    }
  },

  /**
   * Called by server after successful wizard-finish.
   * Closes wizard and refreshes parent grid.
   */
  onFinishSuccess: function(viewName) {
    // Close wizard overlay
    var overlay = document.getElementById('kx-form-overlay-' + viewName)
      || document.getElementById('kx-' + viewName);
    if (overlay) overlay.remove();

    // Show toast notification
    kxGrid.showToast(window.KX_STRINGS.appTitle || '', window.KX_STRINGS.dataSaved || 'Data saved');

    // Refresh parent grid if exists
    var grid = document.querySelector('.kx-list-panel[data-view="' + viewName + '"] tbody');
    if (grid) {
      kxGrid.refresh(viewName);
    }

    // Clean up state
    delete this._state[viewName];
  },

  // --- Internal methods ---

  _showStep: function(viewName, stepIndex) {
    var st = this._state[viewName];
    if (!st) return;

    // Mark current step as completed if moving forward
    if (stepIndex > st.current) {
      var prevIndicator = document.querySelector(
        '#kx-wizard-' + viewName + ' .kx-wizard-step[data-step="' + st.current + '"]');
      if (prevIndicator) {
        prevIndicator.classList.remove('kx-wizard-step-active');
        prevIndicator.classList.add('kx-wizard-step-completed');
      }
    }

    // Hide all pages, show target
    var pages = document.querySelectorAll('#kx-wizard-' + viewName + ' .kx-wizard-page');
    for (var i = 0; i < pages.length; i++) {
      pages[i].style.display = (i === stepIndex) ? '' : 'none';
    }

    st.current = stepIndex;
    this._updateButtons(viewName);
    this._updateStepIndicators(viewName);

    // Update hidden _step field
    var stepInput = document.querySelector('#kx-wizard-' + viewName + ' input[name="_step"]');
    if (stepInput) stepInput.value = stepIndex;
  },

  _updateButtons: function(viewName) {
    var st = this._state[viewName];
    if (!st) return;

    var backBtn = document.getElementById('kx-wizard-back-' + viewName);
    var nextBtn = document.getElementById('kx-wizard-next-' + viewName);
    var finishBtn = document.getElementById('kx-wizard-finish-' + viewName);

    if (backBtn) backBtn.disabled = (st.current === 0);
    if (nextBtn) nextBtn.style.display = (st.current < st.stepCount - 1) ? '' : 'none';
    if (finishBtn) finishBtn.style.display = (st.current === st.stepCount - 1) ? '' : 'none';
  },

  _updateStepIndicators: function(viewName) {
    var st = this._state[viewName];
    if (!st) return;

    var steps = document.querySelectorAll('#kx-wizard-' + viewName + ' .kx-wizard-step');
    for (var i = 0; i < steps.length; i++) {
      steps[i].classList.remove('kx-wizard-step-active', 'kx-wizard-step-completed');
      if (i === st.current) {
        steps[i].classList.add('kx-wizard-step-active');
      } else if (i < st.current) {
        steps[i].classList.add('kx-wizard-step-completed');
      }
    }
  },

  /**
   * Validate required fields on a specific step.
   * Returns true if valid.
   */
  _validateStep: function(viewName, stepIndex) {
    var page = document.getElementById('kx-wizard-page-' + viewName + '-' + stepIndex);
    if (!page) return true; // HTML-only step, no fields

    var inputs = page.querySelectorAll('input[required], select[required], textarea[required]');
    for (var i = 0; i < inputs.length; i++) {
      if (!inputs[i].value && inputs[i].type !== 'checkbox') {
        // Make sure step is visible
        page.style.display = '';
        inputs[i].focus();
        inputs[i].reportValidity();
        return false;
      }
    }
    return true;
  }
};
