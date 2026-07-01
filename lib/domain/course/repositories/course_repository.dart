import 'package:dartz/dartz.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/data/models/course_info.dart'; // Using existing model as entity

abstract class CourseRepository {
  Future<Either<Failure, List<CourseInfo>>> getUserCourses({
    bool forceRefresh = false,
  });
  Future<Either<Failure, List<CourseInfo>>> getAllCourses({
    bool forceRefresh = false,
  }); // For browsing, etc.
  Future<Either<Failure, List<CourseInfo>>> getCoursesByDepartment(
    String departmentCode,
  );
  // Future<Either<Failure, CourseInfo>> getCourseDetails(String courseId); // Optional for now
}
