import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/onboarding/onboarding_prefs.dart';
import '../../core/theme/app_colors.dart';

/// Post-splash start screen — structure matched to the Atlas-style welcome mock.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _floatController;

  late final Animation<double> _collageFade;
  late final Animation<Offset> _collageSlide;
  late final Animation<double> _copyFade;
  late final Animation<Offset> _copySlide;
  late final Animation<double> _ctaFade;
  late final Animation<Offset> _ctaSlide;

  static const _loginTeal = Color(0xFF0F5C5B);
  static const _createPeach = Color(0xFFF3C9B5);

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat(reverse: true);

    _collageFade = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _collageSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));

    _copyFade = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.28, 0.7, curve: Curves.easeOut),
    );
    _copySlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.28, 0.75, curve: Curves.easeOutCubic),
    ));

    _ctaFade = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    _ctaSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    _enterController.forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _goToLogin() async {
    await OnboardingPrefs.markCompleted();
    if (mounted) context.go('/');
  }

  Future<void> _goToSignUp() async {
    await OnboardingPrefs.markCompleted();
    if (mounted) context.go('/signup');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isWide = size.width >= 720;
    final contentWidth = isWide ? 420.0 : math.min(size.width, 440.0);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottomInset),
              child: Column(
                children: [
                  Expanded(
                    flex: 11,
                    child: FadeTransition(
                      opacity: _collageFade,
                      child: SlideTransition(
                        position: _collageSlide,
                        child: AnimatedBuilder(
                          animation: _floatController,
                          builder: (context, child) {
                            final t = _floatController.value;
                            return Transform.translate(
                              offset: Offset(0, math.sin(t * math.pi) * 4),
                              child: child,
                            );
                          },
                          child: const _WelcomeCollage(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeTransition(
                    opacity: _copyFade,
                    child: SlideTransition(
                      position: _copySlide,
                      child: Column(
                        children: [
                          const _PageIndicators(activeIndex: 0, count: 4),
                          const SizedBox(height: 22),
                          Text(
                            'Welcome to TrustVault!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: isWide ? 28 : 26,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              height: 1.2,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'The vault that pays you more — literally.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textDark,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  FadeTransition(
                    opacity: _ctaFade,
                    child: SlideTransition(
                      position: _ctaSlide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: _goToLogin,
                              style: FilledButton.styleFrom(
                                backgroundColor: _loginTeal,
                                foregroundColor: AppColors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                textStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              onPressed: _goToSignUp,
                              style: FilledButton.styleFrom(
                                backgroundColor: _createPeach,
                                foregroundColor: AppColors.textDark,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                textStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              child: const Text('Create an Account'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageIndicators extends StatelessWidget {
  const _PageIndicators({required this.activeIndex, required this.count});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 14,
          height: 4,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0F5C5B) : const Color(0xFFD9D9D9),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

/// Staggered photo-tile collage with TrustVault logo card (Atlas-style layout).
class _WelcomeCollage extends StatelessWidget {
  const _WelcomeCollage();

  static const _photos = <String>[
    // Lifestyle / people tiles — same structural role as the sample collage.
    'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1551836022-d5d32f7f6c70?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1600880292203-757bb62b4baf?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1556740758-90de374c12ad?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1556742111-a301076d9d18?auto=format&fit=crop&w=600&q=80',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final tileRadius = BorderRadius.circular(18);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: h * 0.02,
              width: w * 0.30,
              height: h * 0.28,
              child: _CollageTile(
                borderRadius: tileRadius,
                imageUrl: _photos[0],
                fallback: const Color(0xFF1B3A4B),
              ),
            ),
            Positioned(
              left: w * 0.34,
              top: 0,
              width: w * 0.32,
              height: h * 0.34,
              child: _CollageTile(
                borderRadius: tileRadius,
                imageUrl: _photos[1],
                fallback: const Color(0xFFE8C872),
              ),
            ),
            Positioned(
              right: 0,
              top: h * 0.04,
              width: w * 0.30,
              height: h * 0.30,
              child: _CollageTile(
                borderRadius: tileRadius,
                imageUrl: _photos[2],
                fallback: const Color(0xFF2F5C9E),
              ),
            ),
            Positioned(
              left: w * 0.04,
              top: h * 0.34,
              width: w * 0.42,
              height: h * 0.36,
              child: _CollageTile(
                borderRadius: tileRadius,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0B1220), Color(0xFF1B2A4A)],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: math.min(h * 0.16, 72),
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'TrustVault',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: w * 0.02,
              top: h * 0.36,
              width: w * 0.46,
              height: h * 0.34,
              child: _CollageTile(
                borderRadius: tileRadius,
                imageUrl: _photos[3],
                fallback: const Color(0xFFF3C9B5),
              ),
            ),
            Positioned(
              left: 0,
              bottom: h * 0.02,
              width: w * 0.36,
              height: h * 0.24,
              child: _CollageTile(
                borderRadius: tileRadius,
                imageUrl: _photos[4],
                fallback: const Color(0xFF134E4A),
              ),
            ),
            Positioned(
              left: w * 0.40,
              bottom: 0,
              width: w * 0.28,
              height: h * 0.26,
              child: _CollageTile(
                borderRadius: tileRadius,
                imageUrl: _photos[5],
                fallback: const Color(0xFFE2E8F0),
              ),
            ),
            Positioned(
              right: 0,
              bottom: h * 0.04,
              width: w * 0.28,
              height: h * 0.24,
              child: _CollageTile(
                borderRadius: tileRadius,
                imageUrl: _photos[6],
                fallback: const Color(0xFF0F172A),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CollageTile extends StatelessWidget {
  const _CollageTile({
    required this.borderRadius,
    this.imageUrl,
    this.gradient,
    this.fallback,
    this.child,
  });

  final BorderRadius borderRadius;
  final String? imageUrl;
  final Gradient? gradient;
  final Color? fallback;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fallback ?? const Color(0xFFE2E8F0),
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: child ??
            (imageUrl == null
                ? const SizedBox.expand()
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: fallback ?? const Color(0xFFE2E8F0),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return ColoredBox(
                        color: fallback ?? const Color(0xFFE2E8F0),
                      );
                    },
                  )),
      ),
    );
  }
}
