import 'package:flutter/material.dart';

/// Table-side legibility drives every choice here: dense enough to show a
/// unit's full weapon table without scrolling, high-contrast enough to read at
/// arm's length under bad lighting, with touch targets sized for a hand that is
/// also holding dice.
abstract final class AppTheme {
  static const _seed = Color(0xFF7A5CFF);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        labelStyle: TextStyle(
          fontSize: 10,
          height: 1.1,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 8,
        dense: true,
      ),
    );
  }

  /// Tabular figures matter: statlines must align down a column.
  static TextStyle numeric(BuildContext context, {double size = 13}) =>
      TextStyle(
        fontSize: size,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );
}
