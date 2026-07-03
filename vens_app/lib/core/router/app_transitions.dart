import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SharedAxisVerticalTransition extends CustomTransition {
  SharedAxisVerticalTransition();

  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedPrimary = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final entrance = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(curvedPrimary);

    final scale = Tween<double>(begin: 0.98, end: 1.0).animate(curvedPrimary);

    return FadeTransition(
      opacity: curvedPrimary,
      child: SlideTransition(
        position: entrance,
        child: ScaleTransition(scale: scale, child: child),
      ),
    );
  }
}
