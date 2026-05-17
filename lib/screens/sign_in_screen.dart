import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../services/app_logger.dart';
import '../state/app_state.dart';
import 'sheets/forgot_password_sheet.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    log.info('SignInScreen — sign in tapped email=${AppLogger.maskEmail(_emailCtrl.text.trim())}');
    final state = context.read<AppState>();
    state.clearAuthError();
    // Tell the platform autofill engine the credentials are committed so the
    // password manager can save them on first successful sign-in.
    TextInput.finishAutofillContext();
    await state.signIn(
      email: _emailCtrl.text.trim(),
      password: _pwCtrl.text,
    );
    // On success, AppState.authed becomes true and _AuthGate transitions to
    // AppShell. No manual Navigator work needed here.
  }

  Future<void> _signInWithGoogle() async {
    log.info('SignInScreen — Google sign-in tapped');
    final state = context.read<AppState>();
    state.clearAuthError();
    await state.signInWithGoogle();
    // The session arrives via the auth stream listener (signedIn event) and
    // _AuthGate switches to AppShell. If the user cancels the OAuth flow,
    // _authLoading remains true until they tap again or sign in another way.
  }

  void _openForgotPassword() {
    log.info('SignInScreen — forgot password tapped');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ForgotPasswordSheet(initialEmail: _emailCtrl.text.trim()),
    );
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
                  // const AppMonogram(size: 36),
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

              // ── Fields (wrapped in AutofillGroup so the platform's password
              // manager can save the email + password as a single credential) ──
              AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InputField(
                      label: 'Email',
                      controller: _emailCtrl,
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      onSubmitted: (_) => _pwFocus.requestFocus(),
                    ),
                    const SizedBox(height: 12),
                    _InputField(
                      label: 'Password',
                      controller: _pwCtrl,
                      focusNode: _pwFocus,
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _signIn(),
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
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _openForgotPassword,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('Forgot password?',
                        style: AppType.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: c.teal)),
                  ),
                ),
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

              // ── Google sign-in ────────────────────────
              GoogleSignInButton(onPressed: _signInWithGoogle),

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
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const _InputField({
    required this.label,
    required this.controller,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.focusNode,
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
                  focusNode: focusNode,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  autofillHints: autofillHints,
                  onSubmitted: onSubmitted,
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
