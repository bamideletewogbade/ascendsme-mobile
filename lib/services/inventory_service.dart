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
    final rows = await SupabaseService.client
        .from('user_products')
        .select('*')
        .eq('business_id', businessId)
        .order('created_at', ascending: false);
    log.info(
        'InventoryService.fetchProducts — ${rows.length} products (${sw.elapsedMilliseconds}ms)');
    return List<Map<String, dynamic>>.from(rows as List);
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
  }) async {
    log.info('InventoryService.createProduct — bizId=$businessId name="$name"');
    final sw = Stopwatch()..start();
    final row = await SupabaseService.client
        .from('user_products')
        .insert({
          'business_id': businessId,
          'name': name.trim(),
          if (sku != null && sku.trim().isNotEmpty) 'sku': sku.trim(),
          if (category != null && category.trim().isNotEmpty)
            'category': category.trim(),
          'current_stock': currentStock,
          if (lowStockThreshold != null) 'low_stock_threshold': lowStockThreshold,
          if (unitPrice != null) 'unit_price': unitPrice,
          'type': 'GOODS',
        })
        .select()
        .single();
    log.info(
        'InventoryService.createProduct — done id=${row['id']} (${sw.elapsedMilliseconds}ms)');
    return Map<String, dynamic>.from(row);
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
  }) async {
    log.info('InventoryService.updateProduct — id=$productId');
    final updates = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (sku != null) 'sku': sku.trim().isNotEmpty ? sku.trim() : null,
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (currentStock != null) 'current_stock': currentStock,
      if (lowStockThreshold != null)
        'low_stock_threshold': lowStockThreshold,
      if (unitPrice != null) 'unit_price': unitPrice,
    };
    await SupabaseService.client
        .from('user_products')
        .update(updates)
        .eq('id', productId)
        .eq('business_id', businessId);
    log.info('InventoryService.updateProduct — done');
  }

  /// Delete a product.
  static Future<void> deleteProduct({
    required String productId,
    required String businessId,
  }) async {
    log.info('InventoryService.deleteProduct — id=$productId');
    await SupabaseService.client
        .from('user_products')
        .delete()
        .eq('id', productId)
        .eq('business_id', businessId);
    log.info('InventoryService.deleteProduct — done');
  }
}
