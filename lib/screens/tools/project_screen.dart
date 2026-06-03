import 'package:flutter/material.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';

// ── Task model ────────────────────────────────────────────────────────────────

/// Local task model for the Project Management screen.
/// No backend table exists yet — tasks live in-memory only.
class _TaskItem {
  final String id;
  String title;
  String status; // 'todo' | 'in_progress' | 'done'
  String priority; // 'low' | 'medium' | 'high'
  String? assignee;
  String? description;

  _TaskItem({
    required this.id,
    required this.title,
    this.status = 'todo',
    this.priority = 'medium',
    this.assignee,
    this.description,
  });

  String get statusLabel => switch (status) {
        'in_progress' => 'In Progress',
        'done' => 'Done',
        _ => 'To Do',
      };

  IconData get      statusIcon => switch (status) {
        'in_progress' => Icons.adjust,
        'done' => Icons.check_circle,
        _ => Icons.radio_button_unchecked,
      };
}

// ── Screen ───────────────────────────────────────────────────────────────────

/// Project Management screen — task board with status columns.
/// Tasks are stored locally (no backend table yet).
class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final List<_TaskItem> _tasks = _kSampleTasks;
  String _statusFilter = 'all';
  bool _showCompleted = true;

  List<_TaskItem> get _filteredTasks {
    var result = _tasks;
    if (_statusFilter != 'all') {
      result = result.where((t) => t.status == _statusFilter).toList();
    }
    if (!_showCompleted) {
      result = result.where((t) => t.status != 'done').toList();
    }
    return result;
  }

  int get _todoCount => _tasks.where((t) => t.status == 'todo').length;
  int get _inProgressCount => _tasks.where((t) => t.status == 'in_progress').length;
  int get _doneCount => _tasks.where((t) => t.status == 'done').length;

  void _cycleStatus(_TaskItem task) {
    setState(() {
      task.status = switch (task.status) {
        'todo' => 'in_progress',
        'in_progress' => 'done',
        _ => 'todo',
      };
    });
  }

  Future<void> _openNewTaskSheet() async {
    final task = await showModalBottomSheet<_TaskItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewTaskSheet(),
    );
    if (task != null) {
      setState(() => _tasks.insert(0, task));
    }
  }

  Future<void> _openTaskDetail(_TaskItem task) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailSheet(
        task: task,
        onStatusCycle: () {
          Navigator.pop(context);
          _cycleStatus(task);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'Project Management',
              onBack: () => Navigator.pop(context),
              trailing: GestureDetector(
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
            ),
            // ── Status filter chips + counts ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status summary row
                  Row(
                    children: [
                      _CountBadge(
                        label: 'To Do',
                        count: _todoCount,
                        color: c.textMuted,
                      ),
                      const SizedBox(width: 8),
                      _CountBadge(
                        label: 'In Progress',
                        count: _inProgressCount,
                        color: c.blue,
                      ),
                      const SizedBox(width: 8),
                      _CountBadge(
                        label: 'Done',
                        count: _doneCount,
                        color: c.green,
                      ),
                      const Spacer(),
                      // Toggle completed visibility
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showCompleted = !_showCompleted),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: c.bgElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.border),
                          ),
                          child: Icon(
                            _showCompleted
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 16,
                            color: c.textFaint,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Status filter chips
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      separatorBuilder: (_, i) =>
                          const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final chips = [
                          ('all', 'All', c.teal),
                          ('todo', 'To Do', c.textMuted),
                          ('in_progress', 'In Progress', c.blue),
                          ('done', 'Done', c.green),
                        ];
                        final (key, label, color) = chips[i];
                        final active = _statusFilter == key;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _statusFilter = key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: active
                                  ? color.withValues(alpha: 0.12)
                                  : c.bgElevated,
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: active ? color : c.borderStrong,
                              ),
                            ),
                            child: Text(
                              label,
                              style: AppType.body(
                                size: 12,
                                weight: FontWeight.w600,
                                color: active ? color : c.textMuted,
                              ),
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
              child: _filteredTasks.isEmpty
                  ? _EmptyState(onAdd: _openNewTaskSheet)
                  : RefreshIndicator(
                      onRefresh: () async => setState(() {}),
                      color: c.teal,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        children: [
                          ..._filteredTasks
                              .asMap()
                              .entries
                              .map((e) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: FadeInSlide(
                                      index: e.key,
                                      child: _TaskCard(
                                        task: e.value,
                                        onTap: () =>
                                            _openTaskDetail(e.value),
                                        onStatusCycle: () =>
                                            _cycleStatus(e.value),
                                      ),
                                    ),
                                  )),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Count badge ───────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountBadge({
    required this.label,
    required this.count,
    required this.color,
  });

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
          Text(
            '$count',
            style: AppType.body(
              size: 13,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppType.body(size: 11, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Task card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final _TaskItem task;
  final VoidCallback onTap;
  final VoidCallback onStatusCycle;

  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onStatusCycle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (priColor, priLabel) = switch (task.priority) {
      'high' => (c.rose, 'High'),
      'low' => (c.textMuted, 'Low'),
      _ => (c.amber, 'Medium'),
    };

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator (tap to cycle)
          GestureDetector(
            onTap: onStatusCycle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(2),
              child: Icon(
                task.statusIcon,
                size: 20,
                color: switch (task.status) {
                  'in_progress' => c.blue,
                  'done' => c.green,
                  _ => c.textFaint,
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: AppType.body(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: task.status == 'done'
                              ? c.textMuted
                              : c.text,
                        ),
                      ),
                    ),
                    // Priority pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: priColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        priLabel,
                        style: AppType.body(
                          size: 10,
                          weight: FontWeight.w600,
                          color: priColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.assignee != null ||
                    task.description != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (task.assignee != null) ...[
                        Icon(Icons.person_outline,
                            size: 12, color: c.textFaint),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            task.assignee!,
                            style: AppType.body(
                                size: 11, color: c.textFaint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (task.description != null)
                          Text(' · ',
                              style: AppType.body(
                                  size: 11, color: c.textFaint)),
                      ],
                      if (task.description != null)
                        Expanded(
                          child: Text(
                            task.description!,
                            style: AppType.body(
                                size: 11, color: c.textFaint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
                // Status label
                const SizedBox(height: 4),
                Text(
                  task.statusLabel,
                  style: AppType.body(
                    size: 10.5,
                    weight: FontWeight.w600,
                    color: switch (task.status) {
                      'in_progress' => c.blue,
                      'done' => c.green,
                      _ => c.textFaint,
                    },
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

// ── New task sheet ────────────────────────────────────────────────────────────

class _NewTaskSheet extends StatefulWidget {
  const _NewTaskSheet();

  @override
  State<_NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends State<_NewTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _assigneeCtrl = TextEditingController();
  String _priority = 'medium';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _assigneeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final task = _TaskItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      priority: _priority,
      assignee: _assigneeCtrl.text.trim().isNotEmpty
          ? _assigneeCtrl.text.trim()
          : null,
      description:
          _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
    );
    Navigator.pop(context, task);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Text('New Task',
                style: AppType.heading(size: 20, color: c.text)),
            const SizedBox(height: 20),
            // Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: TextField(
                controller: _titleCtrl,
                autofocus: true,
                style: AppType.body(size: 14, color: c.text),
                decoration: InputDecoration(
                  hintText: 'Task title',
                  hintStyle: AppType.body(size: 14, color: c.textFaint),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Description
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: TextField(
                controller: _descCtrl,
                style: AppType.body(size: 14, color: c.text),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Description (optional)',
                  hintStyle: AppType.body(size: 14, color: c.textFaint),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Assignee
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 16, color: c.textFaint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _assigneeCtrl,
                      style: AppType.body(size: 14, color: c.text),
                      decoration: InputDecoration(
                        hintText: 'Assignee (optional)',
                        hintStyle:
                            AppType.body(size: 14, color: c.textFaint),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Priority selector
            Row(
              children: [
                Text('Priority',
                    style: AppType.body(
                        size: 12,
                        weight: FontWeight.w600,
                        color: c.textMuted)),
                const SizedBox(width: 10),
                _PriorityChip(
                  label: 'Low',
                  color: c.textMuted,
                  active: _priority == 'low',
                  onTap: () => setState(() => _priority = 'low'),
                ),
                const SizedBox(width: 6),
                _PriorityChip(
                  label: 'Medium',
                  color: c.amber,
                  active: _priority == 'medium',
                  onTap: () => setState(() => _priority = 'medium'),
                ),
                const SizedBox(width: 6),
                _PriorityChip(
                  label: 'High',
                  color: c.rose,
                  active: _priority == 'high',
                  onTap: () => setState(() => _priority = 'high'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: AppBtn(
                'Add task',
                full: true,
                icon: 'add',
                onTap: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: AppType.body(
            size: 12,
            weight: FontWeight.w600,
            color: active ? color : color.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ── Task detail sheet ─────────────────────────────────────────────────────────

class _TaskDetailSheet extends StatelessWidget {
  final _TaskItem task;
  final VoidCallback onStatusCycle;

  const _TaskDetailSheet({
    required this.task,
    required this.onStatusCycle,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (priColor, priLabel) = switch (task.priority) {
      'high' => (c.rose, 'High'),
      'low' => (c.textMuted, 'Low'),
      _ => (c.amber, 'Medium'),
    };

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 12),
            Row(
              children: [
                AppPill(
                  task.statusLabel,
                  tone: switch (task.status) {
                    'in_progress' => PillTone.teal,
                    'done' => PillTone.green,
                    _ => PillTone.neutral,
                  },
                  small: true,
                ),
                const SizedBox(width: 8),
                AppPill(priLabel,
                    tone: switch (task.priority) {
                  'high' => PillTone.rose,
                  'low' => PillTone.neutral,
                  _ => PillTone.amber,
                }, small: true),
              ],
            ),
            const SizedBox(height: 14),
            Text(task.title,
                style: AppType.heading(size: 20, color: c.text)),
            if (task.description != null &&
                task.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(task.description!,
                  style: AppType.body(size: 14, color: c.textMuted)),
            ],
            if (task.assignee != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 16, color: c.textFaint),
                  const SizedBox(width: 8),
                  Text(task.assignee!,
                      style: AppType.body(
                          size: 13.5, color: c.text)),
                ],
              ),
            ],
            const SizedBox(height: 24),
            // Actions
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onStatusCycle,
                icon: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: c.teal,
                ),
                label: Text(
                  'Move to ${switch (task.status) { 'todo' => 'In Progress', 'in_progress' => 'Done', _ => 'To Do' }}',
                  style: AppType.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: c.teal,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: c.teal.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

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
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.tealSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.view_kanban_outlined,
                size: 26, color: c.teal),
          ),
          const SizedBox(height: 16),
          Text('No tasks yet',
              style: AppType.heading(size: 18, color: c.text)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Create your first task to start tracking project\nprogress for your business.',
              textAlign: TextAlign.center,
              style: AppType.body(size: 13, color: c.textMuted),
            ),
          ),
          const SizedBox(height: 18),
          AppBtn('New task', icon: 'add', onTap: onAdd),
        ],
      ),
    );
  }
}

// ── Sample tasks ─────────────────────────────────────────────────────────────

final _kSampleTasks = [
  _TaskItem(
    id: 't1',
    title: 'Set up business banking',
    status: 'todo',
    priority: 'high',
    assignee: 'Kwame',
  ),
  _TaskItem(
    id: 't2',
    title: 'Register for Ghana Revenue Authority',
    status: 'in_progress',
    priority: 'high',
    assignee: 'Ama',
    description: 'Get TIN certificate',
  ),
  _TaskItem(
    id: 't3',
    title: 'Create social media pages',
    status: 'todo',
    priority: 'medium',
    assignee: 'Kojo',
  ),
  _TaskItem(
    id: 't4',
    title: 'Design product catalog',
    status: 'done',
    priority: 'medium',
    assignee: 'Esi',
    description: 'Include pricing for all products',
  ),
  _TaskItem(
    id: 't5',
    title: 'Hire first employee',
    status: 'todo',
    priority: 'low',
  ),
  _TaskItem(
    id: 't6',
    title: 'Set up inventory system',
    status: 'done',
    priority: 'high',
    assignee: 'Kwame',
    description: 'Import product list',
  ),
];
