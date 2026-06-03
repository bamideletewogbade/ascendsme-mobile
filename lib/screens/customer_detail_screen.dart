import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../services/crm_service.dart';
import '../services/supabase_service.dart';
import '../state/app_state.dart';
import 'tools/invoice_detail_screen.dart';

/// Customer detail — enhanced with CRM profile, interaction timeline,
/// tags management, smart segments, and internal notes.
class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  CrmProfile? _crmProfile;
  List<CrmInteraction> _interactions = [];
  bool _loadingCrm = true;
  String? _newTag;
  bool _showInternalNotes = false;

  @override
  void initState() {
    super.initState();
    _loadCrmData();
  }

  Future<void> _loadCrmData() async {
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;

    setState(() => _loadingCrm = true);

    try {
      // Get or create CRM profile
      final profileRow = await CrmService.getOrCreateCrmProfile(
        businessId: bizId,
        name: widget.customer.fullName,
        email: widget.customer.email,
        phone: widget.customer.phone,
      );

      if (profileRow != null) {
        final profile = CrmProfile.fromRow(profileRow);
        final interactionRows = await CrmService.getInteractions(
          businessId: bizId,
          customerProfileId: profile.id,
        );

        if (!mounted) return;
        setState(() {
          _crmProfile = profile;
          _interactions = interactionRows.map(CrmInteraction.fromRow).toList();
          _loadingCrm = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _loadingCrm = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCrm = false);
    }
  }

  Future<void> _addInteraction(String type) async {
    if (_crmProfile == null) return;
    final descCtrl = TextEditingController();
    final c = context.colors;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log ${type == 'internal' ? 'note' : type}',
            style: AppType.heading(size: 16, color: c.text)),
        content: TextField(
          controller: descCtrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter ${type == 'internal' ? 'internal note' : 'description'}…',
            hintStyle: AppType.body(size: 13, color: c.textFaint),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: AppType.body(size: 13, color: c.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.teal)),
          ),
        ],
      ),
    );

    if (result != true || descCtrl.text.trim().isEmpty) return;
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;

    if (type == 'internal') {
      await CrmService.addInteraction(
        businessId: bizId,
        customerProfileId: _crmProfile!.id,
        type: 'note',
        description: 'Internal Note',
        internalNotes: descCtrl.text.trim(),
        isInternal: true,
      );
    } else {
      await CrmService.addInteraction(
        businessId: bizId,
        customerProfileId: _crmProfile!.id,
        type: type,
        description: descCtrl.text.trim(),
      );
    }
    _loadCrmData();
  }

  Future<void> _addTag() async {
    if (_crmProfile == null || _newTag == null || _newTag!.trim().isEmpty) return;
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;
    await CrmService.addTag(
      businessId: bizId,
      profileId: _crmProfile!.id,
      tag: _newTag!.trim(),
    );
    setState(() => _newTag = null);
    _loadCrmData();
  }

  Future<void> _removeTag(String tag) async {
    if (_crmProfile == null) return;
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;
    await CrmService.removeTag(
      businessId: bizId,
      profileId: _crmProfile!.id,
      tag: tag,
    );
    _loadCrmData();
  }

  Future<void> _showEditCustomer(BuildContext context) async {
    final nameCtrl = TextEditingController(text: widget.customer.fullName);
    final phoneCtrl = TextEditingController(text: widget.customer.phone ?? '');
    final emailCtrl = TextEditingController(text: widget.customer.email ?? '');
    final c = this.context.colors;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit customer',
            style: AppType.heading(size: 17, color: c.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: AppType.body(size: 12, color: c.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: AppType.body(size: 14, color: c.text),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: 'Phone',
                labelStyle: AppType.body(size: 12, color: c.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: AppType.body(size: 14, color: c.text),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: emailCtrl,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: AppType.body(size: 12, color: c.textMuted),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              style: AppType.body(size: 14, color: c.text),
              keyboardType: TextInputType.emailAddress,
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
            child: Text('Save',
                style: AppType.body(size: 13, weight: FontWeight.w600, color: c.teal)),
          ),
        ],
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;

    try {
      await SupabaseService.client
          .from('customers')
          .update({
            'full_name': nameCtrl.text.trim(),
            if (phoneCtrl.text.trim().isNotEmpty) 'phone': phoneCtrl.text.trim(),
            if (emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
          })
          .eq('id', widget.customer.id);
      if (!mounted) return;
      context.read<AppState>().loadCustomers();
      _loadCrmData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not update customer.'),
          backgroundColor: c.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();

    final invoices = state.invoices
        .where((inv) =>
            inv.customer.trim().toLowerCase() ==
            widget.customer.fullName.trim().toLowerCase())
        .toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime(2000);
        final bDate = b.createdAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

    final total = invoices.fold<int>(0, (s, i) => s + i.amount);
    final outstanding = invoices
        .where((i) => i.status != 'paid' && i.status != 'void')
        .fold<int>(0, (s, i) => s + i.amount);
    final overdue = invoices.where((i) => i.status == 'overdue').length;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: c.bgElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: c.border),
                    ),
                    child: Icon(Icons.arrow_back, size: 18, color: c.text),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Customer',
                    style: AppType.heading(size: 18, color: c.text)),
              ],
            ),
            const SizedBox(height: 16),

            // Identity card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAvatar(_customerInitials, size: 54),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(widget.customer.fullName,
                                      style: AppType.heading(size: 18, color: c.text)),
                                ),
                                GestureDetector(
                                  onTap: () => _showEditCustomer(context),
                                  child: Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      color: c.bgInset,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: c.border),
                                    ),
                                    child: Icon(Icons.edit_outlined, size: 14, color: c.textMuted),
                                  ),
                                ),
                              ],
                            ),
                            if (widget.customer.phone != null || widget.customer.email != null) ...[
                              const SizedBox(height: 4),
                              if (widget.customer.phone != null)
                                _InfoRow(Icons.phone_outlined, widget.customer.phone!),
                              if (widget.customer.email != null)
                                _InfoRow(Icons.email_outlined, widget.customer.email!),
                            ],
                            const SizedBox(height: 4),
                            Text('${invoices.length} ${invoices.length == 1 ? "invoice" : "invoices"} · GHS ${total.round()} total',
                                style: AppType.body(size: 12.5, color: c.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // CRM segments (if available)
                  if (_crmProfile != null && _crmProfile!.smartSegments.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(height: 1, color: c.border),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _crmProfile!.smartSegments.map((seg) {
                        final segColor = switch (seg) {
                          'At-risk' => c.rose,
                          'High value' => c.amber,
                          'Inactive 90d+' => c.textMuted,
                          'Open lead' => c.blue,
                          _ => c.teal,
                        };
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: segColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(seg,
                              style: AppType.body(size: 10.5, weight: FontWeight.w600, color: segColor)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Outstanding card
            if (outstanding > 0)
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Outstanding',
                              style: AppType.body(size: 11.5, color: c.textMuted)),
                          const SizedBox(height: 4),
                          Text('GHS ${outstanding.round()}',
                              style: AppType.heading(size: 20, color: c.text)),
                          if (overdue > 0)
                            Text('$overdue overdue ${overdue == 1 ? "invoice" : "invoices"}',
                                style: AppType.body(size: 11.5, color: c.rose)),
                        ],
                      ),
                    ),
                    if (overdue > 0)
                      AppPill('Follow up', tone: PillTone.rose, small: true),
                  ],
                ),
              ),

            if (_loadingCrm) ...[
              const SizedBox(height: 22),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(c.teal)),
                  ),
                ),
              ),
            ],
            if (!_loadingCrm && _crmProfile != null) ...[
              const SizedBox(height: 22),
              Text('CRM Profile',
                  style: AppType.heading(size: 16, color: c.text)),
              const SizedBox(height: 10),

              // CRM metrics
              Row(
                children: [
                  Expanded(child: _CrmStat(label: 'CLV', value: 'GHS ${_crmProfile!.customerLifetimeValueGhs.round()}', color: c.teal)),
                  Expanded(child: _CrmStat(label: 'Orders', value: '${_crmProfile!.totalOrders}', color: c.blue)),
                  Expanded(child: _CrmStat(label: 'Churn risk', value: '${(_crmProfile!.churnRiskScore * 100).round()}%', color: _crmProfile!.churnRiskScore >= 0.6 ? c.rose : c.green)),
                  Expanded(child: _CrmStat(label: 'Spent', value: 'GHS ${_crmProfile!.totalSpentGhs.round()}', color: c.amber)),
                ],
              ),
              const SizedBox(height: 12),

              // Tags
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Tags',
                          style: AppType.body(size: 12, weight: FontWeight.w600, color: c.textMuted)),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_crmProfile!.tags.isEmpty)
                    Text('No tags yet',
                        style: AppType.body(size: 12, color: c.textFaint))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _crmProfile!.tags.map((tag) => Chip(
                            label: Text(tag,
                                style: AppType.body(size: 11, weight: FontWeight.w600, color: c.teal)),
                            backgroundColor: c.tealSurface,
                            deleteIcon: Icon(Icons.close, size: 14, color: c.teal),
                            onDeleted: () => _removeTag(tag),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                          )).toList(),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: c.bgInset,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: c.border),
                          ),
                          child: TextField(
                            onChanged: (v) => _newTag = v,
                            onSubmitted: (_) => _addTag(),
                            style: AppType.body(size: 12, color: c.text),
                            decoration: InputDecoration(
                              hintText: 'Add tag…',
                              hintStyle: AppType.body(size: 12, color: c.textFaint),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _addTag,
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: c.teal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Interaction log
              Row(
                children: [
                  Text('Activity log',
                      style: AppType.heading(size: 15, color: c.text)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showInternalNotes = !_showInternalNotes),
                    child: Text(_showInternalNotes ? 'Hide notes' : 'Show notes',
                        style: AppType.body(size: 12, weight: FontWeight.w600, color: c.teal)),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Quick action buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ActionChip(label: 'Call', icon: Icons.phone_outlined, onTap: () => _addInteraction('call')),
                    _ActionChip(label: 'WhatsApp', icon: Icons.chat_bubble_outline, onTap: () => _addInteraction('whatsapp')),
                    _ActionChip(label: 'Email', icon: Icons.email_outlined, onTap: () => _addInteraction('email')),
                    _ActionChip(label: 'Meeting', icon: Icons.people_outline, onTap: () => _addInteraction('meeting')),
                    _ActionChip(label: 'Note', icon: Icons.notes_outlined, onTap: () => _addInteraction('internal')),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Interaction list
              if (_interactions.isEmpty)
                Text('No activity logged yet',
                    style: AppType.body(size: 12, color: c.textFaint))
              else
                ..._interactions.where((i) => _showInternalNotes || !i.isInternal).map((interaction) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _InteractionTile(interaction: interaction),
                    )),
            ],

            const SizedBox(height: 22),

            // Invoice history
            Text('Invoice history',
                style: AppType.heading(size: 16, color: c.text)),
            const SizedBox(height: 10),

            if (invoices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No invoices yet for this customer.',
                    style: AppType.body(size: 13, color: c.textMuted)),
              )
            else
              ...invoices.map((inv) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _InvoiceTile(
                      invoice: inv,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailScreen(initialInvoice: inv),
                        ),
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  String get _customerInitials {
    final parts = widget.customer.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '—';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: c.textFaint),
          const SizedBox(width: 4),
          Text(text, style: AppType.body(size: 12, color: c.textMuted)),
        ],
      ),
    );
  }
}

