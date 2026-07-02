// lib/data/auth/repositories/auth_repository_impl.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:vens_hub/core/error/exceptions.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/core/services/auth/auth_service.dart';
import 'package:vens_hub/core/services/data/firestore_service.dart'; // MODIFIED: Import FireStoreServices
import 'package:vens_hub/core/services/storage/r2_storage_service.dart'; // Import R2StorageService
import 'package:vens_hub/core/services/local_storage/user_cache_service.dart';
import 'package:vens_hub/core/services/local_storage/cache_clearing_service.dart';
import 'package:vens_hub/data/models/course_info.dart';
import 'package:vens_hub/data/models/user_model.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';
import 'package:vens_hub/core/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;

// import 'package:firebase_auth/firebase_auth.dart' as fb_auth; // No longer needed directly

class AuthRepositoryImpl implements AuthRepository {
  final AuthService authService;
  final FireStoreServices
  firestoreService; // MODIFIED: Inject FireStoreServices
  final R2StorageService r2StorageService; // Add R2StorageService
  final UserCacheService userCacheService;
  final CacheClearingService cacheClearingService;

  AuthRepositoryImpl({
    required this.authService,
    required this.firestoreService, // MODIFIED: Update constructor
    required this.r2StorageService, // Add R2StorageService
    required this.userCacheService,
    required this.cacheClearingService,
  });

  // Helper method to fetch course info using FireStoreServices
  Future<List<CourseInfo>> _fetchCourseInfoForUser(
    String levelCode,
    String departmentCode,
  ) async {
    try {
      // Use FireStoreServices to get course info
      final courses = await firestoreService.getCourseInfo(
        departmentCode,
        levelCode,
      );
      return courses;
    } catch (e) {
      // Log the error but don't block user creation. Return an empty list.
      // Consider if this error should be propagated or handled more gracefully
      debugPrint('Error fetching course info via service during sign up: $e');
      if (e is FirestoreServiceException) {
        // If it's a known exception from our service, we might want to handle it
        // or rethrow it as a specific failure type if appropriate.
        // For now, returning empty list as per original logic.
      }
      return [];
    }
  }

  Future<UserModel> _createUserProfile({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    required String department,
    required List<String> selectedCourses,
    required bool isEmailVerified,
  }) async {
    // Build minimal course info from selected course codes
    final courseInfo = selectedCourses.map((code) => CourseInfo(
      id: code,
      title: '',
      code: code,
      semester: const [],
      tags: const [],
      departmentCodes: const [],
      topics: const [],
    )).toList();

    final userModel = UserModel(
      id: uid,
      email: email,
      firstName: firstName,
      lastName: lastName,
      level: '',
      department: department,
      courseInfo: courseInfo,
      createdAt: DateTime.now(),
      isEmailVerified: isEmailVerified,
    );
    await firestoreService.setUserData(userModel);
    return userModel;
  }

