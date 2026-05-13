import 'package:flutter/material.dart';

/// Outlined social login tile: white background, black border, offset shadow.
///
/// Matches the "Google" / "Apple" buttons in the login mockup.
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isEnabled = true,
  });

  /// Text next to the icon ("Google", "Apple").
  final String label;

  /// Called when the user taps the button (only if [isEnabled] is true).
  final VoidCallback onPressed;

  /// Optional leading widget (brand icon or image).
  final Widget? icon;

  /// When false, the button is greyed out and taps are ignored (e.g. while loading).
  final bool isEnabled;

  static const Color _borderBlack = Color(0xFF000000);
  static const double _radius = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: isEnabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onPressed : null,
          borderRadius: BorderRadius.circular(_radius),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: _borderBlack, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: 10),
                ],
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _borderBlack,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
