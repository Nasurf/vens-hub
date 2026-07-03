import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:vens_hub/presentation/widgets/common/themed_logo.dart';
import 'package:google_fonts/google_fonts.dart';

class DailyCongratsArgs {
  final int previousStreakCount;
  final int currentStreakCount;
  final String courseTitle;

  DailyCongratsArgs({
    required this.previousStreakCount,
    required this.currentStreakCount,
    required this.courseTitle,
  });
}

class FirstDailyCongratsPage extends StatefulWidget {
  const FirstDailyCongratsPage({
    super.key,
    required this.previousStreakCount,
    required this.currentStreakCount,
    required this.courseTitle,
  });

  final int previousStreakCount;
  final int currentStreakCount;
  final String courseTitle;

  @override
  State<FirstDailyCongratsPage> createState() => _FirstDailyCongratsPageState();
}

class _FirstDailyCongratsPageState extends State<FirstDailyCongratsPage>
    with TickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _blinkCurrentController;
  late final AnimationController _blinkMilestoneController;
  late final Animation<double> _currentScale;
  late final Animation<double> _milestoneScale;

  late int _displayNumber;
  int _blockStart = 1;

  @override
  void initState() {
    super.initState();
    _displayNumber = widget.previousStreakCount;
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 1200),
    );
    _blinkCurrentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _blinkMilestoneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _currentScale = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _blinkCurrentController, curve: Curves.easeInOut),
    );
    _milestoneScale = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(
        parent: _blinkMilestoneController,
        curve: Curves.easeInOut,
      ),
    );

    // Trigger flip after a brief pause, then confetti
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _displayNumber = widget.currentStreakCount;
      });
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _confettiController.play();
    });

    // Initialize block start and handle milestone rollover animation
    final int current = widget.currentStreakCount;
    _blockStart = ((current - 1) ~/ 10) * 10 + 1;
    if (current % 10 == 0) {
      // After showing confetti, slide to next block (e.g., 11..20)
      Future<void>.delayed(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        setState(() {
          _blockStart = current + 1;
        });
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _blinkCurrentController.dispose();
    _blinkMilestoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    Color lighten(Color color, [double amount = 0.18]) {
      final hsl = HSLColor.fromColor(color);
      final hslLight = hsl.withLightness(
        (hsl.lightness + amount).clamp(0.0, 1.0),
      );
      return hslLight.toColor();
    }

    Color darken(Color color, [double amount = 0.18]) {
      final hsl = HSLColor.fromColor(color);
      final hslDark = hsl.withLightness(
        (hsl.lightness - amount).clamp(0.0, 1.0),
      );
      return hslDark.toColor();
    }

    final Color currentPulseColor =
        isLight
            ? darken(colorScheme.primary, 0.24)
            : lighten(colorScheme.primary, 0.28);

    List<Color> buildTealShades(Color base) {
      final hsl = HSLColor.fromColor(base);
      final darker =
          hsl.withLightness((hsl.lightness * 0.55).clamp(0.0, 1.0)).toColor();
      final mid =
          hsl.withLightness((hsl.lightness * 0.85).clamp(0.0, 1.0)).toColor();
      final light =
          hsl.withLightness((hsl.lightness * 1.1).clamp(0.0, 1.0)).toColor();
      return [darker, mid, light];
    }

    final int current = widget.currentStreakCount;
    final int milestone = _blockStart + 9; // end of current block

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: 0.06,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: const ThemedLogo(fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox.shrink(),

          // Confetti overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.02,
                  numberOfParticles: 24,
                  gravity: 0.25,
                  shouldLoop: false,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        'Great job! You kept your ',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rubik(
                          textStyle: theme.textTheme.headlineSmall,
                        ).copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _GradientText(
                        text: 'streak!',
                        style: GoogleFonts.rubik(
                          textStyle: theme.textTheme.headlineSmall,
                        ).copyWith(fontWeight: FontWeight.w900),
                        colors: buildTealShades(colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Daily progress recorded',
                    style: GoogleFonts.rubik(
                      textStyle: theme.textTheme.titleMedium,
                    ).copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Big flip number (colorScheme + gentle pulse)
                  ScaleTransition(
                    scale: _currentScale,
                    child: _FlipNumber(
                      number: _displayNumber,
                      textStyle: GoogleFonts.rubik(
                        textStyle: TextStyle(
                          fontSize: (MediaQuery.of(context).size.width * 0.3)
                              .clamp(96.0, 180.0),
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2,
                          height: 0.9,
                          color: colorScheme.primary,
                        ),
                      ),
                      gradientColors: null,
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'day streak',
                    style: GoogleFonts.rubik(
                      textStyle: theme.textTheme.titleLarge,
                    ).copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 10-day tracker with two rounded bars underlay
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (child, anim) => SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeInOut,
                            ),
                          ),
                          child: child,
                        ),
                    child: _TenDayTracker(
                      key: ValueKey(_blockStart),
                      startDay: _blockStart,
                      currentDay: current,
                      milestoneDay: milestone,
                      currentPulse: _currentScale,
                      milestonePulse: _milestoneScale,
                      currentPulseColor: currentPulseColor,
                      gradientColors: buildTealShades(colorScheme.primary),
                    ),
                  ),

                  const Spacer(),

                  // Milestone CTA text with gradient only on the word "milestone"
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Can you reach the next ',
                          style: GoogleFonts.rubik(
                            textStyle: theme.textTheme.titleMedium,
                          ).copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _GradientText(
                          text: 'milestone?',
                          style: GoogleFonts.rubik(
                            textStyle: theme.textTheme.titleMedium,
                          ).copyWith(fontWeight: FontWeight.w800),
                          colors: buildTealShades(colorScheme.primary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 7),

                  // Encouragement button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        // Return the course title to the caller. The caller decides where to go next.
                        Get.back(result: widget.courseTitle);
                      },
                      child: Text(
                        'I CAN DO IT',
                        style: GoogleFonts.rubik(
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ).copyWith(
                          color:
                              theme.brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlipNumber extends StatelessWidget {
  const _FlipNumber({
    required this.number,
    required this.textStyle,
    this.gradientColors,
  });

  final int number;
  final TextStyle textStyle;
  final List<Color>? gradientColors;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeInBack,
      transitionBuilder: (child, anim) {
        // 3D flip-like effect
        final rotate = Tween(begin: math.pi / 2, end: 0.0).animate(anim);
        return AnimatedBuilder(
          animation: rotate,
          child: child,
          builder: (context, child) {
            final t = rotate.value;
            final isUnder = (child?.key != ValueKey(number));
            final tilt = (isUnder ? -0.003 : 0.003) * (1 - anim.value);
            final Matrix4 transform =
                Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(t + tilt);
            return Transform(
              transform: transform,
              alignment: Alignment.center,
              child: child,
            );
          },
        );
      },
      child:
          gradientColors == null
              ? Text('$number', key: ValueKey(number), style: textStyle)
              : ShaderMask(
                shaderCallback:
                    (bounds) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: gradientColors!,
                    ).createShader(
                      Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                    ),
                blendMode: BlendMode.srcIn,
                child: Text(
                  '$number',
                  key: ValueKey(number),
                  style: textStyle.copyWith(color: Colors.white),
                ),
              ),
    );
  }
}

class _TenDayTracker extends StatelessWidget {
  const _TenDayTracker({
    super.key,
    required this.startDay,
    required this.currentDay,
    required this.milestoneDay,
    required this.currentPulse,
    required this.milestonePulse,
    required this.currentPulseColor,
    required this.gradientColors,
  });

  final int startDay;
  final int currentDay;
  final int milestoneDay;
  final Animation<double> currentPulse;
  final Animation<double> milestonePulse;
  final Color currentPulseColor;
  final List<Color> gradientColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final double itemSize = (size.width / 12).clamp(28.0, 40.0);

    final days = List<int>.generate(10, (i) => startDay + i);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        // Sizing now derived directly from itemSize for shell and track/bar
        // Fill should end at the midpoint between current and next number
        final int index = (currentDay - startDay).clamp(0, 9);

        // Debug print disabled for release build

        // Compute middle primary-over-surface color (same as quiz customization header)
        final bool isLight = Theme.of(context).brightness == Brightness.light;
        Color computeMiddlePrimaryOverSurface(Color primary, Color surface) {
          final double a0 = isLight ? 0.18 : 0.12;
          final double r0 = primary.r;
          final double g0 = primary.g;
          final double b0 = primary.b;
          final double r1 = surface.r;
          final double g1 = surface.g;
          final double b1 = surface.b;
          const double a1 = 1.0;
          final double aMid = (a0 + a1) / 2.0;
          final double rPre = (a0 * r0 + a1 * r1) / 2.0;
          final double gPre = (a0 * g0 + a1 * g1) / 2.0;
          final double bPre = (a0 * b0 + a1 * b1) / 2.0;
          final double rComp = rPre + (1.0 - aMid) * r1;
          final double gComp = gPre + (1.0 - aMid) * g1;
          final double bComp = bPre + (1.0 - aMid) * b1;
          return Color.fromARGB(
            255,
            (rComp * 255.0).round(),
            (gComp * 255.0).round(),
            (bComp * 255.0).round(),
          );
        }

        final Color midTintColor = computeMiddlePrimaryOverSurface(
          colorScheme.primary,
          colorScheme.surface,
        );

        // Provide generous spacing around number containers like the reference
        final double outerHeight = (itemSize * 1.7).clamp(
          itemSize + 12,
          itemSize * 2.2,
        );
        final double innerHeight = (itemSize * 1.18).clamp(
          itemSize + 6,
          itemSize * 1.4,
        );
        final double ringGap = (outerHeight - innerHeight) / 2;
        final double trackWidth = totalWidth - 2 * ringGap;
        final double numbersSidePadding = (itemSize * 0.35).clamp(
          6.0,
          trackWidth * 0.12,
        );
        final double availableWidth = (trackWidth - 2 * numbersSidePadding)
            .clamp(0.0, double.infinity);
        final double perNumberWidth = (availableWidth / 10.0).clamp(
          14.0,
          itemSize,
        );
        final double gapWidth = ((availableWidth - perNumberWidth * 10) / 9.0)
            .clamp(0.0, double.infinity);
        final double barEndFromLeft =
            index == 9
                ? (trackWidth - numbersSidePadding - perNumberWidth / 2)
                : (numbersSidePadding +
                    perNumberWidth / 2 +
                    (index + 0.5) * (perNumberWidth + gapWidth));
        final double completedWidth = barEndFromLeft.clamp(0.0, trackWidth);

        return SizedBox(
          height: outerHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Thermometer shell - outer container covering all numbers
              Container(
                height: outerHeight,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.8,
                    ),
                    width: 2.0,
                  ),
                  borderRadius: BorderRadius.circular(outerHeight / 2),
                ),
              ),

              // Gradient ring between shell and inner track (fills the gap)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _RingFillPainter(
                      outerHeight: outerHeight,
                      innerHeight: innerHeight,
                      gradientColors: gradientColors,
                      gap: ringGap,
                    ),
                  ),
                ),
              ),

              // Thermometer liquid - progress bar that fills up
              Positioned(
                left: ringGap,
                top: (outerHeight - innerHeight) / 2,
                child: Container(
                  width: completedWidth,
                  height: innerHeight,
                  decoration: BoxDecoration(
                    color: midTintColor,
                    borderRadius: BorderRadius.circular(innerHeight / 2),
                  ),
                ),
              ),

              // Inner track outline (same height as progress bar, no fill)
              Positioned(
                left: ringGap,
                right: ringGap,
                top: (outerHeight - innerHeight) / 2,
                child: IgnorePointer(
                  child: Container(
                    height: innerHeight,
                    margin: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.7,
                        ),
                        width: 1.4,
                      ),
                      borderRadius: BorderRadius.circular(innerHeight / 2),
                    ),
                  ),
                ),
              ),

              // Day numbers positioned inside the inner track
              Positioned(
                left: ringGap,
                right: ringGap,
                top: (outerHeight - innerHeight) / 2,
                height: innerHeight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: numbersSidePadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:
                        days.map((day) {
                          final bool isCompleted = day < currentDay;
                          final bool isCurrent = day == currentDay;
                          final bool isMilestone = day == milestoneDay;

                          final Color baseColor =
                              (isCompleted || isCurrent)
                                  ? colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant;

                          Widget numberText(bool useGradient) {
                            final Text base = Text(
                              '${day % 10 == 0 ? 10 : day % 10}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: (perNumberWidth * 0.65).clamp(
                                  12.0,
                                  24.0,
                                ),
                                color:
                                    isCompleted
                                        ? colorScheme.primary
                                        : baseColor,
                              ),
                            );
                            final Widget pulsing =
                                base; // remove beeping on numbers

                            if (useGradient) {
                              return ShaderMask(
                                shaderCallback:
                                    (bounds) => LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: gradientColors,
                                    ).createShader(
                                      Rect.fromLTWH(
                                        0,
                                        0,
                                        bounds.width,
                                        bounds.height,
                                      ),
                                    ),
                                blendMode: BlendMode.srcIn,
                                child: pulsing,
                              );
                            }
                            return pulsing;
                          }

                          final Widget chip = SizedBox(
                            width: perNumberWidth,
                            height: itemSize,
                            child: Center(
                              child:
                                  isMilestone
                                      ? numberText(true)
                                      : numberText(false),
                            ),
                          );

                          if (isMilestone) {
                            return chip; // remove beeping/scale on milestone too
                          }

                          return chip;
                        }).toList(),
                  ),
                ),
              ),

              // Note: No overlay above numbers; they remain fully visible
            ],
          ),
        );
      },
    );
  }
}

