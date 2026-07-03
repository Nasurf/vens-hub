// Main screen: bottom nav + sidebar routing
import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:vens_hub/presentation/blocs/home/home_controller.dart';
import 'package:vens_hub/presentation/screens/home/main_screen/main_screen.desktop.dart';
import 'package:vens_hub/presentation/screens/home/main_screen/main_screen.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Initialize the HomeController here to ensure it's available
  // to both mobile and desktop child widgets.

  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(
      mobile: MobileMainScreen(),
      desktop: DesktopMainScreen(),
    );
  }
}
