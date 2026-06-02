import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/hrm_service.dart';
import '../../state/app_state.dart';

/// Bottom sheet for adding a new staff member or editing an existing one.
class AddStaffSheet extends StatefulWidget {
  final StaffMember? existing;

  const AddStaffSheet({super.key, this.existing});

  @override
  State<AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends State<AddStaffSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();

  bool _saving = false;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e.staffName;
      _emailCtrl.text = e.staffEmail ?? '';
      _phoneCtrl.text = e.staffPhone ?? '';
      _roleCtrl.text = e.role;
      _salaryCtrl.text = e.salaryMonthly?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _roleCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final role = _roleCtrl.text.trim();
    final salaryRaw = _salaryCtrl.text.trim();

    if (name.isEmpty) {
      setState(() { _saving = false; _error = 'Staff name is required.'; });
      return;
    }
    if (role.isEmpty) {
      setState(() { _saving = false; _error = 'Role is required.'; });
      return;
    }

    final salary = salaryRaw.isNotEmpty ? double.tryParse(salaryRaw) : null;
    final appState = context.read<AppState>();
    final businessId = appState.business.id;

    if (!appState.supabaseConfigured) {
      setState(() { _saving = false; _saved = true; });
      return;
    }
    if (businessId == null) {
      setState(() { _saving = false; _error = 'Business profile not set up yet.'; });
      return;
    }

    try {
      if (widget.existing != null) {
        await HrmService.updateStaff(
          staffId: widget.existing!.id,
          businessId: businessId,
          staffName: name,
          staffEmail: email.isNotEmpty ? email : null,
          staffPhone: phone.isNotEmpty ? phone : null,
          role: role,
          salaryMonthly: salary,
        );
      } else {
        await HrmService.createStaff(
          businessId: businessId,
          staffName: name,
          staffEmail: email.isNotEmpty ? email : null,
          staffPhone: phone.isNotEmpty ? phone : null,
          role: role,
          salaryMonthly: salary,
        );
      }

      if (!mounted) return;
      unawaited(appState.loadStaff());
      setState(() { _saving = false; _saved = true; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _error = _friendlyError(e); });
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    final match = RegExp(r'message:\s*([^,)]+)').firstMatch(msg);
    final extracted = match?.group(1)?.trim();
    if (extracted != null && extracted.isNotEmpty) return extracted;
    return 'Could not save staff member. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isEdit = widget.existing != null;

    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: _saved ? _buildSaved(c) : _buildForm(c, isEdit),
    );
  }

  Widget _buildForm(AppColorsX c, bool isEdit) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Text(isEdit ? 'Edit staff' : 'Add staff',
                style: AppType.heading(size: 20, color: c.text)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Text(
              'Add a team member to your business roster.',
              style: AppType.body(size: 13, color: c.textMuted),
            ),
          ),

          // Full name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Field(
              label: 'Full name',
              ctrl: _nameCtrl,
              hint: 'e.g. Kwame Asante',
              autofocus: true,
            ),
          ),
          const SizedBox(height: 14),

          // Role
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Field(
              label: 'Role / Position',
              ctrl: _roleCtrl,
              hint: 'e.g. Sales associate, Tailor, Driver',
            ),
          ),
          const SizedBox(height: 14),

          // Email + Phone row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _Field(
                    label: 'Email (optional)',
                    ctrl: _emailCtrl,
                    hint: 'email@example.com',
                    keyboard: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    label: 'Phone (optional)',
                    ctrl: _phoneCtrl,
                    hint: '+233 XX XXX XXXX',
                    keyboard: TextInputType.phone,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Monthly salary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Field(
              label: 'Monthly salary GHS (optional)',
              ctrl: _salaryCtrl,
              hint: '0.00',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: c.rose.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.rose.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 16, color: c.rose),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: AppType.body(size: 13, color: c.rose)),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _saving
                ? Center(
                    child: SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(c.teal),
                      ),
                    ),
                  )
                : AppBtn(isEdit ? 'Save changes' : 'Add staff member',
                    full: true, onTap: _save),
          ),
        ],
      ),
    );
  }

  Widget _buildSaved(AppColorsX c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: c.greenSurface, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 32, color: c.green),
          ),
          const SizedBox(height: 16),
          Text(
            widget.existing != null ? 'Staff updated' : 'Staff added',
            style: AppType.heading(size: 22, color: c.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Your team roster has been updated.',
            textAlign: TextAlign.center,
            style: AppType.body(size: 13, color: c.textMuted),
          ),
          const SizedBox(height: 24),
          AppBtn('Done',
              full: true,
              variant: BtnVariant.secondary,
              onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

// ── Reusable field ────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final TextInputType? keyboard;
  final bool autofocus;

  const _Field({
    required this.label,
    required this.hint,
    required this.ctrl,
    this.keyboard,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppType.body(
                size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
        const SizedBox(height: 5),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: ctrl,
            autofocus: autofocus,
            keyboardType: keyboard,
            style: AppType.body(size: 14, color: c.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppType.body(size: 13, color: c.textFaint),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
