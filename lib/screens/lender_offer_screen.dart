import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';

/// Detail view for one matched lender. v0.1 just expands the data we already
/// have in the lender card; Phase 4 wires "Start application" to a real flow
/// that hands off to the lender (deep link, webview, or hosted form).
class LenderOfferScreen extends StatelessWidget {
  final Lender lender;

  const LenderOfferScreen({super.key, required this.lender});

  void _showApplyStub(BuildContext context) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${lender.name} application — coming soon. Your account manager will reach out.',
          style: AppType.body(size: 13, color: Colors.white),
        ),
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
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader('Lender offer',
                onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(lender.name,
                                      style: AppType.heading(
                                          size: 20, color: c.text)),
                                  const SizedBox(height: 4),
                                  Text(lender.product,
                                      style: AppType.body(
                                          size: 13, color: c.textMuted)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: c.tealSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${lender.match}% match',
                                  style: AppType.body(
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: c.tealDeep)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Max loan',
                          value:
                              'GHS ${(lender.max / 1000).toStringAsFixed(0)}k',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          label: 'Interest rate',
                          value: '${lender.rate} p.a.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('What to expect',
                      style: AppType.heading(size: 16, color: c.text)),
                  const SizedBox(height: 8),
                  Text(
                    'Your account manager confirms eligibility, prepares your bank-ready report, and submits the application on your behalf. You\'ll be notified at each step.',
                    style: AppType.body(size: 13.5, color: c.textMuted),
                  ),
                  const SizedBox(height: 28),
                  AppBtn(
                    'Start application',
                    full: true,
                    onTap: () => _showApplyStub(context),
                  ),
                  const SizedBox(height: 10),
                  AppBtn(
                    'Talk to my account manager',
                    full: true,
                    variant: BtnVariant.outline,
                    onTap: () => _showApplyStub(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppType.body(size: 11.5, color: c.textMuted)),
          const SizedBox(height: 6),
          Text(value,
              style: AppType.heading(size: 18, color: c.text)),
        ],
      ),
    );
  }
}
