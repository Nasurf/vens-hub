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
      department: params.department,
      selectedCourses: params.selectedCourses,
    );
  }
}

class SignUpParams extends Equatable {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String department;
  final List<String> selectedCourses;

  const SignUpParams({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.department,
    required this.selectedCourses,
  });

  @override
  List<Object?> get props => [
    email,
    password,
    firstName,
    lastName,
    department,
    selectedCourses,
  ];
}