  @override
  Future<Either<Failure, UserModel>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String department,
    required List<String> selectedCourses,
  }) async {
    try {
      final firebaseUser = await authService.signUpWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (firebaseUser == null) {
        return Left(
          AuthenticationFailure(message: 'Sign up failed: No user created.'),
        );
      }

      final userModel = await _createUserProfile(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? email,
        firstName: firstName,
        lastName: lastName,
        department: department,
        selectedCourses: selectedCourses,
        isEmailVerified:
            firebaseUser.emailVerified,
      );

      return Right(userModel);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthenticationException catch (e) {
      if (e is EmailAlreadyInUseException) {
        return Left(EmailAlreadyInUseFailure(message: e.message));
      }
      if (e is InvalidEmailException) {
        return Left(InvalidEmailFailure(message: e.message));
      }
      if (e is OperationNotAllowedException) {
        return Left(OperationNotAllowedFailure(message: e.message));
      }
      if (e is WeakPasswordException) {
        return Left(WeakPasswordFailure(message: e.message));
      }
      return Left(AuthenticationFailure(message: e.message));
    } on FirebaseException catch (e) {
      return Left(
        ServerFailure(message: e.message ?? "Failed to create user profile."),
      );
    } catch (e) {
      return Left(
        UnknownFailure(message: 'An unknown error occurred during sign up.'),
      );
    }
  }

  // Helper method to fetch user profile using FireStoreServices
  Future<UserModel?> _fetchAuthUser(String uid) async {
    try {
      // Ensure the Firebase user is reloaded to get the latest email verification status
      await authService.reloadCurrentUser();
      final firebaseUser = authService.currentUser;

      if (firebaseUser == null || firebaseUser.uid != uid) {
        // User not found or mismatch, return null or throw specific exception
        return null;
      }

      // Use FireStoreServices to get user data from Firestore
      final userModel = await firestoreService.getUserData(uid);

      if (userModel != null) {
        // Prepare updates based on Firebase Auth profile where available
        final String? firebasePhotoUrl = firebaseUser.photoURL;
        final bool photoChanged =
            firebasePhotoUrl != null &&
            firebasePhotoUrl.isNotEmpty &&
            firebasePhotoUrl != userModel.photoUrl;
        final bool verificationChanged =
            (userModel.isEmailVerified ?? false) != firebaseUser.emailVerified;

        // Create a new UserModel with the updated email verification status and photo URL from Firebase
        final updatedUserModel = userModel.copyWith(
          isEmailVerified: firebaseUser.emailVerified,
          photoUrl: firebasePhotoUrl ?? userModel.photoUrl,
        );

        // Persist photo URL and verification flag if changed
        try {
          if (photoChanged) {
            await firestoreService.updateUserData(uid, {
              'photoUrl': firebasePhotoUrl,
            });
          }
          if (verificationChanged) {
            await firestoreService.updateUserData(uid, {
              'isEmailVerified': firebaseUser.emailVerified,
            });
          }
        } catch (_) {
          // Non-fatal; ignore write failure but still return updated model
        }

        // Cache the user data for future use
        await userCacheService.cacheUserData(updatedUserModel);

        return updatedUserModel;
      }
      return null;
    } on FirestoreServiceException catch (e) {
      throw CacheException(message: e.message);
    } catch (e) {
      throw CacheException(
        message: 'Failed to fetch user profile from Firestore: $e',
      );
    }
  }

  @override
  Future<Either<Failure, UserModel>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final firebaseUser = await authService.signInWithEmailAndPassword(
        email,
        password,
      );
      if (firebaseUser == null) {
        return Left(
          AuthenticationFailure(message: 'Sign in failed: No user returned.'),
        );
      }
      final authUser = await _fetchAuthUser(firebaseUser.uid);
      if (authUser == null) {
        return Left(AuthenticationFailure(message: 'User profile not found.'));
      }
      return Right(authUser);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthenticationException catch (e) {
      if (e is InvalidEmailException) {
        return Left(InvalidEmailFailure(message: e.message));
      }
      if (e is UserDisabledException) {
        // Added {}
        return Left(UserDisabledFailure(message: e.message));
      }
      if (e is UserNotFoundException) {
        // Added {}
        return Left(UserNotFoundFailure(message: e.message));
      }
      if (e is WrongPasswordException) {
        // Added {}
        return Left(WrongPasswordFailure(message: e.message));
      }
      return Left(AuthenticationFailure(message: e.message));
    } on CacheException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: 'An unknown error occurred.'));
    }
  }

  @override
  Future<Either<Failure, UserModel>> signInWithGoogle() async {
    try {
      // Unified provider-based flow, then enforce user existence
      final firebaseUser = await authService.signInWithGoogle();
      if (firebaseUser == null) {
        return Left(
          AuthenticationFailure(message: 'Google sign-in was cancelled.'),
        );
      }

      final userExists = await firestoreService.userExistsByEmail(
        firebaseUser.email ?? '',
      );
      if (!userExists) {
        await authService.deleteCurrentUser();
        return Left(
          UserNotFoundFailure(
            message: 'No account found with this email. Please sign up first.',
          ),
        );
      }

      final authUser = await _fetchAuthUser(firebaseUser.uid);
      if (authUser == null) {
        await authService.deleteCurrentUser();
        return Left(
          AuthenticationFailure(
            message: 'Account data inconsistency. Please contact support.',
          ),
        );
      }
      return Right(authUser);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message));
    } on FirestoreServiceException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(
        UnknownFailure(
          message: 'An unknown error occurred during Google sign-in.',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await authService.signOut();
      await cacheClearingService.clearAllUserCaches();
      return const Right(null);
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message));
    } catch (e) {
      return Left(
        UnknownFailure(message: 'An unknown error occurred during sign out.'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccountAndData() async {
    try {
      final user = await authService.getCurrentFirebaseUser();
      if (user == null) {
        return Left(AuthenticationFailure(message: 'No authenticated user.'));
      }

      // Get fresh ID token after reauthentication; required for Authorization header
      final token = await authService.getIdToken(forceRefresh: true);
      final base = AppConfig.functionsBaseUrl;
      final uri = Uri.parse('$base/delete_account');
      final resp = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: '{}',
      );
      if (resp.statusCode == 200) {
        // Sign out locally and clear caches
        try {
          await cacheClearingService.clearAllUserCaches();
        } catch (_) {}
        try {
          await authService.signOut();
        } catch (_) {}
        return const Right(null);
      }
      // If function indicates recent login required, surface a clear message
      if (resp.statusCode == 401 &&
          resp.body.contains('RECENT_LOGIN_REQUIRED')) {
        return Left(
          AuthenticationFailure(
            message: 'Please reauthenticate and try again.',
          ),
        );
      }

      // Fallback path on server errors (e.g., 5xx, including 503)
      if (resp.statusCode >= 500) {
        try {
          // Best-effort: delete Firestore user data client-side
          await firestoreService.deleteUserData(user.uid);
        } catch (_) {
          // ignore; we still attempt to delete the Auth user
        }
        try {
          // Delete the Firebase Auth user (requires recent auth)
          await authService.deleteCurrentUser();
        } catch (e) {
          // If even local deletion fails, return server error
          final msg =
              resp.body.isNotEmpty
                  ? resp.body
                  : 'Account deletion failed with status ${resp.statusCode}';
          return Left(ServerFailure(message: msg));
        }

        // Clear local caches
        try {
          await cacheClearingService.clearAllUserCaches();
        } catch (_) {}

        return const Right(null);
      }

      final msg =
          resp.body.isNotEmpty
              ? resp.body
              : 'Account deletion failed with status ${resp.statusCode}';
      return Left(ServerFailure(message: msg));
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message));
    } catch (e) {
      return Left(
        UnknownFailure(
          message: 'An unknown error occurred during account deletion.',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, UserModel?>> getCurrentUser() async {
    try {
      final firebaseUser = await authService.getCurrentFirebaseUser();
      if (firebaseUser == null) {
        return const Right(null);
      }

      // Fast path: serve cached user immediately if present and matches current UID,
      // then refresh in the background without blocking startup navigation.
      final cached = await userCacheService.getCachedUserData();
      if (cached != null && cached.id == firebaseUser.uid) {
        // Background refresh to keep cache warm and fields up to date
        // ignore: unawaited_futures
        _fetchAuthUser(firebaseUser.uid)
            .then((fresh) async {
              if (fresh != null) {
                try {
                  await userCacheService.cacheUserData(fresh);
                } catch (_) {}
              }
            })
            .catchError((_) {});
        return Right(cached);
      }

      // No valid cache; fetch from Firestore
      final authUser = await _fetchAuthUser(firebaseUser.uid);
      return Right(authUser);
    } on AuthenticationException catch (e) {
      return Left(AuthenticationFailure(message: e.message));
    } on CacheException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: 'An unknown error occurred.'));
    }
  }

  @override
  Future<Either<Failure, UserModel>> completeUserProfileDataStorage({
    required String userId,
    required String email,
    required String firstName,
    required String lastName,
    required String department,
    required List<String> selectedCourses,
  }) async {
    try {
      final fbUser = await authService.getCurrentFirebaseUser();
      if (fbUser == null || fbUser.uid != userId) {
        return Left(
          AuthenticationFailure(
            message: "User session mismatch. Please sign in again.",
          ),
        );
      }

      final userModel = await _createUserProfile(
        uid: userId,
        email: email,
        firstName: firstName,
        lastName: lastName,
        department: department,
        selectedCourses: selectedCourses,
        isEmailVerified: fbUser.emailVerified,
      );

      return Right(userModel);
    } on FirebaseException catch (e) {
      return Left(
        ServerFailure(
          message: e.message ?? "Failed to save user profile to Firestore.",
        ),
      );
    } on CacheException catch (e) {
      // If _createUserProfile can throw this (e.g. _fetchCourseInfoForUser)
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(
        UnknownFailure(
          message:
              'An unknown error occurred while saving user profile: ${e.toString()}',
        ),
      );
    }
  }
}
