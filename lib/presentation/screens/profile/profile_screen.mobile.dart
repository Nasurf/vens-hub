import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vens_hub/core/services/theme/theme_service.dart';
import 'package:vens_hub/core/services/app/privacy_service.dart';
import 'package:vens_hub/core/theme/app_colors.dart';
import 'package:vens_hub/core/theme/theme_enums.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/data/models/user_model.dart';
import 'package:vens_hub/core/config/environment_config.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';
import 'package:vens_hub/core/services/notifications/notification_service.dart';
import 'package:vens_hub/domain/repositories/schedule_repository.dart';
import 'package:vens_hub/core/services/notifications/notification_prefs_service.dart';
import 'package:vens_hub/core/services/notifications/notification_permission_service.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';
import '../../../core/router/routes.dart';
import '../../../core/di/injection_container.dart' as di;

class MobileProfileScreen extends StatefulWidget {
  const MobileProfileScreen({super.key});

  @override
  State<MobileProfileScreen> createState() => _MobileProfileScreenState();
}

class _MobileProfileScreenState extends State<MobileProfileScreen> {
  final AuthRepository _authRepo = di.sl<AuthRepository>();
  final PrivacyService _privacyService = Get.find<PrivacyService>();
  final HomeController _homeController = Get.find<HomeController>();

  late final ScrollController _scrollController;
  double _titleOpacity = 1.0; // 1 = fully visible at top

  void _onScroll() {
    // Fade out the title over the first ~72px of scroll
    const fadeDistance = 72.0;
    final offset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final nextOpacity = (1.0 - (offset / fadeDistance)).clamp(0.0, 1.0);
    if ((nextOpacity - _titleOpacity).abs() > 0.02) {
      setState(() => _titleOpacity = nextOpacity);
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // Helper method to get color for each scheme
  Color _getSchemeColor(AppColorScheme scheme, BuildContext context) {
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

  String _getSchemeDisplayName(AppColorScheme scheme) {
    final name = scheme.toString().split('.').last;
    return name[0].toUpperCase() + name.substring(1);
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Enhanced App Bar with gradient
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(color: headerMidColor),
              ),
              titlePadding: const EdgeInsets.only(left: 8, bottom: 16),
              title: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _titleOpacity,
                child: Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              centerTitle: false,
            ),
            leading: null,
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced Profile Header
                  _buildProfileHeader(context),

                  const SizedBox(height: 32.0),

                  // Quick Actions Row
                  _buildQuickActions(context),

                  const SizedBox(height: 32.0),

                  // Settings title
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // Theme Mode Section
                  _buildThemeModeSection(context, svc),

                  const SizedBox(height: 24.0),

                  // Color Scheme Section
                  _buildColorSchemeSection(context, svc),

                  const SizedBox(height: 24.0),

                  // Department & Level Section
                  _buildAcademicSection(context),

                  const SizedBox(height: 24.0),

                  // Privacy & Notifications sections are managed via Quick Action dialogs now
                  const SizedBox(height: 24.0),

                  // About Section
                  _buildAboutSection(context),

                  const SizedBox(height: 24.0),

                  // Advanced Settings
                  _buildAdvancedSettings(context),

                  const SizedBox(height: 40.0),

                  // Enhanced Logout Button
                  _buildLogoutButton(context),

                  const SizedBox(height: 20.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return _buildSettingsCard(
      context,
      icon: Icons.school_outlined,
      title: 'Department & Level',
      subtitle: 'Used to load your courses and timetable',
      child: Obx(() {
        final user = _homeController.currentUser.value;
        final dept = user?.department ?? '';
        final level = user?.level ?? '';
        final hasDept = dept.isNotEmpty;
        final hasLevel = level.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            children: [
              // Department Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.6,
                      ),
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
                  onPressed: () => _showChangeDeptLevelSheet(context),
                  icon: Icon(
                    hasDept && hasLevel
                        ? Icons.edit_rounded
                        : Icons.add_rounded,
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
          ),
        );
      }),
    );
  }

  Future<void> _showChangeDeptLevelSheet(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hc = _homeController;
    final user = hc.currentUser.value;
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

    final Widget content = StatefulBuilder(
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

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
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
              const SizedBox(height: 24),

              // Form Fields
              IgnorePointer(
                ignoring: isSaving,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isSaving ? 0.6 : 1.0,
                  child: Column(
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

              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
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
                              // Fetch fresh courses for new selection
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
                              await hc.refreshUserDetails(forceRefresh: true);
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child:
                      isSaving
                          ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colorScheme.onPrimary,
                            ),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Save Changes',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (kIsWeb) {
      await showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              contentPadding: const EdgeInsets.all(24),
              content: SingleChildScrollView(child: content),
            ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder:
            (ctx) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: content,
            ),
      );
    }
  }

