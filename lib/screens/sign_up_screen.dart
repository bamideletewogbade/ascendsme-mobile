import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';

const _kIndustries = [
  'Retail',
  'Food & Beverage',
  'Fashion',
  'Technology',
  'Agriculture',
  'Healthcare',
  'Education',
  'Transport',
  'Construction',
  'Beauty & Wellness',
  'Finance',
  'Other',
];

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  int _step = 0;

  // Step 1 — Business
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _industry = _kIndustries.first;

  // Step 2 — Account
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _obscurePw = true;
  bool _obscureConfirm = true;

  String? _localError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _localError = 'Business name is required.');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _localError = 'Phone number is required.');
      return;
    }
    setState(() {
      _localError = null;
      _step = 1;
    });
  }

  Future<void> _submit() async {
    setState(() => _localError = null);

    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _localError = 'Email is required.');
      return;
    }
    if (_pwCtrl.text.length < 8) {
      setState(() => _localError = 'Password must be at least 8 characters.');
      return;
    }
    if (_pwCtrl.text != _confirmPwCtrl.text) {
      setState(() => _localError = 'Passwords do not match.');
      return;
    }

    final state = context.read<AppState>();
    final ok = await state.signUp(
      email: _emailCtrl.text.trim(),
      password: _pwCtrl.text,
      businessName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      industry: _industry,
    );
    if (!mounted) return;

    if (ok) {
      if (state.authed) {
        // Mock or instant-login Supabase — already authed.
        // Pop back so _SplashGate's AnimatedSwitcher shows AppShell.
        Navigator.of(context).pop();
      } else {
        // Email confirmation required.
        setState(() => _step = 2);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  if (_step < 2)
                    GestureDetector(
                      onTap: _step == 0
                          ? () => Navigator.pop(context)
                          : () => setState(() {
                                _step = 0;
                                _localError = null;
                              }),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: c.bgInset,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: c.text,
                        ),
                      ),
                    ),
                  if (_step < 2) const SizedBox(width: 12),
                  Text('Create account',
                      style: AppType.heading(size: 16, color: c.text)),
                  const Spacer(),
                  if (_step < 2)
                    Text('${_step + 1} of 2',
                        style: AppType.label(size: 12, color: c.textFaint)),
                ],
              ),
            ),

            // Progress bar
            if (_step < 2) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / 2,
                    minHeight: 3,
                    backgroundColor: c.bgInset,
                    valueColor: AlwaysStoppedAnimation(c.teal),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── Body ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: _step == 0
                      ? _BusinessStep(
                          key: const ValueKey(0),
                          nameCtrl: _nameCtrl,
                          phoneCtrl: _phoneCtrl,
                          industry: _industry,
                          onIndustryChanged: (v) =>
                              setState(() => _industry = v),
                          error: _localError,
                          onNext: _nextStep,
                        )
                      : _step == 1
                          ? _AccountStep(
                              key: const ValueKey(1),
                              emailCtrl: _emailCtrl,
                              pwCtrl: _pwCtrl,
                              confirmPwCtrl: _confirmPwCtrl,
                              obscurePw: _obscurePw,
                              obscureConfirm: _obscureConfirm,
                              onTogglePw: () =>
                                  setState(() => _obscurePw = !_obscurePw),
                              onToggleConfirm: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                              error: _localError ?? state.authError,
                              loading: state.authLoading,
                              onSubmit: _submit,
                            )
                          : _SuccessStep(
                              key: const ValueKey(2),
                              email: _emailCtrl.text,
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 1: Business info ─────────────────────────────────────────────────────

class _BusinessStep extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final String industry;
  final ValueChanged<String> onIndustryChanged;
  final String? error;
  final VoidCallback onNext;

  const _BusinessStep({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.industry,
    required this.onIndustryChanged,
    required this.error,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your business', style: AppType.display(size: 28, color: c.text)),
        const SizedBox(height: 6),
        Text("Let's get your business set up on AscendSME.",
            style: AppType.body(size: 14, color: c.textMuted)),
        const SizedBox(height: 28),

        _SignUpField(
          label: 'Business name',
          controller: nameCtrl,
          icon: Icons.storefront_outlined,
          hint: 'e.g. Akwaaba Threads',
        ),
        const SizedBox(height: 16),
        _SignUpField(
          label: 'Phone number',
          controller: phoneCtrl,
          icon: Icons.phone_outlined,
          hint: '+233 XX XXX XXXX',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),

        Text('Industry',
            style: AppType.body(
                size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
        const SizedBox(height: 6),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: industry,
              isExpanded: true,
              style: AppType.body(
                  size: 14, weight: FontWeight.w500, color: c.text),
              dropdownColor: c.bgElevated,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  color: c.textFaint, size: 20),
              items: _kIndustries
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onIndustryChanged(v);
              },
            ),
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(error!),
        ],

        const SizedBox(height: 28),
        AppBtn('Next →', full: true, fontSize: 15, onTap: onNext),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Step 2: Account credentials ───────────────────────────────────────────────

class _AccountStep extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController pwCtrl;
  final TextEditingController confirmPwCtrl;
  final bool obscurePw;
  final bool obscureConfirm;
  final VoidCallback onTogglePw;
  final VoidCallback onToggleConfirm;
  final String? error;
  final bool loading;
  final VoidCallback onSubmit;

  const _AccountStep({
    super.key,
    required this.emailCtrl,
    required this.pwCtrl,
    required this.confirmPwCtrl,
    required this.obscurePw,
    required this.obscureConfirm,
    required this.onTogglePw,
    required this.onToggleConfirm,
    required this.error,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your account', style: AppType.display(size: 28, color: c.text)),
        const SizedBox(height: 6),
        Text('Create your login credentials.',
            style: AppType.body(size: 14, color: c.textMuted)),
        const SizedBox(height: 28),

        _SignUpField(
          label: 'Email',
          controller: emailCtrl,
          icon: Icons.email_outlined,
          hint: 'hello@yourbusiness.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _SignUpField(
          label: 'Password',
          controller: pwCtrl,
          icon: Icons.lock_outline,
          hint: 'At least 8 characters',
          obscure: obscurePw,
          suffix: GestureDetector(
            onTap: onTogglePw,
            child: Icon(
              obscurePw
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
              color: c.textFaint,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SignUpField(
          label: 'Confirm password',
          controller: confirmPwCtrl,
          icon: Icons.lock_outline,
          hint: 'Repeat your password',
          obscure: obscureConfirm,
          suffix: GestureDetector(
            onTap: onToggleConfirm,
            child: Icon(
              obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 18,
              color: c.textFaint,
            ),
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: 14),
          _ErrorBanner(error!),
        ],

        const SizedBox(height: 28),
        loading
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
            : AppBtn('Create account', full: true, fontSize: 15,
                onTap: onSubmit),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Step 3: Email confirmation ────────────────────────────────────────────────

class _SuccessStep extends StatelessWidget {
  final String email;
  const _SuccessStep({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.teal, c.tealDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: c.teal.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              color: Colors.white, size: 36),
        ),
        const SizedBox(height: 28),
        Text('Check your inbox!',
            style: AppType.display(size: 26, color: c.text)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'We sent a confirmation link to\n$email\n\nClick the link to activate your account,\nthen come back and sign in.',
            textAlign: TextAlign.center,
            style: AppType.body(size: 14, color: c.textMuted),
          ),
        ),
        const SizedBox(height: 36),
        AppBtn(
          'Back to Sign In',
          full: true,
          fontSize: 15,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Shared field ──────────────────────────────────────────────────────────────

class _SignUpField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _SignUpField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppType.body(
                size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
        const SizedBox(height: 6),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(icon, size: 17, color: c.textFaint),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  style: AppType.body(
                      size: 14, weight: FontWeight.w500, color: c.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: hint,
                    hintStyle: AppType.body(size: 14, color: c.textFaint),
                  ),
                ),
              ),
              if (suffix != null) ...[suffix!, const SizedBox(width: 14)],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.rose.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.rose.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: c.rose),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text(message, style: AppType.body(size: 13, color: c.rose))),
        ],
      ),
    );
  }
}
