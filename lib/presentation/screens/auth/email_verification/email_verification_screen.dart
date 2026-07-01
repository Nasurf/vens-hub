import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:vens_hub/presentation/widgets/common/app_notification.dart';
import 'package:vens_hub/core/services/auth/auth_service.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_event.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_state.dart';
import 'package:vens_hub/core/router/routes.dart'; // Assuming you have a routes file for navigation
import 'package:vens_hub/core/di/injection_container.dart' as di;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  // Periodically check verification to improve UX (particularly on web)
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    // On web, if the page is opened directly with an oobCode, apply it here as a fallback
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final qp = Uri.base.queryParameters;
          final oob = qp['oobCode'];
          if (oob != null && oob.isNotEmpty) {
            try {
              await fb_auth.FirebaseAuth.instance.checkActionCode(oob);
              await fb_auth.FirebaseAuth.instance.applyActionCode(oob);
            } catch (_) {
              // Even if apply fails (already used/expired), user's email may already be verified
            } finally {
              try {
                await fb_auth.FirebaseAuth.instance.currentUser?.reload();
              } catch (_) {}
              try {
                await fb_auth.FirebaseAuth.instance.currentUser?.getIdToken(
                  true,
                );
              } catch (_) {}
              if (mounted) {
                context.read<AuthBloc>().add(AuthCheckEmailVerification());
              }
            }
          }
        } catch (_) {}
      });
    }
    // Poll less frequently to reduce background events
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        context.read<AuthBloc>().add(AuthCheckEmailVerification());
      }
    });
  }

  final authService = di.sl<AuthService>();

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          // User is authenticated and email is verified
          Get.offAllNamed(AppRoutes.main);
        }
        // Suppress periodic failure popups here; handled in inner widget on manual checks
      },
      child: Scaffold(body: SafeArea(child: _EmailVerificationBody())),
    );
  }
}

class _EmailVerificationBody extends StatefulWidget {
  @override
  State<_EmailVerificationBody> createState() => _EmailVerificationBodyState();
}

class _EmailVerificationBodyState extends State<_EmailVerificationBody> {
  bool _resending = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  bool _manualCheckRequested = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        setState(() => _cooldown = 0);
        t.cancel();
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailureState) {
          final msg = state.message;
          final isPending = msg.toLowerCase().contains('not verified');
          // Only show popup on manual checks or for non-pending errors
          if (_manualCheckRequested || !isPending) {
            AppNotifier.error(
              context: context,
              title: 'Verification',
              message: msg,
            );
          }
          _manualCheckRequested = false;
        }
      },
      builder: (context, state) {
        final isChecking = state is AuthEmailVerificationLoading;

        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.bottomLeft,
              child: IconButton(
                onPressed: () {
                  Feedback.forTap(context);
                  context.read<AuthBloc>().add(AuthSignOut());
                  Get.offAllNamed(AppRoutes.onBoarding);
                },
                icon: const Icon(Icons.arrow_back_ios_new),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Card(
                      elevation: 0,
                      color: colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Verify your email',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A verification email has been sent to your address. Please verify and then continue.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed:
                                    (_resending || _cooldown > 0)
                                        ? null
                                        : () async {
                                          Feedback.forTap(context);
                                          setState(() => _resending = true);
                                          context.read<AuthBloc>().add(
                                            AuthSendVerificationEmailRequested(),
                                          );
                                          await Future.delayed(
                                            const Duration(milliseconds: 400),
                                          );
                                          if (context.mounted) {
                                            setState(() => _resending = false);
                                            _startCooldown(60);
                                            AppNotifier.success(
                                              context: context,
                                              title: 'Email sent',
                                              message:
                                                  'We sent you a fresh verification link.',
                                            );
                                          }
                                        },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  child:
                                      _resending
                                          ? const SizedBox(
                                            key: ValueKey('resend_loading'),
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.6,
                                              color: Colors.white,
                                            ),
                                          )
                                          : Text(
                                            key: const ValueKey('resend_label'),
                                            _cooldown > 0
                                                ? 'Resend in ${_cooldown}s'
                                                : 'Resend Verification Email',
                                          ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed:
                                  isChecking
                                      ? null
                                      : () {
                                        Feedback.forTap(context);
                                        _manualCheckRequested = true;
                                        context.read<AuthBloc>().add(
                                          AuthCheckEmailVerification(),
                                        );
                                      },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child:
                                    isChecking
                                        ? const SizedBox(
                                          key: ValueKey('check_loading'),
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                        : const Text(
                                          key: ValueKey('check_label'),
                                          'I have verified my email',
                                        ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
