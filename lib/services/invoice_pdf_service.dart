import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../core/models.dart';
import '../core/share_utils.dart';
import 'app_logger.dart';

/// Generates branded, GRA-compliant PDF invoice/receipt documents matching the
/// AscendSME web platform's design language exactly.
///
/// Key design decisions (mirroring web's invoicePdf.ts):
/// - Primary teal: #00A99D
/// - Rotated watermarks for PAID (-15°) and PROFORMA (-18°)
/// - VERIFIED BUSINESS badge for verified businesses
/// - Ghana tax inclusive levy breakdown table
/// - Payment methods liquidity block
/// - "Powered by AscendSME" footer
class InvoicePdfService {
  // ── Brand colors (web platform palette, cf. invoicePdf.ts) ──────────────
  static const _primary = PdfColor.fromInt(0xFF00A99D);
  static const _dark = PdfColor.fromInt(0xFF121212);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _faint = PdfColor.fromInt(0xFF9CA3AF);
  static const _white = PdfColor.fromInt(0xFFFFFFFF);
  static const _tableHeader = PdfColor.fromInt(0xFFF5F7FA);
  static const _paidStamp = PdfColor.fromInt(0xFFDCFCE7);
  static const _paidText = PdfColor.fromInt(0xFF16A34A);
  static const _proformaStamp = PdfColor.fromInt(0xFFF5F5F5);
  static const _verifiedBadge = PdfColor.fromInt(0xFF00A99D);
  static const _verifiedText = PdfColor.fromInt(0xFFFFFFFF);
  static const _levyBg = PdfColor.fromInt(0xFFF9FAFB);
  static const _levyBorder = PdfColor.fromInt(0xFFE5E7EB);
  static const _liquidityBg = PdfColor.fromInt(0xFFF8FAFC);

  static const _margin = 48.0;
  static final _pageWidth = PdfPageFormat.a4.width;
  static final _contentWidth = _pageWidth - 2 * _margin;
  static final _pageHeight = PdfPageFormat.a4.height;
  static final _contentHeight = _pageHeight - 2 * _margin;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Generate PDF bytes for direct sharing.
  static Future<List<int>> generatePdfBytes({
    required Invoice invoice,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
    String? logoUrl,
    bool verified = false,
  }) async {
    final doc = await _buildPdf(
      invoice: invoice,
      businessName: businessName,
      businessHandle: businessHandle,
      businessCity: businessCity,
      businessRegion: businessRegion,
      logoUrl: logoUrl,
      verified: verified,
    );
    return doc.save();
  }

