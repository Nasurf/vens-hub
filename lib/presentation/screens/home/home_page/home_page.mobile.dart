import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vens_hub/core/di/injection_container.dart';
import 'package:vens_hub/presentation/blocs/course/course_bloc.dart';
import 'package:vens_hub/presentation/blocs/course/course_event.dart';
import 'package:vens_hub/presentation/blocs/course/course_state.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'dart:async';
import 'package:vens_hub/data/models/course_info.dart';
import 'dart:math' as math;
import 'package:vens_hub/presentation/widgets/courses/course_hero.dart';
// Removed profile avatar menu from home header per UX change

class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _MobileHomePageState extends State<MobileHomePage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final HomeController _homeController = Get.find<HomeController>();
  int _currentCardIndex = 0; // State for the card PageView
  Worker? _userWorker;

  Future<void> _reloadHomeData(BuildContext context) async {
    await _homeController.refreshUserDetails(forceRefresh: true);
    if (!context.mounted) return;
    context.read<CourseBloc>().add(const LoadUserCourses(forceRefresh: true));
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85, initialPage: 0);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOutCubic,
    );
    if (_homeController.currentUser.value == null &&
        !_homeController.isLoading.value) {
      _homeController.refreshUserDetails();
    }

    // Listen for user changes to refresh courses (department/level swap)
    _userWorker = ever(_homeController.currentUser, (user) {
      if (user != null && mounted) {
        log("MobileHomePage: User attributes changed, refreshing courses...");
        context.read<CourseBloc>().add(
          const LoadUserCourses(forceRefresh: true),
        );
      }
    });

    _fadeController.forward();
  }

  @override
  void dispose() {
    _userWorker?.dispose();
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Geist'),
      ),
      child: Builder(
        builder: (context) {
          final ThemeData theme = Theme.of(context);
          final ColorScheme colorScheme = theme.colorScheme;
          final TextTheme textTheme = theme.textTheme;

          return Scaffold(
            backgroundColor: colorScheme.surface,
            body: Obx(() {
              if (_homeController.isLoading.value &&
                  _homeController.currentUser.value == null) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_homeController.currentUser.value == null &&
                  !_homeController.isLoading.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Could not load user data.",
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _homeController.refreshUserDetails(),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                );
              }

              final user = _homeController.currentUser.value;

              return SafeArea(
                child: BlocProvider<CourseBloc>(
                  create: (_) => sl<CourseBloc>()..add(LoadUserCourses()),
                  child: Builder(
                    builder:
                        (blocContext) => RefreshIndicator(
                          onRefresh: () => _reloadHomeData(blocContext),
                          triggerMode: RefreshIndicatorTriggerMode.anywhere,
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            slivers: [
                              SliverPadding(
                                padding: const EdgeInsets.only(
                                  left: 24.0,
                                  right: 24.0,
                                  top: 24.0,
                                  bottom: 16.0,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            StreamBuilder<DateTime>(
                                              stream: Stream<DateTime>.periodic(
                                                const Duration(minutes: 1),
                                                (_) => DateTime.now(),
                                              ),
                                              initialData: DateTime.now(),
                                              builder: (context, snapshot) {
                                                return Obx(() {
                                                  final bool completedToday =
                                                      _homeController
                                                          .hasCompletedToday
                                                          .value;
                                                  final int streak =
                                                      _homeController
                                                          .streakCount
                                                          .value;
                                                  final DateTime now =
                                                      snapshot.data ??
                                                      DateTime.now();
                                                  final bool isAfterTenPm =
                                                      now.hour >= 22;
                                                  final bool showDanger =
                                                      !completedToday &&
                                                      isAfterTenPm;

                                                  final Color accent =
                                                      showDanger
                                                          ? Colors.red
                                                          : (completedToday
                                                              ? colorScheme
                                                                  .primary
                                                              : colorScheme
                                                                  .outline);
                                                  final String label =
                                                      '$streak';
                                                  Widget
                                                  streakWidget = GestureDetector(
                                                    behavior:
                                                        HitTestBehavior.opaque,
                                                    onTap:
                                                        () => Get.toNamed(
                                                          AppRoutes.streaks,
                                                        ),
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        _buildHeaderIconText(
                                                          context,
                                                          Icons
                                                              .local_fire_department_rounded,
                                                          label,
                                                          accent,
                                                        ),
                                                        if (showDanger)
                                                          Positioned(
                                                            left: -6,
                                                            bottom: -6,
                                                            child: Container(
                                                              width: 28,
                                                              height: 28,
                                                              alignment:
                                                                  Alignment
                                                                      .center,
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .red
                                                                    .withValues(
                                                                      alpha:
                                                                          0.9,
                                                                    ),
                                                                shape:
                                                                    BoxShape
                                                                        .circle,
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color: Colors
                                                                        .red
                                                                        .withValues(
                                                                          alpha:
                                                                              0.4,
                                                                        ),
                                                                    blurRadius:
                                                                        6,
                                                                    offset:
                                                                        const Offset(
                                                                          0,
                                                                          2,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                              child: Transform.translate(
                                                                // Fine-tune nudge to visually center the glyph
                                                                offset: Offset(
                                                                  0.45,
                                                                  -0.25,
                                                                ),
                                                                child: Icon(
                                                                  Icons
                                                                      .warning_amber_rounded,
                                                                  size: 18,
                                                                  color:
                                                                      Colors
                                                                          .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  );

                                                  return showDanger
                                                      ? Tooltip(
                                                        message:
                                                            'Do your streak',
                                                        child: streakWidget,
                                                      )
                                                      : streakWidget;
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 36),
                                        GestureDetector(
                                          child: Text(
                                            "Welcome, ${user?.firstName ?? 'User'}",
                                            style: textTheme.displayMedium
                                                ?.copyWith(
                                                  color: colorScheme.onSurface,
                                                  letterSpacing: -0.5,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          user?.department != null &&
                                                  user?.level != null
                                              ? "${user!.department} - Level ${user.level}"
                                              : "Explore your learning journey",
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                color:
                                                    colorScheme
                                                        .onSurfaceVariant,
                                                letterSpacing: 0.2,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                    vertical: 20.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Your Courses",
                                        style: textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // ===============================================
                              // MODIFIED BlocBuilder LOGIC
                              // ===============================================
                              BlocBuilder<CourseBloc, CourseState>(
                                builder: (context, courseState) {
                                  // 1. Handle loading and initial states first.
                                  if (courseState is CourseLoading ||
                                      courseState is CourseInitial) {
                                    // Skeleton: card placeholders to improve perceived speed
                                    return SliverToBoxAdapter(
                                      child: SizedBox(
                                        height: 350,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 24,
                                          ),
                                          itemCount: 3,
                                          itemBuilder: (context, index) {
                                            return Container(
                                              width:
                                                  MediaQuery.of(
                                                    context,
                                                  ).size.width *
                                                  0.8,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    colorScheme
                                                        .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                                border: Border.all(
                                                  color: colorScheme
                                                      .outlineVariant
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  32,
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      width: 80,
                                                      height: 14,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            colorScheme
                                                                .surfaceContainerLow,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    Container(
                                                      width: double.infinity,
                                                      height: 22,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            colorScheme
                                                                .surfaceContainerLow,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Container(
                                                      width:
                                                          MediaQuery.of(
                                                            context,
                                                          ).size.width *
                                                          0.5,
                                                      height: 22,
                                                      decoration: BoxDecoration(
                                                        color:
                                                            colorScheme
                                                                .surfaceContainerLow,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    Align(
                                                      alignment:
                                                          Alignment.bottomRight,
                                                      child: Container(
                                                        width: 24,
                                                        height: 24,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              colorScheme
                                                                  .surfaceContainerLow,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  }

                                  // 2. Handle the error state.
                                  if (courseState is CourseError) {
                                    return SliverFillRemaining(
                                      child: Center(
                                        child: Text(courseState.message),
                                      ),
                                    );
                                  }

                                  // 3. Handle the success state. It's now SAFE to access `courses`.
                                  if (courseState is UserCoursesLoaded) {
                                    final courses = courseState.courses;

                                    if (courses.isEmpty) {
                                      return SliverFillRemaining(
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20.0),
                                            child: Text(
                                              "No courses assigned to you yet.",
                                              style: textTheme.titleMedium
                                                  ?.copyWith(
                                                    color:
                                                        colorScheme
                                                            .onSurfaceVariant,
                                                  ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    // If we have courses, build the PageView.

                                    return SliverToBoxAdapter(
                                      child: SizedBox(
                                        height:
                                            350, // Increased height for longer cards
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            PageView.builder(
                                              controller: _pageController,
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              scrollDirection: Axis.horizontal,
                                              itemCount: courses.length,
                                              onPageChanged:
                                                  (index) => setState(
                                                    () =>
                                                        _currentCardIndex =
                                                            index,
                                                  ),
                                              itemBuilder: (context, index) {
                                                final course = courses[index];
                                                return GestureDetector(
                                                  onTap:
                                                      () => Get.toNamed(
                                                        AppRoutes.coursePage,
                                                        arguments: course,
                                                      ),
                                                  child: AnimatedTopicCard(
                                                    course: course,
                                                    isActive:
                                                        index ==
                                                        _currentCardIndex,
                                                  ),
                                                );
                                              },
                                            ),
                                            // Positioned.fill(
                                            //   child: Align(
                                            //     alignment: Alignment.centerRight,
                                            //     child: IgnorePointer(
                                            //       ignoring: !showJumpToFirstButton,
                                            //       child: AnimatedOpacity(
                                            //         opacity:
                                            //             showJumpToFirstButton ? 1 : 0,
                                            //         duration: const Duration(
                                            //           milliseconds: 200,
                                            //         ),
                                            //         child: AnimatedSlide(
                                            //           offset: showJumpToFirstButton
                                            //               ? Offset.zero
                                            //               : const Offset(0.1, 0),
                                            //           duration: const Duration(
                                            //             milliseconds: 200,
                                            //           ),
                                            //           curve: Curves.easeOut,
                                            //           child: Padding(
                                            //             padding:
                                            //                 const EdgeInsets.only(
                                            //               right: 12,
                                            //             ),
                                            //             child: GestureDetector(
                                            //               onTap: () {
                                            //                 _pageController
                                            //                     .animateToPage(
                                            //                   0,
                                            //                   duration:
                                            //                       const Duration(
                                            //                     milliseconds: 400,
                                            //                   ),
                                            //                   curve:
                                            //                       Curves.easeOutCubic,
                                            //                 );
                                            //               },
                                            //               child: Container(
                                            //                 decoration: BoxDecoration(
                                            //                   shape: BoxShape.circle,
                                            //                   color: colorScheme.primary
                                            //                       .withValues(
                                            //                           alpha: 0.9),
                                            //                   boxShadow: [
                                            //                     BoxShadow(
                                            //                       color: colorScheme
                                            //                           .primary
                                            //                           .withValues(
                                            //                               alpha: 0.25),
                                            //                       blurRadius: 12,
                                            //                       offset: const Offset(
                                            //                         0,
                                            //                         4,
                                            //                       ),
                                            //                     ),
                                            //                   ],
                                            //                 ),
                                            //                 padding: const EdgeInsets.all(
                                            //                   12,
                                            //                 ),
                                            //                 child: Icon(
                                            //                   Icons
                                            //                       .arrow_back_ios_new_rounded,
                                            //                   color:
                                            //                       colorScheme.onPrimary,
                                            //                 ),
                                            //               ),
                                            //             ),
                                            //           ),
                                            //         ),
                                            //       ),
                                            //     ),
                                            //   ),
                                            // ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  // Fallback for any other unhandled state.
                                  return const SliverToBoxAdapter(
                                    child: SizedBox.shrink(),
                                  );
                                },
                              ),
                              // View More Button at the bottom (always visible)
                              BlocBuilder<CourseBloc, CourseState>(
                                builder: (context, courseState) {
                                  return SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Column(
                                      children: [
                                        const Spacer(),
                                        Padding(
                                          padding: const EdgeInsets.all(24.0),
                                          child: SizedBox(
                                            width: double.infinity,
                                            height: 56,
                                            child: ElevatedButton(
                                              onPressed:
                                                  () => Get.toNamed(
                                                    AppRoutes.courses,
                                                    arguments: {
                                                      'departmentCode':
                                                          _homeController
                                                              .currentUser
                                                              .value
                                                              ?.department ??
                                                          '',
                                                    },
                                                  ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    colorScheme.primary,
                                                foregroundColor:
                                                    colorScheme.onPrimary,
                                                elevation: 2,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                              ),
                                              child: Text(
                                                "View More Courses",
                                                style: textTheme.titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          colorScheme.onPrimary,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildHeaderIconText(
    BuildContext context,
    IconData icon,
    String label,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color baseAccent = accentColor;
    final effectiveBgColor =
        isDark
            ? Color.alphaBlend(
              baseAccent.withValues(alpha: 0.15),
              theme.colorScheme.surfaceContainerHighest,
            )
            : Color.alphaBlend(baseAccent.withValues(alpha: 0.1), Colors.white);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: baseAccent.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: baseAccent.withValues(alpha: isDark ? 0.2 : 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: baseAccent, size: 24),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: baseAccent,
              fontSize: 20,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedTopicCard extends StatefulWidget {
  final CourseInfo course;
  final bool isActive;

  const AnimatedTopicCard({
    super.key,
    required this.course,
    required this.isActive,
  });

  @override
  State<AnimatedTopicCard> createState() => _AnimatedTopicCardState();
}

class _AnimatedTopicCardState extends State<AnimatedTopicCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late AnimationController _meshController;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();

    // Scale animation with better performance
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.95, // Less dramatic scale for better performance
      upperBound: 1.0,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic, // Smoother curve
    );

    // Mesh animation with adaptive duration
    _meshController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.isActive ? 12000 : 20000, // Slower when inactive
      ),
    );

    // Start animations based on initial state
    if (widget.isActive) {
      _scaleController.forward();
      _startMeshAnimation();
    } else {
      _startMeshAnimation(); // Always start mesh, but slower
    }
  }

  void _startMeshAnimation() {
    if (!_isDisposed && mounted) {
      _meshController.repeat();
    }
  }

  void _stopMeshAnimation() {
    if (!_isDisposed && _meshController.isAnimating) {
      _meshController.stop();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedTopicCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _scaleController.forward();
        // Speed up mesh animation when active
        _meshController.duration = const Duration(milliseconds: 12000);
        if (!_meshController.isAnimating) _startMeshAnimation();
      } else {
        _scaleController.reverse();
        // Slow down mesh animation when inactive
        _meshController.duration = const Duration(milliseconds: 20000);
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopMeshAnimation();
    _scaleController.dispose();
    _meshController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cardBackgroundColor = colorScheme.surfaceContainerHighest;

    final heroSurface = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: cardBackgroundColor,
              child: CustomPaint(
                painter: EnhancedMeshPainter(
                  animation: _meshController,
                  meshColor: colorScheme.primary.withValues(alpha: 0.08),
                  isActive: widget.isActive,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(
                    alpha: widget.isActive ? 0.15 : 0.05,
                  ),
                  blurRadius: widget.isActive ? 12 : 6,
                  offset: Offset(0, widget.isActive ? 6 : 3),
                ),
              ],
              border: Border.all(
                color:
                    widget.isActive
                        ? colorScheme.primary.withValues(alpha: 0.7)
                        : colorScheme.outline.withValues(alpha: 0.3),
                width: widget.isActive ? 2.0 : 1.0,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.course.code,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    textScaler: TextScaler.linear(0.9),
                    softWrap: true,
                    widget.course.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color:
                        widget.isActive
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        height: 290,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
        child: buildCourseHero(
          course: widget.course,
          child: Material(color: Colors.transparent, child: heroSurface),
        ),
      ),
    );
  }
}

class EnhancedMeshPainter extends CustomPainter {
  final Animation<double> animation;
  final Color meshColor;
  final bool isActive;

  // Cache for expensive calculations
  static final Map<String, Path> _pathCache = {};
  static int _cacheCleanupCounter = 0;

  EnhancedMeshPainter({
    required this.animation,
    required this.meshColor,
    required this.isActive,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // Prevent rendering if size is invalid
    if (size.width <= 0 || size.height <= 0) return;

    // Limit animation value to prevent overflow
    final double clampedAnimation = animation.value.clamp(0.0, 1.0);

    // Performance optimization: reduce complexity based on device capabilities
    final bool isHighPerformance =
        size.width * size.height < 200000; // Rough performance threshold

    // Configure paints with proper settings for performance
    final paint =
        Paint()
          ..color = meshColor
          ..strokeWidth = isActive ? 1.5 : 1.0
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round; // Smoother line endings

    final activePaint =
        Paint()
          ..color = meshColor.withValues(alpha: isActive ? 0.25 : 0.08)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true
          ..strokeCap = StrokeCap.round;

    // Optimized spacing calculations
    final double baseSpacing = math.max(
      25.0,
      size.width / 12,
    ); // Responsive spacing
    final double maxLines = (size.width + size.height) / baseSpacing;

    // Prevent excessive line drawing
    if (maxLines > 50) {
      _drawSimplifiedMesh(canvas, size, paint, clampedAnimation, baseSpacing);
      return;
    }

    // Smooth wave calculations with performance bounds
    final double waveOffset =
        math.sin(clampedAnimation * 2 * math.pi) *
        math.min(8.0, size.width * 0.02); // Scale wave with card size
    final double flowOffset = clampedAnimation * baseSpacing * 1.5;

    // Use clipRect to prevent overdraw
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Draw primary diagonal mesh with bounds checking
    _drawDiagonalLines(
      canvas,
      size,
      paint,
      activePaint,
      baseSpacing,
      flowOffset,
      waveOffset,
      isHighPerformance,
    );

    // Enhanced effects for active cards only
    if (isActive && isHighPerformance) {
      _drawActiveEffects(
        canvas,
        size,
        activePaint,
        clampedAnimation,
        baseSpacing,
      );
    }

    // Cleanup cache periodically to prevent memory leaks
    _cacheCleanupCounter++;
    if (_cacheCleanupCounter > 100) {
      _pathCache.clear();
      _cacheCleanupCounter = 0;
    }
  }

  void _drawDiagonalLines(
    Canvas canvas,
    Size size,
    Paint paint,
    Paint activePaint,
    double baseSpacing,
    double flowOffset,
    double waveOffset,
    bool isHighPerformance,
  ) {
    // Calculate bounds to prevent unnecessary drawing
    final double startBound = -size.height - baseSpacing;
    final double endBound = size.width + size.height + baseSpacing;

    // Forward diagonal lines
    for (double i = startBound; i < endBound; i += baseSpacing) {
      final double startX = i + flowOffset + waveOffset;
      final double endX = startX + size.height;

      // Skip lines completely outside the visible area
      if (endX < 0 || startX > size.width) continue;

      // Primary line
      canvas.drawLine(Offset(startX, 0), Offset(endX, size.height), paint);

      // Secondary lines for active state (reduced frequency)
      if (isActive && isHighPerformance && (i / baseSpacing) % 2 == 0) {
        final double secondaryStartX = startX + baseSpacing * 0.4;
        final double secondaryEndX = secondaryStartX + size.height;

        if (secondaryEndX >= 0 && secondaryStartX <= size.width) {
          canvas.drawLine(
            Offset(secondaryStartX, 0),
            Offset(secondaryEndX, size.height),
            activePaint,
          );
        }
      }
    }

    // Reverse diagonal lines with similar optimizations
    for (double i = endBound; i > startBound; i -= baseSpacing) {
      final double startX = i - flowOffset - waveOffset;
      final double endX = startX - size.height;

      if (startX < 0 || endX > size.width) continue;

      canvas.drawLine(Offset(startX, 0), Offset(endX, size.height), paint);
    }
  }

  void _drawActiveEffects(
    Canvas canvas,
    Size size,
    Paint activePaint,
    double clampedAnimation,
    double baseSpacing,
  ) {
    // Limit wave complexity based on card size
    final int wavePoints = math.min(20, (size.width / 15).round());
    final double waveSpacing = baseSpacing * 2;

    // Create flowing horizontal waves

    for (
      double y = waveSpacing;
      y < size.height - waveSpacing;
      y += waveSpacing
    ) {
      final path = Path();
      path.moveTo(0, y);

      // Optimize wave generation
      final double stepSize = size.width / wavePoints;
      for (int i = 0; i <= wavePoints; i++) {
        final double x = i * stepSize;
        final double waveY =
            y +
            math.sin((x / 25) + (clampedAnimation * 3 * math.pi)) *
                math.min(4.0, size.height * 0.015);
        path.lineTo(x, waveY);
      }

      canvas.drawPath(path, activePaint);
    }

    // Add subtle pulsing intersection points
    _drawIntersectionPoints(
      canvas,
      size,
      activePaint,
      clampedAnimation,
      baseSpacing,
    );
  }

  void _drawIntersectionPoints(
    Canvas canvas,
    Size size,
    Paint activePaint,
    double clampedAnimation,
    double baseSpacing,
  ) {
    final double pulseRadius =
        1.5 + math.sin(clampedAnimation * 4 * math.pi) * 0.5;
    final Paint pointPaint =
        Paint()
          ..color = activePaint.color.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;

    // Draw intersection points at strategic locations
    for (double x = baseSpacing; x < size.width; x += baseSpacing * 2) {
      for (double y = baseSpacing; y < size.height; y += baseSpacing * 2) {
        // Add some randomness to prevent perfect grid
        final double offsetX =
            math.sin(x / 30 + clampedAnimation * 2 * math.pi) * 3;
        final double offsetY =
            math.cos(y / 30 + clampedAnimation * 2 * math.pi) * 3;

        canvas.drawCircle(
          Offset(x + offsetX, y + offsetY),
          pulseRadius,
          pointPaint,
        );
      }
    }
  }

  void _drawSimplifiedMesh(
    Canvas canvas,
    Size size,
    Paint paint,
    double clampedAnimation,
    double baseSpacing,
  ) {
    // Fallback simplified mesh for low-performance scenarios
    final double largeSpacing = baseSpacing * 2;
    final double flowOffset = clampedAnimation * largeSpacing;

    // Minimal diagonal lines
    for (
      double i = -size.height;
      i < size.width + size.height;
      i += largeSpacing
    ) {
      final double startX = i + flowOffset;
      final double endX = startX + size.height;

      if (endX >= 0 && startX <= size.width) {
        canvas.drawLine(Offset(startX, 0), Offset(endX, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EnhancedMeshPainter oldDelegate) {
    // Optimize repainting by comparing key properties
    return oldDelegate.animation.value != animation.value ||
        oldDelegate.isActive != isActive ||
        oldDelegate.meshColor != meshColor;
  }

  @override
  bool hitTest(Offset position) => false; // Disable hit testing for performance
}
