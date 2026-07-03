import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:vens_hub/core/services/analytics/analytics_service.dart';
import 'package:vens_hub/core/services/crash_reporting/crashlytics_service.dart';
import 'package:vens_hub/core/services/performance/performance_service.dart';
import 'package:vens_hub/core/utils/app_logger.dart';

class PrivacyService extends GetxController {
  final _box = GetStorage();
  final _analyticsEnabledKey = 'analytics_enabled';
  final _crashlyticsEnabledKey = 'crashlytics_enabled';
  final _performanceEnabledKey = 'performance_enabled';

  // Reactive variables for privacy settings
  final _analyticsEnabled = true.obs;
  final _crashlyticsEnabled = true.obs;
  final _performanceEnabled = true.obs;

  @override
  void onInit() {
    super.onInit();
    _loadPrivacySettings();
  }

  Future<PrivacyService> init() async {
    await GetStorage.init();
    return this;
  }

  // Getters for reactive variables
  Rx<bool> get analyticsEnabledObs => _analyticsEnabled;
  Rx<bool> get crashlyticsEnabledObs => _crashlyticsEnabled;
  Rx<bool> get performanceEnabledObs => _performanceEnabled;

  void _loadPrivacySettings() {
    _analyticsEnabled.value = _box.read(_analyticsEnabledKey) ?? true;
    _crashlyticsEnabled.value = _box.read(_crashlyticsEnabledKey) ?? true;
    _performanceEnabled.value = _box.read(_performanceEnabledKey) ?? true;
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    await _box.write(_analyticsEnabledKey, enabled);
    _analyticsEnabled.value = enabled;

    try {
      await di.sl<AnalyticsService>().setAnalyticsCollectionEnabled(enabled);
      if (enabled) {
        await di.sl<AnalyticsService>().logEvent(
          name: 'analytics_consent_granted',
          parameters: {'timestamp': DateTime.now().toIso8601String()},
        );
      }
    } catch (e) {
      AppLogger.e('Error updating analytics settings', error: e);
    }
  }

  Future<void> setCrashlyticsEnabled(bool enabled) async {
    await _box.write(_crashlyticsEnabledKey, enabled);
    _crashlyticsEnabled.value = enabled;

    try {
      await di.sl<CrashlyticsService>().setCrashlyticsCollectionEnabled(
        enabled,
      );
      if (enabled) {
        await di.sl<AnalyticsService>().logEvent(
          name: 'crashlytics_consent_granted',
          parameters: {'timestamp': DateTime.now().toIso8601String()},
        );
      }
    } catch (e) {
      AppLogger.e('Error updating crashlytics settings', error: e);
    }
  }

  Future<void> setPerformanceEnabled(bool enabled) async {
    await _box.write(_performanceEnabledKey, enabled);
    _performanceEnabled.value = enabled;

    try {
      await di.sl<PerformanceService>().setPerformanceCollectionEnabled(
        enabled,
      );
      if (enabled) {
        await di.sl<AnalyticsService>().logEvent(
          name: 'performance_consent_granted',
          parameters: {'timestamp': DateTime.now().toIso8601String()},
        );
      }
    } catch (e) {
      AppLogger.e('Error updating performance settings', error: e);
    }
  }

  Map<String, bool> getAllPrivacySettings() {
    return {
      'analytics': _analyticsEnabled.value,
      'crashlytics': _crashlyticsEnabled.value,
      'performance': _performanceEnabled.value,
    };
  }

  Future<void> resetAllSettings() async {
    await setAnalyticsEnabled(true);
    await setCrashlyticsEnabled(true);
    await setPerformanceEnabled(true);
  }
}
