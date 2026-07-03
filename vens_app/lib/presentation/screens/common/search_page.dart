import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';
import 'package:vens_hub/core/router/app_router.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/data/models/course_info.dart';
import 'package:vens_hub/domain/repositories/course_repository.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final CourseRepository _courseRepository = CourseRepository();
  List<CourseInfo> _allCourses = [];
  List<CourseInfo> _filteredCourses = [];
  bool _isLoading = true;
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
    });
    final courses = await _courseRepository.getAllCourses();
    setState(() {
      _allCourses = courses;
      _filteredCourses = courses;
      _isLoading = false;
    });
  }

  void _filterCourses(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isEmpty) {
        setState(() {
          _filteredCourses = _allCourses;
        });
        return;
      }
      setState(() {
        _filteredCourses =
            _allCourses
                .where(
                  (course) =>
                      course.title.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      course.code.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          _buildSearchBar(context),
          Expanded(child: _buildSearchResults(context)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search courses, topics, or questions...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon:
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _filterCourses('');
                    },
                  )
                  : null,
        ),
        onChanged: _filterCourses,
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_filteredCourses.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'No courses available.'
              : 'No courses found.',
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredCourses.length,
      itemBuilder: (context, index) {
        final course = _filteredCourses[index];
        return _buildSearchResultItem(context, course);
      },
    );
  }

  Widget _buildSearchResultItem(BuildContext context, CourseInfo course) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          AppRouter.navigateTo(AppRoutes.coursePage, course);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.school, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      course.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Code: ${course.code}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(179),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
