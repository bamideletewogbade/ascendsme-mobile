import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/crm_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../customer_detail_screen.dart';
import '../sheets/bulk_import_customers_sheet.dart';

/// CRM Dashboard — customer relationship management with smart segments,
/// churn insights, CLV tracking, and interaction logging.
/// Mobile-focused: quick actions, glanceable metrics, customer list.
class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  String _searchQuery = '';
  String _activeSegment = 'all';
  List<CrmProfile> _crmProfiles = [];
  List<CustomerGroup> _groups = [];
  bool _loading = true;
  bool _loadingGroups = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _showCustomerDetail(BuildContext context, CrmProfile profile) {
    final c = context.colors;
    final invoices = context.read<AppState>().invoices;
    final customerInvoices = invoices
        .where((inv) =>
            inv.customer.trim().toLowerCase() ==
            profile.customerName.trim().toLowerCase())
        .toList();
    final outstanding = customerInvoices
        .where((i) => i.status != 'paid' && i.status != 'void')
        .fold<int>(0, (s, i) => s + i.amount);
    final overdue = customerInvoices.where((i) => i.status == 'overdue').length;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassSheet(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAvatar(_initials(profile.customerName), size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.customerName,
                            style: AppType.heading(size: 18, color: c.text)),
                        if (profile.customerEmail != null ||
                            profile.customerPhone != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              [profile.customerPhone, profile.customerEmail]
                                  .whereType<String>()
                                  .join(' · '),
                              style: AppType.body(
                                  size: 12, color: c.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metrics row
              Row(
                children: [
                  _crmStat(c, 'CLV', formatGHS(profile.customerLifetimeValueGhs), c.teal),
                  const SizedBox(width: 8),
                  _crmStat(c, 'Orders', '${profile.totalOrders}', c.blue),
                  const SizedBox(width: 8),
                  _crmStat(c, 'Churn', '${(profile.churnRiskScore * 100).round()}%',
                      profile.churnRiskScore >= 0.6 ? c.rose : c.green),
                ],
              ),
              const SizedBox(height: 12),

              // Tags / segments
              if (profile.smartSegments.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: profile.smartSegments.map((seg) {
                    final segColor = switch (seg) {
                      'At-risk' => c.rose,
                      'High value' => c.amber,
                      'Inactive 90d+' => c.textMuted,
                      'Open lead' => c.blue,
                      _ => c.teal,
                    };
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: segColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(seg,
                          style: AppType.body(size: 11, weight: FontWeight.w600, color: segColor)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Last interaction
              if (profile.lastInteractionDate != null) ...[
                Text('Last interaction',
                    style: AppType.body(size: 11, color: c.textMuted)),
                const SizedBox(height: 4),
                Text(_lastActiveLabel(profile.lastInteractionDate!),
                    style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 12),
              ],

              // Outstanding / overdue
              if (outstanding > 0) ...[
                _detailRow(c, 'Outstanding', formatGHS(outstanding)),
                if (overdue > 0) ...[
                  const SizedBox(height: 4),
                  _detailRow(c, 'Overdue invoices', '$overdue'),
                ],
                const SizedBox(height: 12),
              ],

              // Contact actions
              Row(
                children: [
                  if (profile.customerPhone != null)
                    Expanded(
                      child: _ContactBtn(
                        icon: Icons.phone_outlined,
                        label: 'Call',
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: profile.customerPhone!));
                          Navigator.pop(ctx);
                          _showSnackBar('Phone copied: ${profile.customerPhone}');
                        },
                      ),
                    ),
                  if (profile.customerPhone != null &&
                      profile.customerEmail != null)
                    const SizedBox(width: 8),
                  if (profile.customerEmail != null)
                    Expanded(
                      child: _ContactBtn(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: profile.customerEmail!));
                          Navigator.pop(ctx);
                          _showSnackBar('Email copied: ${profile.customerEmail}');
                        },
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ContactBtn(
                      icon: Icons.person_outline,
                      label: 'Profile',
                      onTap: () {
                        Navigator.pop(ctx);
                        final customer = Customer(
                          id: profile.id,
                          fullName: profile.customerName,
                          phone: profile.customerPhone,
                          email: profile.customerEmail,
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerDetailScreen(customer: customer),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _crmStat(AppColorsX c, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: c.bgInset,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: AppType.heading(size: 16, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: AppType.label(size: 9.5, color: c.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(AppColorsX c, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppType.body(size: 12, color: c.textMuted)),
        Text(value,
            style: AppType.body(size: 12, weight: FontWeight.w600, color: c.text)),
      ],
    );
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: context.colors.navyDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showBulkImport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BulkImportCustomersSheet(),
    );
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    final bizId = state.business.id;
    if (bizId == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    try {
      // Load CRM profiles and customers in parallel
      final results = await Future.wait([
        CrmService.fetchCrmProfiles(businessId: bizId),
        CrmService.getCustomerGroups(businessId: bizId),
      ]);
      if (!mounted) return;
      setState(() {
        _crmProfiles = (results[0] as List<Map<String, dynamic>>)
            .map(CrmProfile.fromRow)
            .toList();
        _groups = (results[1] as List<Map<String, dynamic>>)
            .map(CustomerGroup.fromRow)
            .toList();
        _loading = false;
        _loadingGroups = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<CrmProfile> get _filteredProfiles {
    var profiles = _crmProfiles;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      profiles = profiles.where((p) =>
          p.customerName.toLowerCase().contains(q) ||
          (p.customerEmail?.toLowerCase().contains(q) ?? false) ||
          (p.customerPhone?.contains(q) ?? false)).toList();
    }
    switch (_activeSegment) {
      case 'at_risk':
        profiles = profiles.where((p) => p.churnRiskScore >= 0.6).toList();
      case 'high_value':
        profiles = profiles.where((p) =>
            p.customerLifetimeValueGhs >= 1000 || p.totalSpentGhs >= 1000).toList();
      case 'inactive':
        profiles = profiles.where((p) {
          if (p.lastInteractionDate == null) return true;
          final last = DateTime.tryParse(p.lastInteractionDate!);
          if (last == null) return true;
          return DateTime.now().difference(last).inDays >= 90;
        }).toList();
      case 'active':
        profiles = profiles.where((p) {
          if (p.lastInteractionDate == null) return false;
          final last = DateTime.tryParse(p.lastInteractionDate!);
          if (last == null) return false;
          return DateTime.now().difference(last).inDays < 30;
        }).toList();
      default:
        if (_activeSegment.startsWith('group:')) {
          final groupId = _activeSegment.substring(6);
          final group = _groups.where((g) => g.id == groupId).firstOrNull;
          if (group != null) {
            profiles = profiles
                .where((p) => p.groupNames.contains(group.name))
                .toList();
          }
        }
    }
    return profiles;
  }

  int get _atRiskCount =>
      _crmProfiles.where((p) => p.churnRiskScore >= 0.6).length;
  int get _highValueCount =>
      _crmProfiles.where((p) => p.customerLifetimeValueGhs >= 1000 || p.totalSpentGhs >= 1000).length;
  double get _totalClv =>
      _crmProfiles.fold(0.0, (s, p) => s + p.customerLifetimeValueGhs);

  Future<void> _quickAddCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final c = context.colors;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add customer',
            style: AppType.heading(size: 17, color: c.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Customer name',
                labelStyle: AppType.body(size: 12, color: c.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: AppType.body(size: 14, color: c.text),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: 'Phone (optional)',
                labelStyle: AppType.body(size: 12, color: c.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: AppType.body(size: 14, color: c.text),
              keyboardType: TextInputType.phone,
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
            child: Text('Add',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.teal)),
          ),
        ],
      ),
    );

    if (created != true || nameCtrl.text.trim().isEmpty) return;
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;

    // Create in both customers table and CRM
    await SupabaseService.createCustomer(
      businessId: bizId,
      fullName: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
    );
    await CrmService.getOrCreateCrmProfile(
      businessId: bizId,
      name: nameCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();
    final filtered = _filteredProfiles;
    final invoices = state.invoices;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text('CRM',
                        style: AppType.display(size: 28, color: c.text)),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _showBulkImport(context),
                          child: Container(
                            width: 36, height: 36,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: c.bgInset,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: c.border),
                            ),
                            child: Icon(Icons.file_upload_outlined, size: 18, color: c.textMuted),
                          ),
                        ),
                        GestureDetector(
                          onTap: _quickAddCustomer,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: c.teal,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_add, size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!_loading && _crmProfiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(
                    'Customers appear here as you send invoices or log sales',
                    style: AppType.body(size: 12.5, color: c.textMuted),
                  ),
                ),

              // ── Metrics row ──
              if (!_loading && _crmProfiles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      Expanded(child: _MetricCard(
                        label: 'Customers',
                        value: '${_crmProfiles.length}',
                        icon: Icons.people_outline,
                        color: c.teal,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _MetricCard(
                        label: 'At risk',
                        value: '$_atRiskCount',
                        icon: Icons.warning_amber_outlined,
                        color: _atRiskCount > 0 ? c.rose : c.textFaint,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: _MetricCard(
                        label: 'High value',
                        value: '$_highValueCount',
                        icon: Icons.star_outline,
                        color: _highValueCount > 0 ? c.amber : c.textFaint,
                      )),
                    ],
                  ),
                ),

              // ── Search bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
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

              // ── Group filter chips ──
              if (!_loading && _groups.isNotEmpty)
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    children: [
                      _GroupChip(
                        label: 'Groups',
                        active: _activeSegment == 'groups_all',
                        count: _crmProfiles.length,
                        onTap: () => setState(() => _activeSegment = 'groups_all'),
                      ),
                      ..._groups.map((g) => _GroupChip(
                            label: g.name,
                            active: _activeSegment == 'group:${g.id}',
                            count: g.memberCount,
                            onTap: () => setState(() => _activeSegment = 'group:${g.id}'),
                          )),
                    ],
                  ),
                ),
              // ── Smart segment chips ──
              if (!_loading && _crmProfiles.isNotEmpty)
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    children: [
                      _SegmentChip(
                        label: 'All',
                        active: _activeSegment == 'all',
                        onTap: () => setState(() => _activeSegment = 'all'),
                      ),
                      _SegmentChip(
                        label: 'Active',
                        active: _activeSegment == 'active',
                        onTap: () => setState(() => _activeSegment = 'active'),
                      ),
                      _SegmentChip(
                        label: 'At-risk ($_atRiskCount)',
                        active: _activeSegment == 'at_risk',
                        onTap: () => setState(() => _activeSegment = 'at_risk'),
                      ),
                      _SegmentChip(
                        label: 'High value ($_highValueCount)',
                        active: _activeSegment == 'high_value',
                        onTap: () => setState(() => _activeSegment = 'high_value'),
                      ),
                      _SegmentChip(
                        label: 'Inactive 90d+',
                        active: _activeSegment == 'inactive',
                        onTap: () => setState(() => _activeSegment = 'inactive'),
                      ),
                    ],
                  ),
                ),

              // ── Loading / Empty / Customer list ──
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_crmProfiles.isEmpty)
                _EmptyState(c: c, onAdd: _quickAddCustomer)
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 36, color: c.textFaint),
                        const SizedBox(height: 8),
                        Text('No customers match this filter',
                            style: AppType.body(size: 13, color: c.textMuted)),
                      ],
                    ),
                  ),
                )
              else
                ...filtered.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: FadeInSlide(
                        index: e.key,
                        child: _CrmCustomerRow(
                          profile: e.value,
                          invoices: invoices.where((inv) =>
                              inv.customer.trim().toLowerCase() ==
                              e.value.customerName.trim().toLowerCase()).toList(),
                          onTap: () => _showCustomerDetail(context, e.value),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

String _lastActiveLabel(String dateStr) {
  final dt = DateTime.tryParse(dateStr);
  if (dt == null) return '—';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${diff.inDays ~/ 7}w ago';
  return '${diff.inDays ~/ 30}mo ago';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '—';
  if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

// ── Group chip ────────────────────────────────────────────────────────────

class _GroupChip extends StatelessWidget {
  final String label;
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _GroupChip({
    required this.label,
    required this.active,
    required this.count,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? c.navySurfaceStrong : c.bgInset,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? c.navy : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_outlined, size: 12,
                  color: active ? Colors.white : c.textMuted),
              const SizedBox(width: 4),
              Text(label,
                  style: AppType.body(size: 11.5, weight: FontWeight.w600,
                      color: active ? Colors.white : c.textMuted)),
              if (count > 0) ...[
                const SizedBox(width: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: active ? Colors.white.withValues(alpha: 0.2) : c.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('$count',
                      style: AppType.label(size: 8.5, color: active ? Colors.white : c.textFaint)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Contact button ────────────────────────────────────────────────────────

class _ContactBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: c.bgInset,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: c.teal),
            const SizedBox(height: 4),
            Text(label,
                style: AppType.body(size: 10.5, weight: FontWeight.w600, color: c.textMuted)),
          ],
        ),
      ),
    );
  }
}

// ── Metric card ───────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value,
              style: AppType.body(size: 16, weight: FontWeight.w700, color: c.text)),
          Text(label,
              style: AppType.body(size: 10, color: c.textMuted)),
        ],
      ),
    );
  }
}

