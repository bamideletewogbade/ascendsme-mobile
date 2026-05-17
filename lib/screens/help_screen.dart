import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'How do I qualify for funding through AscendSME?',
      'Complete the verification checklist (business registration, ID, tax certificate, bank statements). Once verified, your account manager prepares your bank-ready report and we match you to lenders who fit your revenue and operating history.',
    ),
    (
      'Can I add team members to my business?',
      'Team members are coming soon. The current release supports a single owner login per business; the web platform already supports invites for owners on the Lite plan and above.',
    ),
    (
      'Is my financial data shared with lenders?',
      'Only with your explicit consent when you initiate a lender application. You control exactly what is shared and can revoke access at any time.',
    ),
    (
      'How do I get help with a specific issue?',
      'Tap "Email support" below, or message your account manager via Chat/Call above. We typically reply within one business day.',
    ),
  ];

  static const _resources = [
    ('description', 'Getting started guide'),
    ('book',        'SME compliance checklist'),
    ('school',      'Finance masterclass (free)'),
    ('mail',        'Email support'),
  ];

  void _comingSoon(BuildContext context, String label) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label — coming soon.',
            style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: c.tealDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Text('Help & Support',
                style: AppType.display(size: 28, color: c.text)),
          ),

          // Support card — honest about what's available now.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              background: c.tealSurface,
              border: Border.all(color: c.tealSurfaceStrong),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.support_agent,
                          size: 22, color: c.tealDeep),
                      const SizedBox(width: 10),
                      Text('Need a hand?',
                          style:
                              AppType.heading(size: 15, color: c.text)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email us at support@ascendsme.africa and the team will get back to you within one business day. In-app chat with an account manager is coming soon.',
                    style: AppType.body(size: 13, color: c.textMuted),
                  ),
                  const SizedBox(height: 14),
                  AppBtn(
                    'Email support',
                    variant: BtnVariant.primary,
                    icon: 'mail',
                    fontSize: 12.5,
                    onTap: () =>
                        _comingSoon(context, 'Email support'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // FAQ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Frequently asked'),
                ..._faqs.map(
                  (faq) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FaqItem(question: faq.$1, answer: faq.$2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Resources
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader('Resources'),
                ..._resources.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ResourceRow(
                      iconName: r.$1,
                      label: r.$2,
                      onTap: () => _comingSoon(context, r.$2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String question, answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: () => setState(() => _open = !_open),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.question,
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600, color: c.text)),
              ),
              Icon(_open ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: c.textMuted),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            Text(widget.answer,
                style: AppType.body(size: 12.5, color: c.textMuted)),
          ],
        ],
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  final String iconName, label;
  final VoidCallback onTap;

  const _ResourceRow({
    required this.iconName,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final icon = switch (iconName) {
      'description' => Icons.description_outlined,
      'book'        => Icons.menu_book_outlined,
      'school'      => Icons.school_outlined,
      'mail'        => Icons.email_outlined,
      _             => Icons.circle_outlined,
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: c.bgInset, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: c.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: AppType.body(
                    size: 13, weight: FontWeight.w600, color: c.text)),
          ),
          Icon(Icons.chevron_right, size: 18, color: c.textFaint),
        ],
      ),
    );
  }
}
