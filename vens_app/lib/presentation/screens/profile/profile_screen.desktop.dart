import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vens_hub/core/services/theme/theme_service.dart';
import 'package:vens_hub/core/services/app/privacy_service.dart';
import 'package:vens_hub/core/theme/app_colors.dart';
import 'package:vens_hub/core/theme/theme_enums.dart';
import 'package:vens_hub/core/config/environment_config.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/core/services/notifications/notification_service.dart';
import 'package:vens_hub/domain/repositories/schedule_repository.dart';
import 'package:vens_hub/core/services/notifications/notification_prefs_service.dart';
import 'package:vens_hub/core/services/notifications/notification_permission_service.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';

import '../../../core/router/routes.dart';
import '../../../core/di/injection_container.dart' as di;

class DesktopProfileScreen extends GetView<ThemeService> {
  DesktopProfileScreen({super.key});

  final AuthRepository _authRepo = di.sl<AuthRepository>();
  final HomeController _homeController = Get.find<HomeController>();
  final PrivacyService _privacyService = Get.find<PrivacyService>();

  // Helper method to get color for each scheme
  Color _getSchemeColor(AppColorScheme scheme, BuildContext context) {
    // You'll need to map these to your actual color schemes
    switch (scheme) {
      case AppColorScheme.blue:
        return AppColors.bluePrimary;
      case AppColorScheme.green:
        return AppColors.greenPrimary;
      case AppColorScheme.purple:
        return AppColors.purplePrimary;
      case AppColorScheme.pink:
        return AppColors.pinkPrimary;
      case AppColorScheme.orange:
        return AppColors.orangePrimary;
      case AppColorScheme.greyscale:
        return AppColors.gsDarkPrimary;
      case AppColorScheme.teal:
        return AppColors.tealPrimary;
    }
  }

