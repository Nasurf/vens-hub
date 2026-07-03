import "dart:developer";

import "package:firebase_storage/firebase_storage.dart";
import "package:vens_hub/core/di/injection_container.dart";
// import "package:get/get.dart"; // Removed GetX
import "package:vens_hub/core/error/exceptions.dart";
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirebaseStorageService {
  // Removed extends GetxController
  // static get find => Get.find(); // Removed GetX static finder
  final FirebaseStorage _firebaseStorage =
      FirebaseStorage.instance; // Made final
  FirebasePerformance? get _performance =>
      sl.isRegistered<FirebasePerformance>() ? sl<FirebasePerformance>() : null;

  // Default constructor is fine
  FirebaseStorageService();

  Future<List<Map<String, String>>> getDocumentsFromPath(String path) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('storage_getDocumentsFromPath');
    trace?.putAttribute('path', path);
    await trace?.start();

    List<Map<String, String>> data = [];

    try {
      Reference reference = _firebaseStorage.ref().child(path);
      ListResult result = await reference.listAll();
      trace?.setMetric('items_found', result.items.length);

      for (var items in result.items) {
        var downloadUrl = await items.getDownloadURL();
        data.add({"name": items.name, "url": downloadUrl});
        log("Got Document ${items.name}: $downloadUrl");
      }
      return data;
    } on FirebaseException catch (e) {
      // Catch specific FirebaseException
      trace?.putAttribute('error', e.code);
      log("Firebase Storage Error: ${e.message} (Code: ${e.code})");
      throw StorageException(
        message: "Firebase Storage Error: ${e.message ?? e.code}",
      );
    } catch (e) {
      // Catch any other error
      trace?.putAttribute('error', e.runtimeType.toString());
      log("Firebase Storage Error $e");
      throw StorageException(message: "Firebase Storage Error: $e");
    } finally {
      await trace?.stop();
    }
  }
}
