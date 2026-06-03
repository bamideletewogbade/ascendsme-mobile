import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/inventory_service.dart';
import '../../services/app_logger.dart';
import '../../state/app_state.dart';

/// Bottom sheet for bulk importing products into inventory.
///
/// Accepts tab/comma-separated rows with format:
///   Name, SKU, Category, Stock, Price, Low Stock Threshold
///
/// Each row creates a product via [InventoryService.createProduct].
class BulkImportSheet extends StatefulWidget {
  const BulkImportSheet({super.key});

  @override
  State<BulkImportSheet> createState() => _BulkImportSheetState();
}

class _BulkImportSheetState extends State<BulkImportSheet> {
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
    final lines = raw.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
    return lines.map((line) {
      // Support both tab and comma separation
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
      final sku = cols.length > 1 ? cols[1] : null;
      final category = cols.length > 2 ? cols[2] : 'General';
      final stock = cols.length > 3 ? int.tryParse(cols[3].replaceAll(',', '')) : 0;
      final price = cols.length > 4 ? double.tryParse(cols[4].replaceAll(',', '')) : null;
      final threshold = cols.length > 5 ? int.tryParse(cols[5].replaceAll(',', '')) : null;

      try {
        await InventoryService.createProduct(
          businessId: bizId,
          name: name,
          sku: sku,
          category: category,
          currentStock: stock ?? 0,
          lowStockThreshold: threshold,
          unitPrice: price,
        );
        success++;
      } catch (e) {
        log.warning('BulkImport — row ${i + 1} failed: $e');
        errors++;
      }
    }

    if (!mounted) return;

    unawaited(appState.loadInventory());

    setState(() {
      _importing = false;
      _done = true;
      _errorCount = errors;
      _summary = '$success product${success == 1 ? '' : 's'} added'
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
            child: Text('Bulk import products',
                style: AppType.heading(size: 20, color: c.text)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Paste product data below. Use one row per product with '
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
                  Text('Format: Name, SKU, Category, Stock, Price, Threshold',
                      style: AppType.mono(size: 10, color: c.navy)),
                  const SizedBox(height: 6),
                  Text('Example:', style: AppType.body(size: 11, weight: FontWeight.w600, color: c.navy)),
                  Text('Kente stole, KS-001, Fashion, 15, 240, 5\nAnkara fabric, AF-002, Fashion, 40, 180, 10',
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
                Text('Product data',
                    style: AppType.body(
                        size: 11.5, weight: FontWeight.w600, color: c.textMuted)),
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
                      hintText: 'Product name, SKU, Category, 0, 0.00, 0\n...',
                      hintStyle: AppType.body(size: 12, color: c.textFaint),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(c.teal),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      AppBtn('Import products',
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
            width: 64, height: 64,
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
