import 'package:flutter/material.dart';

/// Defines the color palette for the application, including both light and dark themes.
class AppColors {
  // --- Core Primary Colors (Keep these consistent) ---
  static const Color tealPrimary = Color(0xFF009688); // Vibrant Teal
  static const Color purplePrimary = Color(0xFF7E57C2); // Soft Lavender
  static const Color orangePrimary = Color(0xFFFB8C00); // Warm Amber
  static const Color greenPrimary = Color(0xFF43A047); // Emerald Green
  static const Color bluePrimary = Color(0xFF1E88E5); // Bright Sky Blue
  static const Color pinkPrimary = Color(0xFFF42870); // Deep Fuchsia

  // --- Light Theme Specific Colors ---
  static const Color backgroundLight = Color(0xFFFFFFFF); // Pure White
  static const Color surfaceLight = Color(0xFFFAFAFA); // Very Light Gray
  static const Color surfaceVariantLight = Color(0xFFEEEEEE); // Light Gray
  static const Color outlineLight = Color(0xFFBDBDBD); // Medium Gray
  static const Color outlineVariantLight = Color(0xFFE0E0E0); // Lighter Gray

  // 'On' Colors for Light Theme (Text/Icons on light surfaces)
  static const Color onBackgroundLight = Color(0xFF1F1F1F); // Near Black
  static const Color onSurfaceLight = Color(0xFF1F1F1F); // Near Black
  static const Color onSurfaceVariantLight = Color(0xFF424242); // Dark Gray
  static const Color onPrimaryLight =
      Colors.white; // White text on primary color
  static const Color onSecondaryLight =
      Colors.black; // Black text on secondary color (adjust if needed)
  static const Color onTertiaryLight =
      Colors.black; // Black text on tertiary color (adjust if needed)
  static const Color onErrorLight = Colors.white; // White text on error color

  // Secondary/Tertiary for Light Theme (Often used for accents)
  static const Color tealSecondaryLight = Color(0xFF00796B); // Dark Teal
  static const Color purpleSecondaryLight = Color(0xFF9575CD); // Light Indigo
  static const Color orangeSecondaryLight = Color(0xFFFFA726); // Vivid Orange
  static const Color greenSecondaryLight = Color(0xFF66BB6A); // Light Lime
  static const Color blueSecondaryLight = Color(0xFF42A5F5); // Clear Sky Blue
  static const Color pinkSecondaryLight = Color(0xFFE91E63); // Soft Pink

  static const Color tealTertiaryLight = Color(0xFF80CBC4); // Pale Teal
  static const Color purpleTertiaryLight = Color(0xFFB39DDB); // Light Mauve
  static const Color orangeTertiaryLight = Color(0xFFFFCC80); // Pastel Orange
  static const Color greenTertiaryLight = Color(0xFFA5D6A7); // Mint Green
  static const Color blueTertiaryLight = Color(0xFF90CAF9); // Light Sky Blue
  static const Color pinkTertiaryLight = Color(0xFFF48FB1); // Pale Rose

  // Error Colors for Light Theme
  static const Color errorLight = Color(0xFFB00020); // Standard Error Red
  static const Color errorContainerLight = Color(
    0xFFFFDAD6,
  ); // Light Red Background
  static const Color onErrorContainerLight = Color(
    0xFF410002,
  ); // Dark Red Text on errorContainer

  // --- Dark Theme Specific Colors (for existing themes) ---
  static const Color backgroundDark = Color(
    0xFF121212,
  ); // Very Dark Gray (Material Standard)
  static const Color surfaceDark = Color(0xFF1E1E1E); // Dark Gray
  static const Color surfaceVariantDark = Color(
    0xFF303030,
  ); // Slightly Lighter Dark Gray
  static const Color outlineDark = Color(
    0xFF8A8A8A,
  ); // Medium Gray (for contrast)
  static const Color outlineVariantDark = Color(0xFF424242); // Darker Gray

