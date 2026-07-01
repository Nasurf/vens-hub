import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

/// Tracks simple once-per-day cache markers.
class DailyCacheService {
  static const String _prefix = 'daily_cache_key_';

  /// Returns true when data identified by [key] should be refreshed today.
  Future<bool> shouldRefresh(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('$_prefix$key');
      if (stored == null) return true;

      final lastRefresh = DateTime.tryParse(stored);
      if (lastRefresh == null) return true;

      final today = DateTime.now();
      final normalizedToday = DateTime(today.year, today.month, today.day);
      final normalizedStored = DateTime(
        lastRefresh.year,
        lastRefresh.month,
        lastRefresh.day,
      );

      return normalizedStored.isBefore(normalizedToday);
    } catch (e) {
      log('DailyCacheService: error checking refresh state for $key: $e');
      return true;
    }
  }

  /// Record that [key] was refreshed today.
  Future<void> markRefreshed(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final normalizedToday =
          DateTime(today.year, today.month, today.day).toIso8601String();
      await prefs.setString('$_prefix$key', normalizedToday);
    } catch (e) {
      log('DailyCacheService: error marking refresh for $key: $e');
    }
  }

  /// Remove any stored refresh marker for [key].
  Future<void> invalidate(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (e) {
      log('DailyCacheService: error invalidating key $key: $e');
    }
  }

  /// Clears every stored daily marker.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_prefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      log('DailyCacheService: error clearing markers: $e');
    }
  }
}
