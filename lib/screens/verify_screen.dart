import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../core/models.dart';
import '../state/app_state.dart';
import 'verify_step_screen.dart';

/// Trust Vault — the mobile equivalent of web's VerificationCenter.
///
/// Three-tier verification system:
///   Tier 1: Access (Grey)  — Always unlocked, active platform use
///   Tier 2: Legitimacy (Teal) — Ghana Card + RGD Certificate
///   Tier 3: Sustainability (Indigo) — TIN Certificate + Proof of Address + Bank Statements
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  bool _showMyDocs = false;
  bool _showBusinessProfile = false;

  bool _isTierLocked(int tier, List<VerificationStep> steps) {
    if (tier <= 2) return false;
    final tier2Steps = steps.where((s) => s.tier == 2);
    return tier2Steps.isNotEmpty && !tier2Steps.every((s) => s.status == 'verified');
  }

  (int, int) _tierProgress(int tier, List<VerificationStep> steps) {
    final tierSteps = steps.where((s) => s.tier == tier).toList();
    final done = tierSteps.where((s) => s.status == 'verified').length;
    return (done, tierSteps.length);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final business = state.business;
    final steps = state.verificationSteps;
    final progress = state.verificationProgress;
    final pct = (progress * 100).round();

    final tier2Steps = steps.where((s) => s.tier == 2).toList();
    final tier3Steps = steps.where((s) => s.tier == 3).toList();
    final tier3Locked = _isTierLocked(3, steps);
    final (tier2Done, tier2Total) = _tierProgress(2, steps);
    final (tier3Done, tier3Total) = _tierProgress(3, steps);
    final totalDone = state.verificationDone;
    final totalSteps = state.verificationTotal;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            // ── Header with back button ──
            SubScreenHeader('Trust Vault',
                onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Complete verification to unlock features and become investment-ready',
                style: AppType.body(size: 13, color: c.textMuted).copyWith(height: 1.4),
              ),
            ),
            const SizedBox(height: 16),

            // ── Trust Score — Circular Progress ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Business info row
                    Row(
                      children: [
                        AppAvatar(business.initials,
                            size: 40, imageUrl: business.logoUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(business.name,
                                  style: AppType.heading(size: 15, color: c.text)),
                              const SizedBox(height: 1),
                              Text(business.handle,
                                  style: AppType.body(size: 12, color: c.textMuted)),
                            ],
                          ),
                        ),
                        if (totalDone == totalSteps && totalSteps > 0)
                          AppPill('Verified', tone: PillTone.green,
                              icon: 'check_circle', small: true),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Centered circular progress ring
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CustomPaint(
                              painter: _TrustScoreRingPainter(
                                progress: progress,
                                trackColor: c.bgInset,
                                progressColor: progress >= 0.8
                                    ? c.green
                                    : progress >= 0.4
                                        ? c.teal
                                        : c.amber,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$pct%',
                                        style: AppType.display(
                                            size: 28, color: c.text)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Verification Progress',
                              style: AppType.body(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: c.textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(height: 8, color: c.bgInset),
                          LayoutBuilder(
                            builder: (_, constraints) => AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              height: 8,
                              width: constraints.maxWidth * progress,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: LinearGradient(
                                  colors: progress >= 0.8
                                      ? [c.green, c.greenDeep]
                                      : [c.teal, c.tealDeep],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('$pct% complete',
                            style: AppType.body(size: 11.5, color: c.textMuted)),
                        const Spacer(),
                        Text(
                          totalDone == totalSteps
                              ? 'All verified'
                              : '$totalDone verified',
                          style: AppType.body(size: 11.5,
                              weight: FontWeight.w600,
                              color: progress >= 0.8 ? c.green : c.teal),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Business Profile (collapsible) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _BusinessProfileSection(
                expanded: _showBusinessProfile,
                onToggle: () => setState(() => _showBusinessProfile = !_showBusinessProfile),
                business: business,
                state: state,
              ),
            ),
            const SizedBox(height: 24),

            // ── Tier Sections ──
            _TierSection(
              tierNumber: 1,
              title: 'Access',
              subtitle: 'Active platform use — getting started',
              color: c.textFaint,
              icon: Icons.shield_outlined,
              steps: const [],
              doneCount: 0,
              totalCount: 1,
              isLocked: false,
            ),
            const SizedBox(height: 16),

            _TierSection(
              tierNumber: 2,
              title: 'Legitimacy',
              subtitle: tier2Done == tier2Total && tier2Total > 0
                  ? 'All complete'
                  : 'Unlocks invoicing & gigs',
              color: c.teal,
              icon: Icons.business_outlined,
              steps: tier2Steps,
              doneCount: tier2Done,
              totalCount: tier2Total,
              isLocked: false,
              onStepTap: (step) => _handleStepTap(step),
            ),
            const SizedBox(height: 16),

            _TierSection(
              tierNumber: 3,
              title: 'Sustainability',
              subtitle: tier3Locked
                  ? 'Complete Legitimacy first'
                  : 'Unlocks funding & marketplace',
              color: const Color(0xFF5B5BD6),
              icon: Icons.trending_up_outlined,
              steps: tier3Steps,
              doneCount: tier3Done,
              totalCount: tier3Total,
              isLocked: tier3Locked,
              onStepTap: tier3Locked ? null : (step) => _handleStepTap(step),
            ),
            const SizedBox(height: 24),

            // ── My Docs ──
            _MyDocsSection(
              expanded: _showMyDocs,
              onToggle: () => setState(() => _showMyDocs = !_showMyDocs),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _handleStepTap(VerificationStep step) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VerifyStepScreen(step: step)),
    );
  }
}

// ── Trust Score Ring Painter ────────────────────────────────────────────────

class _TrustScoreRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _TrustScoreRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 10.0;
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawArc(rect, 0, 2 * 3.14159, false,
        Paint()..color = trackColor..style = PaintingStyle.stroke..strokeWidth = stroke);

    // Progress arc
    canvas.drawArc(
      rect, -3.14159 / 2, 2 * 3.14159 * progress.clamp(0.0, 1.0), false,
      Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TrustScoreRingPainter old) =>
      old.progress != progress || old.trackColor != trackColor || old.progressColor != progressColor;
}

// ── Business Profile Section (collapsible) ──────────────────────────────────

class _BusinessProfileSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final Business business;
  final AppState state;

  const _BusinessProfileSection({
    required this.expanded,
    required this.onToggle,
    required this.business,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.business_outlined, size: 18, color: c.teal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Business Profile',
                            style: AppType.heading(size: 15, color: c.text)),
                        const SizedBox(height: 1),
                        Text(
                          'Your business information for invoices, receipts, and official documents',
                          style: AppType.body(size: 11.5, color: c.textMuted)),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: c.textFaint,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Logo
                  Row(
                    children: [
                      AppAvatar(business.initials,
                          size: 48, imageUrl: business.logoUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Business Logo',
                                style: AppType.body(
                                    size: 12, weight: FontWeight.w600, color: c.text)),
                            const SizedBox(height: 2),
                            Text('This logo appears on your invoices and receipts.',
                                style: AppType.body(size: 11, color: c.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Contact fields
                  _ProfileField(
                    icon: Icons.business_outlined,
                    label: 'Business Name',
                    value: business.name,
                  ),
                  const SizedBox(height: 10),
                  _ProfileField(
                    icon: Icons.location_on_outlined,
                    label: 'City & Region',
                    value: '${business.city}${business.region != '—' ? ', ${business.region}' : ''}',
                  ),
                  const SizedBox(height: 10),
                  _ProfileField(
                    icon: Icons.category_outlined,
                    label: 'Industry',
                    value: business.industry,
                  ),
                  const SizedBox(height: 10),
                  _ProfileField(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: state.user?.email ?? '—',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.teal.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.teal.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: c.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Edit your business details in Settings',
                            style: AppType.body(size: 12, color: c.textMuted)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Profile Field ──────────────────────────────────────────────────────────

class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasValue = value.isNotEmpty && value != '—';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: c.textFaint),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppType.body(size: 10.5, color: c.textFaint)),
              const SizedBox(height: 1),
              Text(hasValue ? value : 'Not set',
                  style: AppType.body(
                    size: 13,
                    weight: FontWeight.w500,
                    color: hasValue ? c.text : c.textFaint,
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tier Section (collapsible dropdown) ─────────────────────────────────────

class _TierSection extends StatefulWidget {
  final int tierNumber;
  final String title, subtitle;
  final Color color;
  final IconData icon;
  final List<VerificationStep> steps;
  final int doneCount, totalCount;
  final bool isLocked;
  final void Function(VerificationStep)? onStepTap;

  const _TierSection({
    required this.tierNumber,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.steps,
    required this.doneCount,
    required this.totalCount,
    required this.isLocked,
    this.onStepTap,
  });

  @override
  State<_TierSection> createState() => _TierSectionState();
}

class _TierSectionState extends State<_TierSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final allDone = widget.totalCount > 0 && widget.doneCount == widget.totalCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  // Icon badge
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: widget.isLocked
                          ? c.bgInset
                          : (allDone ? widget.color.withValues(alpha: 0.15) : widget.color.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(10),
                      border: allDone && !widget.isLocked
                          ? Border.all(color: widget.color.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Icon(widget.icon, size: 18,
                        color: widget.isLocked ? c.textFaint : widget.color),
                  ),
                  const SizedBox(width: 12),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text('Tier ${widget.tierNumber}: ${widget.title}',
                                  style: AppType.heading(size: 14, color: c.text),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (widget.isLocked) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: c.bgInset,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(Icons.lock_outline, size: 12, color: c.textFaint),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(widget.subtitle,
                            style: AppType.body(size: 11.5,
                                color: widget.isLocked ? c.textFaint : c.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Progress badge + chevron
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.steps.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: (allDone ? c.green : c.teal).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (allDone ? c.green : c.teal).withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (allDone) ...[
                                Icon(Icons.check, size: 11, color: c.green),
                                const SizedBox(width: 3),
                              ],
                              Text('${widget.doneCount}/${widget.totalCount}',
                                  style: AppType.body(size: 11, weight: FontWeight.w700,
                                      color: allDone ? c.green : c.teal)),
                            ],
                          ),
                        ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more, size: 20, color: c.textFaint),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Collapsible content: task cards (or empty-state for Tier 1) ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  if (widget.steps.isNotEmpty)
                    ...widget.steps.map((step) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TaskCard(
                            step: step,
                            isLocked: widget.isLocked,
                            onTap: (widget.isLocked || widget.onStepTap == null) ? null : () => widget.onStepTap!(step),
                          ),
                        )),
                  if (widget.steps.isEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: c.green.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.green.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: c.green.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.check_circle, size: 16, color: c.green),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Active platform user',
                                style: AppType.body(size: 13, weight: FontWeight.w500, color: c.text)),
                          ),
                          AppPill('Active', tone: PillTone.green, small: true),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ── Task Card ────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final VerificationStep step;
  final bool isLocked;
  final VoidCallback? onTap;

  const _TaskCard({
    required this.step,
    required this.isLocked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (icon, iconColor, iconBg, tone, badgeLabel) = switch (step.status) {
      'verified' => (
        Icons.check_circle_rounded,
        c.green,
        c.green.withValues(alpha: 0.1),
        PillTone.green,
        'Done'
      ),
      'pending'  => (
        Icons.access_time_rounded,
        c.orange,
        c.orange.withValues(alpha: 0.1),
        PillTone.orange,
        'Pending'
      ),
      _ => (
        isLocked ? Icons.lock_outline : Icons.radio_button_unchecked,
        isLocked ? c.textFaint : c.teal,
        isLocked ? c.bgInset : c.teal.withValues(alpha: 0.08),
        PillTone.neutral,
        isLocked ? 'Locked' : 'To-do'
      ),
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.label,
                    style: AppType.body(
                        size: 13, weight: FontWeight.w600,
                        color: isLocked ? c.textFaint : c.text)),
                const SizedBox(height: 2),
                Text(
                  isLocked ? 'Finish Tier 2 steps to unlock' : 
                  (step.status == 'verified' ? 'Completed' : step.detail),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.body(size: 11.5,
                      color: isLocked ? c.textFaint.withValues(alpha: 0.7) : 
                             step.status == 'verified' ? c.green : c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppPill(badgeLabel, tone: tone, small: true),
        ],
      ),
    );
  }
}

// ── My Docs Section ─────────────────────────────────────────────────────────

class _MyDocsSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _MyDocsSection({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionHeader('My Docs')),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.teal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(expanded ? 'Hide' : 'Show',
                          style: AppType.body(size: 12, weight: FontWeight.w600, color: c.teal)),
                      const SizedBox(width: 3),
                      Icon(expanded ? Icons.expand_less : Icons.expand_more,
                          size: 16, color: c.teal),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (expanded)
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.teal.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.teal.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: c.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.info_outline, size: 16, color: c.teal),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Documents uploaded for verification are saved here automatically.',
                            style: AppType.body(size: 12, color: c.textMuted).copyWith(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: c.bgInset,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.folder_open_rounded, size: 36, color: c.textFaint),
                  ),
                  const SizedBox(height: 12),
                  Text('No documents yet',
                      style: AppType.body(size: 14, weight: FontWeight.w600, color: c.textMuted)),
                  const SizedBox(height: 4),
                  Text(
                    'Documents you upload for verification steps\nwill appear here.',
                    textAlign: TextAlign.center,
                    style: AppType.body(size: 12, color: c.textFaint),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
