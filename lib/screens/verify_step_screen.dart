import 'package:flutter/material.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';

/// Detail view for one verification checklist item. v0.1 explains the step
/// and surfaces an Upload button that's stubbed; Phase 4 wires the actual
/// file picker + Supabase Storage upload + status update.
class VerifyStepScreen extends StatelessWidget {
  final VerificationStep step;

  const VerifyStepScreen({super.key, required this.step});

  void _showUploadStub(BuildContext context) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document upload — coming soon.',
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
    final (icon, iconColor, statusLabel) = switch (step.status) {
      'verified' => (Icons.check_circle, c.green, 'Verified'),
      'pending' => (Icons.access_time, c.amber, 'Under review'),
      _ => (Icons.radio_button_unchecked, c.textFaint, 'Not started'),
    };
    final isDone = step.status == 'verified';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader('Verification',
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
                            Icon(icon, size: 28, color: iconColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(step.label,
                                  style: AppType.heading(
                                      size: 18, color: c.text)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(statusLabel,
                            style: AppType.body(
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: iconColor)),
                        const SizedBox(height: 14),
                        Container(height: 1, color: c.border),
                        const SizedBox(height: 14),
                        Text('What\'s needed',
                            style: AppType.body(
                                size: 11.5, color: c.textMuted)),
                        const SizedBox(height: 6),
                        Text(step.detail,
                            style: AppType.body(
                                size: 14, color: c.text)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (!isDone) ...[
                    AppBtn(
                      step.status == 'pending'
                          ? 'View submission'
                          : 'Upload document',
                      full: true,
                      icon: 'add',
                      onTap: () => _showUploadStub(context),
                    ),
                    const SizedBox(height: 10),
                  ],
                  AppBtn(
                    'Talk to my account manager',
                    full: true,
                    variant: BtnVariant.outline,
                    onTap: () => _showUploadStub(context),
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
