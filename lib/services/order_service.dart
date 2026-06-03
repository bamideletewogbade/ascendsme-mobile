/// Shop Order Service — manages orders placed through the online storefront.
///
/// Reads from the shared `shop_orders` and `shop_order_items` tables (same
/// schema as the AscendSME web platform). Mobile scope: list orders, update
/// status (confirm, ship, deliver, cancel). Order creation flows through the
/// web platform's checkout; mobile reads + manages fulfillment.

import '../core/models.dart';
import 'app_logger.dart';
import 'supabase_service.dart';

class OrderService {
  /// Fetch the most recent orders for this business.
  static Future<List<ShopOrder>> fetchOrders({
    required String businessId,
    int limit = 50,
  }) async {
    log.debug('OrderService.fetchOrders — bizId=$businessId');
    final sw = Stopwatch()..start();
    final rows = await SupabaseService.fetchOrders(
      businessId: businessId,
      limit: limit,
    );
    final orders = rows.map(ShopOrder.fromRow).toList();
    log.info('OrderService.fetchOrders — ${orders.length} orders (${sw.elapsedMilliseconds}ms)');
    return orders;
  }

  /// Fetch orders grouped by status for the shop dashboard.
  static Future<Map<String, List<ShopOrder>>> fetchOrdersGrouped({
    required String businessId,
  }) async {
    final orders = await fetchOrders(businessId: businessId);
    final grouped = <String, List<ShopOrder>>{
      'pending': [],
      'confirmed': [],
      'processing': [],
      'shipped': [],
      'delivered': [],
      'cancelled': [],
    };
    for (final o in orders) {
      grouped.putIfAbsent(o.status, () => []).add(o);
    }
    return grouped;
  }

  /// Update order status and set the appropriate timestamp.
  static Future<void> updateStatus({
    required String orderId,
    required String status,
  }) async {
    log.info('OrderService.updateStatus — orderId=$orderId status=$status');
    await SupabaseService.updateOrderStatus(
      orderId: orderId,
      status: status,
    );
  }

  /// Get a human-readable label for the order status.
  static String statusLabel(String status) => switch (status) {
        'confirmed' => 'Confirmed',
        'processing' => 'Processing',
        'shipped' => 'Shipped',
        'delivered' => 'Delivered',
        'cancelled' => 'Cancelled',
        _ => 'Pending',
      };
}
