/* Locally served Leaflet 1.9.4; external requests are only the optional OSM tiles. */
(function () {
  'use strict';
  var binding = new Shiny.OutputBinding();
  binding.find = function (scope) { return $(scope).find('.rrm-map-output'); };
  function text(value) { var el = document.createElement('div'); el.textContent = value; return el; }
  /* One visual language for every RRM map: REACH ink/red/sand, white-edged points. */
  var INK = '#58585A', RED = '#EE5859', SAND = '#D2CBB8', MUTED = '#79797B';
  function point(fill, radius) { return {radius: radius, color: '#FFFFFF', weight: 1.5, opacity: 1, fillColor: fill, fillOpacity: 1}; }
  binding.renderValue = function (el, data) {
    if (!data || !data.districts) return;
    if (!el._rrm) {
      var map = L.map(el, {scrollWheelZoom: false, minZoom: 4, maxZoom: 18, zoomSnap: 0.25, zoomDelta: 0.5});
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
    var interventionMode = data.kind === 'interventions';
    var alertMode = data.kind === 'alert_routes';
    var contextMode = interventionMode || alertMode;
    var showSettlements = state.settlements && m.hasLayer(state.settlements);
    var showTowns = state.towns && m.hasLayer(state.towns);
    var showProvinces = state.provinces ? m.hasLayer(state.provinces) : !contextMode;
    var showPosts = !state.posts || m.hasLayer(state.posts) || data.selected_post !== 'All';
    if (state.control) m.removeControl(state.control);
    ['districts','towns','provinces','posts','settlements','interventions','alertPoints','alertConnections'].forEach(function (key) {
      if (state[key]) m.removeLayer(state[key]);
    });
    state.districts = L.geoJSON(data.districts, {
      style: function (f) {
        return contextMode ?
          {color: INK, weight: 1, opacity: 0.55, fillColor: SAND, fillOpacity: 0.06} :
          {color: '#FFFFFF', weight: 1.2, opacity: 1, fillColor: f.properties.assigned ? RED : SAND, fillOpacity: 0.5};
      },
      onEachFeature: function (f, layer) {
        var p = f.properties;
        layer.bindTooltip(text(p.district + ' · ' + p.pcode +
          (contextMode ? '' : '\nGLA: ' + p.assignment)),
          {className: contextMode ? '' : 'rrm-coverage-tooltip'});
        layer.bindPopup(text(p.district + ' | ' + p.province + ' | ' + p.pcode + (contextMode ? ' — District boundary (context only)' : ' — ' + p.assignment)));
        layer.on('mouseover', function () { layer.setStyle({color: INK, weight: 2.5, opacity: 1}); });
        layer.on('mouseout', function () { state.districts.resetStyle(layer); });
      }
    }).addTo(m);
    var districtProperties = {};
    data.districts.features.forEach(function (f) { districtProperties[f.properties.pcode] = f.properties; });
    state.posts = L.geoJSON(data.posts, {
      style: {color: INK, weight: data.selected_post === 'All' ? 0.6 : 2.5, opacity: data.selected_post === 'All' ? 0.5 : 1, dashArray: '2 3', fill: true, fillOpacity: 0},
      onEachFeature: function (f, layer) {
        var p = f.properties;
        var parent = districtProperties[p.district_pcode];
        layer.bindTooltip(text(p.administrative_post + ' · ' + p.pcode +
          (contextMode ? '' : '\nDistrict GLA (' + p.district + '): ' + (parent ? parent.assignment : 'Unknown'))),
          {className: contextMode ? '' : 'rrm-coverage-tooltip'});
        layer.bindPopup(text(p.administrative_post + ' | ' + p.district + ' | ' + p.pcode +
          (contextMode ? ' — Administrative-post boundary (context only)' :
          ' — Administrative-post boundary. District responsibility: ' + (parent ? parent.assignment : 'Unknown') +
          ' Colours describe district responsibilities, not post-level response coverage.')));
      }
    });
    state.provinces = L.geoJSON(data.provinces, {interactive: false, style: {color: INK, weight: 2, opacity: 0.9, fill: false}});
    state.towns = L.geoJSON(data.towns, {
      pointToLayer: function (f, latlng) { return L.circleMarker(latlng, point(MUTED, 3.5)); },
      onEachFeature: function (f, layer) { layer.bindTooltip(text(f.properties.name + ' · locality (context only)')); }
    });
    var overlays = {};
    overlays[contextMode ? 'District boundaries' : 'District coverage'] = state.districts;
    overlays['Administrative-post boundaries'] = state.posts;
    overlays['Province boundaries'] = state.provinces;
    overlays['Main towns (context only)'] = state.towns;
    if (interventionMode) {
      state.interventions = L.geoJSON(data.markers, {
        pointToLayer: function (f, latlng) { return L.circleMarker(latlng, point(f.properties.validated_records > 0 ? RED : INK, 7)); },
        onEachFeature: function (f, layer) {
          var p = f.properties;
          layer.bindTooltip(text(p.name + ' · ' + p.record_count + ' reported activity records'));
          layer.bindPopup(text(p.name + ' | ' + p.district + ' | ' + (p.admin_post || 'Post unresolved') +
            '\nGeographic source: ' + p.source_layer + ' · ' + p.point_id +
            '\nLinked activity records: ' + p.record_count + '\nIncluded in validated results: ' + p.validated_records +
            '\nOther / pending / excluded records: ' + p.other_records +
            '\nImplementing agencies: ' + p.agencies + '\nSectors: ' + p.sectors +
            '\nName-based geographic linkage only; no reach or output totals allocated.'));
        }
      });
      state.settlements = L.geoJSON(data.settlements, {
        pointToLayer: function (f, latlng) { return L.circleMarker(latlng, {radius: 2, color: MUTED, weight: 1, fillColor: MUTED, fillOpacity: 0.5}); },
        onEachFeature: function (f, layer) {
          var p = f.properties;
          layer.bindTooltip(text(p.name + ' · ' + p.source_layer + ' (reference point)'));
          layer.bindPopup(text(p.name + ' | ' + p.district + ' | ' + (p.admin_post || 'Post unresolved') +
            ' | ' + p.point_id + ' — Reference point only; no intervention link implied.'));
        }
      });
      overlays['Reported intervention locations'] = state.interventions;
      overlays['Settlement reference points'] = state.settlements;
      if (showSettlements) state.settlements.addTo(m);
    }
    if (alertMode) {
      state.alertConnections = L.geoJSON(data.connections, {
        style: {color: INK, weight: 1.8, opacity: 0.75, dashArray: '5 4'},
        onEachFeature: function (f, layer) {
          var p = f.properties;
          layer.bindTooltip(text(p.origin + ' → ' + p.arrival));
          layer.bindPopup(text(p.alert_id + ' | ' + p.route_id + '\n' + p.origin + ' → ' + p.arrival +
            '\nRoute people: ' + (p.people == null ? 'Unavailable' : p.people) +
            '\nRoute HH: ' + (p.households == null ? 'Unavailable' : p.households) +
            '\nCaseload stage: ' + p.stage + '\nRRM targeted at arrival: ' + p.targeted +
            '\nOrigin–arrival connection only; not a travelled path.' + (data.mode === 'demo' ? '\nDEMO · fictional movement.' : '')));
        }
      }).addTo(m);
      state.alertPoints = L.geoJSON(data.markers, {
        pointToLayer: function (f, latlng) { return L.circleMarker(latlng, point(f.properties.endpoint === 'origin' ? INK : RED, 6)); },
        onEachFeature: function (f, layer) {
          var p = f.properties;
          layer.bindTooltip(text((p.endpoint === 'origin' ? 'Origin: ' : 'Arrival: ') + p.name));
          layer.bindPopup(text(p.name + ' | ' + p.endpoint + '\n' + p.details +
            '\nCoordinate source: ' + p.coordinate_source + '\nCoordinate status: ' + p.coordinate_status +
            (data.mode === 'demo' ? '\nDEMO · fictional coordinates and movement.' : '')));
        }
      }).addTo(m);
      overlays['Origin and arrival points'] = state.alertPoints;
      overlays['Origin–arrival connections'] = state.alertConnections;
    }
    if (showPosts) state.posts.addTo(m);
    if (showTowns) state.towns.addTo(m);
    if (showProvinces) state.provinces.addTo(m);
    if (interventionMode) state.interventions.addTo(m);
    state.control = L.control.layers({'OpenStreetMap': state.osm, 'No basemap': state.blank}, overlays).addTo(m);
    var key = data.districts.features.map(function (f) { return f.properties.pcode; }).join(',') + ':' + data.selected_post;
    if (interventionMode) key += ':' + data.markers.features.map(function (f) { return f.properties.point_id + ':' + f.geometry.coordinates.join(','); }).join(';');
    if (alertMode) key += ':' + data.markers.features.map(function (f) { return f.properties.location_id; }).join(';');
    var extent = alertMode && data.markers.features.length ? state.alertPoints : interventionMode && data.markers.features.length ? state.interventions : data.selected_post !== 'All' ? state.posts : state.districts;
    if (state.key !== key && extent.getBounds().isValid()) m.fitBounds(extent.getBounds(), {padding: [10, 10], maxZoom: contextMode ? 13 : 18, animate: false});
    state.key = key;
    requestAnimationFrame(function () { m.invalidateSize({pan: false}); });
  };
  Shiny.outputBindings.register(binding, 'rrm.geography');
}());
