import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/subscription_service.dart';
import '../../services/payment_service.dart';
import '../../state/app_state.dart';

/// Subscription management screen — view current plan, compare tiers, upgrade
/// or downgrade. Accessible from Profile and Settings.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  BillingPeriod _selectedPeriod = BillingPeriod.monthly;
  String? _selectedTierId;
  bool _processing = false;
  String? _processError;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final state = context.read<AppState>();
    try {
      _loadFailed = false;
      if (state.availablePlans.isEmpty) {
        await state.loadAvailablePlans();
      }
      await state.loadSubscription();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    await Future.wait([
      state.loadAvailablePlans(),
      state.loadSubscription(),
    ]);
  }

  /// True when [plan] matches the business's current subscription.
  bool _isCurrentPlan(SubscriptionPlan plan, SubscriptionInfo? currentSub) {
    if (currentSub?.tierId == plan.id) return true;
    if (currentSub != null && currentSub.tierCode == plan.tierCode) return true;
    return false;
  }

  Future<void> _selectPlan(String tierId) async {
    final state = context.read<AppState>();
    final plan = state.availablePlans.where((p) => p.id == tierId).firstOrNull;
    if (plan != null && _isCurrentPlan(plan, state.subscription)) return;

    setState(() {
      _selectedTierId = tierId;
      _processError = null;
    });
  }

  Future<void> _confirmUpgrade() async {
    if (_selectedTierId == null) return;

    setState(() {
      _processing = true;
      _processError = null;
    });

    final state = context.read<AppState>();
    final businessId = state.business.id;
    final plan =
        state.availablePlans.where((p) => p.id == _selectedTierId).firstOrNull;

    if (businessId == null) {
      _setError('Business profile not ready.');
      return;
    }
    if (plan == null) {
      _setError('Selected plan not found.');
      return;
    }
    if (!state.supabaseConfigured) {
      _setError('Subscription requires a server connection. Sign in to continue.');
      return;
    }

    try {
      // Step 1 — collect payment when the plan has a price
      final price = _priceForPlan(plan);
      if (price > 0) {
        final email = state.user?.email ?? '';
        final result = await PaymentService.chargeCard(
          context: context,
          email: email.isNotEmpty ? email : 'customer@ascendsme.app',
          amountGhs: price,
          businessId: businessId,
        );
        if (!result.success) {
          _setError(result.errorMessage ?? 'Payment failed. Please try again.');
          return;
        }
      }

      // Step 2 — create / update the subscription
      await SubscriptionService.createSubscription(
        businessId: businessId,
        tierId: _selectedTierId!,
        billingPeriod: _selectedPeriod,
      );

      if (!mounted) return;
      unawaited(state.loadSubscription());
      unawaited(state.loadBusiness());
      setState(() {
        _processing = false;
        _selectedTierId = null;
      });
      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      _setError('Failed to update subscription. Please try again.');
    }
  }

  void _setError(String msg) {
    setState(() {
      _processing = false;
      _processError = msg;
    });
  }

  Future<void> _cancelSubscription() async {
    final state = context.read<AppState>();
    final sub = state.subscription;
    if (sub == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: const Text(
          'Your plan will remain active until the current billing period ends, '
          'then your business will revert to the Free plan. No further charges.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: ctx.colors.rose),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _processing = true;
      _processError = null;
    });

    try {
      await SubscriptionService.cancelSubscription(
        subscriptionId: sub.id,
      );
      if (!mounted) return;
      unawaited(state.loadSubscription());
      unawaited(state.loadBusiness());
      setState(() => _processing = false);
      _showCancelled();
    } catch (e) {
      if (!mounted) return;
      _setError('Failed to cancel. Please try again or contact support.');
    }
  }

  void _showSuccess() => _showResultSheet(
        icon: Icons.check,
        iconColor: context.colors.green,
        title: 'Plan updated',
        subtitle: 'Your subscription has been updated successfully.',
      );

  void _showCancelled() => _showResultSheet(
        icon: Icons.cancel_outlined,
        iconColor: context.colors.orange,
        title: 'Subscription cancelled',
        subtitle:
            'Your current plan is active until the end of the billing period.',
      );

  void _showResultSheet({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppType.heading(size: 22, color: c.text)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppType.body(size: 13, color: c.textMuted),
            ),
            const SizedBox(height: 24),
            AppBtn('Done',
                full: true,
                variant: BtnVariant.secondary,
                onTap: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final plans = state.availablePlans;
    final currentSub = state.subscription;
    final currentTierCode = currentSub?.tierCode ?? 'free';
    final isLoading = state.subscriptionLoading && plans.isEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader('Subscription',
                onBack: () => Navigator.pop(context)),
            Expanded(
              child: isLoading
                  ? const _LoadingState()
                  : _loadFailed
                      ? _ErrorState(onRetry: _loadData)
                      : _buildBody(c, plans, currentTierCode, currentSub),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    AppColorsX c,
    List<SubscriptionPlan> plans,
    String currentTierCode,
    SubscriptionInfo? currentSub,
  ) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: c.teal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
        // ── Current plan badge ──
        _CurrentPlanCard(
          currentTierCode: currentTierCode,
          currentSub: currentSub,
        ),

        if (currentSub != null && currentTierCode != 'free') ...[
          const SizedBox(height: 12),
          // ── Cancel subscription ──
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _processing ? null : _cancelSubscription,
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: Text(
                _processing ? 'Processing…' : 'Cancel subscription',
                style: AppType.body(
                  size: 12,
                  color: c.rose,
                  weight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.rose,
                side: BorderSide(color: c.rose.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // ── Billing period toggle ──
        if (plans.any((p) => p.priceMonthly > 0))
          _buildPeriodToggle(c),

        if (plans.any((p) => p.priceMonthly > 0))
          const SizedBox(height: 20),

        // ── Plan cards ──
        ...plans.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FadeInSlide(
                index: e.key,
                child: _PlanCard(
                  plan: e.value,
                  billingPeriod: _selectedPeriod,
                  isCurrent: _isCurrentPlan(e.value, currentSub),
                  isSelected: _selectedTierId == e.value.id,
                  onSelect: () => _selectPlan(e.value.id),
                ),
              ),
            )),

        // ── Confirm / subscribe button ──
        if (_selectedTierId != null) ...[
          const SizedBox(height: 8),
          if (_processError != null) _buildError(c),
          AppBtn(
            _buttonLabel(currentSub, plans),
            full: true,
            icon: _selectedTierId != null &&
                    _isDowngrade(currentSub, plans)
                ? 'arrow_downward'
                : 'north_east',
            onTap: _processing ? null : _confirmUpgrade,
          ),
        ],

        const SizedBox(height: 20),

        // ── Disclaimer ──
        Text(
          'Plans shown are in GHS (GH¢). Billed securely via Paystack. '
          'Contact support for enterprise or annual custom pricing.',
          style: AppType.body(size: 11.5, color: c.textFaint),
          textAlign: TextAlign.center,
        ),
      ],
    ));
  }

  Widget _buildPeriodToggle(AppColorsX c) {
    return Row(
      children: [
        _PeriodToggle(
          label: 'Monthly',
          active: _selectedPeriod == BillingPeriod.monthly,
          onTap: () => setState(() => _selectedPeriod = BillingPeriod.monthly),
        ),
        const SizedBox(width: 8),
        _PeriodToggle(
          label: 'Quarterly',
          active: _selectedPeriod == BillingPeriod.quarterly,
          onTap: () =>
              setState(() => _selectedPeriod = BillingPeriod.quarterly),
        ),
        const SizedBox(width: 8),
        _PeriodToggle(
          label: 'Yearly',
          active: _selectedPeriod == BillingPeriod.yearly,
          onTap: () => setState(() => _selectedPeriod = BillingPeriod.yearly),
          badge: 'Save 20%',
        ),
      ],
    );
  }

  Widget _buildError(AppColorsX c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
              child: Text(_processError!,
                  style: AppType.body(size: 13, color: c.rose)),
            ),
          ],
        ),
      ),
    );
  }

  /// Contextual button label: "Subscribe" for free → paid, "Confirm upgrade"
  /// for paid → more expensive, "Confirm downgrade" for paid → cheaper.
  String _buttonLabel(SubscriptionInfo? currentSub,
      List<SubscriptionPlan> plans) {
    if (_processing) return 'Processing…';
    if (currentSub == null || currentSub.tierCode == 'free') return 'Subscribe';
    if (_isDowngrade(currentSub, plans)) return 'Confirm downgrade';
    return 'Confirm upgrade';
  }

  /// True when the selected plan is cheaper than the current plan.
  bool _isDowngrade(SubscriptionInfo? currentSub,
      List<SubscriptionPlan> plans) {
    if (currentSub == null || _selectedTierId == null) return false;

    final currentPlan =
        plans.where((p) => p.tierCode == currentSub.tierCode).firstOrNull;
    final selectedPlan =
        plans.where((p) => p.id == _selectedTierId).firstOrNull;
    if (currentPlan == null || selectedPlan == null) return false;

    return _priceForPlan(selectedPlan) < _priceForPlan(currentPlan);
  }

  int _priceForPlan(SubscriptionPlan plan) {
    return switch (_selectedPeriod) {
      BillingPeriod.monthly => plan.priceMonthly,
      BillingPeriod.quarterly => plan.priceQuarterly ?? plan.priceMonthly * 3,
      BillingPeriod.yearly => plan.priceYearly ?? plan.priceMonthly * 12,
    };
  }
}

