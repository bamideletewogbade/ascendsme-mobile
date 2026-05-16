import 'package:flutter/material.dart';
import 'app_logger.dart';

// Logs every Navigator push / pop / replace so "navigated to white page"
// style bugs show up as a clear trail in the log output.
class AppRouterObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    log.info('NAV push  → ${_name(route)}  (from: ${_name(previousRoute)})');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    log.info('NAV pop   ← ${_name(route)}  (back to: ${_name(previousRoute)})');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    log.info('NAV replace ${_name(oldRoute)} → ${_name(newRoute)}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    log.info('NAV remove  ${_name(route)}');
  }

  String _name(Route<dynamic>? route) {
    if (route == null) return '[null]';
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    return route.runtimeType.toString();
  }
}
