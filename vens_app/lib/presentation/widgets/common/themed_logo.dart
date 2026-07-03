import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:vens_hub/core/services/theme/theme_service.dart';
import 'package:vens_hub/core/theme/theme_enums.dart';

/// Displays the branded SVG logo variant that matches the current color scheme.
class ThemedLogo extends StatelessWidget {
  const ThemedLogo({super.key, this.width, this.height, this.fit});

  final double? width;
  final double? height;
  final BoxFit? fit;

  String _getLogoPath(AppColorScheme colorScheme) {
    switch (colorScheme) {
      case AppColorScheme.teal:
        return 'assets/svg/transp_11_inlined_teal.svg';
      case AppColorScheme.purple:
        return 'assets/svg/transp_11_inlined_purple.svg';
      case AppColorScheme.orange:
        return 'assets/svg/transp_11_inlined_orange.svg';
      case AppColorScheme.green:
        // Original green version
        return 'assets/svg/transp_11_inlined.svg';
      case AppColorScheme.blue:
        return 'assets/svg/transp_11_inlined_blue.svg';
      case AppColorScheme.pink:
        return 'assets/svg/transp_11_inlined_pink.svg';
      case AppColorScheme.greyscale:
        return 'assets/svg/transp_11_inlined_greyscale.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeService themeService = Get.find<ThemeService>();
    return Obx(() {
      final scheme = themeService.colorSchemeObs.value;
      final logoPath = _getLogoPath(scheme);
      return SvgPicture.asset(
        logoPath,
        width: width,
        height: height,
        fit: fit ?? BoxFit.contain,
      );
    });
  }
}
