import 'package:equatable/equatable.dart';
import 'package:vens_hub/data/models/course_info.dart';

abstract class CourseEvent extends Equatable {
  const CourseEvent();
  @override
  List<Object?> get props => [];
}

class LoadUserCourses extends CourseEvent {
  final bool forceRefresh;
  const LoadUserCourses({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class LoadAllCourses extends CourseEvent {
  final bool forceRefresh;
  const LoadAllCourses({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class LoadCoursesPage extends CourseEvent {
  final int page;
  final int limit;
  final String? searchQuery;
  final String? departmentFilter;
  final bool forceRefresh;

  const LoadCoursesPage({
    required this.page,
    this.limit = 20,
    this.searchQuery,
    this.departmentFilter,
    this.forceRefresh = false,
  });

  @override
  List<Object?> get props => [
    page,
    limit,
    searchQuery,
    departmentFilter,
    forceRefresh,
  ];
}

class LoadDepartmentCourses extends CourseEvent {
  final String departmentCode;
  const LoadDepartmentCourses(this.departmentCode);

  @override
  List<Object?> get props => [departmentCode];
}

class SearchAndFilterCourses extends CourseEvent {
  final String searchQuery;
  final String? departmentFilter;
  final List<CourseInfo> allCourses;

  const SearchAndFilterCourses({
    required this.searchQuery,
    this.departmentFilter,
    required this.allCourses,
  });

  @override
  List<Object?> get props => [searchQuery, departmentFilter, allCourses];
}
