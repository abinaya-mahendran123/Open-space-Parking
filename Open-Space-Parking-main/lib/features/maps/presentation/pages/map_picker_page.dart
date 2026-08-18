import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/maps/domain/entities/geocoding_result.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';

class MapPickerPage extends ConsumerStatefulWidget {
  const MapPickerPage({
    super.key,
    this.initialCoordinate,
    this.title = 'Pick Location',
  });

  final MapCoordinate? initialCoordinate;
  final String title;

  @override
  ConsumerState<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends ConsumerState<MapPickerPage> {
  final _locationController = TextEditingController();
  GeocodingResult? _resolved;
  bool _isLoading = false;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<GeocodingResult?> _lookupLocation() async {
    final locationName = _locationController.text.trim();
    if (locationName.isEmpty) {
      ref.read(snackbarServiceProvider).showError('Enter a location name.');
      return null;
    }
    if (Validators.requiredField(locationName, fieldName: 'Location name') !=
        null) {
      return null;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ref
          .read(mapsRepositoryProvider)
          .geocodeLocationName(locationName);
      if (mounted) setState(() => _resolved = result);
      return result;
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
      if (mounted) setState(() => _resolved = null);
      return null;
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not find that location.');
      if (mounted) setState(() => _resolved = null);
      return null;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCoordinate() async {
    final result = _resolved ?? await _lookupLocation();
    if (result == null) return;

    await ref.read(mapsRepositoryProvider).saveCoordinate(
          label: result.displayName,
          coordinate: result.coordinate,
        );
    ref.invalidate(savedCoordinatesProvider);
    ref.read(snackbarServiceProvider).showSuccess('Location saved.');
  }

  Future<void> _confirmSelection() async {
    final result = _resolved ?? await _lookupLocation();
    if (result == null || !mounted) return;
    context.pop(result.coordinate);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the location name and the app will find it for you.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _locationController,
                label: 'Location Name',
                hint: 'e.g. Chennai, Tamil Nadu',
                textInputAction: TextInputAction.search,
                onFieldSubmitted: (_) => _lookupLocation(),
                validator: (v) =>
                    Validators.requiredField(v, fieldName: 'Location name'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _lookupLocation,
                icon: _isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_isLoading ? 'Finding location...' : 'Find Location'),
              ),
              if (_resolved != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.place, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location found',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _resolved!.displayName,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _saveCoordinate,
                      child: const Text('Save Location'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Use Location',
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _confirmSelection,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