// ── Current plan card ─────────────────────────────────────────────────────────
class _CurrentPlanCard extends StatelessWidget {
  final String currentTierCode;
  final SubscriptionInfo? currentSub;

  const _CurrentPlanCard({
    required this.currentTierCode,
    this.currentSub,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = _displayTier(currentTierCode);
    final isFree = currentTierCode == 'free';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.navy, c.navyDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.navy,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isFree
                  ? Icons.favorite_outline
                  : Icons.workspace_premium_outlined,
              size: 22,
              color: c.green,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current plan',
                    style: AppType.body(
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.65))),
                const SizedBox(height: 2),
                Text(label,
                    style: AppType.heading(size: 18, color: Colors.white)),
                if (currentSub?.currentPeriodEnd != null &&
                    currentTierCode != 'free')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Renews ${_formatDate(currentSub!.currentPeriodEnd!)}',
                      style: AppType.body(
                          size: 10.5,
                          color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ),
              ],
            ),
          ),
          AppPill(
            currentTierCode == 'free' ? 'Free' : 'Active',
            tone: PillTone.inverse,
            small: true,
          ),
        ],
      ),
    );
  }

  String _displayTier(String code) {
    switch (code) {
      case 'free':
        return 'Ascend Free';
      case 'lite':
        return 'SME Suite Lite';
      case 'plus':
        return 'SME Suite Plus';
      case 'elite':
        return 'SME Suite Elite';
      default:
        return 'Free';
    }
  }

  String _formatDate(DateTime d) =>
      '${_kMonthNames[d.month - 1]} ${d.day}';
}

