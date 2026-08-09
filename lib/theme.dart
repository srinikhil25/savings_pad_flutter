import 'package:flutter/material.dart';

/// Material 3 colour schemes seeded from one colour, so light and dark stay
/// consistent without hand-picking every shade.
class SavingsTheme {
  static const seed = Color(0xFF10B981);

  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Semantic colours for money. Green means the stash grew, red means it
/// shrank — used in one place so the meaning never drifts between screens.
extension MoneyColors on ColorScheme {
  Color get positive => brightness == Brightness.dark
      ? const Color(0xFF34D399)
      : const Color(0xFF047857);

  Color get negative => brightness == Brightness.dark
      ? const Color(0xFFF87171)
      : const Color(0xFFB91C1C);

  Color get caution => brightness == Brightness.dark
      ? const Color(0xFFFBBF24)
      : const Color(0xFF92600A);
}
