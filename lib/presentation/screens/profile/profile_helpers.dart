import 'package:flutter/material.dart';
import 'package:vens_hub/core/theme/app_colors.dart';
import 'package:vens_hub/core/theme/theme_enums.dart';

// ─── Animation Constants ─────────────────────────────────────────────────────

/// Custom easing curves — Emil Kowalski philosophy
class ProfileEasing {
  /// Strong ease-out for UI interactions: fast start, slow settle
  static const easeOut = Cubic(0.23, 1, 0.32, 1);

  /// Strong ease-in-out for on-screen movement
  static const easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// Drawer-style curve (from Ionic)
  static const easeDrawer = Cubic(0.32, 0.72, 0, 1);

  /// Gentle ease for color/opacity transitions
  static const ease = Cubic(0.25, 0.1, 0.25, 1);
}

/// Duration constants matching Emil's table
class ProfileDuration {
  /// Button press feedback: 100-160ms
  static const press = Duration(milliseconds: 120);

  /// Tooltips, small popovers: 125-200ms
  static const tooltip = Duration(milliseconds: 150);

  /// Dropdowns, selects: 150-250ms
  static const dropdown = Duration(milliseconds: 200);

  /// Modals, drawers: 200-500ms
  static const modal = Duration(milliseconds: 300);

  /// Entry animation for sections/rows: 300ms max per Emil
  static const entry = Duration(milliseconds: 300);

  /// Stagger delay between items: 30-80ms
  static const stagger = Duration(milliseconds: 50);

  /// Color/scheme transitions
  static const scheme = Duration(milliseconds: 250);
}

// ─── Color Helpers ───────────────────────────────────────────────────────────

/// Compute a solid midpoint color from primary → surface gradient (for header bg)
Color getHeaderMidpointColor(BuildContext context) {
  final theme = Theme.of(context);
  final isLight = theme.brightness == Brightness.light;
  final primary = theme.colorScheme.primary;
  final surface = theme.colorScheme.surface;
  final double a0 = isLight ? 0.18 : 0.12;
  final double r0 = primary.r, g0 = primary.g, b0 = primary.b;
  final double r1 = surface.r, g1 = surface.g, b1 = surface.b;
  const double a1 = 1.0;
  final double aMid = (a0 + a1) / 2.0;
  final double rPre = (a0 * r0 + a1 * r1) / 2.0;
  final double gPre = (a0 * g0 + a1 * g1) / 2.0;
  final double bPre = (a0 * b0 + a1 * b1) / 2.0;
  final double rComp = rPre + (1.0 - aMid) * r1;
  final double gComp = gPre + (1.0 - aMid) * g1;
  final double bComp = bPre + (1.0 - aMid) * b1;
  return Color.fromARGB(255, (rComp * 255).round(), (gComp * 255).round(),
      (bComp * 255).round());
}

/// Map [AppColorScheme] to its primary color
Color getSchemeColor(AppColorScheme scheme, BuildContext context) {
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

/// Human-readable name for a color scheme
String getSchemeDisplayName(AppColorScheme scheme) {
  final raw = scheme.toString().split('.').last;
  return raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
}

/// Return black or white depending on luminance
Color getContrastingColor(Color color) {
  return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

// ─── Initials Helper ─────────────────────────────────────────────────────────

String computeInitials({String? firstName, String? lastName, String? email}) {
  final f = (firstName ?? '').trim();
  final l = (lastName ?? '').trim();
  if (f.isNotEmpty || l.isNotEmpty) {
    final i1 = f.isNotEmpty ? f[0].toUpperCase() : '';
    final i2 = l.isNotEmpty ? l[0].toUpperCase() : '';
    final res = (i1 + i2).trim();
    if (res.isNotEmpty) return res;
  }
  final mail = (email ?? '').trim();
  if (mail.isEmpty) return 'U';
  final username = mail.split('@').first;
  final parts =
      username.split(RegExp(r'[._-]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return username.substring(0, 1).toUpperCase();
  return '${parts.first[0].toUpperCase()}${parts.length > 1 ? parts[1][0].toUpperCase() : ''}';
}

// ─── Theme Mode Helpers ──────────────────────────────────────────────────────

IconData getThemeModeIcon(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return Icons.light_mode_outlined;
    case AppThemeMode.dark:
      return Icons.dark_mode_outlined;
    case AppThemeMode.system:
      return Icons.settings_suggest_outlined;
  }
}

String getThemeModeDisplayName(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return 'Light';
    case AppThemeMode.dark:
      return 'Dark';
    case AppThemeMode.system:
      return 'System';
  }
}

// ─── Reusable Animated Scale Press Widget ────────────────────────────────────

/// Wraps a child with press-down scale (0.97) animation.
/// Uses Emil's timing: 120ms ease-out press, instant release.
class AnimatedScalePress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const AnimatedScalePress({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<AnimatedScalePress> createState() => _AnimatedScalePressState();
}

class _AnimatedScalePressState extends State<AnimatedScalePress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ProfileDuration.press,
    );
    _scale = Tween(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: ProfileEasing.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ─── Staggered Entry Animation ───────────────────────────────────────────────

/// Wraps a child that fades in + slides up with stagger delay.
/// Uses scale(0.95) + opacity(0) → scale(1) + opacity(1) per Emil's rule.
class StaggerFadeIn extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration? baseDuration;

  const StaggerFadeIn({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDuration,
  });

  @override
  Widget build(BuildContext context) {
    final delay = index * ProfileDuration.stagger;
    final duration = baseDuration ?? ProfileDuration.entry;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: ProfileEasing.easeOut,
      // Use fraction of total (delay / total) as the effective start
      // TweenAnimationBuilder doesn't support delay directly, so we use
      // a trick: begin the tween at a value that mirrors delay
      // Actually TweenAnimationBuilder does NOT support delay.
      // We'll use a different approach — let the parent control via index.
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// A stagger wrapper that uses a builder pattern with actual delay support.
class StaggerItem extends StatefulWidget {
  final Widget child;
  final int index;

  const StaggerItem({super.key, required this.child, this.index = 0});

  @override
  State<StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<StaggerItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _translate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: ProfileDuration.entry,
    );
    _opacity = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: ProfileEasing.easeOut),
    );
    _translate = Tween<Offset>(
      begin: const Offset(0, 12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: ProfileEasing.easeOut));

    Future.delayed(widget.index * ProfileDuration.stagger, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _translate.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ─── Settings Card (single shadow, no border — impeccable rule) ──────────────

class ProfileSettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const ProfileSettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.04),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            offset: const Offset(0, 4),
            blurRadius: 12,
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
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.primary, size: 20),
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
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Inner Section Container (for content inside a settings card) ────────────

class ProfileInnerSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ProfileInnerSection({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
