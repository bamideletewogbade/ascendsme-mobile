import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';

/// Bottom sheet for editing a proforma quote before sending it as a real
/// invoice. Lets the user update the customer, amount, description, and
/// line items.
class EditProformaSheet extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback? onSaved;

  const EditProformaSheet({super.key, required this.invoice, this.onSaved});

  @override
  State<EditProformaSheet> createState() => _EditProformaSheetState();
}

class _EditProformaSheetState extends State<EditProformaSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _customerName;

  @override
  void initState() {
    super.initState();
    _customerName = TextEditingController(text: widget.invoice.customer);
    _amountCtrl =
        TextEditingController(text: widget.invoice.amount.toString());
    _descCtrl = TextEditingController(
      text: widget.invoice.lineItems.isNotEmpty
          ? widget.invoice.lineItems.first.description
          : '',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _customerName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final bizId = context.read<AppState>().business.id;
    final invId = widget.invoice.backendId;
    if (bizId == null || invId == null) return;

    final customer = _customerName.text.trim();
    final amount = num.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (customer.isEmpty || amount <= 0) return;

    try {
      await SupabaseService.updateInvoice(
        invoiceId: invId,
        customerName: customer,
        totalAmount: amount,
        description: _descCtrl.text.trim(),
      );
      if (!mounted) return;
      context.read<AppState>().loadInvoices();
      widget.onSaved?.call();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e',
              style: AppType.body(size: 13, color: Colors.white)),
          backgroundColor: context.colors.rose,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                        Icon(Icons.close, size: 20, color: c.text),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Edit proforma',
                        style: AppType.heading(size: 18, color: c.text)),
                  ),
                  AppBtn('Save',
                      variant: BtnVariant.secondary,
                      onTap: _save,
                      fontSize: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer name',
                      style: AppType.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: c.textMuted)),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _customerName,
                      style: AppType.body(size: 14, color: c.text),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Description',
                      style: AppType.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: c.textMuted)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _descCtrl,
                      style: AppType.body(size: 14, color: c.text),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14),
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Amount (GHS)',
                      style: AppType.body(
                          size: 11,
                          weight: FontWeight.w600,
                          color: c.textMuted)),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      style: AppType.body(size: 14, color: c.text),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.bgInset,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: c.textMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Changes are saved to the proforma. '
                            'Convert to invoice when ready.',
                            style:
                                AppType.body(size: 12, color: c.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppBtn('Save changes',
                      full: true,
                      icon: 'check',
                      onTap: _save),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
