import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

/// A pending mutation queued while the device is offline.
///
/// [domain] matches the CacheService domain (e.g. 'invoices', 'receipts').
/// [action] is one of 'create', 'update', 'delete'.
/// [payload] contains the data that would have been sent to Supabase.
/// [id] is an optional record identifier for update/delete/void actions.
class PendingMutation {
  final String domain;
  final String action;
  final Map<String, dynamic> payload;
  final String? id;
  final String timestamp;

  const PendingMutation({
    required this.domain,
    required this.action,
    required this.payload,
    this.id,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'domain': domain,
        'action': action,
        'payload': payload,
        if (id != null) 'id': id,
        'timestamp': timestamp,
      };

  factory PendingMutation.fromJson(Map<String, dynamic> json) =>
      PendingMutation(
        domain: json['domain'] as String,
        action: json['action'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        id: json['id'] as String?,
        timestamp: json['timestamp'] as String,
      );
}

/// Queues mutations made while offline and provides them for replay when
/// connectivity returns. This is a pure queue manager — AppState reads the
/// queue and executes mutations via SupabaseService.
///
/// The queue is persisted in SharedPreferences so it survives app restarts.
class SyncService extends ChangeNotifier {
  static const _queueKey = 'sync_pending_mutations';

  List<PendingMutation> _queue = [];
  bool _processing = false;
  int _failedCount = 0;

  List<PendingMutation> get queue => List.unmodifiable(_queue);
  int get pendingCount => _queue.length;
  bool get isProcessing => _processing;
  int get failedCount => _failedCount;
  bool get hasPending => _queue.isNotEmpty;

  /// Enqueue a mutation. Called by services when a write is attempted offline.
  Future<void> enqueue({
    required String domain,
    required String action,
    required Map<String, dynamic> payload,
    String? id,
  }) async {
    final mutation = PendingMutation(
      domain: domain,
      action: action,
      payload: payload,
      id: id,
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
    _queue.add(mutation);
    await _persist();
    log.info('SyncService — enqueued $action $domain (queue: ${_queue.length})');
    notifyListeners();
  }

  /// Remove and return the next batch of mutations for processing.
  /// Returns the full snapshot and clears the working queue — if processing
  /// fails, the caller should re-enqueue remaining mutations.
  List<PendingMutation> dequeueAll() {
    final snapshot = List<PendingMutation>.from(_queue);
    _queue.clear();
    _persist();
    return snapshot;
  }

  /// Re-queue mutations that failed to process (e.g. network error mid-sync).
  Future<void> reenqueue(List<PendingMutation> mutations) async {
    _queue.insertAll(0, mutations);
    await _persist();
    notifyListeners();
  }

  /// Mark the queue as being processed (for UI feedback).
  void setProcessing(bool v) {
    _processing = v;
    notifyListeners();
  }

  /// Set the count of failed mutations (for UI feedback).
  void setFailedCount(int count) {
    _failedCount = count;
    notifyListeners();
  }

  /// Persist the queue to SharedPreferences.
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_queue.map((m) => m.toJson()).toList());
      await prefs.setString(_queueKey, raw);
    } catch (e, st) {
      log.warning('SyncService — persist failed', error: e, stackTrace: st);
    }
  }

  /// Restore the queue from SharedPreferences. Call once at startup.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List;
      _queue = decoded
          .map((e) => PendingMutation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      log.info('SyncService — restored ${_queue.length} pending mutations');
      notifyListeners();
    } catch (e, st) {
      log.warning('SyncService — restore failed', error: e, stackTrace: st);
    }
  }

  /// Clear all pending mutations (e.g. after sign-out).
  Future<void> clear() async {
    _queue.clear();
    _failedCount = 0;
    await _persist();
    notifyListeners();
  }
}
