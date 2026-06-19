import 'app_logger.dart';
import 'supabase_service.dart';

/// Project Management Service — handles project milestones and tasks.
/// Shared with web: `project_milestones` and `project_tasks` tables.
class ProjectService {
  /// Fetch all milestones (projects) for a business.
  static Future<List<Map<String, dynamic>>> fetchMilestones({
    required String businessId,
  }) async {
    log.debug('ProjectService.fetchMilestones — bizId=$businessId');
    final sw = Stopwatch()..start();
    
    final rows = await SupabaseService.client
        .from('project_milestones')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', ascending: false);
        
    log.info('ProjectService.fetchMilestones — ${rows.length} projects (${sw.elapsedMilliseconds}ms)');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Fetch all tasks for a specific milestone.
  static Future<List<Map<String, dynamic>>> fetchTasks({
    required String milestoneId,
  }) async {
    log.debug('ProjectService.fetchTasks — milestoneId=$milestoneId');
    final sw = Stopwatch()..start();
    
    final rows = await SupabaseService.client
        .from('project_tasks')
        .select('*')
        .eq('milestone_id', milestoneId)
        .order('created_at', ascending: true);
        
    log.info('ProjectService.fetchTasks — ${rows.length} tasks (${sw.elapsedMilliseconds}ms)');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Create a new project milestone.
  static Future<Map<String, dynamic>> createMilestone({
    required String businessId,
    required String projectName,
    String projectType = 'custom',
    int totalMilestones = 1,
  }) async {
    log.info('ProjectService.createMilestone — name="$projectName"');
    
    final row = await SupabaseService.client
        .from('project_milestones')
        .insert({
          'business_id': businessId,
          'project_name': projectName,
          'project_type': projectType,
          'status': 'not_started',
          'current_milestone_index': 0,
          'total_milestones': totalMilestones,
          'milestone_data': [{'name': 'Initiation', 'status': 'pending'}],
        })
        .select()
        .single();
        
    return Map<String, dynamic>.from(row);
  }

  /// Create a new task within a milestone.
  static Future<Map<String, dynamic>> createTask({
    required String milestoneId,
    required String taskName,
    String taskType = 'custom',
    String? assignedToUserId,
  }) async {
    log.info('ProjectService.createTask — name="$taskName"');
    
    final row = await SupabaseService.client
        .from('project_tasks')
        .insert({
          'milestone_id': milestoneId,
          'task_name': taskName,
          'task_type': taskType,
          'status': 'pending',
          if (assignedToUserId != null) 'assigned_to_user_id': assignedToUserId,
        })
        .select()
        .single();
        
    return Map<String, dynamic>.from(row);
  }

  /// Update task status.
  static Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    log.info('ProjectService.updateTaskStatus — id=$taskId status=$status');
    
    final updates = {
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (status == 'in_progress') 'started_at': DateTime.now().toUtc().toIso8601String(),
      if (status == 'completed') 'completed_at': DateTime.now().toUtc().toIso8601String(),
    };
    
    await SupabaseService.client
        .from('project_tasks')
        .update(updates)
        .eq('id', taskId);
  }

  /// Delete a task.
  static Future<void> deleteTask(String taskId) async {
    await SupabaseService.client
        .from('project_tasks')
        .delete()
        .eq('id', taskId);
  }

  /// Advance a milestone to the next stage.
  /// If `currentIndex >= totalMilestones - 1`, marks the project as completed.
  static Future<void> advanceMilestone(String milestoneId) async {
    log.info('ProjectService.advanceMilestone — id=$milestoneId');

    // Fetch the current milestone first to get its state
    final row = await SupabaseService.client
        .from('project_milestones')
        .select('current_milestone_index, total_milestones, status, milestone_data')
        .eq('id', milestoneId)
        .single();

    final currentIdx = (row['current_milestone_index'] as num?)?.toInt() ?? 0;
    final total = (row['total_milestones'] as num?)?.toInt() ?? 1;
    final rawData = row['milestone_data'] as List<dynamic>? ?? [];

    if (currentIdx >= total - 1) {
      // All milestones done — mark as completed
      await SupabaseService.client
          .from('project_milestones')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', milestoneId);
      return;
    }

    // Advance to next milestone
    final newIdx = currentIdx + 1;
    final milestoneLabel = newIdx < rawData.length
        ? (rawData[newIdx] as Map<String, dynamic>)['name'] as String?
        : null;

    await SupabaseService.client
        .from('project_milestones')
        .update({
          'current_milestone_index': newIdx,
          'status': 'in_progress',
          'started_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', milestoneId);

    log.info('ProjectService.advanceMilestone — advanced to milestone $newIdx ($milestoneLabel)');
  }

  /// Assign a task to a staff member and set status to in_progress.
  static Future<void> assignTask({
    required String taskId,
    required String staffUserId,
  }) async {
    log.info('ProjectService.assignTask — taskId=$taskId staffUserId=$staffUserId');
    await SupabaseService.client
        .from('project_tasks')
        .update({
          'assigned_to_user_id': staffUserId,
          'status': 'in_progress',
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', taskId);
  }

  /// Update arbitrary task fields (name, status, type, etc.).
  static Future<void> updateTask({
    required String taskId,
    String? taskName,
    String? status,
    String? taskType,
    String? assignedToUserId,
    int? timeSpentMinutes,
  }) async {
    log.info('ProjectService.updateTask — id=$taskId');
    final updates = <String, dynamic>{
      if (taskName != null) 'task_name': taskName,
      if (status != null) 'status': status,
      if (taskType != null) 'task_type': taskType,
      if (assignedToUserId != null) 'assigned_to_user_id': assignedToUserId,
      if (timeSpentMinutes != null) 'time_spent_minutes': timeSpentMinutes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (status == 'in_progress') 'started_at': DateTime.now().toUtc().toIso8601String(),
      if (status == 'completed') 'completed_at': DateTime.now().toUtc().toIso8601String(),
    };
    await SupabaseService.client
        .from('project_tasks')
        .update(updates)
        .eq('id', taskId);
  }
}
