import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vens_hub/data/models/course_info.dart';

class CourseCacheService {
  static const String _coursesKey = 'cached_course_catalog';
  static const String _timestampKey = 'cached_course_catalog_ts';
  static const Duration _cacheValidity = Duration(hours: 24);

  Future<void> cacheCourses(List<CourseInfo> courses) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> payload =
          courses.map((c) => c.toJson()).toList();
      await prefs.setString(_coursesKey, jsonEncode(payload));
      await prefs.setInt(_timestampKey, DateTime.now().millisecondsSinceEpoch);
      log('CourseCacheService: cached ${courses.length} courses');
    } catch (e) {
      log('CourseCacheService: error caching courses: $e');
    }
  }

  Future<List<CourseInfo>?> getCachedCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_coursesKey);
      final ts = prefs.getInt(_timestampKey);
      if (data == null || ts == null) return null;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(ts);
      if (DateTime.now().difference(cacheTime) > _cacheValidity) {
        await clearCache();
        return null;
      }

      final List<dynamic> decoded = jsonDecode(data) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => CourseInfo.fromJson(m))
          .toList();
    } catch (e) {
      log('CourseCacheService: error reading cached courses: $e');
      await clearCache();
      return null;
    }
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_coursesKey);
      await prefs.remove(_timestampKey);
      log('CourseCacheService: cache cleared');
    } catch (e) {
      log('CourseCacheService: error clearing cache: $e');
    }
  }

  Future<double?> cacheAgeHours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(_timestampKey);
      if (ts == null) return null;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      return DateTime.now().difference(dt).inMinutes / 60.0;
    } catch (_) {
      return null;
    }
  }
}
