import 'package:flutter/material.dart';

import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';

class OwnerDetailsForm extends StatefulWidget {
  const OwnerDetailsForm({
    super.key,
    required this.initial,
    required this.onSave,
  });

  final OwnerDetails? initial;
  final ValueChanged<OwnerDetails> onSave;

  @override
  State<OwnerDetailsForm> createState() => OwnerDetailsFormState();
}

class OwnerDetailsFormState extends State<OwnerDetailsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _aadhaarController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.fullName ?? '');
    _phoneController = TextEditingController(text: widget.initial?.phone ?? '');
    _emailController = TextEditingController(text: widget.initial?.email ?? '');
    _addressController = TextEditingController(text: widget.initial?.address ?? '');
    _aadhaarController =
        TextEditingController(text: widget.initial?.aadhaarNumber ?? '');
  }

  @override
  void didUpdateWidget(covariant OwnerDetailsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final initial = widget.initial;
    if (initial == null) return;

    if (_nameController.text.isEmpty && initial.fullName.isNotEmpty) {
      _nameController.text = initial.fullName;
    }
    if (_phoneController.text.isEmpty && initial.phone.isNotEmpty) {
      _phoneController.text = initial.phone;
    }
    if (_emailController.text.isEmpty && initial.email.isNotEmpty) {
      _emailController.text = initial.email;
    }
    if (_addressController.text.isEmpty && initial.address.isNotEmpty) {
      _addressController.text = initial.address;
    }
    if (_aadhaarController.text.isEmpty &&
        (initial.aadhaarNumber?.isNotEmpty ?? false)) {
      _aadhaarController.text = initial.aadhaarNumber!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }

  bool validateAndSave() {
    if (!_formKey.currentState!.validate()) return false;

    widget.onSave(
      OwnerDetails(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        aadhaarNumber: _aadhaarController.text.replaceAll(RegExp(r'\s+'), ''),
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AppTextField(
            controller: _nameController,
            label: 'Full Name',
            validator: (v) => Validators.requiredField(v, fieldName: 'Name'),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _phoneController,
            label: 'Phone Number',
            keyboardType: TextInputType.phone,
            validator: (v) => Validators.requiredField(v, fieldName: 'Phone'),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _emailController,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _addressController,
            label: 'Address',
            validator: (v) => Validators.requiredField(v, fieldName: 'Address'),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _aadhaarController,
            label: 'Aadhaar Number',
            keyboardType: TextInputType.number,
            validator: Validators.aadhaar,
          ),
        ],
      ),
    );
  }
}
