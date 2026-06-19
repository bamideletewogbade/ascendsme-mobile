import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/app_logger.dart';

/// WhatsApp / share utility for AscendSME.
///
/// Wraps `share_plus` with user-friendly helpers. Since `share_plus` opens the
/// system share sheet with WhatsApp as an option on both Android and iOS, we
/// use it as our primary mechanism. A "Copy to clipboard" fallback covers the
/// case where the user wants to paste directly into WhatsApp.
class ShareUtils {
  ShareUtils._();

  /// Share a PDF file via the system share sheet (WhatsApp, email, etc.).
  static Future<void> sharePdf({
    required List<int> bytes,
    required String fileName,
    required String text,
    BuildContext? context,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
      );
    } catch (e, st) {
      log.error('ShareUtils.sharePdf failed', error: e, stackTrace: st);
      if (context != null && context.mounted) {
        _toast(context, 'Could not share. Try copying instead.');
      }
    }
  }

  /// Share plain text via the system share sheet (opens WhatsApp as option).
  static Future<void> shareText({
    required String text,
    BuildContext? context,
  }) async {
    try {
      await Share.share(text);
    } catch (e, st) {
      log.error('ShareUtils.shareText failed', error: e, stackTrace: st);
      if (context != null && context.mounted) {
        _toast(context, 'Could not share. Copied to clipboard instead.');
        await copyToClipboard(text, context: context);
      }
    }
  }

  /// Share text with a pre-built WhatsApp-optimised message. The share sheet
  /// shows WhatsApp as the first option on most devices.
  static Future<void> shareViaWhatsApp({
    required String message,
    BuildContext? context,
  }) async {
    await shareText(text: message, context: context);
  }

  /// Copy text to clipboard with a visual snackbar confirmation.
  /// Returns the copied text.
  static Future<String> copyToClipboard(
    String text, {
    BuildContext? context,
    String? label,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context != null && context.mounted) {
      _toast(context, label ?? 'Copied — paste into WhatsApp');
    }
    return text;
  }

  /// Build a shareable WhatsApp message for an invoice or quote.
  static String invoiceMessage({
    required String customer,
    required String invoiceId,
    required String amount,
    required String businessName,
    String? payLink,
    bool isOverdue = false,
    int? overdueDays,
  }) {
    final overdue = isOverdue ? ' (${overdueDays ?? 0} days overdue)' : '';
    if (payLink != null) {
      return 'Hi $customer, here\'s your invoice $invoiceId for $amount '
          'from $businessName$overdue.\n'
          'Pay securely here: $payLink';
    }
    return 'Hi $customer, your invoice $invoiceId for $amount '
        'from $businessName is ready$overdue.';
  }

  /// Build a WhatsApp message for a receipt.
  static String receiptMessage({
    required String customer,
    required String amount,
    required String businessName,
    String? receiptNumber,
  }) {
    final ref = receiptNumber != null ? ' (ref: $receiptNumber)' : '';
    return 'Hi $customer, we\'ve received your payment of $amount at '
        '$businessName$ref. Thank you!';
  }

  /// Build a WhatsApp message for an expense receipt.
  static String expenseReceiptMessage({
    required String description,
    required String amount,
    required String businessName,
  }) {
    return 'Expense recorded at $businessName: $description for $amount.';
  }

  /// Small inline toast for contextual feedback.
  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: const Color(0xFF009B9E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
