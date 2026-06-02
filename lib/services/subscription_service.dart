/// Subscription Service — wraps the `subscription_tiers` and `subscriptions`
/// tables (shared with web). Mobile scope: list available plans, get current
/// subscription, upgrade/downgrade, cancel.
///
/// Tables:
///   - `subscription_tiers`: id, tier_code, tier_name, price_monthly_ghs,
///     price_quarterly_ghs, price_yearly_ghs, description, features[]
///   - `subscriptions`: id, business_id, tier_id, status, current_period_end
///
/// All methods require supabaseConfigured to be true; callers should guard
/// with AppState.supabaseConfigured before routing here.

import '../core/models.dart';
import 'app_logger.dart';
import 'supabase_service.dart';

class SubscriptionService {
  /// Fetch all available subscription tiers.
  static Future<List<SubscriptionPlan>> fetchTiers() async {
    log.debug('SubscriptionService.fetchTiers');
    final sw = Stopwatch()..start();
    final rows = await SupabaseService.client
        .from('subscription_tiers')
        .select('*')
        .order('price_monthly_ghs', ascending: true);
    log.info('SubscriptionService.fetchTiers — ${rows.length} tiers (${sw.elapsedMilliseconds}ms)');
    return (rows as List).map((r) => SubscriptionPlan.fromRow(r as Map<String, dynamic>)).toList();
  }

  /// Get the current active subscription for this business. Returns null when
  /// the business has no active subscription (free tier or expired).
  static Future<SubscriptionInfo?> getCurrentSubscription({
    required String businessId,
  }) async {
    log.debug('SubscriptionService.getCurrentSubscription — bizId=$businessId');
    final sw = Stopwatch()..start();
    final row = await SupabaseService.client
        .from('subscriptions')
        .select('*, tier:subscription_tiers(*)')
        .eq('business_id', businessId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) {
      log.info('SubscriptionService.getCurrentSubscription — no active sub (${sw.elapsedMilliseconds}ms)');
      return null;
    }

    final sub = SubscriptionInfo.fromRow(Map<String, dynamic>.from(row));

    // Check if the subscription period has ended — if so, downgrade the business
    // to free and return null (the web handles this via a background job, but
    // mobile enforces it inline for correctness).
    if (sub.currentPeriodEnd != null && sub.currentPeriodEnd!.isBefore(DateTime.now())) {
      log.info('SubscriptionService.getCurrentSubscription — period ended, downgrading to free');
      await SupabaseService.client
          .from('subscriptions')
          .update({'status': 'expired', 'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', sub.id);
      await SupabaseService.client
          .from('businesses')
          .update({'subscription_tier': 'free', 'subscription_id': null})
          .eq('id', businessId);
      return null;
    }

    log.info('SubscriptionService.getCurrentSubscription — found tier=${sub.tierCode} (${sw.elapsedMilliseconds}ms)');
    return sub;
  }

  /// Create a new subscription for this business. Used for upgrades and new
  /// subscriptions. Returns the created subscription info.
  static Future<SubscriptionInfo> createSubscription({
    required String businessId,
    required String tierId,
    required BillingPeriod billingPeriod,
  }) async {
    log.info('SubscriptionService.createSubscription — bizId=$businessId tierId=$tierId period=$billingPeriod');
    final sw = Stopwatch()..start();

    // Calculate period end based on billing period
    final now = DateTime.now();
    final periodEnd = switch (billingPeriod) {
      BillingPeriod.yearly => DateTime(now.year + 1, now.month, now.day),
      BillingPeriod.quarterly => DateTime(now.year, now.month + 3, now.day),
      BillingPeriod.monthly => DateTime(now.year, now.month + 1, now.day),
    };

    final row = await SupabaseService.client
        .from('subscriptions')
        .insert({
          'business_id': businessId,
          'tier_id': tierId,
          'status': 'active',
          'current_period_start': now.toUtc().toIso8601String(),
          'current_period_end': periodEnd.toUtc().toIso8601String(),
        })
        .select('*, tier:subscription_tiers(*)')
        .single();

    // Update the business record with the new tier
    final tierCode = (row['tier'] as Map<String, dynamic>)['tier_code'] as String;
    await SupabaseService.client
        .from('businesses')
        .update({
          'subscription_tier': tierCode,
          'subscription_id': row['id'],
        })
        .eq('id', businessId);

    log.info('SubscriptionService.createSubscription — done id=${row['id']} tier=$tierCode (${sw.elapsedMilliseconds}ms)');
    return SubscriptionInfo.fromRow(Map<String, dynamic>.from(row));
  }

  /// Cancel the subscription at period end. Returns the updated subscription.
  static Future<void> cancelSubscription({
    required String subscriptionId,
  }) async {
    log.info('SubscriptionService.cancelSubscription — subId=$subscriptionId');
    await SupabaseService.client
        .from('subscriptions')
        .update({
          'cancel_at_period_end': true,
          'cancelled_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', subscriptionId);
    log.info('SubscriptionService.cancelSubscription — done');
  }
}
