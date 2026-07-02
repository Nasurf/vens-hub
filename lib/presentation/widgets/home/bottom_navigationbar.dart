// Bottom navigation bar with adaptive behavior
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/presentation/widgets/common/profile_avatar_menu.dart';
import 'package:vens_hub/presentation/widgets/common/themed_hub_icon.dart';

Widget buildAppBottomNavigationBar(
  BuildContext context,
  ColorScheme colorScheme, {
  required Function(int) onTap,
}) {
  return SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: _FloatingNavBar(colorScheme: colorScheme, onTap: onTap),
    ),
  );
}

class _FloatingNavBar extends StatelessWidget {
  final ColorScheme colorScheme;
  final Function(int) onTap;

  const _FloatingNavBar({required this.colorScheme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final HomeController controller = Get.find<HomeController>();

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.04),
            offset: const Offset(0, 1),
            blurRadius: 0,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.02),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.04),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            offset: const Offset(0, 16),
            blurRadius: 32,
          ),
        ],
      ),
      child: Obx(() {
        final selectedIndex = controller.currentPage.value;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              index: 0,
              selectedIndex: selectedIndex,
              colorScheme: colorScheme,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.calendar_month_rounded,
              index: 1,
              selectedIndex: selectedIndex,
              colorScheme: colorScheme,
              onTap: onTap,
            ),
            _HubNavItem(
              index: 2,
              selectedIndex: selectedIndex,
              colorScheme: colorScheme,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.menu_book_rounded,
              index: 3,
              selectedIndex: selectedIndex,
              colorScheme: colorScheme,
              onTap: onTap,
            ),
            _ProfileNavItem(
              index: 4,
              selectedIndex: selectedIndex,
              colorScheme: colorScheme,
              onTap: onTap,
            ),
          ],
        );
      }),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final int index;
  final int selectedIndex;
  final ColorScheme colorScheme;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.index,
    required this.selectedIndex,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.2)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 26,
          color:
              isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _HubNavItem extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final ColorScheme colorScheme;
  final Function(int) onTap;

  const _HubNavItem({
    required this.index,
    required this.selectedIndex,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.2)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: ThemedHubIcon(selected: isSelected, size: 28),
      ),
    );
  }
}

class _ProfileNavItem extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final ColorScheme colorScheme;
  final Function(int) onTap;

  const _ProfileNavItem({
    required this.index,
    required this.selectedIndex,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.8)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              isSelected
                  ? Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  )
                  : null,
        ),
        child: ProfileAvatarMenu(
          radius: 14,
          padding: EdgeInsets.zero,
          showMenu: false,
          enableTap: false,
        ),
      ),
    );
  }
}
