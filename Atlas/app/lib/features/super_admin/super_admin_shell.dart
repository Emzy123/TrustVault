import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
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
                  Expanded(child: PageScaffold(child: child)),
                ],
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.png', height: 26),
                  const SizedBox(width: 10),
                  Text('Super Admin', style: AppTypography.textTheme.titleMedium),
                ],
              ),
              actions: const [SignOutButton()],
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
            body: PageScaffold(child: child),
          );
        },
      ),
    );
  }
}
