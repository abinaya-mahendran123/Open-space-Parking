import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/land_location_picker_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/yes_no_tile.dart';
import 'package:open_space_parking/features/maps/domain/entities/geocoding_result.dart';
import 'package:open_space_parking/features/maps/domain/entities/location_permission_status.dart';
import 'package:open_space_parking/features/maps/domain/repositories/maps_repository.dart';
import 'package:open_space_parking/features/maps/presentation/utils/location_access.dart';

class LandDetailsForm extends StatefulWidget {
  const LandDetailsForm({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final LandDetails? initial;
  final ValueChanged<LandDetails> onSave;

  @override
  State<LandDetailsForm> createState() => LandDetailsFormState();
}

class LandDetailsFormState extends State<LandDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _areaController;
  late final TextEditingController _locationNameController;

  bool _roadAccess = false;
  bool _drainage = false;
  bool _flood = false;
  bool _boundary = false;
  bool _cctv = false;
  GeocodingResult? _resolvedLocation;
  bool _applyingPickedLocation = false;
  bool _isOpeningMapPicker = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _areaController =
        TextEditingController(text: initial?.areaSqFt.toString() ?? '');
    _locationNameController =
        TextEditingController(text: initial?.landAddress ?? '');
    _roadAccess = initial?.roadAccess ?? false;
    _drainage = initial?.drainage ?? false;
    _flood = initial?.flood ?? false;
    _boundary = initial?.boundary ?? false;
    _cctv = initial?.cctv ?? false;

    if (initial != null &&
        initial.landAddress != null &&
        initial.landAddress!.isNotEmpty &&
        initial.gpsLatitude != 0 &&
        initial.gpsLongitude != 0) {
      _resolvedLocation = GeocodingResult(
        latitude: initial.gpsLatitude,
        longitude: initial.gpsLongitude,
        displayName: initial.landAddress!,
      );
    }
    _locationNameController.addListener(_onLocationNameChanged);
  }

  void _onLocationNameChanged() {
    if (_applyingPickedLocation) return;
    if (_resolvedLocation != null) {
      setState(() => _resolvedLocation = null);
    }
  }

  @override
  void dispose() {
    _locationNameController.removeListener(_onLocationNameChanged);
    _areaController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }

  Future<bool> _ensureLocationAccess() async {
    final mapsRepo = GetIt.I<MapsRepository>();
    final permission = await LocationAccess.ensure(
      context: context,
      repository: mapsRepo,
    );
    if (!permission.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocationAccess.messageFor(permission))),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _openLocationPicker({
    required String initialName,
    required bool searchOnOpen,
  }) async {
    if (!await _ensureLocationAccess()) return;
    if (!mounted) return;

    final result = await Navigator.of(context).push<GeocodingResult>(
      MaterialPageRoute(
        builder: (_) => LandLocationPickerPage(
          initialLocationName: initialName,
          searchOnOpen: searchOnOpen,
        ),
      ),
    );

    if (!mounted || result == null) return;

    _applyPickedLocation(result);
  }

  void _applyPickedLocation(GeocodingResult result) {
    _applyingPickedLocation = true;
    _locationNameController.text = result.displayName;
    _applyingPickedLocation = false;
    setState(() => _resolvedLocation = result);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Location saved: ${result.displayName}')),
    );
  }

  Future<void> _verifyByName() async {
    final locationName = _locationNameController.text.trim();
    if (locationName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a location name to verify.')),
      );
      return;
    }

    await _openLocationPicker(
      initialName: locationName,
      searchOnOpen: true,
    );
  }

  Future<void> _pickOnMap() async {
    if (_isOpeningMapPicker) return;

    setState(() => _isOpeningMapPicker = true);
    try {
      await _openLocationPicker(
        initialName: '',
        searchOnOpen: false,
      );
    } finally {
      if (mounted) setState(() => _isOpeningMapPicker = false);
    }
  }

  Future<bool> validateAndSave() async {
    if (!_formKey.currentState!.validate()) return false;

    if (_resolvedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set your land location by verifying the name or picking on the map.',
          ),
        ),
      );
      return false;
    }

    final area = double.tryParse(_areaController.text);
    if (area == null) return false;

    widget.onSave(
      LandDetails(
        gpsLatitude: _resolvedLocation!.latitude,
        gpsLongitude: _resolvedLocation!.longitude,
        areaSqFt: area,
        roadAccess: _roadAccess,
        drainage: _drainage,
        flood: _flood,
        boundary: _boundary,
        cctv: _cctv,
        landAddress: _resolvedLocation!.displayName,
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _locationNameController,
            label: 'Location Name',
            hint: 'e.g. Anna Nagar, Chennai',
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _verifyByName(),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose either option: type the area name and verify, or pick on the map '
            'manually — pin the spot, then tap Confirm Location to save.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Verify by Name',
            onPressed: _verifyByName,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isOpeningMapPicker ? null : _pickOnMap,
            icon: _isOpeningMapPicker
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  )
                : const Icon(Icons.map_outlined),
            label: Text(
              _isOpeningMapPicker ? 'Opening map...' : 'Pick on Map Manually',
            ),
          ),
          if (_resolvedLocation != null) ...[
            const SizedBox(height: 12),
            Card(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Location set',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _resolvedLocation!.displayName,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          AppTextField(
            controller: _areaController,
            label: 'Area (sq ft)',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => Validators.requiredField(v, fieldName: 'Area'),
          ),
          const SizedBox(height: 8),
          Text(
            'Total usable land area in square feet that can be used for parking '
            '(include the full plot size you plan to offer, not just the built portion).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          YesNoTile(
            label: 'Road Access',
            description:
                'Select Yes if vehicles can drive in and out directly from a public '
                'road or driveway. Select No if access is only on foot or through '
                'narrow lanes where cars cannot enter.',
            value: _roadAccess,
            onChanged: (v) => setState(() => _roadAccess = v),
          ),
          YesNoTile(
            label: 'Drainage',
            description:
                'Select Yes if the land has proper water drainage (storm drains, '
                'slopes, or channels) so rain water does not collect on the surface. '
                'Select No if waterlogging is common after rain.',
            value: _drainage,
            onChanged: (v) => setState(() => _drainage = v),
          ),
          YesNoTile(
            label: 'Flood',
            description:
                'Select Yes if the land is in a flood-prone area or gets submerged '
                'during heavy rain or monsoon. Select No if flooding is not a concern '
                'at this location.',
            value: _flood,
            onChanged: (v) => setState(() => _flood = v),
          ),
          YesNoTile(
            label: 'Boundary',
            description:
                'Select Yes if the property has clear physical boundaries such as a '
                'compound wall, fence, or marked borders. Select No if the land is '
                'open or boundaries are not defined.',
            value: _boundary,
            onChanged: (v) => setState(() => _boundary = v),
          ),
          YesNoTile(
            label: 'CCTV',
            description:
                'Select Yes if CCTV cameras are already installed or will be available '
                'to monitor the parking area. Select No if there is no surveillance '
                'on site.',
            value: _cctv,
            onChanged: (v) => setState(() => _cctv = v),
          ),
        ],
      ),
    );
  }
}
