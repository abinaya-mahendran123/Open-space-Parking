import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_marker_data.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/map_zoom_controls.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/osm_map_view.dart';
class GoogleMapView extends ConsumerStatefulWidget {
  const GoogleMapView({
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
  ConsumerState<GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends ConsumerState<GoogleMapView> {
  GoogleMapController? _controller;
  double _currentZoom = 14;
  static const _minZoom = 5.0;
  static const _maxZoom = 18.0;
  MapCoordinate? _lastCenteredLocation;

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.initialZoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mapSelectionProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Native GoogleMap crashes the process if com.google.android.geo.API_KEY
    // is missing. Use OSM until a Maps key is configured.
    const mapsKey = String.fromEnvironment(
      'GOOGLE_MAPS_API_KEY',
      defaultValue: '',
    );
    if (kIsWeb || mapsKey.isEmpty) {
      return OsmMapView(
        height: widget.height,
        markers: widget.markers,
        enableSelection: widget.enableSelection,
        showCurrentLocation: widget.showCurrentLocation,
        highlightedMarker: widget.highlightedMarker,
        initialZoom: widget.initialZoom,
        onMarkerTap: widget.onMarkerTap,
        onCoordinateSelected: widget.onCoordinateSelected,
      );
    }

    ref.listen<MapSelectionState>(mapSelectionProvider, (previous, next) {
      if (!widget.showCurrentLocation) return;
      final loc = next.currentLocation;
      if (loc != null && loc != _lastCenteredLocation) {
        _lastCenteredLocation = loc;
        _moveTo(LatLng(loc.latitude, loc.longitude), zoom: 15);
      }
    });

    final mapState = ref.watch(mapSelectionProvider);
    final currentLocation =
        widget.showCurrentLocation ? mapState.currentLocation : null;
    final selected = widget.enableSelection ? mapState.selected : null;

    final googleMarkers = buildGoogleMarkers(
      markers: widget.markers,
      selected: selected,
      currentLocation: currentLocation,
      highlighted: widget.highlightedMarker,
      onTap: widget.onMarkerTap,
    );

    final initialTarget = initialCameraTarget(
      selected: selected,
      currentLocation: currentLocation,
      markers: widget.markers,
    )!;

    final map = GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialTarget,
        zoom: widget.initialZoom,
      ),
      markers: googleMarkers,
      myLocationEnabled: widget.showCurrentLocation && mapState.permission.isGranted,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        _controller = controller;
        _refreshZoom();
      },
      onTap: widget.enableSelection
          ? (latLng) {
              ref.read(mapSelectionProvider.notifier).selectFromLatLng(latLng);
              widget.onCoordinateSelected?.call(
                MapCoordinate(
                  latitude: latLng.latitude,
                  longitude: latLng.longitude,
                ),
              );
            }
          : null,
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

  Future<void> _refreshZoom() async {
    final zoom = await _controller?.getZoomLevel();
    if (zoom != null && mounted) {
      setState(() => _currentZoom = zoom);
    }
  }

  Future<void> _zoomIn() async {
    if (_controller == null || _currentZoom >= _maxZoom) return;
    await _controller!.animateCamera(CameraUpdate.zoomIn());
    await _refreshZoom();
  }

  Future<void> _zoomOut() async {
    if (_controller == null || _currentZoom <= _minZoom) return;
    await _controller!.animateCamera(CameraUpdate.zoomOut());
    await _refreshZoom();
  }

  Future<void> _moveTo(LatLng target, {double? zoom}) async {
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(target, zoom ?? widget.initialZoom),
    );
    await _refreshZoom();
  }

  Widget _buildMapControlsColumn({required MapSelectionState mapState}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showCurrentLocation)
          FloatingActionButton.small(
            heroTag: null,
            onPressed: mapState.isLoadingLocation
                ? null
                : () async {
                    await ref
                        .read(mapSelectionProvider.notifier)
                        .refreshCurrentLocation();
                    final loc = ref.read(mapSelectionProvider).currentLocation;
                    if (loc != null) {
                      await _moveTo(
                        LatLng(loc.latitude, loc.longitude),
                        zoom: 16,
                      );
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
          onZoomIn: _currentZoom < _maxZoom ? _zoomIn : null,
          onZoomOut: _currentZoom > _minZoom ? _zoomOut : null,
        ),
      ],
    );
  }
}