  // 'On' Colors for Dark Theme (Text/Icons on dark surfaces)
  static const Color onBackgroundDark = Color(
    0xFFE3E3E3,
  ); // Light Gray (Near White)
  static const Color onSurfaceDark = Color(
    0xFFE3E3E3,
  ); // Light Gray (Near White)
  static const Color onSurfaceVariantDark = Color(0xFFBDBDBD); // Lighter Gray
  static const Color onPrimaryDark =
      Colors
          .black; // Black text on primary color (adjust if primary is very dark)
  static const Color onSecondaryDark =
      Colors.black; // Black text on secondary color (adjust if needed)
  static const Color onTertiaryDark =
      Colors.black; // Black text on tertiary color (adjust if needed)
  static const Color onErrorDark = Colors.black; // Black text on error color

  // Primary/Secondary/Tertiary for Dark Theme (Often lighter/more saturated)
  static const Color tealPrimaryDark = Color(0xFF4DB6AC); // Lighter Teal
  static const Color purplePrimaryDark = Color(0xFF9575CD); // Lighter Lavender
  static const Color orangePrimaryDark = Color(0xFFFFB74D); // Lighter Amber
  static const Color greenPrimaryDark = Color(0xFF81C784); // Lighter Green
  static const Color bluePrimaryDark = Color(0xFF64B5F6); // Lighter Sky Blue
  static const Color pinkPrimaryDark = Color(0xFFF06292); // Lighter Fuchsia

  static const Color tealSecondaryDark = Color(0xFF26A69A); // Medium Teal
  static const Color purpleSecondaryDark = Color(0xFF7986CB); // Medium Indigo
  static const Color orangeSecondaryDark = Color(
    0xFFFF8A65,
  ); // Lighter Vivid Orange
  static const Color greenSecondaryDark = Color(0xFF4CAF50); // Standard Green
  static const Color blueSecondaryDark = Color(0xFF2196F3); // Standard Blue
  static const Color pinkSecondaryDark = Color(0xFFEC407A); // Medium Pink

  static const Color tealTertiaryDark = Color(
    0xFF80CBC4,
  ); // Pale Teal (Often same as light)
  static const Color purpleTertiaryDark = Color(
    0xFFB39DDB,
  ); // Light Mauve (Often same as light)
  static const Color orangeTertiaryDark = Color(
    0xFFFFCC80,
  ); // Pastel Orange (Often same as light)
  static const Color greenTertiaryDark = Color(
    0xFFA5D6A7,
  ); // Mint Green (Often same as light)
  static const Color blueTertiaryDark = Color(
    0xFF90CAF9,
  ); // Light Sky Blue (Often same as light)
  static const Color pinkTertiaryDark = Color(
    0xFFF48FB1,
  ); // Pale Rose (Often same as light)

  // Error Colors for Dark Theme
  static const Color errorDark = Color(
    0xFFCF6679,
  ); // Lighter Red for Dark Theme
  static const Color errorContainerDark = Color(
    0xFF93000A,
  ); // Dark Red Background
  static const Color onErrorContainerDark = Color(
    0xFFFFDAD6,
  ); // Light Red Text on errorContainerDark

  // --- Greyscale Dark Theme (Inspired by Image and iOS Dark Mode Palettes) ---

  // Primary: Used for key interactive elements like FABs, selected states, active indicators.
  // In the image, the FAB "+" and the selected "Main" icon are white.
  static const Color gsDarkPrimary = Colors.white;
  static const Color gsDarkOnPrimary = Color(
    0xFF121212,
  ); // Nearly black, for content (e.g., icon) on a white primary surface.

  // Primary Container: A less prominent version of primary, or a background for primary elements.
  static const Color gsDarkPrimaryContainer = Color(
    0xFF3A3A3C,
  ); // A medium-dark grey.
  static const Color gsDarkOnPrimaryContainer =
      Colors.white; // White text/icons on the primary container.

  // Secondary: Used for less prominent components or alternative actions.
  // The circular backgrounds for search/bell icons can be considered secondary containers.
  static const Color gsDarkSecondary = Color(
    0xFF8E8E93,
  ); // A medium-light grey for secondary text or subtle accents.
  static const Color gsDarkOnSecondary =
      Colors
          .white; // Assuming gsDarkSecondary might be used as a background for white content.

