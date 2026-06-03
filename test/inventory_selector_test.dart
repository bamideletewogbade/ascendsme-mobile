import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';
import '../lib/core/models.dart';
import '../lib/core/widgets/inventory_selector.dart';
import '../lib/state/app_state.dart';

/// Build a minimal test inventory list.
List<InventoryItem> _sampleInventory() => [
      InventoryItem(
        id: 'p1',
        name: 'Kente cloth',
        sku: 'KNT-001',
        category: 'Fabric',
        currentStock: 15,
        lowStockThreshold: 5,
        unitPrice: 150.0,
      ),
      InventoryItem(
        id: 'p2',
        name: 'Adinkra stamps',
        sku: 'ADK-002',
        category: 'Tools',
        currentStock: 3,
        lowStockThreshold: 10,
        unitPrice: 45.0,
      ),
      InventoryItem(
        id: 'p3',
        name: 'Batik dye (blue)',
        category: 'Supplies',
        currentStock: 8,
        lowStockThreshold: null,
        unitPrice: 25.0,
      ),
      InventoryItem(
        id: 'p4',
        name: 'Sewing needle set',
        sku: 'NS-001',
        category: 'Tools',
        currentStock: 40,
        lowStockThreshold: 5,
        unitPrice: 12.0,
      ),
      InventoryItem(
        id: 'p5',
        name: 'Cotton thread (white)',
        sku: 'THR-WH',
        category: 'Supplies',
        currentStock: 200,
        lowStockThreshold: 20,
        unitPrice: 3.5,
      ),
      InventoryItem(
        id: 'p6',
        name: 'Wooden mannequin',
        category: 'Display',
        currentStock: 2,
        lowStockThreshold: 1,
        unitPrice: 250.0,
      ),
    ];

void main() {
  setUpAll(() {
    initTestLogger();
  });

  group('InventorySelector', () {
    testWidgets('renders label and search field', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          label: 'Add products',
          multiSelect: true,
          onChanged: (_) {},
        ),
      ));

      expect(find.text('Add products'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search and add products…'), findsOneWidget);
    });

    testWidgets('shows default hint based on multiSelect mode', (tester) async {
      // Multi-select hint
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          multiSelect: true,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Search and add products…'), findsOneWidget);

      // Single-select hint
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          multiSelect: false,
          onChanged: (_) {},
        ),
      ));
      expect(find.text('Search products…'), findsOneWidget);
    });

    testWidgets('shows first 6 items on focus (empty field)', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          multiSelect: true,
          onChanged: (_) {},
        ),
      ));

      // Focus the text field
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Should show first 6 items as suggestions
      expect(find.text('Kente cloth'), findsOneWidget);
      expect(find.text('Adinkra stamps'), findsOneWidget);
      expect(find.text('Batik dye (blue)'), findsOneWidget);
      expect(find.text('Sewing needle set'), findsOneWidget);
      expect(find.text('Cotton thread (white)'), findsOneWidget);
      expect(find.text('Wooden mannequin'), findsOneWidget);
    });

    testWidgets('filters items by name on search', (tester) async {
      InventoryItem? selected;
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          multiSelect: true,
          onChanged: (item) => selected = item,
        ),
      ));

      // Focus and type a search query
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kente');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // Should show filtered results
      expect(find.text('Kente cloth'), findsOneWidget);
      expect(find.text('Adinkra stamps'), findsNothing);
    });

    testWidgets('selects item in single-select mode', (tester) async {
      InventoryItem? selected;
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          multiSelect: false,
          onChanged: (item) => selected = item,
        ),
      ));

      // Focus the text field
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Tap on 'Kente cloth'
      await tester.tap(find.text('Kente cloth'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.name, 'Kente cloth');
      expect(selected!.id, 'p1');
    });

    testWidgets('selects item in multi-select mode and clears field', (tester) async {
      InventoryItem? selected;
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          multiSelect: true,
          onChanged: (item) => selected = item,
        ),
      ));

      // Focus the text field
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Type a search
      await tester.enterText(find.byType(TextField), 'adinkra');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      // Tap on 'Adinkra stamps'
      await tester.tap(find.text('Adinkra stamps'));
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.name, 'Adinkra stamps');

      // Field should be cleared after multi-select
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('shows stock count and price in dropdown', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          multiSelect: true,
          onChanged: (_) {},
        ),
      ));

      // Focus the text field
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Should show stock info for Kente cloth
      expect(find.text('15 in stock'), findsOneWidget);
      expect(find.text('GHS 150'), findsOneWidget);
    });

    testWidgets('highlights low stock items', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          multiSelect: true,
          onChanged: (_) {},
        ),
      ));

      // Focus the text field
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Adinkra stamps has 3 in stock with threshold of 10 — it's low stock
      expect(find.text('3 in stock'), findsOneWidget);
      // Kente cloth has 15 in stock with threshold of 5 — it's not low
      expect(find.text('15 in stock'), findsOneWidget);
    });

    testWidgets('shows no results message', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          multiSelect: true,
          onChanged: (_) {},
        ),
      ));

      // Focus and type a non-matching query
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzzzzzz');
      await tester.pumpAndSettle(const Duration(milliseconds: 300));

      expect(find.textContaining('No products match'), findsOneWidget);
    });

    testWidgets('shows add icon in multi-select mode', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          multiSelect: true,
          onChanged: (_) {},
        ),
      ));

      // Focus the text field
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Should show add_circle_outline icon
      expect(find.byIcon(Icons.add_circle_outline), findsWidgets);
    });

    testWidgets('shows check mark after single selection', (tester) async {
      await tester.pumpWidget(wrapWithProviders(
        InventorySelector(
          inventory: _sampleInventory(),
          multiSelect: false,
          onChanged: (_) {},
        ),
      ));

      // Focus and select an item
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kente cloth'));
      await tester.pumpAndSettle();

      // Should show check icon
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
