import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:vens_hub/core/di/injection_container.dart';
import 'package:vens_hub/presentation/blocs/course/course_bloc.dart';
import 'package:vens_hub/presentation/blocs/course/course_event.dart';
import 'package:vens_hub/presentation/blocs/course/course_state.dart';
import 'package:vens_hub/core/router/app_router.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/data/models/course_info.dart';
import 'package:vens_hub/presentation/widgets/courses/course_hero.dart';
import 'package:shimmer/shimmer.dart';

class ViewMoreCoursesPage extends StatefulWidget {
  const ViewMoreCoursesPage({super.key});

  @override
  State<ViewMoreCoursesPage> createState() => _ViewMoreCoursesPageState();
}

class _ViewMoreCoursesPageState extends State<ViewMoreCoursesPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedDepartmentCode;
  late CourseBloc _courseBloc;

  static const Map<String, String> _departments = {
    'EEE': 'Electrical Engineering',
    'MEE': 'Mechanical Engineering',
    'MCT': 'Mechatronics Engineering',
    'COE': 'Computer Engineering',
    'CHE': 'Chemical Engineering',
    'BME': 'Biomedical Engineering',
    'AAE': 'Aeronautics Engineering',
    'CVE': 'Civil Engineering',
    'PTE': 'Petroleum Engineering',
  };

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final state = _courseBloc.state;
      if (state is CoursesPageLoaded && state.hasMore && !state.isLoadingMore) {
        _courseBloc.add(
          LoadCoursesPage(
            page: state.currentPage + 1,
            searchQuery:
                _searchController.text.trim().isEmpty
                    ? null
                    : _searchController.text.trim(),
            departmentFilter: _selectedDepartmentCode,
          ),
        );
      }
    }
  }

  void _loadFirstPage() {
    _courseBloc.add(
      LoadCoursesPage(
        page: 1,
        searchQuery:
            _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
        departmentFilter: _selectedDepartmentCode,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search courses...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                      });
                      _loadFirstPage();
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onSubmitted: (_) => _loadFirstPage(),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Builder(
            builder: (context) {
              final theme = Theme.of(context);
              final bool isSelected = _selectedDepartmentCode == null;
              return FilterChip(
                label: Text(
                  'All',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color:
                        isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                  ),
                ),
                selected: isSelected,
                selectedColor: theme.colorScheme.primaryContainer,
                backgroundColor: theme.colorScheme.surface,
                checkmarkColor: theme.colorScheme.onPrimaryContainer,
                side: BorderSide(
                  color:
                      isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedDepartmentCode = null;
                    });
                    _loadFirstPage();
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
          ..._departments.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  final bool isSelected = _selectedDepartmentCode == entry.key;
                  return FilterChip(
                    label: Text(
                      entry.key,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color:
                            isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primaryContainer,
                    backgroundColor: theme.colorScheme.surface,
                    checkmarkColor: theme.colorScheme.onPrimaryContainer,
                    side: BorderSide(
                      color:
                          isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedDepartmentCode = selected ? entry.key : null;
                      });
                      _loadFirstPage();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(CourseInfo course) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(24);

    final card = Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => AppRouter.navigateTo(AppRoutes.coursePage, course),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      course.code,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (course.semester.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${course.semester.join(", ").toLowerCase().capitalizeFirst} Semester',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                course.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (course.description?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(
                  course.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (course.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      course.tags
                          .take(3)
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                tag,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: buildCourseHero(
        course: course,
        child: Material(type: MaterialType.transparency, child: card),
      ),
    );
  }

  Widget _buildShimmerCard() {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Shimmer.fromColors(
                  baseColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  highlightColor: theme.colorScheme.surfaceContainerHighest,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(width: 60, height: 16),
                  ),
                ),
                const Spacer(),
                Shimmer.fromColors(
                  baseColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  highlightColor: theme.colorScheme.surfaceContainerHighest,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(width: 80, height: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Shimmer.fromColors(
              baseColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              highlightColor: theme.colorScheme.surfaceContainerHighest,
              child: Container(
                height: 20,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Shimmer.fromColors(
              baseColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              highlightColor: theme.colorScheme.surfaceContainerHighest,
              child: Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Shimmer.fromColors(
                  baseColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  highlightColor: theme.colorScheme.surfaceContainerHighest,
                  child: Container(
                    width: 50,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Shimmer.fromColors(
                  baseColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  highlightColor: theme.colorScheme.surfaceContainerHighest,
                  child: Container(
                    width: 60,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoadingList() {
    return ListView.builder(
      itemCount: 6, // Show 6 shimmer cards while loading
      itemBuilder: (context, index) {
        return _buildShimmerCard();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'All Courses',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocProvider<CourseBloc>(
        create: (_) {
          final args =
              Get.arguments is Map ? Get.arguments as Map : <String, dynamic>{};
          final String departmentCode =
              (args['departmentCode'] as String?) ?? '';
          _courseBloc = sl<CourseBloc>();
          if (departmentCode.isNotEmpty) {
            _selectedDepartmentCode = departmentCode;
          }
          _courseBloc.add(
            LoadCoursesPage(page: 1, departmentFilter: _selectedDepartmentCode),
          );
          return _courseBloc;
        },
        child: BlocBuilder<CourseBloc, CourseState>(
          builder: (context, state) {
            if (state is CourseLoading) {
              return Column(
                children: [
                  _buildSearchBar(),
                  _buildFilterChips(),
                  const SizedBox(height: 8),
                  Expanded(child: _buildShimmerLoadingList()),
                ],
              );
            }

            if (state is CourseError) {
              return _buildEmptyState('Error: ${state.message}');
            }

            if (state is CoursesPageLoaded) {
              return Column(
                children: [
                  _buildSearchBar(),
                  _buildFilterChips(),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        state.courses.isEmpty
                            ? _buildEmptyState('No courses found')
                            : ListView.builder(
                              controller: _scrollController,
                              itemCount:
                                  state.courses.length +
                                  (state.hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == state.courses.length) {
                                  // Show shimmer loading indicator for pagination
                                  return Column(
                                    children: [
                                      _buildShimmerCard(),
                                      const SizedBox(height: 16),
                                    ],
                                  );
                                }
                                return _buildCourseCard(state.courses[index]);
                              },
                            ),
                  ),
                ],
              );
            }

            return _buildEmptyState('Loading courses...');
          },
        ),
      ),
    );
  }
}
