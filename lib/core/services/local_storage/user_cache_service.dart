import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vens_hub/data/models/user_model.dart';

class UserCacheService {
  static const String _userCacheKey = 'cached_user_data';
  static const String _cacheTimestampKey = 'user_cache_timestamp';
  static const Duration _cacheValidityDuration = Duration(
    hours: 24,
  ); // Cache for 24 hours

  /// Cache user data locally
  Future<void> cacheUserData(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = jsonEncode(user.toJson());
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await prefs.setString(_userCacheKey, userJson);
      await prefs.setInt(_cacheTimestampKey, timestamp);

      log("UserCacheService: User data cached successfully");
    } catch (e) {
      log("UserCacheService: Error caching user data: $e");
    }
  }

  /// Get cached user data if it exists and is still valid
  Future<UserModel?> getCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userCacheKey);
      final timestamp = prefs.getInt(_cacheTimestampKey);

      if (userJson == null || timestamp == null) {
        log("UserCacheService: No cached user data found");
        return null;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      // Check if cache is still valid
      if (now.difference(cacheTime) > _cacheValidityDuration) {
        log("UserCacheService: Cached user data has expired");
        await clearCachedUserData();
        return null;
      }

      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      final user = UserModel.fromJson(userMap);

      log(
        "UserCacheService: Retrieved cached user data for ${user.firstName} ${user.lastName}",
      );
      return user;
    } catch (e) {
      log("UserCacheService: Error retrieving cached user data: $e");
      await clearCachedUserData();
      return null;
    }
  }

  /// Clear cached user data
  Future<void> clearCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userCacheKey);
      await prefs.remove(_cacheTimestampKey);
      log("UserCacheService: Cached user data cleared");
    } catch (e) {
      log("UserCacheService: Error clearing cached user data: $e");
    }
  }

  /// Check if cached data exists and is valid
  Future<bool> hasValidCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userCacheKey);
      final timestamp = prefs.getInt(_cacheTimestampKey);

      if (userJson == null || timestamp == null) {
        return false;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      return now.difference(cacheTime) <= _cacheValidityDuration;
    } catch (e) {
      log("UserCacheService: Error checking cache validity: $e");
      return false;
    }
  }

  /// Get cache age in hours
  Future<double?> getCacheAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);

      if (timestamp == null) {
        return null;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      return now.difference(cacheTime).inMinutes / 60.0;
    } catch (e) {
      log("UserCacheService: Error getting cache age: $e");
      return null;
    }
  }
}
