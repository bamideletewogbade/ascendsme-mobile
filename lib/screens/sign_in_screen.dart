import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final state = context.read<AppState>();
    state.clearAuthError();
    await state.signIn(
      email: _emailCtrl.text.trim(),
      password: _pwCtrl.text,
    );
    // On success, AppState.authed becomes true.
    // _SplashGate's AnimatedSwitcher handles the transition to AppShell.
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: c.bgElevated,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // ── Brand ─────────────────────────────────
              Row(
                children: [
                  const AppMonogram(size: 36),
                  const SizedBox(width: 10),
                  Text('AscendSME',
                      style: AppType.heading(size: 22, color: c.text)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: c.bgInset,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🇬🇭', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text('Built for Ghana SMEs',
                        style: AppType.body(
                            size: 11,
                            weight: FontWeight.w600,
                            color: c.textMuted)),
                  ],
                ),
              ),

              const SizedBox(height: 52),

              // ── Headline ──────────────────────────────
              Text('Welcome back.',
                  style: AppType.display(size: 32, color: c.text)),
              const SizedBox(height: 8),
              Text('Sign in to your AscendSME workspace.',
                  style: AppType.body(size: 14, color: c.textMuted)),

              const SizedBox(height: 32),

              // ── Fields ────────────────────────────────
              _InputField(
                label: 'Email',
                controller: _emailCtrl,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _InputField(
                label: 'Password',
                controller: _pwCtrl,
                icon: Icons.lock_outline,
                obscure: _obscure,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: c.textFaint,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Forgot password?',
                    style: AppType.body(
                        size: 13,
                        weight: FontWeight.w600,
                        color: c.teal)),
              ),

              // ── Error message ─────────────────────────
              if (state.authError != null) ...[
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
                        child: Text(state.authError!,
                            style: AppType.body(size: 13, color: c.rose)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Sign in button ────────────────────────
              state.authLoading
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
                  : AppBtn(
                      'Sign in',
                      full: true,
                      fontSize: 15,
                      onTap: _signIn,
                    ),

              const SizedBox(height: 18),

              // ── Divider ───────────────────────────────
              Row(
                children: [
                  Expanded(child: Divider(color: c.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: AppType.label(size: 11, color: c.textFaint)),
                  ),
                  Expanded(child: Divider(color: c.border)),
                ],
              ),

              const SizedBox(height: 18),

              // ── Phone option ──────────────────────────
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Phone sign-in coming soon.',
                        style: AppType.body(size: 13, color: Colors.white),
                      ),
                      backgroundColor: c.tealDeep,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 18),
                  decoration: BoxDecoration(
                    color: c.bgElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.borderStrong),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone_outlined, size: 18, color: c.text),
                      const SizedBox(width: 10),
                      Text('Continue with phone',
                          style: AppType.body(
                              size: 14,
                              weight: FontWeight.w600,
                              color: c.text)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Sign up prompt ────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SignUpScreen()),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('New to AscendSME? ',
                          style:
                              AppType.body(size: 13, color: c.textMuted)),
                      Text('Create an account',
                          style: AppType.body(
                              size: 13,
                              weight: FontWeight.w600,
                              color: c.teal)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Input field ───────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _InputField({
    required this.label,
    required this.controller,
    required this.icon,
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
            color: c.bg,
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
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
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
