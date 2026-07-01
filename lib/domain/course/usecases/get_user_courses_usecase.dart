import 'package:dartz/dartz.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/core/usecases/usecase.dart';
import 'package:vens_hub/data/models/course_info.dart';
import 'package:vens_hub/domain/course/repositories/course_repository.dart';
import 'package:equatable/equatable.dart';

class GetUserCoursesUseCase
    implements UseCase<List<CourseInfo>, CourseCacheParams> {
  final CourseRepository repository;
  GetUserCoursesUseCase(this.repository);

  @override
  Future<Either<Failure, List<CourseInfo>>> call(
    CourseCacheParams params,
  ) async {
    return await repository.getUserCourses(forceRefresh: params.forceRefresh);
  }
}

class CourseCacheParams extends Equatable {
  final bool forceRefresh;
  const CourseCacheParams({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}
