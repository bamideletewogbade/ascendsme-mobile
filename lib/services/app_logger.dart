import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppLogger — structured logging for AscendSME.
//
// Usage:
//   log.info('Something happened');
//   log.warning('Degraded state', error: e);
//   log.error('Fatal error', error: e, stackTrace: st);
//
// Debug builds: coloured console output, Level.debug and above.
// Release builds: console + rotating daily log file, Level.info and above.
//   File: <app-documents>/ascendsme_YYYY-MM-DD.log (7-day retention)
//   Retrieve: adb shell "run-as com.ascendsme.ascendsme_mobile cat /data/data/com.ascendsme.ascendsme_mobile/files/ascendsme_YYYY-MM-DD.log"
// ─────────────────────────────────────────────────────────────────────────────

class AppLogger {
  AppLogger._();
  static final AppLogger _instance = AppLogger._();
  static AppLogger get instance => _instance;

  late Logger _logger;

  // Phase 1 — called synchronously at the top of main(), before binding init.
  // Console-only; file output attaches in phase 2.
  void init() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 10,
        lineLength: 120,
        colors: kDebugMode,
        printEmojis: false,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: ConsoleOutput(),
      level: kDebugMode ? Level.debug : Level.info,
    );
    _logger.i('AppLogger init (${kDebugMode ? "debug" : "release"} mode)');
  }

  // Phase 2 — called after WidgetsFlutterBinding.ensureInitialized().
  // Attaches file output for release builds; no-op in debug.
  Future<void> initFileOutput() async {
    if (kDebugMode) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName =
          'ascendsme_${now.year}-${_pad(now.month)}-${_pad(now.day)}.log';
      final file = File('${dir.path}/$fileName');

      _pruneOldLogs(dir);

      _logger = Logger(
        printer: SimplePrinter(printTime: true, colors: false),
        output: MultiOutput([ConsoleOutput(), _FileLogOutput(file)]),
        level: Level.info,
      );
      _logger.i('File logging active — ${file.path}');
    } catch (e) {
      // Don't crash the app if file logging fails — console logging continues.
      _logger.w('Could not initialise file logging: $e');
    }
  }

  void debug(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.d(message, error: error, stackTrace: stackTrace);

  void info(String message) => _logger.i(message);

  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  void error(String message,
          {required Object error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Mask a JWT / auth token — shows only the first 12 chars.
  static String maskToken(String? token) {
    if (token == null || token.isEmpty) return '[null]';
    if (token.length <= 12) return '[short]';
    return '${token.substring(0, 12)}...';
  }

  /// Mask an email address — shows first 3 chars + domain.
  /// e.g. "adwoa.mensah@gmail.com" → "adw***@gmail.com"
  static String maskEmail(String? email) {
    if (email == null || email.isEmpty) return '[null]';
    final at = email.indexOf('@');
    if (at < 0) return '***';
    if (at < 3) return '***${email.substring(at)}';
    return '${email.substring(0, 3)}***${email.substring(at)}';
  }

  void _pruneOldLogs(Directory dir) {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              f.path.contains('ascendsme_') && f.path.endsWith('.log'))
          .where((f) => f.statSync().modified.isBefore(cutoff))
          .forEach((f) => f.deleteSync());
    } catch (_) {
      // Best-effort; don't crash on cleanup failures.
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

class _FileLogOutput extends LogOutput {
  final File file;
  _FileLogOutput(this.file);

  @override
  void output(OutputEvent event) {
    try {
      final sink = file.openWrite(mode: FileMode.append);
      for (final line in event.lines) {
        sink.writeln(line);
      }
      sink.close();
    } catch (_) {
      // Swallow I/O errors — don't let logging crash the app.
    }
  }
}

/// Top-level singleton accessor. Call sites: `log.info(...)`, `log.error(...)`.
final log = AppLogger.instance;