  // Secondary Container: Backgrounds for secondary elements. (e.g., search/bell icon backgrounds in image)
  static const Color gsDarkSecondaryContainer = Color(
    0xFF2C2C2E,
  ); // Dark grey, as seen for icon button backgrounds.
  static const Color gsDarkOnSecondaryContainer =
      Colors.white; // White icons/text on gsDarkSecondaryContainer.

  // Tertiary: Used for even less prominent elements or decorative purposes.
  static const Color gsDarkTertiary = Color(
    0xFF636366,
  ); // A medium-dark grey, distinct from secondary.
  static const Color gsDarkOnTertiary = Colors.white;

  // Tertiary Container: Backgrounds for tertiary elements.
  static const Color gsDarkTertiaryContainer = Color(
    0xFF232325,
  ); // A very dark grey, slightly different from surface.
  static const Color gsDarkOnTertiaryContainer = Color(
    0xFFE0E0E0,
  ); // Light grey text/icons.

  // Error colors can reuse the general dark theme error colors
  static const Color gsDarkError =
      errorDark; // From your existing dark theme definitions
  static const Color gsDarkOnError = onErrorDark;
  static const Color gsDarkErrorContainer = errorContainerDark;
  static const Color gsDarkOnErrorContainer = onErrorContainerDark;

  // Background: The main screen background.
  static const Color gsDarkBackground = Color(
    0xFF000000,
  ); // True black, for the deepest background areas.
  static const Color gsDarkOnBackground = Color(
    0xFFFFFFFF,
  ); // Pure white for main titles like "Send".

  // Surface: Backgrounds for elevated or distinct UI elements like cards, dialogs, bottom navigation.
  static const Color gsDarkSurface = Color(
    0xFF1C1C1E,
  ); // Dark grey for cards, as in the image.
  static const Color gsDarkOnSurface = Color(
    0xFFE5E5E7,
  ); // Off-white/very light grey for primary text on surfaces.

  // Surface Variant: For elements that need to be subtly distinct from the main surface, or for input fields.
  static const Color gsDarkSurfaceVariant = Color(
    0xFF2A2A2C,
  ); // A slightly different dark grey.
  // For subtitles, helper text, inactive icons on surfaces/surface variants. ("In 4 country", inactive nav icons)
  static const Color gsDarkOnSurfaceVariant = Color(0xFFB0B0B3); // Medium grey.

  // Outline: For borders on components like cards (if desired), buttons, or input fields.
  static const Color gsDarkOutline = Color(
    0xFF48484A,
  ); // A visible grey for borders.
  // Outline Variant: For subtle dividers or decorative lines (e.g., the timeline).
  static const Color gsDarkOutlineVariant = Color(
    0xFF333333,
  ); // Darker, more subtle grey.      // Fainter borders/dividers (e.g., timeline in image)

  // --- Sidebar Theme Colors (YouTube-style sidebar inspired) ---

  // Light mode: Warm off-white background
  static const Color sidebarBackgroundLight = Color(
    0xFFD5D5D5,
  ); // Updated light sidebar bg
  static const Color sidebarOnBackgroundLight = Color(
    0xFF2F2F2F,
  ); // Dark text/icons
  static const Color sidebarBorderLight = Color(0xFFE8E8E6); // Subtle border

  // Dark mode: Warm charcoal with white blend
  static const Color sidebarBackgroundDark = Color(
    0xFF262626,
  ); // Warm charcoal-off-white
  static const Color sidebarOnBackgroundDark = Color(
    0xFFE8E8E8,
  ); // Light text/icons
  static const Color sidebarBorderDark = Color(0xFF383838); // Subtle border

  // Selected/Active states
  static const Color sidebarSelectedBackgroundLight = Color(
    0xFFE8F4FD,
  ); // Light primary tint
  static const Color sidebarSelectedBackgroundDark = Color(
    0xFF1A2332,
  ); // Dark primary tint
}
