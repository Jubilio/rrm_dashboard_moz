/* Keep DT columns aligned with their panel after hidden tabs/details are shown. */
(function () {
  'use strict';
  var pending = new Set();
  var frame = null;
  var widths = new WeakMap();
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
    $(document).on('destroy.dt.rrmWidth', function (event, settings) {
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
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, {once: true});
  else start();
}());
