/* Keep DT columns aligned with their panel after hidden tabs/details are shown. */
(function () {
  'use strict';
  var pending = new Set();
  var frame = null;
  var widths = new WeakMap();
  var topScrolls = new WeakMap();
  function updateTopScroll(table) {
    var container = table.closest('.dataTables_scroll, .dt-scroll');
    if (!container) return;
    var body = container.querySelector('.dataTables_scrollBody, .dt-scroll-body');
    if (!body || !body.contains(table)) return;
    var state = topScrolls.get(table);
    if (!state) {
      var bar = document.createElement('div');
      bar.className = 'rrm-table-top-scroll';
      bar.tabIndex = 0;
      bar.setAttribute('role', 'region');
      bar.setAttribute('aria-label', 'Scroll table horizontally');
      var track = document.createElement('div');
      bar.appendChild(track);
      container.insertBefore(bar, container.firstChild);
      var fromTop = function () {
        if (Math.abs(body.scrollLeft - bar.scrollLeft) > 1) body.scrollLeft = bar.scrollLeft;
      };
      var fromBody = function () {
        if (Math.abs(bar.scrollLeft - body.scrollLeft) > 1) bar.scrollLeft = body.scrollLeft;
      };
      bar.addEventListener('scroll', fromTop, {passive: true});
      body.addEventListener('scroll', fromBody, {passive: true});
      state = {bar: bar, track: track, body: body, fromBody: fromBody};
      topScrolls.set(table, state);
    }
    state.bar.style.width = body.clientWidth + 'px';
    state.track.style.width = body.scrollWidth + 'px';
    state.bar.hidden = body.clientWidth === 0 || body.scrollWidth <= body.clientWidth + 1;
    state.bar.scrollLeft = body.scrollLeft;
  }
  var observer = window.ResizeObserver ? new ResizeObserver(function (entries) {
    entries.forEach(function (entry) {
      var node = entry.target;
      var width = node.getBoundingClientRect().width;
      var previous = widths.get(node);
      widths.set(node, width);
      if (width > 0 && node.getClientRects().length && (previous == null || Math.abs(width - previous) > 1)) schedule(node);
    });
  }) : null;
  function schedule(node) {
    pending.add(node || document);
    if (frame !== null) return;
    frame = requestAnimationFrame(function () {
      frame = null;
      var tables = new Set();
      pending.forEach(function (root) {
        if (root.matches && root.matches('table.dataTable')) tables.add(root);
        root.querySelectorAll('table.dataTable').forEach(function (table) { tables.add(table); });
      });
      pending.clear();
      tables.forEach(function (table) {
        if (!table.isConnected || !table.getClientRects().length || table.getBoundingClientRect().width === 0) return;
        if ($.fn.dataTable && $.fn.dataTable.isDataTable(table)) $(table).DataTable().columns.adjust();
        updateTopScroll(table);
      });
    });
  }
  function watch(table) {
    var widget = table.closest('.datatables');
    if (observer && widget) observer.observe(widget);
    schedule(widget || table);
  }
  function start() {
    if (!window.jQuery) return;
    $(document).on('init.dt.rrmWidth', function (event, settings) { watch(settings.nTable); });
    $(document).on('draw.dt.rrmWidth column-sizing.dt.rrmWidth', function (event, settings) {
      updateTopScroll(settings.nTable);
    });
    $(document).on('destroy.dt.rrmWidth', function (event, settings) {
      var state = topScrolls.get(settings.nTable);
      if (state) {
        state.body.removeEventListener('scroll', state.fromBody);
        state.bar.remove();
        topScrolls.delete(settings.nTable);
      }
      var widget = settings.nTable.closest('.datatables');
      if (observer && widget) observer.unobserve(widget);
    });
    $(document).on('shown.bs.tab.rrmWidth shiny:visualchange.rrmWidth shiny:idle.rrmWidth', function () { schedule(document); });
    document.addEventListener('toggle', function (event) {
      if (event.target.tagName === 'DETAILS' && event.target.open) schedule(event.target);
    }, true);
    window.addEventListener('resize', function () { schedule(document); });
    document.querySelectorAll('table.dataTable').forEach(watch);
  }
  document.addEventListener('click', function (event) {
    var button = event.target.closest('button:is(.rrm-alert-detail-button,.rrm-alert-link)[data-input][data-alert]');
    if (button && window.Shiny && Shiny.setInputValue) {
      Shiny.setInputValue(button.dataset.input, button.dataset.alert, {priority: 'event'});
    }
  }, true);
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true});
  else start();
}());
/* Show/hide panels and record detail rows (More filters, Manage workbook, row chevrons). */
document.addEventListener('click', function (event) {
  var button = event.target.closest('button[data-toggle-target]');
  if (!button) return;
  var target = document.getElementById(button.getAttribute('data-toggle-target'));
  if (!target) return;
  var open = button.getAttribute('aria-expanded') !== 'true';
  button.setAttribute('aria-expanded', String(open));
  target.hidden = !open;
  if (open && window.jQuery) window.jQuery(target).trigger('shown');
});
/* About the RRM: fit as many blocks as the panel holds, page the rest.
   A heading always moves with the block after it; a block taller than the panel gets a page of its own. */
