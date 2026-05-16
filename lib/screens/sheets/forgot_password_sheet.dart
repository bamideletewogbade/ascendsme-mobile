import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/app_logger.dart';
import '../../services/supabase_service.dart';
import '../../config.dart';

/// Bottom sheet for password reset. Pre-fills [initialEmail] when provided
/// (typically the email already typed on the sign-in screen).
class ForgotPasswordSheet extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordSheet({super.key, this.initialEmail});

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  late final TextEditingController _emailCtrl;
  bool _loading = false;
  String? _error;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    if (AppConfig.supabaseUrl.isEmpty) {
      // Mock mode — just pretend it worked.
      log.info('ForgotPasswordSheet — mock mode, faking success for ${AppLogger.maskEmail(email)}');
      setState(() => _sent = true);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    log.info('ForgotPasswordSheet — sending reset to ${AppLogger.maskEmail(email)}');
    try {
      await SupabaseService.resetPassword(email);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
      });
    } catch (e, st) {
      log.error('ForgotPasswordSheet — resetPassword failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not send reset link. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            if (!_sent) ...[
              Text('Reset your password',
                  style: AppType.heading(size: 20, color: c.text)),
              const SizedBox(height: 6),
              Text(
                "Enter the email you signed up with. We'll send you a link to set a new password.",
                style: AppType.body(size: 13, color: c.textMuted),
              ),
              const SizedBox(height: 22),

              Text('Email',
                  style: AppType.body(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: c.textMuted)),
              const SizedBox(height: 6),
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.email_outlined, size: 17, color: c.textFaint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: (_) => _send(),
                        style: AppType.body(
                            size: 14,
                            weight: FontWeight.w500,
                            color: c.text),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'you@business.com',
                          hintStyle:
                              AppType.body(size: 14, color: c.textFaint),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: c.rose.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: c.rose.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 16, color: c.rose),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style:
                                AppType.body(size: 13, color: c.rose)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),
              _loading
                  ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(c.teal),
                        ),
                      ),
                    )
                  : AppBtn('Send reset link',
                      full: true, fontSize: 15, onTap: _send),
            ] else ...[
              // ── Sent state ───────────────────────────────────────────
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: c.tealSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mark_email_read_outlined,
                      size: 32, color: c.tealDeep),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text('Check your inbox',
                    style: AppType.heading(size: 20, color: c.text)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  "We've sent a reset link to ${_emailCtrl.text.trim()}. Open it on this device to set a new password.",
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 13, color: c.textMuted),
                ),
              ),
              const SizedBox(height: 22),
              AppBtn('Done',
                  full: true,
                  fontSize: 15,
                  onTap: () => Navigator.pop(context)),
            ],
          ],
        ),
      ),
    );
  }
}
