import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../../services/project_service.dart';

// ── Screen ───────────────────────────────────────────────────────────────────

/// Project Management screen — task board with status columns, milestone
/// tracking, staff assignment, and bottleneck detection.
///
/// Mirrors web's ProjectManagementModule.tsx: kanban-style task view,
/// milestone progression, resource allocation (staff workload).
class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  ProjectMilestone? _selectedProject;
  List<ProjectTask> _tasks = [];
  bool _loadingTasks = false;
  String _statusFilter = 'all';
  bool _showCompleted = true;
  bool _advancingMilestone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLoad();
    });
  }

  Future<void> _initLoad() async {
    final state = context.read<AppState>();
    await state.loadMilestones();
    if (!mounted) return;
    if (state.milestones.isNotEmpty) {
      setState(() => _selectedProject = state.milestones.first);
      _loadTasks();
    }
  }

  Future<void> _loadTasks() async {
    if (_selectedProject == null) return;
    if (mounted) setState(() => _loadingTasks = true);
    try {
      final rows = await ProjectService.fetchTasks(milestoneId: _selectedProject!.id);
      if (mounted) {
        setState(() {
          _tasks = rows.map(ProjectTask.fromRow).toList();
          _loadingTasks = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  List<ProjectTask> get _filteredTasks {
    var result = _tasks;
    if (_statusFilter != 'all') {
      result = result.where((t) => t.status == _statusFilter).toList();
    }
    if (!_showCompleted) {
      result = result.where((t) => t.status != 'completed').toList();
    }
    return result;
  }

  int get _todoCount => _tasks.where((t) => t.status == 'pending').length;
  int get _inProgressCount => _tasks.where((t) => t.status == 'in_progress').length;
  int get _blockedCount => _tasks.where((t) => t.status == 'blocked').length;
  int get _doneCount => _tasks.where((t) => t.status == 'completed').length;

  /// Cycle task status: pending → in_progress → blocked → completed → pending
  Future<void> _cycleStatus(ProjectTask task) async {
    final newStatus = switch (task.status) {
      'pending' => 'in_progress',
      'in_progress' => 'blocked',
      'blocked' => 'completed',
      'completed' => 'pending',
      _ => 'pending',
    };

    // Optimistic update
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) {
        _tasks[idx] = ProjectTask(
          id: task.id,
          milestoneId: task.milestoneId,
          taskName: task.taskName,
          taskType: task.taskType,
          status: newStatus,
          assignedToUserId: task.assignedToUserId,
          timeSpentMinutes: task.timeSpentMinutes,
          createdAt: task.createdAt,
        );
      }
    });

    try {
      await ProjectService.updateTaskStatus(taskId: task.id, status: newStatus);
    } catch (e) {
      _loadTasks();
    }
  }

  Future<void> _advanceMilestone() async {
    if (_selectedProject == null) return;
    if (_advancingMilestone) return;

    // Confirm with user
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Advance milestone?'),
        content: Text(
          'Move "${_selectedProject!.projectName}" to the next milestone? '
          'All existing tasks will remain.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Advance')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _advancingMilestone = true);
    try {
      await ProjectService.advanceMilestone(_selectedProject!.id);
      if (!mounted) return;
      final state = context.read<AppState>();
      await state.loadMilestones();
      if (mounted) {
        // Refresh selected project from state
        final updated = state.milestones.where((m) => m.id == _selectedProject!.id).firstOrNull;
        setState(() {
          _selectedProject = updated ?? _selectedProject;
          _advancingMilestone = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedProject?.status == 'completed'
                  ? 'Project completed! 🎉'
                  : 'Advanced to next milestone',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _advancingMilestone = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to advance milestone')),
        );
      }
    }
  }

  Future<void> _openTaskDetail(ProjectTask task) async {
    final state = context.read<AppState>();
    await state.loadStaff();

    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailSheet(
        task: task,
        staff: state.staff,
        onAssign: (staffMember) async {
          await ProjectService.assignTask(
            taskId: task.id,
            staffUserId: staffMember.id,
          );
          _loadTasks();
        },
        onStatusChange: (newStatus) async {
          await ProjectService.updateTaskStatus(taskId: task.id, status: newStatus);
          _loadTasks();
        },
        onDelete: () async {
          await ProjectService.deleteTask(task.id);
          _loadTasks();
        },
      ),
    );

    if (result != null) {
      _loadTasks();
    }
  }

  Future<void> _openNewProjectSheet() async {
    final state = context.read<AppState>();
    final bizId = state.business.id;
    if (bizId == null) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewProjectSheet(),
    );

    if (result != null && result['name'] != null && (result['name'] as String).isNotEmpty) {
      try {
        final row = await ProjectService.createMilestone(
          businessId: bizId,
          projectName: result['name'] as String,
          projectType: (result['type'] as String?) ?? 'custom',
          totalMilestones: (result['milestones'] as int?) ?? 1,
        );
        await state.loadMilestones();
        if (mounted) {
          setState(() => _selectedProject = ProjectMilestone.fromRow(row));
          _loadTasks();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create project')),
          );
        }
      }
    }
  }

  Future<void> _openNewTaskSheet() async {
    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a project first')),
      );
      return;
    }

    final state = context.read<AppState>();
    await state.loadStaff();
    if (!mounted) return;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewTaskSheet(staff: state.staff),
    );

    if (result == null) return;
    final taskName = result['name'] as String?;
    if (taskName == null || taskName.isEmpty) return;

    try {
      final assignedTo = result['assignedTo'] as String?;
      await ProjectService.createTask(
        milestoneId: _selectedProject!.id,
        taskName: taskName,
        assignedToUserId: assignedTo,
      );
      _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create task')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final milestones = state.milestones;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Project Management',
              onBack: () => Navigator.pop(context),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // New project button
                  GestureDetector(
                    onTap: _openNewProjectSheet,
                    child: Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: c.bgElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(Icons.create_new_folder_outlined, size: 18, color: c.text),
                    ),
                  ),
                  GestureDetector(
                    onTap: _openNewTaskSheet,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.teal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // ── Project Selector ──
            if (milestones.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _ProjectPickerSheet(
                        projects: milestones,
                        selectedId: _selectedProject?.id,
                        onSelect: (p) {
                          setState(() => _selectedProject = p);
                          _loadTasks();
                          Navigator.pop(context);
                        },
                        onNew: () {
                          Navigator.pop(context);
                          _openNewProjectSheet();
                        },
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: c.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.folder_open, size: 18, color: c.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedProject?.projectName ?? 'Select Project',
                            style: AppType.body(size: 14, weight: FontWeight.w600, color: c.text),
                          ),
                        ),
                        Icon(Icons.keyboard_arrow_down, size: 18, color: c.textFaint),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Milestone Progress Bar ──
            if (_selectedProject != null && _selectedProject!.totalMilestones > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 14, color: c.teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedProject!.status == 'completed'
                                  ? 'All milestones complete'
                                  : 'Milestone ${_selectedProject!.currentIndex + 1} of ${_selectedProject!.totalMilestones}',
                              style: AppType.body(size: 12, weight: FontWeight.w600, color: c.text),
                            ),
                          ),
                          if (_selectedProject!.status == 'completed')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: c.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text('Completed',
                                style: AppType.body(size: 9.5, weight: FontWeight.w700, color: c.green)),
                            ),
                          if (_selectedProject!.status != 'completed')
                            GestureDetector(
                              onTap: _advancingMilestone ? null : _advanceMilestone,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: c.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: _advancingMilestone
                                    ? SizedBox(
                                        width: 12, height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: c.teal),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Advance',
                                            style: AppType.body(size: 9.5, weight: FontWeight.w700, color: c.teal)),
                                          const SizedBox(width: 3),
                                          Icon(Icons.arrow_forward_ios, size: 8, color: c.teal),
                                        ],
                                      ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _selectedProject!.totalMilestones > 0
                              ? (_selectedProject!.currentIndex + 1) / _selectedProject!.totalMilestones
                              : 0,
                          backgroundColor: c.bgInset,
                          color: _selectedProject!.status == 'completed' ? c.green : c.teal,
                          minHeight: 6,
                        ),
                      ),
                      // Milestone dots
                      if (_selectedProject!.totalMilestones > 1) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: List.generate(_selectedProject!.totalMilestones, (i) {
                            final isPast = i <= _selectedProject!.currentIndex;
                            final isCurrent = i == _selectedProject!.currentIndex;
                            return Expanded(
                              child: Row(
                                children: [
                                  if (i > 0)
                                    Expanded(
                                      child: Container(
                                        height: 2,
                                        color: isPast ? c.teal : c.border,
                                      ),
                                    ),
                                  Container(
                                    width: isCurrent ? 10 : 6,
                                    height: isCurrent ? 10 : 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isPast ? c.teal : c.borderStrong,
                                      border: isCurrent ? Border.all(color: c.teal, width: 2) : null,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // ── Status filter chips + counts ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _CountBadge(label: 'To Do', count: _todoCount, color: c.textMuted),
                      const SizedBox(width: 8),
                      _CountBadge(label: 'In Progress', count: _inProgressCount, color: c.blue),
                      const SizedBox(width: 8),
                      _CountBadge(label: 'Blocked', count: _blockedCount, color: c.rose),
                      const SizedBox(width: 8),
                      _CountBadge(label: 'Done', count: _doneCount, color: c.green),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _showCompleted = !_showCompleted),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: c.bgElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.border),
                          ),
                          child: Icon(
                            _showCompleted ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 16,
                            color: c.textFaint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      separatorBuilder: (_, i) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final chips = [
                          ('all', 'All', c.teal),
                          ('pending', 'To Do', c.textMuted),
                          ('in_progress', 'In Progress', c.blue),
                          ('blocked', 'Blocked', c.rose),
                          ('completed', 'Done', c.green),
                        ];
                        final (key, label, color) = chips[i];
                        final active = _statusFilter == key;
                        return GestureDetector(
                          onTap: () => setState(() => _statusFilter = key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: active ? color.withValues(alpha: 0.12) : c.bgElevated,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: active ? color : c.borderStrong),
                            ),
                            child: Text(
                              label,
                              style: AppType.body(size: 12, weight: FontWeight.w600, color: active ? color : c.textMuted),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Task list ──
            Expanded(
              child: _loadingTasks
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedProject == null
                      ? _NoProjectState(onNew: _openNewProjectSheet)
                      : _filteredTasks.isEmpty
                          ? _EmptyState(onAdd: _openNewTaskSheet)
                          : RefreshIndicator(
                              onRefresh: _loadTasks,
                              color: c.teal,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                                itemCount: _filteredTasks.length,
                                itemBuilder: (context, i) {
                                  final task = _filteredTasks[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: FadeInSlide(
                                      index: i,
                                      child: _TaskCard(
                                        task: task,
                                        onTap: () => _openTaskDetail(task),
                                        onStatusCycle: () => _cycleStatus(task),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Project Picker ────────────────────────────────────────────────────────────

class _ProjectPickerSheet extends StatelessWidget {
  final List<ProjectMilestone> projects;
  final String? selectedId;
  final Function(ProjectMilestone) onSelect;
  final VoidCallback onNew;

  const _ProjectPickerSheet({
    required this.projects,
    this.selectedId,
    required this.onSelect,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 12),
          Text('Select Project', style: AppType.heading(size: 18, color: c.text)),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: projects.length,
              itemBuilder: (context, i) {
                final p = projects[i];
                final active = p.id == selectedId;
                return ListTile(
                  onTap: () => onSelect(p),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    p.status == 'completed' ? Icons.check_circle : Icons.folder,
                    color: active ? c.teal : c.textFaint,
                    size: 20,
                  ),
                  title: Text(p.projectName, style: AppType.body(size: 14, color: active ? c.teal : c.text)),
                  subtitle: p.totalMilestones > 1
                      ? Text('Milestone ${p.currentIndex + 1}/${p.totalMilestones}',
                          style: AppType.body(size: 11, color: c.textMuted))
                      : Text(switch (p.status) {
                          'in_progress' => 'In progress',
                          'completed' => 'Completed',
                          _ => 'Not started',
                        }, style: AppType.body(size: 11, color: c.textFaint)),
                  trailing: active ? Icon(Icons.check, size: 18, color: c.teal) : null,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          AppBtn('New Project', full: true, variant: BtnVariant.secondary, icon: 'add', onTap: onNew),
        ],
      ),
    );
  }
}

// ── Count badge ───────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count', style: AppType.body(size: 13, weight: FontWeight.w700, color: color)),
          const SizedBox(width: 4),
          Text(label, style: AppType.body(size: 11, color: c.textMuted)),
        ],
      ),
    );
  }
}

// ── Task card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final ProjectTask task;
  final VoidCallback onTap;
  final VoidCallback onStatusCycle;

  const _TaskCard({required this.task, required this.onTap, required this.onStatusCycle});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onStatusCycle,
            child: Icon(
              switch (task.status) {
                'in_progress' => Icons.adjust,
                'blocked' => Icons.block,
                'completed' => Icons.check_circle,
                _ => Icons.radio_button_unchecked,
              },
              size: 20,
              color: switch (task.status) {
                'in_progress' => c.blue,
                'blocked' => c.rose,
                'completed' => c.green,
                _ => c.textFaint,
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskName,
                  style: AppType.body(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: task.status == 'completed' ? c.textMuted : c.text,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      switch (task.status) {
                        'in_progress' => 'In Progress',
                        'blocked' => 'Blocked',
                        'completed' => 'Done',
                        _ => 'To Do',
                      },
                      style: AppType.body(
                        size: 10.5,
                        weight: FontWeight.w600,
                        color: switch (task.status) {
                          'in_progress' => c.blue,
                          'blocked' => c.rose,
                          'completed' => c.green,
                          _ => c.textFaint,
                        },
                      ),
                    ),
                    if (task.assignedToUserId != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.person_outline, size: 11, color: c.textFaint),
                    ],
                    if (task.timeSpentMinutes > 0) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.timer_outlined, size: 11, color: c.textFaint),
                      const SizedBox(width: 2),
                      Text(
                        '${task.timeSpentMinutes}m',
                        style: AppType.body(size: 10, color: c.textFaint),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 16, color: c.textFaint),
        ],
      ),
    );
  }
}

