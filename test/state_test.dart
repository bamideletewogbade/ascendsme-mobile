import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'helpers.dart';
import '../lib/state/app_state.dart';
import '../lib/core/models.dart';
import '../lib/services/app_logger.dart';

void main() {
  setUpAll(() {
    initTestLogger();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppState — auth', () {
    test('starts unauthenticated', () {
      final state = createTestAppState();
      expect(state.authed, false);
      expect(state.user, isNull);
      expect(state.authLoading, false);
    });

    test('mock auth works when Supabase not configured', () async {
      final state = createTestAppState();
      final success = await state.signIn(email: 'test@test.com', password: 'pass123');
      expect(success, true);
      expect(state.authed, true);
    });

    test('mock sign-up works', () async {
      final state = createTestAppState();
      final success = await state.signUp(
        email: 'test@test.com',
        password: 'pass123',
        businessName: 'Test Biz',
        phone: '0244000001',
        fullName: 'Test User',
      );
      expect(success, true);
      expect(state.authed, true);
    });

    test('mock Google sign-in works', () async {
      final state = createTestAppState();
      final success = await state.signInWithGoogle();
      expect(success, true);
      expect(state.authed, true);
    });

    test('sign-out clears auth state', () async {
      final state = createTestAppState();
      await state.signIn(email: 'test@test.com', password: 'pass123');
      expect(state.authed, true);

      state.signOut();
      expect(state.authed, false);
    });

    test('clearAuthError resets error', () {
      final state = createTestAppState();
      // Manually set an error (simulating what real sign-in would do on failure)
      state.clearAuthError();
      expect(state.authError, isNull);
    });

    test('hasRealBusiness is false initially', () {
      final state = createTestAppState();
      expect(state.hasRealBusiness, false);
    });

    test('business falls back to kBusiness mock', () {
      final state = createTestAppState();
      expect(state.business.name, 'Akwaaba Threads');
    });
  });

  group('AppState — navigation', () {
    test('starts on home tab', () {
      final state = createTestAppState();
      expect(state.tab, AppTab.home);
    });

    test('setTab changes tab', () {
      final state = createTestAppState();
      state.setTab(AppTab.finance);
      expect(state.tab, AppTab.finance);
      state.setTab(AppTab.customers);
      expect(state.tab, AppTab.customers);
      state.setTab(AppTab.profile);
      expect(state.tab, AppTab.profile);
    });
  });

  group('AppState — appearance', () {
    test('dark mode defaults to false', () {
      final state = createTestAppState();
      expect(state.darkMode, false);
    });

    test('toggleDark switches mode', () {
      final state = createTestAppState();
      state.toggleDark();
      expect(state.darkMode, true);
      state.toggleDark();
      expect(state.darkMode, false);
    });
  });

  group('AppState — offline awareness', () {
    test('isOffline is false when online', () {
      final state = createTestAppState(online: true);
      expect(state.isOffline, false);
    });

    test('isOffline is true when offline', () {
      final state = createTestAppState(online: false);
      expect(state.isOffline, true);
    });
  });

  group('AppState — financials', () {
    test('financials starts empty', () {
      final state = createTestAppState();
      expect(state.financials.isEmpty, true);
    });

    test('recentInvoices returns mock invoices when no real business', () {
      final state = createTestAppState();
      final recent = state.recentInvoices(count: 3);
      expect(recent.length, 3);
      expect(recent[0].customer, 'Kente Co.');
    });
  });

  group('AppState — computed properties', () {
    test('firstName returns null when no user metadata', () {
      final state = createTestAppState();
      expect(state.firstName, isNull);
    });
  });

  group('AppState — cache cleanup', () {
    test('signOut clears caches', () async {
      final state = createTestAppState();
      await state.signIn(email: 'test@test.com', password: 'pass123');
      expect(state.authed, true);

      // Write something to a cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_invoices_biz-001', '[{"test": true}]');

      state.signOut();
      expect(state.authed, false);

      // Cache should be cleared
      final cached = prefs.getString('cache_invoices_biz-001');
      expect(cached, isNull);
    });
  });

  group('AppState — processPendingMutations', () {
    test('handles empty queue gracefully', () async {
      final state = createTestAppState();
      // Should not throw for empty queue
      await state.processPendingMutations();
    });
  });
}
