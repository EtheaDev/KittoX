/**
 * kxGoogleMap - Google Maps integration for KittoX GoogleMap controller.
 * Manages map instances, geocoding-based marker placement, routing, and data refresh.
 */
var kxGoogleMap = {
  _instances: {},     // viewName -> { map, markers[], infoWindow, directionsRenderer, bounds }
  _apiLoaded: false,
  _apiLoading: false,
  _pendingInits: [],

  /**
   * Loads Google Maps JS API dynamically (once) with async loading.
   */
  _loadApi: function(apiKey, callback) {
    if (kxGoogleMap._apiLoaded) { callback(); return; }
    if (kxGoogleMap._apiLoading) {
      kxGoogleMap._pendingInits.push(callback);
      return;
    }
    kxGoogleMap._apiLoading = true;
    var script = document.createElement('script');
    script.src = 'https://maps.googleapis.com/maps/api/js?key=' + encodeURIComponent(apiKey) +
                 '&libraries=geometry,marker&loading=async&callback=_kxGoogleMapApiReady';
    script.async = true;
    script.defer = true;
    window._kxGoogleMapApiReady = function() {
      kxGoogleMap._apiLoaded = true;
      kxGoogleMap._apiLoading = false;
      callback();
      kxGoogleMap._pendingInits.forEach(function(fn) { fn(); });
      kxGoogleMap._pendingInits = [];
      delete window._kxGoogleMapApiReady;
    };
    document.head.appendChild(script);
  },

  /**
   * Initializes a Google Map for the given viewName.
   */
  init: function(viewName, config) {
    kxGoogleMap._loadApi(config.apiKey, function() {
      kxGoogleMap._createMap(viewName, config);
    });
  },

  _createMap: function(viewName, config) {
    var el = document.getElementById('kx-googlemap-' + viewName);
    if (!el) return;

    // Destroy previous instance
    kxGoogleMap.destroy(viewName);

    var center = config.center || { lat: 0, lng: 0 };
    var isDark = kxGoogleMap._isDarkTheme();
    var controls = config.mapControls || {};
    var view = config.mapView || {};

    var mapOptions = {
      zoom: config.zoom || 12,
      center: center,
      mapTypeId: (config.mapTypeId || 'ROADMAP').toLowerCase(),
      zoomControl: controls.zoom !== false,
      mapTypeControl: controls.mapType !== false,
      fullscreenControl: controls.fullScreen !== false,
      streetViewControl: !!controls.streetView,
      mapId: 'kx-googlemap-' + viewName,
      colorScheme: isDark ? 'DARK' : 'LIGHT'
    };

    var map = new google.maps.Map(el, mapOptions);
    var trafficLayer = new google.maps.TrafficLayer();
    var bicyclingLayer = new google.maps.BicyclingLayer();

    var inst = {
      map: map,
      markers: [],
      infoWindow: new google.maps.InfoWindow(),
      directionsRenderer: null,
      bounds: new google.maps.LatLngBounds(),
      config: config,
      trafficLayer: trafficLayer,
      bicyclingLayer: bicyclingLayer,
      // Current toggle states
      state: {
        traffic: !!view.traffic,
        bicycling: !!view.bicycling,
        markers: view.markers !== false
      }
    };
    kxGoogleMap._instances[viewName] = inst;

    // Apply initial layer states
    if (inst.state.traffic) trafficLayer.setMap(map);
    if (inst.state.bicycling) bicyclingLayer.setMap(map);

    // Center by address (geocoding)
    if (config.address && (!center.lat && !center.lng)) {
      var geocoder = new google.maps.Geocoder();
      geocoder.geocode({ address: config.address }, function(results, status) {
        if (status === 'OK' && results[0]) {
          map.setCenter(results[0].geometry.location);
        }
      });
    }

    // Directions renderer
    if (config.showDirectionsPanel) {
      var dirEl = document.getElementById('kx-googlemap-directions-' + viewName);
      inst.directionsRenderer = new google.maps.DirectionsRenderer();
      inst.directionsRenderer.setMap(map);
      if (dirEl) {
        inst.directionsRenderer.setPanel(dirEl);
      }
    }

    // Place markers (geocoding-based)
    if (inst.state.markers && config.markers && config.markers.length > 0) {
      kxGoogleMap._geocodeAndPlaceMarkers(viewName, config.markers);
    }

    // Routing
    if (config.routing && config.routing.origin && config.routing.destination) {
      kxGoogleMap.route(viewName, config.routing.origin, config.routing.destination,
        config.routing.mode || 'DRIVING');
    }

    // Sync toolbar toggle buttons
    kxGoogleMap._syncToolbarButtons(viewName);
  },

  /**
   * Toggle a MapView feature on/off.
   */
  toggle: function(viewName, feature) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst) return;

    inst.state[feature] = !inst.state[feature];
    var on = inst.state[feature];

    switch (feature) {
      case 'traffic':
        inst.trafficLayer.setMap(on ? inst.map : null);
        break;
      case 'bicycling':
        inst.bicyclingLayer.setMap(on ? inst.map : null);
        break;
      case 'markers':
        inst.markers.forEach(function(m) {
          if (on) { if (m.map !== inst.map) m.map = inst.map; }
          else { m.map = null; }
        });
        break;
    }

    kxGoogleMap._syncToolbarButtons(viewName);
  },

  /**
   * Toggle a map control (zoom, mapType, fullScreen, streetView).
   */
  toggleControl: function(viewName, control, on) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst) return;

    var optionName = {
      zoom: 'zoomControl',
      mapType: 'mapTypeControl',
      fullScreen: 'fullscreenControl',
      streetView: 'streetViewControl'
    }[control];

    if (optionName) {
      inst.map.setOptions({ [optionName]: on });
    }
  },

  /**
   * Sync toolbar button/checkbox states with current toggle states.
   */
  _syncToolbarButtons: function(viewName) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst) return;
    var toolbar = document.getElementById('kx-googlemap-toolbar-' + viewName);
    if (!toolbar) return;

    // Sync toggle buttons
    var buttons = toolbar.querySelectorAll('[data-toggle]');
    buttons.forEach(function(btn) {
      var feature = btn.getAttribute('data-toggle');
      if (inst.state[feature]) {
        btn.classList.add('kx-toolbar-btn-active');
      } else {
        btn.classList.remove('kx-toolbar-btn-active');
      }
    });

    // Sync control checkboxes
    var controls = inst.config.mapControls || {};
    var checkboxes = toolbar.querySelectorAll('[data-control]');
    checkboxes.forEach(function(cb) {
      var control = cb.getAttribute('data-control');
      cb.checked = controls[control] !== false;
    });
  },

  /**
   * Geocode addresses and place markers with throttling.
   */
  _geocodeAndPlaceMarkers: function(viewName, markers) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst) return;

    var geocoder = new google.maps.Geocoder();
    var batchSize = 5;
    var delay = 300;
    var idx = 0;

    function processBatch() {
      var end = Math.min(idx + batchSize, markers.length);
      for (var i = idx; i < end; i++) {
        (function(m) {
          if (m.lat && m.lng) {
            var pos = new google.maps.LatLng(m.lat, m.lng);
            kxGoogleMap._placeMarker(viewName, pos, m.title, m.info, m.address, m.idx);
          } else if (m.address) {
            geocoder.geocode({ address: m.address }, function(results, status) {
              if (status === 'OK' && results[0]) {
                var pos = results[0].geometry.location;
                kxGoogleMap._placeMarker(viewName, pos, m.title, m.info, m.address, m.idx);
              }
            });
          }
        })(markers[i]);
      }
      idx = end;
      if (idx < markers.length) {
        setTimeout(processBatch, delay);
      }
    }

    processBatch();
  },

  /**
   * Build InfoWindow content from title, info, and address.
   * Always returns something meaningful.
   */
  /**
   * Detect if current KittoX theme is dark.
   * Checks data-theme attribute and prefers-color-scheme media query.
   */
  _isDarkTheme: function() {
    var theme = document.documentElement.getAttribute('data-theme');
    if (theme === 'dark') return true;
    if (theme === 'light') return false;
    // Auto mode: follow system preference
    return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  },

  _buildInfoContent: function(info, address) {
    var content = '';
    if (info) {
      content = info;
    } else if (address) {
      content = kxGoogleMap._escapeHtml(address);
    }
    if (content) {
      var textColor = kxGoogleMap._isDarkTheme() ? '#e5e7eb' : '#333';
      content = '<div style="color:' + textColor + ';font-size:13px;line-height:1.4;padding:2px 0">' + content + '</div>';
    }
    return content;
  },

  _openInfoWindow: function(viewName, marker) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst) return;
    // Set header with title (styled bold, color adapts to theme)
    if (marker._title) {
      var isDark = kxGoogleMap._isDarkTheme();
      var header = document.createElement('span');
      header.style.cssText = 'color:' + (isDark ? '#e5e7eb' : '#333') + ';font-weight:bold;font-size:14px';
      header.textContent = marker._title;
      inst.infoWindow.setHeaderContent(header);
    } else {
      inst.infoWindow.setHeaderDisabled(true);
    }
    // Set body with info/address
    inst.infoWindow.setContent(marker._infoContent || '');
    inst.infoWindow.open(inst.map, marker);
  },

  _escapeHtml: function(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  },

  _placeMarker: function(viewName, position, title, info, address, rowIdx) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst) return;

    // Use AdvancedMarkerElement if available, fall back to legacy Marker
    var marker;
    if (google.maps.marker && google.maps.marker.AdvancedMarkerElement) {
      marker = new google.maps.marker.AdvancedMarkerElement({
        position: position,
        map: inst.map,
        title: title || ''
      });
    } else {
      marker = new google.maps.Marker({
        position: position,
        map: inst.map,
        title: title || ''
      });
    }

    if (typeof rowIdx !== 'undefined') {
      marker._rowIdx = rowIdx;
    }
    // Store title and info content on the marker
    marker._title = title || '';
    marker._infoContent = kxGoogleMap._buildInfoContent(info, address);

    // Always add click listener if there's any content to show
    // AdvancedMarkerElement uses 'gmp-click', legacy Marker uses 'click'
    if (marker._infoContent || title) {
      var clickEvent = (marker instanceof google.maps.marker.AdvancedMarkerElement) ? 'gmp-click' : 'click';
      marker.addListener(clickEvent, function() {
        kxGoogleMap._openInfoWindow(viewName, marker);
        if (typeof marker._rowIdx !== 'undefined') {
          kxGoogleMap._highlightRow(viewName, marker._rowIdx);
        }
      });
    }

    inst.markers.push(marker);
    inst.bounds.extend(position);

    // Auto-fit bounds after all markers placed (debounced)
    if (inst._fitTimer) clearTimeout(inst._fitTimer);
    inst._fitTimer = setTimeout(function() {
      kxGoogleMap._fitBounds(viewName);
    }, 500);
  },

  _fitBounds: function(viewName) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst || inst.markers.length === 0) return;

    if (inst.markers.length === 1) {
      inst.map.setCenter(inst.markers[0].position);
      inst.map.setZoom(inst.config.zoom || 12);
    } else {
      inst.map.fitBounds(inst.bounds);
    }
  },

  _highlightRow: function(viewName, rowIdx) {
    var tbody = document.getElementById('kx-googlemap-grid-' + viewName);
    if (!tbody) return;
    var rows = tbody.querySelectorAll('tr');
    rows.forEach(function(r) { r.classList.remove('kx-googlemap-row-active'); });
    if (rows[rowIdx]) {
      rows[rowIdx].classList.add('kx-googlemap-row-active');
      rows[rowIdx].scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
  },

  _clearMarkers: function(viewName) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst) return;
    inst.markers.forEach(function(m) {
      if (m.setMap) m.setMap(null);        // legacy Marker
      else if (m.map) m.map = null;         // AdvancedMarkerElement
    });
    inst.markers = [];
    inst.bounds = new google.maps.LatLngBounds();
  },

  /**
   * Refresh markers from server via AJAX.
   */
  refresh: function(viewName) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst) return;

    var baseUrl = document.querySelector('base') ? document.querySelector('base').href : '';
    fetch(baseUrl + 'kx/view/' + viewName + '/map-data', {
      headers: { 'X-KittoX': 'true' }
    })
    .then(function(r) { return r.json(); })
    .then(function(data) {
      kxGoogleMap._clearMarkers(viewName);
      if (data.markers && data.markers.length > 0) {
        kxGoogleMap._geocodeAndPlaceMarkers(viewName, data.markers);
      }
      // Update grid sidebar if gridHtml is returned
      if (typeof data.gridHtml === 'string') {
        var tbody = document.getElementById('kx-googlemap-grid-' + viewName);
        if (tbody) {
          tbody.innerHTML = data.gridHtml;
        }
      }
    })
    .catch(function(err) { console.error('kxGoogleMap refresh error:', err); });
  },

  /**
   * Calculate route between two addresses or coordinates.
   */
  route: function(viewName, origin, destination, mode) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst) return;

    if (!inst.directionsRenderer) {
      inst.directionsRenderer = new google.maps.DirectionsRenderer();
      inst.directionsRenderer.setMap(inst.map);
      var dirEl = document.getElementById('kx-googlemap-directions-' + viewName);
      if (dirEl) {
        inst.directionsRenderer.setPanel(dirEl);
      }
    }

    var directionsService = new google.maps.DirectionsService();
    var request = {
      origin: origin,
      destination: destination,
      travelMode: google.maps.TravelMode[mode || 'DRIVING']
    };

    directionsService.route(request, function(response, status) {
      if (status === 'OK') {
        inst.directionsRenderer.setDirections(response);
      } else {
        console.error('kxGoogleMap route error:', status);
      }
    });
  },

  /**
   * Center map on a specific marker (e.g., from grid row click).
   */
  centerOnMarker: function(viewName, rowIdx) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst || !inst.markers[rowIdx]) return;

    var marker = inst.markers[rowIdx];
    inst.map.setCenter(marker.position);
    inst.map.setZoom(15);
    // Show InfoWindow with header (title) + body (info)
    if (marker._infoContent || marker._title) {
      kxGoogleMap._openInfoWindow(viewName, marker);
    }
    kxGoogleMap._highlightRow(viewName, rowIdx);
  },

  /**
   * Cleanup a map instance.
   */
  destroy: function(viewName) {
    var inst = kxGoogleMap._instances[viewName];
    if (!inst) return;
    if (inst._fitTimer) clearTimeout(inst._fitTimer);
    kxGoogleMap._clearMarkers(viewName);
    if (inst.trafficLayer) inst.trafficLayer.setMap(null);
    if (inst.bicyclingLayer) inst.bicyclingLayer.setMap(null);
    if (inst.directionsRenderer) inst.directionsRenderer.setMap(null);
    delete kxGoogleMap._instances[viewName];
  }
};

// Resize maps on tab switch or splitter drag
function _kxGoogleMapResizeAll() {
  for (var name in kxGoogleMap._instances) {
    var inst = kxGoogleMap._instances[name];
    if (inst && inst.map) {
      google.maps.event.trigger(inst.map, 'resize');
    }
  }
}

document.addEventListener('click', function(e) {
  if (e.target.closest('[data-tab-target]')) {
    setTimeout(_kxGoogleMapResizeAll, 100);
  }
});

// Resize after splitter drag ends
document.addEventListener('pointerup', function(e) {
  if (e.target.closest('.kx-splitter')) {
    setTimeout(_kxGoogleMapResizeAll, 50);
  }
});