// ── Task Detail Sheet ─────────────────────────────────────────────────────────

class _TaskDetailSheet extends StatelessWidget {
  final ProjectTask task;
  final List<StaffMember> staff;
  final Function(StaffMember) onAssign;
  final Function(String) onStatusChange;
  final VoidCallback onDelete;

  const _TaskDetailSheet({
    required this.task,
    required this.staff,
    required this.onAssign,
    required this.onStatusChange,
    required this.onDelete,
  });

  StaffMember? get _assignedStaff => staff.where((s) => s.id == task.assignedToUserId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 16),

          // Task name + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(task.taskName,
                    style: AppType.heading(size: 18, color: c.text)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: switch (task.status) {
                    'in_progress' => c.blue.withValues(alpha: 0.12),
                    'blocked' => c.rose.withValues(alpha: 0.12),
                    'completed' => c.green.withValues(alpha: 0.12),
                    _ => c.bgInset,
                  },
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  switch (task.status) {
                    'in_progress' => 'In Progress',
                    'blocked' => 'Blocked',
                    'completed' => 'Done',
                    _ => 'To Do',
                  },
                  style: AppType.body(
                    size: 11,
                    weight: FontWeight.w700,
                    color: switch (task.status) {
                      'in_progress' => c.blue,
                      'blocked' => c.rose,
                      'completed' => c.green,
                      _ => c.textMuted,
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Type badge
          if (task.taskType != 'custom')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.tealSurface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task.taskType[0].toUpperCase() + task.taskType.substring(1),
                  style: AppType.body(size: 10, weight: FontWeight.w600, color: c.tealDeep),
                ),
              ),
            ),

          // Assigned staff
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.bgInset,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: c.textFaint),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _assignedStaff != null
                        ? 'Assigned to ${_assignedStaff!.staffName}'
                        : 'Unassigned',
                    style: AppType.body(size: 13, color: _assignedStaff != null ? c.text : c.textMuted),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showStaffPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      _assignedStaff != null ? 'Reassign' : 'Assign',
                      style: AppType.body(size: 11, weight: FontWeight.w600, color: c.teal),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (task.timeSpentMinutes > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: c.textFaint),
                  const SizedBox(width: 10),
                  Text(
                    '${task.timeSpentMinutes} minutes logged',
                    style: AppType.body(size: 13, color: c.text),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Status actions
          Text('Change status', style: AppType.body(size: 12, weight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatusActionChip(
                label: 'To Do',
                icon: Icons.radio_button_unchecked,
                color: c.textMuted,
                active: task.status == 'pending',
                onTap: () => _changeStatus(context, 'pending'),
              ),
              const SizedBox(width: 6),
              _StatusActionChip(
                label: 'In Progress',
                icon: Icons.adjust,
                color: c.blue,
                active: task.status == 'in_progress',
                onTap: () => _changeStatus(context, 'in_progress'),
              ),
              const SizedBox(width: 6),
              _StatusActionChip(
                label: 'Blocked',
                icon: Icons.block,
                color: c.rose,
                active: task.status == 'blocked',
                onTap: () => _changeStatus(context, 'blocked'),
              ),
              const SizedBox(width: 6),
              _StatusActionChip(
                label: 'Done',
                icon: Icons.check_circle,
                color: c.green,
                active: task.status == 'completed',
                onTap: () => _changeStatus(context, 'completed'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Delete
          Center(
            child: GestureDetector(
              onTap: () => _confirmDelete(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: c.rose.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, size: 14, color: c.rose),
                    const SizedBox(width: 6),
                    Text('Delete task',
                        style: AppType.body(size: 12, weight: FontWeight.w600, color: c.rose)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeStatus(BuildContext context, String status) {
    onStatusChange(status);
    Navigator.pop(context);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Remove "${task.taskName}" from this project?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
              Navigator.pop(context); // Close detail sheet
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showStaffPicker(BuildContext context) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text('Assign to staff', style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 4),
            Text('Select a team member', style: AppType.body(size: 12, color: c.textMuted)),
            const SizedBox(height: 16),
            if (staff.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No staff members. Add your team in Staff first.',
                    style: AppType.body(size: 13, color: c.textMuted)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: staff.length,
                  itemBuilder: (ctx, i) {
                    final s = staff[i];
                    final active = s.id == task.assignedToUserId;
                    return ListTile(
                      onTap: () {
                        onAssign(s);
                        Navigator.pop(ctx);
                      },
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: active ? c.teal.withValues(alpha: 0.2) : c.bgInset,
                        child: Text(
                          s.staffName.isNotEmpty ? s.staffName[0].toUpperCase() : '?',
                          style: AppType.body(size: 13, weight: FontWeight.w700, color: active ? c.teal : c.textMuted),
                        ),
                      ),
                      title: Text(s.staffName, style: AppType.body(size: 14, color: c.text)),
                      subtitle: Text(s.role, style: AppType.body(size: 11, color: c.textMuted)),
                      trailing: active ? Icon(Icons.check, size: 18, color: c.teal) : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _StatusActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: active ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : c.bgInset,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: active ? color : c.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? color : c.textFaint),
            const SizedBox(width: 4),
            Text(label,
                style: AppType.body(size: 10.5, weight: FontWeight.w600, color: active ? color : c.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── New Project Sheet (enhanced) ──────────────────────────────────────────────

class _NewProjectSheet extends StatefulWidget {
  const _NewProjectSheet();
  @override
  State<_NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<_NewProjectSheet> {
  final _nameCtrl = TextEditingController();
  String _projectType = 'custom';
  int _milestoneCount = 1;

  static const _types = [
    ('custom', 'Custom Project'),
    ('gig', 'Gig / Contract'),
    ('booking', 'Booking Pipeline'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Container(
        decoration: BoxDecoration(color: c.bgElevated, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text('New Project', style: AppType.heading(size: 20, color: c.text)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Project Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // Project type
            Text('Project Type', style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
            const SizedBox(height: 8),
            Row(
              children: _types.map((t) {
                final (key, label) = t;
                final active = _projectType == key;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t == _types.last ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _projectType = key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: active ? c.tealSurface : c.bgInset,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: active ? c.teal : c.border),
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: AppType.body(size: 11, weight: FontWeight.w600,
                              color: active ? c.tealDeep : c.textMuted),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Milestone count
            if (_projectType != 'gig') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Milestones', style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _milestoneCount > 1 ? () => setState(() => _milestoneCount--) : null,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: c.bgInset,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(Icons.remove, size: 14, color: _milestoneCount > 1 ? c.text : c.textFaint),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$_milestoneCount', style: AppType.heading(size: 16, color: c.teal)),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _milestoneCount < 10 ? () => setState(() => _milestoneCount++) : null,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: c.bgInset,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: c.border),
                      ),
                      child: Icon(Icons.add, size: 14, color: _milestoneCount < 10 ? c.text : c.textFaint),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            AppBtn('Create Project', full: true, onTap: () {
              Navigator.pop(context, {
                'name': _nameCtrl.text.trim(),
                'type': _projectType,
                'milestones': _milestoneCount,
              });
            }),
          ],
        ),
      ),
    );
  }
}

// ── New Task Sheet (enhanced with staff assignment) ───────────────────────────

class _NewTaskSheet extends StatefulWidget {
  final List<StaffMember> staff;
  const _NewTaskSheet({this.staff = const []});
  @override
  State<_NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends State<_NewTaskSheet> {
  final _nameCtrl = TextEditingController();
  String? _assignedStaffId;
  String _taskType = 'custom';

  static const _types = [
    ('custom', 'General'),
    ('fitting', 'Fitting'),
    ('registration', 'Registration'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final assigned = _assignedStaffId != null
        ? widget.staff.where((s) => s.id == _assignedStaffId).firstOrNull
        : null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Container(
        decoration: BoxDecoration(color: c.bgElevated, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text('New Task', style: AppType.heading(size: 20, color: c.text)),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Task Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 16),

            // Task type pills
            Text('Task Type', style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
            const SizedBox(height: 8),
            Row(
              children: _types.map((t) {
                final (key, label) = t;
                final active = _taskType == key;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t == _types.last ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _taskType = key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: active ? c.tealSurface : c.bgInset,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: active ? c.teal : c.border),
                        ),
                        child: Text(label, textAlign: TextAlign.center,
                            style: AppType.body(size: 11, weight: FontWeight.w600,
                                color: active ? c.tealDeep : c.textMuted)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Staff assignment
            if (widget.staff.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Assign to', style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showStaffPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: assigned != null ? c.tealSurface : c.bgInset,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: assigned != null ? c.teal : c.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (assigned != null) ...[
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: c.teal,
                              child: Text(assigned.staffName[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                            const SizedBox(width: 6),
                            Text(assigned.staffName, style: AppType.body(size: 11, color: c.tealDeep)),
                          ] else ...[
                            Icon(Icons.person_add_alt_1_outlined, size: 12, color: c.textMuted),
                            const SizedBox(width: 4),
                            Text('Assign', style: AppType.body(size: 11, color: c.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),
            AppBtn('Add Task', full: true, onTap: () {
              Navigator.pop(context, {
                'name': _nameCtrl.text.trim(),
                'assignedTo': _assignedStaffId,
                'taskType': _taskType,
              });
            }),
          ],
        ),
      ),
    );
  }

  void _showStaffPicker(BuildContext context) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text('Assign to staff', style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.staff.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    // Unassign option
                    return ListTile(
                      onTap: () {
                        setState(() => _assignedStaffId = null);
                        Navigator.pop(ctx);
                      },
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: c.bgInset,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person_off_outlined, size: 16),
                      ),
                      title: Text('Unassigned', style: AppType.body(size: 14, color: c.textMuted)),
                      trailing: _assignedStaffId == null
                          ? Icon(Icons.check, size: 18, color: c.teal) : null,
                    );
                  }
                  final s = widget.staff[i - 1];
                  final active = s.id == _assignedStaffId;
                  return ListTile(
                    onTap: () {
                      setState(() => _assignedStaffId = s.id);
                      Navigator.pop(ctx);
                    },
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: active ? c.teal.withValues(alpha: 0.2) : c.bgInset,
                      child: Text(s.staffName.isNotEmpty ? s.staffName[0].toUpperCase() : '?',
                          style: AppType.body(size: 13, weight: FontWeight.w700,
                              color: active ? c.teal : c.textMuted)),
                    ),
                    title: Text(s.staffName, style: AppType.body(size: 14, color: c.text)),
                    subtitle: Text(s.role, style: AppType.body(size: 11, color: c.textMuted)),
                    trailing: active ? Icon(Icons.check, size: 18, color: c.teal) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── States ────────────────────────────────────────────────────────────────────

class _NoProjectState extends StatelessWidget {
  final VoidCallback onNew;
  const _NoProjectState({required this.onNew});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_copy_outlined, size: 48, color: c.textFaint),
          const SizedBox(height: 16),
          Text('No projects found', style: AppType.heading(size: 18, color: c.text)),
          const SizedBox(height: 16),
          AppBtn('Create Project', icon: 'add', onTap: onNew),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: c.textFaint),
          const SizedBox(height: 16),
          Text('No tasks yet', style: AppType.heading(size: 18, color: c.text)),
          const SizedBox(height: 16),
          AppBtn('Add Task', icon: 'add', onTap: onAdd),
        ],
      ),
    );
  }
}
