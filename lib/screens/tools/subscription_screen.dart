import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/subscription_service.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.availablePlans.isEmpty) {
        state.loadAvailablePlans();
      }
    });
  }

  Future<void> _selectPlan(String tierId) async {
    final state = context.read<AppState>();
    final currentSub = state.subscription;

    // If this is the same as the current plan, no-op
    if (currentSub?.tierId == tierId) return;

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

    if (businessId == null) {
      setState(() { _processing = false; _processError = 'Business profile not ready.'; });
      return;
    }

    try {
      await SubscriptionService.createSubscription(
        businessId: businessId,
        tierId: _selectedTierId!,
        billingPeriod: _selectedPeriod,
      );

      if (!mounted) return;
      unawaited(state.loadSubscription());
      unawaited(state.loadBusiness()); // Refresh business.tier
      setState(() { _processing = false; _selectedTierId = null; });
      _showSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _processError = 'Failed to update subscription. Please try again.';
      });
    }
  }

  void _showSuccess() {
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
              width: 64, height: 64,
              decoration: BoxDecoration(color: c.greenSurface, shape: BoxShape.circle),
              child: Icon(Icons.check, size: 32, color: c.green),
            ),
            const SizedBox(height: 16),
            Text('Plan updated', style: AppType.heading(size: 22, color: c.text)),
            const SizedBox(height: 6),
            Text(
              'Your subscription has been updated successfully.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 13, color: c.textMuted),
            ),
            const SizedBox(height: 24),
            AppBtn('Done', full: true, variant: BtnVariant.secondary,
                onTap: () => Navigator.pop(ctx)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final plans = state.availablePlans;
    final currentSub = state.subscription;
    final currentTierCode = currentSub?.tierCode ?? 'free';

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader('Subscription', onBack: () => Navigator.pop(context)),
            Expanded(
              child: state.subscriptionLoading && plans.isEmpty
                  ? const _LoadingState()
                  : _buildBody(c, plans, currentTierCode),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppColorsX c, List<SubscriptionPlan> plans, String currentTierCode) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Current plan badge
        _CurrentPlanCard(currentTierCode: currentTierCode),

        const SizedBox(height: 24),

        // Billing period toggle
        Row(
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
              onTap: () => setState(() => _selectedPeriod = BillingPeriod.quarterly),
            ),
            const SizedBox(width: 8),
            _PeriodToggle(
              label: 'Yearly',
              active: _selectedPeriod == BillingPeriod.yearly,
              onTap: () => setState(() => _selectedPeriod = BillingPeriod.yearly),
              badge: 'Save 20%',
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Plan cards
        ...plans.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FadeInSlide(
                index: e.key,
                child: _PlanCard(
                  plan: e.value,
                  billingPeriod: _selectedPeriod,
                  isCurrent: e.value.tierCode == currentTierCode,
                  isSelected: _selectedTierId == e.value.id,
                  onSelect: () => _selectPlan(e.value.id),
                ),
              ),
            )),

        if (_selectedTierId != null && plans.isNotEmpty && _selectedTierId != plans.firstWhere((p) => p.tierCode == currentTierCode, orElse: () => plans.first).id) ...[
          const SizedBox(height: 8),
          if (_processError != null)
            Padding(
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
            ),
          AppBtn(
            'Confirm upgrade',
            full: true,
            icon: 'north_east',
            onTap: _processing ? null : _confirmUpgrade,
          ),
        ],

        const SizedBox(height: 20),

        // Plan comparison note
        Text(
          'Plans shown are in GHS (GH¢). Billed securely via the web platform. '
          'Contact support for enterprise or annual custom pricing.',
          style: AppType.body(size: 11.5, color: c.textFaint),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Current plan card ─────────────────────────────────────────────────────────
class _CurrentPlanCard extends StatelessWidget {
  final String currentTierCode;

  const _CurrentPlanCard({required this.currentTierCode});

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
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isFree ? Icons.favorite_outline : Icons.workspace_premium_outlined,
              size: 22, color: c.green,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current plan',
                    style: AppType.body(
                        size: 12, color: Colors.white.withValues(alpha: 0.65))),
                const SizedBox(height: 2),
                Text(label,
                    style: AppType.heading(size: 18, color: Colors.white)),
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
      case 'free': return 'Ascend Free';
      case 'lite': return 'SME Suite Lite';
      case 'plus': return 'SME Suite Plus';
      case 'elite': return 'SME Suite Elite';
      default: return 'Free';
    }
  }
}

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
                      size: 13, weight: FontWeight.w600,
                      color: active ? c.teal : c.textMuted)),
              if (badge != null) ...[
                const SizedBox(height: 2),
                Text(badge!,
                    style: AppType.body(
                        size: 9, weight: FontWeight.w600,
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
                Text('GHS ${_price.toString().replaceAllMapped(
                    RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                    style: AppType.display(size: 26, color: c.text)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(_periodLabel,
                      style: AppType.body(size: 13, color: c.textMuted)),
                ),
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
            width: 28, height: 28,
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
