import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static const String _streakCountKey = 'streak_count';
  static const String _lastCompletionDateKey =
      'streak_last_completion_date'; // yyyy-MM-dd
  static const String _streakLongestKey = 'streak_longest';
  static const String _completionHistoryKey = 'streak_completion_history';
  static const int _maxStoredHistory = 120;

  final FirebaseFirestore _db;
  final fb_auth.FirebaseAuth _auth;

  StreakService({
    required FirebaseFirestore db,
    required fb_auth.FirebaseAuth auth,
  }) : _db = db,
       _auth = auth;

  String _scopedKey(String base) =>
      '${base}_${_auth.currentUser?.uid ?? 'anon'}';

  Future<int> getStreakCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scopedKey(_streakCountKey)) ?? 0; // local cached value
  }

  Future<String?> _getLastCompletionDateISO() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_scopedKey(_lastCompletionDateKey));
  }

  Future<void> _setLocal({
    required int count,
    required String lastIso,
    int? longest,
    List<String>? history,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_scopedKey(_streakCountKey), count);
    await prefs.setString(_scopedKey(_lastCompletionDateKey), lastIso);
    if (longest != null) {
      await prefs.setInt(_scopedKey(_streakLongestKey), longest);
    }
    if (history != null) {
      await prefs.setStringList(_scopedKey(_completionHistoryKey), history);
    }
  }

  Future<Map<String, dynamic>?> _getRemote() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    final int? count = (data[_streakCountKey] as num?)?.toInt();
    final String? lastIso = data[_lastCompletionDateKey] as String?;
    final int? longest = (data[_streakLongestKey] as num?)?.toInt();
    final List<String>? history =
        (data[_completionHistoryKey] as List<dynamic>?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    if (count == null &&
        lastIso == null &&
        longest == null &&
        history == null) {
      return null;
    }
    return {
      'count': count,
      'lastIso': lastIso,
      'longest': longest,
      'history': history,
    };
  }

  Future<void> _setRemote({
    required int count,
    required String lastIso,
    int? longest,
    List<String>? history,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final data = {
      _streakCountKey: count,
      _lastCompletionDateKey: lastIso,
      if (longest != null) _streakLongestKey: longest,
      if (history != null) _completionHistoryKey: history,
    };
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Future<bool> hasCompletedToday() async {
    final last = await _getLastCompletionDateISO();
    if (last == null) return false;
    final todayIso = _formatDate(DateTime.now());
    return last == todayIso;
  }

  Future<List<DateTime>> getCompletionHistory({int days = 30}) async {
    final isoHistory = await _getLocalHistoryIso();
    final List<DateTime> parsed = [];
    for (final iso in isoHistory) {
      try {
        parsed.add(_dateOnly(_parse(iso)));
      } catch (_) {}
    }
    parsed.sort();
    if (days <= 0) {
      return parsed;
    }
    final cutoff = _dateOnly(DateTime.now()).subtract(Duration(days: days - 1));
    return parsed.where((date) => !date.isBefore(cutoff)).toList();
  }

  /// Get weekly completion status for widget (Sat, Sun, Mon, Tue, Wed, Thu, Fri)
  /// Returns a map with day names and boolean completion status
  Future<Map<String, bool>> getWeeklyCompletionStatus() async {
    final now = DateTime.now();
    final today = _dateOnly(now);

    // Find the start of the current week (Saturday)
    // In Dart, DateTime.weekday: 1=Monday, 7=Sunday
    // We want: Saturday=start of week
    int daysFromSaturday = (today.weekday == 7) ? 1 : (today.weekday + 1);
    final weekStart = today.subtract(Duration(days: daysFromSaturday));

    // Get completion history for the past 7 days
    final history = await getCompletionHistory(days: 7);
    final completionSet = history.map((d) => _formatDate(d)).toSet();

    // Check each day of the week
    final result = <String, bool>{};
    final days = [
      'saturday',
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
    ];

    for (int i = 0; i < 7; i++) {
      final dayDate = weekStart.add(Duration(days: i));
      final dayIso = _formatDate(dayDate);
      result[days[i]] = completionSet.contains(dayIso);
    }

    return result;
  }

  /// Sync local and remote streaks into a consistent state for today.
  /// If the user missed at least one full day, reset to 0.
  Future<void> syncForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final String? localLastIso = prefs.getString(
      _scopedKey(_lastCompletionDateKey),
    );
    final int localCount = prefs.getInt(_scopedKey(_streakCountKey)) ?? 0;
    final List<String> localHistory = await _getLocalHistoryIso();

    final remote = await _getRemote();
    final String? remoteLastIso = remote?['lastIso'] as String?;
    final int remoteCount = (remote?['count'] as int?) ?? 0;
    final int remoteLongest = (remote?['longest'] as int?) ?? 0;
    final List<String> remoteHistory = _mergeHistorySets(
      remote?['history'] as List<String>?,
      null,
    );

    // Choose the most recent source as baseline
    String? baselineLastIso;
    int baselineCount = 0;
    int baselineLongest = remoteLongest;

    if (remoteLastIso != null &&
        (localLastIso == null ||
            _parse(remoteLastIso).isAfter(_parse(localLastIso)))) {
      baselineLastIso = remoteLastIso;
      baselineCount = remoteCount;
    } else if (localLastIso != null) {
      baselineLastIso = localLastIso;
      baselineCount = localCount;
    }

    final List<String> mergedHistory = _mergeHistorySets(
      localHistory,
      remoteHistory,
    );

    if (baselineLastIso == null) {
      if (mergedHistory.isEmpty) {
        // Nothing to sync yet
        return;
      }
      baselineLastIso = mergedHistory.first;
      baselineCount = mergedHistory.length == 1 ? 1 : baselineCount;
    }

    final int diffDays = _daysBetween(
      _parse(baselineLastIso),
      _dateOnly(DateTime.now()),
    );
    if (diffDays > 1) {
      baselineCount = 0; // Missed a day → reset
    }

    // Update local cache
    await _setLocal(
      count: baselineCount,
      lastIso: baselineLastIso,
      longest: baselineLongest,
      history: mergedHistory,
    );

    // Push to remote (if signed in)
    await _setRemote(
      count: baselineCount,
      lastIso: baselineLastIso,
      longest: baselineLongest == 0 ? null : baselineLongest,
      history: mergedHistory,
    );
  }

  /// Mark that the user completed a quiz today and update both local and remote streaks.
  Future<int> markCompletedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final String? localLastIso = prefs.getString(
      _scopedKey(_lastCompletionDateKey),
    );
    final int localCount = prefs.getInt(_scopedKey(_streakCountKey)) ?? 0;
    final List<String> localHistory = await _getLocalHistoryIso();

    final remote = await _getRemote();
    final String? remoteLastIso = remote?['lastIso'] as String?;
    final int remoteCount = (remote?['count'] as int?) ?? 0;
    final int remoteLongest = (remote?['longest'] as int?) ?? 0;
    final List<String> remoteHistory = _mergeHistorySets(
      remote?['history'] as List<String>?,
      null,
    );

    // Choose baseline (latest lastIso wins)
    String? lastIso = localLastIso;
    int count = localCount;
    int longest = remoteLongest;

    if (remoteLastIso != null &&
        (localLastIso == null ||
            _parse(remoteLastIso).isAfter(_parse(localLastIso)))) {
      lastIso = remoteLastIso;
      count = remoteCount;
    }

    final String todayIso = _formatDate(DateTime.now());
    List<String> history = _mergeHistorySets(localHistory, remoteHistory);
    history = _insertHistoryIso(history, todayIso);

    if (lastIso == null) {
      // First ever completion
      count = 1;
      lastIso = todayIso;
    } else {
      final int diffDays = _daysBetween(
        _parse(lastIso),
        _dateOnly(DateTime.now()),
      );
      if (diffDays == 0) {
        // Already completed today; keep existing count
        await _setLocal(
          count: count,
          lastIso: lastIso,
          longest: longest,
          history: history,
        );
        await _setRemote(
          count: count,
          lastIso: lastIso,
          longest: longest == 0 ? null : longest,
          history: history,
        );
        return count;
      } else if (diffDays == 1) {
        count = count + 1;
        lastIso = todayIso;
      } else {
        // Missed one or more days → reset to 1
        count = 1;
        lastIso = todayIso;
      }
    }

    // Track longest streak
    if (count > longest) {
      longest = count;
    }

    await _setLocal(
      count: count,
      lastIso: lastIso,
      longest: longest,
      history: history,
    );
    await _setRemote(
      count: count,
      lastIso: lastIso,
      longest: longest,
      history: history,
    );
    return count;
  }

  Future<void> clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scopedKey(_streakCountKey));
    await prefs.remove(_scopedKey(_lastCompletionDateKey));
    await prefs.remove(_scopedKey(_streakLongestKey));
    await prefs.remove(_scopedKey(_completionHistoryKey));
  }

  Future<List<String>> _getLocalHistoryIso() async {
    final prefs = await SharedPreferences.getInstance();
    final entries =
        prefs.getStringList(_scopedKey(_completionHistoryKey)) ?? <String>[];
    final set = <String>{};
    for (final entry in entries) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) continue;
      set.add(trimmed);
    }
    final list = set.toList()..sort((a, b) => b.compareTo(a));
    if (list.length > _maxStoredHistory) {
      list.removeRange(_maxStoredHistory, list.length);
    }
    return list;
  }

  List<String> _mergeHistorySets(List<String>? a, List<String>? b) {
    final set = <String>{};
    if (a != null) {
      set.addAll(a.where((e) => e.trim().isNotEmpty));
    }
    if (b != null) {
      set.addAll(b.where((e) => e.trim().isNotEmpty));
    }
    final list = set.toList()..sort((x, y) => y.compareTo(x));
    if (list.length > _maxStoredHistory) {
      list.removeRange(_maxStoredHistory, list.length);
    }
    return list;
  }

  List<String> _insertHistoryIso(List<String> base, String iso) {
    final sanitized = iso.trim();
    if (sanitized.isEmpty) return base;
    final list = base.toList();
    list.remove(sanitized);
    list.add(sanitized);
    list.sort((a, b) => b.compareTo(a));
    if (list.length > _maxStoredHistory) {
      list.removeRange(_maxStoredHistory, list.length);
    }
    return list;
  }

  static String _formatDate(DateTime dt) {
    final d = _dateOnly(dt);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static DateTime _parse(String iso) => DateTime.parse(iso);

  static int _daysBetween(DateTime from, DateTime to) =>
      to.difference(_dateOnly(from)).inDays;
}
