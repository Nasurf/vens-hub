import 'dart:developer';
// import 'package:get/get.dart';
import 'package:vens_hub/core/services/storage/firestore_textbook_service.dart'; // Changed to Firestore Textbook Service
// import 'package:vens_hub/core/services/firestore/firestore_services.dart'; // Removed unused import
import 'package:vens_hub/data/models/textbook_model.dart'; // Corrected import path
import 'package:vens_hub/domain/study/repositories/study_repository.dart'; // Import interface
import 'package:dartz/dartz.dart'; // For Either
import 'package:vens_hub/core/error/failure.dart'; // For Failure
import 'package:vens_hub/core/error/exceptions.dart'; // For StorageException

class StudyRepositoryImpl implements StudyRepository {
  // Implement interface, remove GetxController
  final FirestoreTextbookService
  storageService; // Changed to Firestore Textbook Service
  final Map<String, List<TextBookModel>> _cache = {};
  final String _defaultPath = "elect/Data Communication";

  StudyRepositoryImpl({required this.storageService}); // Constructor

  // TODO: PRELOADING AND CACHING TEXT: CONSIDER IT
  // Consider how to trigger this or if it's still needed with BLoC approach.
  // void preloadDefaultTextbooks() {
  //   getTextBooks(_defaultPath).then((result) {
  //     result.fold(
  //       (failure) => log("Error preloading textbooks: ${failure.message}"),
  //       (books) { _cachedTextbooks = books; log("Preloaded textbooks successfully."); }
  //     );
  //   }).catchError((e) { // Should not happen if Either is handled
  //     log("Error preloading textbooks (exception): $e");
  //   });
  // }

  @override
  Future<Either<Failure, List<TextBookModel>>> getTextBooks(String path) async {
    final cached = _cache[path];
    if (cached != null) {
      return Right(cached);
    }
    List<TextBookModel> data = [];
    try {
      List<Map<String, String>> response = await storageService
          .getDocumentsFromPath(path);
      for (var item in response) {
        data.add(TextBookModel.fromJson(item));
      }
      _cache[path] = data;
      return Right(data);
    } on StorageException catch (e) {
      // Catch specific StorageException from service
      log("StorageException getting textbook data: ${e.message}");
      return Left(
        ServerFailure(message: "Failed to fetch textbooks: ${e.message}"),
      );
    } catch (e) {
      // Catch any other generic error
      log("Error getting textbook data: $e");
      return Left(
        ServerFailure(message: "Failed to fetch textbooks: ${e.toString()}"),
      );
    }
  }

  @override
  void clearCache([String? path]) {
    if (path != null) {
      _cache.remove(path);
    } else {
      _cache.clear();
    }
  }
}
