import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/premium_widgets.dart';
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
                  Text('Admin', style: AppTypography.textTheme.titleMedium),
                ],
              ),
              actions: const [SignOutButton()],
            ),
            drawer: Drawer(
              child: AdminSidebar(
                items: adminNavItems,
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
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Row(
            children: [
              Image.asset('assets/images/logo.png', height: 32),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Atlas',
                    style: AppTypography.textTheme.titleSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    title,
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (sectionDividerAfter != null && i == sectionDividerAfter)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    child: Text(
                      'SUPER OVERSIGHT',
                      style: AppTypography.overline.copyWith(
                        color: AppColors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                _NavItemTile(
                  item: items[i],
                  isSelected: currentPath == items[i].path,
                  inDrawer: inDrawer,
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        Divider(color: AppColors.white.withValues(alpha: 0.12), indent: 20, endIndent: 20),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.white.withValues(alpha: 0.12),
            child: Text(
              footer.isNotEmpty ? footer[0].toUpperCase() : 'A',
              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
            ),
          ),
          title: Text(
            footer,
            style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const SignOutButton(),
        ),
        const SizedBox(height: 12),
      ],
    );

    final decoration = BoxDecoration(gradient: AppDecorations.authPanelGradient);

    if (inDrawer) {
      return Container(
        decoration: decoration,
        child: SafeArea(child: content),
      );
    }

    return Container(
      width: 268,
      decoration: decoration,
      child: SafeArea(child: content),
    );
  }
}

class _NavItemTile extends StatelessWidget {
  const _NavItemTile({
    required this.item,
    required this.isSelected,
    required this.inDrawer,
  });

  final AdminNavItem item;
  final bool isSelected;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? AppColors.white.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (inDrawer) Navigator.of(context).pop();
            context.go(item.path);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: isSelected ? AppColors.accentGoldLight : AppColors.white.withValues(alpha: 0.75),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      color: isSelected ? AppColors.white : AppColors.white.withValues(alpha: 0.75),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.accentGoldLight,
                      shape: BoxShape.circle,
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
