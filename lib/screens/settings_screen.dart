import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import '../services/app_logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _cityCtrl;
  bool _saving = false;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _nameCtrl = TextEditingController(text: state.business.name);
    _phoneCtrl = TextEditingController(text: '');
    _cityCtrl = TextEditingController(
        text: state.business.city != '—' ? state.business.city : '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBusinessInfo() async {
    final state = context.read<AppState>();
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final city = _cityCtrl.text.trim();

    if (name.isEmpty) {
      _showSnack('Business name cannot be empty');
      return;
    }
    if (name == state.business.name && phone.isEmpty && city.isEmpty) {
      _showSnack('No changes to save');
      return;
    }

    setState(() => _saving = true);
    try {
      await state.updateBusinessInfo(
        name: name != state.business.name ? name : null,
        phone: phone.isNotEmpty ? phone : null,
        city: city.isNotEmpty ? city : null,
      );
      if (!mounted) return;
      _showSnack('Business info updated');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to save. Check your connection.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final state = context.read<AppState>();
    final bizId = state.business.id;
    if (bizId == null) {
      _showSnack('Sign in to upload a logo');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.bytes == null) {
        _showSnack('Could not read the selected image');
        return;
      }

      final ext = file.extension?.toLowerCase() ?? 'jpg';
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };

      setState(() => _uploadingLogo = true);
      final url = await state.uploadBusinessLogo(
        fileBytes: file.bytes!,
        fileName: 'logo.$ext',
        fileType: mimeType,
      );
      if (!mounted) return;
      if (url != null) {
        _showSnack('Logo uploaded');
      } else {
        _showSnack('Logo upload failed');
      }
    } catch (e) {
      log.error('logo pick failed', error: e);
      if (mounted) _showSnack('Could not pick image');
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _removeLogo() async {
    final state = context.read<AppState>();
    setState(() => _uploadingLogo = true);
    try {
      await state.removeBusinessLogo();
      if (!mounted) return;
      _showSnack('Logo removed');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to remove logo');
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _onAvatarTap() async {
    final state = context.read<AppState>();
    if (state.business.logoUrl == null) {
      await _pickAndUploadLogo();
      return;
    }
    final action = await showPhotoOptionsSheet(context);
    if (action == 'change') {
      await _pickAndUploadLogo();
    } else if (action == 'remove') {
      await _removeLogo();
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: c.navyDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader('Settings', onBack: () => Navigator.pop(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // ── Business Info ────────────────────────────────────────
                  _SectionLabel('Business Info'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        // Logo upload row
                        _LogoRow(
                          initials: state.business.initials,
                          logoUrl: state.business.logoUrl,
                          uploading: _uploadingLogo,
                          onTap: _uploadingLogo ? null : _onAvatarTap,
                        ),
                        Divider(color: c.border, height: 1, indent: 52),
                        // Business name
                        _EditableRow(
                          icon: Icons.business_outlined,
                          label: 'Business name',
                          controller: _nameCtrl,
                        ),
                        Divider(color: c.border, height: 1, indent: 52),
                        // Phone
                        _EditableRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          controller: _phoneCtrl,
                          hint: 'Add phone number',
                        ),
                        Divider(color: c.border, height: 1, indent: 52),
                        // City
                        _EditableRow(
                          icon: Icons.location_on_outlined,
                          label: 'City',
                          controller: _cityCtrl,
                          hint: 'Add city',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppBtn(
                    _saving ? 'Saving\u2026' : 'Save changes',
                    full: true,
                    variant: BtnVariant.primary,
                    fontSize: 13,
                    onTap: _saving ? null : _saveBusinessInfo,
                  ),

                  const SizedBox(height: 24),

                  // ── Notifications ────────────────────────────────────────
                  _SectionLabel('Notifications'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _SettingsSwitch(
                          icon: Icons.description_outlined,
                          label: 'Invoice reminders',
                          subtitle: 'When invoices are due or overdue',
                          value: state.notifyInvoiceReminders,
                          onChanged: state.setNotifyInvoiceReminders,
                        ),
                        Divider(color: c.border, height: 1, indent: 52),
                        _SettingsSwitch(
                          icon: Icons.payments_outlined,
                          label: 'Payment received',
                          subtitle: 'When a customer pays an invoice',
                          value: state.notifyPaymentReceived,
                          onChanged: state.setNotifyPaymentReceived,
                        ),
                        Divider(color: c.border, height: 1, indent: 52),
                        _SettingsSwitch(
                          icon: Icons.receipt_outlined,
                          label: 'Expense reminders',
                          subtitle: 'Weekly reminders to log expenses',
                          value: state.notifyExpenseReminders,
                          onChanged: state.setNotifyExpenseReminders,
                        ),
                        Divider(color: c.border, height: 1, indent: 52),
                        _SettingsSwitch(
                          icon: Icons.schedule,
                          label: 'Expiring proforma alerts',
                          subtitle: 'When a proforma expires within 3 days',
                          value: state.notifyExpiringQuotes,
                          onChanged: state.setNotifyExpiringQuotes,
                        ),
                        Divider(color: c.border, height: 1, indent: 52),
                        _SettingsSwitch(
                          icon: Icons.warning_amber_rounded,
                          label: 'Overdue invoice alerts',
                          subtitle: 'When invoices are 7+ days overdue',
                          value: state.notifyOverdueInvoices,
                          onChanged: state.setNotifyOverdueInvoices,
                        ),
                        Divider(color: c.border, height: 1, indent: 52),
                        _SettingsSwitch(
                          icon: Icons.inventory_2,
                          label: 'Low stock alerts',
                          subtitle: 'When inventory runs below threshold',
                          value: state.notifyLowStock,
                          onChanged: state.setNotifyLowStock,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Appearance ───────────────────────────────────────────
                  _SectionLabel('Appearance'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: _ThemeToggle(
                      value: state.darkMode,
                      onChanged: state.setDark,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Account ──────────────────────────────────────────────
                  _SectionLabel('Account'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _ReadOnlyRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: state.user?.email ?? '\u2014',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── About ────────────────────────────────────────────────
                  _SectionLabel('About'),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: _ReadOnlyRow(
                      icon: Icons.info_outline,
                      label: 'App version',
                      value: '1.0.0',
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Sign out ─────────────────────────────────────────────
                  _SignOutButton(
                    onTap: () => _confirmSignOut(context),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign out?',
            style: AppType.heading(size: 17, color: c.text)),
        content: Text(
          'You will need to sign in again to access your business.',
          style: AppType.body(size: 13, color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppType.body(
                    size: 13, weight: FontWeight.w600, color: c.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sign out',
                style: AppType.body(
                    size: 13, weight: FontWeight.w600, color: c.rose)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
    context.read<AppState>().signOut();
  }
}

// ── Section label ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(label,
          style: AppType.label(size: 11, color: c.textMuted)),
    );
  }
}

// ── Logo upload row — shows avatar + tap-to-change hint ───────────────────────

class _LogoRow extends StatelessWidget {
  final String initials;
  final String? logoUrl;
  final bool uploading;
  final VoidCallback? onTap;

  const _LogoRow({
    required this.initials,
    this.logoUrl,
    required this.uploading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              children: [
                AppAvatar(initials, size: 48, imageUrl: logoUrl),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: c.teal,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.bgElevated, width: 2.5),
                    ),
                    child: uploading
                        ? SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.camera_alt,
                            size: 10, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Tap the camera icon to upload or change your business logo',
                style: AppType.body(size: 12.5, color: c.textMuted)),
          ),
        ],
      ),
    );
  }
}

// ── Editable row (text field) ────────────────────────────────────────────────

class _EditableRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final String? hint;

  const _EditableRow({
    required this.icon,
    required this.label,
    required this.controller,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.textMuted),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppType.body(
                  size: 14, weight: FontWeight.w500, color: c.text),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: AppType.body(
                    size: 11.5, weight: FontWeight.w600, color: c.textMuted),
                hintText: hint,
                hintStyle: AppType.body(size: 14, color: c.textFaint),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Read-only info row ──────────────────────────────────────────────────────

class _ReadOnlyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.textMuted),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label,
                style: AppType.body(
                    size: 14, weight: FontWeight.w500, color: c.text)),
          ),
          Text(value,
              style: AppType.body(size: 13, color: c.textMuted),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─── Settings switch (notification toggle) ─────────────────────────────────

class _SettingsSwitch extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c.textMuted),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppType.body(
                        size: 14, weight: FontWeight.w500, color: c.text)),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!,
                      style: AppType.body(size: 11.5, color: c.textMuted)),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: c.teal,
            activeTrackColor: c.tealSurface,
          ),
        ],
      ),
    );
  }
}

// ── Theme toggle ─────────────────────────────────────────────────────────────

class _ThemeToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ThemeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.dark_mode_outlined, size: 20, color: c.textMuted),
          const SizedBox(width: 16),
          Expanded(
            child: Text('Dark mode',
                style: AppType.body(
                    size: 14, weight: FontWeight.w500, color: c.text)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: c.teal,
            activeTrackColor: c.tealSurface,
          ),
        ],
      ),
    );
  }
}

// ── Sign out button ──────────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: c.rose.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.rose.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 18, color: c.rose),
            const SizedBox(width: 10),
            Text('Sign out',
                style: AppType.body(
                    size: 14, weight: FontWeight.w600, color: c.rose)),
          ],
        ),
      ),
    );
  }
}
