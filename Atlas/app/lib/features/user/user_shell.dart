import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../services/auth_service.dart';
import '../shared/profile_bootstrap.dart';
import '../shared/sign_out_button.dart';

class UserShell extends StatelessWidget {
  const UserShell({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    _NavDestination('/app', 'Home', Icons.home_outlined, Icons.home_rounded),
    _NavDestination('/app/profile', 'Me', Icons.person_outline, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _indexForLocation(location);
    final compact = context.isMobile;

    return ProfileBootstrap(
      builder: (profile) => Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', height: compact ? 24 : 28),
              if (!compact) ...[
                const SizedBox(width: 10),
                Text(
                  'Atlas',
                  style: AppTypography.textTheme.titleMedium,
                ),
              ],
            ],
          ),
          actions: [
            if (compact)
              PopupMenuButton<void>(
                tooltip: 'Account menu',
                offset: const Offset(0, 48),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.12),
                    child: Text(
                      profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.secondaryBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem<void>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName.split(' ').first,
                          style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          profile.levelBadgeTitle,
                          style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<void>(
                    onTap: () => AuthService(Supabase.instance.client).signOut(),
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('Sign out'),
                      ],
                    ),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Row(
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          profile.fullName.split(' ').first,
                          style: AppTypography.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          profile.levelBadgeTitle,
                          style: AppTypography.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.secondaryBlue.withValues(alpha: 0.12),
                      child: Text(
                        profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.secondaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const SignOutButton(),
                  ],
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.borderGrey),
          ),
        ),
        body: PageScaffold(child: child),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AppColors.navBarBg,
            border: Border(top: BorderSide(color: AppColors.borderGrey.withValues(alpha: 0.8))),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryNavy.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: compact ? 64 : 68,
            selectedIndex: selectedIndex,
            destinations: [
              for (final dest in _destinations)
                NavigationDestination(
                  icon: Icon(dest.icon),
                  selectedIcon: Icon(dest.selectedIcon),
                  label: dest.label,
                ),
            ],
            onDestinationSelected: (index) {
              final target = _destinations[index].path;
              if (location != target) context.go(target);
            },
          ),
        ),
      ),
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith('/app/profile')) return 1;
    return 0;
  }
}

class _NavDestination {
  const _NavDestination(this.path, this.label, this.icon, this.selectedIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
