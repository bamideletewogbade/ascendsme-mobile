/// Inventory Service — wraps the `user_products` table (shared with web).
/// Mobile scope: list products, add/edit product, adjust stock levels. No
/// reservations, no multi-location, no demand prediction.
///
/// Table: `user_products`
/// Columns used: id, business_id, name, sku, category, current_stock,
/// low_stock_threshold, unit_price, type ('GOODS' | 'SERVICE'), image_url.
///
/// All methods require supabaseConfigured to be true; callers should guard
/// with AppState.supabaseConfigured before routing here. For mock/dev mode
/// without Supabase keys, the calling screens should use fallback mock data.

import 'app_logger.dart';
import 'supabase_service.dart';

class InventoryService {
  /// Fetch all products for this business.
  static Future<List<Map<String, dynamic>>> fetchProducts({
    required String businessId,
  }) async {
    log.debug('InventoryService.fetchProducts — bizId=$businessId');
    final sw = Stopwatch()..start();
    final rows = await SupabaseService.fetchProducts(businessId: businessId);
    log.info(
        'InventoryService.fetchProducts — ${rows.length} products (${sw.elapsedMilliseconds}ms)');
    return rows;
  }

  /// Create a new product.
  static Future<Map<String, dynamic>> createProduct({
    required String businessId,
    required String name,
    String? sku,
    String? category,
    int currentStock = 0,
    int? lowStockThreshold,
    double? unitPrice,
    double? unitCost,
    String type = 'GOODS',
  }) async {
    log.info('InventoryService.createProduct — bizId=$businessId name="$name" type=$type');
    final sw = Stopwatch()..start();
    final row = await SupabaseService.createProduct(
      businessId: businessId,
      name: name,
      sku: sku,
      category: category,
      currentStock: currentStock,
      lowStockThreshold: lowStockThreshold,
      unitPrice: unitPrice,
      unitCost: unitCost,
      type: type,
    );
    log.info(
        'InventoryService.createProduct — done id=${row['id']} (${sw.elapsedMilliseconds}ms)');
    return row;
  }

  /// Update an existing product's fields.
  static Future<void> updateProduct({
    required String productId,
    required String businessId,
    String? name,
    String? sku,
    String? category,
    int? currentStock,
    int? lowStockThreshold,
    double? unitPrice,
    double? unitCost,
    String? type,
  }) async {
    log.info('InventoryService.updateProduct — id=$productId');
    await SupabaseService.updateProduct(
      productId: productId,
      businessId: businessId,
      name: name,
      sku: sku,
      category: category,
      currentStock: currentStock,
      lowStockThreshold: lowStockThreshold,
      unitPrice: unitPrice,
      unitCost: unitCost,
      type: type,
    );
    log.info('InventoryService.updateProduct — done');
  }

  /// Delete a product.
  static Future<void> deleteProduct({
    required String productId,
    required String businessId,
  }) async {
    log.info('InventoryService.deleteProduct — id=$productId');
    await SupabaseService.deleteProduct(
      productId: productId,
      businessId: businessId,
    );
    log.info('InventoryService.deleteProduct — done');
  }
}
