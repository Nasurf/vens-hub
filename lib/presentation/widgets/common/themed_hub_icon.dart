import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:vector_graphics/vector_graphics.dart' as vg;

import 'package:vens_hub/core/services/theme/theme_service.dart';
import 'package:vens_hub/core/theme/theme_enums.dart';

/// Theme-aware Hub icon that swaps SVG assets based on the current app color scheme
/// and selection state. Uses greyscale/424242 for unselected variants.
class ThemedHubIcon extends StatelessWidget {
  const ThemedHubIcon({super.key, this.size = 28, required this.selected});

  final double size;
  final bool selected;

  String _getActiveAsset(AppColorScheme scheme) {
    switch (scheme) {
      case AppColorScheme.teal:
        return 'assets/svg/hub_inlined_teal.svg';
      case AppColorScheme.purple:
        return 'assets/svg/hub_inlined_purple.svg';
      case AppColorScheme.orange:
        return 'assets/svg/hub_inlined_orange.svg';
      case AppColorScheme.green:
        return 'assets/svg/hub_inlined.svg';
      case AppColorScheme.blue:
        return 'assets/svg/hub_inlined_blue.svg';
      case AppColorScheme.pink:
        return 'assets/svg/hub_inlined_pink.svg';
      case AppColorScheme.greyscale:
        return 'assets/svg/hub_inlined_greyscale.svg';
    }
  }

  /// Inactive asset for unselected state; prefers #424242 in light mode to match
  /// bottom nav unselected color, and greyscale in dark mode.
  String _getInactiveAsset(Brightness brightness) {
    if (brightness == Brightness.light) {
      return 'assets/svg/hub_inlined_inactive_light.svg';
    }
    return 'assets/svg/hub_inlined_greyscale.svg';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeService themeService = Get.find<ThemeService>();
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    return Obx(() {
      final scheme = themeService.colorSchemeObs.value;
      final assetPath =
          selected ? _getActiveAsset(scheme) : _getInactiveAsset(brightness);
      final loader = vg.AssetBytesLoader('$assetPath.vec');
      return SvgPicture(
        loader,
        width: size,
        height: size,
        fit: BoxFit.contain,
        // Let the themed SVG files show their original gradient colors when selected.
        // Only apply color filter for unselected state to maintain proper contrast.
        colorFilter:
            !selected
                ? ColorFilter.mode(
                  brightness == Brightness.light
                      ? const Color(0xFF424242)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  BlendMode.srcIn,
                )
                : null,
      );
    });
  }
}
