import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vens_hub/domain/course/usecases/get_all_courses_usecase.dart';
import 'package:vens_hub/domain/course/usecases/get_user_courses_usecase.dart';
import 'package:vens_hub/data/models/course_info.dart';
import 'course_event.dart';
import 'course_state.dart';

class CourseBloc extends Bloc<CourseEvent, CourseState> {
  final GetUserCoursesUseCase getUserCoursesUseCase;
  final GetAllCoursesUseCase getAllCoursesUseCase;
  final GetDepartmentCoursesUseCase? getDepartmentCoursesUseCase;

  CourseBloc({
    required this.getUserCoursesUseCase,
    required this.getAllCoursesUseCase,
    this.getDepartmentCoursesUseCase,
  }) : super(CourseInitial()) {
    on<LoadUserCourses>(_onLoadUserCourses);
    on<LoadAllCourses>(_onLoadAllCourses);
    on<LoadCoursesPage>(_onLoadCoursesPage);
    on<LoadDepartmentCourses>(_onLoadDepartmentCourses);
    on<SearchAndFilterCourses>(_onSearchAndFilterCourses);
  }

  Future<void> _onLoadUserCourses(
    LoadUserCourses event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    final failureOrCourses = await getUserCoursesUseCase(
      CourseCacheParams(forceRefresh: event.forceRefresh),
    );
    failureOrCourses.fold(
      (failure) => emit(CourseError(failure.message)),
      (courses) => emit(UserCoursesLoaded(courses)),
    );
  }

  Future<void> _onLoadCoursesPage(
    LoadCoursesPage event,
    Emitter<CourseState> emit,
  ) async {
    if (event.page == 1) {
      emit(CourseLoading());
    } else if (state is CoursesPageLoaded) {
      emit((state as CoursesPageLoaded).copyWith(isLoadingMore: true));
    }

    final failureOrCourses = await getAllCoursesUseCase(
      CourseCacheParams(forceRefresh: event.forceRefresh),
    );
    failureOrCourses.fold((failure) => emit(CourseError(failure.message)), (
      allCourses,
    ) {
      List<CourseInfo> filteredCourses = allCourses;

      // Apply filters
      if (event.departmentFilter?.isNotEmpty == true) {
        final dept = event.departmentFilter!.toUpperCase();
        filteredCourses =
            filteredCourses
                .where(
                  (c) =>
                      c.departmentCodes.any((dc) => dc.toUpperCase() == dept),
                )
                .toList();
      }

      if (event.searchQuery?.isNotEmpty == true) {
        final query = event.searchQuery!.toLowerCase();
        filteredCourses =
            filteredCourses
                .where(
                  (c) =>
                      c.title.toLowerCase().contains(query) ||
                      c.code.toLowerCase().contains(query) ||
                      c.description?.toLowerCase().contains(query) == true ||
                      c.tags.any((tag) => tag.toLowerCase().contains(query)),
                )
                .toList();
      }

      // Paginate
      final startIndex = (event.page - 1) * event.limit;
      final endIndex = startIndex + event.limit;
      final pageItems =
          filteredCourses.skip(startIndex).take(event.limit).toList();

      List<CourseInfo> currentCourses = [];
      if (event.page > 1 && state is CoursesPageLoaded) {
        currentCourses = (state as CoursesPageLoaded).courses;
      }

      emit(
        CoursesPageLoaded(
          courses: [...currentCourses, ...pageItems],
          hasMore: endIndex < filteredCourses.length,
          currentPage: event.page,
        ),
      );
    });
  }

  Future<void> _onLoadAllCourses(
    LoadAllCourses event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    final failureOrCourses = await getAllCoursesUseCase(
      const CourseCacheParams(),
    );
    failureOrCourses.fold(
      (failure) => emit(CourseError(failure.message)),
      (courses) => emit(AllCoursesLoaded(courses)),
    );
  }

  Future<void> _onLoadDepartmentCourses(
    LoadDepartmentCourses event,
    Emitter<CourseState> emit,
  ) async {
    emit(CourseLoading());
    final usecase = getDepartmentCoursesUseCase;
    if (usecase == null) {
      emit(const CourseError('Department courses use case not configured'));
      return;
    }
    final result = await usecase(DepartmentParams(event.departmentCode));
    result.fold((failure) => emit(CourseError(failure.message)), (courses) {
      final Map<String, List<CourseInfo>> groups = {};
      for (final c in courses) {
        String groupKey;
        if (c.code.isNotEmpty && RegExp(r'\d').hasMatch(c.code)) {
          final match = RegExp(r'(\d)').firstMatch(c.code);
          groupKey = match != null ? '${match.group(1)}00' : 'Other';
        } else if (c.semester.isNotEmpty) {
          groupKey = c.semester.first;
        } else {
          groupKey = 'Other';
        }
        groups.putIfAbsent(groupKey, () => []).add(c);
      }
      final ordered = <String, List<CourseInfo>>{};
      for (final key in ['100', '200', '300', '400', '500']) {
        if (groups.containsKey(key)) {
          ordered[key] = groups[key]!;
        }
      }
      for (final entry in groups.entries) {
        if (!ordered.containsKey(entry.key)) {
          ordered[entry.key] = entry.value;
        }
      }
      emit(
        DepartmentCoursesLoaded(
          departmentCode: event.departmentCode,
          coursesByLevel: ordered,
        ),
      );
    });
  }

  void _onSearchAndFilterCourses(
    SearchAndFilterCourses event,
    Emitter<CourseState> emit,
  ) {
    final query = event.searchQuery.trim().toLowerCase();
    final dept = event.departmentFilter?.trim() ?? '';
    List<CourseInfo> list = event.allCourses;

    if (dept.isNotEmpty) {
      final upperDept = dept.toUpperCase();
      list =
          list
              .where(
                (c) => c.departmentCodes.any(
                  (dc) => dc.toUpperCase() == upperDept,
                ),
              )
              .toList();
    }

    if (query.isNotEmpty) {
      list =
          list
              .where(
                (c) =>
                    c.title.toLowerCase().contains(query) ||
                    c.code.toLowerCase().contains(query) ||
                    c.description?.toLowerCase().contains(query) == true ||
                    c.tags.any((tag) => tag.toLowerCase().contains(query)),
              )
              .toList();
    }

    emit(
      FilteredCoursesLoaded(
        courses: list,
        searchQuery: event.searchQuery,
        departmentFilter: event.departmentFilter,
      ),
    );
  }
}
