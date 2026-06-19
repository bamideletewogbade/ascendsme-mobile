import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';


/// A single line in a General Ledger report — one transaction row.
class GeneralLedgerLine {
  final String dateLabel;
  final String account;
  final String description;
  final String reference;
  final double debit;
  final double credit;

  const GeneralLedgerLine({
    required this.dateLabel,
    required this.account,
    required this.description,
    this.reference = '',
    this.debit = 0,
    this.credit = 0,
  });
}

/// A single cash flow line item for the Cash Flow Statement.
class CashFlowLine {
  final String label;
  final double amount;
  final String description;

  const CashFlowLine({
    required this.label,
    required this.amount,
    this.description = '',
  });
}

/// Section of the cash flow statement (operating, investing, financing).
class CashFlowSection {
  final String title;
  final List<CashFlowLine> items;
  final double total;

  const CashFlowSection({
    required this.title,
    required this.items,
    required this.total,
  });
}

/// Generates branded PDF financial reports for AscendSME businesses.
///
/// Uses the same pdf/printing packages as [InvoicePdfService] but for
/// aggregated reports (P&L Statement, General Ledger, Cash Flow Statement)
/// rather than individual invoices.
class FinancialReportService {
  /// Generate and preview a P&L Statement PDF.
  static Future<void> previewPnL({
    required String businessName,
    required String periodLabel,
    required double revenue,
    required double expenses,
    required List<MapEntry<String, double>> expenseBreakdown,
    required List<MapEntry<String, double>> incomeBreakdown,
    required String logoUrl,
    String? businessCity,
    String? businessRegion,
  }) async {
    final doc = await _buildPnL(
      businessName: businessName,
      periodLabel: periodLabel,
      revenue: revenue,
      expenses: expenses,
      expenseBreakdown: expenseBreakdown,
      incomeBreakdown: incomeBreakdown,
    );
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'PnL_Statement_$periodLabel',
    );
  }

  /// Share a P&L Statement PDF via the share sheet (WhatsApp, email, etc.).
  static Future<void> sharePnL({
    required String businessName,
    required String periodLabel,
    required double revenue,
    required double expenses,
    required List<MapEntry<String, double>> expenseBreakdown,
    required List<MapEntry<String, double>> incomeBreakdown,
    String? logoUrl,
  }) async {
    final doc = await _buildPnL(
      businessName: businessName,
      periodLabel: periodLabel,
      revenue: revenue,
      expenses: expenses,
      expenseBreakdown: expenseBreakdown,
      incomeBreakdown: incomeBreakdown,
    );
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/PnL_$periodLabel.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'P&L Statement for $businessName — $periodLabel',
    );
  }

  /// Build the PDF document for a P&L statement.
  static Future<pw.Document> _buildPnL({
    required String businessName,
    required String periodLabel,
    required double revenue,
    required double expenses,
    required List<MapEntry<String, double>> expenseBreakdown,
    required List<MapEntry<String, double>> incomeBreakdown,
  }) async {
    final doc = pw.Document();
    final navy = PdfColor.fromInt(0xFF1A2B48);
    final dark = PdfColor.fromInt(0xFF121212);
    final muted = PdfColor.fromInt(0xFF6B7280);
    final faint = PdfColor.fromInt(0xFF9CA3AF);
    final white = PdfColor.fromInt(0xFFFFFFFF);
    final green = PdfColor.fromInt(0xFF16A34A);
    final rose = PdfColor.fromInt(0xFFDC2626);

    final netIncome = revenue - expenses;
    final margin = revenue > 0 ? (netIncome / revenue * 100) : 0.0;
    final cogs = expenseBreakdown
        .where((e) => e.key == 'cogs')
        .fold<double>(0.0, (s, e) => s + e.value);
    final totalExpenses = expenseBreakdown.fold(0.0, (s, e) => s + e.value);
    final totalIncome = incomeBreakdown.fold(0.0, (s, e) => s + e.value);
    final grossProfit = revenue - cogs;
    final opex = expenseBreakdown.where((e) => e.key != 'cogs').toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) => <pw.Widget>[
          // ── Header ──
          _header(businessName, periodLabel, navy, white),
          // ── Summary row ──
          _summaryRow(revenue, totalExpenses, netIncome, green, rose),
          pw.SizedBox(height: 24),
          // ── Margin bar ──
          _marginBar(margin, green, rose, muted),
          pw.SizedBox(height: 24),
          // ── Income section ──
          pw.Text('INCOME',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: muted,
                  letterSpacing: 1)),
          pw.SizedBox(height: 8),
          _ledgerTable(
            headerText: 'Source',
            entries: incomeBreakdown,
            total: totalIncome,
            dark: dark,
            muted: muted,
            faint: faint,
            greenColor: green,
          ),
          pw.SizedBox(height: 24),
          // ── Cost of Goods Sold ──
          ..._cogsSection(cogs, grossProfit, green, rose, dark, muted, faint),
          // ── Operating Expenses ──
          ..._opexSection(opex, totalExpenses, cogs, rose, dark, muted, faint),
          // ── Net Income ──
          _pnlDivider(faint),
          pw.SizedBox(height: 8),
          _pnlRow('NET INCOME', _fmt(netIncome),
              netIncome >= 0 ? green : rose, dark,
              bold: true, size: 16),
          pw.SizedBox(height: 4),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(1)}% margin',
              style: pw.TextStyle(fontSize: 10, color: muted),
            ),
          ),
          // ── Footer ──
          pw.SizedBox(height: 32),
          pw.Divider(color: faint),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated by AscendSME · $businessName · $periodLabel',
            style: pw.TextStyle(fontSize: 8, color: faint),
          ),
        ],
      ),
    );
    return doc;
  }

  static List<pw.Widget> _cogsSection(double cogs, double grossProfit,
      PdfColor green, PdfColor rose, PdfColor dark, PdfColor muted, PdfColor faint) {
    if (cogs <= 0) return [];
    return [
      _sectionLabel('COST OF GOODS SOLD', muted),
      pw.SizedBox(height: 8),
      _pnlRow('Cost of Goods Sold', _fmt(cogs), dark, muted),
      pw.SizedBox(height: 4),
      _pnlDivider(faint),
      _pnlRow('Gross Profit', _fmt(grossProfit),
          grossProfit >= 0 ? green : rose, dark, bold: true),
      pw.SizedBox(height: 20),
    ];
  }

  static List<pw.Widget> _opexSection(List<MapEntry<String, double>> opex,
      double totalExpenses, double cogs, PdfColor rose,
      PdfColor dark, PdfColor muted, PdfColor faint) {
    if (opex.isEmpty) return [];
    return [
      _sectionLabel('OPERATING EXPENSES', muted),
      pw.SizedBox(height: 8),
      _ledgerTable(
        headerText: 'Category',
        entries: opex,
        total: totalExpenses - cogs,
        dark: dark,
        muted: muted,
        faint: faint,
        greenColor: rose,
        isExpense: true,
      ),
      pw.SizedBox(height: 20),
    ];
  }

  static pw.Widget _header(String businessName, String periodLabel,
      PdfColor navy, PdfColor white) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: navy,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Row(
        children: [
          pw.Text('\u{1F1EC}\u{1F1ED}',
              style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PROFIT & LOSS STATEMENT',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: white,
                    letterSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  periodLabel,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromInt(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(businessName,
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: white)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(double revenue, double totalExpenses,
      double netIncome, PdfColor green, PdfColor rose) {
    return pw.Row(
      children: [
        _statBox('Total Revenue', _fmt(revenue), green),
        pw.SizedBox(width: 8),
        _statBox('Total Expenses', _fmt(totalExpenses), rose),
        pw.SizedBox(width: 8),
        _statBox('Net Income', _fmt(netIncome),
            netIncome >= 0 ? green : rose),
      ],
    );
  }

  static pw.Widget _marginBar(
      double margin, PdfColor green, PdfColor rose, PdfColor muted) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF9FAFB),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(
            color: PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Text('Profit Margin: ',
              style: pw.TextStyle(fontSize: 10, color: muted)),
          pw.Text(
            '${margin >= 0 ? '+' : ''}${margin.toStringAsFixed(1)}%',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: margin >= 0 ? green : rose,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _statBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFF9FAFB),
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(
              color: PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 8, color: PdfColor.fromInt(0xFF6B7280))),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _ledgerTable({
    required String headerText,
    required List<MapEntry<String, double>> entries,
    required double total,
    required PdfColor dark,
    required PdfColor muted,
    required PdfColor faint,
    required PdfColor greenColor,
    bool isExpense = false,
  }) {
    final sorted = List<MapEntry<String, double>>.from(entries)
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Table(
      border: pw.TableBorder(
        bottom: pw.BorderSide(color: faint, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF9FAFB),
          ),
          children: [
            _cell(headerText, bold: true, color: muted, fontSize: 9),
            _cell('%', bold: true, color: muted, fontSize: 9,
                align: pw.TextAlign.center),
            _cell('Amount', bold: true, color: muted, fontSize: 9,
                align: pw.TextAlign.right),
          ],
        ),
        ...sorted.map((e) {
          final pct = total > 0 ? (e.value / total * 100) : 0.0;
          return pw.TableRow(
            children: [
              _cell(e.key, color: dark, fontSize: 10.5),
              _cell('${pct.round()}%',
                  align: pw.TextAlign.center,
                  color: muted, fontSize: 10),
              _cell(_fmt(e.value),
                  align: pw.TextAlign.right,
                  color: isExpense ? PdfColor.fromInt(0xFFDC2626) : greenColor,
                  fontSize: 10.5,
                  bold: true),
            ],
          );
        }),
        pw.TableRow(
          children: [
            _cell('', color: dark),
            _cell('', color: dark),
            _cell(_fmt(total),
                align: pw.TextAlign.right,
                color: dark, fontSize: 11, bold: true),
          ],
        ),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    bool bold = false,
    PdfColor? color,
    double fontSize = 11,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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

  static pw.Widget _sectionLabel(String text, PdfColor muted) {
    return pw.Text(text,
        style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: muted,
            letterSpacing: 1));
  }

  static pw.Widget _pnlRow(String label, String value, PdfColor valueColor,
      PdfColor labelColor,
      {bool bold = false, double size = 13}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: size - 1,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: labelColor)),
          ),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: size,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: valueColor)),
        ],
      ),
    );
  }

  static pw.Widget _pnlDivider(PdfColor faint) {
    return pw.Divider(color: faint, height: 1);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // General Ledger
  // ═══════════════════════════════════════════════════════════════════════

  /// Preview a General Ledger PDF.
  static Future<void> previewLedger({
    required String businessName,
    required String periodLabel,
    required List<GeneralLedgerLine> entries,
  }) async {
    final doc = await _buildLedger(
      businessName: businessName,
      periodLabel: periodLabel,
      entries: entries,
    );
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'GeneralLedger_$periodLabel',
    );
  }

  /// Share a General Ledger PDF via the share sheet.
  static Future<void> shareLedger({
    required String businessName,
    required String periodLabel,
    required List<GeneralLedgerLine> entries,
  }) async {
    final doc = await _buildLedger(
      businessName: businessName,
      periodLabel: periodLabel,
      entries: entries,
    );
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/GeneralLedger_$periodLabel.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'General Ledger for $businessName — $periodLabel',
    );
  }

  /// Build the PDF document for a General Ledger.
  static Future<pw.Document> _buildLedger({
    required String businessName,
    required String periodLabel,
    required List<GeneralLedgerLine> entries,
  }) async {
    final doc = pw.Document();
    final navy = PdfColor.fromInt(0xFF1A2B48);
    final dark = PdfColor.fromInt(0xFF121212);
    final muted = PdfColor.fromInt(0xFF6B7280);
    final faint = PdfColor.fromInt(0xFF9CA3AF);
    final white = PdfColor.fromInt(0xFFFFFFFF);
    final green = PdfColor.fromInt(0xFF16A34A);
    final rose = PdfColor.fromInt(0xFFDC2626);

    final totalDebits =
        entries.fold<double>(0.0, (s, e) => s + e.debit);
    final totalCredits =
        entries.fold<double>(0.0, (s, e) => s + e.credit);

    // Limit to first 500 rows to avoid massive PDFs
    final displayEntries = entries.length > 500
        ? entries.sublist(0, 500)
        : entries;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) => <pw.Widget>[
          // ── Header ──
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: navy,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              children: [
                pw.Text('\u{1F1EC}\u{1F1ED}',
                    style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'GENERAL LEDGER',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        periodLabel,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromInt(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(businessName,
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: white)),
                  ],
                ),
              ],
            ),
          ),

          // ── Summary strip ──
          pw.Row(
            children: [
              _statBox('Total Debits', _fmt(totalDebits), rose),
              pw.SizedBox(width: 8),
              _statBox('Total Credits', _fmt(totalCredits), green),
              pw.SizedBox(width: 8),
              _statBox('Entries', '${entries.length}', dark),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Table header ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF9FAFB),
              borderRadius:
                  pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                    flex: 2,
                    child: _cell('Date',
                        bold: true, color: muted, fontSize: 9)),
                pw.Expanded(
                    flex: 3,
                    child: _cell('Account',
                        bold: true, color: muted, fontSize: 9)),
                pw.Expanded(
                    flex: 2,
                    child: _cell('Description',
                        bold: true, color: muted, fontSize: 9)),
                pw.Expanded(
                    flex: 1,
                    child: _cell('Debit',
                        bold: true,
                        color: muted,
                        fontSize: 9,
                        align: pw.TextAlign.right)),
                pw.Expanded(
                    flex: 1,
                    child: _cell('Credit',
                        bold: true,
                        color: muted,
                        fontSize: 9,
                        align: pw.TextAlign.right)),
              ],
            ),
          ),

          // ── Table rows ──
          ...displayEntries.map((e) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(
                        color: faint, width: 0.3),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text(e.dateLabel,
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: muted))),
                    pw.Expanded(
                        flex: 3,
                        child: pw.Text(e.account,
                            style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: dark))),
                    pw.Expanded(
                        flex: 2,
                        child: pw.Text(e.description,
                            style: pw.TextStyle(
                                fontSize: 7.5, color: muted))),
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          e.debit > 0
                              ? _fmt(e.debit)
                              : '',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color:
                                e.debit > 0 ? rose : faint,
                          ),
                          textAlign: pw.TextAlign.right,
                        )),
                    pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          e.credit > 0
                              ? _fmt(e.credit)
                              : '',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color:
                                e.credit > 0 ? green : faint,
                          ),
                          textAlign: pw.TextAlign.right,
                        )),
                  ],
                ),
              )),

          // ── Truncation note ──
          if (entries.length > 500)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                'Showing first 500 of ${entries.length} entries',
                style: pw.TextStyle(fontSize: 9, color: muted),
              ),
            ),

          // ── Totals footer ──
          pw.SizedBox(height: 12),
          pw.Divider(color: dark, thickness: 1),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Spacer(),
              pw.Text('Total Debits: ',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: dark)),
              pw.Text(_fmt(totalDebits),
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: rose)),
              pw.SizedBox(width: 20),
              pw.Text('Total Credits: ',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: dark)),
              pw.Text(_fmt(totalCredits),
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: green)),
            ],
          ),

          // ── Footer ──
          pw.SizedBox(height: 32),
          pw.Divider(color: faint),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated by AscendSME · $businessName · $periodLabel',
            style: pw.TextStyle(fontSize: 8, color: faint),
          ),
        ],
      ),
    );
    return doc;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // Cash Flow Statement
  // ═══════════════════════════════════════════════════════════════════════

  /// Preview a Cash Flow Statement PDF.
  static Future<void> previewCashFlow({
    required String businessName,
    required String periodLabel,
    required List<CashFlowSection> sections,
    required double netCashFlow,
    required double openingCash,
    required double closingCash,
  }) async {
    final doc = await _buildCashFlow(
      businessName: businessName,
      periodLabel: periodLabel,
      sections: sections,
      netCashFlow: netCashFlow,
      openingCash: openingCash,
      closingCash: closingCash,
    );
    await Printing.layoutPdf(
      onLayout: (_) => doc.save(),
      name: 'CashFlowStatement_$periodLabel',
    );
  }

  /// Share a Cash Flow Statement PDF via the share sheet (WhatsApp, email).
  static Future<void> shareCashFlow({
    required String businessName,
    required String periodLabel,
    required List<CashFlowSection> sections,
    required double netCashFlow,
    required double openingCash,
    required double closingCash,
  }) async {
    final doc = await _buildCashFlow(
      businessName: businessName,
      periodLabel: periodLabel,
      sections: sections,
      netCashFlow: netCashFlow,
      openingCash: openingCash,
      closingCash: closingCash,
    );
    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/CashFlowStatement_$periodLabel.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Cash Flow Statement for $businessName — $periodLabel',
    );
  }

  /// Build the PDF document for a Cash Flow Statement.
  static Future<pw.Document> _buildCashFlow({
    required String businessName,
    required String periodLabel,
    required List<CashFlowSection> sections,
    required double netCashFlow,
    required double openingCash,
    required double closingCash,
  }) async {
    final doc = pw.Document();
    final navy = PdfColor.fromInt(0xFF1A2B48);
    final dark = PdfColor.fromInt(0xFF121212);
    final muted = PdfColor.fromInt(0xFF6B7280);
    final faint = PdfColor.fromInt(0xFF9CA3AF);
    final white = PdfColor.fromInt(0xFFFFFFFF);
    final green = PdfColor.fromInt(0xFF16A34A);
    final rose = PdfColor.fromInt(0xFFDC2626);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) => <pw.Widget>[
          // ── Header ──
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: navy,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Row(
              children: [
                pw.Text('\u{1F1EC}\u{1F1ED}',
                    style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CASH FLOW STATEMENT',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        periodLabel,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromInt(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(businessName,
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: white)),
                  ],
                ),
              ],
            ),
          ),

          // ── Opening / Closing cash summary ──
          pw.Row(
            children: [
              _statBox('Opening Cash', _fmt(openingCash), dark),
              pw.SizedBox(width: 8),
              _statBox('Closing Cash', _fmt(closingCash),
                  closingCash >= 0 ? green : rose),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Sections ──
          for (final section in sections) ...[
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF9FAFB),
                borderRadius:
                    pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(section.title.toUpperCase(),
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: muted,
                            letterSpacing: 1)),
                  ),
                  pw.Text(_fmt(section.total),
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: section.total >= 0 ? green : rose)),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            for (final item in section.items) ...[
              pw.Padding(
                padding:
                    const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 8),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(item.label,
                          style: pw.TextStyle(
                              fontSize: 10, color: dark)),
                    ),
                    pw.Text(
                      item.amount >= 0
                          ? _fmt(item.amount)
                          : _fmt(item.amount),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color:
                            item.amount >= 0 ? green : rose,
                      ),
                    ),
                  ],
                ),
              ),
              if (item.description.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(
                      left: 12, bottom: 3),
                  child: pw.Text(item.description,
                      style: pw.TextStyle(
                          fontSize: 7.5, color: muted)),
                ),
            ],
            pw.SizedBox(height: 12),
          ],

          // ── Net Cash Flow ──
          pw.Divider(color: dark, thickness: 1),
          pw.SizedBox(height: 6),
          _pnlRow('NET CASH FLOW', _fmt(netCashFlow),
              netCashFlow >= 0 ? green : rose, dark,
              bold: true, size: 16),

          // ── Footer ──
          pw.SizedBox(height: 32),
          pw.Divider(color: faint),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated by AscendSME · $businessName · $periodLabel',
            style: pw.TextStyle(fontSize: 8, color: faint),
          ),
        ],
      ),
    );
    return doc;
  }

  static String _fmt(double amount) {
    final s = amount.abs().round().toString();
    final formatted = s.replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    return 'GHS ${amount < 0 ? '\u2212' : ''}$formatted';
  }
}
