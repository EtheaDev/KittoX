/*!
 * kxchat.js - KittoX in-app help chat (panel, assistant bubble, polling v1)
 * Copyright 2012-2026 Ethea S.r.l. - Apache License 2.0
 *
 * Renders a floating assistant button in the bottom-right corner. Clicking it
 * opens a chat drawer: the user asks questions, the message is sent to
 * `kx/chat/send`, and the assistant reply - produced asynchronously on a server
 * worker - is retrieved by polling `kx/chat/poll/{id}`. Active only on the
 * authenticated home (body.kx-authenticated) and when HelpChat is enabled
 * (KX_CFG.helpChat). Uses fetch (not htmx) so transient poll errors never
 * surface the global htmx error dialog. SSE streaming can later replace polling.
 *
 * The header carries the name the assistant answers to (KX_CFG.helpChatName,
 * the same value that opens the system prompt), what can be done with the
 * conversation - copy it, print it, clear it - and the language of the
 * interface, which is also the language the model is told to answer in. The
 * keyboard reaches all of it: F1 opens and closes the panel, Enter sends,
 * Shift+Enter breaks the line, the arrows browse one's own past questions and
 * Escape closes.
 */
(function () {
  'use strict';

  // Poll cadence and cap: without a cap a server that keeps answering "pending"
  // would be polled for as long as the page lives. 900 polls is about 12 minutes,
  // past which a reply is not coming.
  var POLL_MS = 800;
  var MAX_POLLS = 900;
  var NOTE_MS = 3500;
  var ui = null;
  var isOpen = false;
  var loaded = false;
  var pending = null;   // id of the reply being waited for, null when none
  var langsLoaded = false;
  // The questions this user asked, oldest first, and where the arrows are in
  // them (-1: not browsing). Filled from the history as well, so reopening the
  // panel does not lose them.
  var asked = [];
  var askedPos = -1;

  function el(tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) { e.className = cls; }
    if (html != null) { e.innerHTML = html; }
    return e;
  }

  // Localized label from KX_STRINGS (injected server-side from gettext _()),
  // with an English fallback.
  function t(key, fallback) {
    return (window.KX_STRINGS && window.KX_STRINGS[key]) || fallback;
  }

  // The name the assistant answers to: configured in HelpChat/AssistantName and
  // served with the page, so the header and the system prompt say the same name.
  // It arrives encoded for HTML (the page template encodes what it writes into
  // the script), which is what the header wants and not what a tooltip or the
  // clipboard want: hence the second form below.
  function assistantName() {
    var cfg = window.KX_CFG || {};
    return (cfg.helpChatName && String(cfg.helpChatName).trim()) || t('help', 'Help');
  }

  // The same label as plain text: &#39; back to an apostrophe.
  function plain(html) {
    var box = document.createElement('textarea');
    box.innerHTML = String(html == null ? '' : html);
    return box.value;
  }

  // Themed Material SVG icon (CSS mask, currentColor) as an HTML string.
  // Attachments are off unless the application turned them on, and the list of
  // what the file dialog offers comes from the server too: the dialog must not
  // offer what the endpoint would refuse.
  // Which assistant the panel is talking to: the name of a profile declared in
  // the configuration, or '' for the one at the root. It is decided by the
  // server when the panel opens, from the screen the chat was opened from, and
  // sent back with everything that follows - the screen may well change while a
  // reply is being written, and that must not send the answer to another
  // conversation.
  var profile = '';

  // The profile as a field of a request, which is nothing at all in the usual
  // case of a single assistant.
  function withProfile(url) {
    return profile ? url + (url.indexOf('?') >= 0 ? '&' : '?') +
      'profile=' + encodeURIComponent(profile) : url;
  }

  function attachOn() {
    var cfg = window.KX_CFG || {};
    return cfg.helpChatAttach === true;
  }

  function acceptList() {
    var cfg = window.KX_CFG || {};
    return cfg.helpChatAccept || '';
  }

  function iconHtml(name, sizeCls) {
    var cfg = window.KX_CFG || { resPath: '', iconStyle: 'filled' };
    var url = (cfg.resPath || '') + '/icons/' + (cfg.iconStyle || 'filled') + '/' + name + '.svg';
    return '<span class="kx-icon ' + (sizeCls || 'kx-icon-sm') +
      '" style="-webkit-mask-image:url(\'' + url + '\');mask-image:url(\'' + url + '\')"></span>';
  }

  function headerButton(action, label, icon) {
    return '<button type="button" class="kx-chat-hbtn" data-action="' + action +
      '" title="' + label + '" aria-label="' + label + '">' + iconHtml(icon) + '</button>';
  }

  // Best-effort: the view the user is currently on (used as help context by a
  // DocuWiki/AI provider). Empty when it cannot be determined.
  function currentViewName() {
    // data-view is what the tab panel emits; the server turns the name into the
    // screen label and controller type, which the client has no business knowing.
    var active = document.querySelector('.kx-tab-active[data-view]');
    return active ? (active.getAttribute('data-view') || '') : '';
  }

  function build() {
    var cfg = window.KX_CFG || { resPath: '', iconStyle: 'filled' };
    var wrap = el('div', 'kx-chat');
    wrap.id = 'kx-chat';

    // Floating assistant button (themed Material SVG via CSS mask).
    var fab = el('button', 'kx-chat-fab');
    fab.type = 'button';
    fab.title = plain(assistantName());
    fab.setAttribute('aria-label', t('helpAssistant', 'Help assistant'));
    var iconUrl = (cfg.resPath || '') + '/icons/' + (cfg.iconStyle || 'filled') + '/support_agent.svg';
    var icon = el('span', 'kx-icon kx-icon-md');
    icon.style.webkitMaskImage = "url('" + iconUrl + "')";
    icon.style.maskImage = "url('" + iconUrl + "')";
    fab.appendChild(icon);

    // Drawer.
    var panel = el('div', 'kx-chat-panel');
    panel.innerHTML =
      '<div class="kx-chat-header">' +
        '<span class="kx-chat-title">' + assistantName() + '</span>' +
        '<span class="kx-chat-actions">' +
          // The flag of the interface language lands here, when there is more
          // than one language to choose from.
          '<span class="kx-chat-langslot"></span>' +
          headerButton('copy', t('copyConversation', 'Copy the conversation'), 'content_copy') +
          headerButton('print', t('print', 'Print'), 'print') +
          headerButton('clear', t('clear', 'Clear'), 'delete_sweep') +
          headerButton('close', t('close', 'Close'), 'close') +
        '</span>' +
      '</div>' +
      '<div class="kx-chat-body"></div>' +
      // The bar of the attachments: filled by the server, empty (and hidden by
      // the stylesheet) when there is nothing attached.
      '<div class="kx-chat-attbar"></div>' +
      '<div class="kx-chat-footer">' +
        (attachOn()
          ? '<input type="file" class="kx-chat-file" accept="' + acceptList() + '" multiple hidden>' +
            '<button type="button" class="kx-chat-clip" title="' + t('attach', 'Attach a file') +
            '" aria-label="' + t('attach', 'Attach a file') + '">' + iconHtml('attach_file') + '</button>'
          : '') +
        '<textarea class="kx-chat-input" rows="1" placeholder="' + t('chatPlaceholder', 'Ask about the application...') + '"></textarea>' +
        '<button type="button" class="kx-chat-send" title="' + t('send', 'Send') + '">' + iconHtml('send') + '</button>' +
        '<button type="button" class="kx-chat-send kx-chat-stop" title="' + t('stop', 'Stop') + '" hidden>' + iconHtml('stop') + '</button>' +
      '</div>';

    wrap.appendChild(fab);
    wrap.appendChild(panel);
    document.body.appendChild(wrap);

    var u = {
      wrap: wrap, fab: fab, panel: panel,
      body: panel.querySelector('.kx-chat-body'),
      input: panel.querySelector('.kx-chat-input'),
      send: panel.querySelector('.kx-chat-send'),
      stop: panel.querySelector('.kx-chat-stop'),
      langs: panel.querySelector('.kx-chat-langslot'),
      attbar: panel.querySelector('.kx-chat-attbar'),
      file: panel.querySelector('.kx-chat-file'),
      clip: panel.querySelector('.kx-chat-clip')
    };

    fab.addEventListener('click', function () { toggle(); });

    panel.querySelector('.kx-chat-header').addEventListener('click', function (ev) {
      var btn = ev.target.closest('.kx-chat-hbtn');
      if (!btn) { return; }
      var action = btn.getAttribute('data-action');
      if (action === 'close') { close(); }
      else if (action === 'clear') { clearConversation(); }
      else if (action === 'copy') { copyConversation(btn); }
      else if (action === 'print') { printConversation(); }
    });

    // The copy button of a single answer: the bubbles are replaced at every
    // poll, so the click is caught on the body and not on the button.
    u.body.addEventListener('click', function (ev) {
      var btn = ev.target.closest('.kx-chat-copy');
      if (!btn) { return; }
      copyAnswer(btn.closest('.kx-chat-msg'), btn);
    });

    u.send.addEventListener('click', function () { sendMessage(); });
    u.stop.addEventListener('click', function () { cancelReply(); });

    if (u.clip && u.file) {
      u.clip.addEventListener('click', function () { u.file.click(); });
      u.file.addEventListener('change', function () {
        uploadAll(u.file.files);
        // Cleared, or picking the same file twice in a row fires no event.
        u.file.value = '';
      });
    }

    // The chips are rewritten by the server at every change, so the click is
    // caught on the bar and not on the button.
    if (u.attbar) {
      u.attbar.addEventListener('click', function (ev) {
        var btn = ev.target.closest('.kx-chat-att-del');
        if (!btn) { return; }
        removeAttachment(btn.getAttribute('data-id'));
      });
    }

    // Dropping a file on the panel. The drag events must be stopped for the
    // drop to reach us at all, and the page's own default - opening the file -
    // is what happens otherwise.
    if (attachOn()) {
      ['dragenter', 'dragover'].forEach(function (name) {
        panel.addEventListener(name, function (ev) {
          if (!hasFiles(ev)) { return; }
          ev.preventDefault();
          panel.classList.add('kx-chat-dropping');
        });
      });
      ['dragleave', 'dragend'].forEach(function (name) {
        panel.addEventListener(name, function (ev) {
          // A drag over a child fires dragleave on the parent: only the one
          // that leaves the panel itself counts.
          if (ev.target !== panel && panel.contains(ev.target)) { return; }
          panel.classList.remove('kx-chat-dropping');
        });
      });
      panel.addEventListener('drop', function (ev) {
        if (!hasFiles(ev)) { return; }
        ev.preventDefault();
        panel.classList.remove('kx-chat-dropping');
        uploadAll(ev.dataTransfer.files);
      });
    }

    u.input.addEventListener('keydown', function (ev) {
      if (ev.key === 'ArrowUp' || ev.key === 'ArrowDown') {
        browseAsked(ev);
      } else if (ev.key === 'Enter' && !ev.shiftKey) {
        ev.preventDefault();
        sendMessage();
      } else if (ev.key === 'Escape') {
        close();
      }
    });
    // Auto-grow the textarea up to a few rows.
    u.input.addEventListener('input', function () {
      askedPos = -1;
      autosize();
    });

    return u;
  }

  function autosize() {
    ui.input.style.height = 'auto';
    ui.input.style.height = Math.min(ui.input.scrollHeight, 120) + 'px';
  }

  function toggle() { if (isOpen) { close(); } else { open(); } }

  function open() {
    isOpen = true;
    ui.wrap.classList.add('kx-chat-open');
    if (!loaded) { loadHistory(); }
    if (!langsLoaded) { loadLangs(); }
    // Not cached: a file may have been attached from another window of the same
    // user, and a reload must find what is still attached rather than an empty
    // bar while the files keep going out with every question.
    loadAttachments();
    setTimeout(function () { ui.input.focus(); }, 50);
  }

  function close() {
    isOpen = false;
    ui.wrap.classList.remove('kx-chat-open');
    // Stop waiting: a closed panel polling in the background is traffic nobody
    // asked for. Reopening reloads the conversation, reply included.
    stopWaiting();
    loaded = false;
  }

  // The language of the interface, as the switcher of the application renders
  // it: the chat has no language of its own, and picking one here reloads the
  // page exactly as picking it anywhere else does. The server answers with
  // nothing when there is only one language, and then no flag is shown.
  function loadLangs() {
    if (!ui.langs) { return; }
    langsLoaded = true;
    fetch('kx/chat/langs', { headers: { 'X-KittoX': 'true' }, credentials: 'same-origin' })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (html) { if (html) { ui.langs.innerHTML = html; } })
      .catch(function () { langsLoaded = false; });
  }

  // True when what is being dragged carries files: a drag of selected text
  // must not turn the panel into a drop target.
  function hasFiles(ev) {
    var dt = ev.dataTransfer;
    if (!dt) { return false; }
    if (dt.types) {
      for (var i = 0; i < dt.types.length; i++) {
        if (dt.types[i] === 'Files') { return true; }
      }
      return false;
    }
    return true;
  }

  function setBar(html) {
    if (!ui || !ui.attbar) { return; }
    ui.attbar.innerHTML = html || '';
  }

  function loadAttachments() {
    if (!attachOn() || !ui.attbar) { return; }
    fetch(withProfile('kx/chat/attachments'),
      { headers: { 'X-KittoX': 'true' }, credentials: 'same-origin' })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (html) { if (html !== null) { setBar(html); } })
      .catch(function () { /* the bar stays as it is */ });
  }

  // One file at a time, in order: the limits are counted on the server, and two
  // uploads racing for the last place would have one of them refused for a
  // reason the user cannot see coming.
  function uploadAll(files) {
    if (!attachOn() || !files || !files.length) { return; }
    var list = Array.prototype.slice.call(files);
    (function next() {
      if (!list.length) { return; }
      uploadOne(list.shift()).then(next);
    })();
  }

  function uploadOne(file) {
    var data = new FormData();
    data.append('file', file, file.name);
    if (ui.clip) { ui.clip.disabled = true; ui.clip.title = t('attaching', 'Sending...'); }
    return fetch(withProfile('kx/chat/attach'), {
      method: 'POST', body: data,
      headers: { 'X-KittoX': 'true' }, credentials: 'same-origin'
    })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (html) {
        if (html === null) { showNote(t('attachFailed', 'The file could not be attached.')); }
        else { setBar(html); }
      })
      .catch(function () { showNote(t('attachFailed', 'The file could not be attached.')); })
      .then(function () {
        if (ui.clip) { ui.clip.disabled = false; ui.clip.title = t('attach', 'Attach a file'); }
      });
  }

  function removeAttachment(id) {
    if (!id) { return; }
    fetch(withProfile('kx/chat/attach/' + encodeURIComponent(id) + '/remove'), {
      method: 'POST', headers: { 'X-KittoX': 'true' }, credentials: 'same-origin'
    })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (html) { if (html !== null) { setBar(html); } })
      .catch(function () { /* the bar stays as it is */ });
  }

  function stopWaiting() {
    pending = null;
    if (ui && ui.stop) { ui.stop.hidden = true; }
  }

  function startWaiting(msgId) {
    pending = msgId;
    if (ui && ui.stop) { ui.stop.hidden = false; }
  }

  function cancelReply() {
    if (!pending) { return; }
    var id = pending;
    fetch(withProfile('kx/chat/cancel/' + encodeURIComponent(id)), {
      method: 'POST', headers: { 'X-KittoX': 'true' }, credentials: 'same-origin'
    })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (html) {
        if (html) {
          var current = ui.body.querySelector('.kx-chat-msg[data-msgid="' + id + '"]');
          if (current) { current.outerHTML = html; }
          decorateAnswers();
        }
      })
      .catch(function () { /* the poll will show the outcome anyway */ });
  }

  function scrollToEnd() { ui.body.scrollTop = ui.body.scrollHeight; }

  // A line that says what happened (nothing to print, the clipboard refused):
  // shown in the conversation, part of no conversation, gone on its own.
  function showNote(text) {
    var note = el('div', 'kx-chat-note', text);
    ui.body.appendChild(note);
    scrollToEnd();
    setTimeout(function () { if (note.parentNode) { note.parentNode.removeChild(note); } }, NOTE_MS);
  }

  // The assistant the server says is answering, as the panel endpoint declares
  // it: its name goes in the header, and the profile travels with every later
  // request. The element itself is hidden and is dropped once read.
  function takeIdentity() {
    var ident = ui.body.querySelector('.kx-chat-ident');
    if (!ident) { return; }
    profile = ident.getAttribute('data-profile') || '';
    var name = ident.getAttribute('data-name') || '';
    var title = ui.panel.querySelector('.kx-chat-title');
    if (name && title) {
      title.textContent = name;
      ui.fab.title = name;
    }
    ident.parentNode.removeChild(ident);
  }

  function loadHistory() {
    // The screen decides which assistant answers, and only here: from this
    // point on the panel carries the profile it was given.
    var view = currentViewName();
    fetch('kx/chat/panel' + (view ? '?viewName=' + encodeURIComponent(view) : ''),
      { headers: { 'X-KittoX': 'true' }, credentials: 'same-origin' })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (t) {
        if (t == null) { return; }
        ui.body.innerHTML = t;
        takeIdentity();
        loaded = true;
        decorateAnswers();
        collectAsked();
        scrollToEnd();
        // A reply may still be in flight from before the panel was closed: pick
        // the waiting up again instead of leaving a bubble that never fills.
        var pendingEl = ui.body.querySelector('.kx-chat-msg[data-pending="1"]');
        if (pendingEl) {
          startWaiting(pendingEl.getAttribute('data-msgid'));
          pollReply(pendingEl.getAttribute('data-msgid'));
        }
      })
      .catch(function () { /* ignore */ });
  }

  function clearConversation() {
    fetch(withProfile('kx/chat/clear'),
      { method: 'POST', headers: { 'X-KittoX': 'true' }, credentials: 'same-origin' })
      .then(function (r) { if (!r.ok) { kxReportRequestError(r, clearConversation); return null; } return r.text(); })
      .then(function (t) {
        if (t != null) {
          ui.body.innerHTML = t;
          asked = [];
          askedPos = -1;
          // The server dropped the attachments with the conversation they
          // belonged to: the bar must not keep showing files that are gone.
          setBar('');
          scrollToEnd();
        }
      })
      .catch(function () { kxReportRequestError(undefined, clearConversation); });
  }

  function postSend(text, viewName, ctype) {
    var params = new URLSearchParams();
    params.set('message', text);
    params.set('viewName', viewName || '');
    params.set('controllerType', ctype || '');
    // Which assistant this question is for: the one the panel was opened with,
    // whatever screen is in front now.
    if (profile) { params.set('profile', profile); }

    fetch('kx/chat/send', {
      method: 'POST',
      headers: { 'X-KittoX': 'true', 'Content-Type': 'application/x-www-form-urlencoded' },
      credentials: 'same-origin',
      body: params.toString()
    })
      .then(function (r) {
        if (!r.ok) { kxReportRequestError(r, function () { postSend(text, viewName, ctype); }); return null; }
        return r.text();
      })
      .then(function (t) {
        if (t == null) { return; }
        loaded = true;
        ui.body.insertAdjacentHTML('beforeend', t);
        decorateAnswers();
        scrollToEnd();
        var pendingEl = ui.body.querySelector('.kx-chat-msg[data-pending="1"]');
        if (pendingEl) {
          startWaiting(pendingEl.getAttribute('data-msgid'));
          pollReply(pendingEl.getAttribute('data-msgid'));
        }
      })
      .catch(function () { kxReportRequestError(undefined, function () { postSend(text, viewName, ctype); }); });
  }

  function sendMessage() {
    var text = (ui.input.value || '').trim();
    if (!text) { return; }
    ui.input.value = '';
    ui.input.style.height = 'auto';
    remember(text);
    postSend(text, currentViewName(), '');
  }

  // ---- one's own questions, under the arrows --------------------------------
  function remember(text) {
    if (asked[asked.length - 1] !== text) { asked.push(text); }
    askedPos = -1;
  }

  function collectAsked() {
    var nodes = ui.body.querySelectorAll('.kx-chat-user .kx-chat-bubble');
    var i;
    asked = [];
    for (i = 0; i < nodes.length; i++) { asked.push(nodes[i].innerText); }
    askedPos = -1;
  }

  // ArrowUp goes back one question, ArrowDown comes forward and past the last
  // one leaves the box empty. While the box holds something that is not one of
  // them, the arrows belong to the text: they only take over from an empty box
  // or from the very beginning of it.
  function browseAsked(ev) {
    if (!asked.length) { return; }
    var atStart = ui.input.selectionStart === 0 && ui.input.selectionEnd === 0;
    if (askedPos < 0 && ui.input.value !== '' && !atStart) { return; }
    ev.preventDefault();
    if (askedPos < 0) { askedPos = asked.length; }
    if (ev.key === 'ArrowUp') { askedPos = Math.max(0, askedPos - 1); }
    else { askedPos = Math.min(asked.length, askedPos + 1); }
    ui.input.value = (askedPos >= asked.length) ? '' : asked[askedPos];
    autosize();
    var end = ui.input.value.length;
    try { ui.input.setSelectionRange(end, end); } catch (e) { /* ignore */ }
  }

  // ---- copy -----------------------------------------------------------------
  // Both flavours at once: the HTML keeps the bold, the lists and the tables for
  // a word processor, the plain text is what an editor or a plain mail gets.
  function copyRich(html, text, btn) {
    var done = function () { flashDone(btn); };
    var fallback = function () {
      // No ClipboardItem, or it was refused: select a hidden node and let the
      // browser put both flavours there, which is what copying a selection has
      // always done.
      var holder = document.createElement('div');
      holder.setAttribute('aria-hidden', 'true');
      holder.style.cssText = 'position:fixed;left:-9999px;top:0;white-space:pre-wrap;user-select:text';
      holder.innerHTML = html;
      document.body.appendChild(holder);
      var ok = false;
      var sel = window.getSelection();
      try {
        var range = document.createRange();
        range.selectNodeContents(holder);
        sel.removeAllRanges();
        sel.addRange(range);
        ok = document.execCommand('copy');
      } catch (e) { ok = false; }
      sel.removeAllRanges();
      document.body.removeChild(holder);
      if (ok) { done(); } else { showNote(t('copyFailed', 'Could not copy to the clipboard')); }
      ui.input.focus();
    };
    if (window.ClipboardItem && navigator.clipboard && navigator.clipboard.write) {
      try {
        var item = new ClipboardItem({
          'text/html': new Blob([html], { type: 'text/html' }),
          'text/plain': new Blob([text], { type: 'text/plain' })
        });
        navigator.clipboard.write([item]).then(done, fallback);
        return;
      } catch (e) { /* down to the selection */ }
    }
    fallback();
  }

  // The button says it took, for a moment, then goes back to what it was.
  function flashDone(btn) {
    if (!btn) { return; }
    var title = btn.title;
    var icon = btn.innerHTML;
    btn.innerHTML = iconHtml('check');
    btn.classList.add('kx-chat-done');
    btn.title = t('copied', 'Copied');
    btn.setAttribute('aria-label', btn.title);
    setTimeout(function () {
      btn.innerHTML = icon;
      btn.classList.remove('kx-chat-done');
      btn.title = title;
      btn.setAttribute('aria-label', title);
    }, 1400);
  }

  function bubbleOf(node) { return node ? node.querySelector('.kx-chat-bubble') : null; }

  function copyAnswer(node, btn) {
    var bubble = bubbleOf(node);
    if (!bubble) { return; }
    copyRich(bubble.innerHTML, bubble.innerText, btn);
  }

  // What a turn is made of, on both sides: the HTML of the bubble, and the text
  // the browser lays out from it - which is why a table copied as text still
  // reads as a table. A reply still being written, and the errors, are not the
  // conversation: the printed document leaves them out too.
  function copyConversation(btn) {
    var nodes = ui.body.querySelectorAll('.kx-chat-msg[data-msgid]');
    var html = '', text = '', i, node, bubble, who;
    for (i = 0; i < nodes.length; i++) {
      node = nodes[i];
      if (node.hasAttribute('data-pending') || node.hasAttribute('data-error')) { continue; }
      bubble = bubbleOf(node);
      if (!bubble) { continue; }
      who = node.classList.contains('kx-chat-user') ? t('question', 'Question') : assistantName();
      html += '<p><strong>' + who + '</strong></p>' + bubble.innerHTML;
      text += plain(who) + ':\n' + bubble.innerText + '\n\n';
    }
    if (!html) { showNote(t('nothingYet', 'There is nothing to print yet.')); return; }
    copyRich('<div>' + html + '</div>', text, btn);
  }

  // ---- print ----------------------------------------------------------------
  // The document is built by the server (kx/chat/print) and opens in a tab of
  // its own, where it prints itself: a drawer of a dark theme printed is a black
  // rectangle, so what goes on paper is a document and not this panel.
  function printConversation() {
    var nodes = ui.body.querySelectorAll('.kx-chat-msg[data-msgid]:not([data-pending]):not([data-error])');
    if (!nodes.length) { showNote(t('nothingYet', 'There is nothing to print yet.')); return; }
    window.open('kx/chat/print', '_blank', 'noopener');
  }

  // ---- the copy button of an answer -----------------------------------------
  // Added after every swap and after every poll that replaced a bubble: the node
  // that had one is gone. Only a finished answer gets it.
  function decorateAnswers() {
    var nodes = ui.body.querySelectorAll(
      '.kx-chat-assistant[data-msgid]:not([data-pending]):not([data-error])');
    var i, node, btn;
    for (i = 0; i < nodes.length; i++) {
      node = nodes[i];
      if (node.querySelector('.kx-chat-copy')) { continue; }
      btn = el('button', 'kx-chat-copy', iconHtml('content_copy'));
      btn.type = 'button';
      btn.title = t('copyAnswer', 'Copy this answer');
      btn.setAttribute('aria-label', btn.title);
      node.appendChild(btn);
    }
  }

  // Contextual trigger: a view's "?" help button opens the chat and asks a
  // contextual question, passing the controller type so the answer is anchored
  // to the right documentation page.
  function openForView(viewName, label, ctype, question) {
    if (!ui) { return; }
    open();
    postSend(question || label || 'Help', viewName, ctype);
  }

  function pollReply(msgId, left) {
    if (!msgId) { return; }
    if (msgId !== pending) { return; }           // panel closed, or another reply started
    if (left == null) { left = MAX_POLLS; }
    if (left <= 0) { stopWaiting(); return; }
    fetch(withProfile('kx/chat/poll/' + encodeURIComponent(msgId)), {
      headers: { 'X-KittoX': 'true' }, credentials: 'same-origin'
    })
      .then(function (r) { return r.ok ? r.text() : null; })
      .then(function (html) {
        if (html == null || html === '') { again(msgId, left - 1); return; }
        var current = ui.body.querySelector('.kx-chat-msg[data-msgid="' + msgId + '"]');
        if (current) { current.outerHTML = html; }
        scrollToEnd();
        // Keep polling while the (replaced) bubble is still pending.
        var refreshed = ui.body.querySelector('.kx-chat-msg[data-msgid="' + msgId + '"]');
        if (refreshed && refreshed.getAttribute('data-pending') === '1') {
          again(msgId, left - 1);
        } else {
          decorateAnswers();
          stopWaiting();
        }
      })
      .catch(function () { again(msgId, left - 1); });
  }

  function again(msgId, left) {
    setTimeout(function () { pollReply(msgId, left); }, POLL_MS);
  }

  function start() {
    if (!document.body.classList.contains('kx-authenticated')) { return; }
    if (!window.KX_CFG || window.KX_CFG.helpChat !== true) { return; }
    ui = build();
    // Delegated handler for the per-view "?" help buttons (rendered by List/Form
    // when HelpChat is enabled). Works for toolbars added later via AJAX.
    document.addEventListener('click', function (ev) {
      var b = ev.target.closest('.kx-help-chat-btn');
      if (!b) { return; }
      ev.preventDefault();
      openForView(b.getAttribute('data-view') || '', b.getAttribute('data-label') || '',
        b.getAttribute('data-ctype') || '', b.getAttribute('data-question') || '');
    });
    // F1 opens the help and closes it again, from anywhere in the application:
    // the key everyone tries first, and the browser's own help page is not what
    // the user is asking for here.
    document.addEventListener('keydown', function (ev) {
      if (ev.key !== 'F1' || ev.ctrlKey || ev.altKey || ev.shiftKey || ev.metaKey) { return; }
      ev.preventDefault();
      toggle();
    });
    // Allow server-rendered markup to trigger it directly too.
    window.kxChat = { openForView: openForView, open: open, close: close, toggle: toggle };
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start);
  } else {
    start();
  }
})();
