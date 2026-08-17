import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_marker_data.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/map_zoom_controls.dart';

class OsmMapView extends ConsumerStatefulWidget {
  const OsmMapView({
    super.key,
    this.height,
    this.markers = const [],
    this.enableSelection = false,
    this.showCurrentLocation = true,
    this.highlightedMarker,
    this.initialZoom = 14,
    this.onMarkerTap,
    this.onCoordinateSelected,
  });

  final double? height;
  final List<MapMarkerData> markers;
  final bool enableSelection;
  final bool showCurrentLocation;
  final MapMarkerData? highlightedMarker;
  final double initialZoom;
  final void Function(MapMarkerData marker)? onMarkerTap;
  final void Function(MapCoordinate coordinate)? onCoordinateSelected;

  @override
  ConsumerState<OsmMapView> createState() => _OsmMapViewState();
}

class _OsmMapViewState extends ConsumerState<OsmMapView> {
  static const _minZoom = 5.0;
  static const _maxZoom = 17.0;

  final MapController _mapController = MapController();
  MapCoordinate? _lastCenteredSelection;
  bool _mapReady = false;
  late LatLng _initialCenter;
  late double _initialZoom;

  @override
  void initState() {
    super.initState();
    _initialZoom = widget.initialZoom.clamp(_minZoom, _maxZoom);
    _initialCenter = const LatLng(20.5937, 78.9629);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapSelectionProvider.notifier).initialize();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncInitialTarget();
  }

  @override
  void didUpdateWidget(covariant OsmMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialZoom != widget.initialZoom && !_mapReady) {
      _initialZoom = widget.initialZoom.clamp(_minZoom, _maxZoom);
    }
  }

  void _syncInitialTarget() {
    final mapState = ref.read(mapSelectionProvider);
    final currentLocation =
        widget.showCurrentLocation ? mapState.currentLocation : null;
    final selected = widget.enableSelection ? mapState.selected : null;
    final target = initialCameraTarget(
      selected: selected,
      currentLocation: currentLocation,
      markers: widget.markers,
    );
    if (target != null) {
      _initialCenter = LatLng(target.latitude, target.longitude);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _registerSelectionListener() {
    ref.listen<MapSelectionState>(mapSelectionProvider, (previous, next) {
      final nextSelected = widget.enableSelection ? next.selected : null;
      if (nextSelected != null && nextSelected != _lastCenteredSelection) {
        _lastCenteredSelection = nextSelected;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _centerOn(nextSelected, zoom: 16);
        });
        return;
      }

      // Recenter when Current Location is resolved (Nearby Parking flow).
      if (widget.showCurrentLocation &&
          next.currentLocation != null &&
          next.currentLocation != previous?.currentLocation) {
        final loc = next.currentLocation!;
        _lastCenteredSelection = loc;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _centerOn(loc, zoom: 15);
        });
      }
    });
  }

  void _centerOn(MapCoordinate coordinate, {double? zoom}) {
    if (!_mapReady) return;
    try {
      _mapController.move(
        LatLng(coordinate.latitude, coordinate.longitude),
        (zoom ?? _mapController.camera.zoom).clamp(_minZoom, _maxZoom),
      );
    } catch (_) {}
  }

  void _zoomBy(double delta) {
    if (!_mapReady) return;
    try {
      final camera = _mapController.camera;
      final nextZoom = (camera.zoom + delta).clamp(_minZoom, _maxZoom);
      if (nextZoom == camera.zoom) return;
      _mapController.move(camera.center, nextZoom);
      setState(() {});
    } catch (_) {}
  }

  void _zoomIn() => _zoomBy(1);

  void _zoomOut() => _zoomBy(-1);

  bool get _canZoomIn {
    if (!_mapReady) return false;
    try {
      return _mapController.camera.zoom < _maxZoom;
    } catch (_) {
      return false;
    }
  }

  bool get _canZoomOut {
    if (!_mapReady) return false;
    try {
      return _mapController.camera.zoom > _minZoom;
    } catch (_) {
      return false;
    }
  }

  Widget _buildMapControlsColumn({
    required MapSelectionState mapState,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showCurrentLocation)
          FloatingActionButton.small(
            heroTag: 'osm_current_location',
            onPressed: mapState.isLoadingLocation
                ? null
                : () async {
                    await ref
                        .read(mapSelectionProvider.notifier)
                        .refreshCurrentLocation();
                    final loc = ref.read(mapSelectionProvider).currentLocation;
                    if (loc != null) {
                      _centerOn(loc, zoom: 16);
                    }
                  },
            child: mapState.isLoadingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        if (widget.showCurrentLocation) const SizedBox(height: 8),
        MapZoomControls(
          onZoomIn: _canZoomIn ? _zoomIn : null,
          onZoomOut: _canZoomOut ? _zoomOut : null,
        ),
      ],
    );
  }

  List<Marker> _buildMarkers({
    required MapCoordinate? selected,
    required MapCoordinate? currentLocation,
  }) {
    final markers = <Marker>[];

    if (currentLocation != null) {
      markers.add(
        Marker(
          point: LatLng(currentLocation.latitude, currentLocation.longitude),
          width: 36,
          height: 36,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 28),
        ),
      );
    }

    if (selected != null) {
      markers.add(
        Marker(
          point: LatLng(selected.latitude, selected.longitude),
          width: 44,
          height: 44,
          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
        ),
      );
    }

    for (final marker in widget.markers) {
      final isHighlighted = widget.highlightedMarker?.id == marker.id;
      markers.add(
        Marker(
          point: LatLng(
            marker.coordinate.latitude,
            marker.coordinate.longitude,
          ),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: widget.onMarkerTap != null
                ? () => widget.onMarkerTap!(marker)
                : null,
            child: Icon(
              Icons.location_on,
              color: isHighlighted ? Colors.orange : Colors.red,
              size: 36,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    _registerSelectionListener();

    final mapState = ref.watch(mapSelectionProvider);
    final currentLocation =
        widget.showCurrentLocation ? mapState.currentLocation : null;
    final selected = widget.enableSelection ? mapState.selected : null;

    final map = FlutterMap(
      key: const ValueKey('osm_map'),
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: _initialZoom,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
        onMapReady: () {
          if (mounted) setState(() => _mapReady = true);
        },
        onPositionChanged: (position, hasGesture) {
          if (mounted) setState(() {});
        },
        onTap: widget.enableSelection
            ? (event, point) {
                ref.read(mapSelectionProvider.notifier).selectCoordinate(
                      MapCoordinate(
                        latitude: point.latitude,
                        longitude: point.longitude,
                      ),
                    );
                widget.onCoordinateSelected?.call(
                  MapCoordinate(
                    latitude: point.latitude,
                    longitude: point.longitude,
                  ),
                );
              }
            : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.openspaceparking.app',
          maxZoom: _maxZoom,
          keepBuffer: 1,
        ),
        MarkerLayer(
          markers: _buildMarkers(
            selected: selected,
            currentLocation: currentLocation,
          ),
        ),
      ],
    );

    final content = widget.height != null
        ? SizedBox(height: widget.height, child: map)
        : map;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          content,
          Positioned(
            right: 12,
            top: 12,
            child: _buildMapControlsColumn(mapState: mapState),
          ),
        ],
      ),
    );
  }
}