// ── Segment chip ──────────────────────────────────────────────────────────

class _SegmentChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SegmentChip({required this.label, required this.active, required this.onTap});

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
          child: Text(label,
              style: AppType.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: active ? Colors.white : c.textMuted)),
        ),
      ),
    );
  }
}

// ── CRM Customer Row ──────────────────────────────────────────────────────

class _CrmCustomerRow extends StatelessWidget {
  final CrmProfile profile;
  final List<Invoice> invoices;
  final VoidCallback onTap;
  const _CrmCustomerRow({
    required this.profile,
    required this.invoices,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final overdue = invoices.where((i) => i.status == 'overdue').length;
    final outstanding = invoices
        .where((i) => i.status != 'paid' && i.status != 'void')
        .fold<int>(0, (s, i) => s + i.amount);
    final segments = profile.smartSegments;
    final contactInfo = profile.customerPhone ?? profile.customerEmail;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AppAvatar(_initials(profile.customerName), size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(profile.customerName,
                        style: AppType.body(size: 13.5, weight: FontWeight.w600, color: c.text),
                        overflow: TextOverflow.ellipsis),
                    if (profile.churnRiskScore >= 0.6) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.warning_amber_rounded, size: 13, color: c.rose),
                    ],
                  ],
                ),
                if (contactInfo != null) ...[
                  const SizedBox(height: 2),
                  Text(contactInfo,
                      style: AppType.body(size: 11.5, color: c.textMuted)),
                ],
                // Segments or invoice summary
                if (segments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: segments.take(2).map((seg) {
                        final segColor = switch (seg) {
                          'At-risk' => c.rose,
                          'High value' => c.amber,
                          'Inactive 90d+' => c.textMuted,
                          'Open lead' => c.blue,
                          _ => c.teal,
                        };
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: segColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(seg,
                              style: AppType.body(size: 9.5, weight: FontWeight.w600, color: segColor)),
                        );
                      }).toList(),
                    ),
                  )
                else if (profile.lastInteractionDate != null)
                  Text('Last active ${_lastActiveLabel(profile.lastInteractionDate!)}',
                      style: AppType.body(size: 11, color: c.textFaint))
                else if (invoices.isNotEmpty)
                  Text('${invoices.length} ${invoices.length == 1 ? 'invoice' : 'invoices'}',
                      style: AppType.body(size: 11, color: c.textFaint)),
              ],
            ),
          ),
          if (outstanding > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('GHS ${outstanding.round()}',
                    style: AppType.body(size: 13, weight: FontWeight.w700, color: c.text)),
                if (overdue > 0)
                  Text('$overdue overdue',
                      style: AppType.body(size: 10.5, color: c.rose)),
              ],
            )
          else if (profile.totalSpentGhs > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('GHS ${profile.totalSpentGhs.round()}',
                    style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
                Text('${profile.totalOrders} orders',
                    style: AppType.body(size: 10, color: c.textFaint)),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final AppColorsX c;
  final VoidCallback onAdd;
  const _EmptyState({required this.c, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: c.tealSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.people_outline, size: 28, color: c.teal),
          ),
          const SizedBox(height: 16),
          Text('No customers yet',
              style: AppType.heading(size: 17, color: c.text)),
          const SizedBox(height: 8),
          Text(
            'Add your first customer or send an invoice — they\'ll appear here with CRM insights, interaction history, and smart segments.',
            textAlign: TextAlign.center,
            style: AppType.body(size: 13, color: c.textMuted),
          ),
          const SizedBox(height: 20),
          AppBtn('Add customer', icon: 'person_add', fontSize: 13, onTap: onAdd),
        ],
      ),
    );
  }
}
