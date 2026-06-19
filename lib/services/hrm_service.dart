// HRM Service — wraps the `staff_members` table (shared with web).
// Now includes delegation metrics and ROI tracking.

import 'app_logger.dart';
import 'supabase_service.dart';

class HrmService {
  /// Fetch all staff members for this business. Optionally filter to active only.
  static Future<List<Map<String, dynamic>>> fetchStaff({
    required String businessId,
    bool activeOnly = true,
  }) async {
    log.debug('HrmService.fetchStaff — bizId=$businessId activeOnly=$activeOnly');
    final sw = Stopwatch()..start();
    var filterQuery = SupabaseService.client
        .from('staff_members')
        .select('*')
        .eq('business_id', businessId);

    if (activeOnly) {
      filterQuery = filterQuery.eq('is_active', true);
    }

    final rows = await filterQuery.order('staff_name', ascending: true);
    log.info('HrmService.fetchStaff — ${rows.length} staff (${sw.elapsedMilliseconds}ms)');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Create a new staff member.
  static Future<Map<String, dynamic>> createStaff({
    required String businessId,
    required String staffName,
    String? staffEmail,
    String? staffPhone,
    required String role,
    double? salaryMonthly,
    String? hireDate,
  }) async {
    log.info('HrmService.createStaff — bizId=$businessId name="$staffName" role="$role"');
    final sw = Stopwatch()..start();
    final row = await SupabaseService.client
        .from('staff_members')
        .insert({
          'business_id': businessId,
          'staff_name': staffName.trim(),
          if (staffEmail != null && staffEmail.trim().isNotEmpty)
            'staff_email': staffEmail.trim(),
          if (staffPhone != null && staffPhone.trim().isNotEmpty)
            'staff_phone': staffPhone.trim(),
          'role': role.trim(),
          if (salaryMonthly != null) 'salary_monthly_ghs': salaryMonthly,
          'hire_date': hireDate ?? DateTime.now().toIso8601String().substring(0, 10),
          'is_active': true,
        })
        .select()
        .single();
    log.info('HrmService.createStaff — done id=${row['id']} (${sw.elapsedMilliseconds}ms)');
    return Map<String, dynamic>.from(row);
  }

  /// Update a staff member's details.
  static Future<void> updateStaff({
    required String staffId,
    required String businessId,
    String? staffName,
    String? staffEmail,
    String? staffPhone,
    String? role,
    double? salaryMonthly,
  }) async {
    log.info('HrmService.updateStaff — id=$staffId');
    final updates = <String, dynamic>{
      if (staffName != null) 'staff_name': staffName.trim(),
      if (staffEmail != null) 'staff_email': staffEmail.trim().isNotEmpty ? staffEmail.trim() : null,
      if (staffPhone != null) 'staff_phone': staffPhone.trim().isNotEmpty ? staffPhone.trim() : null,
      if (role != null) 'role': role.trim(),
      if (salaryMonthly != null) 'salary_monthly_ghs': salaryMonthly,
    };
    await SupabaseService.client
        .from('staff_members')
        .update(updates)
        .eq('id', staffId)
        .eq('business_id', businessId);
    log.info('HrmService.updateStaff — done');
  }

  /// Deactivate a staff member (soft-delete via is_active = false).
  static Future<void> deactivateStaff({
    required String staffId,
    required String businessId,
  }) async {
    log.info('HrmService.deactivateStaff — id=$staffId');
    await SupabaseService.client
        .from('staff_members')
        .update({'is_active': false, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', staffId)
        .eq('business_id', businessId);
    log.info('HrmService.deactivateStaff — done');
  }

  /// Calculate Delegation Index.
  /// Measures how many tasks are assigned to staff vs the owner.
  static Future<Map<String, dynamic>> calculateDelegationIndex(String businessId) async {
    final sw = Stopwatch()..start();
    
    // 1. Get all projects/milestones for this business
    final projects = await SupabaseService.client
        .from('project_milestones')
        .select('id')
        .eq('business_id', businessId);
    
    final projectIds = (projects as List).map((p) => p['id']).toList();
    if (projectIds.isEmpty) return {'percentage': 0.0, 'index': 0.0};

    // 2. Get all tasks for these projects
    final tasks = await SupabaseService.client
        .from('project_tasks')
        .select('assigned_to_user_id')
        .inFilter('milestone_id', projectIds);
    
    final taskList = List<Map<String, dynamic>>.from(tasks as List);
    if (taskList.isEmpty) return {'percentage': 0.0, 'index': 0.0};

    // 3. Get active staff
    final staffRows = await SupabaseService.client
        .from('staff_members')
        .select('id, user_id')
        .eq('business_id', businessId)
        .eq('is_active', true);
    
    final activeStaff = List<Map<String, dynamic>>.from(staffRows as List);
    final staffIds = activeStaff.map((s) => s['id']).toSet();
    final staffUserIds = activeStaff.map((s) => s['user_id']).whereType<String>().toSet();

    var delegatedCount = 0;
    for (final task in taskList) {
      final assignee = task['assigned_to_user_id'];
      if (assignee != null && (staffIds.contains(assignee) || staffUserIds.contains(assignee))) {
        delegatedCount++;
      }
    }

    final percentage = (delegatedCount / taskList.length) * 100;
    final staffMultiplier = (activeStaff.length / 5.0).clamp(0.0, 1.0);
    final index = (percentage / 100.0) * staffMultiplier;

    log.info('HrmService.calculateDelegationIndex — index=${index.toStringAsFixed(2)} (${sw.elapsedMilliseconds}ms)');
    return {
      'percentage': percentage,
      'index': index,
      'total_tasks': taskList.length,
      'delegated_tasks': delegatedCount,
    };
  }
}
