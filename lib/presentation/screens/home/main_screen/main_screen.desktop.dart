import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/presentation/screens/home/home_page/home_page.desktop.dart';
import 'package:vens_hub/presentation/screens/profile/profile_screen.dart';
import 'package:vens_hub/presentation/screens/schedule/schedule_page.desktop.dart';
import 'package:vens_hub/presentation/screens/study/study_page.desktop.dart';
import 'package:vens_hub/presentation/screens/hub/hub_page.desktop.dart';
import 'package:vens_hub/presentation/screens/hub/hub_page.mobile.dart'
    show HubController;

import '../../../widgets/sidebar/custom_sidebar.dart';

class DesktopMainScreen extends StatefulWidget {
  const DesktopMainScreen({super.key});

  @override
  State<DesktopMainScreen> createState() => _DesktopMainScreenState();
}

class _DesktopMainScreenState extends State<DesktopMainScreen> {
  final List<Widget> pages = [
    DesktopHomePage(),
    DesktopScheduleScreen(),
    DesktopHubPage(),
    DesktopStudyPage(),
    ProfileScreen(), // Changed from DesktopProfileScreen() to ProfileScreen()
  ];
  // Removed _navDestinations as we're now using CustomSidebar
  late final PageController _pageController;
  final HomeController _homeController = Get.find<HomeController>();

  @override
  void initState() {
    super.initState();
    // Ensure HubController is available
    if (!Get.isRegistered<HubController>()) {
      Get.put(HubController());
    }

    _pageController = PageController(
      initialPage: _homeController.currentPage.value,
    );

    // Listen to currentPage changes and jump PageView accordingly
    ever<int>(_homeController.currentPage, (index) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content area (fills entire space)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 76.0,
                ), // leave room for floating sidebar (60 + 8 + 8)
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    _homeController.currentPage.value = index;
                  },
                  children: pages,
                ),
              ),
            ),

            // Floating sidebar positioned on the left with margin
            Positioned(
              left: 8,
              top: 8,
              bottom: 8,
              child: SizedBox(width: 60, child: CustomSidebar()),
            ),
          ],
        ),
      ),
    );
  }
}
