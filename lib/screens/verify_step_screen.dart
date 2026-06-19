import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';
import '../services/app_logger.dart';
import '../services/document_service.dart';
import '../state/app_state.dart';

/// Detail view for one verification checklist item.
///
/// Phase 4 implementation: wires the actual file picker + Supabase Storage
/// upload + status update. After a successful upload the local status moves
/// to 'pending' and the UI shows "View submission" instead of "Upload document".
/// The server-side review process (admin → verified/rejected) is a web-only
/// workflow for now.
class VerifyStepScreen extends StatefulWidget {
  final VerificationStep step;

  const VerifyStepScreen({super.key, required this.step});

  @override
  State<VerifyStepScreen> createState() => _VerifyStepScreenState();
}

class _VerifyStepScreenState extends State<VerifyStepScreen> {
  String _status = '';
  bool _uploading = false;
  bool _uploaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.step.status;
  }

  Future<void> _pickAndUpload() async {
    log.info('VerifyStepScreen — picking document for step: ${widget.step.id}');

    // 1. Pick a file
    final file = await DocumentService.pickDocument();
    if (file == null || !mounted) return;

    // 2. Get business ID
    final state = context.read<AppState>();
    final bizId = state.business.id;
    if (bizId == null) {
      _showError('Business profile not loaded. Please try again.');
      return;
    }

    // 3. Upload
    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final result = await DocumentService.uploadDocument(
        businessId: bizId,
        name: widget.step.label,
        category: 'verification',
        file: file,
        verificationTaskId: widget.step.id,
        description: widget.step.detail,
      );

      if (!mounted) return;

      if (result != null) {
        log.info('VerifyStepScreen — upload complete: docId=${result.id}');
        setState(() {
          _status = 'pending';
          _uploaded = true;
          _uploading = false;
        });
        _showSuccess('${widget.step.label} — document uploaded successfully.');
        // Refresh verification status so the home screen ring + profile
        // screen counters reflect the new upload immediately.
        context.read<AppState>().loadVerificationStatus();
      } else {
        _showError('Upload failed. Please try again.');
        setState(() => _uploading = false);
      }
    } catch (e, st) {
      log.error('VerifyStepScreen — upload failed', error: e, stackTrace: st);
      if (!mounted) return;
      _showError(DocumentService.friendlyUploadError(e));
      setState(() => _uploading = false);
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: context.colors.greenDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: context.colors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, iconColor, statusLabel) = switch (_status) {
      'verified' => (Icons.check_circle, c.green, 'Verified'),
      'pending'  => (Icons.access_time, c.orange, 'Under review'),
      _          => (Icons.radio_button_unchecked, c.textFaint, 'Not started'),
    };
    final isDone = _status == 'verified';

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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(icon, size: 24, color: iconColor),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.step.label,
                                      style: AppType.heading(size: 18, color: c.text)),
                                  const SizedBox(height: 2),
                                  Text(statusLabel,
                                      style: AppType.body(size: 12.5,
                                          weight: FontWeight.w600,
                                          color: iconColor)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(height: 1, color: c.border),
                        const SizedBox(height: 16),
                        Text('What\'s needed',
                            style: AppType.label(size: 11, color: c.textMuted)),
                        const SizedBox(height: 8),
                        Text(widget.step.detail,
                            style: AppType.body(size: 14, color: c.text).copyWith(height: 1.4)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Upload progress / result ──
                  if (_uploading)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5),
                          ),
                          SizedBox(width: 10),
                          Text('Uploading document…'),
                        ],
                      ),
                    ),

                  if (_uploaded && !_uploading) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: c.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: c.green.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 20, color: c.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Document submitted',
                                    style: AppType.body(
                                        size: 13,
                                        weight: FontWeight.w600,
                                        color: c.green)),
                                const SizedBox(height: 2),
                                Text(
                                  'Your document is under review. '
                                  'This usually takes 1-2 business days.',
                                  style: AppType.body(
                                      size: 11.5, color: c.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Error banner ──
                  if (_error != null && !_uploading && !_uploaded) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: c.rose.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: c.rose.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 16, color: c.rose),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: AppType.body(
                                    size: 13, color: c.rose)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Action buttons ──
                  if (!isDone && !_uploading) ...[
                    AppBtn(
                      _status == 'pending' || _uploaded
                          ? 'Document submitted'
                          : 'Upload document',
                      full: true,
                      icon: _status == 'pending' || _uploaded
                          ? 'check_circle'
                          : 'upload',
                      onTap: _status == 'pending' || _uploaded
                          ? null
                          : _pickAndUpload,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!isDone) ...[
                    AppBtn(
                      'Talk to my account manager',
                      full: true,
                      variant: BtnVariant.outline,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Contact support@ascendsme.com for help.',
                              style: AppType.body(
                                  size: 13, color: Colors.white)),
                            backgroundColor: c.navyDeep,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
