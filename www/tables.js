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
    var button = event.target.closest('.rrm-alert-detail-button[data-input][data-alert]');
    if (button && window.Shiny && Shiny.setInputValue) {
      Shiny.setInputValue(button.dataset.input, button.dataset.alert, {priority: 'event'});
    }
  }, true);
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true});
  else start();
}());
