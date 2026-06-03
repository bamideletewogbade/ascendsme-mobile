/// Payment Service — handles subscription payments via Paystack.
///
/// Since the official `paystack_flutter_sdk` package is still in alpha,
/// this service wraps the payment flow with a clean abstraction. In mock
/// mode (default), it simulates successful payments for end-to-end testing.
/// When the Paystack SDK is properly configured, switch [useMock] to false
/// and implement the real [chargeWithPaystack] method.
///
/// Records completed transactions in the shared `payment_transactions` table.

import 'package:flutter/widgets.dart';
import 'app_logger.dart';
import 'supabase_service.dart';

/// Result returned after a completed payment flow.
class PaymentResult {
  final bool success;
  final String? reference;
  final String? errorMessage;

  const PaymentResult({
    required this.success,
    this.reference,
    this.errorMessage,
  });
}

class PaymentService {
  /// Set to false once the Paystack SDK is properly integrated.
  /// When true, all chargeCard/checkout calls mock a successful response.
  static bool useMock = true;

  /// Initialize the payment gateway.
  /// Currently a no-op in mock mode; will initialize the Paystack SDK once integrated.
  static Future<void> initialize() async {
    if (!useMock) {
      // TODO: Initialize Paystack SDK here when ready
      log.info('PaymentService.initialize — real SDK not yet wired');
    }
    log.info('PaymentService.initialize — mock mode=$useMock');
  }

  /// Charge a card via the payment gateway.
  ///
  /// In mock mode, returns a successful [PaymentResult] immediately so the
  /// subscription flow can be tested end-to-end. When [useMock] is false,
  /// this delegates to [chargeWithPaystack] (to be implemented).
  ///
  /// [context] is required by the Paystack SDK to present the checkout modal.
  static Future<PaymentResult> chargeCard({
    required BuildContext context,
    required String email,
    required int amountGhs,
    required String businessId,
    String? subscriptionId,
    String? metadata,
  }) async {
    log.info('PaymentService.chargeCard — email=$email amount=$amountGhs mock=$useMock');

    final reference = _generateReference(businessId);

    if (useMock) {
      log.warning('PaymentService.chargeCard — mock mode, simulating success');
      await _recordTransaction(
        businessId: businessId,
        subscriptionId: subscriptionId,
        amountGhs: amountGhs,
        reference: reference,
        metadata: metadata,
      );
      return PaymentResult(success: true, reference: reference);
    }

    return chargeWithPaystack(
      context: context,
      email: email,
      amountGhs: amountGhs,
      reference: reference,
      subscriptionId: subscriptionId,
      metadata: metadata,
    );
  }

  /// Real Paystack charge flow — implement when the SDK is integrated.
  /// This is extracted to keep the mock/real switch clean.
  static Future<PaymentResult> chargeWithPaystack({
    required BuildContext context,
    required String email,
    required int amountGhs,
    required String reference,
    String? subscriptionId,
    String? metadata,
  }) async {
    // TODO: Integrate paystack_flutter_sdk and call the real checkout here.
    // Example:
    //   final response = await PaystackSdk.instance.checkout(
    //     context: context,
    //     email: email,
    //     amount: amountGhs * 100, // pesewas
    //     reference: reference,
    //     currency: 'GHS',
    //   );
    log.info('PaymentService.chargeWithPaystack — not implemented, falling back to mock');
    await _recordTransaction(
      businessId: '', // TODO: pass businessId
      subscriptionId: subscriptionId,
      amountGhs: amountGhs,
      reference: reference,
      metadata: metadata,
    );
    return PaymentResult(success: true, reference: reference);
  }

  /// Checkout alias — same as [chargeCard] but with a friendlier name.
  static Future<PaymentResult> checkout({
    required BuildContext context,
    required String email,
    required int amountGhs,
    required String businessId,
    String? subscriptionId,
    String? metadata,
  }) {
    return chargeCard(
      context: context,
      email: email,
      amountGhs: amountGhs,
      businessId: businessId,
      subscriptionId: subscriptionId,
      metadata: metadata,
    );
  }

  /// Record a completed transaction in the payment_transactions table.
  static Future<void> _recordTransaction({
    required String businessId,
    String? subscriptionId,
    required int amountGhs,
    required String reference,
    String status = 'completed',
    String? metadata,
  }) async {
    try {
      await SupabaseService.createPaymentTransaction(
        businessId: businessId,
        subscriptionId: subscriptionId,
        amountGhs: amountGhs,
        provider: 'paystack',
        reference: reference,
        status: status,
        metadata: metadata,
      );
    } catch (e, st) {
      log.error('PaymentService._recordTransaction — failed', error: e, stackTrace: st);
    }
  }

  /// Generate a unique payment reference.
  static String _generateReference(String businessId) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final short = businessId.length > 8 ? businessId.substring(0, 8) : businessId;
    return 'ASC_${short}_$ts';
  }
}
