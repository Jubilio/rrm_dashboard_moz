/* Locally served Leaflet 1.9.4; external requests are only the optional OSM tiles. */
(function () {
  'use strict';
  var binding = new Shiny.OutputBinding();
  binding.find = function (scope) { return $(scope).find('.rrm-map-output'); };
  function text(value) { var el = document.createElement('div'); el.textContent = value; return el; }
  /* One visual language for every RRM map: REACH ink/red/sand, white-edged points. */
  var INK = '#58585A', RED = '#EE5859', SAND = '#D2CBB8', MUTED = '#79797B';
  /* Partner view: primary in REACH red, secondary in REACH ink, so the two roles differ in hue and lightness. */
  var PRIMARY = RED, SECONDARY = INK;
  function point(fill, radius) { return {radius: radius, color: '#FFFFFF', weight: 1.5, opacity: 1, fillColor: fill, fillOpacity: 1}; }
  function bindMapAction(layer, label, activate) {
    layer.on('click', function () { activate(false); });
    layer.on('add', function () {
      var path = layer.getElement();
      if (!path) return;
      path.setAttribute('tabindex', '0');
      path.setAttribute('role', 'button');
      path.setAttribute('aria-label', label);
      L.DomEvent.on(path, 'keydown', function (event) {
        if (event.key !== 'Enter' && event.key !== ' ') return;
        L.DomEvent.stop(event);
        activate(true);
      });
    });
  }
  binding.renderValue = function (el, data) {
    if (!data || !data.districts) return;
    if (!el._rrm) {
      var map = L.map(el, {scrollWheelZoom: true, minZoom: 4, maxZoom: 18, zoomSnap: 0.25, zoomDelta: 0.5});
      var osm = L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
      }).addTo(map);
      var blank = L.layerGroup();
      L.control.scale({imperial: false}).addTo(map);
      el._rrm = {map: map, osm: osm, blank: blank};
      if (window.ResizeObserver) {
        el._rrm.observer = new ResizeObserver(function () {
          if (!el.clientWidth || !el.clientHeight) return;
          map.invalidateSize({pan: false});
          /* A map rendered while hidden (size 0) is framed once it becomes visible. */
          var pending = el._rrm.pendingFit;
          if (pending) { el._rrm.pendingFit = null; map.fitBounds(pending.bounds, pending.options); }
        });
        el._rrm.observer.observe(el);
      }
    }
    var state = el._rrm, m = state.map;
    var interventionMode = data.kind === 'interventions';
    var alertMode = data.kind === 'alert_routes';
    var reachMode = data.kind === 'district_reach';
    var contextMode = interventionMode || alertMode || reachMode;
    var showSettlements = state.settlements && m.hasLayer(state.settlements);
    var showTowns = state.towns && m.hasLayer(state.towns);
    var showProvinces = state.provinces ? m.hasLayer(state.provinces) : !contextMode;
    var showPosts = !state.posts || m.hasLayer(state.posts) || data.selected_post !== 'All';
    if (state.control) m.removeControl(state.control);
    if (state.reachLegend) { m.removeControl(state.reachLegend); state.reachLegend = null; }
    if (state.partnerControl) { m.removeControl(state.partnerControl); state.partnerControl = null; }
    if (state.partnerLegend) { m.removeControl(state.partnerLegend); state.partnerLegend = null; }
    /* Partner icons (coverage map only): clicking one shows its primary and secondary districts. */
    var partners = (!contextMode && data.partners) || [];
    if (state.partner && !partners.some(function (p) { return p.partner === state.partner; })) state.partner = null;
    function partnerRole(pcode) {
      var p = partners.filter(function (x) { return x.partner === state.partner; })[0];
      if (!p) return null;
      if (p.primary.indexOf(pcode) >= 0) return 'Primary';
      if (p.secondary.indexOf(pcode) >= 0) return 'Secondary';
      return 'None';
    }
    ['districts','towns','provinces','posts','settlements','interventions','alertPoints','alertConnections','districtReach'].forEach(function (key) {
      if (state[key]) m.removeLayer(state[key]);
    });
    state.districts = L.geoJSON(data.districts, {
      style: function (f) {
        if (contextMode) return (data.selected_district && data.selected_district !== 'All' && f.properties.pcode === data.selected_district) ?
          {color: RED, weight: 2.5, opacity: 1, fillColor: RED, fillOpacity: 0.15} :
          {color: INK, weight: 1, opacity: 0.55, fillColor: SAND, fillOpacity: 0.06};
        var role = state.partner ? partnerRole(f.properties.pcode) : null;
        if (role === 'Primary') return {color: '#FFFFFF', weight: 1.2, opacity: 1, fillColor: PRIMARY, fillOpacity: 0.8};
        if (role === 'Secondary') return {color: '#FFFFFF', weight: 1.2, opacity: 1, fillColor: SECONDARY, fillOpacity: 0.8};
        if (role === 'None') return {color: '#FFFFFF', weight: 1.2, opacity: 1, fillColor: SAND, fillOpacity: 0.25};
        return {color: '#FFFFFF', weight: 1.2, opacity: 1, fillColor: f.properties.assigned ? RED : SAND, fillOpacity: 0.5};
      },
      onEachFeature: function (f, layer) {
        var p = f.properties;
        var nAlerts = p.alerts ? p.alerts.length : 0;
        layer.bindTooltip(text(p.district + ' · ' + p.pcode +
          (contextMode ? '' : '\nGLA: ' + p.assignment +
            '\n' + (nAlerts ? 'Click to view ' + nAlerts + ' related alert' + (nAlerts > 1 ? 's' : '') : 'No related alerts — click to open Alerts'))),
          {className: contextMode ? '' : 'rrm-coverage-tooltip'});
        if (contextMode) {
          layer.bindPopup(text(p.district + ' | ' + p.province + ' | ' + p.pcode + ' — District boundary (context only)'));
        } else {
          /* No popup: a click opens the Alerts page filtered to this district. */
          bindMapAction(layer, 'View alerts for ' + p.district, function () {
            Shiny.setInputValue('map_district_alerts', p.pcode, {priority: 'event'});
          });
        }
        layer.on('mouseover', function () { layer.setStyle({color: INK, weight: 2.5, opacity: 1}); });
        layer.on('mouseout', function () { state.districts.resetStyle(layer); });
      }
    }).addTo(m);
    function updatePartnerView() {
      state.districts.setStyle(state.districts.options.style);
      if (state.partnerControl) state.partnerControl.getContainer().querySelectorAll('button').forEach(function (b) {
        b.setAttribute('aria-pressed', String(b.getAttribute('data-partner') === state.partner));
      });
      if (state.partnerLegend) { m.removeControl(state.partnerLegend); state.partnerLegend = null; }
      if (!state.partner) return;
      var p = partners.filter(function (x) { return x.partner === state.partner; })[0];
      state.partnerLegend = L.control({position: 'bottomright'});
      state.partnerLegend.onAdd = function () {
        var box = L.DomUtil.create('div', 'rrm-partner-legend');
        var title = document.createElement('strong'); title.textContent = p.partner; title.title = p.name;
        box.appendChild(title);
        [[PRIMARY, 'Primary', p.primary.length], [SECONDARY, 'Secondary', p.secondary.length]].forEach(function (r) {
          var row = document.createElement('div'), sw = document.createElement('span');
          sw.className = 'map-swatch'; sw.style.background = r[0];
          row.appendChild(sw); row.appendChild(document.createTextNode(r[1] + ' (' + r[2] + ')'));
          box.appendChild(row);
        });
        return box;
      };
      state.partnerLegend.addTo(m);
    }
    if (partners.length) {
      state.partnerControl = L.control({position: 'topleft'});
      state.partnerControl.onAdd = function () {
        var box = L.DomUtil.create('div', 'rrm-partner-icons leaflet-bar');
        box.setAttribute('role', 'group'); box.setAttribute('aria-label', 'Show districts by partner');
        partners.forEach(function (p) {
          var b = L.DomUtil.create('button', 'rrm-partner-btn', box);
          b.type = 'button'; b.title = p.name + ': show primary and secondary districts';
          b.setAttribute('data-partner', p.partner);
          b.setAttribute('aria-pressed', String(p.partner === state.partner));
          if (p.icon) { var img = document.createElement('img'); img.src = p.icon; img.alt = p.partner; b.appendChild(img); }
          else b.textContent = p.partner;
          L.DomEvent.on(b, 'click', function (e) {
            L.DomEvent.stop(e);
            state.partner = state.partner === p.partner ? null : p.partner;
            updatePartnerView();
          });
        });
        L.DomEvent.disableClickPropagation(box); L.DomEvent.disableScrollPropagation(box);
        return box;
      };
      state.partnerControl.addTo(m);
    }
    updatePartnerView();
    var districtProperties = {};
    data.districts.features.forEach(function (f) { districtProperties[f.properties.pcode] = f.properties; });
    state.posts = L.geoJSON(data.posts, {
      // On RNA Intro, post outlines leave the district interiors clickable.
      style: {color: INK, weight: data.selected_post === 'All' ? 0.6 : 2.5, opacity: data.selected_post === 'All' ? 0.5 : 1, dashArray: '2 3', fill: contextMode, fillOpacity: 0},
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
        pointToLayer: function (f, latlng) { return L.circleMarker(latlng, point(({Ongoing:'#E69F00',Closed:'#0072B2',Mixed:'#8B5CF6'})[f.properties.response_status] || INK, 7)); },
        onEachFeature: function (f, layer) {
          var p = f.properties;
          layer.bindTooltip(text(p.name + ' · ' + p.record_count + ' reported activity records'));
          layer.bindPopup(text(p.name + ' | ' + p.district + ' | ' + (p.admin_post || 'Post unresolved') +
            '\nGeographic source: ' + p.source_layer + ' · ' + p.point_id +
            '\nResponse status: ' + p.response_status + '\nRecords by response status: ongoing ' + p.ongoing_records + ', closed ' + p.closed_records + ', not reported ' + p.unknown_status_records +
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
    if (reachMode) {
      var reachFeatures = data.reach.features;
      var reachMax = Math.max.apply(null, [0].concat(reachFeatures.map(function (f) { return f.properties.people; })));
      state.districtReach = L.featureGroup();
      reachFeatures.forEach(function (f) {
        var p = f.properties;
        var centre = L.geoJSON(f).getBounds().getCenter();
        var radius = reachMax > 0 ? 32 * Math.sqrt(p.people / reachMax) : 0;
        var label = p.district + ': ' + p.people.toLocaleString() + ' gross people reached';
        // A zero has no area; use a small hollow point so reported zero stays inspectable.
        var circle = L.circleMarker(centre, {radius: p.people === 0 ? 3 : radius,
          color: RED, weight: 1.5, fillColor: RED, fillOpacity: p.people === 0 ? 0 : 0.45});
        circle.bindTooltip(text(label));
        circle.bindPopup(text(label + '\n' + p.measure + '\nValidated activity records: ' + p.record_count +
          '\nGross across activities; repeat recipients may overlap. District symbol, not a delivery site.'));
        state.districtReach.addLayer(circle);
      });
      state.districtReach.addTo(m);
      overlays['Gross people reached by district'] = state.districtReach;
      if (reachMax > 0) {
        state.reachLegend = L.control({position: 'bottomright'});
        state.reachLegend.onAdd = function () {
          var legend = document.createElement('div');
          legend.style.cssText = 'background:white;padding:8px 12px;color:#58585A;border-radius:4px;';
          legend.appendChild(text('Gross people reached'));
          [reachMax / 4, reachMax].forEach(function (value) {
            var row = document.createElement('div'), symbol = document.createElement('span');
            var diameter = 64 * Math.sqrt(value / reachMax);
            symbol.style.cssText = 'display:inline-block;vertical-align:middle;border:1px solid #EE5859;background:rgba(238,88,89,.45);border-radius:50%;margin:4px 8px 4px 0;box-sizing:border-box;';
            symbol.style.width = diameter + 'px'; symbol.style.height = diameter + 'px';
            row.appendChild(symbol); row.appendChild(document.createTextNode(value.toLocaleString(undefined, {maximumFractionDigits: 1})));
            legend.appendChild(row);
          });
          return legend;
        };
        state.reachLegend.addTo(m);
      }
    }
    if (alertMode) {
      // Keep alert targets above the district and other geographic overlays.
      var alertPane = 'alertFeatures';
      if (!m.getPane(alertPane)) m.createPane(alertPane).style.zIndex = '450';
      var bindAlertSelection = function (layer, feature, label) {
        if (!data.selection_input) return;
        bindMapAction(layer, label, function (keyboard) {
          Shiny.setInputValue(data.selection_input, feature.selection_id, {priority: 'event'});
          if (keyboard) layer.openPopup();
        });
      };
      state.alertConnections = L.geoJSON(data.connections, {
        pane: alertPane,
        style: {color: INK, weight: 1.8, opacity: 0.75, dashArray: '5 4'},
        onEachFeature: function (f, layer) {
          var p = f.properties;
          layer.bindTooltip(text(p.origin + ' → ' + p.arrival));
          layer.bindPopup(text(p.alert_id + ' | ' + p.route_id + '\n' + p.origin + ' → ' + p.arrival +
            '\nRoute people: ' + (p.people == null ? 'Unavailable' : p.people) +
            '\nRoute HH: ' + (p.households == null ? 'Unavailable' : p.households) +
            '\nCaseload stage: ' + p.stage + '\nRRM targeted at arrival: ' + p.targeted +
            '\nOrigin–arrival connection only; not a travelled path.' + (data.mode === 'demo' ? '\nDEMO · fictional movement.' : '')));
          bindAlertSelection(layer, p, 'Route: ' + p.origin + ' to ' + p.arrival + ', ' + p.alert_id);
        }
      }).addTo(m);
      state.alertPoints = L.geoJSON(data.markers, {
        pointToLayer: function (f, latlng) {
          var style = point(f.properties.endpoint === 'origin' ? INK : RED, 6);
          style.pane = alertPane;
          return L.circleMarker(latlng, style);
        },
        onEachFeature: function (f, layer) {
          var p = f.properties;
          layer.bindTooltip(text((p.endpoint === 'origin' ? 'Origin: ' : 'Arrival: ') + p.name));
          layer.bindPopup(text(p.name + ' | ' + p.endpoint + '\n' + p.details +
            '\nCoordinate source: ' + p.coordinate_source + '\nCoordinate status: ' + p.coordinate_status +
            (data.mode === 'demo' ? '\nDEMO · fictional coordinates and movement.' : '')));
          bindAlertSelection(layer, p, (p.endpoint === 'origin' ? 'Origin: ' : 'Arrival: ') + p.name);
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
    var key = data.districts.features.map(function (f) { return f.properties.pcode; }).join(',') + ':' + data.selected_post + ':' + data.kind;
    if (interventionMode) key += ':' + data.markers.features.map(function (f) { return f.properties.point_id + ':' + f.geometry.coordinates.join(','); }).join(';');
    if (alertMode) key += ':' + data.markers.features.map(function (f) { return f.properties.location_id; }).join(';') + ':' + (data.selected_district || 'All');
    var extent = alertMode && data.markers.features.length ? state.alertPoints : interventionMode && data.markers.features.length ? state.interventions : data.selected_post !== 'All' ? state.posts : state.districts;
    var bounds = extent.getBounds();
    if (alertMode && data.selected_district && data.selected_district !== 'All') {
      state.districts.eachLayer(function (layer) {
        if (layer.feature.properties.pcode !== data.selected_district) return;
        bounds = data.markers.features.length ? L.latLngBounds(bounds).extend(layer.getBounds()) : layer.getBounds();
      });
    }
    if (state.key !== key && bounds.isValid()) {
      var fit = {bounds: bounds, options: {padding: [10, 10], maxZoom: contextMode ? 13 : 18, animate: false}};
      /* Hidden map (another page is open): defer framing until it has a size. */
      if (el.clientWidth && el.clientHeight) { state.pendingFit = null; m.fitBounds(fit.bounds, fit.options); }
      else state.pendingFit = fit;
    }
    state.key = key;
    requestAnimationFrame(function () { m.invalidateSize({pan: false}); });
  };
  Shiny.outputBindings.register(binding, 'rrm.geography');
}());