class _RingFillPainter extends CustomPainter {
  _RingFillPainter({
    required this.outerHeight,
    required this.innerHeight,
    required this.gradientColors,
    this.gap = 6.0,
  });

  final double outerHeight;
  final double innerHeight;
  final List<Color> gradientColors;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final double outerRadius = outerHeight / 2;
    final double innerRadius = innerHeight / 2;

    final RRect outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        0,
        (size.height - outerHeight) / 2,
        size.width,
        outerHeight,
      ),
      Radius.circular(outerRadius),
    );
    final RRect inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        gap,
        (size.height - innerHeight) / 2,
        size.width - 2 * gap,
        innerHeight,
      ),
      Radius.circular(innerRadius),
    );

    final Path ringPath =
        Path()
          ..addRRect(outer)
          ..addRRect(inner)
          ..fillType = PathFillType.evenOdd;

    final Paint paint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: gradientColors,
          ).createShader(
            Rect.fromLTWH(
              0,
              (size.height - outerHeight) / 2,
              size.width,
              outerHeight,
            ),
          );

    canvas.drawPath(ringPath, paint);
  }

  @override
  bool shouldRepaint(covariant _RingFillPainter oldDelegate) {
    return oldDelegate.outerHeight != outerHeight ||
        oldDelegate.innerHeight != innerHeight ||
        oldDelegate.gradientColors != gradientColors ||
        oldDelegate.gap != gap;
  }
}

class _GradientText extends StatelessWidget {
  const _GradientText({required this.text, required this.colors, this.style});

  final String text;
  final List<Color> colors;
  final TextStyle? style;

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
