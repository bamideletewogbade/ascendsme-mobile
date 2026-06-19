import 'package:flutter/material.dart';
import 'new_invoice_sheet.dart';

/// Dedicated bottom sheet for creating a proforma quote.
///
/// This is a thin wrapper around [NewInvoiceSheet] that forces the
/// proforma-only mode so the proforma toggle is hidden and all labels
/// say "proforma" instead of "invoice".
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => const CreateProformaSheet(),
/// );
/// ```
class CreateProformaSheet extends StatelessWidget {
  final VoidCallback? onSent;

  const CreateProformaSheet({super.key, this.onSent});

  @override
  Widget build(BuildContext context) {
    return NewInvoiceSheet(
      onSent: onSent,
      isProformaOnly: true,
    );
  }
}
