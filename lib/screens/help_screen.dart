import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      'How do I add team members?',
      'Team member invites are available on the Lite plan and above via the web platform. Mobile support is coming soon — you\'ll be able to add staff directly from this app.',
    ),
    (
      'Is my data shared with lenders?',
      'Only with your explicit consent when you initiate a lender application. You control exactly what is shared and can revoke access at any time.',
    ),
    (
      'How do I export my financial reports?',
      'Go to Finance → Reports and tap the share icon to export as PDF. Invoicing also supports PDF sharing via the invoice detail screen.',
    ),
    (
      'What if I forget my password?',
      'Tap "Forgot password" on the sign-in screen. A reset link will be sent to your registered email address.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Help & Support',
                    style: AppType.display(size: 28, color: c.text)),
                const SizedBox(height: 4),
                Text(
                  'Get the most out of AscendSME',
                  style: AppType.body(size: 13.5, color: c.textMuted),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 12),

          // ── Contact Support Card ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c.tealSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.headset_mic,
                            size: 20, color: c.teal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Contact support',
                                style: AppType.heading(
                                    size: 15, color: c.text)),
                            const SizedBox(height: 2),
                            Text(
                              'We typically reply within one business day',
                              style: AppType.body(
                                  size: 12, color: c.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: AppBtn(
                      'Copy email address',
                      variant: BtnVariant.primary,
                      icon: 'content_copy',
                      fontSize: 12.5,
                      onTap: () => _copyEmail(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _copyEmail(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.email_outlined,
                            size: 13, color: c.teal),
                        const SizedBox(width: 6),
                        Text(
                          'support@ascendsme.africa',
                          style: AppType.body(
                              size: 12.5,
                              color: c.teal,
                              weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 28),

          // ── FAQ ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionHeader('Frequently asked questions'),
          ),
          const SizedBox(height: 8),
          ..._faqs.asMap().entries.map(
                (entry) => Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
                  child: _FaqItem(
                          question: entry.value.$1, answer: entry.value.$2)
                      .animate()
                      .fadeIn(
                          duration: 350.ms,
                          delay: (50 * entry.key).ms)
                      .slideY(begin: 0.08, end: 0),
                ),
              ),

        ],
      ),
    );
  }

  static const _supportEmail = 'support@ascendsme.africa';

  void _copyEmail(BuildContext context) {
    final c = context.colors;
    Clipboard.setData(const ClipboardData(text: _supportEmail));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Email address copied to clipboard',
            style: TextStyle(color: Colors.white)),
        backgroundColor: c.navyDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── FAQ Item ─────────────────────────────────────────────────────────────────

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _open ? Icons.help : Icons.help_outline,
                size: 18,
                color: _open ? c.tealDeep : c.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.question,
                  style: AppType.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: _open ? c.teal : c.text,
                  ),
                ),
              ),
              Icon(
                _open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 20,
                color: c.textMuted,
              ),
            ],
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10, left: 28),
              child: Text(
                widget.answer,
                style: AppType.body(size: 12.5, color: c.textMuted).copyWith(height: 1.5),
              ),
            ),
            crossFadeState: _open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
