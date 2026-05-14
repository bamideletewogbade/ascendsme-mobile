import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'How is my sustainability score calculated?',
      'Your score reflects verification completeness, cash flow health, payment history, and compliance activity. It updates as you complete quests and log business activity.',
    ),
    (
      'How do I qualify for a loan?',
      'Reach a score of 60+ and complete at least 4 verification steps. Your account manager will guide you through creating your bank-ready report.',
    ),
    (
      'Can I add team members?',
      'Yes — go to Settings > Team to invite up to 5 members on the Lite plan. Each member gets their own login with role-based access.',
    ),
    (
      'Is my data shared with lenders?',
      'Only with your explicit consent when you initiate a lender application. You control exactly what is shared.',
    ),
  ];

  static const _resources = [
    ('description', 'Getting started guide'),
    ('book',        'SME compliance checklist'),
    ('school',      'Finance masterclass (free)'),
    ('mail',        'Email support'),
  ];

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

          // Account manager card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              background: c.tealSurface,
              border: Border.all(color: c.tealSurfaceStrong),
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAvatar('KO', size: 44, tone: 'teal'),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kojo Asante',
                            style: AppType.heading(size: 15, color: c.text)),
                        Text('Your account manager',
                            style:
                                AppType.body(size: 12, color: c.textMuted)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            AppBtn('Chat',
                                variant: BtnVariant.primary,
                                icon: 'chat',
                                fontSize: 12),
                            const SizedBox(width: 8),
                            AppBtn('Call',
                                variant: BtnVariant.outline,
                                icon: 'phone',
                                fontSize: 12),
                          ],
                        ),
                      ],
                    ),
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
                    child: _ResourceRow(iconName: r.$1, label: r.$2),
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

  const _ResourceRow({required this.iconName, required this.label});

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
