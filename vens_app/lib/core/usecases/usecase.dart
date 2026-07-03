import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:vens_hub/core/error/failure.dart'; // Adjusted import path

// Abstract class for Use Cases
// Type: the return type of the use case (e.g., a Model or void)
// Params: the parameters required by the use case
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

// Helper class for use cases that don't require parameters
class NoParams extends Equatable {
  @override
  List<Object?> get props => [];
}
