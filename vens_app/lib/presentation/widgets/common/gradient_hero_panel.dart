import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Reusable right-side hero with gradients, soft glows and watermark logos.
class GradientHeroPanel extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final String? imagePath;

  const GradientHeroPanel({
    super.key,
    this.title,
    this.subtitle,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color darkBg = const Color(0xFF0C0F0F);
    final Color teal = colorScheme.primary;

    return Container(
      color: darkBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base diagonal gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    darkBg,
                    Color.alphaBlend(teal.withValues(alpha: 0.12), darkBg),
                  ],
                ),
              ),
            ),
          ),

          // Soft radial glows (top-center & bottom-right)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RadialGlowPainter(
                  topCenterColor: teal.withValues(alpha: 0.25),
                  bottomRightColor: teal.withValues(alpha: 0.22),
                ),
              ),
            ),
          ),

          // Large watermark logos
          Positioned(
            right: 60,
            top: 80,
            child: Opacity(
              opacity: 0.08,
              child: SvgPicture.asset(
                'assets/svg/transp_11_inlined.svg',
                width: 220,
                height: 220,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          Positioned(
            left: 80,
            bottom: 60,
            child: Opacity(
              opacity: 0.08,
              child: SvgPicture.asset(
                'assets/svg/transp_11_inlined.svg',
                width: 260,
                height: 260,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),

          // Text Overlay
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    )
                  else
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(
                          context,
                        ).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.1,
                        ),
                        children: [
                          const TextSpan(text: 'Engineer '),
                          TextSpan(
                            text: 'smarter',
                            style: TextStyle(color: teal),
                          ),
                          const TextSpan(text: ',\nnot harder.'),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    subtitle ??
                        'Join fellow students in mastering their craft with our practice quizzes and smart study planner.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialGlowPainter extends CustomPainter {
  final Color topCenterColor;
  final Color bottomRightColor;

  _RadialGlowPainter({
    required this.topCenterColor,
    required this.bottomRightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintRadial(
      canvas,
      size,
      center: Offset(size.width * 0.5, size.height * 0.25),
      radius: size.width * 0.45,
      color: topCenterColor,
    );

    _paintRadial(
      canvas,
      size,
      center: Offset(size.width * 0.7, size.height * 0.8),
      radius: size.width * 0.55,
      color: bottomRightColor,
    );
  }

  void _paintRadial(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint paint =
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            radius,
            [
              color,
              color.withValues(alpha: 0.10),
              color.withValues(alpha: 0.0),
            ],
            [0.0, 0.45, 1.0],
          );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
