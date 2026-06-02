/// Cash Flow Forecast Service
///
/// Calculates a 30-day cash flow projection:
///   CF₃₀ = C_now + (AR_due + S_predicted) - (AP_due + I_restock + OpEx_fixed)
///
/// Simplified for mobile: uses invoices, expenses, and receipts data via
/// SupabaseService. No inventory demand prediction in v1.

import 'app_logger.dart';
import 'supabase_service.dart';

class CashFlowForecastData {
  final double currentCash;
  final double accountsReceivableDue;
  final double predictedSales;
  final double pipelineValue;
  final double plannedRestockCost;
  final double fixedOperatingCosts;
  final double projectedCash30Days;
  final double safetyLine;
  final double liquidityGap;
  final bool isAtRisk;
  final List<DailyForecastPoint> dailyForecast;
  final List<OverdueInvoice> overdueInvoices;
  final List<UpcomingExpense> upcomingExpenses;
  final double overallConfidence;
  final String dataQuality;

  const CashFlowForecastData({
    required this.currentCash,
    required this.accountsReceivableDue,
    required this.predictedSales,
    required this.pipelineValue,
    required this.plannedRestockCost,
    required this.fixedOperatingCosts,
    required this.projectedCash30Days,
    required this.safetyLine,
    required this.liquidityGap,
    required this.isAtRisk,
    this.dailyForecast = const [],
    this.overdueInvoices = const [],
    this.upcomingExpenses = const [],
    this.overallConfidence = 0,
    this.dataQuality = 'low',
  });

  static const empty = CashFlowForecastData(
    currentCash: 0,
    accountsReceivableDue: 0,
    predictedSales: 0,
    pipelineValue: 0,
    plannedRestockCost: 0,
    fixedOperatingCosts: 0,
    projectedCash30Days: 0,
    safetyLine: 0,
    liquidityGap: 0,
    isAtRisk: false,
  );
}

class DailyForecastPoint {
  final String date;
  final double projected;
  final double withPipeline;
  final double safetyLine;

  const DailyForecastPoint({
    required this.date,
    required this.projected,
    required this.withPipeline,
    required this.safetyLine,
  });
}

class OverdueInvoice {
  final String id;
  final String invoiceNumber;
  final String clientName;
  final double amount;
  final int daysPastDue;

  const OverdueInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.clientName,
    required this.amount,
    required this.daysPastDue,
  });
}

class UpcomingExpense {
  final String category;
  final double amount;
  final bool isRecurring;

  const UpcomingExpense({
    required this.category,
    required this.amount,
    this.isRecurring = false,
  });
}

class ForecastRecommendation {
  final String type;
  final String title;
  final String description;
  final String actionLabel;
  final double impact;
  final String urgency;

  const ForecastRecommendation({
    required this.type,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.impact,
    required this.urgency,
  });
}

