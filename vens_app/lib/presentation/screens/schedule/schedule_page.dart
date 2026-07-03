// Schedule page: calendar with day, week, and agenda views
import 'package:flutter/material.dart';
import 'package:vens_hub/presentation/screens/schedule/schedule_page.desktop.dart';
import 'package:vens_hub/presentation/screens/schedule/schedule_page.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(
      mobile: MobileScheduleScreen(),
      desktop: DesktopScheduleScreen(),
    );
  }
}
