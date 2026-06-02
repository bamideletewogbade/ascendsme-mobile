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

class _SignInScreenState extends State<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwFocus = FocusNode();
  bool _obscure = true;
  bool _rememberDevice = true;

  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 24),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceCtrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwFocus.dispose();
    _entranceCtrl.dispose();
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
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 36),

              // ── Brand wordmark (centered) ─────────────
              Center(                  child: Text('AscendSME',
                    style: AppType.heading(size: 22, color: c.teal)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
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
              ),

              const SizedBox(height: 36),

              // ── Headline (centered) ───────────────────
              Text('Welcome Back',
                  textAlign: TextAlign.center,
                  style: AppType.display(size: 30, color: c.teal)),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Access your business dashboard and financial tools.',
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 14, color: c.textMuted),
                ),
              ),

              const SizedBox(height: 26),

              // ── Form card ─────────────────────────────
              AppCard(
                padding: const EdgeInsets.all(20),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InputField(
                        label: 'Email address',
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
                      const SizedBox(height: 14),
                      // Password label row with inline "Forgot password?" link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Password',
                              style: AppType.body(
                                  size: 11.5,
                                  weight: FontWeight.w600,
                                  color: c.textMuted)),
                          GestureDetector(
                            onTap: _openForgotPassword,
                            behavior: HitTestBehavior.opaque,
                            child: Text('Forgot Password?',
                                style: AppType.body(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: c.blueDeep)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _InputField(
                        label: '',
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

                      const SizedBox(height: 14),
                      // Remember-this-device checkbox. Supabase already
                      // persists sessions across launches; this toggle is
                      // surfaced so users have explicit visibility into it.
                      GestureDetector(
                        onTap: () => setState(
                            () => _rememberDevice = !_rememberDevice),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _rememberDevice
                                    ? c.teal
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: _rememberDevice
                                        ? c.teal
                                        : c.borderStrong,
                                    width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: _rememberDevice
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text('Remember this device',
                                style: AppType.body(
                                    size: 13.5, color: c.text)),
                          ],
                        ),
                      ),

                      // ── Error message ─────────────────
                      if (state.authError != null) ...[
                        const SizedBox(height: 14),
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
                                child: Text(state.authError!,
                                    style: AppType.body(
                                        size: 13, color: c.rose)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // ── Sign in button (navy with right arrow) ──
                      state.authLoading
                          ? Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation(c.teal),
                                ),
                              ),
                            )
                          : SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _signIn,
                                icon: Text('Sign in',
                                    style: AppType.body(
                                        size: 15,
                                        weight: FontWeight.w600,
                                        color: Colors.white)),
                                label: const Icon(Icons.arrow_forward,
                                    size: 18, color: Colors.white),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.teal,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24),
                                ),
                              ),
                            ),

                      const SizedBox(height: 18),

                      // ── OR LOGIN WITH divider ────────
                      Row(
                        children: [
                          Expanded(child: Divider(color: c.border)),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OR LOGIN WITH',
                                style: AppType.label(
                                    size: 11, color: c.textFaint)),
                          ),
                          Expanded(child: Divider(color: c.border)),
                        ],
                      ),

                      const SizedBox(height: 18),
                      GoogleSignInButton(onPressed: _signInWithGoogle),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

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
                              AppType.body(size: 13.5, color: c.textMuted)),
                      Text('Create an Account',
                          style: AppType.body(
                              size: 13.5,
                              weight: FontWeight.w700,
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
        if (label.isNotEmpty) ...[
          Text(label,
              style: AppType.body(
                  size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
          const SizedBox(height: 6),
        ],
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: c.bgInset,
            borderRadius: BorderRadius.circular(12),
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
