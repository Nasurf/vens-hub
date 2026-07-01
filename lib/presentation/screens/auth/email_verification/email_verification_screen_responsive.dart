import 'package:flutter/material.dart';
import 'package:vens_hub/core/utils/responsive_utils.dart';
import 'email_verification_screen.dart';

class ResponsiveEmailVerificationScreen extends StatelessWidget {
  const ResponsiveEmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      mobile: (context) => const EmailVerificationScreen(),
      desktop: (context) => const EmailVerificationScreen(),
    );
  }
}
