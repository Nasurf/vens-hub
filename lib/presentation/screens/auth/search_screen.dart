import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vens_hub/core/constants/ui_constants.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart';
import 'package:vens_hub/data/models/course_info.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_bloc.dart';
import 'package:vens_hub/presentation/blocs/quiz/quiz_event.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/routes.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredResults = [];
  bool _isLoading = true;
  String? _errorMessage;

  Timer? _debounce; // Timer for debouncing.
  static const _debounceDuration = Duration(
    milliseconds: 500,
  ); // Debounce duration.
  // Move constant here
  static const int numberOfTags = 3;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(
      _onSearchTextChanged,
    ); // Listen for changes in search text.
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _debounce
        ?.cancel(); // Cancel the timer when the widget is disposed of. Prevents setState on disposed
    super.dispose();
  }

  // Loads data from Firestore using FireStoreServices.
  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load all courses initially (empty search)
      final results = await FireStoreServices.find.searchCoursesAndTopics('');

      setState(() {
        _filteredResults = results;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading data: $error';
      });
    }
  }

  void _onSearchTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(_debounceDuration, () async {
      try {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

        final query = _searchController.text.trim();
        final results = await FireStoreServices.find.searchCoursesAndTopics(
          query,
        );

        setState(() {
          _filteredResults = results;
          _isLoading = false;
        });
      } catch (error) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error searching: $error';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_outlined),
                    onPressed: () {
                      AppRouter.pop();
                    },
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                      ), // Consistent padding.
                      child: TextField(
                        controller: _searchController,
                        enabled: !_isLoading, // Disable input while loading.
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search courses and topics...',
                          hintStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null
                        ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        )
                        : _filteredResults.isNotEmpty
                        ? ListView.builder(
                          itemCount: _filteredResults.length,
                          itemBuilder: (context, index) {
                            return _buildSearchResultItem(
                              context,
                              _filteredResults[index],
                            );
                          },
                        )
                        : const Center(
                          // Improved empty state
                          child: Padding(
                            padding: EdgeInsets.all(
                              16.0,
                            ), // Padding for better visual appearance
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize
                                      .min, //  Column to take only necessary space.
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 60,
                                  color: Colors.grey,
                                ), //  icon for no results
                                SizedBox(height: 16),
                                Text(
                                  'No results found.',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  'Try a different search term.', // Suggestion
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(
    BuildContext context,
    Map<String, dynamic> courseData,
  ) {
    // Filter tags based on the search query
    List<String> filteredTags = [];
    if (_searchController.text.isNotEmpty) {
      final topics = courseData['topics'] as List<dynamic>? ?? [];
      for (var topic in topics) {
        String title = '';
        if (topic is Map<String, dynamic>) {
          title = topic['title'] as String? ?? '';
        } else {
          title = topic.toString();
        }

        if (title.toLowerCase().contains(
          _searchController.text.toLowerCase(),
        )) {
          filteredTags.add(title);
        }
      }
    }

    // Create CourseInfo object from Firestore data
    final courseInfo = CourseInfo(
      id: courseData['id'] ?? '',
      title: courseData['title'] ?? courseData['course'] ?? 'Unknown Course',
      code: courseData['code'] ?? '',
      semester: List<String>.from(
        courseData['semester'] is List
            ? courseData['semester']
            : [courseData['semester'] ?? ''],
      ),
      description: courseData['description'],
      imageUrl: courseData['imageUrl'],
      tags: List<String>.from(courseData['tags'] ?? []),
      topics:
          (courseData['topics'] as List?)
              ?.map((t) => Topic.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      departmentCodes: List<String>.from(
        courseData['department_codes'] ?? courseData['department codes'] ?? [],
      ),
    );

    return GestureDetector(
      onTap: () {
        // Navigate to course page with course data using GetX
        AppRouter.navigateTo(AppRoutes.coursePage, courseInfo);
      },
      child: Padding(
        padding: EdgeInsets.all(AppConstants.cardOuterPadding),
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                courseData['course'] ?? 'Unknown Course',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children:
                    (_searchController.text.isEmpty)
                        ? []
                        : filteredTags
                            .take(numberOfTags) //Moved constant here
                            .map(
                              (topic) => _buildTopicChip(
                                context,
                                topic,
                                courseData["course"] ?? '',
                              ),
                            )
                            .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicChip(BuildContext context, String topic, String course) {
    return GestureDetector(
      onTap: () {
        context.read<QuizBloc>().add(
          UpdateCourseInfo(course: course, choosenTopic: topic),
        );
        AppRouter.navigateTo(AppRoutes.quizCustomization, {
          'course': course,
          'topic': topic,
        });
      },
      child: Chip(
        label: Text(
          topic,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.scrim,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      ),
    );
  }
}
