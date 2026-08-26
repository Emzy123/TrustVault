import 'package:flutter/material.dart';

/// Shared breakpoints and responsive helpers.
abstract final class Breakpoints {
  static const mobile = 600.0;
  static const tablet = 900.0;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isMobile => screenWidth < Breakpoints.mobile;

  bool get isCompact => screenWidth < Breakpoints.tablet;

  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(
        isMobile ? 16 : 20,
        isMobile ? 16 : 20,
        isMobile ? 16 : 20,
        isMobile ? 88 : 100,
      );

  EdgeInsets get adminPagePadding => EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        isMobile ? 16 : 28,
        isMobile ? 16 : 28,
        isMobile ? 24 : 28,
      );

  int gridColumns({double minTileWidth = 150}) {
    if (screenWidth < Breakpoints.mobile) return 2;
    if (screenWidth < Breakpoints.tablet) return 2;
    return (screenWidth / minTileWidth).floor().clamp(3, 4);
  }
}

/// Adaptive grid for metric/stat tiles — full width on narrow screens.
class ResponsiveMetricGrid extends StatelessWidget {
  const ResponsiveMetricGrid({
    super.key,
    required this.children,
    this.minTileWidth = 150,
  });

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = context.gridColumns(minTileWidth: minTileWidth);
        final spacing = context.isMobile ? 12.0 : 16.0;
        final tileWidth = (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(
                width: tileWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

/// 2×2 (mobile) or 4-column quick action grid.
class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final columns = context.screenWidth >= 520 ? 4 : 2;
    final spacing = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Stacks body + actions vertically on mobile; side-by-side on wider screens.
class ResponsiveReviewCard extends StatelessWidget {
  const ResponsiveReviewCard({
    super.key,
    required this.leading,
    required this.body,
    required this.actions,
  });

  final Widget leading;
  final Widget body;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(child: body),
            ],
          ),
          const SizedBox(height: 14),
          actions,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(width: 16),
        Expanded(child: body),
        const SizedBox(width: 16),
        actions,
      ],
    );
  }
}

/// Page header with optional action — stacks on mobile.
class ResponsivePageHeader extends StatelessWidget {
  const ResponsivePageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: context.isMobile ? 22 : null,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ],
      ],
    );

    if (context.isMobile && actions.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleBlock),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 8),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    );
  }
}
