import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:get/get.dart';
import 'package:vens_hub/core/di/injection_container.dart';
import 'package:vens_hub/core/error/exceptions.dart';
// import 'package:vens_hub/core/theme/app_colors.dart'; // Removed unused import
import 'package:vens_hub/data/models/course_info.dart'; // Corrected import path
import 'package:vens_hub/data/models/user_model.dart'; // Corrected import path

class FireStoreServices extends GetxController {
  static FireStoreServices get find => Get.find<FireStoreServices>();

  final _db = FirebaseFirestore.instance;
  FirebasePerformance? get _performance =>
      sl.isRegistered<FirebasePerformance>() ? sl<FirebasePerformance>() : null;

  /// Refresh App Check token if needed
  Future<void> _refreshAppCheckTokenIfNeeded() async {
    try {
      await FirebaseAppCheck.instance.getToken(true);
      log("App Check token refreshed successfully");
    } catch (e) {
      log("Failed to refresh App Check token: $e");
      // Continue without token - App Check will retry automatically
    }
  }

  final String courseCollectionName = "course_data";

  // ===== Question Reports =====
  Future<void> submitQuestionReport({
    String? uid,
    required String questionType,
    String? questionId,
    required String questionText,
    String? courseName,
    String? topic,
    String? difficulty,
    int? questionIndex,
    required String issueNature,
    String? issueDetails,
    bool includeLogs = false,
    Map<String, dynamic>? logs,
  }) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_submitQuestionReport');
    await trace?.start();
    try {
      await _refreshAppCheckTokenIfNeeded();

      final Map<String, dynamic> data = {
        'uid': uid,
        'questionType': questionType,
        'questionId': questionId,
        'questionText': questionText,
        'courseName': courseName,
        'topic': topic,
        'difficulty': difficulty,
        'questionIndex': questionIndex,
        'issueNature': issueNature,
        'issueDetails': issueDetails,
        'includeLogs': includeLogs,
        if (includeLogs && logs != null) 'logs': logs,
        'createdAt': FieldValue.serverTimestamp(),
      }..removeWhere((key, value) => value == null);

      await _db.collection('question_reports').add(data);
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error submitting report: $e');
      rethrow;
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      log('Error submitting report: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  // ===== Timetable APIs =====
  // Firestore shape:
  // collection('timetables')
  //   doc('<department_code>_<level>') e.g. 'EEE_400'
  //     collection('entries')
  //       doc(auto)
  //         { title: 'monday', course, venue, participants, start_time, end_time }

  Future<List<Map<String, dynamic>>> getTimetableEntries({
    required String departmentCode,
    required String level,
  }) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_getTimetableEntries');
    trace?.putAttribute('department', departmentCode);
    trace?.putAttribute('level', level);
    await trace?.start();
    try {
      await _refreshAppCheckTokenIfNeeded();
      final docId = '${departmentCode}_$level';
      Query<Map<String, dynamic>> baseQuery = _db
          .collection('timetables')
          .doc(docId)
          .collection('entries')
          .orderBy('title');
      final querySnapshot = await baseQuery.get();
      final data =
          querySnapshot.docs.map((d) => ({...d.data(), 'id': d.id})).toList();
      trace?.setMetric('entries_fetched', data.length);
      return data;
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error fetching timetable: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  Future<void> upsertTimetableEntries({
    required String departmentCode,
    required String level,
    required List<Map<String, dynamic>> entries,
  }) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_upsertTimetableEntries');
    trace?.putAttribute('department', departmentCode);
    trace?.putAttribute('level', level);
    await trace?.start();
    final batch = _db.batch();
    try {
      final docId = '${departmentCode}_$level';
      final colRef = _db
          .collection('timetables')
          .doc(docId)
          .collection('entries');
      for (final entry in entries) {
        final id = entry['id'] as String?;
        final data = Map<String, dynamic>.from(entry)..remove('id');
        if (data['title'] is String) {
          data['title'] = (data['title'] as String).toLowerCase();
        }
        final docRef =
            id != null && id.isNotEmpty ? colRef.doc(id) : colRef.doc();
        batch.set(docRef, data, SetOptions(merge: true));
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error upserting timetable: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  Future<void> replaceTimetable({
    required String departmentCode,
    required String level,
    required List<Map<String, dynamic>> entries,
  }) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_replaceTimetable');
    trace?.putAttribute('department', departmentCode);
    trace?.putAttribute('level', level);
    await trace?.start();
    try {
      final docId = '${departmentCode}_$level';
      final colRef = _db
          .collection('timetables')
          .doc(docId)
          .collection('entries');
      final existing = await colRef.get();
      final batch = _db.batch();
      for (final d in existing.docs) {
        batch.delete(d.reference);
      }
      for (final entry in entries) {
        final data = Map<String, dynamic>.from(entry)..remove('id');
        // Ensure canonical weekday key
        if (data['title'] is String) {
          data['title'] = (data['title'] as String).toLowerCase();
        }
        batch.set(colRef.doc(), data);
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error replacing timetable: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  Future<void> deleteTimetable({
    required String departmentCode,
    required String level,
  }) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_deleteTimetable');
    trace?.putAttribute('department', departmentCode);
    trace?.putAttribute('level', level);
    await trace?.start();
    try {
      final docId = '${departmentCode}_$level';
      final colRef = _db
          .collection('timetables')
          .doc(docId)
          .collection('entries');
      final existing = await colRef.get();
      final batch = _db.batch();
      for (final d in existing.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error deleting timetable: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  // ===== User Events APIs =====
  // users/{uid}/events documents use the same schema as timetable entries
  Future<List<Map<String, dynamic>>> getUserEvents({
    required String uid,
  }) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_getUserEvents');
    trace?.putAttribute('uid', uid);
    await trace?.start();
    try {
      await _refreshAppCheckTokenIfNeeded();
      final snapshot =
          await _db.collection('users').doc(uid).collection('events').get();
      return snapshot.docs.map((d) => ({...d.data(), 'id': d.id})).toList();
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error fetching user events: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  Future<String> addUserEvent({
    required String uid,
    required Map<String, dynamic> event,
  }) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_addUserEvent');
    trace?.putAttribute('uid', uid);
    await trace?.start();
    try {
      final data = Map<String, dynamic>.from(event);
      if (data['title'] is String) {
        data['title'] = (data['title'] as String).toLowerCase();
      }
      final ref = await _db
          .collection('users')
          .doc(uid)
          .collection('events')
          .add(data);
      return ref.id;
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error adding user event: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  Future<void> deleteUserEvent({
    required String uid,
    required String eventId,
  }) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_deleteUserEvent');
    trace?.putAttribute('uid', uid);
    await trace?.start();
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc(eventId)
          .delete();
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error deleting user event: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  // ===== User hidden schedule (per-user hides of non-user events) =====
  Future<List<Map<String, dynamic>>> getHiddenScheduleEvents({
    required String uid,
  }) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_getHiddenScheduleEvents');
    trace?.putAttribute('uid', uid);
    await trace?.start();
    try {
      final snap =
          await _db
              .collection('users')
              .doc(uid)
              .collection('hidden_schedule')
              .get();
      return snap.docs
          .map((d) => ({...d.data(), 'id': d.id}))
          .toList(growable: false);
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error fetching hidden schedule: $e');
      return const [];
    } finally {
      await trace?.stop();
    }
  }

  Future<void> hideScheduleEvent({
    required String uid,
    required String source, // 'tt' | 'ac'
    required String eventId,
  }) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_hideScheduleEvent');
    trace?.putAttribute('uid', uid);
    await trace?.start();
    try {
      final docId = '${source}_$eventId';
      await _db
          .collection('users')
          .doc(uid)
          .collection('hidden_schedule')
          .doc(docId)
          .set(<String, dynamic>{
            'source': source,
            'eventId': eventId,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  Future<void> unhideScheduleEvent({
    required String uid,
    required String source, // 'tt' | 'ac'
    required String eventId,
  }) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_unhideScheduleEvent');
    trace?.putAttribute('uid', uid);
    await trace?.start();
    try {
      final docId = '${source}_$eventId';
      await _db
          .collection('users')
          .doc(uid)
          .collection('hidden_schedule')
          .doc(docId)
          .delete();
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  Future<void> updateUserEvent({
    required String uid,
    required String eventId,
    required Map<String, dynamic> event,
  }) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_updateUserEvent');
    trace?.putAttribute('uid', uid);
    await trace?.start();
    try {
      final data = Map<String, dynamic>.from(event);
      if (data['title'] is String) {
        data['title'] = (data['title'] as String).toLowerCase();
      }
      await _db
          .collection('users')
          .doc(uid)
          .collection('events')
          .doc(eventId)
          .set(data, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error updating user event: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  Future<void> setUserData(UserModel user) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_setUserData');
    await trace?.start();
    try {
      log("Saving user data to Firestore: ${user.toJson()}");

      if (user.id == null) {
        log("Error: User ID is null, cannot save to Firestore");
        throw FirestoreServiceException(
          message: "User ID is null, cannot save to Firestore",
        );
      }

      await _db.collection("users").doc(user.id).set(user.toJson());

      log("User data saved successfully to Firestore");
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      // Specific catch for FirebaseException
      log("Firebase error saving user data to Firestore: $e");
      throw FirestoreServiceException(
        message: e.message ?? "Error setting user data",
        underlyingException: e,
      );
    } catch (error) {
      trace?.putAttribute('error', error.runtimeType.toString());
      // Generic catch for other errors
      log("Error saving user data to Firestore: $error");
      throw FirestoreServiceException(
        message: "Error setting user data",
        underlyingException: error,
      );
    } finally {
      await trace?.stop();
    }
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_updateUserData');
    await trace?.start();
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  Future<void> deleteUserData(String uid) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_deleteUserData');
    await trace?.start();
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  // Retrieve user data by UID.
  Future<UserModel?> getUserData(String uid) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_getUserData');
    await trace?.start();
    try {
      log("Fetching user data for UID: $uid");
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      trace?.setMetric('document_exists', doc.exists ? 1 : 0);

      if (doc.exists) {
        log("User document exists, data: ${doc.data()}");
        return UserModel.fromJson(doc.data() as Map<String, dynamic>);
      } else {
        log("User document does not exist for UID: $uid");
        return null;
      }
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      // Specific catch for FirebaseException
      log("Firebase error fetching user data: $e");
      throw FirestoreServiceException(
        message: e.message ?? "Issue fetching user data",
        underlyingException: e,
      );
    } catch (error) {
      trace?.putAttribute('error', error.runtimeType.toString());
      // Generic catch for other errors
      log("Error fetching user data: $error");
      throw FirestoreServiceException(
        message: "Issue fetching user data",
        underlyingException: error,
      );
    } finally {
      await trace?.stop();
    }
  }

  // Check if a user exists by email address
  Future<bool> userExistsByEmail(String email) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_userExistsByEmail');
    await trace?.start();
    try {
      log("Checking if user exists with email: $email");
      QuerySnapshot querySnapshot =
          await _db
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      final exists = querySnapshot.docs.isNotEmpty;
      trace?.setMetric('user_exists', exists ? 1 : 0);
      log("User exists with email $email: $exists");
      return exists;
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log("Firebase error checking user existence by email: $e");
      throw FirestoreServiceException(
        message: e.message ?? "Error checking user existence",
        underlyingException: e,
      );
    } catch (error) {
      trace?.putAttribute('error', error.runtimeType.toString());
      log("Error checking user existence by email: $error");
      throw FirestoreServiceException(
        message: "Error checking user existence",
        underlyingException: error,
      );
    } finally {
      await trace?.stop();
    }
  }

  Future<List<CourseInfo>> getCourseInfo(
    String department,
    String level,
  ) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_getCourseInfo');
    trace?.putAttribute('department', department);
    trace?.putAttribute('level', level);
    await trace?.start();
    try {
      // Refresh App Check token before making the request
      await _refreshAppCheckTokenIfNeeded();

      log("Fetching course info for department: $department, level: $level");
      QuerySnapshot<Map<String, dynamic>> doc =
          await _db
              .collection(courseCollectionName)
              .where("level", isEqualTo: level)
              .where("department_codes", arrayContains: department)
              .get();

      var data =
          doc.docs.map((item) => CourseInfo.fromFirestore(item)).toList();

      // Fallback: Check 'department_code' (singular string) if no results found
      if (data.isEmpty) {
        log(
          "No results with 'department_codes' array. Trying 'department_code' string for $department...",
        );
        final fallbackDoc =
            await _db
                .collection(courseCollectionName)
                .where("level", isEqualTo: level)
                .where("department_code", isEqualTo: department)
                .get();
        data =
            fallbackDoc.docs
                .map((item) => CourseInfo.fromFirestore(item))
                .toList();
      }

      trace?.setMetric('courses_fetched', data.length);
      log("Course info fetched successfully: ${data.length} items");
      return data;
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      // Specific catch for FirebaseException
      log("Firebase error fetching course info: $e");

      // Handle App Check related errors gracefully
      if (e.code == 'app-check-failed' || e.code == 'permission-denied') {
        log("App Check or permission error - this may be temporary");
        // You might want to retry or show a user-friendly message
      }

      throw FirestoreServiceException(
        message: e.message ?? "Error fetching course info",
        underlyingException: e,
      );
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      // Generic catch for other errors
      log("Error fetching course info: $e");
      throw FirestoreServiceException(
        message: "Error fetching course info",
        underlyingException: e,
      );
    } finally {
      await trace?.stop();
    }
  }

  // Fetch the full catalog of courses from the course_data collection
  Future<List<CourseInfo>> getAllCourseData() async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_getAllCourseData');
    await trace?.start();
    try {
      log("Fetching full course catalog from '$courseCollectionName'");
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _db.collection(courseCollectionName).get();

      final List<CourseInfo> courses =
          snapshot.docs
              .map((doc) => CourseInfo.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
      trace?.setMetric('courses_fetched', courses.length);
      log("Fetched ${courses.length} courses from '$courseCollectionName'.");
      return courses;
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log("Firebase error fetching department courses: $e");
      throw FirestoreServiceException(
        message: e.message ?? "Error fetching department courses",
        underlyingException: e,
      );
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      log("Error fetching department courses: $e");
      throw FirestoreServiceException(
        message: "Error fetching department courses",
        underlyingException: e,
      );
    } finally {
      await trace?.stop();
    }
  }

  /// Fetch a single course from `course_data` by its exact title.
  Future<CourseInfo?> getCourseByTitle(String title) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_getCourseByTitle');
    trace?.putAttribute('title', title);
    await trace?.start();
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _db
              .collection(courseCollectionName)
              .where('title', isEqualTo: title)
              .limit(1)
              .get();
      if (snapshot.docs.isEmpty) return null;
      final doc = snapshot.docs.first;
      return CourseInfo.fromFirestore(doc);
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log("Firebase error fetching course by title: $e");
      return null; // Graceful fallback; caller can handle null
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      log("Error fetching course by title: $e");
      return null;
    } finally {
      await trace?.stop();
    }
  }

  // Fetch courses filtered by department code from the course_data collection
  Future<List<CourseInfo>> getCoursesByDepartment(String departmentCode) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_getCoursesByDepartment');
    trace?.putAttribute('department_code', departmentCode);
    await trace?.start();
    try {
      log(
        "Fetching courses for department: $departmentCode from '$courseCollectionName'",
      );
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _db
              .collection(courseCollectionName)
              .where('department_codes', arrayContains: departmentCode)
              .get();

      final List<CourseInfo> courses =
          snapshot.docs
              .map((doc) => CourseInfo.fromJson({...doc.data(), 'id': doc.id}))
              .toList();
      trace?.setMetric('courses_fetched', courses.length);
      log("Fetched ${courses.length} courses for department $departmentCode.");
      return courses;
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log("Firebase error fetching department courses: $e");
      throw FirestoreServiceException(
        message: e.message ?? "Error fetching department courses",
        underlyingException: e,
      );
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      log("Error fetching department courses: $e");
      throw FirestoreServiceException(
        message: "Error fetching department courses",
        underlyingException: e,
      );
    } finally {
      await trace?.stop();
    }
  }

  // Listen to real-time updates for a user document.
  Stream<UserModel?> userDataStream(String uid) {
    // Return UserModel?
    log("Setting up stream for user data with UID: $uid");
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            log("Stream received update for user: $uid, data: ${doc.data()}");
            try {
              return UserModel.fromJson(doc.data()!);
            } catch (e) {
              log(
                "Error parsing UserModel from snapshot for UID $uid: $e. Data: ${doc.data()}",
              );
              // Depending on strictness, could rethrow or return null. Returning null for resilience.
              return null;
            }
          } else {
            log(
              "Document does not exist in stream for UID: $uid. Returning null.",
            );
            return null; // Return null if document doesn't exist
          }
        })
        .handleError((error) {
          // Catch errors from the stream source itself (e.g., permission denied)
          log("Error in userDataStream for UID $uid: $error");
          // Emit null or a special error marker UserModel, or rethrow as a stream error
          // For now, emitting null to align with "no data"
          return null;
        });
  }

  // New method to fetch all documents from the top-level 'courses' collection
  // This assumes documents in 'courses' collection are themselves CourseInfo or can be mapped to it.
  // If they represent levels (e.g., "100", "200"), the mapping to CourseInfo might be incorrect.
  // This directly replaces `firestore.collection('courses').get()` from CourseRepositoryImpl.
  Future<List<Map<String, dynamic>>>
  getRawDocumentsFromTopLevelCourses() async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace(
              'firestore_getRawDocumentsFromTopLevelCourses',
            );
    await trace?.start();
    try {
      log("Fetching all documents from top-level 'courses' collection");
      QuerySnapshot querySnapshot = await _db.collection("courses").get();

      final data =
          querySnapshot.docs
              .map((item) => item.data() as Map<String, dynamic>)
              .toList();
      trace?.setMetric('documents_fetched', data.length);
      log(
        "Raw documents from 'courses' fetched successfully: ${data.length} items",
      );
      return data;
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log("Firebase error fetching from 'courses' collection: $e");
      throw FirestoreServiceException(
        message: e.message ?? "Error fetching from 'courses' collection",
        underlyingException: e,
      );
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      log("Error fetching from 'courses' collection: $e");
      throw FirestoreServiceException(
        message: "Error fetching from 'courses' collection",
        underlyingException: e,
      );
    } finally {
      await trace?.stop();
    }
  }

  // Search functionality for courses and topics
  Future<List<Map<String, dynamic>>> searchCoursesAndTopics(
    String query,
  ) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_searchCoursesAndTopics');
    trace?.putAttribute('query', query);
    await trace?.start();

    try {
      log("Searching courses and topics with query: $query");

      if (query.isEmpty) {
        return [];
      }

      final lowerQuery = query.toLowerCase();

      // Search in course outlines collection
      QuerySnapshot courseSnapshot =
          await _db.collection(courseCollectionName).get();

      List<Map<String, dynamic>> results = [];

      for (var doc in courseSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Check if course name matches (using 'title')
        final courseTitle = data['title']?.toString().toLowerCase() ?? '';
        final topics = data['topics'] as List<dynamic>? ?? [];

        bool matches = false;

        // Check course title
        if (courseTitle.contains(lowerQuery)) {
          matches = true;
        }

        // Check topics (which are now maps)
        if (!matches) {
          for (var topic in topics) {
            if (topic is Map<String, dynamic>) {
              final title = topic['title']?.toString().toLowerCase() ?? '';
              if (title.contains(lowerQuery)) {
                matches = true;
                break;
              }
            } else if (topic.toString().toLowerCase().contains(lowerQuery)) {
              matches = true;
              break;
            }
          }
        }

        if (matches) {
          results.add({...data, 'id': doc.id});
        }
      }

      trace?.setMetric('search_results', results.length);
      log("Search completed successfully: ${results.length} results");
      return results;
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log("Firebase error during search: $e");
      throw FirestoreServiceException(
        message: e.message ?? "Error searching courses",
        underlyingException: e,
      );
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      log("Error during search: $e");
      throw FirestoreServiceException(
        message: "Error searching courses",
        underlyingException: e,
      );
    } finally {
      await trace?.stop();
    }
  }

  // ===== Quiz Attempts (Daily) =====
  // Store a record of questions attempted in a day for future features
  // Schema: users/{uid}/daily_attempts/{YYYY-MM-DD}/attempts/{autoId}
  Future<void> addDailyQuizAttempt({
    required String uid,
    required DateTime startedAt,
    required Duration elapsed,
    required int questionsCount,
    required int correctCount,
    required Map<String, dynamic> course,
    required String topic,
    required String questionType, // 'theory', 'multipleChoice', 'gapFill', etc
    List<Map<String, dynamic>>? items, // optional per-question summaries
  }) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('firestore_addDailyQuizAttempt');
    trace?.putAttribute('uid', uid);
    await trace?.start();
    try {
      await _refreshAppCheckTokenIfNeeded();
      final String dayId = _formatDayId(startedAt);
      final DocumentReference<Map<String, dynamic>> dayDocRef = _db
          .collection('users')
          .doc(uid)
          .collection('daily_attempts')
          .doc(dayId);

      // Ensure the parent day document exists so it can be discovered later
      await dayDocRef.set({
        'dayId': dayId,
        'lastAttemptAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final Map<String, dynamic> data = {
        'startedAt': Timestamp.fromDate(startedAt),
        'elapsedMs': elapsed.inMilliseconds,
        'questionsCount': questionsCount,
        'correctCount': correctCount,
        'course': course,
        'topic': topic,
        'questionType': questionType,
        'createdAt': FieldValue.serverTimestamp(),
        if (items != null) 'items': items,
      }..removeWhere((k, v) => v == null);

      await dayDocRef.collection('attempts').add(data);
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error adding daily quiz attempt: $e');
      rethrow;
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      log('Error adding daily quiz attempt: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  /// Returns up to [limit] of the most recent quiz attempts across all days for
  /// the given [uid]. Attempts are ordered ascending by start time so that
  /// visualizations can plot a natural chronology.
  Future<List<Map<String, dynamic>>> getRecentQuizAttempts({
    required String uid,
    int limit = 20,
  }) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_getRecentQuizAttempts');
    trace?.putAttribute('limit', limit.toString());
    await trace?.start();
    try {
      await _refreshAppCheckTokenIfNeeded();
      final attempts = <Map<String, dynamic>>[];

      final dayCol = _db
          .collection('users')
          .doc(uid)
          .collection('daily_attempts');

      final daySnapshots = await dayCol.get();
      final dayDocs = daySnapshots.docs..sort((a, b) => b.id.compareTo(a.id));

      for (final dayDoc in dayDocs.take(30)) {
        final attemptsSnap =
            await dayDoc.reference
                .collection('attempts')
                .orderBy('createdAt', descending: true)
                .limit(limit)
                .get();

        for (final doc in attemptsSnap.docs) {
          final data = doc.data();

          DateTime? startedAt;
          final startedRaw = data['startedAt'];
          if (startedRaw is Timestamp) {
            startedAt = startedRaw.toDate();
          } else if (startedRaw is DateTime) {
            startedAt = startedRaw;
          }

          if (startedAt == null) {
            final createdRaw = data['createdAt'];
            if (createdRaw is Timestamp) {
              startedAt = createdRaw.toDate();
            } else if (createdRaw is DateTime) {
              startedAt = createdRaw;
            }
          }

          startedAt ??= _parseDayDocId(dayDoc.id);

          if (startedAt == null) continue;

          final questionsCount = (data['questionsCount'] as num?)?.toInt() ?? 0;
          final correctCount = (data['correctCount'] as num?)?.toInt() ?? 0;
          final elapsedMs = (data['elapsedMs'] as num?)?.toInt();

          String? subject;
          final dynamic courseRaw = data['course'];
          if (courseRaw is Map<String, dynamic>) {
            final title = courseRaw['title'];
            if (title is String && title.trim().isNotEmpty) {
              subject = title.trim();
            } else {
              final name = courseRaw['name'];
              if (name is String && name.trim().isNotEmpty) {
                subject = name.trim();
              }
            }
          } else if (courseRaw is String && courseRaw.trim().isNotEmpty) {
            subject = courseRaw.trim();
          }

          subject ??= 'Unknown course';
          final topic = (data['topic'] as String?)?.trim();

          attempts.add({
            'startedAt': startedAt,
            'questionsCount': questionsCount,
            'correctCount': correctCount,
            'elapsedMs': elapsedMs,
            'subject': subject,
            'topic': topic,
          });

          if (attempts.length >= limit) break;
        }

        if (attempts.length >= limit) break;
      }

      attempts.sort((a, b) {
        final aDate = a['startedAt'] as DateTime;
        final bDate = b['startedAt'] as DateTime;
        return aDate.compareTo(bDate);
      });

      if (attempts.length > limit) {
        return attempts.sublist(attempts.length - limit);
      }
      return attempts;
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      log('Error fetching recent quiz attempts: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  String _formatDayId(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime? _parseDayDocId(String dayId) {
    try {
      final parts = dayId.split('-');
      if (parts.length != 3) return null;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  /// Compute ISO-like week of month (1-5) for a given date.
  int _weekOfMonth(DateTime date) {
    final firstOfMonth = DateTime(date.year, date.month, 1);
    final offset = firstOfMonth.weekday % 7; // 0=Sunday, 1=Monday ...
    return ((date.day + offset - 1) ~/ 7) + 1; // 1-based week index
  }

  /// Returns 7-length list of counts for the selected week of a month.
  /// Index 0..6 correspond to Mon..Sun labels on UI (or first-letter labels).
  Future<List<int>> getDailyCountsForWeek({
    required String uid,
    required DateTime anyDayInWeek,
  }) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_getDailyCountsForWeek');
    await trace?.start();
    try {
      await _refreshAppCheckTokenIfNeeded();

      // Determine week bounds within the month
      final year = anyDayInWeek.year;
      final month = anyDayInWeek.month;

      // Start from the Monday of that week (or Sunday depending on weekday)
      // We'll scan only days inside the same month for simplicity
      final weekIndex = _weekOfMonth(anyDayInWeek);
      final firstOfMonth = DateTime(year, month, 1);
      final startDay = 1 + (weekIndex - 1) * 7 - ((firstOfMonth.weekday % 7));
      final start = DateTime(
        year,
        month,
        startDay.clamp(1, DateTime(year, month + 1, 0).day),
      );

      final List<int> counts = List<int>.filled(7, 0);

      // Iterate up to 7 days from start, bounded by month
      for (int i = 0; i < 7; i++) {
        final d = DateTime(year, month, start.day + i);
        if (d.month != month) break;
        final String dayId = _formatDayId(d);
        final dayDocRef = _db
            .collection('users')
            .doc(uid)
            .collection('daily_attempts')
            .doc(dayId);
        final attemptsSnap = await dayDocRef.collection('attempts').get();
        counts[i] = attemptsSnap.docs.length;
      }
      return counts;
    } catch (e) {
      log('Error fetching weekly counts: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  /// Returns 4-length list for a month: counts per week 1..4.
  /// A 5th week is folded into week 4 to keep the axis 1..4 with a tail.
  Future<List<int>> getWeeklyCountsForMonth({
    required String uid,
    required int year,
    required int month,
  }) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_getWeeklyCountsForMonth');
    await trace?.start();
    try {
      await _refreshAppCheckTokenIfNeeded();
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final List<int> counts = List<int>.filled(4, 0);

      for (int day = 1; day <= daysInMonth; day++) {
        final d = DateTime(year, month, day);
        final week = _weekOfMonth(d); // 1..5
        final weekIndex = week >= 4 ? 3 : (week - 1); // fold 5th into 4th
        final String dayId = _formatDayId(d);
        final dayDocRef = _db
            .collection('users')
            .doc(uid)
            .collection('daily_attempts')
            .doc(dayId);
        final attemptsSnap = await dayDocRef.collection('attempts').get();
        counts[weekIndex] = counts[weekIndex] + attemptsSnap.docs.length;
      }
      return counts;
    } catch (e) {
      log('Error fetching monthly weekly counts: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  /// Returns a 24-length list where each index represents the hour of day
  /// (0-23) and the value is the number of quiz attempts that started in
  /// that hour for the given [day]. If nothing is found, returns zeros.
  Future<List<int>> getHourlyQuizAttempts({
    required String uid,
    required DateTime day,
  }) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_getHourlyQuizAttempts');
    await trace?.start();
    try {
      await _refreshAppCheckTokenIfNeeded();
      final String dayId = _formatDayId(day);
      final DocumentReference<Map<String, dynamic>> dayDocRef = _db
          .collection('users')
          .doc(uid)
          .collection('daily_attempts')
          .doc(dayId);

      final dayDoc = await dayDocRef.get();
      if (!dayDoc.exists) {
        return List<int>.filled(24, 0);
      }

      final attemptsSnap = await dayDocRef.collection('attempts').get();

      final List<int> counts = List<int>.filled(24, 0);
      for (final doc in attemptsSnap.docs) {
        try {
          DateTime? started;
          final data = doc.data();
          final dynamic startedRaw = data['startedAt'];
          if (startedRaw is Timestamp) {
            started = startedRaw.toDate();
          } else if (startedRaw is DateTime) {
            started = startedRaw;
          } else {
            final dynamic createdRaw = data['createdAt'];
            if (createdRaw is Timestamp) started = createdRaw.toDate();
          }
          if (started != null) {
            final int hour = started.hour;
            if (hour >= 0 && hour < 24) counts[hour] = counts[hour] + 1;
          }
        } catch (e) {
          // Skip malformed rows but continue aggregation
          if (kIsWeb) {
            // no-op
          }
        }
      }
      return counts;
    } catch (e) {
      log('Error fetching hourly quiz attempts: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  /// Returns the course title of the most recent quiz attempt for a user, or null
  /// if none exist. It first finds the latest day document by ID (YYYY-MM-DD), then
  /// the latest attempt by createdAt within that day.
  Future<String?> getMostRecentQuizCourseTitle(String uid) async {
    try {
      // Fetch all day documents and compute the latest by ID locally
      // (IDs are YYYY-MM-DD so lexicographic max is the most recent)
      final dayCol = _db
          .collection('users')
          .doc(uid)
          .collection('daily_attempts');
      final dayDocs = await dayCol.get();

      if (dayDocs.docs.isEmpty) return null;
      final docs = dayDocs.docs;
      QueryDocumentSnapshot<Map<String, dynamic>> latestDayDoc = docs.first;
      for (final d in docs.skip(1)) {
        if (d.id.compareTo(latestDayDoc.id) >= 0) {
          latestDayDoc = d;
        }
      }
      final dayRef = latestDayDoc.reference;

      // Within the latest day, pick the latest attempt by createdAt
      final latestAttemptSnapshot =
          await dayRef
              .collection('attempts')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

      if (latestAttemptSnapshot.docs.isEmpty) return null;
      final data = latestAttemptSnapshot.docs.first.data();
      final dynamic courseField = data['course'];
      if (courseField is Map<String, dynamic>) {
        return courseField['title'] as String?;
      }
      if (courseField is String) {
        return courseField;
      }
      return null;
    } catch (e) {
      log('Error fetching most recent quiz course: $e');
      return null;
    }
  }

  Future<CourseInfo?> getMostRecentQuizCourse(String uid) async {
    try {
      // Fetch all day documents and compute the latest by ID locally
      // (IDs are YYYY-MM-DD so lexicographic max is the most recent)
      final dayCol = _db
          .collection('users')
          .doc(uid)
          .collection('daily_attempts');
      final dayDocs = await dayCol.get();

      if (dayDocs.docs.isEmpty) {
        log("No daily attempts found for user $uid");
        return null;
      }
      final docs = dayDocs.docs;
      QueryDocumentSnapshot<Map<String, dynamic>> latestDayDoc = docs.first;
      for (final d in docs.skip(1)) {
        if (d.id.compareTo(latestDayDoc.id) >= 0) {
          latestDayDoc = d;
        }
      }
      final dayRef = latestDayDoc.reference;

      // Within the latest day, pick the latest attempt by createdAt
      final latestAttemptSnapshot =
          await dayRef
              .collection('attempts')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();

      if (latestAttemptSnapshot.docs.isEmpty) {
        log("No attempts found for the latest day for user $uid");
        return null;
      }
      final data = latestAttemptSnapshot.docs.first.data();

      // Extract a course title from the attempt, handling both legacy string
      // and newer map formats. We then hydrate it from course_data to ensure
      // topics/tags are populated.
      String? title;
      final dynamic rawCourse = data['course'];
      if (rawCourse is Map<String, dynamic>) {
        title = rawCourse['title'] as String?;
      } else if (rawCourse is String) {
        title = rawCourse;
      }

      if (title == null || title.isEmpty) {
        log("Most recent attempt has no course title: $rawCourse");
        return null;
      }

      // Hydrate using the catalog in course_data
      try {
        final List<CourseInfo> all = await getAllCourseData();
        if (all.isNotEmpty) {
          final CourseInfo found = all.firstWhere(
            (c) => c.title == title,
            orElse: () => all.first,
          );
          return found;
        }
      } catch (e) {
        // If hydration fails, fall back to constructing from raw map if present
        log('Hydration from course_data failed: $e');
      }

      // Fallback: if we only have a map, return it; otherwise null.
      if (rawCourse is Map<String, dynamic>) {
        return CourseInfo.fromJson(
          rawCourse,
        ); // Keep fromJson if it's already a processed Map
      }
      return null;
    } catch (e, s) {
      log('Error fetching most recent quiz course object: $e', stackTrace: s);
      return null;
    }
  }

  // ===== Academic Calendar APIs =====
  // Firestore shape:
  // collection('academic_calendar_sessions')
  //   doc('<session_id>') e.g. '2025_2026'
  //     collection('events')
  //       doc(auto)
  //         {
  //           title: '<weekday>', // lowercased, optional for client
  //           course: '<event text>'
  //           semester: 'first' | 'second' | 'next_session'
  //           session: '2025/2026'
  //           start_time: Timestamp | ISO string
  //           end_time: Timestamp | ISO string
  //           event_type: 'academic_calendar'
  //           all_day: true
  //         }
  Future<List<Map<String, dynamic>>> getAcademicCalendarEvents({
    required String sessionId,
  }) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_getAcademicCalendarEvents');
    trace?.putAttribute('session', sessionId);
    await trace?.start();
    try {
      await _refreshAppCheckTokenIfNeeded();
      final colRef = _db
          .collection('academic_calendar_sessions')
          .doc(sessionId)
          .collection('events')
          .orderBy('start_time');
      final snapshot = await colRef.get();
      return snapshot.docs.map((d) => ({...d.data(), 'id': d.id})).toList();
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error fetching academic calendar: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  Future<void> replaceAcademicCalendarSession({
    required String sessionId,
    required List<Map<String, dynamic>> entries,
  }) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace(
              'firestore_replaceAcademicCalendarSession',
            );
    trace?.putAttribute('session', sessionId);
    await trace?.start();
    try {
      final colRef = _db
          .collection('academic_calendar_sessions')
          .doc(sessionId)
          .collection('events');
      final existing = await colRef.get();
      final batch = _db.batch();
      for (final d in existing.docs) {
        batch.delete(d.reference);
      }
      for (final entry in entries) {
        final data = Map<String, dynamic>.from(entry)..remove('id');
        if (data['title'] is String) {
          data['title'] = (data['title'] as String).toLowerCase();
        }
        batch.set(colRef.doc(), data);
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error replacing academic calendar: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }

  Future<void> markDailyQuizCompleted(String uid) async {
    final trace =
        kIsWeb
            ? null
            : _performance?.newTrace('firestore_markDailyQuizCompleted');
    trace?.putAttribute('uid', uid);
    await trace?.start();
    try {
      await _refreshAppCheckTokenIfNeeded();
      final String dayId = _formatDayId(DateTime.now());
      final DocumentReference<Map<String, dynamic>> dayDocRef = _db
          .collection('users')
          .doc(uid)
          .collection('daily_attempts')
          .doc(dayId);

      await dayDocRef.set({
        'dayId': dayId,
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      trace?.putAttribute('error', e.code);
      log('Firebase error marking daily quiz completed: $e');
      rethrow;
    } finally {
      await trace?.stop();
    }
  }
}
