import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStatusService {
  static const String _onboardingCompletedKey = 'onboarding_completed';

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, completed);
  }

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ??
        false; // Default to false if not set
  }
}
