import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../core/models.dart';

/// Generates a branded PDF invoice for sharing via WhatsApp, email, or any
/// share sheet. Uses the [pdf] package for document generation and
/// [printing] for preview / platform Print API.
class InvoicePdfService {
  /// Preview the invoice PDF in the platform print dialog / preview.
  static Future<void> previewInvoice({
    required Invoice invoice,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
  }) async {
    final doc = await _buildPdf(
      invoice: invoice,
      businessName: businessName,
      businessHandle: businessHandle,
      businessCity: businessCity,
      businessRegion: businessRegion,
    );
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'Invoice_${invoice.id.replaceAll('/', '_')}',
    );
  }

  /// Share the invoice PDF via the system share sheet (WhatsApp, email, etc.).
  static Future<void> shareInvoice({
    required Invoice invoice,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
  }) async {
    final doc = await _buildPdf(
      invoice: invoice,
      businessName: businessName,
      businessHandle: businessHandle,
      businessCity: businessCity,
      businessRegion: businessRegion,
    );
    final bytes = await doc.save();

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/Invoice_${invoice.id.replaceAll('/', '_')}.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Invoice ${invoice.id} from $businessName',
    );
  }

  static Future<pw.Document> _buildPdf({
    required Invoice invoice,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
  }) async {
    final doc = pw.Document();
    final primary = PdfColor.fromInt(0xFF009B9E);
    final navy = PdfColor.fromInt(0xFF1A2B48);
    final dark = PdfColor.fromInt(0xFF121212);
    final muted = PdfColor.fromInt(0xFF6B7280);
    final faint = PdfColor.fromInt(0xFF9CA3AF);
    final white = PdfColor.fromInt(0xFFFFFFFF);

    final isProforma = invoice.isProforma;
    final docTypeLabel = isProforma ? 'PROFORMA QUOTE' : 'INVOICE';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) => [
          // ── Note: Proforma watermark banner ──
          if (isProforma)
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF3F4F6),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Row(
                children: [
                  pw.Text('📄', style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'This is a quote — not a final invoice. '
                    'Share with your client for review before converting.',
                    style: pw.TextStyle(fontSize: 9, color: muted),
                    maxLines: 2,
                  ),
                ],
              ),
            ),

          // ── Letterhead ──
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Business monogram + name
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: isProforma ? navy : primary,
                      borderRadius:
                          const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Text(
                      _initials(businessName),
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(businessName,
                      style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: dark)),
                  pw.SizedBox(height: 2),
                  pw.Text(businessHandle,
                      style: pw.TextStyle(fontSize: 10, color: muted)),
                  if (businessCity != null &&
                      businessRegion != null &&
                      businessCity != '—')
                    pw.Text('$businessCity, $businessRegion',
                        style: pw.TextStyle(fontSize: 10, color: muted)),
                ],
              ),
              pw.Spacer(),
              // Document number + type
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(docTypeLabel,
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: isProforma ? navy : primary)),
                  pw.SizedBox(height: 4),
                  pw.Text(invoice.id,
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: dark)),
                  pw.SizedBox(height: 4),
                  if (!isProforma)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: _statusColor(invoice.status, muted, faint),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(99)),
                      ),
                      child: pw.Text(
                        _statusLabel(invoice.status),
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: dark),
                      ),
                    ),
                  if (isProforma)
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFEBEFF5),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(99)),
                      ),
                      child: pw.Text(
                        'QUOTE',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: navy),
                      ),
                    ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 32),

          // ── Bill to ──
          pw.Text('BILL TO',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: muted,
                  letterSpacing: 1)),
          pw.SizedBox(height: 6),
          pw.Text(invoice.customer,
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          if (invoice.clientEmail != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(invoice.clientEmail!,
                style: pw.TextStyle(fontSize: 11, color: muted)),
          ],

          pw.SizedBox(height: 28),

          // ── Line items table ──
          pw.Table(
            border: pw.TableBorder(
              bottom: pw.BorderSide(color: faint, width: 0.5),
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.5),
            },
            children: [
              // Header row
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF9FAFB),
                ),
                children: [
                  _cell('Description', bold: true, color: muted, fontSize: 9),
                  _cell('Qty',
                      bold: true,
                      color: muted,
                      fontSize: 9,
                      align: pw.TextAlign.center),
                  _cell('Amount',
                      bold: true,
                      color: muted,
                      fontSize: 9,
                      align: pw.TextAlign.right),
                ],
              ),
              // Item rows
              ...invoice.lineItems.map((item) {
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: pw.Text(item.description,
                          style: pw.TextStyle(fontSize: 11, color: dark)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: pw.Text(
                          '${item.quantity?.round() ?? 1}',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 11, color: dark)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: pw.Text(
                        'GHS ${_formatAmount(item.amount)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(fontSize: 11, color: dark),
                      ),
                    ),
                  ],
                );
              }),
              // Total row
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Container(),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Container(),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(color: dark, width: 1),
                      ),
                    ),
                    child: pw.Text(
                      'GHS ${_formatAmount(invoice.amount)}',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: dark),
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // ── Meta info ──
          pw.Row(
            children: [
              if (isProforma && invoice.validUntil != null)
                _metaBlock('Valid until',
                    _formatDate(invoice.validUntil!), muted, dark)
              else
                _metaBlock('Due date',
                    invoice.dueDate != null
                        ? _formatDate(invoice.dueDate!)
                        : '—',
                    muted,
                    dark),
              pw.SizedBox(width: 48),
              _metaBlock(
                  'Created',
                  invoice.createdAt != null
                      ? _formatDate(invoice.createdAt!)
                      : '—',
                  muted,
                  dark),
            ],
          ),

          pw.SizedBox(height: 32),

          // ── Footer ──
          pw.Divider(color: faint),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text(
                'Powered by AscendSME',
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
              pw.Spacer(),
              pw.Text(
                isProforma ? 'Quote ${invoice.id}' : 'Invoice ${invoice.id}',
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
    return doc;
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    PdfColor? color,
    double fontSize = 11,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColor.fromInt(0xFF121212),
        ),
      ),
    );
  }

  static pw.Widget _metaBlock(
      String label, String value, PdfColor muted, PdfColor dark) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(),
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: muted,
                letterSpacing: 0.5)),
        pw.SizedBox(height: 4),
        pw.Text(value,
            style: pw.TextStyle(fontSize: 12, color: dark)),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'AS';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  static String _formatAmount(num amount) {
    final s = amount.round().abs().toString();
    return s.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static PdfColor _statusColor(
      String status, PdfColor muted, PdfColor faint) {
    return switch (status) {
      'paid' => PdfColor.fromInt(0xFFECFDF5),
      'overdue' => const PdfColor(1.0, 0.9, 0.9),
      _ => faint,
    };
  }

  static String _statusLabel(String status) => switch (status) {
        'paid' => 'PAID',
        'overdue' => 'OVERDUE',
        'pending' || 'sent' => 'PENDING',
        'proforma' => 'QUOTE',
        'void' => 'CANCELLED',
        _ => 'DRAFT',
      };
}
