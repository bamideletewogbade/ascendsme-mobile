import 'models.dart';

/// Generate recommendations from the user's real business state. Replaces the
/// old hardcoded `kRecommendations` list which referenced fake numbers
/// ("GHS 18,420 in revenue") and showed the same content to every user.
///
/// Each recommendation has an action `id` that AppShell._handleAction routes
/// to the right destination. Ordered by priority (urgent → high → medium).
List<Recommendation> buildRecommendations({
  required Business business,
  required Financials financials,
  required List<Invoice> invoices,
}) {
  final recs = <Recommendation>[];

  // ── First-time actions for a brand-new user ────────────────────────────
  // Foundational record-keeping: send an invoice, log an expense. Without
  // these the cashflow tiles are empty and nothing else makes sense.
  if (invoices.isEmpty) {
    recs.add(const Recommendation(
      id: 'rec_first_invoice',
      priority: 'urgent',
      title: 'Send your first invoice',
      why:
          'Recording sales as you go gives you a clear picture of revenue — and starts the record that funding programs look at.',
      cta: 'New invoice',
      minutes: 2,
      impact: 'Start your records',
    ));
  }

  // ── Overdue follow-up — only if real overdue invoices exist ─────────────
  if (financials.outstandingOverdueCount > 0) {
    final n = financials.outstandingOverdueCount;
    recs.add(Recommendation(
      id: 'rec_followup_overdue',
      priority: 'urgent',
      title: 'Follow up on $n overdue ${n == 1 ? "invoice" : "invoices"}',
      why:
          "A polite WhatsApp reminder usually closes 60% of overdue invoices. Ascend can draft one for you.",
      cta: 'Draft reminder',
      minutes: 2,
      impact: 'GHS ${financials.outstanding}',
    ));
  }

  // ── Log expenses — needed for a margin view ─────────────────────────────
  if (financials.expensesThisMonth == 0) {
    recs.add(Recommendation(
      id: 'rec_first_expense',
      priority: 'high',
      title: financials.revenueThisMonth > 0
          ? "Log this month's expenses to see your margin"
          : 'Log your first expense',
      why:
          "Without expenses recorded, your P&L is incomplete — and you can't see whether your business is actually profitable.",
      cta: 'Log expense',
      minutes: 3,
      impact: 'Unlocks margin view',
    ));
  }

  // ── Complete business profile ───────────────────────────────────────────
  // industry and city default to '—' in Business.fromRow when missing.
  final missingIndustry = business.industry.trim() == '—' ||
      business.industry.trim().isEmpty;
  final missingCity =
      business.city.trim() == '—' || business.city.trim().isEmpty;
  if (missingIndustry || missingCity) {
    recs.add(const Recommendation(
      id: 'rec_profile',
      priority: 'high',
      title: 'Complete your business profile',
      why:
          "Adding your industry and location helps Ascend tailor your recommendations and prepares you for funding applications later.",
      cta: 'Edit profile',
      minutes: 3,
      impact: 'Better insights',
    ));
  }

  // ── Verification — only suggested once they have some data ──────────────
  if (!business.verified && invoices.isNotEmpty) {
    recs.add(const Recommendation(
      id: 'rec_verify',
      priority: 'medium',
      title: 'Start your verification checklist',
      why:
          'Verified businesses can prepare bank-ready records that grants and lenders look for. No application required yet — just keep your records ready.',
      cta: 'Open Verify',
      minutes: 5,
      impact: 'Funding readiness',
    ));
  }

  // ── Expiring proformas — proactively surface before they go stale ──────
  final now = DateTime.now();
  final expiringSoon = invoices
      .where((i) =>
          i.isProforma &&
          i.validUntil != null &&
          i.validUntil!.isAfter(now) &&
          i.validUntil!.difference(now).inDays <= 7)
      .toList();
  if (expiringSoon.length >= 2) {
    final total = expiringSoon.fold<num>(0, (s, i) => s + i.amount);
    recs.add(Recommendation(
      id: 'rec_convert_expiring',
      priority: 'urgent',
      title:
          '${expiringSoon.length} proformas expiring soon — worth ${formatGHS(total)}',
      why:
          'Converting these expiring proformas to invoices now can recover revenue that might otherwise be lost. Follow up with customers before the deadline.',
      cta: 'Convert expiring',
      minutes: 3,
      impact: formatGHS(total),
    ));
  } else if (expiringSoon.length == 1) {
    final q = expiringSoon.first;
    recs.add(Recommendation(
      id: 'rec_convert_expiring',
      priority: 'urgent',
      title:
          'Proforma for ${q.customer} (${formatGHS(q.amount)}) expires ${q.validUntil!.difference(now).inDays} day${q.validUntil!.difference(now).inDays == 1 ? '' : 's'}',
      why:
          'This proforma will expire soon. Following up now could turn it into paid work before the deadline passes.',
      cta: 'Follow up',
      minutes: 2,
      impact: formatGHS(q.amount),
    ));
  }

  // ── Everything's covered ───────────────────────────────────────────────
  // Better than showing nothing, which can read as "empty / broken."
  if (recs.isEmpty) {
    recs.add(const Recommendation(
      id: 'rec_all_clear',
      priority: 'medium',
      title: 'Your records are up to date',
      why:
          'Keep logging sales and expenses — consistent records are the foundation of funding readiness.',
      cta: 'Open Finance',
      minutes: 0,
      impact: 'Keep going',
    ));
  }

  // Priority sort
  const priorityOrder = {'urgent': 0, 'high': 1, 'medium': 2, 'low': 3};
  recs.sort((a, b) =>
      (priorityOrder[a.priority] ?? 99)
          .compareTo(priorityOrder[b.priority] ?? 99));

  return recs;
}
