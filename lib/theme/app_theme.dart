import 'package:material_ui/material_ui.dart';

class AppTheme {
  static const Color _fallbackSeed = Color(0xFF3F51B5);

  static ThemeData light({Color? dynamicSeed}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: dynamicSeed ?? _fallbackSeed,
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData dark({Color? dynamicSeed}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: dynamicSeed ?? _fallbackSeed,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surfaceContainerLow,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
