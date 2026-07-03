import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:vens_hub/core/theme/app_colors.dart';
import 'package:vens_hub/core/theme/theme_enums.dart';
import 'package:vens_hub/core/utils/app_logger.dart'; // Import for AppColorScheme
import 'package:vens_hub/core/theme/page_transitions.dart';

/// =========================================================================
/// Theme Definitions using AppColors
/// =========================================================================
class AppThemes {
  // --- Base Helper for Shared Properties ---
  static ThemeData _createTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: const FadeScalePageTransitionsBuilder(),
          TargetPlatform.fuchsia: const FadeScalePageTransitionsBuilder(),
          TargetPlatform.linux: const FadeScalePageTransitionsBuilder(),
          TargetPlatform.windows: const FadeScalePageTransitionsBuilder(),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
        },
      ),

      // --- Component Theming (Uses colorScheme correctly) ---
      appBarTheme: AppBarTheme(
        backgroundColor:
            colorScheme.primary, // Sticking to original request style
        foregroundColor: colorScheme.onPrimary,
        elevation: isDark ? 1 : 2, // Subtle elevation difference
        shadowColor: colorScheme.shadow.withValues(alpha: 0.2), // Softer shadow
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        highlightElevation: 8,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            isDark
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.7)
                : colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.error, width: 2.0),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: isDark ? 1 : 2,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: isDark ? 0.5 : 0.0,
          ), // Subtle border for dark cards
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 16,
        ),
      ),

      chipTheme: ChipThemeData(
        // Make unselected state neutral and readable
        backgroundColor: colorScheme.surface,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.onSurface),
        // Selected state: use container + its matching on-color for contrast
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: colorScheme.outline, width: isDark ? 0.8 : 0.5),
      ),

      // ADDED/MODIFIED BottomNavigationBarThemeData
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            colorScheme.surface, // Use surface or surfaceContainer as base
        selectedItemColor:
            colorScheme
                .primary, // Often primary or onSurface/onBackground for selected
        unselectedItemColor:
            colorScheme.onSurfaceVariant, // For unselected items
        elevation: isDark ? 2 : 4,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true, // Explicitly set for consistency
        showUnselectedLabels: true, // Explicitly set for consistency
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.primary,
        ), // Match selectedItemColor logic
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 57,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
          color: colorScheme.onSurface,
        ),
        displayMedium: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 45,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        displaySmall: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 36,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: colorScheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: colorScheme.onSurface, // Titles often on main background
        ),
        titleMedium: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          color: colorScheme.onSurface,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: colorScheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          color: colorScheme.onSurface, // Body text on main background
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: colorScheme.onSurface,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: colorScheme.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          color: colorScheme.onPrimary,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: colorScheme.onSurfaceVariant,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Chorus Sans Serif',
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  // --- Teal Theme ---
  static final ThemeData tealLightTheme = _createTheme(
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.tealPrimary,
      onPrimary: AppColors.onPrimaryLight,
      primaryContainer: AppColors.tealTertiaryLight,
      onPrimaryContainer: AppColors.onTertiaryLight,
      secondary: AppColors.tealSecondaryLight,
      onSecondary: AppColors.onPrimaryLight,
      secondaryContainer: AppColors.tealTertiaryLight,
      onSecondaryContainer: AppColors.onTertiaryLight,
      tertiary: AppColors.bluePrimary,
      onTertiary: AppColors.onPrimaryLight,
      tertiaryContainer: AppColors.blueTertiaryLight,
      onTertiaryContainer: AppColors.onTertiaryLight,
      error: AppColors.errorLight,
      onError: AppColors.onErrorLight,
      errorContainer: AppColors.errorContainerLight,
      onErrorContainer: AppColors.onErrorContainerLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineVariantLight,
      shadow: Colors.black,
      scrim: Color.fromRGBO(0, 0, 0, 0.4),
      inverseSurface: AppColors.surfaceDark,
      onInverseSurface: AppColors.onSurfaceDark,
      inversePrimary: AppColors.tealPrimaryDark,
    ),
  );

  static final ThemeData tealDarkTheme = _createTheme(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.tealPrimaryDark,
      onPrimary: AppColors.onPrimaryDark,
      primaryContainer: AppColors.tealSecondaryDark,
      onPrimaryContainer: AppColors.onSecondaryDark,
      secondary: AppColors.tealSecondaryDark,
      onSecondary: AppColors.onSecondaryDark,
      secondaryContainer: Color(0xFF003731),
      onSecondaryContainer: AppColors.tealTertiaryDark,
      tertiary: AppColors.bluePrimaryDark,
      onTertiary: AppColors.onPrimaryDark,
      tertiaryContainer: AppColors.blueSecondaryDark,
      onTertiaryContainer: AppColors.onSecondaryDark,
      error: AppColors.errorDark,
      onError: AppColors.onErrorDark,
      errorContainer: AppColors.errorContainerDark,
      onErrorContainer: AppColors.onErrorContainerDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
      shadow: Colors.black,
      scrim: Color.fromRGBO(0, 0, 0, 0.5),
      inverseSurface: AppColors.surfaceLight,
      onInverseSurface: AppColors.onSurfaceLight,
      inversePrimary: AppColors.tealPrimary,
    ),
  );

  // --- Purple Theme ---
  static final ThemeData purpleLightTheme = _createTheme(
    brightness: Brightness.light,
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.purplePrimary,
      onPrimary: AppColors.onPrimaryLight,
      primaryContainer: AppColors.purpleTertiaryLight,
      onPrimaryContainer: AppColors.onTertiaryLight,
      secondary: AppColors.purpleSecondaryLight,
      onSecondary: AppColors.onPrimaryLight,
      secondaryContainer: AppColors.purpleTertiaryLight,
      onSecondaryContainer: AppColors.onTertiaryLight,
      tertiary: AppColors.pinkPrimary,
      onTertiary: AppColors.onPrimaryLight,
      tertiaryContainer: AppColors.pinkTertiaryLight,
      onTertiaryContainer: AppColors.onTertiaryLight,
      error: AppColors.errorLight,
      onError: AppColors.onErrorLight,
      errorContainer: AppColors.errorContainerLight,
      onErrorContainer: AppColors.onErrorContainerLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineVariantLight,
      shadow: Colors.black,
      scrim: const Color.fromRGBO(0, 0, 0, 0.4),
      inverseSurface: AppColors.surfaceDark,
      onInverseSurface: AppColors.onSurfaceDark,
      inversePrimary: AppColors.purplePrimaryDark,
    ),
  );

  static final ThemeData purpleDarkTheme = _createTheme(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.purplePrimaryDark,
      onPrimary: AppColors.onPrimaryDark,
      primaryContainer: AppColors.purpleSecondaryDark,
      onPrimaryContainer: AppColors.onSecondaryDark,
      secondary: AppColors.purpleSecondaryDark,
      onSecondary: AppColors.onSecondaryDark,
      secondaryContainer: Color(0xFF3A006F),
      onSecondaryContainer: AppColors.purpleTertiaryDark,
      tertiary: AppColors.pinkPrimaryDark,
      onTertiary: AppColors.onPrimaryDark,
      tertiaryContainer: AppColors.pinkSecondaryDark,
      onTertiaryContainer: AppColors.onSecondaryDark,
      error: AppColors.errorDark,
      onError: AppColors.onErrorDark,
      errorContainer: AppColors.errorContainerDark,
      onErrorContainer: AppColors.onErrorContainerDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
      shadow: Colors.black,
      scrim: Color.fromRGBO(0, 0, 0, 0.5),
      inverseSurface: AppColors.surfaceLight,
      onInverseSurface: AppColors.onSurfaceLight,
      inversePrimary: AppColors.purplePrimary,
    ),
  );

  // --- Orange Theme ---
  static final ThemeData orangeLightTheme = _createTheme(
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.orangePrimary,
      onPrimary: AppColors.onPrimaryLight,
      primaryContainer: AppColors.orangeTertiaryLight,
      onPrimaryContainer: AppColors.onTertiaryLight,
      secondary: AppColors.orangeSecondaryLight,
      onSecondary: AppColors.onSecondaryLight,
      secondaryContainer: AppColors.orangeTertiaryLight,
      onSecondaryContainer: AppColors.onTertiaryLight,
      tertiary: AppColors.tealPrimary,
      onTertiary: AppColors.onPrimaryLight,
      tertiaryContainer: AppColors.tealTertiaryLight,
      onTertiaryContainer: AppColors.onTertiaryLight,
      error: AppColors.errorLight,
      onError: AppColors.onErrorLight,
      errorContainer: AppColors.errorContainerLight,
      onErrorContainer: AppColors.onErrorContainerLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineVariantLight,
      shadow: Colors.black,
      scrim: Color.fromRGBO(0, 0, 0, 0.4),
      inverseSurface: AppColors.surfaceDark,
      onInverseSurface: AppColors.onSurfaceDark,
      inversePrimary: AppColors.orangePrimaryDark,
    ),
  );

  static final ThemeData orangeDarkTheme = _createTheme(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.orangePrimaryDark,
      onPrimary: AppColors.onPrimaryDark,
      primaryContainer: AppColors.orangeSecondaryDark,
      onPrimaryContainer: AppColors.onSecondaryDark,
      secondary: AppColors.orangeSecondaryDark,
      onSecondary: AppColors.onSecondaryDark,
      secondaryContainer: Color(0xFF601400),
      onSecondaryContainer: AppColors.orangeTertiaryDark,
      tertiary: AppColors.tealPrimaryDark,
      onTertiary: AppColors.onPrimaryDark,
      tertiaryContainer: AppColors.tealSecondaryDark,
      onTertiaryContainer: AppColors.onSecondaryDark,
      error: AppColors.errorDark,
      onError: AppColors.onErrorDark,
      errorContainer: AppColors.errorContainerDark,
      onErrorContainer: AppColors.onErrorContainerDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
      shadow: Colors.black,
      scrim: Color.fromRGBO(0, 0, 0, 0.5),
      inverseSurface: AppColors.surfaceLight,
      onInverseSurface: AppColors.onSurfaceLight,
      inversePrimary: AppColors.orangePrimary,
    ),
  );

  // --- Green Theme ---
  static final ThemeData greenLightTheme = _createTheme(
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.greenPrimary,
      onPrimary: AppColors.onPrimaryLight,
      primaryContainer: AppColors.greenTertiaryLight,
      onPrimaryContainer: AppColors.onTertiaryLight,
      secondary: AppColors.greenSecondaryLight,
      onSecondary: AppColors.onSecondaryLight,
      secondaryContainer: AppColors.greenTertiaryLight,
      onSecondaryContainer: AppColors.onTertiaryLight,
      tertiary: AppColors.orangePrimary,
      onTertiary: AppColors.onPrimaryLight,
      tertiaryContainer: AppColors.orangeTertiaryLight,
      onTertiaryContainer: AppColors.onTertiaryLight,
      error: AppColors.errorLight,
      onError: AppColors.onErrorLight,
      errorContainer: AppColors.errorContainerLight,
      onErrorContainer: AppColors.onErrorContainerLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineVariantLight,
      shadow: Colors.black,
      scrim: Color.fromRGBO(0, 0, 0, 0.4),
      inverseSurface: AppColors.surfaceDark,
      onInverseSurface: AppColors.onSurfaceDark,
      inversePrimary: AppColors.greenPrimaryDark,
    ),
  );

  static final ThemeData greenDarkTheme = _createTheme(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.greenPrimaryDark,
      onPrimary: AppColors.onPrimaryDark,
      primaryContainer: AppColors.greenSecondaryDark,
      onPrimaryContainer: AppColors.onSecondaryDark,
      secondary: AppColors.greenSecondaryDark,
      onSecondary: AppColors.onSecondaryDark,
      secondaryContainer: Color(0xFF00390A),
      onSecondaryContainer: AppColors.greenTertiaryDark,
      tertiary: AppColors.orangePrimaryDark,
      onTertiary: AppColors.onPrimaryDark,
      tertiaryContainer: AppColors.orangeSecondaryDark,
      onTertiaryContainer: AppColors.onSecondaryDark,
      error: AppColors.errorDark,
      onError: AppColors.onErrorDark,
      errorContainer: AppColors.errorContainerDark,
      onErrorContainer: AppColors.onErrorContainerDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
      shadow: Colors.black,
      scrim: Color.fromRGBO(0, 0, 0, 0.5),
      inverseSurface: AppColors.surfaceLight,
      onInverseSurface: AppColors.onSurfaceLight,
      inversePrimary: AppColors.greenPrimary,
    ),
  );

  // --- Blue Theme ---
  static final ThemeData blueLightTheme = _createTheme(
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.bluePrimary,
      onPrimary: AppColors.onPrimaryLight,
      primaryContainer: AppColors.blueTertiaryLight,
      onPrimaryContainer: AppColors.onTertiaryLight,
      secondary: AppColors.blueSecondaryLight,
      onSecondary: AppColors.onPrimaryLight,
      secondaryContainer: AppColors.blueTertiaryLight,
      onSecondaryContainer: AppColors.onTertiaryLight,
      tertiary: AppColors.purplePrimary,
      onTertiary: AppColors.onPrimaryLight,
      tertiaryContainer: AppColors.purpleTertiaryLight,
      onTertiaryContainer: AppColors.onTertiaryLight,
      error: AppColors.errorLight,
      onError: AppColors.onErrorLight,
      errorContainer: AppColors.errorContainerLight,
      onErrorContainer: AppColors.onErrorContainerLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineVariantLight,
      shadow: Colors.black,
      scrim: Color.fromRGBO(0, 0, 0, 0.4),
      inverseSurface: AppColors.surfaceDark,
      onInverseSurface: AppColors.onSurfaceDark,
      inversePrimary: AppColors.bluePrimaryDark,
    ),
  );

  static final ThemeData blueDarkTheme = _createTheme(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.bluePrimaryDark,
      onPrimary: AppColors.onPrimaryDark,
      primaryContainer: AppColors.blueSecondaryDark,
      onPrimaryContainer: AppColors.onSecondaryDark,
      secondary: AppColors.blueSecondaryDark,
      onSecondary: AppColors.onSecondaryDark,
      secondaryContainer: Color(0xFF00346E),
      onSecondaryContainer: AppColors.blueTertiaryDark,
      tertiary: AppColors.purplePrimaryDark,
      onTertiary: AppColors.onPrimaryDark,
      tertiaryContainer: AppColors.purpleSecondaryDark,
      onTertiaryContainer: AppColors.onSecondaryDark,
      error: AppColors.errorDark,
      onError: AppColors.onErrorDark,
      errorContainer: AppColors.errorContainerDark,
      onErrorContainer: AppColors.onErrorContainerDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
      shadow: Colors.black,
      scrim: Color.fromRGBO(0, 0, 0, 0.5),
      inverseSurface: AppColors.surfaceLight,
      onInverseSurface: AppColors.onSurfaceLight,
      inversePrimary: AppColors.bluePrimary,
    ),
  );

  // --- Pink Theme ---
  static final ThemeData pinkLightTheme = _createTheme(
    brightness: Brightness.light,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.pinkPrimary,
      onPrimary: AppColors.onPrimaryLight,
      primaryContainer: AppColors.pinkTertiaryLight,
      onPrimaryContainer: AppColors.onTertiaryLight,
      secondary: AppColors.pinkSecondaryLight,
      onSecondary: AppColors.onPrimaryLight,
      secondaryContainer: AppColors.pinkTertiaryLight,
      onSecondaryContainer: AppColors.onTertiaryLight,
      tertiary: AppColors.purplePrimary,
      onTertiary: AppColors.onPrimaryLight,
      tertiaryContainer: AppColors.purpleTertiaryLight,
      onTertiaryContainer: AppColors.onTertiaryLight,
      error: AppColors.errorLight,
      onError: AppColors.onErrorLight,
      errorContainer: AppColors.errorContainerLight,
      onErrorContainer: AppColors.onErrorContainerLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      surfaceContainerHighest: AppColors.surfaceVariantLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineVariantLight,
      shadow: Colors.black,
      scrim: Color.fromRGBO(0, 0, 0, 0.4),
      inverseSurface: AppColors.surfaceDark,
      onInverseSurface: AppColors.onSurfaceDark,
      inversePrimary: AppColors.pinkPrimaryDark,
    ),
  );

  static final ThemeData pinkDarkTheme = _createTheme(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.pinkPrimaryDark,
      onPrimary: AppColors.onPrimaryDark,
      primaryContainer: AppColors.pinkSecondaryDark,
      onPrimaryContainer: AppColors.onSecondaryDark,
      secondary: AppColors.pinkSecondaryDark,
      onSecondary: AppColors.onSecondaryDark,
      secondaryContainer: Color(0xFF63003A),
      onSecondaryContainer: AppColors.pinkTertiaryDark,
      tertiary: AppColors.purplePrimaryDark,
      onTertiary: AppColors.onPrimaryDark,
      tertiaryContainer: AppColors.purpleSecondaryDark,
      onTertiaryContainer: AppColors.onSecondaryDark,
      error: AppColors.errorDark,
      onError: AppColors.onErrorDark,
      errorContainer: AppColors.errorContainerDark,
      onErrorContainer: AppColors.onErrorContainerDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      surfaceContainerHighest: AppColors.surfaceVariantDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineVariantDark,
      shadow: Colors.black,
      scrim: Color.fromRGBO(0, 0, 0, 0.5),
      inverseSurface: AppColors.surfaceLight,
      onInverseSurface: AppColors.onSurfaceLight,
      inversePrimary: AppColors.pinkPrimary,
    ),
  );

  // --- NEW: Greyscale Dark Theme (Inspired by Image) ---
  static final ThemeData greyscaleDarkTheme = _createTheme(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.gsDarkPrimary, // White (for FAB, selected nav items)
      onPrimary:
          AppColors.gsDarkOnPrimary, // Dark Grey/Black (on white primary)
      primaryContainer: AppColors.gsDarkPrimaryContainer, // White
      onPrimaryContainer: AppColors.gsDarkOnPrimaryContainer, // Dark Grey/Black

      secondary:
          AppColors
              .gsDarkSecondary, // Light Grey (e.g., BDBDBD for minor accents)
      onSecondary:
          AppColors
              .gsDarkOnSecondary, // Dark Grey/Black (on light grey secondary)
      secondaryContainer:
          AppColors
              .gsDarkSecondaryContainer, // Dark Grey (0xFF2C2C2E, for icon button BGs)
      onSecondaryContainer:
          AppColors
              .gsDarkOnSecondaryContainer, // White (on gsDarkSecondaryContainer)

      tertiary: AppColors.gsDarkTertiary, // Medium Grey (0xFF9E9E9E)
      onTertiary: AppColors.gsDarkOnTertiary, // Dark Grey/Black
      tertiaryContainer:
          AppColors.gsDarkTertiaryContainer, // Another Dark Grey (0xFF3E3E3E)
      onTertiaryContainer: AppColors.gsDarkOnTertiaryContainer, // White

      error: AppColors.gsDarkError, // Standard dark error red
      onError: AppColors.gsDarkOnError, // Black text on error red
      errorContainer: AppColors.gsDarkErrorContainer,
      onErrorContainer:
          AppColors
              .gsDarkOnErrorContainer, // White (for main text like "Send", "Receiving")

      surface:
          AppColors
              .gsDarkSurface, // Dark Grey (0xFF1C1C1E, for cards, bottom nav)
      onSurface:
          AppColors
              .gsDarkOnSurface, // Light Grey/Off-white (0xFFE0E0E0, for text on cards)

      surfaceContainerHighest:
          AppColors
              .gsDarkSurfaceVariant, // Another Dark Grey (0xFF2A2A2A, for input fields etc.)
      onSurfaceVariant:
          AppColors
              .gsDarkOnSurfaceVariant, // Medium Grey (0xFFBDBDBD, for subtitles, inactive icons)

      outline: AppColors.gsDarkOutline, // Grey (0xFF444444, for borders)
      outlineVariant:
          AppColors
              .gsDarkOutlineVariant, // Darker Grey (0xFF333333, for subtle dividers like timeline)

      shadow: Colors.black54, // Deeper shadow for very dark themes
      scrim: Colors.black54, // Darker scrim

      inverseSurface:
          AppColors.surfaceLight, // Light grey for inverse scenarios
      onInverseSurface:
          AppColors.onSurfaceLight, // Dark text on light inverse surface
      inversePrimary:
          AppColors.gsDarkOnPrimary, // Dark grey/black as inverse primary
      surfaceTint:
          Colors
              .transparent, // Keep surface tint transparent or very subtle for this style
    ),
  ).copyWith(
    // Specific overrides for greyscaleDarkTheme if _createTheme defaults aren't perfect
    appBarTheme: AppBarTheme(
      // Override AppBar to match image's header style
      backgroundColor:
          AppColors.gsDarkBackground, // Blend with screen background
      foregroundColor: AppColors.gsDarkOnBackground, // White titles
      elevation: 0, // No elevation for this style
      titleTextStyle: TextStyle(
        // Ensure title text style matches general onBackground
        fontFamily: 'Chorus Sans Serif',
        fontSize: 32, // Large title like "Send"
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: AppColors.gsDarkOnBackground,
      ),
    ),
    // Adjust BottomNavigationBarTheme specifically for greyscale to match image more closely
    // The _createTheme already sets selectedItemColor to colorScheme.primary.
    // For this theme, primary is white, which is correct for selected items.
    // UnselectedItemColor is colorScheme.onSurfaceVariant (gsDarkOnSurfaceVariant - BDBDBD), also good.
    // Background is colorScheme.surface (gsDarkSurface - 1C1C1E), which matches cards and is fine.
  );

  // --- New Static Method to Get ThemeData ---
  static ThemeData getThemeData(AppColorScheme scheme, Brightness brightness) {
    switch (scheme) {
      case AppColorScheme.teal:
        return brightness == Brightness.light ? tealLightTheme : tealDarkTheme;
      case AppColorScheme.purple:
        return brightness == Brightness.light
            ? purpleLightTheme
            : purpleDarkTheme;
      case AppColorScheme.orange:
        return brightness == Brightness.light
            ? orangeLightTheme
            : orangeDarkTheme;
      case AppColorScheme.green:
        return brightness == Brightness.light
            ? greenLightTheme
            : greenDarkTheme;
      case AppColorScheme.blue:
        return brightness == Brightness.light ? blueLightTheme : blueDarkTheme;
      case AppColorScheme.pink:
        return brightness == Brightness.light ? pinkLightTheme : pinkDarkTheme;
      case AppColorScheme.greyscale:
        if (brightness == Brightness.light) {
          AppLogger.w(
            'Greyscale light theme not explicitly defined, defaulting to Teal Light.',
          );
          return tealLightTheme; // Default to teal light for greyscale light
        }
        return greyscaleDarkTheme; // Only dark theme is explicitly defined for greyscale
      // default:
      //   // Default to teal theme if something goes wrong
      //   AppLogger.w('Unknown color scheme requested, defaulting to Teal.');
      //   return brightness == Brightness.light ? tealLightTheme : tealDarkTheme;
    }
  }
}
