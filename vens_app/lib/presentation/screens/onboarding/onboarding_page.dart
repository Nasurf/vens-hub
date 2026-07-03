// Onboarding: welcome flow with feature showcase
import 'package:flutter/material.dart';
import 'package:vens_hub/presentation/screens/onboarding/onboarding_page.desktop.dart';
import 'package:vens_hub/presentation/screens/onboarding/onboarding_page.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(
      mobile: MobileOnboardingPage(),
      desktop: DesktopOnboardingPage(),
    );
  }
}