  /// Preview the invoice PDF in the platform print dialog.
  static Future<void> previewInvoice({
    required Invoice invoice,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
    String? logoUrl,
    bool verified = false,
  }) async {
    final doc = await _buildPdf(
      invoice: invoice,
      businessName: businessName,
      businessHandle: businessHandle,
      businessCity: businessCity,
      businessRegion: businessRegion,
      logoUrl: logoUrl,
      verified: verified,
    );
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'Invoice_${invoice.id.replaceAll('/', '_')}',
    );
  }

  /// Share via system share sheet.
  static Future<void> shareInvoice({
    required Invoice invoice,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
    String? logoUrl,
    bool verified = false,
  }) async {
    final doc = await _buildPdf(
      invoice: invoice,
      businessName: businessName,
      businessHandle: businessHandle,
      businessCity: businessCity,
      businessRegion: businessRegion,
      logoUrl: logoUrl,
      verified: verified,
    );
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Invoice_${invoice.id.replaceAll('/', '_')}.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Invoice ${invoice.id} from $businessName',
    );
  }

  /// Preview the receipt PDF in the platform print dialog.
  static Future<void> previewReceipt({
    required Receipt receipt,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
    String? logoUrl,
    bool verified = false,
    List<InvoiceLineItem> lineItems = const [],
  }) async {
    final doc = await _buildReceiptPdf(
      receipt: receipt,
      businessName: businessName,
      businessHandle: businessHandle,
      businessCity: businessCity,
      businessRegion: businessRegion,
      logoUrl: logoUrl,
      verified: verified,
      lineItems: lineItems,
    );
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'Receipt_${(receipt.receiptNumber ?? receipt.id).replaceAll('/', '_')}',
    );
  }

  /// Share a receipt PDF via the system share sheet.
  static Future<void> shareReceipt({
    required Receipt receipt,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
    String? logoUrl,
    bool verified = false,
    List<InvoiceLineItem> lineItems = const [],
  }) async {
    final doc = await _buildReceiptPdf(
      receipt: receipt,
      businessName: businessName,
      businessHandle: businessHandle,
      businessCity: businessCity,
      businessRegion: businessRegion,
      logoUrl: logoUrl,
      verified: verified,
      lineItems: lineItems,
    );
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final receiptRef = receipt.receiptNumber ?? receipt.id;
    final file = File('${dir.path}/Receipt_${receiptRef.replaceAll('/', '_')}.pdf');
    await file.writeAsBytes(bytes);
    final total = _fmt(receipt.totalAmount);
    final msg = ShareUtils.receiptMessage(
      customer: receipt.clientName ?? 'Customer',
      amount: total,
      businessName: businessName,
      receiptNumber: receipt.receiptNumber,
    );
    await Share.shareXFiles(
      [XFile(file.path)],
      text: msg,
    );
  }

  /// Save PDF bytes to the app's documents directory.
  static Future<String?> savePdfToDocuments({
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(bytes);
      log.info('PDF saved to ${file.path}');
      return file.path;
    } catch (e, st) {
      log.error('savePdfToDocuments failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Download an invoice PDF to persistent storage.
  static Future<String?> downloadInvoice({
    required Invoice invoice,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
    String? logoUrl,
    bool verified = false,
  }) async {
    final doc = await _buildPdf(
      invoice: invoice,
      businessName: businessName,
      businessHandle: businessHandle,
      businessCity: businessCity,
      businessRegion: businessRegion,
      logoUrl: logoUrl,
      verified: verified,
    );
    final bytes = await doc.save();
    final fileName = 'Invoice_${invoice.id.replaceAll('/', '_')}.pdf';
    return savePdfToDocuments(bytes: bytes, fileName: fileName);
  }

  /// Download a receipt PDF to persistent storage.
  static Future<String?> downloadReceipt({
    required Receipt receipt,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
    String? logoUrl,
    bool verified = false,
    List<InvoiceLineItem> lineItems = const [],
  }) async {
    final doc = await _buildReceiptPdf(
      receipt: receipt,
      businessName: businessName,
      businessHandle: businessHandle,
      businessCity: businessCity,
      businessRegion: businessRegion,
      logoUrl: logoUrl,
      verified: verified,
      lineItems: lineItems,
    );
    final bytes = await doc.save();
    final receiptRef = receipt.receiptNumber ?? receipt.id;
    final fileName = 'Receipt_${receiptRef.replaceAll('/', '_')}.pdf';
    return savePdfToDocuments(bytes: bytes, fileName: fileName);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERNAL — Invoice PDF builder
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<pw.Document> _buildPdf({
    required Invoice invoice,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
    String? logoUrl,
    bool verified = false,
  }) async {
    final doc = pw.Document();
    final isProforma = invoice.isProforma;
    final isPaid = invoice.status == 'paid';
    final isOverdue = invoice.status == 'overdue';

    // Load logo
    pw.MemoryImage? logoImage;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        log.warning('InvoicePdf: failed to load logo from $logoUrl');
      }
    }

    final totalBeforeLevy = invoice.amount;
    const levyRate = 0.025;
    final levyAmount = (totalBeforeLevy * levyRate).round();
    final grandTotal = totalBeforeLevy;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_margin),
        header: (ctx) => _buildWatermark(isPaid, isProforma),
        build: (ctx) => [
          // ── Verified Business Badge ──
          if (verified) _buildVerifiedBadge(),

          // ── Letterhead ──
          _buildLetterhead(
            logoImage: logoImage,
            businessName: businessName,
            businessHandle: businessHandle,
            businessCity: businessCity,
            businessRegion: businessRegion,
            isProforma: isProforma,
            documentType: isProforma ? 'PROFORMA' : 'INVOICE',
            documentId: invoice.id,
            status: invoice.status,
            createdAt: invoice.createdAt,
            dueDate: invoice.dueDate,
            validUntil: invoice.validUntil,
          ),

          pw.SizedBox(height: 28),

          // ── Bill to ──
          _buildClientSection('BILL TO', invoice.customer, invoice.clientEmail),

          pw.SizedBox(height: 28),

          // ── Line items table ──
          _buildLineItemsTable(
            items: invoice.lineItems,
            totalBeforeLevy: totalBeforeLevy,
            levyAmount: levyAmount,
            grandTotal: grandTotal,
            isProforma: isProforma,
            defaultDescription: 'Invoice for ${invoice.customer}',
          ),

          pw.SizedBox(height: 24),

          // ── Tax/Levy Breakdown ──
          if (!isProforma) _buildLevyBreakdown(totalBeforeLevy, levyAmount, grandTotal),

          // ── Dates (already in letterhead header — kept here for proforma expiry clarity) ──
          pw.SizedBox(height: 12),
          _buildDatesRow(isProforma, invoice.validUntil, invoice.dueDate, invoice.createdAt),

          pw.SizedBox(height: 20),

          // ── Liquidity / Payment Methods ──
          _buildLiquidityBlock(isProforma),

          // ── Overdue warning ──
          if (isOverdue) ...[
            pw.SizedBox(height: 12),
            _buildOverdueBanner(invoice.dueDate),
          ],

          // ── Footer ──
          pw.SizedBox(height: 20),
          _buildFooter(isProforma, invoice.id),
        ],
      ),
    );
    return doc;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERNAL — Receipt PDF builder
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<pw.Document> _buildReceiptPdf({
    required Receipt receipt,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
    String? logoUrl,
    bool verified = false,
    List<InvoiceLineItem> lineItems = const [],
  }) async {
    final doc = pw.Document();

    pw.MemoryImage? logoImage;
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(logoUrl));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        log.warning('ReceiptPdf: failed to load logo from $logoUrl');
      }
    }

    final paidDateStr =
        '${receipt.paidDate.day}/${receipt.paidDate.month}/${receipt.paidDate.year}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_margin),
        header: (ctx) => _buildWatermark(true, false),
        build: (ctx) => [
          // ── Verified Business Badge ──
          if (verified) _buildVerifiedBadge(),

          // ── Letterhead ──
          _buildLetterhead(
            logoImage: logoImage,
            businessName: businessName,
            businessHandle: businessHandle,
            businessCity: businessCity,
            businessRegion: businessRegion,
            isProforma: false,
            documentType: 'RECEIPT',
            documentId: receipt.receiptNumber ?? receipt.id,
            status: 'paid',
            createdAt: receipt.paidDate,
          ),

          pw.SizedBox(height: 28),

          // ── Paid by ──
          _buildClientSection(
            'PAID BY',
            receipt.clientName ?? 'Walk-in customer',
            null,
          ),

          pw.SizedBox(height: 24),

          // ── Payment info card ──
          _buildPaymentInfoCard(receipt, paidDateStr),

          pw.SizedBox(height: 28),

          // ── Amount received ──
          pw.Text('AMOUNT RECEIVED',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _muted,
                  letterSpacing: 1)),
          pw.SizedBox(height: 4),
          pw.Text(
            _fmt(receipt.totalAmount),
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: _primary,
            ),
          ),

          pw.SizedBox(height: 16),

          // ── Type pill ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(
              color: _paidStamp,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(99)),
            ),
            child: pw.Text(
              receipt.isInvoicePayment ? 'Invoice Payment' : 'Direct Sale',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _paidText),
            ),
          ),

          // ── Line items ──
          if (lineItems.isNotEmpty) ...[
            pw.SizedBox(height: 28),
            _buildReceiptLineItemsTable(lineItems, receipt.totalAmount),
          ],

          // ── Footer ──
          pw.SizedBox(height: 32),
          _buildFooter(false, receipt.receiptNumber ?? receipt.id, isReceipt: true),
        ],
      ),
    );
    return doc;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPONENT BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Rotated watermark overlay — rendered on every page via MultiPage header.
  /// Shows "PAID" (light green, -15°) or "PROFORMA" (light gray, -18°).
  ///
  /// Uses [pw.SizedBox.shrink] as the Stack anchor so the header is zero-height
  /// and doesn't push build content to subsequent pages. Positioned children
  /// render at absolute coordinates since PDF stacks don't clip.
  static pw.Widget _buildWatermark(bool isPaid, bool isProforma) {
    if (!isPaid && !isProforma) return pw.SizedBox.shrink();

    final text = isPaid ? 'PAID' : 'PROFORMA';
    final angle = isPaid ? -15 : -18;
    final color = isPaid ? _paidStamp : _proformaStamp;
    final fontSize = isPaid ? 80.0 : 90.0;

    return pw.Stack(
      children: [
        // Zero-size anchor — header takes no space so build content flows normally.
        pw.SizedBox.shrink(),
        pw.Positioned(
          left: _contentWidth / 2 - (isPaid ? 100 : 160),
          top: _contentHeight / 2 - 60,
          child: pw.Transform.rotate(
            angle: angle * math.pi / 180,
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 🛡️ VERIFIED BUSINESS badge — teal rounded rect with white text.
  static pw.Widget _buildVerifiedBadge() {
    return pw.Align(
      alignment: pw.Alignment.topRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: pw.BoxDecoration(
          color: _verifiedBadge,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text('\u{1F6E1}\u{FE0F}',
                style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(width: 5),
            pw.Text(
              'VERIFIED BUSINESS',
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _verifiedText,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Letterhead: logo/business identity left, document type + ID + dates right.
  /// Matches the web platform's header layout — dates positioned top-right
  /// alongside the document number, not in a separate section below.
  static pw.Widget _buildLetterhead({
    required pw.MemoryImage? logoImage,
    required String businessName,
    required String businessHandle,
    String? businessCity,
    String? businessRegion,
    required bool isProforma,
    required String documentType,
    required String documentId,
    required String status,
    DateTime? createdAt,
    DateTime? dueDate,
    DateTime? validUntil,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── Left: Logo + Business info ──
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logoImage != null)
              pw.Image(logoImage, width: 64, height: 64)
            else
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: isProforma ? PdfColor.fromInt(0xFF1A2B48) : _primary,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  _initials(businessName),
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _white,
                  ),
                ),
              ),
            pw.SizedBox(height: 8),
            pw.Text(businessName,
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _dark)),
            pw.SizedBox(height: 2),
            pw.Text(businessHandle,
                style: pw.TextStyle(fontSize: 10, color: _muted)),
            if (businessCity != null &&
                businessRegion != null &&
                businessCity != '—')
              pw.SizedBox(height: 1),
            if (businessCity != null &&
                businessRegion != null &&
                businessCity != '—')
              pw.Text('$businessCity, $businessRegion',
                  style: pw.TextStyle(fontSize: 9.5, color: _muted)),
          ],
        ),

        pw.Spacer(),

        // ── Right: Document type + ID + dates ──
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              documentType,
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: isProforma ? PdfColor.fromInt(0xFF1A2B48) : _primary,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(documentId,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _dark)),
            pw.SizedBox(height: 6),
            _buildStatusPill(status),
            pw.SizedBox(height: 10),
            // Date row matching web's top-right positioning
            if (createdAt != null)
              _metaBlock('Date', _fmtDate(createdAt)),
            if (createdAt != null) pw.SizedBox(height: 4),
            if (isProforma && validUntil != null)
              _metaBlock('Valid until', _fmtDate(validUntil))
            else if (!isProforma && dueDate != null)
              _metaBlock('Due date', _fmtDate(dueDate)),
          ],
        ),
      ],
    );
  }

  /// Status pill badge (PAID / PENDING / OVERDUE / PROFORMA).
  static pw.Widget _buildStatusPill(String status) {
    final (PdfColor bg, String label) = switch (status) {
      'paid' => (_paidStamp, 'PAID'),
      'overdue' => (PdfColor.fromInt(0xFFFEF2F2), 'OVERDUE'),
      'proforma' => (PdfColor.fromInt(0xFFEBEFF5), 'PROFORMA'),
      _ => (_tableHeader, 'PENDING'),
    };
    final fg = switch (status) {
      'paid' => _paidText,
      'overdue' => PdfColor.fromInt(0xFFDC2626),
      'proforma' => PdfColor.fromInt(0xFF1A2B48),
      _ => _muted,
    };
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(99)),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: fg),
      ),
    );
  }

  /// Client information section.
  static pw.Widget _buildClientSection(
      String label, String name, String? email) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
                letterSpacing: 1)),
        pw.SizedBox(height: 6),
        pw.Text(name,
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold)),
        if (email != null) ...[
          pw.SizedBox(height: 2),
          pw.Text(email, style: pw.TextStyle(fontSize: 11, color: _muted)),
        ],
      ],
    );
  }

  /// Line items table with subtotal, levy (if not proforma), and total.
  /// Shows clear gap between item rows and the totals section.
  static pw.Widget _buildLineItemsTable({
    required List<InvoiceLineItem> items,
    required int totalBeforeLevy,
    required int levyAmount,
    required int grandTotal,
    required bool isProforma,
    required String defaultDescription,
  }) {
    final displayItems = items.isEmpty
        ? [InvoiceLineItem(description: defaultDescription, amount: totalBeforeLevy)]
        : items;

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // ── Header row ──
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: _tableHeader,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          children: [
            _cell('Description', bold: true, color: _muted, fontSize: 9),
            _cell('Qty',
                bold: true,
                color: _muted,
                fontSize: 9,
                align: pw.TextAlign.right),
            _cell('Price',
                bold: true,
                color: _muted,
                fontSize: 9,
                align: pw.TextAlign.right),
            _cell('Total',
                bold: true,
                color: _muted,
                fontSize: 9,
                align: pw.TextAlign.right),
          ],
        ),

        // ── Item rows ──
        ...displayItems.map((item) {
          return pw.TableRow(
            children: [
              _cell(item.description, color: _dark, fontSize: 10.5),
              _cell(
                item.quantity != null ? '${item.quantity!.round()}' : '1',
                color: _dark,
                fontSize: 10.5,
                align: pw.TextAlign.right,
              ),
              _cell(
                item.unitPrice != null
                    ? _fmt(item.unitPrice!)
                    : _fmt(item.amount),
                color: _dark,
                fontSize: 10.5,
                align: pw.TextAlign.right,
              ),
              _cell(
                _fmt(item.amount),
                color: _dark,
                fontSize: 10.5,
                align: pw.TextAlign.right,
                bold: true,
              ),
            ],
          );
        }),

        // ── Gap row (blank spacer between items and totals) ──
        pw.TableRow(
          children: [
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
          ],
        ),
        pw.TableRow(
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _levyBorder, width: 0.5),
            ),
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: _cell(''),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: _cell(''),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: _cell(''),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: _cell(''),
            ),
          ],
        ),

        // ── Subtotal ──
        pw.TableRow(
          children: [
            _cell(''),
            _cell(''),
            _cell(''),
            _cell(''),
          ],
        ),
        pw.TableRow(
          children: [
            _cell(''),
            _cell(''),
            _cell('Subtotal',
                color: _muted,
                fontSize: 10,
                align: pw.TextAlign.right),
            _cell(_fmt(totalBeforeLevy),
                color: _dark,
                fontSize: 11,
                align: pw.TextAlign.right,
                bold: true),
          ],
        ),

        // ── Levy row (only for non-proforma) ──
        if (!isProforma)
          pw.TableRow(
            children: [
              _cell(''),
              _cell(''),
              _cell('NHIL/GETFund (2.5% incl.)',
                  color: _muted,
                  fontSize: 9,
                  align: pw.TextAlign.right),
              _cell(_fmt(levyAmount),
                  color: _muted,
                  fontSize: 9,
                  align: pw.TextAlign.right),
            ],
          ),

        // ── Total row ──
        pw.TableRow(
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _dark, width: 0.5),
              bottom: pw.BorderSide(color: _dark, width: 1.5),
            ),
          ),
          children: [
            _cell(''),
            _cell(''),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Text('TOTAL',
                  textAlign: pw.TextAlign.right,
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _primary)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Text(
                _fmt(grandTotal),
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tax & Levy breakdown card (only for non-proforma invoices).
  static pw.Widget _buildLevyBreakdown(
      int totalBeforeLevy, int levyAmount, int grandTotal) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _levyBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _levyBorder, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('TAX & LEVY BREAKDOWN',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _muted,
                  letterSpacing: 0.8)),
          pw.SizedBox(height: 8),
          _levyRow('Net Supply', _fmt(totalBeforeLevy), _dark),
          _levyRow('NHIL (2.5%)', _fmt(levyAmount), _muted),
          _levyRow('GETFund (2.5%)', _fmt(levyAmount), _muted),
          pw.Divider(color: _levyBorder),
          _levyRow('Total Due', _fmt(grandTotal), _dark, bold: true),
          pw.SizedBox(height: 4),
          pw.Text(
            '* NHIL & GETFund are included in the total as prescribed by the Ghana Revenue Authority.',
            style: pw.TextStyle(fontSize: 7.5, color: _faint, fontStyle: pw.FontStyle.italic),
          ),
        ],
      ),
    );
  }

  /// A single row in the levy breakdown.
  static pw.Widget _levyRow(String label, String value, PdfColor color,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: color)),
          ),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  /// Dates row: valid until / due date + created date.
  static pw.Widget _buildDatesRow(
    bool isProforma,
    DateTime? validUntil,
    DateTime? dueDate,
    DateTime? createdAt,
  ) {
    return pw.Row(
      children: [
        if (isProforma && validUntil != null)
          _metaBlock('Valid until', _fmtDate(validUntil))
        else
          _metaBlock('Due date',
              dueDate != null ? _fmtDate(dueDate) : '—'),
        pw.SizedBox(width: 48),
        _metaBlock('Created',
            createdAt != null ? _fmtDate(createdAt) : '—'),
      ],
    );
  }

  /// Meta block (label + value).
  static pw.Widget _metaBlock(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label.toUpperCase(),
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
                letterSpacing: 0.5)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 11.5, color: _dark)),
      ],
    );
  }

  /// Payment methods / liquidity block (matching web's "PAYMENT DETAILS" block).
  static pw.Widget _buildLiquidityBlock(bool isProforma) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _liquidityBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _levyBorder, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('PAYMENT DETAILS',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _muted,
                  letterSpacing: 0.8)),
          pw.SizedBox(height: 8),
          pw.Text(
            isProforma
                ? 'This is a proforma quote. Payment is due upon conversion to a final invoice. Prices are valid for 14 days from the proforma date.'
                : 'Payment is due by the date specified above. Late payments may incur additional charges.',
            style: pw.TextStyle(fontSize: 9, color: _muted),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Accepted methods: Mobile Money (MTN, Vodafone, AirtelTigo), Bank Transfer, Cash.',
            style: pw.TextStyle(fontSize: 8.5, color: _faint),
          ),
        ],
      ),
    );
  }

  /// Overdue warning banner (red-tinted background).
  static pw.Widget _buildOverdueBanner(DateTime? dueDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFEF2F2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(
            color: PdfColor.fromInt(0xFFFECACA), width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Text('\u26A0\uFE0F',
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(width: 8),
          pw.Text(
            'OVERDUE — Payment was due on '
            '${dueDate != null ? _fmtDate(dueDate) : ''}. '
            'Please remit immediately to avoid further escalation.',
            style: pw.TextStyle(
                fontSize: 9, color: PdfColor.fromInt(0xFFDC2626)),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  /// Payment info card for receipts (payment method, date, receipt number).
  static pw.Widget _buildPaymentInfoCard(
      Receipt receipt, String paidDateStr) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _levyBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _levyBorder, width: 0.5),
      ),
      child: pw.Column(
        children: [
          _receiptInfoRow('Payment method', receipt.methodLabel),
          pw.SizedBox(height: 8),
          _receiptInfoRow('Date paid', paidDateStr),
          if (receipt.receiptNumber != null) ...[
            pw.SizedBox(height: 8),
            _receiptInfoRow('Receipt number', receipt.receiptNumber!),
          ],
          if (receipt.isInvoicePayment && receipt.invoiceId != null) ...[
            pw.SizedBox(height: 8),
            _receiptInfoRow('Invoice ref', receipt.invoiceId!),
          ],
        ],
      ),
    );
  }

  static pw.Widget _receiptInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(label,
              style: pw.TextStyle(fontSize: 11, color: _muted)),
        ),
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _dark)),
      ],
    );
  }

  /// Line items table for receipts — 4 columns (Description, Qty, Rate, Amount)
  /// matching the web platform's receipt PDF table exactly.
  static pw.Widget _buildReceiptLineItemsTable(
      List<InvoiceLineItem> items, num totalAmount) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('ITEMS',
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: _muted,
                letterSpacing: 1)),
        pw.SizedBox(height: 10),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.3),
          },
          children: [
            // ── Header ──
            pw.TableRow(
              decoration: pw.BoxDecoration(
                color: _tableHeader,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              children: [
                _cell('Description',
                    bold: true, color: _muted, fontSize: 9),
                _cell('Qty',
                    bold: true,
                    color: _muted,
                    fontSize: 9,
                    align: pw.TextAlign.right),
                _cell('Rate (GHS)',
                    bold: true,
                    color: _muted,
                    fontSize: 9,
                    align: pw.TextAlign.right),
                _cell('Amount (GHS)',
                    bold: true,
                    color: _muted,
                    fontSize: 9,
                    align: pw.TextAlign.right),
              ],
            ),
            // ── Items ──
            ...items.map((item) {
              return pw.TableRow(
                children: [
                  _cell(item.description,
                      color: _dark, fontSize: 10.5),
                  _cell(
                    item.quantity != null ? '${item.quantity!.round()}' : '1',
                    color: _dark,
                    fontSize: 10.5,
                    align: pw.TextAlign.right,
                  ),
                  _cell(
                    item.unitPrice != null
                        ? _fmt(item.unitPrice!)
                        : _fmt(item.amount),
                    color: _dark,
                    fontSize: 10.5,
                    align: pw.TextAlign.right,
                  ),
                  _cell(
                    _fmt(item.amount),
                    color: _dark,
                    fontSize: 10.5,
                    align: pw.TextAlign.right,
                    bold: true,
                  ),
                ],
              );
            }),
            // ── Gap ──
            pw.TableRow(
              children: [_cell(''), _cell(''), _cell(''), _cell('')],
            ),
            pw.TableRow(
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: _dark, width: 0.5),
                  bottom: pw.BorderSide(color: _dark, width: 1.5),
                ),
              ),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Text('TOTAL',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: _primary)),
                ),
                pw.Container(), // spacer
                pw.Container(), // spacer
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  child: pw.Text(
                    _fmt(totalAmount),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: _primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Footer with "Powered by AscendSME" and document reference.
  static pw.Widget _buildFooter(
    bool isProforma,
    String docId, {
    bool isReceipt = false,
  }) {
    return pw.Column(
      children: [
        pw.Divider(color: _faint),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Text(
              'Powered by AscendSME',
              style: pw.TextStyle(fontSize: 8, color: _faint),
            ),
            pw.Spacer(),
            pw.Text(
              isReceipt
                  ? 'Receipt #$docId'
                  : isProforma
                      ? 'Proforma $docId'
                      : 'Invoice $docId',
              style: pw.TextStyle(fontSize: 8, color: _faint),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    PdfColor? color,
    double fontSize = 11,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? _dark,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'AS';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  static String _fmt(num amount) {
    final s = amount.round().abs().toString();
    final formatted = s.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return 'GHS $formatted';
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
