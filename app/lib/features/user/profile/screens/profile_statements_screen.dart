import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/premium_widgets.dart';

class ProfileStatementsScreen extends StatefulWidget {
  const ProfileStatementsScreen({super.key});

  @override
  State<ProfileStatementsScreen> createState() => _ProfileStatementsScreenState();
}

class _ProfileStatementsScreenState extends State<ProfileStatementsScreen> {
  String _selectedRange = 'Current Month';
  String _selectedFormat = 'PDF';
  bool _isGenerating = false;

  Future<void> _generateStatement() async {
    setState(() => _isGenerating = true);
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _isGenerating = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Statement ($_selectedRange) exported as $_selectedFormat successfully!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileSubScreenScaffold(
      title: 'Account Statements',
      child: PremiumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.secondaryBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Export Official Statement', style: AppTypography.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Download signed statements for tax or compliance purposes.',
                        style: AppTypography.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text('Statement Period', style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Current Month', 'Last 30 Days', 'Last 90 Days', 'Year ${DateTime.now().year}']
                  .map(
                    (range) => FilterChip(
                      label: Text(range),
                      selected: _selectedRange == range,
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedRange = range);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text('Export Format', style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Center(child: Text('PDF (.pdf)')),
                    selected: _selectedFormat == 'PDF',
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedFormat = 'PDF');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilterChip(
                    label: const Center(child: Text('CSV (.csv)')),
                    selected: _selectedFormat == 'CSV',
                    onSelected: (sel) {
                      if (sel) setState(() => _selectedFormat = 'CSV');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isGenerating ? null : _generateStatement,
              child: _isGenerating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                        ),
                        SizedBox(width: 12),
                        Text('Generating Statement...'),
                      ],
                    )
                  : Text('Export Statement ($_selectedFormat)'),
            ),
          ],
        ),
      ),
    );
  }
}
