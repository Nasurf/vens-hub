import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vens_hub/data/models/course_info.dart';
import 'package:vens_hub/core/utils/app_logger.dart';

class CourseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<CourseInfo>> getAllCourses() async {
    try {
      final snapshot = await _firestore.collection('courses').get();
      if (snapshot.docs.isEmpty) {
        return [];
      }
      return snapshot.docs.map((doc) => CourseInfo.fromFirestore(doc)).toList();
    } catch (e) {
      // In a real app, you'd want more robust error handling
      AppLogger.e('Error fetching courses', error: e);
      return [];
    }
  }
}
