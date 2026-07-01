import 'package:dartz/dartz.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:equatable/equatable.dart';
import 'package:vens_hub/core/usecases/usecase.dart';
import 'package:vens_hub/data/models/course_info.dart';
import 'package:vens_hub/domain/course/repositories/course_repository.dart';
import 'package:vens_hub/domain/course/usecases/get_user_courses_usecase.dart';

class GetAllCoursesUseCase
    implements UseCase<List<CourseInfo>, CourseCacheParams> {
  final CourseRepository repository;
  GetAllCoursesUseCase(this.repository);

  @override
  Future<Either<Failure, List<CourseInfo>>> call(
    CourseCacheParams params,
  ) async {
    return await repository.getAllCourses(forceRefresh: params.forceRefresh);
  }
}

class GetDepartmentCoursesUseCase
    implements UseCase<List<CourseInfo>, DepartmentParams> {
  final CourseRepository repository;
  GetDepartmentCoursesUseCase(this.repository);

  @override
  Future<Either<Failure, List<CourseInfo>>> call(
    DepartmentParams params,
  ) async {
    return await repository.getCoursesByDepartment(params.departmentCode);
  }
}

class DepartmentParams extends Equatable {
  final String departmentCode;
  const DepartmentParams(this.departmentCode);

  @override
  List<Object?> get props => [departmentCode];
}
