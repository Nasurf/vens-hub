// Study page: textbooks, theory questions, problem sets
import 'package:flutter/material.dart';
import 'package:vens_hub/presentation/screens/study/study_page.desktop.dart';
import 'package:vens_hub/presentation/screens/study/study_page.mobile.dart';
import 'package:vens_hub/presentation/widgets/common/app_layout.dart';

class StudyPage extends StatelessWidget {
  const StudyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLayoutBuilder(
      mobile: MobileStudyPage(),
      desktop: DesktopStudyPage(),
    );
  }
}
