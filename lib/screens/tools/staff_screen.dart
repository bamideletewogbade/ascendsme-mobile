import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/hrm_service.dart';
import '../../state/app_state.dart';
import '../sheets/add_staff_sheet.dart';

/// Staff management screen — view team roster, add/edit staff, deactivate.
/// Mobile scope: name, role, contact, salary, active status.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.staff.isEmpty && !state.staffLoading) {
        state.loadStaff();
      }
    });
  }

  void _openAddStaff(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddStaffSheet(),
    );
  }

  void _openEditStaff(BuildContext context, StaffMember staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddStaffSheet(existing: staff),
    );
  }

  Future<void> _deactivateStaff(StaffMember staff) async {
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove ${staff.staffName}?',
            style: AppType.heading(size: 17, color: c.text)),
        content: Text(
          'This staff member will be deactivated and removed from the active roster.',
          style: AppType.body(size: 13, color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.rose)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final appState = context.read<AppState>();
    final businessId = appState.business.id;
    if (businessId == null) return;

    try {
      await HrmService.deactivateStaff(staffId: staff.id, businessId: businessId);
      if (!mounted) return;
      unawaited(appState.loadStaff());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final allStaff = state.staff;

    final filtered = allStaff.where((staff) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return staff.staffName.toLowerCase().contains(q) ||
          staff.role.toLowerCase().contains(q) ||
          (staff.staffEmail?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              'People',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: state.staffLoading && allStaff.isEmpty
                  ? const _LoadingState()
                  : allStaff.isEmpty
                      ? _EmptyState(onAdd: () => _openAddStaff(context))
                      : _ListBody(
                          staff: filtered,
                          allCount: allStaff.length,
                          searchQuery: _searchQuery,
                          onSearchChanged: (v) => setState(() => _searchQuery = v),
                          onAdd: () => _openAddStaff(context),
                          onEdit: (s) => _openEditStaff(context, s),
                          onDeactivate: _deactivateStaff,
                        ),
            ),
            if (allStaff.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: AppBtn(
                  'Add team member',
                  full: true,
                  icon: 'person_add',
                  onTap: () => _openAddStaff(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── List body ────────────────────────────────────────────────────────────────

class _ListBody extends StatelessWidget {
  final List<StaffMember> staff;
  final int allCount;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAdd;
  final void Function(StaffMember) onEdit;
  final void Function(StaffMember) onDeactivate;

  const _ListBody({
    required this.staff,
    required this.allCount,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Summary
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text('$allCount team members',
              style: AppType.body(size: 13, color: c.textMuted)),
        ),

        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: c.textFaint),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: onSearchChanged,
                  style: AppType.body(size: 13.5, color: c.text),
                  decoration: InputDecoration(
                    hintText: 'Search team…',
                    hintStyle: AppType.body(size: 13.5, color: c.textFaint),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () => onSearchChanged(''),
                  child: Icon(Icons.close, size: 16, color: c.textFaint),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Staff list
        if (staff.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 36, color: c.textFaint),
                  const SizedBox(height: 8),
                  Text('No team members match your search',
                      style: AppType.body(size: 13, color: c.textMuted)),
                ],
              ),
            ),
          )
        else
          ...staff.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FadeInSlide(
                  index: e.key,
                  child: _StaffCard(
                    member: e.value,
                    onEdit: () => onEdit(e.value),
                    onDeactivate: () => onDeactivate(e.value),
                  ),
                ),
              )),
      ],
    );
  }
}

// ── Staff card ──────────────────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  final StaffMember member;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  const _StaffCard({
    required this.member,
    required this.onEdit,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = member.staffName
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: c.navySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(initials,
                  style: AppType.body(
                      size: 14, weight: FontWeight.w700, color: c.navyTint)),
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
                      child: Text(member.staffName,
                          style: AppType.body(
                              size: 13.5, weight: FontWeight.w600, color: c.text)),
                    ),
                    GestureDetector(
                      onTap: () => _showOptions(context),
                      child: Icon(Icons.more_horiz, size: 18, color: c.textFaint),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(member.role,
                        style: AppType.body(size: 11.5, color: c.textMuted)),
                    if (member.salaryMonthly != null) ...[
                      Text(' · ',
                          style: AppType.body(size: 11, color: c.textFaint)),
                      Text('GHS ${member.salaryMonthly!.round()}',
                          style: AppType.body(size: 11, color: c.textFaint)),
                    ],
                  ],
                ),
                if (member.staffEmail != null || member.staffPhone != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    [member.staffEmail, member.staffPhone]
                        .whereType<String>()
                        .join(' · '),
                    style: AppType.body(size: 10.5, color: c.textFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 8),
            Text(member.staffName,
                style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 2),
            Text(member.role,
                style: AppType.body(size: 13, color: c.textMuted)),
            const SizedBox(height: 20),
            _OptionRow(
              icon: Icons.edit_outlined,
              label: 'Edit details',
              onTap: () { Navigator.pop(ctx); onEdit(); },
            ),
            const SizedBox(height: 4),
            _OptionRow(
              icon: Icons.person_remove_outlined,
              label: 'Deactivate',
              labelColor: c.rose,
              onTap: () { Navigator.pop(ctx); onDeactivate(); },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  const _OptionRow({
    required this.icon,
    required this.label,
    this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.bgInset,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: labelColor ?? c.textMuted),
            const SizedBox(width: 12),
            Text(label,
                style: AppType.body(
                    size: 14, weight: FontWeight.w500,
                    color: labelColor ?? c.text)),
          ],
        ),
      ),
    );
  }
}

// ── Loading / Empty states ───────────────────────────────────────────────────

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
          Text('Loading team…',
              style: AppType.body(size: 13, color: c.textMuted)),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.18),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: c.navySurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.how_to_reg_outlined, size: 26, color: c.navy),
              ),
              const SizedBox(height: 16),
              Text('No team members yet',
                  style: AppType.heading(size: 18, color: c.text)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Add your first team member to start building your business roster.',
                  textAlign: TextAlign.center,
                  style: AppType.body(size: 13, color: c.textMuted),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: AppBtn('Add team member', full: true, icon: 'person_add', onTap: onAdd),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
