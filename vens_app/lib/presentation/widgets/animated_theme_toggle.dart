import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/controllers/theme_controller.dart';

class AnimatedThemeToggle extends StatefulWidget {
  final double? width;
  final double? height;
  final bool showLabel;

  const AnimatedThemeToggle({
    super.key,
    this.width,
    this.height,
    this.showLabel = true,
  });

  @override
  State<AnimatedThemeToggle> createState() => _AnimatedThemeToggleState();
}

class _AnimatedThemeToggleState extends State<AnimatedThemeToggle>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  late ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = Get.find<ThemeController>();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Set initial animation state
    if (_themeController.isDarkMode) {
      _animationController.value = 1.0;
    } else {
      _animationController.value = 0.0;
    }

    // Listen to theme changes and sync animation
    ever(_themeController.themeModeObs, (ThemeMode mode) {
      if (mounted) {
        if (mode == ThemeMode.dark) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    // Just toggle the theme, the animation will be handled by the listener
    _themeController.toggleTheme();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      return GestureDetector(
        onTap: _toggleTheme,
        child: Container(
          width: widget.width ?? 280,
          height: widget.height ?? 60,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background track
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primaryContainer.withValues(alpha: 0.3),
                      colorScheme.secondaryContainer.withValues(alpha: 0.3),
                    ],
                  ),
                ),
              ),

              // Animated sliding indicator
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Positioned(
                    left: _animation.value * ((widget.width ?? 280) - 140),
                    child: Container(
                      width: 136,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _themeController.isDarkMode
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: colorScheme.onPrimary,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),

              // Labels
              if (widget.showLabel)
                Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: textTheme.labelMedium!.copyWith(
                            color:
                                !_themeController.isDarkMode
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                            fontWeight:
                                !_themeController.isDarkMode
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                          ),
                          child: const Text('Light'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: textTheme.labelMedium!.copyWith(
                            color:
                                _themeController.isDarkMode
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                            fontWeight:
                                _themeController.isDarkMode
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                          ),
                          child: const Text('Dark'),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    });
  }
}

// Simple theme toggle button for compact spaces
class CompactThemeToggle extends StatelessWidget {
  const CompactThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeController themeController = Get.find<ThemeController>();
    final colorScheme = Theme.of(context).colorScheme;

    return Obx(() {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          onPressed: () => themeController.toggleTheme(),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return RotationTransition(turns: animation, child: child);
            },
            child: Icon(
              themeController.themeIcon,
              key: ValueKey(themeController.isDarkMode),
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          tooltip: themeController.themeDescription,
        ),
      );
    });
  }
}
