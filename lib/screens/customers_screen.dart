import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../services/crm_service.dart';
import '../services/supabase_service.dart';
import '../state/app_state.dart';
import 'customer_detail_screen.dart';

/// Customers tab — enhanced with CRM groups, tags, and smart segments.
class CustomersScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const CustomersScreen({super.key, this.onOpenDrawer});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  bool _loaded = false;
  List<CustomerGroup> _groups = [];
  String _selectedGroup = 'all';
  String _searchQuery = '';
  /// Customer names (lowercased) that belong to the selected group.
  /// Null when "All" is selected (no group filter).
  Set<String>? _groupCustomerNames;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final state = context.read<AppState>();
    if (state.business.id != null && state.customers.isEmpty && !state.customersLoading) {
      _loaded = true;
      state.loadCustomers();
      _loadGroups();
    }
  }

  Future<void> _loadGroups() async {
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;
    final rows = await CrmService.getCustomerGroups(businessId: bizId);
    if (!mounted) return;
    setState(() => _groups = rows.map(CustomerGroup.fromRow).toList());
  }

  Future<void> _showCreateGroup() async {
    final c = context.colors;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Group',
            style: AppType.heading(size: 17, color: c.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Group name',
                labelStyle: AppType.body(size: 12, color: c.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: AppType.body(size: 14, color: c.text),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: AppType.body(size: 12, color: c.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: AppType.body(size: 14, color: c.text),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Create',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.teal)),
          ),
        ],
      ),
    );

    if (created != true || nameCtrl.text.trim().isEmpty) return;
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;
    await CrmService.createCustomerGroup(
      businessId: bizId,
      name: nameCtrl.text.trim(),
      description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
    );
    _loadGroups();
  }

  /// Fetch customer names that belong to [groupId] from the
  /// customer_group_members + crm_profiles tables.
  Future<void> _filterByGroup(String groupId) async {
    setState(() {
      _selectedGroup = groupId;
      _groupCustomerNames = null; // clear while loading
    });
    if (groupId == 'all') return; // no group filter

    try {
      final members = await SupabaseService.client
          .from('customer_group_members')
          .select('crm_profile_id')
          .eq('group_id', groupId);

      final profileIds = (members as List)
          .map((m) => (m as Map)['crm_profile_id'] as String?)
          .whereType<String>()
          .toList();

      if (profileIds.isEmpty) {
        if (!mounted) return;
        setState(() => _groupCustomerNames = {});
        return;
      }

      // Fetch CRM profiles to get customer names for filtering
      final profiles = await SupabaseService.client
          .from('crm_profiles')
          .select('customer_name')
          .inFilter('id', profileIds);

      final names = (profiles as List)
          .map((p) => (p as Map)['customer_name'] as String?)
          .whereType<String>()
          .map((n) => n.trim().toLowerCase())
          .toSet();

      if (!mounted) return;
      setState(() => _groupCustomerNames = names);
    } catch (e) {
      if (!mounted) return;
      // If the group query fails, show all customers (no filter).
      setState(() => _groupCustomerNames = null);
    }
  }

  List<Customer> get _filteredCustomers {
    final state = context.read<AppState>();
    var customers = state.customers;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      customers = customers.where((c) =>
          c.fullName.toLowerCase().contains(q) ||
          (c.phone?.contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false)).toList();
    }
    // Filter by selected group
    if (_selectedGroup != 'all' && _groupCustomerNames != null) {
      customers = customers
          .where((c) => _groupCustomerNames!.contains(c.fullName.trim().toLowerCase()))
          .toList();
    }
    return customers;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final customers = _filteredCustomers;
    final invoices = state.invoices;

    final totalOutstanding = invoices
        .where((i) => i.status != 'paid' && i.status != 'void')
        .fold<int>(0, (s, i) => s + i.amount);

    return Material(
      color: c.bg,
      child: SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onOpenDrawer,
                  child: AppAvatar(state.business.initials, size: 40, imageUrl: state.business.logoUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Customers',
                      style: AppType.display(size: 28, color: c.text)),
                ),
              ],
            ),
          ),

          // Summary
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Text(
              customers.isEmpty
                  ? 'No customers yet — they appear as you send invoices'
                  : '${customers.length} ${customers.length == 1 ? "customer" : "customers"} · '
                      '${invoices.length} ${invoices.length == 1 ? "invoice" : "invoices"} · '
                      '${formatGHS(totalOutstanding)} outstanding',
              style: AppType.body(size: 12.5, color: c.textMuted),
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: c.textFaint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: AppType.body(size: 13, color: c.text),
                      decoration: InputDecoration(
                        hintText: 'Search customers…',
                        hintStyle: AppType.body(size: 13, color: c.textFaint),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _searchQuery = ''),
                      child: Icon(Icons.close, size: 16, color: c.textFaint),
                    ),
                ],
              ),
            ),
          ),

          // Groups row
          if (_groups.isNotEmpty) ...[
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  _GroupChip(
                    label: 'All',
                    active: _selectedGroup == 'all',
                    onTap: () => _filterByGroup('all'),
                  ),
                  ..._groups.map((g) => _GroupChip(
                        label: g.name,
                        count: g.memberCount,
                        active: _selectedGroup == g.id,
                        onTap: () => _filterByGroup(g.id),
                      )),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: GestureDetector(
                      onTap: _showCreateGroup,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: c.tealSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.add, size: 14, color: c.teal),
                            const SizedBox(width: 3),
                            Text('Group',
                                style: AppType.body(size: 11.5, weight: FontWeight.w600, color: c.teal)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Loading state
          if (state.customersLoading && customers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: _LoadingIndicator()),
            ),

          // Empty state
          if (!state.customersLoading && customers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.people_outline, size: 36, color: c.textFaint),
                    const SizedBox(height: 12),
                    Text('Your customers will appear here',
                        textAlign: TextAlign.center,
                        style: AppType.heading(size: 15, color: c.text)),
                    const SizedBox(height: 4),
                    Text(
                      'Create an invoice or log a sale with a customer name — they\'ll show up here automatically.',
                      textAlign: TextAlign.center,
                      style: AppType.body(size: 12.5, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ),

          // Customer list
          if (!state.customersLoading && customers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: _showCreateGroup,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: c.tealSurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group_add, size: 14, color: c.teal),
                              const SizedBox(width: 6),
                              Text('Create group to organize customers',
                                  style: AppType.body(size: 11.5, color: c.teal)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ...customers.asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FadeInSlide(
                          index: e.key,
                          child: Builder(
                            builder: (rowContext) => _CustomerRow(
                              customer: e.value,
                              invoices: invoices.where((inv) =>
                                  inv.customer.trim().toLowerCase() ==
                                  e.value.fullName.trim().toLowerCase()
                              ).toList(),
                              onTap: () => Navigator.push(
                                rowContext,
                                MaterialPageRoute(
                                  builder: (_) => CustomerDetailScreen(
                                    customer: e.value,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    ));
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SizedBox(
      width: 28, height: 28,
      child: CircularProgressIndicator(
          strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(c.teal)),
    );
  }
}

// ── Group Chip ──────────────────────────────────────────────────────────────

class _GroupChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;
  final VoidCallback onTap;
  const _GroupChip({
    required this.label,
    this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? c.teal : c.bgInset,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? c.teal.withValues(alpha: 0.3) : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: AppType.body(
                      size: 12,
                      weight: FontWeight.w600,
                      color: active ? Colors.white : c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text('$count',
                    style: AppType.body(size: 11, color: active ? Colors.white70 : c.textFaint)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Customer Row ────────────────────────────────────────────────────────────

class _CustomerRow extends StatelessWidget {
  final Customer customer;
  final List<Invoice> invoices;
  final VoidCallback onTap;

  const _CustomerRow({
    required this.customer,
    required this.invoices,
    required this.onTap,
  });

  String get _initials {
    final parts = customer.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '—';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final totalOutstanding = invoices
        .where((i) => i.status != 'paid' && i.status != 'void')
        .fold<int>(0, (s, i) => s + i.amount);
    final hasOutstanding = totalOutstanding > 0;
    final contactInfo = customer.phone ?? customer.email;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AppAvatar(_initials, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.fullName,
                    style: AppType.body(size: 13.5, weight: FontWeight.w600, color: c.text)),
                if (contactInfo != null) ...[
                  const SizedBox(height: 2),
                  Text(contactInfo,
                      style: AppType.body(size: 11.5, color: c.textMuted)),
                ],
                if (invoices.isNotEmpty)
                  Text('${invoices.length} ${invoices.length == 1 ? "invoice" : "invoices"}',
                      style: AppType.body(size: 11, color: c.textFaint)),
              ],
            ),
          ),
          if (hasOutstanding)
            AppPill('GHS ${totalOutstanding.round()} due',
                tone: PillTone.rose, small: true),
        ],
      ),
    );
  }
}
