import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.maxLines = 1,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.maxLength,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final int maxLines;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  /// After a failed submit, hide the error as soon as the user edits again.
  bool _hideErrorWhileEditing = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.obscureText,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      autovalidateMode: AutovalidateMode.disabled,
      validator: (value) {
        final error = widget.validator?.call(value);
        // Form.validate() should always show errors again.
        _hideErrorWhileEditing = false;
        return error;
      },
      onChanged: (value) {
        if (!_hideErrorWhileEditing) {
          setState(() => _hideErrorWhileEditing = true);
        }
        widget.onChanged?.call(value);
      },
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        prefixText: widget.prefixText,
        suffixIcon: widget.suffixIcon,
        // Keep validator result for Form.validate(), but visually hide it
        // once the user starts typing again.
        errorStyle: _hideErrorWhileEditing
            ? const TextStyle(height: 0, fontSize: 0, color: Colors.transparent)
            : null,
      ),
    );
  }
}
