import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/crm_service.dart';
import '../../services/app_logger.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';

/// Bottom sheet for bulk importing customers into the CRM.
///
/// Accepts tab/comma-separated rows with format:
///   Full Name, Phone, Email
///
/// Each row creates a customer via [SupabaseService.createCustomer] and
/// a CRM profile via [CrmService.getOrCreateCrmProfile].
class BulkImportCustomersSheet extends StatefulWidget {
  const BulkImportCustomersSheet({super.key});

  @override
  State<BulkImportCustomersSheet> createState() =>
      _BulkImportCustomersSheetState();
}

class _BulkImportCustomersSheetState extends State<BulkImportCustomersSheet> {
  final _dataCtrl = TextEditingController();
  bool _importing = false;
  bool _done = false;
  int _errorCount = 0;
  String? _summary;

  @override
  void dispose() {
    _dataCtrl.dispose();
    super.dispose();
  }

  List<List<String>> _parseRows(String raw) {
    final lines =
        raw.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
    return lines.map((line) {
      if (line.contains('\t')) {
        return line.split('\t').map((c) => c.trim()).toList();
      }
      return line.split(',').map((c) => c.trim()).toList();
    }).toList();
  }

  Future<void> _import() async {
    final appState = context.read<AppState>();
    final bizId = appState.business.id;
    if (bizId == null) return;

    setState(() {
      _importing = true;
      _errorCount = 0;
      _summary = null;
    });

    final rows = _parseRows(_dataCtrl.text);
    if (rows.isEmpty) {
      setState(() {
        _importing = false;
        _summary = 'No data rows found.';
      });
      return;
    }

    var success = 0;
    var errors = 0;

    for (var i = 0; i < rows.length; i++) {
      final cols = rows[i];
      if (cols.isEmpty || cols[0].isEmpty) {
        errors++;
        continue;
      }

      final name = cols[0];
      final phone = cols.length > 1 ? cols[1] : null;
      final email = cols.length > 2 && cols[2].isNotEmpty ? cols[2] : null;

      try {
        await SupabaseService.createCustomer(
          businessId: bizId,
          fullName: name,
          phone: phone?.isNotEmpty == true ? phone : null,
          email: email?.isNotEmpty == true ? email : null,
        );
        await CrmService.getOrCreateCrmProfile(
          businessId: bizId,
          name: name,
          phone: phone?.isNotEmpty == true ? phone : null,
          email: email?.isNotEmpty == true ? email : null,
        );
        success++;
      } catch (e) {
        log.warning('BulkImportCustomers — row ${i + 1} failed: $e');
        errors++;
      }
    }

    if (!mounted) return;

    unawaited(appState.loadCustomers());

    setState(() {
      _importing = false;
      _done = true;
      _errorCount = errors;
      _summary = '$success customer${success == 1 ? '' : 's'} added'
          '${errors > 0 ? ', $errors failed' : ''}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: _done ? _buildDone(c) : _buildForm(c),
    );
  }

  Widget _buildForm(AppColorsX c) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Text('Bulk import customers',
                style: AppType.heading(size: 20, color: c.text)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Paste customer data below. Use one row per customer with '
              'columns separated by commas or tabs.',
              style: AppType.body(size: 13, color: c.textMuted),
            ),
          ),
          // Format hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.navySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.navyTint.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Format: Name, Phone, Email',
                      style: AppType.mono(size: 10, color: c.navy)),
                  const SizedBox(height: 6),
                  Text('Example:',
                      style: AppType.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: c.navy)),
                  Text('Ama Mensah, 0244123456, ama@example.com\nKofi Asante, 0544987654',
                      style: AppType.mono(size: 10, color: c.navyDeep)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Data input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Customer data',
                    style: AppType.body(
                        size: 11.5,
                        weight: FontWeight.w600,
                        color: c.textMuted)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: c.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: _dataCtrl,
                    maxLines: 8,
                    minLines: 5,
                    style: AppType.mono(size: 13, color: c.text),
                    decoration: InputDecoration(
                      hintText: 'Ama Mensah, 0244123456, ama@example.com\n...',
                      hintStyle:
                          AppType.body(size: 12, color: c.textFaint),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_summary != null && !_importing) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: c.rose.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.rose.withValues(alpha: 0.25)),
                ),
                child: Text(_summary!,
                    style: AppType.body(size: 13, color: c.rose)),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _importing
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(c.teal),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      AppBtn('Import customers',
                          full: true, onTap: _import),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text('Cancel',
                              style: AppType.body(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: c.textMuted)),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(AppColorsX c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _errorCount == 0 ? c.greenSurface : c.orangeSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _errorCount == 0 ? Icons.check : Icons.warning_amber_rounded,
              size: 32,
              color: _errorCount == 0 ? c.green : c.orange,
            ),
          ),
          const SizedBox(height: 16),
          Text('Import complete',
              style: AppType.heading(size: 22, color: c.text)),
          const SizedBox(height: 6),
          Text(_summary ?? '',
              textAlign: TextAlign.center,
              style: AppType.body(size: 13, color: c.textMuted)),
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