class CashFlowService {
  /// Calculate a 30-day cash flow forecast for the business.
  static Future<CashFlowForecastData> calculateForecast({
    required String businessId,
  }) async {
    log.info('CashFlowService.calculateForecast — bizId=$businessId');
    final sw = Stopwatch()..start();

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thirtyDays = DateTime(now.year, now.month, now.day + 30);
      final thirtyDaysAgo = DateTime(now.year, now.month, now.day - 30);

      // 1. Current Cash — from receipts (money received) minus expenses logged
      final recentReceipts = await SupabaseService.sumReceipts(
        businessId: businessId,
        start: DateTime(2000),
        end: thirtyDays,
      );
      final recentExpenses = await SupabaseService.sumExpenses(
        businessId: businessId,
        start: DateTime(2000),
        end: thirtyDays,
      );
      final currentCash = recentReceipts - recentExpenses;

      // 2. Accounts Receivable — pending invoices due within 30 days
      final openInvoices = await SupabaseService.fetchOpenInvoices(businessId: businessId);
      double accountsReceivableDue = 0;
      final overdueInvoices = <OverdueInvoice>[];
      for (final inv in openInvoices) {
        final amount = (inv['total_amount'] as num?)?.toDouble() ?? 0;
        final status = (inv['status'] as String?)?.toLowerCase() ?? '';
        final dueRaw = inv['due_date'] as String?;

        if (status == 'pending' || status == 'overdue') {
          final due = dueRaw != null ? DateTime.tryParse(dueRaw) : null;
          if (due != null && !due.isAfter(thirtyDays)) {
            accountsReceivableDue += amount;
          }
          if (due != null && due.isBefore(today)) {
            overdueInvoices.add(OverdueInvoice(
              id: inv['id'] as String? ?? '',
              invoiceNumber: inv['invoice_number'] as String? ?? '',
              clientName: inv['client_name'] as String? ?? 'Customer',
              amount: amount,
              daysPastDue: today.difference(due).inDays,
            ));
          }
        }

        // Pipeline: proforma quotes
        if (status == 'proforma') {
          // Pipeline is tracked separately
        }
      }

      // 3. Fixed Operating Costs — average monthly expenses from last 30 days
      final expenses = await SupabaseService.fetchExpenses(businessId: businessId);
      final expenseByCategory = <String, double>{};
      for (final exp in expenses) {
        final cat = (exp['mapped_category'] as String?) ?? 'other';
        final amt = (exp['amount_ghs'] as num?)?.toDouble() ?? 0;
        expenseByCategory[cat] = (expenseByCategory[cat] ?? 0) + amt;
      }
      final fixedOperatingCosts = expenseByCategory.values.fold(0.0, (a, b) => a + b);
      final upcomingExpenses = expenseByCategory.entries
          .map((e) => UpcomingExpense(
                category: e.key,
                amount: e.value,
                isRecurring: ['labor', 'opex_rent', 'opex_utilities'].contains(e.key),
              ))
          .toList();

      // 4. Calculate projection
      const predictedSales = 0.0; // Not implemented in mobile v1
      const plannedRestockCost = 0.0;
      const accountsPayableDue = 0.0;
      const pipelineValue = 0.0;

      final projectedInflows = accountsReceivableDue + predictedSales;
      final projectedOutflows = accountsPayableDue + plannedRestockCost + fixedOperatingCosts;
      final projectedCash30Days = currentCash + projectedInflows - projectedOutflows;
      final safetyLine = fixedOperatingCosts * 1.2;
      final liquidityGap = projectedCash30Days - safetyLine;
      final isAtRisk = liquidityGap < 0;

      // 5. Daily forecast
      final dailyForecast = <DailyForecastPoint>[];
      double runningBalance = currentCash;
      final dailyInflow = projectedInflows / 30;
      final dailyOutflow = projectedOutflows / 30;
      for (int i = 0; i <= 30; i++) {
        final d = DateTime(now.year, now.month, now.day + i);
        if (i > 0) runningBalance += dailyInflow - dailyOutflow;
        dailyForecast.add(DailyForecastPoint(
          date: '${d.month}/${d.day}',
          projected: runningBalance,
          withPipeline: runningBalance,
          safetyLine: safetyLine,
        ));
      }

      // 6. Confidence
      final dataPoints = [
        recentReceipts > 0,
        fixedOperatingCosts > 0,
        openInvoices.isNotEmpty,
      ].where((b) => b).length;
      final dataQuality = dataPoints >= 3 ? 'high' : dataPoints >= 2 ? 'medium' : 'low';
      final overallConfidence = dataPoints / 3;

      log.info('CashFlowService.calculateForecast — projected=$projectedCash30Days atRisk=$isAtRisk quality=$dataQuality (${sw.elapsedMilliseconds}ms)');

      return CashFlowForecastData(
        currentCash: currentCash,
        accountsReceivableDue: accountsReceivableDue,
        predictedSales: predictedSales,
        pipelineValue: pipelineValue,
        plannedRestockCost: plannedRestockCost,
        fixedOperatingCosts: fixedOperatingCosts,
        projectedCash30Days: projectedCash30Days,
        safetyLine: safetyLine,
        liquidityGap: liquidityGap,
        isAtRisk: isAtRisk,
        dailyForecast: dailyForecast,
        overdueInvoices: overdueInvoices,
        upcomingExpenses: upcomingExpenses,
        overallConfidence: overallConfidence,
        dataQuality: dataQuality,
      );
    } catch (e, st) {
      log.error('CashFlowService.calculateForecast failed', error: e, stackTrace: st);
      return CashFlowForecastData.empty;
    }
  }

  /// Generate actionable recommendations from a forecast.
  static List<ForecastRecommendation> generateRecommendations(
      CashFlowForecastData forecast) {
    final recs = <ForecastRecommendation>[];

    if (forecast.overdueInvoices.isNotEmpty) {
      final total = forecast.overdueInvoices.fold(0.0, (s, i) => s + i.amount);
      recs.add(ForecastRecommendation(
        type: 'collection',
        title: 'Follow Up on Overdue Invoices',
        description:
            '${forecast.overdueInvoices.length} overdue invoice${forecast.overdueInvoices.length > 1 ? 's' : ''} — collect GHS ${total.round()} to improve your position.',
        actionLabel: 'View Invoices',
        impact: total,
        urgency: forecast.isAtRisk ? 'critical' : 'high',
      ));
    }

    if (forecast.isAtRisk) {
      recs.add(ForecastRecommendation(
        type: 'expense',
        title: 'Liquidity Risk Detected',
        description:
            'Projected cash (GHS ${forecast.projectedCash30Days.round()}) falls below your operating minimum (GHS ${forecast.safetyLine.round()}).',
        actionLabel: 'Review Cash Flow',
        impact: forecast.liquidityGap.abs(),
        urgency: 'critical',
      ));
    }

    if (!forecast.isAtRisk && forecast.projectedCash30Days > forecast.safetyLine * 2) {
      recs.add(ForecastRecommendation(
        type: 'growth',
        title: 'Strong Cash Position',
        description:
            'Your forecast shows healthy cash reserves. Consider reinvesting in inventory or exploring growth opportunities.',
        actionLabel: 'Explore Options',
        impact: forecast.projectedCash30Days - forecast.safetyLine,
        urgency: 'low',
      ));
    }

    return recs;
  }
}
