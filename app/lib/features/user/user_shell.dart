import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/profile_bootstrap.dart';
import '../shared/sign_out_button.dart';

class UserShell extends StatelessWidget {
  const UserShell({super.key, required this.child});

  final Widget child;

  static const _destinations = [
    _NavDestination('/app', 'Dashboard', Icons.dashboard_outlined, Icons.dashboard),
    _NavDestination('/app/transfer', 'Transfer', Icons.swap_horiz_outlined, Icons.swap_horiz),
    _NavDestination('/app/history', 'History', Icons.history_outlined, Icons.history),
    _NavDestination('/app/profile', 'Profile', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final selectedIndex = _indexForLocation(location);

    return ProfileBootstrap(
      builder: (profile) => Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', height: 28),
              const SizedBox(width: 10),
              const Text('TrustVault'),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: Text(profile.fullName)),
            ),
            const SignOutButton(),
          ],
        ),
        body: child,
        bottomNavigationBar: NavigationBar(
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
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith('/app/transfer')) return 1;
    if (location.startsWith('/app/history')) return 2;
    if (location.startsWith('/app/profile')) return 3;
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
