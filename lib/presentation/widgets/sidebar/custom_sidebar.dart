import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../core/services/theme/theme_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_enums.dart';
import '../../blocs/home/home_controller.dart';
import '../common/profile_avatar_menu.dart';
import '../common/themed_hub_icon.dart';

/// Sidebar widget with warm off-white (light) / warm charcoal (dark) styling.
/// Uses GetX to reactively highlight the selected page.
class CustomSidebar extends StatefulWidget {
  const CustomSidebar({super.key});

  @override
  State<CustomSidebar> createState() => _CustomSidebarState();
}

class _CustomSidebarState extends State<CustomSidebar> {
  late final HomeController _homeController;
  late final ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _homeController = Get.find<HomeController>();
    _themeService = Get.find<ThemeService>();
  }

  /// Get the appropriate SVG path based on the current color scheme
  String _getLogoPath(AppColorScheme colorScheme) {
    switch (colorScheme) {
      case AppColorScheme.teal:
        return 'assets/svg/transp_11_inlined_teal.svg';
      case AppColorScheme.purple:
        return 'assets/svg/transp_11_inlined_purple.svg';
      case AppColorScheme.orange:
        return 'assets/svg/transp_11_inlined_orange.svg';
      case AppColorScheme.green:
        return 'assets/svg/transp_11_inlined.svg'; // Keep original for green
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Theme-aware colors
    final backgroundColor =
        isDark
            ? AppColors.sidebarBackgroundDark
            : AppColors.sidebarBackgroundLight;
    final onBackgroundColor =
        isDark
            ? AppColors.sidebarOnBackgroundDark
            : AppColors.sidebarOnBackgroundLight;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16), // Add rounded edges
      ),
      child: Column(
        children: [
          _buildLogoHeader(onBackgroundColor),
          const SizedBox(height: 64),
          Expanded(
            child: _buildNavigationList(context, onBackgroundColor, isDark),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ProfileAvatarMenu(
              radius: 18,
              showMenu: false,
              onTap: () => _homeController.currentPage.value = 4,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact logo header with reactive color scheme
  Widget _buildLogoHeader(Color iconColor) {
    return Container(
      height: 70,
      padding: const EdgeInsets.all(10),
      alignment: Alignment.center,
      child: Obx(() {
        final currentColorScheme = _themeService.colorSchemeObs.value;
        final logoPath = _getLogoPath(currentColorScheme);

        return SvgPicture.asset(
          logoPath,
          width: 50,
          height: 50,
          fit: BoxFit.contain,
          // The SVG now uses themed colors that match the current color scheme
        );
      }),
    );
  }

  Widget _buildNavigationList(
    BuildContext context,
    Color onBackgroundColor,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    // Selection background tints
    final selectedBg = primary.withValues(alpha: isDark ? 0.12 : 0.08);

    const destinations = <_Destination>[
      _Destination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Home',
        index: 0,
      ),
      _Destination(
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today,
        label: 'Schedule',
        index: 1,
      ),
      _Destination(
        icon: null, // Uses ThemedHubIcon instead
        selectedIcon: null,
        label: 'Hub',
        index: 2,
        isHub: true,
      ),
      _Destination(
        icon: Icons.book_outlined,
        selectedIcon: Icons.book,
        label: 'Study',
        index: 3,
      ),
      // Removed Profile nav item; avatar at bottom routes to Profile
    ];

    return Obx(() {
      final selIndex = _homeController.currentPage.value;
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: destinations.length,
        itemBuilder: (context, i) {
          final d = destinations[i];
          final selected = d.index == selIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ), // Increased spacing between icons (from 6 to 12)
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _homeController.currentPage.value = d.index,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: selected ? selectedBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child:
                        d.isHub
                            ? ThemedHubIcon(selected: selected, size: 24)
                            : Icon(
                              selected ? d.selectedIcon : d.icon,
                              size: 24,
                              color: selected ? primary : onBackgroundColor,
                            ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class _Destination {
  const _Destination({
    this.icon,
    this.selectedIcon,
    required this.label,
    required this.index,
    this.isHub = false,
  });
  final IconData? icon;
  final IconData? selectedIcon;
  final String label;
  final int index;
  final bool isHub;
}
