import 'package:flutter/material.dart';
import 'package:vens_hub/presentation/screens/profile/profile_screen.desktop.dart';
import 'package:vens_hub/presentation/screens/profile/profile_screen.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';
import 'package:get/get.dart';
import 'package:vens_hub/core/services/app/privacy_service.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback? onOpenMenu;
  const ProfileScreen({super.key, this.onOpenMenu});

  @override
  Widget build(BuildContext context) {
    // Ensure PrivacyService is registered once and reused
    if (!Get.isRegistered<PrivacyService>()) {
      Get.put(PrivacyService());
    }

    return AppLayoutBuilder(
      mobile: MobileProfileScreen(),
      desktop: DesktopProfileScreen(),
    );
  }
}
