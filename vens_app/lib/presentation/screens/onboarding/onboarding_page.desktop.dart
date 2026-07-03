import 'package:flutter/material.dart';
import 'package:vens_hub/core/router/app_router.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/presentation/widgets/common/gradient_hero_panel.dart';
import 'package:vens_hub/presentation/widgets/common/themed_logo.dart';
import 'package:vens_hub/presentation/widgets/common/button_strokes_painter.dart';
import 'package:google_fonts/google_fonts.dart';

/// A full-screen onboarding page for desktop and large tablet layouts.
class DesktopOnboardingPage extends StatelessWidget {
  const DesktopOnboardingPage({super.key});

  // Minimum dimensions for the layout before scrolling kicks in
  static const double _minContentWidth = 420;
  static const double _minHeroWidth = 350;
  static const double _minHeight = 680;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;
          final viewportHeight = constraints.maxHeight;

          // Calculate whether we need scrolling
          final needsHorizontalScroll =
              viewportWidth < (_minContentWidth + _minHeroWidth);
          final needsVerticalScroll = viewportHeight < _minHeight;

          // Build the main row layout
          Widget mainContent = Row(
            children: [
              // The content panel for login/register actions.
              needsHorizontalScroll
                  ? SizedBox(
                    width: _minContentWidth,
                    child: const _OnboardingContent(),
                  )
                  : const Expanded(
                    flex: 4, // 40% of the screen width
                    child: _OnboardingContent(),
                  ),
              // The decorative/brand panel on the right.
              needsHorizontalScroll
                  ? SizedBox(
                    width: _minHeroWidth,
                    child: const GradientHeroPanel(),
                  )
                  : const Expanded(
                    flex: 5, // 50% of the screen width
                    child: GradientHeroPanel(),
                  ),
            ],
          );

          // Apply minimum height if needed
          if (needsVerticalScroll || needsHorizontalScroll) {
            mainContent = SizedBox(
              width:
                  needsHorizontalScroll
                      ? _minContentWidth + _minHeroWidth
                      : null,
              height: needsVerticalScroll ? _minHeight : null,
              child: mainContent,
            );
          }

          // Wrap in scrollable container if viewport is too small
          if (needsHorizontalScroll || needsVerticalScroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: mainContent,
              ),
            );
          }

          return mainContent;
        },
      ),
    );
  }
}

/// The left-side content panel.
class _OnboardingContent extends StatelessWidget {
  const _OnboardingContent();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Very light teal background derived from theme primary
    final HSLColor hsl = HSLColor.fromColor(colorScheme.primary);
    final Color lightTealBg =
        hsl
            .withSaturation((hsl.saturation * 0.35).clamp(0.0, 1.0))
            .withLightness(0.97)
            .toColor();

    return Container(
      color: lightTealBg,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            const minContentHeight = 700.0;
            final needsScroll = availableHeight < minContentHeight;

            Widget content = Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 64.0,
                vertical: 40.0,
              ),
              child: Column(
                mainAxisAlignment:
                    needsScroll
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand row at the top
                  const _BrandRow(),
                  SizedBox(height: needsScroll ? 40 : 60),
                  // Main headline with gradient on "Engineer"
                  Builder(
                    builder: (context) {
                      final titleStyle = GoogleFonts.rubik(
                        textStyle: Theme.of(context).textTheme.displayMedium,
                      ).copyWith(fontWeight: FontWeight.bold, height: 1.2);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _GradientText(
                              text: 'Engineer',
                              style: titleStyle,
                              colors: _buildTealShades(colorScheme.primary),
                            ),
                            Text(
                              ' smarter',
                              style: titleStyle.copyWith(color: Colors.black87),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Subheadline
                  Text(
                    'Courses, practice quizzes, and a smart study planner, all in one place.',
                    style: GoogleFonts.rubik(
                      textStyle: Theme.of(context).textTheme.titleMedium,
                    ).copyWith(
                      color: Colors.grey[700],
                      height: 1.5,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Feature highlights
                  _FeatureHighlight(
                    icon: Icons.check_circle_rounded,
                    title: 'Interactive quizzes: theory and gap-fill modes',
                    description: '',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 16),
                  _FeatureHighlight(
                    icon: Icons.schedule_rounded,
                    title: 'Smart schedule to plan and stay on track',
                    description: '',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 16),
                  _FeatureHighlight(
                    icon: Icons.menu_book_outlined,
                    title: 'Course content and PDF viewer in one workspace',
                    description: '',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 16),
                  _FeatureHighlight(
                    icon: Icons.show_chart_rounded,
                    title: 'Progress tracking across modules',
                    description: '',
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 65),
                  // CTA Buttons (match visual reference: gradient pill + outlined pill)
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      _GradientPillButton(
                        label: 'Get started free',
                        onTap: () => AppRouter.navigateTo(AppRoutes.signUp),
                      ),
                      _OutlinedShadowPillButton(
                        label: 'Sign in',
                        onTap: () => AppRouter.navigateTo(AppRoutes.signIn),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );

            // Always wrap in SingleChildScrollView to prevent overflow
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: needsScroll ? 0 : availableHeight,
                ),
                child: needsScroll ? content : Center(child: content),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const ThemedLogo(height: 48),
        ),
        const SizedBox(width: 14),
        Text(
          'Engineering Hub',
          style: GoogleFonts.rubik(
            textStyle: Theme.of(context).textTheme.titleLarge,
          ).copyWith(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 25,
          ),
        ),
      ],
    );
  }
}

class _FeatureHighlight extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final ColorScheme colorScheme;

  const _FeatureHighlight({
    required this.icon,
    required this.title,
    required this.description,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.rubik(
                  textStyle: Theme.of(context).textTheme.bodyLarge,
                ).copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[800],
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.rubik(
                    textStyle: Theme.of(context).textTheme.bodyMedium,
                  ).copyWith(color: Colors.grey[600], height: 1.3),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GradientPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _GradientPillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: CustomPaint(
        foregroundPainter: ButtonStrokesPainter(
          cornerRadius: 28,
          strokeWidth: 2,
          color: Colors.white,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: _buildTealShades(cs.primary),
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.rubik(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlinedShadowPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlinedShadowPillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        boxShadow: [
          // subtle shadow under the outline button
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        borderRadius: BorderRadius.circular(28),
      ),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          side: BorderSide(color: Colors.grey.shade300, width: 1.4),
          foregroundColor: Colors.grey[900],
          backgroundColor: Colors.white,
          textStyle: GoogleFonts.rubik(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

// Build a smooth teal gradient using shade variations (not just opacity changes)
List<Color> _buildTealShades(Color base) {
  final hsl = HSLColor.fromColor(base);
  // Keep hue, vary lightness to create darker->lighter range
  final darker =
      hsl.withLightness((hsl.lightness * 0.55).clamp(0.0, 1.0)).toColor();
  final mid =
      hsl.withLightness((hsl.lightness * 0.85).clamp(0.0, 1.0)).toColor();
  final light =
      hsl.withLightness((hsl.lightness * 1.1).clamp(0.0, 1.0)).toColor();
  return [darker, mid, light];
}

class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Color> colors;

  const _GradientText({required this.text, required this.colors, this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback:
          (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: colors,
          ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style),
    );
  }
}