function rrmPaginate(pager, keepPage) {
  var body = pager.querySelector('.rrm-pager-body'), nav = pager.querySelector('.rrm-pager-nav');
  var blocks = Array.prototype.slice.call(body.querySelectorAll(':scope > .rrm-flow-block'));
  if (!blocks.length || !pager.offsetParent) return;
  blocks.forEach(function (b) { b.hidden = false; b.classList.remove('rrm-page-start'); });
  /* Without a fixed panel height (narrow screens) everything is shown in one column. */
  if (getComputedStyle(pager).contain.indexOf('size') < 0) {
    nav.hidden = true; pager.setAttribute('data-pages', '1'); return;
  }
  nav.hidden = true;
  var room = body.clientHeight;
  var fitsAll = body.scrollHeight <= room + 1;
  if (!fitsAll) { nav.hidden = false; room = body.clientHeight; }
  var page = 1, used = 0;
  var height = function (b) { var cs = getComputedStyle(b); return b.offsetHeight + parseFloat(cs.marginTop) + parseFloat(cs.marginBottom); };
  for (var i = 0; i < blocks.length; i++) {
    var h = height(blocks[i]);
    if (blocks[i].tagName === 'H3' && blocks[i + 1]) h += height(blocks[i + 1]);
    if (used > 0 && used + h > room) { page++; used = 0; }
    blocks[i].setAttribute('data-page-of', page);
    blocks[i].classList.toggle('rrm-page-start', used === 0);
    used += height(blocks[i]);
    if (blocks[i].tagName === 'H3' && blocks[i + 1]) { i++; blocks[i].setAttribute('data-page-of', page); used += height(blocks[i]); }
  }
  pager.setAttribute('data-pages', String(page));
  var current = keepPage ? Math.min(page, Number(pager.getAttribute('data-page')) || 1) : 1;
  rrmShowPage(pager, current);
}
function rrmShowPage(pager, n) {
  var pages = Number(pager.getAttribute('data-pages')) || 1;
  pager.querySelectorAll('.rrm-pager-body > .rrm-flow-block').forEach(function (b) {
    b.hidden = pages > 1 && Number(b.getAttribute('data-page-of')) !== n;
  });
  pager.setAttribute('data-page', String(n));
  pager.querySelector('.rrm-pager-count').textContent = n + ' of ' + pages;
  pager.querySelector('.rrm-pager-prev').disabled = n === 1;
  pager.querySelector('.rrm-pager-next').disabled = n === pages;
  pager.querySelector('.rrm-pager-body').scrollTop = 0;
}
function rrmPaginateAll(keepPage) { document.querySelectorAll('.rrm-pager').forEach(function (p) { rrmPaginate(p, keepPage); }); }
document.addEventListener('click', function (event) {
  var button = event.target.closest('[data-pager-step]');
  if (!button) return;
  var pager = button.closest('.rrm-pager');
  var pages = Number(pager.getAttribute('data-pages')) || 1;
  var next = Math.min(pages, Math.max(1, (Number(pager.getAttribute('data-page')) || 1) + Number(button.getAttribute('data-pager-step'))));
  rrmShowPage(pager, next);
  pager.querySelector(next === pages ? '.rrm-pager-prev' : '.rrm-pager-next').focus();
});
(function () {
  var timer;
  var later = function (keep) { clearTimeout(timer); timer = setTimeout(function () { rrmPaginateAll(keep); }, 150); };
  window.addEventListener('resize', function () { later(true); });
  document.addEventListener('DOMContentLoaded', function () { later(false); });
  window.addEventListener('load', function () { later(false); });
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(function () { later(false); });
  /* Recalculate when the page becomes visible again or the map finishes sizing. */
  if (window.jQuery) window.jQuery(document).on('shiny:inputchanged', function (e) { if (e.name === 'page') later(true); });
  if (window.ResizeObserver) document.addEventListener('DOMContentLoaded', function () {
    var ro = new ResizeObserver(function () { later(true); });
    document.querySelectorAll('.coverage-map-panel').forEach(function (el) { ro.observe(el); });
  });
})();
/* Help (i): close on Escape or a click elsewhere. */
/* Help (i): Escape, a second click or a click elsewhere closes it, even while hovered or focused.
   The "dismissed" mark is cleared once the pointer and focus have left. */
function rrmCloseHelp(except) {
  document.querySelectorAll('.rrm-help').forEach(function (help) {
    var b = help.querySelector('.rrm-help-button');
    if (b === except) return;
    var wasOpen = b.getAttribute('aria-expanded') === 'true' || help.matches(':hover, :focus-within');
    b.setAttribute('aria-expanded', 'false');
    var panel = document.getElementById(b.getAttribute('data-toggle-target'));
    if (panel) panel.hidden = true;
    if (wasOpen) help.classList.add('rrm-help-dismissed');
  });
}
document.addEventListener('keydown', function (event) {
  if (event.key === 'Escape') rrmCloseHelp();
});
document.addEventListener('click', function (event) {
  var help = event.target.closest('.rrm-help');
  if (!help) return rrmCloseHelp();
  var b = help.querySelector('.rrm-help-button');
  rrmCloseHelp(b);
  if (event.target.closest('.rrm-help-button')) {
    /* Runs before the generic toggle: a click on an open help closes it for good. */
    var opening = b.getAttribute('aria-expanded') !== 'true';
    help.classList.toggle('rrm-help-dismissed', !opening);
  }
}, true);
document.addEventListener('mouseout', function (event) {
  var help = event.target.closest && event.target.closest('.rrm-help');
  if (help && !help.contains(event.relatedTarget) && !help.matches(':focus-within')) help.classList.remove('rrm-help-dismissed');
});
document.addEventListener('focusout', function (event) {
  var help = event.target.closest && event.target.closest('.rrm-help');
  if (help && !help.contains(event.relatedTarget) && !help.matches(':hover')) help.classList.remove('rrm-help-dismissed');
});
