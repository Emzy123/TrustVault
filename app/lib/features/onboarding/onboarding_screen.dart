import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

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
    ),
    _OnboardingPageData(
      title: 'Instant Peer Transfers',
      subtitle:
          'Transfer funds between TrustVault accounts instantaneously with full atomic ledger postings.',
      icon: Icons.swap_horiz_outlined,
      badgeText: 'ZERO LATENCY',
    ),
    _OnboardingPageData(
      title: 'Honest Status & Oversight',
      subtitle:
          'Every transaction status is genuine. Track funding, transfers, and withdrawal reviews with complete transparency.',
      icon: Icons.verified_user_outlined,
      badgeText: 'TRANSPARENT FLOWS',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/app');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset('assets/images/logo.png', height: 32),
                          const SizedBox(width: 12),
                          Text(
                            'TrustVault',
                            style: theme.textTheme.titleLarge?.copyWith(color: AppColors.white),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => context.go('/app'),
                        child: Text(
                          'Skip',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final item = _pages[index];
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.accentGold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.accentGold.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                item.badgeText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.accentGold,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.secondaryBlue.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item.icon, size: 64, color: AppColors.accentGold),
                            ),
                            const SizedBox(height: 40),
                            Text(
                              item.title,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              item.subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.white.withValues(alpha: 0.8),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? AppColors.accentGold
                                  : AppColors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentGold,
                            foregroundColor: AppColors.primaryNavy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _onNext,
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Continue',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String badgeText;
}