  Widget _buildAcademicSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return _buildInnerOptionContainer(
      context,
      Obx(() {
        final user = _homeController.currentUser.value;
        final dept = user?.department ?? '';
        final level = user?.level ?? '';
        final hasDept = dept.isNotEmpty;
        final hasLevel = level.isNotEmpty;

        return Column(
          children: [
            // Department Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.domain_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Department',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasDept ? dept : 'Not set',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              hasDept
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Level Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.trending_up_rounded,
                    size: 20,
                    color: colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasLevel ? 'Level $level' : 'Not set',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              hasLevel
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Edit Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showChangeDeptLevelDialog(context),
                icon: Icon(
                  hasDept && hasLevel ? Icons.edit_rounded : Icons.add_rounded,
                  size: 18,
                ),
                label: Text(hasDept && hasLevel ? 'Change' : 'Set Up'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showChangeDeptLevelDialog(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final user = _homeController.currentUser.value;
    if (user == null || (user.id == null || user.id!.isEmpty)) {
      Get.showSnackbar(
        const GetSnackBar(
          title: 'Not signed in',
          message: 'Please sign in to update your profile',
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    String? department = (user.department.isNotEmpty) ? user.department : null;
    String? level = (user.level.isNotEmpty) ? user.level : null;
    const Map<String, String> departments = {
      'EEE': 'Electrical Engineering',
      'MEE': 'Mechanical Engineering',
      'MCT': 'Mechatronics Engineering',
      'COE': 'Computer Engineering',
      'CHE': 'Chemical Engineering',
      'BME': 'Biomedical Engineering',
      'AAE': 'Aeronautics Engineering',
      'CVE': 'Civil Engineering',
      'PTE': 'Petroleum Engineering',
    };
    const levels = ['100', '200', '300', '400', '500'];

    bool isSaving = false;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: 24,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Academic Profile',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Select your department and level',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: StatefulBuilder(
            builder: (ctx, setLocalState) {
              final inputDecoration = InputDecoration(
                filled: true,
                fillColor: colorScheme.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              );

              return SizedBox(
                width: 440,
                child: IgnorePointer(
                  ignoring: isSaving,
                  child: Opacity(
                    opacity: isSaving ? 0.6 : 1.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Department Label
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.domain_rounded,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Department',
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: department,
                          decoration: inputDecoration.copyWith(
                            hintText: 'Choose your department',
                            hintStyle: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          isExpanded: true,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          dropdownColor: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          items:
                              departments.entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(
                                        '${e.key} - ${e.value}',
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setLocalState(() => department = v),
                        ),

                        const SizedBox(height: 20),

                        // Level Label
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.trending_up_rounded,
                                size: 16,
                                color: colorScheme.secondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Level',
                                style: textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: level,
                          decoration: inputDecoration.copyWith(
                            hintText: 'Choose your level',
                            hintStyle: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          isExpanded: true,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          dropdownColor: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          items:
                              levels
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        'Level $e',
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setLocalState(() => level = v),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            StatefulBuilder(
              builder:
                  (ctx, setLocalState) => FilledButton(
                    onPressed:
                        isSaving
                            ? null
                            : () async {
                              if ((department == null || department!.isEmpty) ||
                                  (level == null || level!.isEmpty)) {
                                Get.showSnackbar(
                                  GetSnackBar(
                                    title: 'Missing info',
                                    message:
                                        'Please choose both department and level',
                                    backgroundColor:
                                        Theme.of(ctx).colorScheme.error,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              try {
                                setLocalState(() => isSaving = true);
                                final fs = Get.find<FireStoreServices>();
                                final courses = await fs.getCourseInfo(
                                  department!,
                                  level!,
                                );
                                await fs.updateUserData(user.id!, {
                                  'department': department,
                                  'level': level,
                                  'courseInfo':
                                      courses.map((c) => c.toJson()).toList(),
                                });
                                // Force refresh user details so HomeController has updated courseInfo immediately
                                await _homeController.refreshUserDetails(
                                  forceRefresh: true,
                                );
                                await Get.find<ScheduleRepository>()
                                    .refreshFromServer();
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                Get.showSnackbar(
                                  const GetSnackBar(
                                    title: 'Updated',
                                    message: 'Profile updated',
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              } catch (e) {
                                if (ctx.mounted) {
                                  Get.showSnackbar(
                                    GetSnackBar(
                                      title: 'Error',
                                      message: 'Failed to save: $e',
                                      backgroundColor:
                                          Theme.of(ctx).colorScheme.error,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } finally {
                                if (ctx.mounted) {
                                  setLocalState(() => isSaving = false);
                                }
                              }
                            },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        isSaving
                            ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(ctx).colorScheme.onPrimary,
                              ),
                            )
                            : const Text('Save Changes'),
                  ),
            ),
          ],
        );
      },
    );
  }

  // About section (parity with mobile)
  Widget _buildAboutSection(BuildContext context) {
    return _buildInnerOptionContainer(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      () => _launchUrl(EnvironmentConfig.developerWebsite),
                  icon: const Icon(Icons.language_outlined, size: 18),
                  label: const Text('Visit Website'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showLicensesDialog(context),
                  icon: const Icon(Icons.article_outlined, size: 18),
                  label: const Text('Licenses'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${EnvironmentConfig.appName} v${EnvironmentConfig.appVersion} (${EnvironmentConfig.buildNumber})',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Support: ${EnvironmentConfig.supportEmail}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showLicensesDialog(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: EnvironmentConfig.appName,
      applicationVersion: EnvironmentConfig.appVersion,
      applicationIcon: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(
          Icons.engineering,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        Get.snackbar(
          'Error',
          'Could not open the link',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (_) {
      Get.snackbar(
        'Error',
        'Could not open the link',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  String _getSchemeDisplayName(AppColorScheme scheme) {
    final raw = scheme.toString().split('.').last;
    if (raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<ThemeService>();
    // Compute the same solid midpoint color used on Quiz Customization header
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;
    final double a0 = isLight ? 0.18 : 0.12; // start alpha of old gradient
    final double r0 = primary.r,
        g0 = primary.g,
        b0 = primary.b; // normalized 0..1
    final double r1 = surface.r,
        g1 = surface.g,
        b1 = surface.b; // normalized 0..1
    const double a1 = 1.0; // end alpha (surface is opaque)
    final double aMid = (a0 + a1) / 2.0;
    final double rPre = (a0 * r0 + a1 * r1) / 2.0;
    final double gPre = (a0 * g0 + a1 * g1) / 2.0;
    final double bPre = (a0 * b0 + a1 * b1) / 2.0;
    final double rComp = rPre + (1.0 - aMid) * r1;
    final double gComp = gPre + (1.0 - aMid) * g1;
    final double bComp = bPre + (1.0 - aMid) * b1;
    final Color headerMidColor = Color.fromARGB(
      255,
      (rComp * 255.0).round(),
      (gComp * 255.0).round(),
      (bComp * 255.0).round(),
    );
    final String userName =
        _homeController.currentUser.value?.firstName ?? 'User';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: null,
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const double maxContentWidth = 1180;
            final double contentWidth =
                constraints.maxWidth < maxContentWidth
                    ? constraints.maxWidth
                    : maxContentWidth;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    constraints.maxWidth > contentWidth
                        ? (constraints.maxWidth - contentWidth) / 2
                        : 0,
              ),
              child: SizedBox(
                width: contentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header – replicated visual style from mobile (gradient panel + glowing avatar)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: headerMidColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.light
                                    ? 0.06
                                    : 0.12,
                          ),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.shadow.withValues(alpha: 0.20),
                            blurRadius: 20,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            // Animated gradient avatar ring (glow)
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 800),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary,
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          spreadRadius: 0,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Obx(() {
                                      final user =
                                          _homeController.currentUser.value;
                                      final String? photoUrl = user?.photoUrl;
                                      final String initials = _computeInitials(
                                        firstName: user?.firstName,
                                        lastName: user?.lastName,
                                        email: user?.email,
                                      );
                                      return CircleAvatar(
                                        radius: 50,
                                        backgroundColor: Colors.transparent,
                                        foregroundImage:
                                            (photoUrl != null &&
                                                    photoUrl.isNotEmpty)
                                                ? NetworkImage(photoUrl)
                                                : null,
                                        child:
                                            (photoUrl == null ||
                                                    photoUrl.isEmpty)
                                                ? Text(
                                                  initials,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .headlineSmall
                                                      ?.copyWith(
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .onPrimary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                )
                                                : null,
                                      );
                                    }),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            // Subtle intro text animation
                            TweenAnimationBuilder<double>(
                              duration: const Duration(milliseconds: 1000),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, value, child) {
                                final firstName =
                                    _homeController
                                        .currentUser
                                        .value
                                        ?.firstName ??
                                    'User';
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: Column(
                                      children: [
                                        Text(
                                          'Welcome back, $firstName !',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Customize your app experience',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyLarge?.copyWith(
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white
                                                    : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // Department & Level Section
                    _buildSectionTitle(context, 'Department & Level'),
                    const SizedBox(height: 16.0),
                    _buildAcademicSection(context),

                    const SizedBox(height: 24.0),

                    // Theme Mode Section
                    _buildSectionTitle(context, 'Appearance'),
                    const SizedBox(height: 16.0),

                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: headerMidColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.light
                                    ? 0.06
                                    : 0.12,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.shadow.withValues(alpha: 0.20),
                            blurRadius: 16,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.brightness_6_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Theme Mode',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          // Visual previews for Light/Dark with selection (always render true light/dark)
                          Obx(() {
                            final selected = svc.themeModeObs.value;
                            final ThemeData lightTheme =
                                svc.getLightThemeData();
                            final ThemeData darkTheme = svc.getDarkThemeData();
                            return _buildInnerOptionContainer(
                              context,
                              Row(
                                children: [
                                  _buildAppearancePreview(
                                    context: context,
                                    label: 'Light',
                                    isSelected: selected == AppThemeMode.light,
                                    onTap:
                                        () => svc.setThemeMode(
                                          AppThemeMode.light,
                                        ),
                                    previewTheme: lightTheme,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildAppearancePreview(
                                    context: context,
                                    label: 'Dark',
                                    isSelected: selected == AppThemeMode.dark,
                                    onTap:
                                        () =>
                                            svc.setThemeMode(AppThemeMode.dark),
                                    previewTheme: darkTheme,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildAppearancePreview(
                                    context: context,
                                    label: 'Auto',
                                    isSelected: selected == AppThemeMode.system,
                                    onTap:
                                        () => svc.setThemeMode(
                                          AppThemeMode.system,
                                        ),
                                    previewTheme: lightTheme,
                                    splitRightTheme: darkTheme,
                                  ),
                                ],
                              ),
                            );
                          }),
                          // Removed old segmented control (redundant)
                        ],
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // Color Scheme Section (moved up directly after Appearance)
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: headerMidColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(
                            alpha:
                                Theme.of(context).brightness == Brightness.light
                                    ? 0.06
                                    : 0.12,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.shadow.withValues(alpha: 0.20),
                            blurRadius: 16,
                            spreadRadius: 0,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.palette_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Color Scheme',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16.0),
                          Obx(() {
                            final selectedScheme = svc.colorSchemeObs.value;
                            return _buildInnerOptionContainer(
                              context,
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final label = _getSchemeDisplayName(
                                        selectedScheme,
                                      );
                                      final color = _getSchemeColor(
                                        selectedScheme,
                                        context,
                                      );
                                      return Text(
                                        label,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.copyWith(
                                          color: color,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 60,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount:
                                          svc.getAvailableColorSchemes().length,
                                      separatorBuilder:
                                          (context, index) =>
                                              const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final scheme =
                                            svc.getAvailableColorSchemes()[index];
                                        final isSelected =
                                            scheme == selectedScheme;
                                        final schemeColor = _getSchemeColor(
                                          scheme,
                                          context,
                                        );
                                        return GestureDetector(
                                          onTap:
                                              () => svc.setColorScheme(scheme),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: schemeColor,
                                              border:
                                                  isSelected
                                                      ? Border.all(
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .outline,
                                                        width: 3,
                                                      )
                                                      : null,
                                              boxShadow:
                                                  isSelected
                                                      ? [
                                                        BoxShadow(
                                                          color: schemeColor
                                                              .withValues(
                                                                alpha: 0.3,
                                                              ),
                                                          blurRadius: 8,
                                                          spreadRadius: 2,
                                                        ),
                                                      ]
                                                      : null,
                                            ),
                                            child:
                                                isSelected
                                                    ? Icon(
                                                      Icons.check,
                                                      color:
                                                          _getContrastingColor(
                                                            schemeColor,
                                                          ),
                                                      size: 24,
                                                    )
                                                    : null,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // Department & Level Section (Academic)
                    _buildSectionTitle(context, 'Academic Profile'),
                    const SizedBox(height: 16.0),
                    _buildAcademicSection(context),

                    const SizedBox(height: 24.0),

                    // Notifications Section
                    _buildSectionTitle(context, 'Notifications'),
                    const SizedBox(height: 16.0),
                    _buildNotificationsSection(context),

                    const SizedBox(height: 24.0),

                    // Privacy Section
                    _buildSectionTitle(context, 'Privacy & Data'),
                    const SizedBox(height: 16.0),
                    _buildPrivacySection(context),
                    const SizedBox(height: 24.0),

                    // Debug Section button (moved below Privacy)
                    _buildSectionTitle(context, 'Debug'),
                    const SizedBox(height: 16.0),
                    _buildInnerOptionContainer(
                      context,
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton.icon(
                          onPressed:
                              () => _showDesktopDebugToolsDialog(context),
                          icon: const Icon(Icons.developer_mode),
                          label: const Text('Open Debug Tools'),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24.0),

                    // About Section
                    _buildSectionTitle(context, 'About'),
                    const SizedBox(height: 16.0),
                    _buildAboutSection(context),

                    const SizedBox(height: 32.0),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 280),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.logout_outlined),
                              label: const Text('Sign Out'),
                              onPressed: () => _showLogoutDialog(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.errorContainer,
                                foregroundColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                minimumSize: const Size(0, 56),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.labelLarge?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 280),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.delete_forever_outlined),
                              label: const Text('Delete Account'),
                              onPressed:
                                  () => _showDeleteAccountDialog(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.errorContainer,
                                foregroundColor:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                minimumSize: const Size(0, 56),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                textStyle: Theme.of(
                                  context,
                                ).textTheme.labelLarge?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // Removed unused _getThemeModeIcon helper after redesign

  Color _getContrastingColor(Color color) {
    // Simple contrast calculation
    final int r = (color.r * 255.0).round().clamp(0, 255);
    final int g = (color.g * 255.0).round().clamp(0, 255);
    final int b = (color.b * 255.0).round().clamp(0, 255);
    final brightness = (r * 299 + g * 587 + b * 114) / 1000;
    return brightness > 128 ? Colors.black : Colors.white;
  }

  String _computeInitials({
    String? firstName,
    String? lastName,
    String? email,
  }) {
    String? f = (firstName ?? '').trim();
    String? l = (lastName ?? '').trim();
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

  // Appearance previews similar to inspiration cards
  // Helper to draw simple UI chrome for previews
  // Uses provided colors so it can mimic either theme side independently
  Widget _buildFakeWindowChrome({
    required Color barColor,
    required Color lineStrong,
    required Color lineFaint,
  }) {
    return Stack(
      children: [
        Positioned(
          left: 8,
          top: 8,
          child: Container(
            width: 28,
            height: 8,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 10,
          right: 8,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 8,
                decoration: BoxDecoration(
                  color: lineStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: lineFaint,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Inner container wrapper like the inspiration screenshot
  Widget _buildInnerOptionContainer(BuildContext context, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _buildPrivacySection(BuildContext context) {
    final privacy = _privacyService;
    return _buildInnerOptionContainer(
      context,
      Obx(() {
        return Column(
          children: [
            SwitchListTile.adaptive(
              title: const Text('Share crash reports'),
              subtitle: const Text(
                'Help improve the app by sending crash data',
              ),
              value: privacy.crashlyticsEnabledObs.value,
              onChanged: (v) async {
                await privacy.setCrashlyticsEnabled(v);
                FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(v);
              },
            ),
            const Divider(height: 8),
            SwitchListTile.adaptive(
              title: const Text('Share analytics'),
              subtitle: const Text('Send anonymous usage statistics'),
              value: privacy.analyticsEnabledObs.value,
              onChanged: (v) async {
                await privacy.setAnalyticsEnabled(v);
              },
            ),
            const Divider(height: 8),
            SwitchListTile.adaptive(
              title: const Text('Share performance data'),
              subtitle: const Text(
                'Share anonymous performance metrics to improve app speed',
              ),
              value: privacy.performanceEnabledObs.value,
              onChanged: (v) async {
                await privacy.setPerformanceEnabled(v);
              },
            ),
            const Divider(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _launchUrl(EnvironmentConfig.privacyPolicyUrl),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => _launchUrl(EnvironmentConfig.termsOfServiceUrl),
            ),
            const Divider(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.security_outlined),
              title: const Text('Notification permissions'),
              subtitle: const Text('Check and manage system permission'),
              trailing: TextButton(
                onPressed: () async {
                  await NotificationPermissionService.openNotificationSettings();
                },
                child: const Text('Open Settings'),
              ),
              onTap: () async {
                final ok =
                    await NotificationPermissionService.areNotificationsEnabled();
                if (context.mounted) {
                  Get.snackbar(
                    'Permissions',
                    ok
                        ? 'Notifications are enabled'
                        : 'Notifications are disabled',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor:
                        ok
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
                  );
                }
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showDesktopDebugToolsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Debug Tools'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Test Crash'),
                  onTap: () {
                    Navigator.of(context).pop();
                    FirebaseCrashlytics.instance.crash();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Send Test Notification'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final svc = Get.find<NotificationService>();
                    await svc.showTestNotification();
                    Get.snackbar(
                      'Notification',
                      'Test notification sent',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule_send_outlined),
                  title: const Text('Schedule Test Notification (1 min)'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final svc = Get.find<NotificationService>();
                    await svc.scheduleTestNotificationIn(
                      const Duration(minutes: 1),
                    );
                    Get.snackbar(
                      'Scheduled',
                      'Test notification in 1 minute',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.class_outlined),
                  title: const Text("Reschedule Today's Class Reminders"),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final svc = Get.find<NotificationService>();
                    final repo = Get.find<ScheduleRepository>();
                    final count =
                        repo.getCombinedEventsForDay(DateTime.now()).length;
                    await svc.scheduleTodayClassReminders();
                    Get.snackbar(
                      'Class reminders',
                      'Scheduled for $count event(s) today',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.refresh_outlined),
                  title: const Text('Reschedule Daily General Reminders'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final svc = Get.find<NotificationService>();
                    await svc.scheduleDailyGeneralReminders();
                    Get.snackbar(
                      'General reminders',
                      'Daily reminders scheduled',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    final prefs = Get.find<NotificationPrefsService>();
    final notifService = Get.find<NotificationService>();
    return _buildInnerOptionContainer(
      context,
      Obx(() {
        final enabled = prefs.notificationsEnabled.value;
        final daily = prefs.dailyGeneralEnabled.value;
        final classR = prefs.classRemindersEnabled.value;
        return Column(
          children: [
            SwitchListTile.adaptive(
              value: enabled,
              title: const Text('Enable notifications'),
              subtitle: const Text('Control all app notifications'),
              onChanged: (v) async {
                await prefs.setNotificationsEnabled(v);
                if (!v) {
                  await notifService.cancelDailyGeneralReminders();
                  await notifService.cancelTodayClassReminders();
                } else {
                  if (prefs.dailyGeneralEnabled.value) {
                    await notifService.scheduleDailyGeneralReminders();
                  }
                  if (prefs.classRemindersEnabled.value) {
                    await notifService.scheduleTodayClassReminders();
                  }
                }
              },
            ),
            const Divider(height: 8),
            SwitchListTile.adaptive(
              value: enabled && daily,
              title: const Text('Daily general reminders'),
              subtitle: const Text('07:30, 15:00, 19:00'),
              onChanged:
                  enabled
                      ? (v) async {
                        await prefs.setDailyGeneralEnabled(v);
                        if (v) {
                          await notifService.scheduleDailyGeneralReminders();
                        } else {
                          await notifService.cancelDailyGeneralReminders();
                        }
                      }
                      : null,
            ),
            SwitchListTile.adaptive(
              value: enabled && classR,
              title: const Text("Today's class reminders"),
              subtitle: const Text('30 mins before events'),
              onChanged:
                  enabled
                      ? (v) async {
                        await prefs.setClassRemindersEnabled(v);
                        if (v) {
                          await notifService.scheduleTodayClassReminders();
                        } else {
                          await notifService.cancelTodayClassReminders();
                        }
                      }
                      : null,
            ),
          ],
        );
      }),
    );
  }

  Widget _buildAppearancePreview({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData previewTheme,
    ThemeData?
    splitRightTheme, // if provided, right half uses this theme (for Auto)
  }) {
    final Color bg = previewTheme.colorScheme.surface;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: splitRightTheme == null ? bg : null,
            gradient:
                splitRightTheme == null
                    ? null
                    : LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        bg,
                        bg,
                        splitRightTheme.colorScheme.surface,
                        splitRightTheme.colorScheme.surface,
                      ],
                      stops: const [0.0, 0.5, 0.5, 1.0],
                    ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fake window chrome preview
              Container(
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      // Left half: light (previewTheme)
                      Expanded(
                        child: Container(
                          color: previewTheme.colorScheme.surface,
                          child: _buildFakeWindowChrome(
                            barColor: previewTheme.colorScheme.onSurfaceVariant,
                            lineStrong: previewTheme
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.8),
                            lineFaint: previewTheme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      if (splitRightTheme != null)
                        Expanded(
                          child: Container(
                            color: splitRightTheme.colorScheme.surface,
                            child: _buildFakeWindowChrome(
                              barColor:
                                  splitRightTheme.colorScheme.onSurfaceVariant,
                              lineStrong: splitRightTheme
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.8),
                              lineFaint: splitRightTheme
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    label == 'Dark'
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    size: 16,
                    color: previewTheme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(label, style: previewTheme.textTheme.labelMedium),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: previewTheme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _authRepo.signOut();
                Get.offAllNamed(AppRoutes.onBoarding);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Delete Account'),
              content: const Text(
                'This will permanently delete your account and data. This action cannot be undone. Are you sure?',
              ),
              actions: [
                TextButton(
                  onPressed:
                      isDeleting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      isDeleting
                          ? null
                          : () async {
                            setState(() => isDeleting = true);
                            final result =
                                await _authRepo.deleteAccountAndData();
                            result.fold(
                              (failure) {
                                setState(() => isDeleting = false);
                                Get.snackbar(
                                  'Deletion Failed',
                                  failure.message,
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              },
                              (_) {
                                Navigator.of(context).pop();
                                Get.offAllNamed(AppRoutes.signIn);
                                Get.snackbar(
                                  'Account Deleted',
                                  'Your account has been removed.',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              },
                            );
                          },
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  child:
                      isDeleting
                          ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onError,
                            ),
                          )
                          : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
