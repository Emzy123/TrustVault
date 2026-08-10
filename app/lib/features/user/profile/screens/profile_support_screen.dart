import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/premium_widgets.dart';

class ProfileSupportScreen extends StatefulWidget {
  const ProfileSupportScreen({super.key});

  @override
  State<ProfileSupportScreen> createState() => _ProfileSupportScreenState();
}

class _ProfileSupportScreenState extends State<ProfileSupportScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<_FaqItem> _faqs = const [
    _FaqItem(
      question: 'How long does KYC identity verification take?',
      answer:
          'Identity verification is reviewed promptly by compliance officers. During demo mode, submissions are processed in real-time or within minutes.',
    ),
    _FaqItem(
      question: 'How do peer-to-peer transfers work?',
      answer:
          'Transfers between TrustVault accounts are processed instantly using our double-entry atomic ledger engine. Funds are debited and credited immediately with zero fee.',
    ),
    _FaqItem(
      question: 'What happens when a withdrawal is under review?',
      answer:
          'Withdrawals enter a genuine pending review queue. Super Admins verify compliance limits and either approve (debiting balance) or decline with explicit reasons.',
    ),
    _FaqItem(
      question: 'How do I upgrade my account daily limits?',
      answer:
          'Submitting government-issued ID (National ID, Passport, or Driver License) upgrades your wallet to Tier 2 with a \$1,000,000 daily limit.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openLiveChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _SupportChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _faqs
        .where((item) =>
            item.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            item.answer.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return ProfileSubScreenScaffold(
      title: 'Help & Support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: AppDecorations.heroCard(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.headset_mic_outlined, color: AppColors.accentGold, size: 36),
                const SizedBox(height: 12),
                Text(
                  'How can we help you today?',
                  style: AppTypography.textTheme.headlineSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Browse frequently asked questions or connect with our support team.',
                  style: AppTypography.textTheme.bodySmall?.copyWith(color: AppColors.white.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentGold,
                    foregroundColor: AppColors.primaryNavy,
                  ),
                  onPressed: _openLiveChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Start Live Chat'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search help topics...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Frequently Asked Questions'),
          const SizedBox(height: 12),
          if (filteredFaqs.isEmpty)
            PremiumCard(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('No matching help topics found.', style: AppTypography.textTheme.bodySmall)),
              ),
            )
          else
            ...filteredFaqs.map(
              (faq) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PremiumCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      title: Text(
                        faq.question,
                        style: AppTypography.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Text(faq.answer, style: AppTypography.textTheme.bodySmall?.copyWith(height: 1.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _SupportChatSheet extends StatefulWidget {
  const _SupportChatSheet();

  @override
  State<_SupportChatSheet> createState() => _SupportChatSheetState();
}

class _SupportChatSheetState extends State<_SupportChatSheet> {
  final List<Map<String, String>> _messages = [
    {'sender': 'bot', 'text': 'Hello! Welcome to TrustVault Support. How can I assist you with your wallet today?'}
  ];
  final _msgController = TextEditingController();

  void _send() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': text});
      _msgController.clear();
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': 'Thank you for reaching out! A compliance support agent has received your query and will assist you shortly.'
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.support_agent_rounded, color: AppColors.secondaryBlue),
                  ),
                  const SizedBox(width: 10),
                  Text('TrustVault Live Assistant', style: AppTypography.textTheme.titleMedium),
                ],
              ),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final isUser = _messages[index]['sender'] == 'user';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.secondaryBlue : AppColors.neutralLightGrey,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _messages[index]['text']!,
                        style: TextStyle(
                          color: isUser ? AppColors.white : AppColors.textDark,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgController,
                  decoration: const InputDecoration(hintText: 'Type your message...'),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send_rounded),
                onPressed: _send,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
