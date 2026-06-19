import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

/// Generic JSON cache layer over SharedPreferences. Each data domain gets
/// its own scoped cache key so we never mix invoices with expenses.
///
/// All data is serialised as a JSON blob — fine for SME-scale volumes
/// (< 200 invoices, < 100 receipts) where the entire dataset fits in
/// SharedPreferences' ~1MB limit.
///
/// Usage:
/// ```dart
/// final cache = CacheService('invoices', businessId: 'biz_123');
/// await cache.put(rows);
/// final rows = await cache.get();
/// await cache.clear();
/// ```
class CacheService {
  final String domain;
  final String? businessId;

  CacheService(this.domain, {this.businessId});

  String get _key {
    if (businessId == null) return 'cache_$domain';
    return 'cache_${domain}_$businessId';
  }

  /// Write a list of row maps to the cache. Overwrites any previous data.
  Future<void> put(List<Map<String, dynamic>> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(rows));
      log.debug('CacheService — cached $domain: ${rows.length} rows');
    } catch (e, st) {
      log.warning('CacheService — put $domain failed', error: e, stackTrace: st);
    }
  }

  /// Read cached rows. Returns null when no cache exists (first run / cleared).
  Future<List<Map<String, dynamic>>?> get() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as List;
      final rows = decoded.cast<Map<String, dynamic>>();
      log.debug('CacheService — loaded $domain: ${rows.length} rows from cache');
      return rows;
    } catch (e, st) {
      log.warning('CacheService — get $domain failed', error: e, stackTrace: st);
      return null;
    }
  }

  /// Read cached rows, returning an empty list when no cache exists.
  Future<List<Map<String, dynamic>>> getOrEmpty() async {
    final rows = await get();
    return rows ?? [];
  }

  /// Remove all cached data for this domain.
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      log.debug('CacheService — cleared $domain');
    } catch (e, st) {
      log.warning('CacheService — clear $domain failed', error: e, stackTrace: st);
    }
  }
}
