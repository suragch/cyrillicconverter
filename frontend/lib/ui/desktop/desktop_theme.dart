import 'package:flutter/material.dart';

/// Desktop-native design system colors, metrics, and typography.
/// Follows modern desktop software patterns (Linear, VS Code, DeepL Desktop):
/// crisp 1px borders, slate/neutral surfaces, 4-6px subtle corner curves, and compact density.
class DesktopTheme {
  // --- Surfaces & Canvas ---
  static const Color canvas = Color(0xFFF8FAFC); // Slate-50
  static const Color panelBackground = Color(0xFFFFFFFF); // Pure white
  static const Color panelHeaderBackground = Color(0xFFF8FAFC); // Slate-50
  static const Color secondarySurface = Color(0xFFF1F5F9); // Slate-100
  static const Color hoverBackground = Color(0xFFE2E8F0); // Slate-200
  static const Color activeBackground = Color(0xFFCBD5E1); // Slate-300

  // --- Borders & Dividers ---
  static const Color border = Color(0xFFE2E8F0); // Subtle 1px slate-200 border
  static const Color borderMedium = Color(0xFFCBD5E1); // Slate-300 border
  static const Color borderFocus = Color(0xFF2563EB); // Blue-600 focus ring

  // --- Text & Foreground ---
  static const Color textPrimary = Color(0xFF0F172A); // Slate-900
  static const Color textSecondary = Color(0xFF475569); // Slate-600
  static const Color textMuted = Color(0xFF94A3B8); // Slate-400

  // --- Brand & Primary Action ---
  static const Color primary = Color(0xFF2563EB); // Blue-600
  static const Color primaryHover = Color(0xFF1D4ED8); // Blue-700
  static const Color primaryActive = Color(0xFF1E40AF); // Blue-800
  static const Color primarySurface = Color(0xFFEFF6FF); // Blue-50

  // --- Semantic States ---
  static const Color success = Color(0xFF16A34A); // Green-600
  static const Color successSurface = Color(0xFFF0FDF4); // Green-50
  static const Color successBorder = Color(0xFFBBF7D0); // Green-200

  static const Color warning = Color(0xFFD97706); // Amber-600
  static const Color warningSurface = Color(0xFFFFFBEB); // Amber-50
  static const Color warningBorder = Color(0xFFFDE68A); // Amber-200

  static const Color danger = Color(0xFFDC2626); // Red-600
  static const Color dangerSurface = Color(0xFFFEF2F2); // Red-50
  static const Color dangerBorder = Color(0xFFFECACA); // Red-200

  // --- Corner Radii ---
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 6.0;
  static const double radiusLarge = 8.0;

  static const BorderRadius roundedSmall = BorderRadius.all(Radius.circular(radiusSmall));
  static const BorderRadius roundedMedium = BorderRadius.all(Radius.circular(radiusMedium));
  static const BorderRadius roundedLarge = BorderRadius.all(Radius.circular(radiusLarge));

  // --- Shadows ---
  static const List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> dialogShadow = [
    BoxShadow(
      color: Color(0x1E000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  // --- Standard Desktop Typography ---
  static const TextStyle titleBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    fontFamily: null,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    color: textPrimary,
    fontFamily: null,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 13,
    color: textSecondary,
    fontFamily: null,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: textMuted,
    fontFamily: null,
  );

  static const TextStyle hotkeyBadge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    fontFamily: 'monospace',
    color: textSecondary,
  );

  /// Global ThemeData configured for desktop styling
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: canvas,
      fontFamily: null, // System desktop font stack
      colorScheme: const ColorScheme.light(
        primary: primary,
        surface: panelBackground,
        onSurface: textPrimary,
        error: danger,
      ),
      dividerColor: border,
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
