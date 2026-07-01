import 'dart:developer' as dev;
import 'package:dartz/dartz.dart';
import 'package:vens_hub/core/error/exceptions.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/data/models/course_info.dart';
// UserModel is not directly used here anymore for constructing, but its structure is relevant for FireStoreServices.getUserData
// import 'package:vens_hub/data/models/user_model.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart'; // To get current user
import 'package:vens_hub/domain/course/repositories/course_repository.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart'; // MODIFIED: Import FireStoreServices
import 'package:vens_hub/core/services/local_storage/user_cache_service.dart';
import 'package:vens_hub/core/services/local_storage/course_cache_service.dart';
import 'package:vens_hub/core/services/local_storage/daily_cache_service.dart';
import 'package:firebase_auth/firebase_auth.dart'
    as fb_auth; // For FirebaseException type if needed, though service should handle

class CourseRepositoryImpl implements CourseRepository {
  final FireStoreServices
  firestoreService; // MODIFIED: Inject FireStoreServices
  final AuthRepository authRepository;
  final UserCacheService userCacheService;
  final CourseCacheService courseCacheService;
  final DailyCacheService dailyCacheService;

  CourseRepositoryImpl({
    required this.firestoreService, // MODIFIED: Update constructor
    required this.authRepository,
    required this.userCacheService,
    required this.courseCacheService,
    required this.dailyCacheService,
  });

  @override
  Future<Either<Failure, List<CourseInfo>>> getUserCourses({
    bool forceRefresh = false,
  }) async {
    Future<List<CourseInfo>?> loadCachedCourses() async {
      final cached = await userCacheService.getCachedUserData();
      return cached?.courseInfo;
    }

    try {
      if (!forceRefresh) {
        final cachedCourses = await loadCachedCourses();
        if (cachedCourses != null) {
          return Right(cachedCourses);
        }
      }

      final userEither = await authRepository.getCurrentUser();
      return await userEither.fold(
        (failure) async {
          final cachedCourses = await loadCachedCourses();
          if (cachedCourses != null) {
            return Right(cachedCourses);
          }
          return Left(failure);
        },
        (authUser) async {
          if (authUser == null) {
            final cachedCourses = await loadCachedCourses();
            if (cachedCourses != null) {
              return Right(cachedCourses);
            }
            return Left(
              AuthenticationFailure(message: 'User not authenticated.'),
            );
          }

          final existingCourses = authUser.courseInfo;
          if (!forceRefresh && existingCourses != null) {
            return Right(existingCourses);
          }

          try {
            final userModel = await firestoreService.getUserData(
              authUser.id as String,
            );
            if (userModel == null) {
              final cachedCourses = await loadCachedCourses();
              if (cachedCourses != null) {
                return Right(cachedCourses);
              }
              return Left(ServerFailure(message: 'User profile not found.'));
            }

            List<CourseInfo> courses = userModel.courseInfo ?? <CourseInfo>[];

            // Fallback: If courseInfo is empty in user doc, fetch by department and level
            if (courses.isEmpty &&
                userModel.department.isNotEmpty &&
                userModel.level.isNotEmpty) {
              dev.log(
                'CourseRepository: userModel.courseInfo is empty, trying fallback fetch by department (${userModel.department}) and level (${userModel.level})',
              );
              final fallbackCourses = await firestoreService.getCourseInfo(
                userModel.department,
                userModel.level,
              );
              courses = fallbackCourses;
            }

            await userCacheService.cacheUserData(userModel);
            return Right(courses);
          } on FirestoreServiceException catch (e) {
            if (existingCourses != null) {
              return Right(existingCourses);
            }
            final cachedCourses = await loadCachedCourses();
            if (cachedCourses != null) {
              return Right(cachedCourses);
            }
            return Left(ServerFailure(message: e.message));
          }
        },
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      final cachedCourses = await loadCachedCourses();
      if (cachedCourses != null) {
        return Right(cachedCourses);
      }
      return Left(
        AuthenticationFailure(
          message: e.message ?? 'Authentication error fetching user courses.',
        ),
      );
    } on CacheException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on FirestoreServiceException catch (e) {
      final cachedCourses = await loadCachedCourses();
      if (cachedCourses != null) {
        return Right(cachedCourses);
      }
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      final cachedCourses = await loadCachedCourses();
      if (cachedCourses != null) {
        return Right(cachedCourses);
      }
      return Left(
        UnknownFailure(
          message: 'An unknown error occurred while fetching user courses.',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<CourseInfo>>> getAllCourses({
    bool forceRefresh = false,
  }) async {
    try {
      // Use FireStoreServices to fetch from 'course_data' which backs auto-registration
      final courses = await firestoreService.getAllCourseData();
      return Right(courses);
    } on FirestoreServiceException catch (e) {
      // Catch specific exception from our service
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(
        UnknownFailure(
          message: 'An unknown error occurred while fetching all courses.',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<CourseInfo>>> getCoursesByDepartment(
    String departmentCode,
  ) async {
    try {
      final courses = await firestoreService.getCoursesByDepartment(
        departmentCode,
      );
      return Right(courses);
    } on FirestoreServiceException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(
        UnknownFailure(
          message:
              'An unknown error occurred while fetching department courses.',
        ),
      );
    }
  }
}
