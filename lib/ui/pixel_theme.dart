import 'package:flutter/material.dart';

@immutable
class PixelTheme extends ThemeExtension<PixelTheme> {
  const PixelTheme({
    required this.background,
    required this.surface,
    required this.raisedSurface,
    required this.line,
    required this.grid,
    required this.accent,
    required this.dimAccent,
    required this.onAccent,
    required this.primaryText,
    required this.mutedText,
    required this.warning,
    required this.danger,
    this.gridUnit = 4,
    this.borderWidth = 2,
  });

  static const defaults = PixelTheme(
    background: Color(0xFF1F1F1F),
    surface: Color(0xFF292929),
    raisedSurface: Color(0xFF292929),
    line: Color(0xFF3A7C41),
    grid: Color(0x293A7C41),
    accent: Color(0xFF74B150),
    dimAccent: Color(0xFF3A7C41),
    onAccent: Color(0xFF1F1F1F),
    primaryText: Color(0xFFDCDCDC),
    mutedText: Color(0xB3DCDCDC),
    warning: Color(0xFFD2A64A),
    danger: Color(0xFFE07373),
  );

  final Color background;
  final Color surface;
  final Color raisedSurface;
  final Color line;
  final Color grid;
  final Color accent;
  final Color dimAccent;
  final Color onAccent;
  final Color primaryText;
  final Color mutedText;
  final Color warning;
  final Color danger;
  final double gridUnit;
  final double borderWidth;

  double get space4 => gridUnit;
  double get space8 => gridUnit * 2;
  double get space12 => gridUnit * 3;
  double get space16 => gridUnit * 4;
  double get space24 => gridUnit * 6;
  double get space32 => gridUnit * 8;

  @override
  PixelTheme copyWith({
    Color? background,
    Color? surface,
    Color? raisedSurface,
    Color? line,
    Color? grid,
    Color? accent,
    Color? dimAccent,
    Color? onAccent,
    Color? primaryText,
    Color? mutedText,
    Color? warning,
    Color? danger,
    double? gridUnit,
    double? borderWidth,
  }) {
    return PixelTheme(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      raisedSurface: raisedSurface ?? this.raisedSurface,
      line: line ?? this.line,
      grid: grid ?? this.grid,
      accent: accent ?? this.accent,
      dimAccent: dimAccent ?? this.dimAccent,
      onAccent: onAccent ?? this.onAccent,
      primaryText: primaryText ?? this.primaryText,
      mutedText: mutedText ?? this.mutedText,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      gridUnit: gridUnit ?? this.gridUnit,
      borderWidth: borderWidth ?? this.borderWidth,
    );
  }

  @override
  PixelTheme lerp(covariant PixelTheme? other, double t) {
    if (other == null) return this;
    return PixelTheme(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raisedSurface: Color.lerp(raisedSurface, other.raisedSurface, t)!,
      line: Color.lerp(line, other.line, t)!,
      grid: Color.lerp(grid, other.grid, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      dimAccent: Color.lerp(dimAccent, other.dimAccent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      gridUnit: gridUnit + (other.gridUnit - gridUnit) * t,
      borderWidth: borderWidth + (other.borderWidth - borderWidth) * t,
    );
  }
}

extension PixelThemeContext on BuildContext {
  PixelTheme get pixel => Theme.of(this).extension<PixelTheme>()!;
}

ThemeData buildPixelTheme() {
  final pixel = PixelTheme.defaults;
  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: pixel.accent,
    onPrimary: pixel.onAccent,
    secondary: pixel.warning,
    onSecondary: pixel.background,
    error: pixel.danger,
    onError: pixel.primaryText,
    surface: pixel.surface,
    onSurface: pixel.primaryText,
    surfaceContainerHighest: pixel.raisedSurface,
    outline: pixel.line,
    outlineVariant: pixel.line,
    primaryContainer: pixel.accent,
    onPrimaryContainer: pixel.onAccent,
    secondaryContainer: pixel.warning,
    onSecondaryContainer: pixel.background,
    errorContainer: pixel.danger,
    onErrorContainer: pixel.primaryText,
    inverseSurface: pixel.primaryText,
    onInverseSurface: pixel.background,
    inversePrimary: pixel.dimAccent,
    shadow: Colors.transparent,
    scrim: pixel.background,
    surfaceTint: Colors.transparent,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.zero,
    borderSide: BorderSide(color: pixel.line, width: pixel.borderWidth),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    extensions: const [PixelTheme.defaults],
    scaffoldBackgroundColor: pixel.background,
    textTheme: TextTheme(
      displayLarge: TextStyle(color: pixel.primaryText, fontSize: 32),
      displayMedium: TextStyle(color: pixel.primaryText, fontSize: 28),
      displaySmall: TextStyle(color: pixel.primaryText, fontSize: 24),
      headlineLarge: TextStyle(color: pixel.primaryText, fontSize: 22),
      headlineMedium: TextStyle(color: pixel.primaryText, fontSize: 20),
      headlineSmall: TextStyle(color: pixel.primaryText, fontSize: 18),
      titleLarge: TextStyle(color: pixel.primaryText, fontSize: 18),
      titleMedium: TextStyle(color: pixel.primaryText, fontSize: 16),
      titleSmall: TextStyle(color: pixel.primaryText, fontSize: 14),
      bodyLarge: TextStyle(color: pixel.primaryText, fontSize: 16),
      bodyMedium: TextStyle(color: pixel.primaryText, fontSize: 14),
      bodySmall: TextStyle(color: pixel.mutedText, fontSize: 12),
      labelLarge: TextStyle(color: pixel.primaryText, fontSize: 14),
      labelMedium: TextStyle(color: pixel.mutedText, fontSize: 12),
      labelSmall: TextStyle(color: pixel.mutedText, fontSize: 11),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: pixel.background,
      foregroundColor: pixel.primaryText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: pixel.surface,
      hintStyle: TextStyle(color: pixel.mutedText),
      labelStyle: TextStyle(color: pixel.mutedText),
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: pixel.accent, width: pixel.borderWidth),
      ),
      errorBorder: border.copyWith(
        borderSide: BorderSide(color: pixel.danger, width: pixel.borderWidth),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: pixel.danger, width: pixel.borderWidth),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: pixel.space12,
        vertical: pixel.space8,
      ),
    ),
    cardTheme: CardThemeData(
      color: pixel.surface,
      margin: EdgeInsets.zero,
      shape: Border.all(color: pixel.line, width: pixel.borderWidth),
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: pixel.surface,
      selectedColor: pixel.accent,
      side: BorderSide(color: pixel.line, width: pixel.borderWidth),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      labelStyle: TextStyle(color: pixel.primaryText),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? pixel.accent
              : pixel.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? pixel.onAccent
              : pixel.primaryText,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? pixel.accent
                : pixel.line,
            width: pixel.borderWidth,
          ),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: pixel.accent,
        foregroundColor: pixel.onAccent,
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: pixel.primaryText,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: pixel.line, width: pixel.borderWidth),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: pixel.surface,
      indicatorColor: pixel.accent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected)
              ? pixel.onAccent
              : pixel.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: pixel.raisedSurface,
      behavior: SnackBarBehavior.floating,
      shape: Border.all(color: pixel.line, width: pixel.borderWidth),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: pixel.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: pixel.surface,
      shape: Border.all(color: pixel.line, width: pixel.borderWidth),
    ),
  );
}
