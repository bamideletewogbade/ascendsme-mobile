import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import '../services/app_logger.dart';
import '../state/app_state.dart';
import 'tokens.dart';
import 'widgets/common.dart';

/// First-run onboarding wizard for new SME owners.
///
/// Shows a guided overlay with three steps:
///   1. Welcome — brief intro to the home screen
///   2. Quick tour — points out cash flow hero, quick actions, recommendations
///   3. Sample data — loads demo invoices, receipts, and expenses
///
/// Automatically detects first run via SharedPreferences.
class OnboardingWizard extends StatefulWidget {
  final VoidCallback onDismissed;

  const OnboardingWizard({super.key, required this.onDismissed});

  /// Check if onboarding has been completed. Returns false on first run.
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferencesHelper.getInstance();
    return prefs.getBool('ascend_onboarding_done') ?? false;
  }

  /// Mark onboarding as completed so it doesn't show again.
  static Future<void> markCompleted() async {
    final prefs = await SharedPreferencesHelper.getInstance();
    await prefs.setBool('ascend_onboarding_done', true);
  }

  /// Reset onboarding flag (for testing).
  static Future<void> reset() async {
    final prefs = await SharedPreferencesHelper.getInstance();
    await prefs.setBool('ascend_onboarding_done', false);
  }

  /// Check if sample data has been loaded.
  static Future<String?> sampleDataStatus() async {
    final prefs = await SharedPreferencesHelper.getInstance();
    final loaded = prefs.getBool('ascend_sample_data_loaded');
    if (loaded == true) return 'loaded';
    final skipped = prefs.getBool('ascend_sample_data_skipped');
    if (skipped == true) return 'skipped';
    return null;
  }

  /// Load sample data into the current business's Supabase tables.
  /// Creates 2 sample invoices, 1 receipt, and 2 expenses.
  static Future<bool> loadSampleData(String businessId) async {
    log.info('OnboardingWizard — loading sample data for bizId=$businessId');
    try {
      final now = DateTime.now();

      // Sample invoices
      await SupabaseService.createInvoice(
        businessId: businessId,
        customerName: 'Nana Yaa Ent. (Sample)',
        totalAmount: 2500,
        description: 'Bulk fabric order — kente & damask',
        isProforma: false,
      );
      await SupabaseService.createInvoice(
        businessId: businessId,
        customerName: 'Kwame Mensah (Sample)',
        totalAmount: 800,
        description: 'Tailoring consultation & fitting',
        isProforma: false,
      );

      // Sample sale (receipt)
      await SupabaseService.createSale(
        businessId: businessId,
        amount: 450,
        paymentMethod: 'momo',
        paidDate: now.subtract(const Duration(days: 2)),
        customerName: 'Adwoa Serwaa (Sample)',
        description: 'Ready-to-wear dress — walk-in purchase',
      );

      // Sample expenses
      await SupabaseService.createExpense(
        businessId: businessId,
        amount: 1200,
        date: now.subtract(const Duration(days: 5)),
        description: 'Fabric purchase from Makola Market',
        category: 'Stock',
        paymentSource: 'cash',
      );
      await SupabaseService.createExpense(
        businessId: businessId,
        amount: 300,
        date: now.subtract(const Duration(days: 3)),
        description: 'Shop electricity token',
        category: 'Utilities',
        paymentSource: 'momo',
      );

      // Mark as loaded
      final prefs = await SharedPreferencesHelper.getInstance();
      await prefs.setBool('ascend_sample_data_loaded', true);
      log.info('OnboardingWizard — sample data loaded successfully');
      return true;
    } catch (e, st) {
      log.error('OnboardingWizard — sample data failed', error: e, stackTrace: st);
      return false;
    }
  }

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  bool _loadingSample = false;
  String? _sampleError;
  bool _sampleDone = false;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  static const _steps = [
    _StepConfig(
      icon: Icons.auto_awesome_rounded,
      title: 'Welcome to AscendSME',
      subtitle: 'Your business in your pocket',
      body:
          'We track your cash flow, send invoices, log expenses, and help you '
          'make smarter decisions — all in one place. Let\'s take a quick tour.',
    ),
    _StepConfig(
      icon: Icons.explore_outlined,
      title: 'Your dashboard at a glance',
      subtitle: 'Everything you need, right here',
      body:
          'The home screen shows your cash flow snapshot at the top — how much '
          'you\'ve earned vs spent this period. Below that, quick tools let you '
          'send an invoice, log a sale, or record an expense in one tap.',
    ),
    _StepConfig(
      icon: Icons.science_outlined,
      title: 'Explore with sample data',
      subtitle: 'See it in action first',
      body:
          'We can load a few sample records so you can see how the dashboard, '
          'activity feed, and reports look with real data. You can delete them later.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _steps.length - 1) {
      _fadeCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() => _step++);
        _fadeCtrl.forward();
      });
    }
  }

  void _prev() {
    if (_step > 0) {
      _fadeCtrl.reverse().then((_) {
        if (!mounted) return;
        setState(() => _step--);
        _fadeCtrl.forward();
      });
    }
  }

  Future<void> _loadSample() async {
    setState(() {
      _loadingSample = true;
      _sampleError = null;
    });
    final state = context.read<AppState>();
    final bizId = state.business.id;
    if (bizId == null) {
      setState(() {
        _loadingSample = false;
        _sampleError = 'Business not loaded yet. Try again.';
      });
      return;
    }
    final ok = await OnboardingWizard.loadSampleData(bizId);
    if (!mounted) return;
    if (ok) {
      setState(() => _sampleDone = true);
      await state.refreshAll();
    } else {
      setState(() {
        _loadingSample = false;
        _sampleError = 'Could not load sample data. Check your connection.';
      });
    }
  }

  void _finish() async {
    await OnboardingWizard.markCompleted();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final step = _steps[_step];

    return Stack(
      children: [
        // Semi-transparent backdrop
        GestureDetector(
          onTap: _step == _steps.length - 1 && _sampleDone ? _finish : null,
          child: Container(color: Colors.black.withValues(alpha: 0.35)),
        ),
        // Center card
        Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: c.bgElevated,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppShadows.sheet,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Step indicator dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_steps.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: i == _step ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _step ? c.teal : c.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),

                      // Icon
                      if (!_sampleDone) ...[
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: c.tealSurface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(step.icon, size: 28, color: c.tealDeep),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Sample data done state
                      if (_sampleDone) ...[
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: c.greenSurface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(Icons.check_circle_outline,
                              size: 28, color: c.green),
                        ),
                        const SizedBox(height: 20),
                        Text('Sample data loaded!',
                            style: AppType.display(
                                size: 22, color: c.text)),
                        const SizedBox(height: 8),
                        Text(
                          'Your dashboard now shows 2 sample invoices, '
                          '1 receipt, and 2 expenses. '
                          'Tap finish to start using the app.',
                          textAlign: TextAlign.center,
                          style: AppType.body(
                              size: 13.5, color: c.textMuted),
                        ),
                        const SizedBox(height: 24),
                        AppBtn('Finish setup',
                            full: true, onTap: _finish),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _finish,
                          child: Text('Skip, I\'ll explore',
                              style: AppType.body(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: c.textMuted)),
                        ),
                      ] else ...[
                        // Title
                        Text(step.title,
                            textAlign: TextAlign.center,
                            style: AppType.display(
                                size: 22, color: c.text)),
                        const SizedBox(height: 4),
                        Text(step.subtitle,
                            textAlign: TextAlign.center,
                            style: AppType.body(
                                size: 12,
                                weight: FontWeight.w600,
                                color: c.teal)),
                        const SizedBox(height: 14),
                        Text(
                          step.body,
                          textAlign: TextAlign.center,
                          style: AppType.body(
                              size: 13.5, color: c.textMuted),
                        ),

                        const SizedBox(height: 28),

                        // Sample data step — load button
                        if (_step == 2) ...[
                          if (_loadingSample)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation(c.teal),
                                ),
                              ),
                            )
                          else ...[
                            SizedBox(
                              width: double.infinity,
                              child: AppBtn(
                                'Load sample data',
                                icon: 'download',
                                onTap: _loadSample,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_sampleError != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: c.rose.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(_sampleError!,
                                    style: AppType.body(
                                        size: 12, color: c.rose)),
                              ),
                            ),
                          GestureDetector(
                            onTap: _finish,
                            child: Text('Skip sample data',
                                style: AppType.body(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: c.textMuted)),
                          ),
                        ],

                        // Navigation buttons
                        if (_step < 2) ...[
                          Row(
                            children: [
                              if (_step > 0)
                                Expanded(
                                  child: AppBtn('Back',
                                      variant: BtnVariant.secondary,
                                      onTap: _prev),
                                ),
                              if (_step > 0) const SizedBox(width: 12),
                              Expanded(
                                flex: _step == 0 ? 1 : 2,
                                child: AppBtn(
                                    _step < _steps.length - 1
                                        ? 'Continue'
                                        : 'Finish',
                                    onTap: _step < _steps.length - 1
                                        ? _next
                                        : _finish),
                              ),
                              if (_step == 0)
                                GestureDetector(
                                  onTap: _finish,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Text('Skip',
                                        style: AppType.body(
                                            size: 13,
                                            weight: FontWeight.w600,
                                            color: c.textMuted)),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepConfig {
  final IconData icon;
  final String title, subtitle, body;
  const _StepConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
  });
}

/// Minimal SharedPreferences helper — delegates to the official package.
class SharedPreferencesHelper {
  static Future<SharedPreferences> getInstance() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      // Fallback for edge-case init failures (e.g. no binding yet).
      if (kDebugMode) print('SharedPreferencesHelper error: $e');
      rethrow;
    }
  }
}
