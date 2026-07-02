// lib/domain/auth/repositories/auth_repository.dart

import 'package:dartz/dartz.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/data/models/user_model.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserModel>> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<Either<Failure, UserModel>> signInWithGoogle();
  Future<Either<Failure, UserModel>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String level, // ADDED
    required String department, // ADDED
  });
  Future<Either<Failure, void>> signOut();
  Future<Either<Failure, UserModel?>> getCurrentUser();
  Future<Either<Failure, void>> deleteAccountAndData();

  Future<Either<Failure, UserModel>> completeUserProfileDataStorage({
    // New method for step 4
    required String userId, // Firebase Auth UID
    required String email,
    required String firstName,
    required String lastName,
    required String level,
    required String department,
  });
}
