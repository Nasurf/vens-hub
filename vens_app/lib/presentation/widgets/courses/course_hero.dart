import 'dart:ui' show lerpDouble;

import 'package:vens_hub/data/models/course_info.dart';
import 'package:flutter/material.dart';

String courseHeroTag(CourseInfo course) =>
    'course-card-${course.id.isNotEmpty ? course.id : (course.code.isNotEmpty ? course.code : course.hashCode)}';

Hero buildCourseHero({required CourseInfo course, required Widget child}) {
  return Hero(
    tag: courseHeroTag(course),
    createRectTween:
        (begin, end) => MaterialRectCenterArcTween(begin: begin, end: end),
    flightShuttleBuilder: _courseFlightShuttleBuilder,
    child: child,
  );
}

Widget _courseFlightShuttleBuilder(
  BuildContext context,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final Widget target =
      flightDirection == HeroFlightDirection.push
          ? toHeroContext.widget
          : fromHeroContext.widget;

  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final double t = Curves.easeOutCubic.transform(animation.value);
      final double scale = lerpDouble(0.92, 1.0, t) ?? 1.0;
      final double opacity = lerpDouble(0.35, 1.0, t) ?? 1.0;
      return Opacity(
        opacity: opacity,
        child: Transform.scale(scale: scale, child: child),
      );
    },
    child: target,
  );
}
