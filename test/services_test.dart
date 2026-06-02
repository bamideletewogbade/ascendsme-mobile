import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers.dart';
import '../lib/services/cache_service.dart';
import '../lib/services/sync_service.dart';
import '../lib/services/app_logger.dart';

void main() {
  setUpAll(() {
    initTestLogger();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // CacheService
  // ─────────────────────────────────────────────────────────────────────────────

  group('CacheService', () {
    test('creates scoped cache keys', () {
      final c1 = CacheService('invoices', businessId: 'biz-001');
      final c2 = CacheService('expenses', businessId: 'biz-001');
      final c3 = CacheService('invoices', businessId: 'biz-002');
      // We can't directly access _key, but behavior distinguishes them
      expect(c1.runtimeType, c2.runtimeType); // just verifying type
    });

    test('put and get round-trip', () async {
      final cache = CacheService('test', businessId: 'biz-001');
      final rows = [
        {'id': '1', 'name': 'Item 1'},
        {'id': '2', 'name': 'Item 2'},
      ];

      await cache.put(rows);
      final loaded = await cache.get();

      expect(loaded, isNotNull);
      expect(loaded!.length, 2);
      expect(loaded[0]['name'], 'Item 1');
      expect(loaded[1]['name'], 'Item 2');
    });

    test('getOrEmpty returns empty list when no cache', () async {
      final cache = CacheService('nonexistent', businessId: 'biz-001');
      final result = await cache.getOrEmpty();
      expect(result, isEmpty);
    });

    test('get returns null when no cache', () async {
      final cache = CacheService('nonexistent', businessId: 'biz-001');
      final result = await cache.get();
      expect(result, isNull);
    });

    test('clear removes cached data', () async {
      final cache = CacheService('test_clear', businessId: 'biz-001');
      await cache.put([{'id': '1'}]);
      await cache.clear();
      final result = await cache.get();
      expect(result, isNull);
    });

    test('scoped keys isolate different domains', () async {
      final invCache = CacheService('invoices', businessId: 'biz-001');
      final expCache = CacheService('expenses', businessId: 'biz-001');

      await invCache.put([{'id': 'inv-1'}]);
      await expCache.put([{'id': 'exp-1'}]);

      final invoices = await invCache.get();
      final expenses = await expCache.get();

      expect(invoices!.length, 1);
      expect(invoices[0]['id'], 'inv-1');
      expect(expenses!.length, 1);
      expect(expenses[0]['id'], 'exp-1');
    });

    test('handles empty row list', () async {
      final cache = CacheService('empty_test');
      await cache.put([]);
      final result = await cache.get();
      expect(result, isNotNull);
      expect(result, isEmpty);
    });

    test('overwrites previous data on put', () async {
      final cache = CacheService('overwrite_test');
      await cache.put([{'id': 'old'}]);
      await cache.put([{'id': 'new'}]);
      final result = await cache.get();
      expect(result!.length, 1);
      expect(result[0]['id'], 'new');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // SyncService
  // ─────────────────────────────────────────────────────────────────────────────

  group('SyncService', () {
    test('starts empty', () {
      final sync = SyncService();
      expect(sync.pendingCount, 0);
      expect(sync.hasPending, false);
      expect(sync.isProcessing, false);
    });

    test('enqueue adds mutations', () async {
      final sync = SyncService();
      await sync.enqueue(
        domain: 'expenses',
        action: 'create',
        payload: {'amount_ghs': 500, 'business_id': 'biz-001'},
      );
      expect(sync.pendingCount, 1);
      expect(sync.hasPending, true);
    });

    test('enqueue multiple mutations', () async {
      final sync = SyncService();
      await sync.enqueue(domain: 'expenses', action: 'create', payload: {'a': 1});
      await sync.enqueue(domain: 'receipts', action: 'create', payload: {'b': 2});
      expect(sync.pendingCount, 2);
    });

    test('dequeueAll removes all mutations', () async {
      final sync = SyncService();
      await sync.enqueue(domain: 'test', action: 'create', payload: {'x': 1});
      await sync.enqueue(domain: 'test', action: 'create', payload: {'y': 2});

      final batch = sync.dequeueAll();
      expect(batch.length, 2);
      expect(sync.pendingCount, 0);
      expect(sync.hasPending, false);
    });

    test('reenqueue restores mutations', () async {
      final sync = SyncService();
      await sync.enqueue(domain: 'test', action: 'create', payload: {'z': 1});
      final batch = sync.dequeueAll();
      expect(sync.pendingCount, 0);

      await sync.reenqueue(batch);
      expect(sync.pendingCount, 1);
    });

    test('Persistence across instances', () async {
      final sync1 = SyncService();
      await sync1.enqueue(domain: 'test', action: 'create', payload: {'persist': true});

      final sync2 = SyncService();
      await sync2.restore();
      expect(sync2.pendingCount, 1);
      expect(sync2.queue.first.payload['persist'], true);
    });

    test('clear resets everything', () async {
      final sync = SyncService();
      await sync.enqueue(domain: 'test', action: 'create', payload: {'a': 1});
      await sync.clear();
      expect(sync.pendingCount, 0);
      expect(sync.failedCount, 0);
    });

    test('setProcessing updates state', () {
      final sync = SyncService();
      sync.setProcessing(true);
      expect(sync.isProcessing, true);
      sync.setProcessing(false);
      expect(sync.isProcessing, false);
    });

    test('setFailedCount updates state', () {
      final sync = SyncService();
      sync.setFailedCount(3);
      expect(sync.failedCount, 3);
    });

    test('PendingMutation toJson/fromJson round-trip', () {
      final mutation = PendingMutation(
        domain: 'invoices',
        action: 'create',
        payload: {'total_amount': 500, 'client_name': 'Test'},
        id: 'inv-001',
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );
      final json = mutation.toJson();
      final restored = PendingMutation.fromJson(json);
      expect(restored.domain, 'invoices');
      expect(restored.action, 'create');
      expect(restored.payload['total_amount'], 500);
      expect(restored.id, 'inv-001');
    });
  });
}