class _CrmStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _CrmStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppType.body(size: 9.5, weight: FontWeight.w600, color: c.textMuted)),
          const SizedBox(height: 4),
          Text(value,
              style: AppType.body(size: 13, weight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: c.bgInset,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: c.textMuted),
              const SizedBox(width: 4),
              Text(label,
                  style: AppType.body(size: 11.5, weight: FontWeight.w600, color: c.text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InteractionTile extends StatelessWidget {
  final CrmInteraction interaction;
  const _InteractionTile({required this.interaction});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, iconBg, iconFg) = switch (interaction.interactionType) {
      'call' || 'voice_call' => (Icons.phone_outlined, c.greenSurface, c.green),
      'whatsapp' => (Icons.chat_bubble_outline, c.tealSurface, c.teal),
      'email' => (Icons.email_outlined, c.blueSurface, c.blue),
      'meeting' => (Icons.people_outline, c.amberSurface, c.amber),
      'purchase' => (Icons.payments_outlined, c.greenSurface, c.green),
      _ => (Icons.notes_outlined, c.bgInset, c.textMuted),
    };

    final date = DateTime.tryParse(interaction.interactionDate);
    final dateStr = date != null
        ? '${date.month}/${date.day} ${date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour)}:${date.minute.toString().padLeft(2, '0')}${date.hour >= 12 ? 'PM' : 'AM'}'
        : '';

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconFg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(interaction.typeLabel,
                        style: AppType.body(size: 12, weight: FontWeight.w600, color: c.text)),
                    if (interaction.isInternal) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.lock_outline, size: 10, color: c.textFaint),
                    ],
                    const Spacer(),
                    Text(dateStr,
                        style: AppType.body(size: 10, color: c.textFaint)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  interaction.isInternal && interaction.internalNotes != null
                      ? interaction.internalNotes!
                      : interaction.description,
                  style: AppType.body(size: 12, color: c.textMuted),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;

  const _InvoiceTile({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (tone, label) = switch (invoice.status) {
      'paid' => (PillTone.green, 'Paid'),
      'overdue' => (PillTone.rose, 'Overdue'),
      'pending' || 'sent' => (PillTone.orange, 'Pending'),
      _ => (PillTone.neutral, 'Draft'),
    };
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.id,
                    style: AppType.mono(size: 11.5, color: c.text)),
                const SizedBox(height: 2),
                Text('Due ${invoice.due}',
                    style: AppType.body(size: 11.5, color: c.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('GHS ${invoice.amount}',
                  style: AppType.body(size: 13.5, weight: FontWeight.w600, color: c.text)),
              const SizedBox(height: 4),
              AppPill(label, tone: tone, small: true),
            ],
          ),
        ],
      ),
    );
  }
}
