import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vens_hub/core/config/app_config.dart';
import 'package:vens_hub/core/error/exceptions.dart';
import 'package:vens_hub/core/di/injection_container.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FirestoreTextbookService {
  // Firebase Performance is not registered on web. Access lazily/optionally.
  FirebasePerformance? get _performance =>
      sl.isRegistered<FirebasePerformance>() ? sl<FirebasePerformance>() : null;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirestoreTextbookService();

  Future<List<Map<String, String>>> getDocumentsFromPath(String path) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_getTextbooksFromPath');
    trace?.putAttribute('path', path);
    await trace?.start();

    List<Map<String, String>> data = [];

    try {
      // Read textbook metadata from Firestore instead of R2
      final textbooks = await _getTextbooksFromFirestore(path);

      for (var textbook in textbooks) {
        data.add({
          "name": textbook['name'] ?? 'Unknown Document',
          "url": textbook['url'] ?? '',
        });
        log("Got Document ${textbook['name']}: ${textbook['url']}");
      }

      trace?.setMetric('items_found', data.length);
      return data;
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      log("Firestore Textbook Error: $e");
      throw StorageException(message: "Firestore Textbook Error: $e");
    } finally {
      await trace?.stop();
    }
  }

  Future<List<Map<String, dynamic>>> _getTextbooksFromFirestore(
    String path,
  ) async {
    try {
      // Query the textbooks collection in Firestore
      // You can organize this by course/path if needed
      QuerySnapshot querySnapshot;

      if (path.contains('Data Communication') || path.contains('elect')) {
        // Filter by course category
        querySnapshot =
            await _firestore
                .collection('textbooks')
                .where('category', isEqualTo: 'data_communication')
                .get();
      } else {
        // Get all textbooks or filter by other criteria
        querySnapshot = await _firestore.collection('textbooks').get();
      }

      final textbooks = <Map<String, dynamic>>[];

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Generate the R2 URL from the stored path
        final r2Path = data['r2_path'] as String?;
        final url =
            r2Path != null
                ? _generateR2Url(r2Path)
                : data['url'] as String? ?? '';

        textbooks.add({
          'name': data['name'] as String? ?? 'Unknown Document',
          'url': url,
          'r2_path': r2Path,
          'category': data['category'] as String? ?? 'general',
          'description': data['description'] as String? ?? '',
          'file_size': data['file_size'] as int? ?? 0,
          'upload_date': data['upload_date'] as Timestamp?,
        });
      }

      return textbooks;
    } catch (e) {
      log("Error fetching textbooks from Firestore: $e");
      throw StorageException(
        message: "Failed to fetch textbooks from Firestore: $e",
      );
    }
  }

  // Method to add a new textbook to Firestore
  Future<void> addTextbook({
    required String name,
    required String r2Path,
    required String category,
    String? description,
    int? fileSize,
  }) async {
    try {
      await _firestore.collection('textbooks').add({
        'name': name,
        'r2_path': r2Path,
        'url': _generateR2Url(r2Path), // Store the full URL for convenience
        'category': category,
        'description': description ?? '',
        'file_size': fileSize ?? 0,
        'upload_date': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log("Error adding textbook to Firestore: $e");
      throw StorageException(
        message: "Failed to add textbook to Firestore: $e",
      );
    }
  }

  // Method to update textbook metadata
  Future<void> updateTextbook({
    required String docId,
    String? name,
    String? category,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (category != null) updates['category'] = category;
      if (description != null) updates['description'] = description;
      updates['updated_at'] = FieldValue.serverTimestamp();

      await _firestore.collection('textbooks').doc(docId).update(updates);
    } catch (e) {
      log("Error updating textbook in Firestore: $e");
      throw StorageException(
        message: "Failed to update textbook in Firestore: $e",
      );
    }
  }

  // Method to delete textbook from Firestore
  Future<void> deleteTextbook(String docId) async {
    try {
      await _firestore.collection('textbooks').doc(docId).delete();
    } catch (e) {
      log("Error deleting textbook from Firestore: $e");
      throw StorageException(
        message: "Failed to delete textbook from Firestore: $e",
      );
    }
  }

  // Generate R2 URL from path
  String _generateR2Url(String r2Path) {
    final encodedPath = r2Path.split('/').map(Uri.encodeComponent).join('/');
    return "${AppConfig.r2PublicDomain}/$encodedPath";
  }

  // Search textbooks by name or description
  Future<List<Map<String, dynamic>>> searchTextbooks(String query) async {
    try {
      // Note: Firestore doesn't support full-text search natively
      // This is a simple contains search on the name field
      // For better search, consider using Algolia or similar service

      final querySnapshot =
          await _firestore
              .collection('textbooks')
              .where('name', isGreaterThanOrEqualTo: query)
              .where('name', isLessThan: '$query\uf8ff')
              .get();

      final textbooks = <Map<String, dynamic>>[];

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final r2Path = data['r2_path'] as String?;
        final url =
            r2Path != null
                ? _generateR2Url(r2Path)
                : data['url'] as String? ?? '';

        textbooks.add({
          'name': data['name'] as String? ?? 'Unknown Document',
          'url': url,
          'r2_path': r2Path,
          'category': data['category'] as String? ?? 'general',
          'description': data['description'] as String? ?? '',
          'file_size': data['file_size'] as int? ?? 0,
          'upload_date': data['upload_date'] as Timestamp?,
        });
      }

      return textbooks;
    } catch (e) {
      log("Error searching textbooks in Firestore: $e");
      throw StorageException(
        message: "Failed to search textbooks in Firestore: $e",
      );
    }
  }
}
