import 'dart:async';

import 'package:flutter/material.dart';

import 'package:open_space_parking/core/services/api/parking_slot_estimate_service.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_priority.dart';

enum ReviewTicketMode { buildParking, existingParking }

/// Editable review page shared by Build Parking and Already Have Parking.
class ReviewTicketForm extends StatefulWidget {
  const ReviewTicketForm({
    super.key,
    required this.mode,
    required this.ownerDetails,
    required this.landDetails,
    required this.onOwnerChanged,
    required this.onLandChanged,
    this.priority,
    this.parkingType,
    this.numberOfCars,
    this.hourlyRate,
    this.onPriorityChanged,
    this.onParkingTypeChanged,
    this.onNumberOfCarsChanged,
    this.onHourlyRateChanged,
  });

  final ReviewTicketMode mode;
  final OwnerDetails ownerDetails;
  final LandDetails landDetails;
  final ValueChanged<OwnerDetails> onOwnerChanged;
  final ValueChanged<LandDetails> onLandChanged;

  final RequestPriority? priority;
  final ParkingType? parkingType;
  final int? numberOfCars;
  final double? hourlyRate;
  final ValueChanged<RequestPriority>? onPriorityChanged;
  final ValueChanged<ParkingType>? onParkingTypeChanged;
  final ValueChanged<int>? onNumberOfCarsChanged;
  final ValueChanged<double?>? onHourlyRateChanged;

  @override
  State<ReviewTicketForm> createState() => ReviewTicketFormState();
}

class ReviewTicketFormState extends State<ReviewTicketForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _idNumberController;
  late final TextEditingController _areaController;
  late final TextEditingController _carsController;
  late final TextEditingController _rateController;
  final _slotEstimateService = ParkingSlotEstimateService();

  int? _estimatedSlots;
  bool _estimatingSlots = false;
  Timer? _slotEstimateDebounce;
  int _slotEstimateRequestId = 0;

  @override
  void initState() {
    super.initState();
    final owner = widget.ownerDetails;
    final land = widget.landDetails;
    _nameController = TextEditingController(text: owner.fullName);
    _phoneController = TextEditingController(text: owner.phone);
    _addressController = TextEditingController(text: owner.address);
    _idNumberController = TextEditingController(
      text: owner.governmentIdNumber ?? owner.aadhaarNumber ?? '',
    );
    _areaController = TextEditingController(
      text: land.areaSqFt > 0 ? land.areaSqFt.toStringAsFixed(0) : '',
    );
    _carsController = TextEditingController(
      text: (widget.numberOfCars != null && widget.numberOfCars! > 0)
          ? '${widget.numberOfCars}'
          : '',
    );
    _rateController = TextEditingController(
      text: (widget.hourlyRate != null && widget.hourlyRate! > 0)
          ? widget.hourlyRate!.toStringAsFixed(0)
          : '',
    );
    if (widget.mode == ReviewTicketMode.existingParking) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scheduleSlotEstimate());
    }
  }

  @override
  void dispose() {
    _slotEstimateDebounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _idNumberController.dispose();
    _areaController.dispose();
    _carsController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _scheduleSlotEstimate() {
    _slotEstimateDebounce?.cancel();
    final area = double.tryParse(_areaController.text.trim()) ?? 0;
    if (area <= 0) {
      if (mounted) {
        setState(() {
          _estimatedSlots = null;
          _estimatingSlots = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _estimatingSlots = true);
    _slotEstimateDebounce = Timer(const Duration(milliseconds: 450), () {
      _fetchSlotEstimate(area);
    });
  }

  Future<void> _fetchSlotEstimate(double area) async {
    final requestId = ++_slotEstimateRequestId;
    try {
      final slots = await _slotEstimateService.estimateSlots(area);
      if (!mounted || requestId != _slotEstimateRequestId) return;
      setState(() {
        _estimatedSlots = slots > 0 ? slots : null;
        _estimatingSlots = false;
      });
    } catch (_) {
      if (!mounted || requestId != _slotEstimateRequestId) return;
      setState(() {
        _estimatedSlots = null;
        _estimatingSlots = false;
      });
    }
  }

  void _pushOwner() {
    final id = _idNumberController.text.trim();
    widget.onOwnerChanged(
      widget.ownerDetails.copyWith(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        governmentIdNumber: id.isEmpty ? null : id,
        aadhaarNumber: id.isEmpty ? null : id,
      ),
    );
  }

  void _pushLand() {
    final area = double.tryParse(_areaController.text.trim()) ?? 0;
    widget.onLandChanged(widget.landDetails.copyWith(areaSqFt: area));
  }

  /// Returns false when required editable fields are invalid.
  bool validateAndSave() {
    _pushOwner();
    _pushLand();

    if (_nameController.text.trim().isEmpty) return false;
    if (_phoneController.text.trim().isEmpty) return false;
    final area = double.tryParse(_areaController.text.trim());
    if (area == null || area <= 0) return false;

    if (widget.mode == ReviewTicketMode.buildParking) {
      final cars = int.tryParse(_carsController.text.trim());
      if (cars == null || cars <= 0) return false;
      widget.onNumberOfCarsChanged?.call(cars);
    } else {
      final rate = double.tryParse(_rateController.text.trim());
      if (rate == null || rate <= 0) return false;
      widget.onHourlyRateChanged?.call(rate);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Review your details and edit anything that looks wrong before submitting.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Owner / Full Name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => _pushOwner(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          onChanged: (_) => _pushOwner(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _idNumberController,
          decoration: InputDecoration(
            labelText: widget.ownerDetails.governmentIdType?.label ?? 'Aadhaar Number',
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (_) => _pushOwner(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Address',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (_) => _pushOwner(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _areaController,
          decoration: const InputDecoration(
            labelText: 'Area (sq ft)',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) {
            _pushLand();
            if (widget.mode == ReviewTicketMode.existingParking) {
              _scheduleSlotEstimate();
            } else {
              setState(() {});
            }
          },
        ),
        if (widget.mode == ReviewTicketMode.buildParking) ...[
          const SizedBox(height: 16),
          Text('Priority', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<RequestPriority>(
            segments: RequestPriority.values
                .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                .toList(),
            selected: {widget.priority ?? RequestPriority.notImmediate},
            onSelectionChanged: (s) => widget.onPriorityChanged?.call(s.first),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ParkingType>(
            initialValue: widget.parkingType ?? ParkingType.towerParking,
            decoration: const InputDecoration(
              labelText: 'Parking Type',
              border: OutlineInputBorder(),
            ),
            items: ParkingType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) {
              if (v != null) widget.onParkingTypeChanged?.call(v);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _carsController,
            decoration: const InputDecoration(
              labelText: 'No of Cars / Slots',
              hintText: 'e.g. 100 cars',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final cars = int.tryParse(v.trim());
              if (cars != null && cars > 0) {
                widget.onNumberOfCarsChanged?.call(cars);
              }
            },
          ),
        ] else ...[
          const SizedBox(height: 12),
          if (_estimatingSlots)
            Text(
              'Estimating slots…',
              style: theme.textTheme.bodySmall,
            )
          else if (_estimatedSlots != null)
            Text(
              'Estimated slots: $_estimatedSlots',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _rateController,
            decoration: const InputDecoration(
              labelText: 'Hourly Amount (₹)',
              hintText: 'Enter parking fee per hour',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final rate = double.tryParse(v.trim());
              widget.onHourlyRateChanged?.call(rate);
            },
          ),
        ],
      ],
    );
  }
}
