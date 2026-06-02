import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'app_logger.dart';

/// Monitors network connectivity and exposes a reactive [isOnline] bool.
/// Wraps [connectivity_plus] so screens never import it directly.
///
/// Usage in AppState:
/// ```dart
/// final connectivity = context.read<ConnectivityService>();
/// if (connectivity.isOnline) { /* fetch from Supabase */ }
/// ```
class ConnectivityService extends ChangeNotifier {
  ConnectivityService() {
    _init();
  }

  bool _isOnline = true;
  bool _initialized = false;

  /// Whether the device currently has internet access.
  bool get isOnline => _isOnline;

  /// True after the first connectivity check completes.
  bool get initialized => _initialized;

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> _init() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateStatus(result);
      _initialized = true;
      notifyListeners();

      // Listen for changes
      _subscription = Connectivity().onConnectivityChanged.listen(_updateStatus);
    } catch (e, st) {
      log.warning('ConnectivityService init failed', error: e, stackTrace: st);
      _initialized = true;
      _isOnline = true; // assume online on error
      notifyListeners();
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final online = results.any((r) =>
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
    if (online != _isOnline) {
      _isOnline = online;
      log.info('ConnectivityService — ${online ? 'ONLINE' : 'OFFLINE'}');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
