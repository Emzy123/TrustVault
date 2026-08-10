import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_typography.dart';
import '../../core/onboarding/onboarding_prefs.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Secure Digital Vault',
      subtitle:
          'Your simulated multi-currency wallet is backed by an atomic double-entry ledger for institutional compliance.',
      icon: Icons.shield_outlined,
      badgeText: 'SECURITY FIRST',
      accentColor: AppColors.secondaryBlue,
    ),
    _OnboardingPageData(
      title: 'Instant Peer Transfers',
      subtitle:
          'Transfer funds between TrustVault accounts instantaneously with full atomic ledger postings.',
      icon: Icons.swap_horiz_rounded,
      badgeText: 'ZERO LATENCY',
      accentColor: AppColors.accentGold,
    ),
    _OnboardingPageData(
      title: 'Honest Status & Oversight',
      subtitle:
          'Every transaction status is genuine. Track funding, transfers, and withdrawal reviews with complete transparency.',
      icon: Icons.verified_user_outlined,
      badgeText: 'TRANSPARENT FLOWS',
      accentColor: AppColors.success,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    await OnboardingPrefs.markCompleted();
    if (mounted) context.go('/');
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return Container(
            decoration: const BoxDecoration(gradient: AppDecorations.authPanelGradient),
            child: Stack(
              children: [
                Positioned(
                  top: -100,
                  right: -80,
                  child: _GlowOrb(size: 280, color: AppColors.white.withValues(alpha: 0.04)),
                ),
                Positioned(
                  bottom: -60,
                  left: -50,
                  child: _GlowOrb(size: 220, color: AppColors.accentGold.withValues(alpha: 0.08)),
                ),
                Positioned(
                  top: constraints.maxHeight * 0.35,
                  left: -30,
                  child: _GlowOrb(size: 120, color: AppColors.secondaryBlue.withValues(alpha: 0.12)),
                ),
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isWide ? 920 : 540),
                      child: Column(
                        children: [
                          _buildHeader(isWide),
                          Expanded(
                            child: isWide
                                ? _buildWideCarousel()
                                : _buildMobileCarousel(),
                          ),
                          _buildFooter(isWide),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 40 : 24, 16, isWide ? 40 : 24, 8),
      child: Row(
        children: [
          Image.asset('assets/images/logo.png', height: isWide ? 36 : 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TrustVault',
                style: AppTypography.textTheme.titleMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Onboarding',
                style: AppTypography.overline.copyWith(color: AppColors.white.withValues(alpha: 0.5)),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: _finishOnboarding,
            style: TextButton.styleFrom(foregroundColor: AppColors.white.withValues(alpha: 0.75)),
            child: const Text('Skip tour'),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCarousel() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) => setState(() => _currentPage = index),
      itemCount: _pages.length,
      itemBuilder: (context, index) => _OnboardingSlide(page: _pages[index], step: index + 1, total: _pages.length),
    );
  }

  Widget _buildWideCarousel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to\nyour digital vault.',
                    style: AppTypography.textTheme.displayMedium?.copyWith(
                      color: AppColors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Three things to know before you start moving funds in the demo environment.',
                    style: AppTypography.textTheme.bodyLarge?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: const [
                      _TrustChip(icon: Icons.verified_user_outlined, label: '256-bit encryption'),
                      _TrustChip(icon: Icons.account_balance_outlined, label: 'Licensed demo'),
                      _TrustChip(icon: Icons.speed_outlined, label: 'Instant transfers'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: AppDecorations.glassCard(tint: AppColors.white),
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) => setState(() => _currentPage = index),
                      itemCount: _pages.length,
                      itemBuilder: (context, index) => _OnboardingSlide(
                        page: _pages[index],
                        step: index + 1,
                        total: _pages.length,
                        onDarkBackground: false,
                      ),
                    ),
                  ),
                  _buildPageIndicators(onDarkBackground: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isWide) {
    if (isWide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(40, 8, 40, 28),
        child: Row(
          children: [
            Text(
              '© ${DateTime.now().year} TrustVault · Demo environment',
              style: AppTypography.textTheme.bodySmall?.copyWith(
                color: AppColors.white.withValues(alpha: 0.4),
              ),
            ),
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: AppColors.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _onNext,
              child: Text(
                _currentPage == _pages.length - 1 ? 'Continue to sign in' : 'Continue',
                style: AppTypography.textTheme.labelLarge?.copyWith(color: AppColors.primaryNavy),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        children: [
          _buildPageIndicators(onDarkBackground: true),
          const SizedBox(height: 28),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: AppColors.primaryNavy,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _onNext,
            child: Text(
              _currentPage == _pages.length - 1 ? 'Continue to sign in' : 'Continue',
              style: AppTypography.textTheme.labelLarge?.copyWith(color: AppColors.primaryNavy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators({required bool onDarkBackground}) {
    final inactive = onDarkBackground
        ? AppColors.white.withValues(alpha: 0.25)
        : AppColors.borderGrey;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index ? AppColors.accentGold : inactive,
            borderRadius: BorderRadius.circular(999),
            boxShadow: _currentPage == index
                ? [
                    BoxShadow(
                      color: AppColors.accentGold.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.page,
    required this.step,
    required this.total,
    this.onDarkBackground = true,
  });

  final _OnboardingPageData page;
  final int step;
  final int total;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final titleColor = onDarkBackground ? AppColors.white : AppColors.textDark;
    final bodyColor = onDarkBackground ? AppColors.white.withValues(alpha: 0.78) : AppColors.textMuted;
    final stepColor = onDarkBackground ? AppColors.white.withValues(alpha: 0.45) : AppColors.textMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'STEP $step OF $total',
            style: AppTypography.overline.copyWith(color: stepColor),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: page.accentColor.withValues(alpha: onDarkBackground ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: page.accentColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              page.badgeText,
              style: AppTypography.overline.copyWith(
                color: onDarkBackground ? AppColors.accentGoldLight : page.accentColor,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  page.accentColor.withValues(alpha: 0.25),
                  page.accentColor.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(color: page.accentColor.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: page.accentColor.withValues(alpha: 0.2),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(page.icon, size: 56, color: onDarkBackground ? AppColors.accentGoldLight : page.accentColor),
          ),
          const SizedBox(height: 36),
          Text(
            page.title,
            style: AppTypography.textTheme.headlineMedium?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            page.subtitle,
            style: AppTypography.textTheme.bodyMedium?.copyWith(color: bodyColor, height: 1.55),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accentGoldLight),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTypography.textTheme.bodySmall?.copyWith(
              color: AppColors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badgeText,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String badgeText;
  final Color accentColor;
}
