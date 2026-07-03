import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:shared_preferences/shared_preferences.dart';

/// Stores and retrieves metadata about the most recent quiz the user took.
///
/// Keys are scoped per-user to avoid collisions across different accounts
/// on the same device, mirroring the pattern used in `StreakService`.
class RecentQuizService {
  static const String _lastCourseTitleKey = 'recent_quiz_course_title';
  static const String _lastTopicKey = 'recent_quiz_topic';
  static const String _lastStartedAtKey = 'recent_quiz_started_at'; // epoch ms

  final fb_auth.FirebaseAuth _auth;

  RecentQuizService({fb_auth.FirebaseAuth? auth})
    : _auth = auth ?? fb_auth.FirebaseAuth.instance;

  String _scopedKey(String base) =>
      '${base}_${_auth.currentUser?.uid ?? 'anon'}';

  Future<void> saveMostRecent({
    required String courseTitle,
    String? topic,
    required DateTime startedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scopedKey(_lastCourseTitleKey), courseTitle);
    if (topic != null) {
      await prefs.setString(_scopedKey(_lastTopicKey), topic);
    }
    await prefs.setInt(
      _scopedKey(_lastStartedAtKey),
      startedAt.millisecondsSinceEpoch,
    );
  }

  Future<String?> getMostRecentCourseTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_lastCourseTitleKey));
  }

  Future<String?> getMostRecentTopic() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_lastTopicKey));
  }

  Future<DateTime?> getMostRecentStartedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final int? epoch = prefs.getInt(_scopedKey(_lastStartedAtKey));
    if (epoch == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch);
  }
}
