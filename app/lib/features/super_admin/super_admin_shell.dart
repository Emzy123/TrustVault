import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../admin/admin_shell.dart';
import '../shared/admin_nav.dart';
import '../shared/profile_bootstrap.dart';
import '../shared/sign_out_button.dart';

class SuperAdminShell extends StatelessWidget {
  const SuperAdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).matchedLocation;

    return ProfileBootstrap(
      builder: (profile) => LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (isWide) {
            return Scaffold(
              body: Row(
                children: [
                  AdminSidebar(
                    title: 'Super Admin',
                    items: superAdminNavItems,
                    footer: profile.fullName,
                    currentPath: currentPath,
                  ),
                  Expanded(child: child),
                ],
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('TrustVault Super Admin'),
              actions: [const SignOutButton()],
            ),
            drawer: Drawer(
              child: AdminSidebar(
                title: 'Super Admin',
                items: superAdminNavItems,
                footer: profile.fullName,
                currentPath: currentPath,
                inDrawer: true,
              ),
            ),
            body: child,
          );
        },
      ),
    );
  }
}
