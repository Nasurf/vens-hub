import 'package:flutter/material.dart';

class HoverEffect extends StatefulWidget {
  final Widget child;
  final Color? hoverColor;
  final double hoverElevation;
  final double normalElevation;
  final Duration duration;
  final Curve curve;
  final BorderRadius? borderRadius;

  const HoverEffect({
    super.key,
    required this.child,
    this.hoverColor,
    this.hoverElevation = 12.0,
    this.normalElevation = 4.0,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeInOut,
    this.borderRadius,
  });

  @override
  State<HoverEffect> createState() => _HoverEffectState();
}

class _HoverEffectState extends State<HoverEffect>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _elevationAnimation = Tween<double>(
      begin: widget.normalElevation,
      end: widget.hoverElevation,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: widget.curve),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _animationController, curve: widget.curve),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });

    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: _elevationAnimation.value,
                    offset: Offset(0, _elevationAnimation.value / 2),
                    spreadRadius: _isHovered ? 1 : 0,
                  ),
                  if (_isHovered)
                    BoxShadow(
                      color: const Color(0xFF34D399).withValues(alpha: 0.2),
                      blurRadius: _elevationAnimation.value * 1.5,
                      offset: Offset(0, _elevationAnimation.value / 1.5),
                    ),
                ],
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

// Extension for easier use
extension HoverExtension on Widget {
  Widget withHoverEffect({
    Color? hoverColor,
    double hoverElevation = 12.0,
    double normalElevation = 4.0,
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.easeInOut,
    BorderRadius? borderRadius,
  }) {
    return HoverEffect(
      hoverColor: hoverColor,
      hoverElevation: hoverElevation,
      normalElevation: normalElevation,
      duration: duration,
      curve: curve,
      borderRadius: borderRadius,
      child: this,
    );
  }
}

// Gradient button that matches the HTML design
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final List<Color> gradientColors;
  final Color textColor;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.borderRadius = 8.0,
    this.gradientColors = const [Color(0xFF2DD4BF), Color(0xFF34D399)],
    this.textColor = const Color(0xFF111827),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onPressed,
          child: Container(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: textColor, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Search bar component that matches the HTML design
class ModernSearchBar extends StatelessWidget {
  final String hintText;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final double width;

  const ModernSearchBar({
    super.key,
    this.hintText = "Search courses...",
    this.onTap,
    this.onChanged,
    this.readOnly = false,
    this.width = 280,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF374151), // gray-700
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        readOnly: readOnly,
        onTap: onTap,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
