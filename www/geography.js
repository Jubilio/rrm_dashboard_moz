/* Locally served Leaflet 1.9.4; external requests are only the optional OSM tiles. */
(function () {
  'use strict';
  var binding = new Shiny.OutputBinding();
  binding.find = function (scope) { return $(scope).find('.rrm-map-output'); };
  function text(value) { var el = document.createElement('div'); el.textContent = value; return el; }
  binding.renderValue = function (el, data) {
    if (!el._rrm) {
      var map = L.map(el, {scrollWheelZoom: false, minZoom: 4, maxZoom: 18});
      var osm = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      }).addTo(map);
      var blank = L.layerGroup();
      L.control.scale({imperial: false}).addTo(map);
      el._rrm = {map: map, osm: osm, blank: blank};
      if (window.ResizeObserver) {
        el._rrm.observer = new ResizeObserver(function () {
          if (el.clientWidth && el.clientHeight) map.invalidateSize({pan: false});
        });
        el._rrm.observer.observe(el);
      }
    }
    var state = el._rrm, m = state.map;
    var showTowns = state.towns && m.hasLayer(state.towns);
    var showProvinces = state.provinces && m.hasLayer(state.provinces);
    var showPosts = !state.posts || m.hasLayer(state.posts) || data.selected_post !== 'All';
    if (state.control) m.removeControl(state.control);
    ['districts','towns','provinces','posts'].forEach(function (key) {
      if (state[key]) m.removeLayer(state[key]);
    });
    state.districts = L.geoJSON(data.districts, {
      style: function (f) { return {color: '#58585A', weight: 1, fillColor: f.properties.assigned ? '#EE5859' : '#D2CBB8', fillOpacity: 0.6}; },
      onEachFeature: function (f, layer) {
        var p = f.properties;
        layer.bindTooltip(text(p.district + ' · ' + p.pcode));
        layer.bindPopup(text(p.district + ' | ' + p.province + ' | ' + p.pcode + ' — ' + p.assignment));
        layer.on('mouseover', function () { layer.setStyle({weight: 3}); });
        layer.on('mouseout', function () { state.districts.resetStyle(layer); });
      }
    }).addTo(m);
    var districtProperties = {};
    data.districts.features.forEach(function (f) { districtProperties[f.properties.pcode] = f.properties; });
    state.posts = L.geoJSON(data.posts, {
      style: {color: '#58585A', weight: data.selected_post === 'All' ? 0.8 : 3, dashArray: '3 3', fill: true, fillOpacity: 0},
      onEachFeature: function (f, layer) {
        var p = f.properties;
        layer.bindTooltip(text(p.administrative_post + ' · ' + p.pcode));
        var parent = districtProperties[p.district_pcode];
        layer.bindPopup(text(p.administrative_post + ' | ' + p.district + ' | ' + p.pcode +
          ' — Administrative-post boundary. District responsibility: ' + (parent ? parent.assignment : 'Unknown') +
          ' Colours describe district responsibilities, not post-level response coverage.'));
      }
    });
    state.provinces = L.geoJSON(data.provinces, {interactive: false, style: {color: '#58585A', weight: 2, fill: false, dashArray: '6 4'}});
    state.towns = L.geoJSON(data.towns, {
      pointToLayer: function (f, latlng) { return L.circleMarker(latlng, {radius: 4, color: '#FFFFFF', weight: 1, fillColor: '#58585A', fillOpacity: 1}); },
      onEachFeature: function (f, layer) { layer.bindTooltip(text(f.properties.name + ' · locality (context only)')); }
    });
    if (showPosts) state.posts.addTo(m);
    if (showTowns) state.towns.addTo(m);
    if (showProvinces) state.provinces.addTo(m);
    state.control = L.control.layers({'OpenStreetMap': state.osm, 'No basemap': state.blank}, {
      'District coverage': state.districts, 'Administrative-post boundaries': state.posts, 'Province boundaries': state.provinces, 'Localities (context only)': state.towns
    }).addTo(m);
    var key = data.districts.features.map(function (f) { return f.properties.pcode; }).join(',') + ':' + data.selected_post;
    var extent = data.selected_post !== 'All' ? state.posts : state.districts;
    if (state.key !== key && extent.getBounds().isValid()) m.fitBounds(extent.getBounds(), {padding: [15, 15], animate: false});
    state.key = key;
    requestAnimationFrame(function () { m.invalidateSize({pan: false}); });
  };
  Shiny.outputBindings.register(binding, 'rrm.geography');
}());
