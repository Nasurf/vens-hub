import 'package:dartz/dartz.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/core/usecases/usecase.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';

class SendVerificationEmailUseCase implements UseCase<void, NoParams> {
  final AuthRepository repository;

  SendVerificationEmailUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    final result = await repository.sendVerificationEmail();
    return result.fold((failure) => Left(failure), (_) => const Right(null));
  }
}
