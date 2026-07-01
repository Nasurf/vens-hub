import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/core/usecases/usecase.dart';
import 'package:vens_hub/data/models/user_model.dart';
import 'package:vens_hub/domain/auth/repositories/auth_repository.dart';

class SignInUserUseCase implements UseCase<UserModel, SignInParams> {
  final AuthRepository authRepository;

  SignInUserUseCase(this.authRepository);

  @override
  Future<Either<Failure, UserModel>> call(SignInParams params) async {
    return await authRepository.signInWithEmailAndPassword(
      email: params.email,
      password: params.password,
    );
  }
}

class SignInParams extends Equatable {
  final String email;
  final String password;

  const SignInParams({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}
