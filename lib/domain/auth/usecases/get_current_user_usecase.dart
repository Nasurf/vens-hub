import 'package:dartz/dartz.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/core/usecases/usecase.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';

import '../../../data/models/user_model.dart';

class GetCurrentUserUseCase implements UseCase<UserModel?, NoParams> {
  // Return type is UserModel?
  final AuthRepository authRepository;

  GetCurrentUserUseCase(this.authRepository);

  @override
  Future<Either<Failure, UserModel?>> call(NoParams params) async {
    return await authRepository.getCurrentUser();
  }
}
