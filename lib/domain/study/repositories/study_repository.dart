import 'package:dartz/dartz.dart';
import 'package:vens_hub/core/error/failure.dart';
import 'package:vens_hub/data/models/textbook_model.dart';

abstract class StudyRepository {
  Future<Either<Failure, List<TextBookModel>>> getTextBooks(String path);
  void clearCache([String? path]);
}
