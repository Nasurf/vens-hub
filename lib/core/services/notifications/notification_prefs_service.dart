import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPrefsService extends GetxController {
  static const _kEnabled = 'notif_enabled';
  static const _kDailyGeneral = 'notif_daily_general';
  static const _kClassReminders = 'notif_class_reminders';

  final RxBool notificationsEnabled = true.obs;
  final RxBool dailyGeneralEnabled = true.obs;
  final RxBool classRemindersEnabled = true.obs;

  Future<NotificationPrefsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    notificationsEnabled.value = prefs.getBool(_kEnabled) ?? true;
    dailyGeneralEnabled.value = prefs.getBool(_kDailyGeneral) ?? true;
    classRemindersEnabled.value = prefs.getBool(_kClassReminders) ?? true;
    return this;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    notificationsEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }

  Future<void> setDailyGeneralEnabled(bool value) async {
    dailyGeneralEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDailyGeneral, value);
  }

  Future<void> setClassRemindersEnabled(bool value) async {
    classRemindersEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kClassReminders, value);
  }
}