  Widget _buildNotificationsSection(BuildContext context) {
    final prefs = Get.find<NotificationPrefsService>();
    final notifService = Get.find<NotificationService>();
    return _buildSettingsCard(
      context,
      icon: Icons.notifications_outlined,
      title: 'Notifications',
      subtitle: 'Reminders and alerts',
      child: Obx(() {
        final enabled = prefs.notificationsEnabled.value;
        final daily = prefs.dailyGeneralEnabled.value;
        final classR = prefs.classRemindersEnabled.value;
        return Column(
          children: [
            _buildToggleRow(
              context,
              title: 'Enable notifications',
              subtitle: 'Control all app notifications',
              value: enabled,
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
            const SizedBox(height: 8),
            _buildToggleRow(
              context,
              title: 'Daily general reminders',
              subtitle: '07:30, 15:00 and 19:00',
              value: enabled && daily,
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
            const SizedBox(height: 8),
            _buildToggleRow(
              context,
              title: "Today's class reminders",
              subtitle: '30 minutes before events',
              value: enabled && classR,
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

  Future<void> _showNotificationSettingsDialog(BuildContext context) async {
    final prefs = Get.find<NotificationPrefsService>();
    final notifService = Get.find<NotificationService>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
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
                            'Notification Settings',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Control how you receive notifications',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Main Settings Container
                Obx(() {
                  final enabled = prefs.notificationsEnabled.value;
                  final daily = prefs.dailyGeneralEnabled.value;
                  final classR = prefs.classRemindersEnabled.value;

                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Master Toggle
                        _buildNotificationToggle(
                          context,
                          icon: Icons.notifications_rounded,
                          iconColor:
                              enabled
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                          title: 'Enable Notifications',
                          subtitle: 'Master switch for all notifications',
                          value: enabled,
                          onChanged: (v) async {
                            await prefs.setNotificationsEnabled(v);
                            if (!v) {
                              await notifService.cancelDailyGeneralReminders();
                              await notifService.cancelTodayClassReminders();
                            } else {
                              // Request permission if enabling
                              await NotificationPermissionService.ensureNotificationPermissions();
                              if (prefs.dailyGeneralEnabled.value) {
                                await notifService
                                    .scheduleDailyGeneralReminders();
                              }
                              if (prefs.classRemindersEnabled.value) {
                                await notifService
                                    .scheduleTodayClassReminders();
                              }
                            }
                          },
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Divider(
                            height: 1,
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),

                        // Daily Reminders
                        _buildNotificationToggle(
                          context,
                          icon: Icons.wb_sunny_rounded,
                          iconColor:
                              enabled && daily
                                  ? Colors.orange
                                  : colorScheme.onSurfaceVariant,
                          title: 'Daily Study Reminders',
                          subtitle:
                              'Morning (7:30), Afternoon (3pm), Evening (7pm)',
                          value: enabled && daily,
                          enabled: enabled,
                          onChanged:
                              enabled
                                  ? (v) async {
                                    await prefs.setDailyGeneralEnabled(v);
                                    if (v) {
                                      await notifService
                                          .scheduleDailyGeneralReminders();
                                    } else {
                                      await notifService
                                          .cancelDailyGeneralReminders();
                                    }
                                  }
                                  : null,
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Divider(
                            height: 1,
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),

                        // Class Reminders
                        _buildNotificationToggle(
                          context,
                          icon: Icons.schedule_rounded,
                          iconColor:
                              enabled && classR
                                  ? colorScheme.tertiary
                                  : colorScheme.onSurfaceVariant,
                          title: 'Class Reminders',
                          subtitle: '30 minutes before scheduled classes',
                          value: enabled && classR,
                          enabled: enabled,
                          onChanged:
                              enabled
                                  ? (v) async {
                                    await prefs.setClassRemindersEnabled(v);
                                    if (v) {
                                      await notifService
                                          .scheduleTodayClassReminders();
                                    } else {
                                      await notifService
                                          .cancelTodayClassReminders();
                                    }
                                  }
                                  : null,
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Action Buttons Row
                Row(
                  children: [
                    // Test button only in debug mode
                    if (kDebugMode) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await notifService.showTestNotification(
                              title: 'Test Notification',
                              body: 'Notifications are working! 🎉',
                            );
                            if (ctx.mounted) {
                              Get.snackbar(
                                'Test Sent',
                                'Check your notification tray',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: colorScheme.primaryContainer,
                                colorText: colorScheme.onPrimaryContainer,
                              );
                            }
                          },
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('Test'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: colorScheme.primary.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await NotificationPermissionService.openNotificationSettings();
                        },
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: const Text('System Settings'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.secondary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: colorScheme.secondary.withValues(alpha: 0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (kIsWeb) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final ok = await notifService.requestWebPushPermission(
                          vapidKey: EnvironmentConfig.webPushVapidKey,
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        Get.snackbar(
                          'Web Push',
                          ok
                              ? 'Browser push enabled'
                              : 'Permission denied or failed',
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                      icon: const Icon(Icons.web),
                      label: const Text('Enable Browser Push'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 8),
              ],
            ),
          ),
    );
  }

  Widget _buildNotificationToggle(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    bool enabled = true,
    required ValueChanged<bool>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: headerMidColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(
            alpha:
                Theme.of(context).brightness == Brightness.light ? 0.06 : 0.12,
          ),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.20),
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
            // Animated Avatar
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
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Obx(() {
                      final UserModel? user = _homeController.currentUser.value;
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
                            (photoUrl != null && photoUrl.isNotEmpty)
                                ? NetworkImage(photoUrl)
                                : null,
                        child:
                            (photoUrl == null || photoUrl.isEmpty)
                                ? Text(
                                  initials,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.w700,
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

            // Welcome text with animation
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                final firstName =
                    _homeController.currentUser.value?.firstName ?? 'User';
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Column(
                      children: [
                        Text(
                          'Welcome back, $firstName!',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Customize your app experience',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            fontSize: 16,
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Manage alerts',
            onTap: () => _showNotificationSettingsDialog(context),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickActionCard(
            context,
            icon: Icons.security_outlined,
            title: 'Privacy',
            subtitle: 'Data & security',
            onTap: () => _showPrivacySettingsDialog(context),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeModeSection(BuildContext context, ThemeService svc) {
    return _buildSettingsCard(
      context,
      icon: Icons.brightness_6_outlined,
      title: 'Theme Mode',
      subtitle: 'Choose your preferred theme',
      child: Obx(() {
        final selected = svc.themeModeObs.value;
        final ThemeData lightTheme = svc.getLightThemeData();
        final ThemeData darkTheme = svc.getDarkThemeData();
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _buildAppearancePreview(
                context: context,
                label: 'Light',
                isSelected: selected == AppThemeMode.light,
                onTap: () => svc.setThemeMode(AppThemeMode.light),
                previewTheme: lightTheme,
              ),
              const SizedBox(width: 8),
              _buildAppearancePreview(
                context: context,
                label: 'Dark',
                isSelected: selected == AppThemeMode.dark,
                onTap: () => svc.setThemeMode(AppThemeMode.dark),
                previewTheme: darkTheme,
              ),
              const SizedBox(width: 8),
              _buildAppearancePreview(
                context: context,
                label: 'Auto',
                isSelected: selected == AppThemeMode.system,
                onTap: () => svc.setThemeMode(AppThemeMode.system),
                previewTheme: lightTheme,
                splitRightTheme: darkTheme,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildColorSchemeSection(BuildContext context, ThemeService svc) {
    return _buildSettingsCard(
      context,
      icon: Icons.palette_outlined,
      title: 'Color Scheme',
      subtitle: 'Pick your favorite colors',
      child: Obx(() {
        final selectedScheme = svc.colorSchemeObs.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selected scheme display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _getSchemeColor(selectedScheme, context),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getSchemeDisplayName(selectedScheme),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Color palette grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: svc.getAvailableColorSchemes().length,
              itemBuilder: (context, index) {
                final scheme = svc.getAvailableColorSchemes()[index];
                final isSelected = scheme == selectedScheme;
                final schemeColor = _getSchemeColor(scheme, context);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => svc.setColorScheme(scheme),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: schemeColor,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            isSelected
                                ? Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                  width: 3,
                                )
                                : null,
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: schemeColor.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                                : [
                                  BoxShadow(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.shadow.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                      ),
                      child:
                          isSelected
                              ? Icon(
                                Icons.check_rounded,
                                color: _getContrastingColor(schemeColor),
                                size: 24,
                              )
                              : null,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      }),
    );
  }

  Widget _buildPrivacySection(BuildContext context) {
    return _buildSettingsCard(
      context,
      icon: Icons.security_outlined,
      title: 'Privacy & Data',
      subtitle: 'Control your data and privacy settings',
      child: Column(
        children: [
          // Privacy Policy and Terms Links
          Row(
            children: [
              Expanded(
                child: _buildPrivacyLinkButton(
                  context,
                  'Privacy Policy',
                  Icons.policy_outlined,
                  () => _launchUrl(EnvironmentConfig.privacyPolicyUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPrivacyLinkButton(
                  context,
                  'Terms of Service',
                  Icons.description_outlined,
                  () => _launchUrl(EnvironmentConfig.termsOfServiceUrl),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return _buildSettingsCard(
      context,
      icon: Icons.info_outline,
      title: 'About ${EnvironmentConfig.appName}',
      subtitle: 'App information and support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                // Version Row
                _buildAboutInfoRow(
                  context,
                  icon: Icons.verified_outlined,
                  iconColor: colorScheme.primary,
                  label: 'Version',
                  value:
                      '${EnvironmentConfig.appVersion} (${EnvironmentConfig.buildNumber})',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                // Developer Row
                _buildAboutInfoRow(
                  context,
                  icon: Icons.code_rounded,
                  iconColor: colorScheme.secondary,
                  label: 'Developed by',
                  value: EnvironmentConfig.developedBy,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                // Support Row
                _buildAboutInfoRow(
                  context,
                  icon: Icons.mail_outline_rounded,
                  iconColor: colorScheme.tertiary,
                  label: 'Support',
                  value: EnvironmentConfig.supportEmail,
                  isEmail: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      () => _launchUrl(EnvironmentConfig.developerWebsite),
                  icon: const Icon(Icons.language_rounded, size: 18),
                  label: const Text('Website'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      () => _launchUrl(
                        'mailto:${EnvironmentConfig.supportEmail}',
                      ),
                  icon: const Icon(Icons.email_rounded, size: 18),
                  label: const Text('Contact'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: colorScheme.secondary.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _showLicensesDialog(context),
              icon: Icon(
                Icons.article_outlined,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              label: Text(
                'View Open Source Licenses',
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutInfoRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isEmail = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isEmail ? iconColor : colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyToggle(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyLinkButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(title),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(color: Theme.of(context).colorScheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _showPrivacySettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.security_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Privacy Settings'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Control how your data is collected and used to improve your experience. All data collection is anonymous and helps us make the app better.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),

                // Analytics Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Analytics & Usage Data',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => SwitchListTile(
                          value: _privacyService.analyticsEnabledObs.value,
                          onChanged:
                              (value) =>
                                  _privacyService.setAnalyticsEnabled(value),
                          title: Text(
                            'Enable Analytics',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            'Help improve the app by sharing anonymous usage patterns and feature usage statistics.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Crash Reports Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bug_report_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Crash Reports',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => SwitchListTile(
                          value: _privacyService.crashlyticsEnabledObs.value,
                          onChanged:
                              (value) =>
                                  _privacyService.setCrashlyticsEnabled(value),
                          title: Text(
                            'Enable Crash Reports',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            'Automatically send crash reports and error logs to help us identify and fix issues quickly.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Performance Data Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.speed_outlined,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Performance Metrics',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => SwitchListTile(
                          value: _privacyService.performanceEnabledObs.value,
                          onChanged:
                              (value) =>
                                  _privacyService.setPerformanceEnabled(value),
                          title: Text(
                            'Enable Performance Data',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            'Share app performance metrics like loading times and responsiveness to help optimize the app.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Privacy Notice
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All data collection is completely anonymous and helps us improve the app experience for everyone.',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () => _launchUrl(EnvironmentConfig.privacyPolicyUrl),
              child: const Text('Privacy Policy'),
            ),
          ],
        );
      },
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
    } catch (e) {
      Get.snackbar(
        'Error',
        'Could not open the link',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Widget _buildAdvancedSettings(BuildContext context) {
    // Only show Debug section in debug builds
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return _buildSettingsCard(
      context,
      icon: Icons.bug_report_outlined,
      title: 'Debug',
      subtitle: 'Developer tools (debug only)',
      child: Column(
        children: [
          _buildSettingsTile(
            context,
            icon: Icons.developer_mode,
            title: 'Open Debug Tools',
            subtitle: 'Crash test, notifications, reminders',
            onTap: () => _showDebugToolsDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showDebugToolsDialog(BuildContext context) async {
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
                    _showCrashTestDialog(context);
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
                ListTile(
                  leading: const Icon(Icons.rule_folder_outlined),
                  title: const Text('Notification Tests'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _showNotificationTestDialog(context);
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

  // Appearance previews – same visual logic used on desktop for consistency
  Widget _buildAppearancePreview({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData previewTheme,
    ThemeData? splitRightTheme,
  }) {
    final Color bg = previewTheme.colorScheme.surface;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(8),
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
            borderRadius: BorderRadius.circular(10),
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
              Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          color: previewTheme.colorScheme.surface,
                          child: _buildFakeWindowChromeMobile(
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
                            child: _buildFakeWindowChromeMobile(
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
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    label == 'Dark'
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    size: 12,
                    color: previewTheme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: previewTheme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.check_circle,
                      size: 12,
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

  Widget _buildFakeWindowChromeMobile({
    required Color barColor,
    required Color lineStrong,
    required Color lineFaint,
  }) {
    return Stack(
      children: [
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            width: 22,
            height: 6,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Positioned(
          left: 6,
          bottom: 8,
          right: 6,
          child: Row(
            children: [
              Flexible(
                flex: 6,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: lineStrong,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 10,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: lineFaint,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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

  Future<void> _showNotificationTestDialog(BuildContext context) async {
    final notificationService = Get.find<NotificationService>();
    final prefsService = Get.find<NotificationPrefsService>();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Notification Tests'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => SwitchListTile(
                    title: const Text('Enable Notifications'),
                    subtitle: const Text('Receive reminders for your events'),
                    value: prefsService.notificationsEnabled.value,
                    onChanged: (value) {
                      prefsService.setNotificationsEnabled(value);
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('Test Immediate'),
                  subtitle: const Text('Show a test notification now'),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () async {
                    await notificationService.showTestNotification(
                      title: 'Test Notification',
                      body: 'This is a test notification from Engineering Hub',
                    );
                    if (context.mounted) Navigator.of(context).pop();
                    Get.snackbar(
                      'Test Sent',
                      'Check your notification panel',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                ),
                ListTile(
                  title: const Text('Test Scheduled'),
                  subtitle: const Text(
                    'Schedule a test notification in 5 seconds',
                  ),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    await notificationService.scheduleTestNotificationIn(
                      const Duration(seconds: 5),
                      title: 'Scheduled Test',
                      body:
                          'This test notification was scheduled 5 seconds ago',
                    );
                    if (context.mounted) Navigator.of(context).pop();
                    Get.snackbar(
                      'Test Scheduled',
                      'You should receive a notification in 5 seconds',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  },
                ),
                ListTile(
                  title: const Text('Test Event Reminder'),
                  subtitle: const Text('Test event reminder in 10 seconds'),
                  trailing: const Icon(Icons.event_note),
                  onTap: () async {
                    final eventStart = DateTime.now().add(
                      const Duration(seconds: 15),
                    );
                    await notificationService.scheduleEventReminder(
                      eventId:
                          'test-event-${DateTime.now().millisecondsSinceEpoch}',
                      eventStart: eventStart,
                      minutesBefore: 1,
                      title: 'Test Event Reminder',
                      description: 'Your test event starts in 1 minute',
                    );
                    if (context.mounted) Navigator.of(context).pop();
                    Get.snackbar(
                      'Event Reminder Scheduled',
                      'You should receive a reminder in 10 seconds',
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

  void _showCrashTestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Test Crash'),
            ],
          ),
          content: const Text(
            'This will force the app to crash for testing Firebase Crashlytics. Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                FirebaseCrashlytics.instance.crash();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Test Crash'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout_outlined,
                color: Theme.of(context).colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Sign Out'),
            ],
          ),
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
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.delete_forever_outlined,
                    color: Theme.of(context).colorScheme.error,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text('Delete Account'),
                ],
              ),
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

  // Section wrapper used across settings
  Widget _buildSettingsCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // Simple settings tile used in Developer Options
  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    final disabled = onChanged == null;
    final fg = Theme.of(context).colorScheme.onSurface;
    final sub = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: disabled ? fg.withValues(alpha: 0.5) : fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: disabled ? sub.withValues(alpha: 0.5) : sub,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  // Remove duplicated methods earlier; keep these canonical ones
  // Theme mode helpers
  IconData _getThemeModeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return Icons.light_mode_outlined;
      case AppThemeMode.dark:
        return Icons.dark_mode_outlined;
      case AppThemeMode.system:
        return Icons.settings_suggest_outlined;
    }
  }

  String _getThemeModeDisplayName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  // Used for check icon contrast on color grid
  Color _getContrastingColor(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  // Logout and delete account actions
  Widget _buildLogoutButton(BuildContext context) {
    return Column(
      children: [
        FilledButton.icon(
          onPressed: () => _showLogoutDialog(context),
          icon: const Icon(Icons.logout_outlined, size: 18),
          label: const Text('Sign Out'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _showDeleteAccountDialog(context),
          icon: const Icon(Icons.delete_forever_outlined, size: 18),
          label: const Text('Delete Account'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }
}
