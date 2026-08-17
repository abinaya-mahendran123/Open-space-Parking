import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/maps/domain/entities/geocoding_result.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/google_map_view.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/location_permission_banner.dart';
import 'package:open_space_parking/features/maps/presentation/widgets/selected_coordinate_card.dart';

class LandLocationPickerPage extends ConsumerStatefulWidget {
  const LandLocationPickerPage({
    super.key,
    this.initialLocationName = '',
    this.searchOnOpen = false,
  });

  /// Pre-filled location name when opening from "Verify by name".
  final String initialLocationName;

  /// When true and [initialLocationName] is not empty, the map searches on open.
  final bool searchOnOpen;

  @override
  ConsumerState<LandLocationPickerPage> createState() =>
      _LandLocationPickerPageState();
}

class _LandLocationPickerPageState extends ConsumerState<LandLocationPickerPage> {
  late final TextEditingController _locationController;
  bool _isSearching = false;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.initialLocationName);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapMap());
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapMap() async {
    await ref.read(mapSelectionProvider.notifier).initialize();
    if (widget.searchOnOpen && widget.initialLocationName.trim().isNotEmpty) {
      await _searchArea(centerOnly: true);
    }
  }

  Future<void> _searchArea({bool centerOnly = false}) async {
    final locationName = _locationController.text.trim();
    if (locationName.isEmpty) {
      _showMessage('Enter a location name to search on the map.');
      return;
    }

    setState(() => _isSearching = true);
    try {
      final result =
          await ref.read(mapsRepositoryProvider).geocodeLocationName(locationName);
      ref.read(mapSelectionProvider.notifier).selectCoordinate(result.coordinate);
      if (!centerOnly && mounted) {
        _showMessage('Location found. Tap the map to adjust the pin if needed.');
      }
    } on AppException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Could not find that location.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _confirmSelection() async {
    if (_isConfirming) return;

    final selected = ref.read(mapSelectionProvider).selected;
    if (selected == null) {
      _showMessage('Tap on the map to select your exact land location.');
      return;
    }

    setState(() => _isConfirming = true);
    try {
      final typedName = _locationController.text.trim();
      GeocodingResult result;
      try {
        result = await ref.read(mapsRepositoryProvider).reverseGeocode(
              latitude: selected.latitude,
              longitude: selected.longitude,
            );
      } catch (_) {
        result = GeocodingResult(
          latitude: selected.latitude,
          longitude: selected.longitude,
          displayName: typedName.isNotEmpty ? typedName : selected.label,
        );
      }

      if (typedName.isNotEmpty &&
          result.displayName.trim().isEmpty) {
        result = GeocodingResult(
          latitude: result.latitude,
          longitude: result.longitude,
          displayName: typedName,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, result);
    } on AppException catch (e) {
      if (mounted) {
        final selected = ref.read(mapSelectionProvider).selected;
        if (selected != null) {
          Navigator.pop(
            context,
            GeocodingResult(
              latitude: selected.latitude,
              longitude: selected.longitude,
              displayName: selected.label,
            ),
          );
          return;
        }
        _showMessage(e.message);
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildFooter({required MapCoordinate? selected}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (selected != null)
          SelectedCoordinateCard(
            coordinate: selected,
            title: 'Pinned location',
          ),
        if (selected != null) const SizedBox(height: 12),
        PrimaryButton(
          label: 'Confirm Location',
          isLoading: _isConfirming,
          onPressed: selected == null || _isConfirming ? null : _confirmSelection,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapSelectionProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final selected = mapState.selected;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Land Location')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const LocationPermissionBanner(),
                  Text(
                    'Search by location name to move the map, or tap the map to pin '
                    'your land. Tap Confirm Location when the pin is correct.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _locationController,
                    label: 'Location Name (optional for map pick)',
                    hint: 'e.g. Anna Nagar, Chennai',
                    textInputAction: TextInputAction.search,
                    onFieldSubmitted: (_) => _searchArea(),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isSearching ? null : () => _searchArea(),
                    icon: _isSearching
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          )
                        : const Icon(Icons.search),
                    label:
                        Text(_isSearching ? 'Searching...' : 'Search on map'),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: GoogleMapView(
                  key: ValueKey('land_location_map'),
                  enableSelection: true,
                  showCurrentLocation: true,
                  initialZoom: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildFooter(selected: selected),
            ),
          ],
        ),
      ),
    );
  }
}
