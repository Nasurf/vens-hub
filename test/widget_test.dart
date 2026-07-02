import 'package:flutter_test/flutter_test.dart';

import 'package:vens_hub/core/router/routes.dart';

void main() {
  test('auth routes keep users in the direct auth flow', () {
    expect(AppRoutes.signIn, '/login');
    expect(AppRoutes.signUp, '/register');
    expect(AppRoutes.completeProfile, '/complete-profile');
    expect(AppRoutes.main, '/app');
  });
}
