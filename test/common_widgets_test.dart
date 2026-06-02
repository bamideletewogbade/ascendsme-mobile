import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';
import '../lib/core/widgets/common.dart';
import '../lib/core/tokens.dart';
import '../lib/state/app_state.dart';

void main() {
  setUpAll(() {
    initTestLogger();
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // AppCard
  // ─────────────────────────────────────────────────────────────────────────────

  group('AppCard', () {
    testWidgets('renders with child', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AppCard(child: Text('Hello')),
      ));
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('responds to onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrapWithProviders(
        AppCard(onTap: () => tapped = true, child: const Text('Tap me')),
      ));
      await tester.tap(find.text('Tap me'));
      expect(tapped, true);
    });

    testWidgets('applies padding', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AppCard(padding: EdgeInsets.all(20), child: Text('Padded')),
      ));
      final card = tester.widget<AppCard>(find.byType(AppCard));
      expect(card.padding, const EdgeInsets.all(20));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // AppBtn
  // ─────────────────────────────────────────────────────────────────────────────

  group('AppBtn', () {
    testWidgets('renders with label', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AppBtn('Click me'),
      ));
      expect(find.text('Click me'), findsOneWidget);
    });

    testWidgets('responds to onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(wrapWithProviders(
        AppBtn('Press', onTap: () => tapped = true),
      ));
      await tester.tap(find.text('Press'));
      expect(tapped, true);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // AppPill / AppPillFilled
  // ─────────────────────────────────────────────────────────────────────────────

  group('AppPill', () {
    testWidgets('renders with text', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AppPill('Active', tone: PillTone.green),
      ));
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('renders small variant', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AppPill('Tiny', tone: PillTone.teal, small: true),
      ));
      expect(find.text('Tiny'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // AppAvatar
  // ─────────────────────────────────────────────────────────────────────────────

  group('AppAvatar', () {
    testWidgets('renders initials', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AppAvatar('AT', size: 42),
      ));
      expect(find.text('AT'), findsOneWidget);
    });

    testWidgets('respects custom size', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AppAvatar('AB', size: 60),
      ));
      final avatar = tester.widget<AppAvatar>(find.byType(AppAvatar));
      expect(avatar.size, 60);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // AppIcon
  // ─────────────────────────────────────────────────────────────────────────────

  group('AppIcon', () {
    testWidgets('renders known icon', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AppIcon('payments', size: 24),
      ));
      // Should find an Icon widget
      expect(find.byIcon(Icons.payments), findsOneWidget);
    });

    testWidgets('renders fallback for unknown icon', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AppIcon('nonexistent_icon', size: 24),
      ));
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });

    testWidgets('renders grid_view icon', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AppIcon('grid_view', size: 24),
      ));
      expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // SectionHeader
  // ─────────────────────────────────────────────────────────────────────────────

  group('SectionHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SectionHeader('My Section'),
      ));
      expect(find.text('My Section'), findsOneWidget);
    });

    testWidgets('renders action when provided', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const SectionHeader('Section', action: 'View all'),
      ));
      expect(find.text('Section'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // GoogleSignInButton
  // ─────────────────────────────────────────────────────────────────────────────

  group('GoogleSignInButton', () {
    testWidgets('renders with Google text', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        GoogleSignInButton(onPressed: () {}),
      ));
      expect(find.text('Google'), findsOneWidget);
    });

    testWidgets('responds to onPressed', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(wrapWithProviders(
        GoogleSignInButton(onPressed: () => pressed = true),
      ));
      await tester.tap(find.text('Google'));
      expect(pressed, true);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // BottomNav
  // ─────────────────────────────────────────────────────────────────────────────

  group('BottomNav', () {
    testWidgets('renders all tabs', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        Builder(builder: (context) {
          // Need to provide NavVariant and onTab
          return BottomNav(
            current: AppTab.home,
            onTab: (_) {},
            onCreate: () {},
            variant: NavVariant.classic,
          );
        }),
      ));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Finance'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('tab change triggers onTab', (tester) async {
      AppTab? selected;
      await tester.pumpWidget(wrapWithProviders(
        Builder(builder: (context) {
          return BottomNav(
            current: AppTab.home,
            onTab: (tab) => selected = tab,
            onCreate: () {},
            variant: NavVariant.classic,
          );
        }),
      ));
      await tester.tap(find.text('Finance'));
      expect(selected, AppTab.finance);
    });

    testWidgets('pill variant renders differently', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        Builder(builder: (context) {
          return BottomNav(
            current: AppTab.home,
            onTab: (_) {},
            onCreate: () {},
            variant: NavVariant.pill,
          );
        }),
      ));
      // Pill variant should still show all tabs
      expect(find.text('Home'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // SubScreenHeader
  // ─────────────────────────────────────────────────────────────────────────────

  group('SubScreenHeader', () {
    testWidgets('renders title and back button', (tester) async {
      bool popped = false;
      await tester.pumpWidget(wrapWithProviders(
        Material(
          child: SubScreenHeader('My Screen', onBack: () => popped = true),
        ),
      ));
      expect(find.text('My Screen'), findsOneWidget);
      // Back button should exist
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // AppShimmer / FadeInSlide
  // ─────────────────────────────────────────────────────────────────────────────

  group('AppShimmer', () {
    testWidgets('renders with dimensions', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const AppShimmer(width: 200, height: 20, radius: 4),
      ));
      // Should render the shimmer element
      expect(find.byType(AppShimmer), findsOneWidget);
    });
  });

  group('FadeInSlide', () {
    testWidgets('renders child with animation', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const FadeInSlide(index: 0, child: Text('Animated')),
      ));
      expect(find.text('Animated'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────────
  // GlassSheet
  // ─────────────────────────────────────────────────────────────────────────────

  group('GlassSheet', () {
    testWidgets('renders with child', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        const GlassSheet(child: Text('Sheet content')),
      ));
      expect(find.text('Sheet content'), findsOneWidget);
    });
  });
}
