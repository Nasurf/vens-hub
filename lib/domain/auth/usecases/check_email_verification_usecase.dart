import 'package:dartz/dartz.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/core/usecases/usecase.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';

class CheckEmailVerificationUseCase implements UseCase<bool, NoParams> {
  final AuthRepository repository;

  CheckEmailVerificationUseCase(this.repository);

  @override
  Future<Either<Failure, bool>> call(NoParams params) async {
    return await repository.checkEmailVerification();
  }
}
