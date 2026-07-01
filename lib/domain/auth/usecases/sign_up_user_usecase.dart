// lib/domain/auth/usecases/sign_up_user_usecase.dart

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/core/usecases/usecase.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';

import '../../../data/models/user_model.dart';

class SignUpUserUseCase implements UseCase<UserModel, SignUpParams> {
  final AuthRepository authRepository;

  SignUpUserUseCase(this.authRepository);

  @override
  Future<Either<Failure, UserModel>> call(SignUpParams params) async {
    return await authRepository.signUpWithEmailAndPassword(
      email: params.email,
      password: params.password,
      firstName: params.firstName,
      lastName: params.lastName,
      level: params.level, // MODIFIED: Pass level
      department: params.department, // MODIFIED: Pass department
    );
  }
}

class SignUpParams extends Equatable {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String level; // ADDED
  final String department; // ADDED

  const SignUpParams({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.level, // ADDED
    required this.department, // ADDED
  });

  @override
  List<Object?> get props => [
    email,
    password,
    firstName,
    lastName,
    level,
    department,
  ]; // ADDED to props
}
