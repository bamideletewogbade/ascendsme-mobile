import 'app_logger.dart';
import 'supabase_service.dart';

/// Payroll Service — handles payroll runs, history, and finance integration.
/// Shared with web: `payroll_runs` table.
class PayrollService {
  /// Fetch all payroll runs for a business.
  static Future<List<Map<String, dynamic>>> fetchPayrollRuns({
    required String businessId,
    int? year,
  }) async {
    log.debug('PayrollService.fetchPayrollRuns — bizId=$businessId year=$year');
    final sw = Stopwatch()..start();
    
    final baseQuery = SupabaseService.client
        .from('payroll_runs')
        .select('*')
        .eq('business_id', businessId);

    final query = year != null
        ? baseQuery.gte('pay_period_month', '$year-01').lte('pay_period_month', '$year-12')
        : baseQuery;

    final rows = await query.order('pay_period_month', ascending: false);
    log.info('PayrollService.fetchPayrollRuns — ${rows.length} runs (${sw.elapsedMilliseconds}ms)');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Calculate expected payroll from current active staff salaries.
  static Future<Map<String, dynamic>> calculateCurrentPayroll(String businessId) async {
    final sw = Stopwatch()..start();
    final rows = await SupabaseService.client
        .from('staff_members')
        .select('id, staff_name, role, salary_monthly_ghs')
        .eq('business_id', businessId)
        .eq('is_active', true);
    
    final staff = List<Map<String, dynamic>>.from(rows as List);
    final payments = staff.where((s) => (s['salary_monthly_ghs'] as num? ?? 0) > 0).map((s) => {
      'staff_id': s['id'],
      'staff_name': s['staff_name'],
      'role': s['role'],
      'amount_ghs': (s['salary_monthly_ghs'] as num).toDouble(),
    }).toList();

    final total = payments.fold<double>(0, (sum, p) => sum + (p['amount_ghs'] as double));
    
    log.info('PayrollService.calculateCurrentPayroll — bizId=$businessId total=$total staff=${payments.length} (${sw.elapsedMilliseconds}ms)');
    return {
      'total_payroll_ghs': total,
      'staff_payments': payments,
    };
  }

  /// Create a new payroll run for the current month.
  static Future<Map<String, dynamic>> createPayrollRun({
    required String businessId,
    required String payPeriodMonth,
  }) async {
    log.info('PayrollService.createPayrollRun — month=$payPeriodMonth');
    
    final calc = await calculateCurrentPayroll(businessId);
    final total = calc['total_payroll_ghs'] as double;
    final payments = calc['staff_payments'] as List;

    if (payments.isEmpty) {
      throw Exception('No active staff with salaries found');
    }

    // Parse the month to get period start/end dates
    final parts = payPeriodMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final periodStart = DateTime(year, month, 1);
    final periodEnd = DateTime(year, month + 1, 0);

    final row = await SupabaseService.client
        .from('payroll_runs')
        .insert({
          'business_id': businessId,
          'pay_period_month': payPeriodMonth,
          'pay_period_start': periodStart.toIso8601String().split('T')[0],
          'pay_period_end': periodEnd.toIso8601String().split('T')[0],
          'total_payroll_ghs': total,
          'staff_count': payments.length,
          'staff_payments': payments,
          'status': 'pending',
        })
        .select()
        .single();
        
    return Map<String, dynamic>.from(row);
  }

  /// Ensure a payroll run exists for the current month.
  /// If it doesn't, create it. If it does, return it.
  static Future<Map<String, dynamic>> ensurePayrollRunForCurrentMonth(String businessId) async {
    final now = DateTime.now();
    final payPeriodMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    log.info('PayrollService.ensurePayrollRunForCurrentMonth — month=$payPeriodMonth');

    // 1. Check for existing
    final existing = await SupabaseService.client
        .from('payroll_runs')
        .select('*')
        .eq('business_id', businessId)
        .eq('pay_period_month', payPeriodMonth)
        .maybeSingle();
    
    if (existing != null) {
      log.info('PayrollService.ensurePayrollRunForCurrentMonth — run already exists');
      return Map<String, dynamic>.from(existing);
    }

    // 2. Create new
    return createPayrollRun(businessId: businessId, payPeriodMonth: payPeriodMonth);
  }

  /// Process a payroll run: log it as an expense and update status.
  static Future<void> processPayrollToFinance({
    required String businessId,
    required String payrollRunId,
    required String paymentSource,
  }) async {
    log.info('PayrollService.processPayrollToFinance — id=$payrollRunId source=$paymentSource');
    
    // 1. Fetch the run
    final run = await SupabaseService.client
        .from('payroll_runs')
        .select('*')
        .eq('id', payrollRunId)
        .single();
    
    if (run['status'] == 'logged_to_finance') {
      throw Exception('Payroll already logged to finance');
    }

    // 2. Log expense
    final monthParts = (run['pay_period_month'] as String).split('-');
    final monthName = _kFullMonthNames[int.parse(monthParts[1]) - 1];
    final description = '$monthName ${monthParts[0]} Payroll — ${run['staff_count']} staff';

    final expense = await SupabaseService.createExpense(
      businessId: businessId,
      amount: run['total_payroll_ghs'] as num,
      date: DateTime.parse(run['pay_period_end'] as String),
      description: description,
      category: 'Wages',
      paymentSource: paymentSource,
    );

    // 3. Update run status
    await SupabaseService.client
        .from('payroll_runs')
        .update({
          'status': 'logged_to_finance',
          'expense_id': expense['id'],
          'payment_source': paymentSource,
          'processed_at': DateTime.now().toUtc().toIso8601String(),
          'logged_to_finance_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', payrollRunId);
        
    log.info('PayrollService.processPayrollToFinance — success');
  }
}

const _kFullMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
];
