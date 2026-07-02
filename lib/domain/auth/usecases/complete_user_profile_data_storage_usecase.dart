import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/core/usecases/usecase.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';

import '../../../data/models/user_model.dart';

class CompleteUserProfileDataStorageUseCase
    extends UseCase<UserModel, CompleteUserProfileDataStorageParams> {
  final AuthRepository repository;

  CompleteUserProfileDataStorageUseCase(this.repository);

  @override
  Future<Either<Failure, UserModel>> call(
    CompleteUserProfileDataStorageParams params,
  ) async {
    return await repository.completeUserProfileDataStorage(
      userId: params.userId,
      email: params.email,
      firstName: params.firstName,
      lastName: params.lastName,
      department: params.department,
      selectedCourses: params.selectedCourses,
    );
  }
}

class CompleteUserProfileDataStorageParams extends Equatable {
  final String userId;
  final String email;
  final String firstName;
  final String lastName;
  final String department;
  final List<String> selectedCourses;

  const CompleteUserProfileDataStorageParams({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.department,
    required this.selectedCourses,
  });

  @override
  List<Object?> get props => [
    userId,
    email,
    firstName,
    lastName,
    department,
    selectedCourses,
  ];
}