const _kMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

// ── Period toggle ──────────────────────────────────────────────────────────────
class _PeriodToggle extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? badge;

  const _PeriodToggle({
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? c.tealSurface : c.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? c.teal : c.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(label,
                  style: AppType.body(
                      size: 13,
                      weight: FontWeight.w600,
                      color: active ? c.teal : c.textMuted)),
              if (badge != null) ...[
                const SizedBox(height: 2),
                Text(badge!,
                    style: AppType.body(
                        size: 9,
                        weight: FontWeight.w600,
                        color: c.green)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Plan card ──────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final BillingPeriod billingPeriod;
  final bool isCurrent;
  final bool isSelected;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.billingPeriod,
    required this.isCurrent,
    required this.isSelected,
    required this.onSelect,
  });

  int get _price {
    return switch (billingPeriod) {
      BillingPeriod.monthly => plan.priceMonthly,
      BillingPeriod.quarterly => plan.priceQuarterly ?? plan.priceMonthly * 3,
      BillingPeriod.yearly => plan.priceYearly ?? plan.priceMonthly * 12,
    };
  }

  String get _periodLabel {
    return switch (billingPeriod) {
      BillingPeriod.monthly => '/mo',
      BillingPeriod.quarterly => '/quarter',
      BillingPeriod.yearly => '/year',
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final borderColor = isSelected
        ? c.teal
        : isCurrent
            ? c.green.withValues(alpha: 0.4)
            : c.border;

    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? AppShadows.card : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan.tierName,
                      style: AppType.heading(size: 18, color: c.text)),
                ),
                if (isCurrent)
                  AppPill('Current', tone: PillTone.green, small: true),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (plan.priceMonthly > 0)
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text:
                              'GHS ${_price.toString().replaceAllMapped(RegExp(r'(\\d)(?=(\\d{3})+(?!\\d))'), (m) => '${m[1]},')}',
                          style: AppType.display(size: 26, color: c.text),
                        ),
                        TextSpan(
                          text: _periodLabel,
                          style: AppType.body(size: 13, color: c.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  Text('Free',
                      style: AppType.display(size: 26, color: c.text)),
              ],
            ),
            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(plan.description!,
                  style: AppType.body(size: 12.5, color: c.textMuted)),
            ],
            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(height: 1, color: c.border),
              const SizedBox(height: 12),
              ...plan.features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check, size: 14, color: c.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f,
                              style: AppType.body(size: 12.5, color: c.text)),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Loading state ─────────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(c.teal)),
          ),
          const SizedBox(height: 12),
          Text('Loading plans…',
              style: AppType.body(size: 13, color: c.textMuted)),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: c.textFaint),
          const SizedBox(height: 12),
          Text('Could not load subscription data',
              style: AppType.body(size: 14, color: c.textMuted)),
          const SizedBox(height: 16),
          AppBtn('Retry', onTap: onRetry),
        ],
      ),
    );
  }
}
