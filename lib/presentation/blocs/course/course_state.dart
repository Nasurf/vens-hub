import 'package:equatable/equatable.dart';
import 'package:vens_hub/data/models/course_info.dart';

abstract class CourseState extends Equatable {
  const CourseState();
  @override
  List<Object?> get props => [];
}

class CourseInitial extends CourseState {}

class CourseLoading extends CourseState {}

class UserCoursesLoaded extends CourseState {
  final List<CourseInfo> courses;
  const UserCoursesLoaded(this.courses);
  @override
  List<Object?> get props => [courses];
}

class AllCoursesLoaded extends CourseState {
  final List<CourseInfo> courses;
  const AllCoursesLoaded(this.courses);
  @override
  List<Object?> get props => [courses];
}

class CoursesPageLoaded extends CourseState {
  final List<CourseInfo> courses;
  final bool hasMore;
  final int currentPage;
  final bool isLoadingMore;

  const CoursesPageLoaded({
    required this.courses,
    required this.hasMore,
    required this.currentPage,
    this.isLoadingMore = false,
  });

  @override
  List<Object?> get props => [courses, hasMore, currentPage, isLoadingMore];

  CoursesPageLoaded copyWith({
    List<CourseInfo>? courses,
    bool? hasMore,
    int? currentPage,
    bool? isLoadingMore,
  }) {
    return CoursesPageLoaded(
      courses: courses ?? this.courses,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class DepartmentCoursesLoaded extends CourseState {
  final String departmentCode;
  final Map<String, List<CourseInfo>> coursesByLevel;

  const DepartmentCoursesLoaded({
    required this.departmentCode,
    required this.coursesByLevel,
  });

  @override
  List<Object?> get props => [departmentCode, coursesByLevel];
}

class CourseError extends CourseState {
  final String message;
  const CourseError(this.message);
  @override
  List<Object?> get props => [message];
}

class FilteredCoursesLoaded extends CourseState {
  final List<CourseInfo> courses;
  final String? departmentFilter;
  final String searchQuery;
  const FilteredCoursesLoaded({
    required this.courses,
    required this.searchQuery,
    this.departmentFilter,
  });
  @override
  List<Object?> get props => [courses, departmentFilter, searchQuery];
}
