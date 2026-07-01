import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Assuming these imports are correct for your project structure
import 'package:vens_hub/core/router/app_router.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/data/models/course_info.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_bloc.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_event.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';
import 'package:vens_hub/presentation/widgets/courses/course_hero.dart';

class CoursePage extends StatefulWidget {
  final CourseInfo course;
  const CoursePage({super.key, required this.course});

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController;

  static const double _titleFadeStart = 40.0;
  static const double _titleFadeEnd = 120.0;
  static const double _descriptionFadeStart = 80.0;
  static const double _descriptionFadeEnd = 150.0;
  static const double _statsFadeStart = 110.0;
  static const double _statsFadeEnd = 190.0;

  double _titleOpacity = 1.0;
  double _descriptionOpacity = 1.0;
  double _statsOpacity = 1.0;

  late CourseInfo _course;
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    _course = widget.course;
    _tabController = TabController(length: 2, vsync: this);
    _scrollController = ScrollController()..addListener(_handleScrollOpacity);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Start fade animation after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _fadeController.forward();
    });

    // After first frame, hydrate course topics if missing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateCourseIfNeeded();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _scrollController.removeListener(_handleScrollOpacity);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScrollOpacity() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;

    double nextTitle = _calculateOpacity(
      offset,
      _titleFadeStart,
      _titleFadeEnd,
    );
    double nextDescription = _calculateOpacity(
      offset,
      _descriptionFadeStart,
      _descriptionFadeEnd,
    );
    double nextStats = _calculateOpacity(
      offset,
      _statsFadeStart,
      _statsFadeEnd,
    );

    if ((nextTitle - _titleOpacity).abs() > 0.01 ||
        (nextDescription - _descriptionOpacity).abs() > 0.01 ||
        (nextStats - _statsOpacity).abs() > 0.01) {
      setState(() {
        _titleOpacity = nextTitle;
        _descriptionOpacity = nextDescription;
        _statsOpacity = nextStats;
      });
    }
  }

  double _calculateOpacity(double offset, double start, double end) {
    if (offset <= start) return 1.0;
    if (offset >= end) return 0.0;
    final progress = (offset - start) / (end - start);
    return (1.0 - progress).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return <Widget>[
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: _buildSliverAppBar(context, innerBoxIsScrolled),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTabContent(
              child: _buildOverviewTab(context),
              storageKey: 'course_overview',
            ),
            _buildTabContent(
              child: _buildTopicsTab(context),
              storageKey: 'course_topics',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _hydrateCourseIfNeeded() async {
    if (_course.topics.isNotEmpty) return;
    setState(() => _hydrating = true);
    try {
      final CourseInfo? hydrated = await FireStoreServices.find
          .getCourseByTitle(_course.title);
      if (mounted && hydrated != null) {
        setState(() => _course = hydrated);
      }
    } finally {
      if (mounted) setState(() => _hydrating = false);
    }
  }

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    bool innerBoxIsScrolled,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SliverAppBar(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      floating: false,
      snap: false,
      expandedHeight: 520.0,
      forceElevated: innerBoxIsScrolled,
      elevation: innerBoxIsScrolled ? 1 : 0,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () {
          HapticFeedback.lightImpact();
          AppRouter.pop();
        },
      ),

      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        background: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildExpandedHeader(context),
        ),
      ),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: colorScheme.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        labelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [Tab(text: "OVERVIEW"), Tab(text: "TOPICS")],
      ),
    );
  }

  Widget _buildExpandedHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const double maxContentWidth = 880;

    final headerContent = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary,
                colorScheme.primary.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.school_rounded,
            size: 40,
            color: colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: 20),
        AnimatedOpacity(
          opacity: _titleOpacity,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: _titleOpacity < 0.05,
            child: Text(
              _course.title,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedOpacity(
          opacity: _descriptionOpacity,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: _descriptionOpacity < 0.05,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                _course.description ??
                    'A collection of topics to expand your knowledge.',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        AnimatedOpacity(
          opacity: _statsOpacity,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: IgnorePointer(
            ignoring: _statsOpacity < 0.05,
            child: _buildCourseStatsCard(context),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surface.withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: kTextTabBarHeight + 24,
          top: 60,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: buildCourseHero(
              course: _course,
              child: Material(
                type: MaterialType.transparency,
                child: headerContent,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    FaIconData icon,
    String count,
    String label,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          count,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent({required Widget child, required String storageKey}) {
    return Builder(
      builder: (context) {
        return CustomScrollView(
          key: PageStorageKey<String>(storageKey),
          slivers: <Widget>[
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            child,
          ],
        );
      },
    );
  }

  Widget _buildOverviewTab(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const double maxContentWidth = 880;
    return SliverPadding(
      padding: const EdgeInsets.all(24.0),
      sliver: SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOverviewCard(
                  context,
                  'What You\'ll Learn',
                  Icons.lightbulb_outline_rounded,
                  _course.description ?? 'No description available.',
                ),
                const SizedBox(height: 16),
                _buildOverviewCard(
                  context,
                  'Prerequisites',
                  Icons.checklist_rounded,
                  'No prior experience required. Just curiosity and a willingness to learn.',
                ),
                const SizedBox(height: 16),
                _buildOverviewCard(
                  context,
                  'Course Format',
                  Icons.play_circle_outline_rounded,
                  'Interactive lessons with hands-on practice exercises and immediate feedback.',
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _tabController.animateTo(1);
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Learning'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 2,
                      shadowColor: colorScheme.primary.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseStatsCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatItem(
              context,
              FontAwesomeIcons.bookOpen,
              _hydrating ? '—' : '${_course.topics.length}',
              'Topics',
            ),
            VerticalDivider(
              color: colorScheme.outline.withValues(alpha: 0.3),
              thickness: 1,
              width: 40,
            ),
            _buildStatItem(
              context,
              FontAwesomeIcons.dumbbell,
              '150',
              'Practice',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    BuildContext context,
    String title,
    IconData icon,
    String content,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicsTab(BuildContext context) {
    final topics = _course.topics;
    if (topics.isEmpty) {
      if (_hydrating) {
        return SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  'Loading topics…',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.topic_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No topics available.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              _buildTopicItem(context, _course.title, topics[index]),
          childCount: topics.length,
        ),
      ),
    );
  }

  Widget _buildTopicItem(
    BuildContext context,
    String courseTitle,
    Topic topic,
  ) {
    final String topicTitle = topic.title;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    const double maxContentWidth = 880;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContentWidth),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Hero(
            tag: 'topic-$courseTitle-$topicTitle',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.read<QuizBloc>().add(
                    UpdateCourseInfo(
                      course: courseTitle,
                      choosenTopic: topicTitle,
                    ),
                  );
                  AppRouter.navigateTo(AppRoutes.quizCustomization);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.1),
                              colorScheme.primary.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 24,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topicTitle,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to start quiz',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
