import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Statements'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/app/profile'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.picture_as_pdf_outlined, color: AppColors.secondaryBlue),
                            const SizedBox(width: 10),
                            Text('Export Official Statement', style: theme.textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Download signed official account statements for tax or compliance purposes.',
                          style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                        ),
                        const Divider(height: 32),
                        const Text('Statement Period', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: ['Current Month', 'Last 30 Days', 'Last 90 Days', 'Year 2026']
                              .map((range) => ChoiceChip(
                                    label: Text(range),
                                    selected: _selectedRange == range,
                                    onSelected: (sel) {
                                      if (sel) setState(() => _selectedRange = range);
                                    },
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                        const Text('Export Format', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('PDF Document (.pdf)')),
                                selected: _selectedFormat == 'PDF',
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedFormat = 'PDF');
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('CSV Spreadsheet (.csv)')),
                                selected: _selectedFormat == 'CSV',
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedFormat = 'CSV');
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isGenerating ? null : _generateStatement,
                            child: _isGenerating
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.white,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Generating Statement...'),
                                    ],
                                  )
                                : Text('Export Statement ($_selectedFormat)'),
                          ),
                        ),
                      ],
                    ),
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
