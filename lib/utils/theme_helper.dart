import 'package:flutter/material.dart';

/// Simple helper to get theme-aware colors.
/// Call isDarkMode(context) to check if dark mode is active.
bool isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

/// Get background color based on theme.
Color getBackgroundColor(BuildContext context) {
  return isDarkMode(context) 
      ? const Color(0xFF1E1E2E) 
      : const Color(0xFFF5F5F7);
}

/// Get card background color based on theme.
Color getCardColor(BuildContext context) {
  return isDarkMode(context) 
      ? const Color(0xFF2A2A3E) 
      : Colors.white;
}

/// Get text color based on theme.
Color getTextColor(BuildContext context) {
  return isDarkMode(context) 
      ? Colors.white 
      : const Color(0xFF000000);
}

/// Get muted text color based on theme.
Color getMutedTextColor(BuildContext context) {
  return isDarkMode(context) 
      ? const Color(0xFFB0B0B8) 
      : const Color(0xFF6B6B70);
}
