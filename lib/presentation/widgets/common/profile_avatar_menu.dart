import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/data/models/user_model.dart';

class ProfileAvatarMenu extends StatelessWidget {
  final double radius;
  final EdgeInsets? padding;
  final bool showMenu; // if false, just tap to route
  final VoidCallback? onTap; // used when showMenu is false
  final bool enableTap; // when false, returns non-interactive avatar
  const ProfileAvatarMenu({
    super.key,
    this.radius = 16,
    this.padding,
    this.showMenu = true,
    this.onTap,
    this.enableTap = true,
  });

  @override
  Widget build(BuildContext context) {
    final HomeController home = Get.find<HomeController>();
    return Obx(() {
      final UserModel? user = home.currentUser.value;
      final String? photoUrl = user?.photoUrl;
      final String initials = _computeInitials(
        firstName: user?.firstName,
        lastName: user?.lastName,
        email: user?.email,
      );

      final colorScheme = Theme.of(context).colorScheme;
      final avatar = CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.primary,
        foregroundImage:
            (photoUrl != null && photoUrl.isNotEmpty)
                ? NetworkImage(photoUrl)
                : null,
        child:
            (photoUrl == null || photoUrl.isEmpty)
                ? Text(
                  initials,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimary,
                  ),
                )
                : null,
      );

      return Padding(
        padding: padding ?? EdgeInsets.zero,
        child:
            showMenu
                ? PopupMenuButton<_MenuAction>(
                  tooltip: 'Account',
                  onSelected: (value) async {
                    switch (value) {
                      case _MenuAction.viewStreaks:
                        Get.toNamed(AppRoutes.streaks);
                        break;
                      case _MenuAction.logout:
                        await home.signOut();
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    final theme = Theme.of(context);
                    return [
                      PopupMenuItem<_MenuAction>(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatFullName(user),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if ((user?.email ?? '').isNotEmpty)
                              Text(
                                user!.email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 10),
                      PopupMenuItem<_MenuAction>(
                        value: _MenuAction.viewStreaks,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department_outlined,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text('Streaks'),
                          ],
                        ),
                      ),
                      PopupMenuItem<_MenuAction>(
                        value: _MenuAction.logout,
                        child: Row(
                          children: [
                            const Icon(Icons.logout, size: 18),
                            const SizedBox(width: 8),
                            Text('Log Out'),
                          ],
                        ),
                      ),
                    ];
                  },
                  child: avatar,
                )
                : enableTap
                ? InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(radius),
                  child: avatar,
                )
                : avatar,
      );
    });
  }

  static String _formatFullName(UserModel? user) {
    final String f = (user?.firstName ?? '').trim();
    final String l = (user?.lastName ?? '').trim();
    final String full = [f, l].where((p) => p.isNotEmpty).join(' ').trim();
    if (full.isNotEmpty) return full;
    return (user?.email ?? '').isNotEmpty ? user!.email : 'Account';
  }

  static String _computeInitials({
    String? firstName,
    String? lastName,
    String? email,
  }) {
    final String f = (firstName ?? '').trim();
    final String l = (lastName ?? '').trim();
    if (f.isNotEmpty || l.isNotEmpty) {
      final String i1 = f.isNotEmpty ? f[0].toUpperCase() : '';
      final String i2 = l.isNotEmpty ? l[0].toUpperCase() : '';
      final String res = (i1 + i2).trim();
      if (res.isNotEmpty) return res;
    }
    final mail = (email ?? '').trim();
    if (mail.isEmpty) return 'U';
    final username = mail.split('@').first;
    final parts =
        username.split(RegExp(r'[._-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return username.substring(0, 1).toUpperCase();
    final first = parts.first[0].toUpperCase();
    final second = parts.length > 1 ? parts[1][0].toUpperCase() : '';
    final initials = (first + second);
    return initials.isNotEmpty ? initials : 'U';
  }
}

enum _MenuAction { viewStreaks, logout }
