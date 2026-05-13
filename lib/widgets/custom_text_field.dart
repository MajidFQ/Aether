import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Neo-brutalist text field: white fill, 2px black border, rounded corners.
///
/// Validation messages are passed in as [errorText] from the parent screen so you
/// can combine format checks and Firebase error mapping in one place.
class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.label,
    this.labelTrailing,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.autocorrect = true,
    this.errorText,
    this.onChanged,
    this.inputFormatters,
  });

  /// Small bold label shown above the box (e.g. "Email Address").
  final String label;

  /// Optional widget on the same row as the label (e.g. "Forgot?" link).
  final Widget? labelTrailing;

  /// Holds what the user typed; parent owns disposal.
  final TextEditingController controller;

  /// Grey placeholder inside the field.
  final String hintText;

  /// When true, shows bullets instead of characters (password fields).
  final bool obscureText;

  /// Which keyboard to show (email, text, etc.).
  final TextInputType keyboardType;

  /// What the "done" key does on the keyboard.
  final TextInputAction textInputAction;

  /// Turn off suggestions for passwords.
  final bool autocorrect;

  /// Shown in red under the field when non-null (client or server validation).
  final String? errorText;

  /// Called on every keystroke; use to clear errors while typing.
  final ValueChanged<String>? onChanged;

  /// Optional input formatters (e.g. length limits).
  final List<TextInputFormatter>? inputFormatters;

  static const Color _borderBlack = Color(0xFF000000);
  static const Color _hintGray = Color(0xFFB0B0B5);
  static const double _radius = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;

    final decoration = InputDecoration(
      hintText: hintText,
      hintStyle: theme.textTheme.bodyLarge?.copyWith(
        color: _hintGray,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(
          color: hasError ? Colors.red : _borderBlack,
          width: 2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(
          color: hasError ? Colors.red : _borderBlack,
          width: 2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: BorderSide(
          color: hasError ? Colors.red : _borderBlack,
          width: 2,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _borderBlack,
                ),
              ),
            ),
            ?labelTrailing,
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autocorrect: autocorrect,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          decoration: decoration,
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
          ),
        ],
      ],
    );
  }
}
