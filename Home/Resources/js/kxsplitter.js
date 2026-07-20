/*!
  kxsplitter.js — part of KittoX. Copyright 2012-2026 Ethea S.r.l.
  Licensed under the Apache License, Version 2.0 — http://www.apache.org/licenses/LICENSE-2.0
*/
/**
 * KittoX region splitter — drag-to-resize for border panel regions.
 *
 * Usage: add a <div class="kx-splitter" data-direction="horizontal|vertical">
 * inside a region div. The splitter resizes its parentElement on drag.
 *
 * For horizontal splitters (West/East): changes the parent's width.
 * For vertical splitters (North/South): changes the parent's height.
 *
 * data-direction: "horizontal" (West/East) or "vertical" (North/South)
 * data-side: "end" (West/North — splitter on right/bottom edge, drag increases)
 *            "start" (East/South — splitter on left/top edge, drag reverses)
 */
(function () {
  'use strict';

  document.addEventListener('pointerdown', function (e) {
    var splitter = e.target.closest('.kx-splitter');
    if (!splitter) return;

    var region = splitter.parentElement;
    if (!region) return;

    // Don't resize when the region is collapsed
    if (region.classList.contains('kx-region-collapsed')) return;

    var isHorizontal = splitter.dataset.direction === 'horizontal';
    var sideEnd = splitter.dataset.side === 'end';
    var startPos = isHorizontal ? e.clientX : e.clientY;
    var startSize = isHorizontal ? region.offsetWidth : region.offsetHeight;

    e.preventDefault();
    splitter.setPointerCapture(e.pointerId);
    document.body.style.cursor = isHorizontal ? 'col-resize' : 'row-resize';
    document.body.style.userSelect = 'none';

    function onMove(ev) {
      var delta = (isHorizontal ? ev.clientX : ev.clientY) - startPos;
      if (!sideEnd) delta = -delta;
      var newSize = Math.max(50, startSize + delta);
      region.style[isHorizontal ? 'width' : 'height'] = newSize + 'px';
    }

    function onUp() {
      document.removeEventListener('pointermove', onMove);
      document.removeEventListener('pointerup', onUp);
      document.body.style.cursor = '';
      document.body.style.userSelect = '';
    }

    document.addEventListener('pointermove', onMove);
    document.addEventListener('pointerup', onUp);
  });
})();
