// Home page: adaptive layout with course cards and streak display
import 'package:flutter/material.dart';
import 'package:vens_hub/presentation/screens/home/home_page/home_page.desktop.dart';
import 'package:vens_hub/presentation/screens/home/home_page/home_page.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(
      mobile: MobileHomePage(),
      desktop: DesktopHomePage(),
    );
  }
}
