import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vens_hub/core/router/app_router.dart';
import 'package:vens_hub/core/router/routes.dart';
import 'package:vens_hub/presentation/widgets/common/utility_widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class MobileOnboardingPage extends StatefulWidget {
  const MobileOnboardingPage({super.key});

  @override
  State<MobileOnboardingPage> createState() => _MobileOnboardingPageState();
}

class _MobileOnboardingPageState extends State<MobileOnboardingPage>
    with TickerProviderStateMixin {
  late AnimationController _mainAnimationController;
  late AnimationController _scrollingMessageController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  int _currentMessageIndex = 0;
  final List<String> _scrollingMessages = [
    "AI-powered quizzes that adapt to you.",
    "Upload textbooks & study at your pace.",
    "Track your streaks & daily progress.",
    "Master engineering concepts daily.",
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startScrollingMessages();
  }

  void _initializeAnimations() {
    // Main animation controller
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Scrolling message controller
    _scrollingMessageController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    // Fade animation
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainAnimationController, curve: Curves.easeOut),
    );

    // Slide animation
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _mainAnimationController.forward();
  }

  void _startScrollingMessages() {
    _scrollingMessageController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentMessageIndex =
              (_currentMessageIndex + 1) % _scrollingMessages.length;
        });
        _scrollingMessageController.reset();
        _scrollingMessageController.forward();
      }
    });
    _scrollingMessageController.forward();
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _scrollingMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallDevice = size.height < 600;

    return Scaffold(
      body: Stack(
        children: [
          const ParallaxAnimation(),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.08),
              child: Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildAnimatedLogo(size),
                              SizedBox(height: size.height * 0.04),
                              _buildAnimatedTitle(size),
                              SizedBox(height: size.height * 0.03),
                              _buildScrollingMessage(size),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: isSmallDevice ? 2 : 2,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFeatureIcons(size),
                          _buildActionButtons(size),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogo(Size size) {
    return SizedBox(
      width: size.width * 0.2,
      height: size.width * 0.2,
      child: SvgPicture.asset('assets/svg/5_inlined.svg', fit: BoxFit.contain),
    );
  }

  Widget _buildAnimatedTitle(Size size) {
    return Column(
      children: [
        Text(
          'Engineering Hub',
          style: GoogleFonts.rubik(
            textStyle: TextStyle(
              fontSize: size.width * 0.08,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ),
        SizedBox(height: size.height * 0.01),
        Container(width: size.width * 0.12, height: 2, color: Colors.black87),
      ],
    );
  }

  Widget _buildScrollingMessage(Size size) {
    return SizedBox(
      height: size.height * 0.05,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.5),
              end: const Offset(0, 0),
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Text(
          _scrollingMessages[_currentMessageIndex],
          key: ValueKey<int>(_currentMessageIndex),
          textAlign: TextAlign.center,
          style: GoogleFonts.rubik(
            textStyle: TextStyle(
              fontSize: size.width * 0.045,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcons(Size size) {
    final icons = [
      'assets/svg/problem_solving_bro_green.svg',
      'assets/svg/mathematics_bro_green.svg',
      'assets/svg/borwn_students(1).svg',
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children:
          icons.map((iconPath) {
            return Container(
              width: size.width * 0.16,
              height: size.width * 0.16,
              padding: EdgeInsets.all(size.width * 0.02),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SvgPicture.asset(iconPath, fit: BoxFit.contain),
            );
          }).toList(),
    );
  }

  Widget _buildActionButtons(Size size) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size.width * 0.8,
          child: buildAppActionButton(
            context,
            text: "Get Started",
            onPressed: () => AppRouter.navigateTo(AppRoutes.signUp),
            backgroundColor: Colors.black87,
          ),
        ),
        SizedBox(height: size.height * 0.02),
        TextButton(
          onPressed: () => AppRouter.navigateTo(AppRoutes.signIn),
          child: Text(
            'Already have an account? Sign in',
            style: GoogleFonts.rubik(
              textStyle: TextStyle(
                fontSize: size.width * 0.038,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ParallaxAnimation extends StatefulWidget {
  const ParallaxAnimation({super.key});

  @override
  State<ParallaxAnimation> createState() => _ParallaxAnimationState();
}

class _ParallaxAnimationState extends State<ParallaxAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _mousePosition = Offset.zero;

  final List<String> _svgAssets = [
    'assets/svg/5_inlined.svg',
    'assets/svg/transp_11_inlined.svg',
    // Add more SVG assets here
  ];

  final List<double> _parallaxFactors = [0.1, 0.3, 0.6, 0.9, 0.2, 0.4];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        setState(() {
          _mousePosition = event.localPosition;
        });
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            children: List.generate(_svgAssets.length, (index) {
              final parallaxFactor =
                  _parallaxFactors[index % _parallaxFactors.length];
              final animationValue = _controller.value;
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;

              // Calculate parallax offset
              final parallaxX =
                  (_mousePosition.dx - screenWidth / 2) * parallaxFactor;
              final parallaxY =
                  (_mousePosition.dy - screenHeight / 2) * parallaxFactor;

              // Calculate floating animation position
              final angle =
                  2 * math.pi * (animationValue + index / _svgAssets.length);
              final floatingX = math.cos(angle) * 20 * (1 - parallaxFactor);
              final floatingY = math.sin(angle) * 20 * (1 - parallaxFactor);

              // Initial random position
              final initialX =
                  (math.Random(index).nextDouble() - 0.5) * screenWidth * 0.8;
              final initialY =
                  (math.Random(index).nextDouble() - 0.5) * screenHeight * 0.8;

              return Positioned(
                left: initialX + parallaxX + floatingX + screenWidth / 2,
                top: initialY + parallaxY + floatingY + screenHeight / 2,
                child: SvgPicture.asset(
                  _svgAssets[index],
                  width: 100 * (1 - parallaxFactor) + 50,
                  height: 100 * (1 - parallaxFactor) + 50,
                  colorFilter: ColorFilter.mode(
                    Colors.grey.withValues(alpha: 0.1),
                    BlendMode.srcIn,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
