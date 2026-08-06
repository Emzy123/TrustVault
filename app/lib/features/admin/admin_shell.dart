import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../shared/admin_nav.dart';
import '../shared/profile_bootstrap.dart';
import '../shared/sign_out_button.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});

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
                    items: adminNavItems,
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
              title: const Text('TrustVault Admin'),
              actions: [const SignOutButton()],
            ),
            drawer: Drawer(
              child: AdminSidebar(
                items: adminNavItems,
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

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.items,
    required this.footer,
    required this.currentPath,
    this.sectionDividerAfter,
    this.title = 'Admin',
    this.inDrawer = false,
  });

  final List<AdminNavItem> items;
  final String footer;
  final String currentPath;
  final int? sectionDividerAfter;
  final String title;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < items.length; i++) ...[
          if (sectionDividerAfter != null && i == sectionDividerAfter)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Super Oversight',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Builder(builder: (context) {
            final isSelected = currentPath == items[i].path;
            return ListTile(
              selected: isSelected,
              selectedTileColor: AppColors.secondaryBlue.withValues(alpha: 0.35),
              leading: Icon(
                isSelected ? items[i].selectedIcon : items[i].icon,
                color: AppColors.white,
              ),
              title: Text(
                items[i].label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () {
                if (inDrawer) Navigator.of(context).pop();
                context.go(items[i].path);
              },
            );
          }),
        ],
        const Spacer(),
        Divider(color: AppColors.white.withValues(alpha: 0.2)),
        ListTile(
          leading: const Icon(Icons.person_outline, color: AppColors.white),
          title: Text(
            footer,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.white),
          ),
          trailing: const SignOutButton(),
        ),
        const SizedBox(height: 8),
      ],
    );

    if (inDrawer) {
      return Material(
        color: AppColors.primaryNavy,
        child: SafeArea(child: content),
      );
    }

    return Material(
      color: AppColors.primaryNavy,
      child: SizedBox(
        width: 260,
        child: SafeArea(child: content),
      ),
    );
  }
}
