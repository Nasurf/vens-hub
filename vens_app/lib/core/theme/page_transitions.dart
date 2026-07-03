import 'package:flutter/material.dart';

/// Shared transition used across the app to emulate a subtle fade/scale motion.
class FadeScalePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeScalePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedPrimary = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(curvedPrimary);

    final scaleAnimation = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(curvedPrimary);

    return FadeTransition(
      opacity: curvedPrimary,
      child: SlideTransition(
        position: slideAnimation,
        child: ScaleTransition(scale: scaleAnimation, child: child),
      ),
    );
  }
}

/// Transition used for flows that feel like a vertical continuation (e.g. quiz setup sheets).
class SharedAxisVerticalPageTransitionsBuilder extends PageTransitionsBuilder {
  const SharedAxisVerticalPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedPrimary = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(curvedPrimary);

    final scale = Tween<double>(begin: 0.98, end: 1.0).animate(curvedPrimary);

    return FadeTransition(
      opacity: curvedPrimary,
      child: SlideTransition(
        position: slideUp,
        child: ScaleTransition(scale: scale, child: child),
      ),
    );
  }
}
