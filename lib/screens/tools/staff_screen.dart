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
/// Now includes a "Payroll" tab for salary run visibility and processing.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _searchQuery = '';
  String _roleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.staff.isEmpty && !state.staffLoading) {
        state.loadStaff();
      }
      state.loadPayrollRuns();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final state = context.read<AppState>();
    await Future.wait([
      state.loadStaff(),
      state.loadPayrollRuns(),
    ]);
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
    final appState = context.read<AppState>();
    final businessId = appState.business.id;
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

    // Derive unique roles from staff list (sorted, 'All' first)
    final roles = ['All', ...{
      for (final s in allStaff) s.role,
    }.toList()..sort()];

    final filtered = allStaff.where((staff) {
      if (_roleFilter != 'All' && staff.role != _roleFilter) return false;
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
              'Team Management',
              onBack: () => Navigator.pop(context),
            ),
            
            // ── Tabs ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              height: 44,
              decoration: BoxDecoration(
                color: c.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: c.teal,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: c.textMuted,
                labelStyle: AppType.body(size: 13, weight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Team Roster'),
                  Tab(text: 'Payroll History'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // Tab 1: Team Roster
                  state.staffLoading && allStaff.isEmpty
                      ? const _LoadingState(label: 'Loading team…')
                      : allStaff.isEmpty
                          ? _EmptyState(onAdd: () => _openAddStaff(context))
                          : RefreshIndicator(
                              onRefresh: _refresh,
                              color: c.teal,
                              child: _ListBody(
                                staff: filtered,
                                roles: roles,
                                roleFilter: _roleFilter,
                                searchQuery: _searchQuery,
                                onSearchChanged: (v) => setState(() => _searchQuery = v),
                                onRoleChanged: (v) => setState(() => _roleFilter = v),
                                onAdd: () => _openAddStaff(context),
                                onEdit: (s) => _openEditStaff(context, s),
                                onDeactivate: _deactivateStaff,
                              ),
                            ),
                  
                  // Tab 2: Payroll History
                  state.payrollLoading && state.payrollRuns.isEmpty
                      ? const _LoadingState(label: 'Loading payroll…')
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          color: c.teal,
                          child: _PayrollBody(
                            runs: state.payrollRuns,
                            ytdTotal: state.ytdPayrollTotal,
                            activeStaffCount: allStaff.length,
                            delegationMetrics: state.delegationMetrics,
                          ),
                        ),
                ],
              ),
            ),
            
            if (_tabCtrl.index == 0 && allStaff.isNotEmpty)
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
  final List<String> roles;
  final String roleFilter;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onAdd;
  final void Function(StaffMember) onEdit;
  final void Function(StaffMember) onDeactivate;

  const _ListBody({
    required this.staff,
    required this.roles,
    required this.roleFilter,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onRoleChanged,
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
        const SizedBox(height: 10),

        // Role filter chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: roles.length,
            separatorBuilder: (_, i) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final role = roles[i];
              final active = role == roleFilter;
              return GestureDetector(
                onTap: () => onRoleChanged(role),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? c.teal : c.bgElevated,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: active ? c.teal : c.borderStrong,
                    ),
                  ),
                  child: Text(
                    role,
                    style: AppType.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: active ? Colors.white : c.textMuted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

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

// ── Payroll Body ─────────────────────────────────────────────────────────────

class _PayrollBody extends StatelessWidget {
  final List<PayrollRun> runs;
  final double ytdTotal;
  final int activeStaffCount;
  final Map<String, dynamic>? delegationMetrics;

  const _PayrollBody({
    required this.runs,
    required this.ytdTotal,
    required this.activeStaffCount,
    this.delegationMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final delegationIndex = (delegationMetrics?['index'] as num? ?? 0.0).toDouble();
    final delegationPct = (delegationMetrics?['percentage'] as num? ?? 0.0).toDouble();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        // Analytics Summary
        Row(
          children: [
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.hub_outlined, size: 14, color: c.teal),
                        const SizedBox(width: 4),
                        Text('Delegation', style: AppType.body(size: 11, weight: FontWeight.w600, color: c.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(delegationIndex.toStringAsFixed(2), style: AppType.heading(size: 20, color: c.text)),
                    Text('${delegationPct.round()}% tasks delegated', style: AppType.body(size: 10, color: c.textFaint)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 14, color: c.orange),
                        const SizedBox(width: 4),
                        Text('YTD Payroll', style: AppType.body(size: 11, weight: FontWeight.w600, color: c.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(formatGHS(ytdTotal), style: AppType.heading(size: 18, color: c.text)),
                    Text('$activeStaffCount active staff', style: AppType.body(size: 10, color: c.textFaint)),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),

        // Quick Action: Run Current Month
        AppBtn(
          'Run Payroll for ${currentMonthName()}',
          full: true,
          variant: BtnVariant.secondary,
          icon: 'play_circle_outline',
          onTap: () async {
            final app = context.read<AppState>();
            try {
              await app.initiateCurrentMonthPayroll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payroll run created for ${currentMonthName()}.')));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
              }
            }
          },
        ),

        const SizedBox(height: 24),
        Text('Payroll History', style: AppType.heading(size: 15, color: c.text)),
        const SizedBox(height: 10),

        if (runs.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Icon(Icons.payments_outlined, size: 40, color: c.textFaint),
                const SizedBox(height: 12),
                Text('No payroll history', style: AppType.body(size: 14, color: c.textMuted)),
              ],
            ),
          )
        else
          ...runs.map((run) => _PayrollRunCard(run: run)),
      ],
    );
  }
}

class _PayrollRunCard extends StatelessWidget {
  final PayrollRun run;
  const _PayrollRunCard({required this.run});

  void _showDetails(BuildContext context) {
    final c = context.colors;
    final parts = run.payPeriodMonth.split('-');
    final monthLabel = _kMonthNames[int.parse(parts[1]) - 1];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('$monthLabel ${parts[0]} Payroll', style: AppType.heading(size: 20, color: c.text)),
                const Spacer(),
                AppPill(
                  run.status == 'logged_to_finance' ? 'Processed' : 'Pending',
                  tone: run.status == 'logged_to_finance' ? PillTone.green : PillTone.amber,
                  small: true,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${run.staffCount} staff members · ${formatGHS(run.totalPayrollGhs)} total', 
                style: AppType.body(size: 14, color: c.textMuted)),
            
            const SizedBox(height: 24),
            Text('Staff Payments', style: AppType.body(size: 12, weight: FontWeight.w700, color: c.textFaint)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: run.staffPayments.length,
                itemBuilder: (ctx, i) {
                  final p = run.staffPayments[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.staffName, style: AppType.body(size: 14, weight: FontWeight.w600, color: c.text)),
                              Text(p.role, style: AppType.body(size: 12, color: c.textFaint)),
                            ],
                          ),
                        ),
                        Text(formatGHS(p.amountGhs), style: AppType.body(size: 14, weight: FontWeight.w600, color: c.text)),
                      ],
                    ),
                  );
                },
              ),
            ),

            if (run.status != 'logged_to_finance') ...[
              const SizedBox(height: 24),
              AppBtn(
                'Log as Business Expense',
                full: true,
                variant: BtnVariant.primary,
                onTap: () async {
                  Navigator.pop(ctx);
                  _confirmProcess(context);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmProcess(BuildContext context) async {
    final c = context.colors;
    final source = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: c.bgElevated,
        title: Text('Payment Source', style: AppType.heading(size: 17, color: c.text)),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'cash'), child: Text('Cash', style: AppType.body(size: 14, color: c.text))),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'momo'), child: Text('Mobile Money', style: AppType.body(size: 14, color: c.text))),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'bank'), child: Text('Bank Transfer', style: AppType.body(size: 14, color: c.text))),
        ],
      ),
    );

    if (source != null && context.mounted) {
      try {
        await context.read<AppState>().processPayroll(
          payrollRunId: run.id,
          paymentSource: source,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payroll processed and logged to finance.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to process payroll.')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final parts = run.payPeriodMonth.split('-');
    final monthLabel = _kMonthNames[int.parse(parts[1]) - 1];
    final yearLabel = parts[0];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => _showDetails(context),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: run.status == 'logged_to_finance' ? c.greenSurface : c.bgInset,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Icon(Icons.receipt_long, color: run.status == 'logged_to_finance' ? c.green : c.textFaint, size: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$monthLabel $yearLabel Payroll', style: AppType.body(size: 14, weight: FontWeight.w600, color: c.text)),
                  const SizedBox(height: 2),
                  Text('${run.staffCount} staff members', style: AppType.body(size: 12, color: c.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatGHS(run.totalPayrollGhs), style: AppType.body(size: 14, weight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: run.status == 'logged_to_finance' ? c.greenSurface : c.bgInset,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    run.status == 'logged_to_finance' ? 'PAID' : 'PENDING',
                    style: AppType.body(size: 9, weight: FontWeight.w800, color: run.status == 'logged_to_finance' ? c.green : c.textFaint),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _kMonthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

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
  final String label;
  const _LoadingState({this.label = 'Loading…'});

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
          Text(label,
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
