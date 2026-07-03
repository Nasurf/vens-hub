import 'package:flutter/material.dart';

/// A responsive layout builder that selects a widget based on screen width.
///
/// It simplifies building responsive UIs by providing specific widgets for
/// mobile, tablet, and desktop layouts. If a tablet widget is not provided,
/// it falls back to the desktop widget for tablet sizes.
///
/// Breakpoints:
/// - **Mobile**: < 768 pixels
/// - **Tablet**: >= 768 pixels
/// - **Desktop**: >= 1100 pixels
class AppLayoutBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const AppLayoutBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  // Standard breakpoints for responsive design.
  // Adjusted to ensure desktop layout (with sidebar) shows on slightly narrower screens.
  static const double _tabletBreakpoint = 768.0;
  static const double _desktopBreakpoint = 1000.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _desktopBreakpoint) {
          return desktop;
        }
        if (constraints.maxWidth >= _tabletBreakpoint) {
          return tablet ?? desktop;
        }
        return mobile;
      },
    );
  }
}
