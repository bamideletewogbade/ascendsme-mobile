import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../services/sync_service.dart';
import '../state/app_state.dart';
import 'home_screen.dart';
import 'tools_screen.dart';
import 'profile_screen.dart';
import 'ask_ascend_screen.dart';
import 'tools/invoices_screen.dart';
import 'tools/inventory_screen.dart';
import 'tools/subscription_screen.dart';
import 'tools/staff_screen.dart';
import 'tools/shop_screen.dart';
import 'sheets/profile_drawer.dart';
import 'sheets/notifications_sheet.dart';
import 'sheets/new_invoice_sheet.dart';
import 'sheets/log_expense_sheet.dart';
import 'sheets/log_sale_sheet.dart';
import 'tools/booking_screen.dart';
import 'tools/cash_flow_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppShellBody();
  }
}

class _AppShellBody extends StatefulWidget {
  const _AppShellBody();
  @override
  State<_AppShellBody> createState() => _AppShellBodyState();
}

class _AppShellBodyState extends State<_AppShellBody> {
  bool _drawerOpen = false;

  void _openNotifications() => _showSheet(context, const NotificationsSheet());
  void _openNewInvoice({VoidCallback? onSent}) =>
      _showSheet(context, NewInvoiceSheet(onSent: onSent));
  void _openAI([String? prompt]) {
    if (prompt != null && prompt.isNotEmpty) {
      context.read<AppState>().setAiPrompt(prompt);
    }
    context.read<AppState>().setTab(AppTab.askAscend);
  }

  void _showSheet(BuildContext ctx, Widget sheet) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  void _handleAction(BuildContext ctx, String id) {
    switch (id) {
      case 'invoice':
      case 'newInvoice':
        _openNewInvoice();
      case 'notifications':
        _openNotifications();
      case 'askAI':
        _openAI();
      case 'followup':
        _openAI('I have overdue invoices. Draft a polite, professional WhatsApp '
            'follow-up reminder I can send to the customer. Keep it warm and brief.');
      case 'expense':
        LogExpenseSheet.show(ctx);
      case 'sale':
        LogSaleSheet.show(ctx);
      case 'booking':
        _pushTool(ctx, 'booking');
      case 'inventory':
        _pushTool(ctx, 'inventory');
      case 'subscription':
        _pushTool(ctx, 'subscription');
      case 'staff':
        _pushTool(ctx, 'staff');
      case 'shop':
        _pushTool(ctx, 'shop');

      // ── Dynamic recommendation IDs from buildRecommendations() ────────
      case 'rec_first_invoice':
        _openNewInvoice();
      case 'rec_followup_overdue':
        _openAI('I have overdue invoices. Draft a polite, professional WhatsApp '
            'follow-up reminder I can send to the customer. Keep it warm and brief.');
      case 'rec_first_expense':
        LogExpenseSheet.show(ctx);
      case 'tools':
        context.read<AppState>().setTab(AppTab.tools);
      case 'rec_verify':
        context.read<AppState>().setTab(AppTab.profile);
      case 'rec_all_clear':
        context.read<AppState>().setTab(AppTab.home);
    }
  }

  void _pushTool(BuildContext ctx, String id) {
    // Route known real tools to their dedicated screens; everything else
    // falls back to the "Coming soon" stub.
    final Widget screen = switch (id) {
      'invoicing'     => const InvoicesScreen(),
      'inventory'     => const InventoryScreen(),
      'subscription'  => const SubscriptionScreen(),
      'staff'         => const StaffScreen(),
      'shop'          => const ShopScreen(),
      'booking' => const BookingScreen(),
      _ => ToolStubScreen(toolId: id),
    };
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = context.colors;
    final bottomPad = state.navVariant == NavVariant.pill ? 96.0 : 72.0;
    final offline = state.isOffline;
    final syncState = context.watch<SyncService>();

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        // Without this, the Stack sizes itself to the largest non-positioned
        // child. ProfileDrawer returns SizedBox.shrink() when closed, so the
        // whole Stack collapses to 0x0 and every Positioned.fill below renders
        // into nothing — symptom: blank screen after auth.
        fit: StackFit.expand,
        children: [
          // ── Main content ───────────────────
          Positioned.fill(
            child: Column(
              children: [
                // ── Offline banner ──
                if (offline || syncState.isProcessing)
                  _OfflineBar(
                    offline: offline,
                    syncing: syncState.isProcessing,
                    pendingCount: syncState.pendingCount,
                    failedCount: syncState.failedCount,
                  ),
                Expanded(
                  child: IndexedStack(
                    index: state.tab.index,
                    children: [
                      HomeScreen(
                        onAction: (id) => _handleAction(context, id),
                        onOpenDrawer: () => setState(() => _drawerOpen = true),
                      ),
                      const CashFlowForecastScreen(),
                      ToolsScreen(
                        onOpenDrawer: () => setState(() => _drawerOpen = true),
                      ),
                      const ProfileScreen(),
                      AskAscendScreen(
                        onOpenDrawer: () => setState(() => _drawerOpen = true),
                      ),
                    ],
                  ),
                ),
                // bottom nav takes space in classic/fab variant
                if (state.navVariant != NavVariant.pill)
                  BottomNav(
                    current: state.tab,
                    onTab: state.setTab,
                    variant: state.navVariant,
                  ),
              ],
            ),
          ),

          // ── Pill nav floats above content ──
          if (state.navVariant == NavVariant.pill)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: BottomNav(
                current: state.tab,
                onTab: state.setTab,
                variant: NavVariant.pill,
              ),
            ),

          // ── Ask Ascend FAB — bottom-right floating button ──
          Positioned(
            right: 20,
            bottom: bottomPad + 16,
            child: GestureDetector(
              onTap: () => _openAI(),
              child: AnimatedPress(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.teal, c.tealDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.teal.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // ── Profile drawer ─────────────────
          ProfileDrawer(
            open: _drawerOpen,
            onClose: () => setState(() => _drawerOpen = false),
            onSignOut: () {
              setState(() => _drawerOpen = false);
              // Clear any pushed routes (tools, etc.) before auth state changes.
              Navigator.of(context).popUntil((route) => route.isFirst);
              context.read<AppState>().signOut();
            },
          ),
        ],
      ),
    );
  }
}

// ── Offline banner ───────────────────────────
class _OfflineBar extends StatelessWidget {
  final bool offline;
  final bool syncing;
  final int pendingCount;
  final int failedCount;

  const _OfflineBar({
    required this.offline,
    required this.syncing,
    required this.pendingCount,
    required this.failedCount,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (offline) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: c.amber.withValues(alpha: 0.12),
        child: Row(
          children: [
            Icon(Icons.wifi_off, size: 14, color: c.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pendingCount > 0
                    ? 'You\'re offline · $pendingCount change${pendingCount == 1 ? '' : 's'} pending sync'
                    : 'You\'re offline — showing cached data',
                style: AppType.body(size: 11.5, weight: FontWeight.w600, color: c.amber),
              ),
            ),
          ],
        ),
      );
    }

    if (syncing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: c.teal.withValues(alpha: 0.08),
        child: Row(
          children: [
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation(c.teal),
              ),
            ),
            const SizedBox(width: 8),
            Text('Syncing changes…',
                style: AppType.body(size: 11.5, weight: FontWeight.w600, color: c.teal)),
            if (failedCount > 0) ...[
              const SizedBox(width: 6),
              Text('$failedCount failed',
                  style: AppType.body(size: 11, color: c.rose)),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Generic tool stub screen ─────────────────
class ToolStubScreen extends StatelessWidget {
  final String toolId;
  const ToolStubScreen({super.key, required this.toolId});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            SubScreenHeader(
              toolId.replaceFirst(toolId[0], toolId[0].toUpperCase()),
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.build_circle_outlined, size: 48, color: c.navy),
                    const SizedBox(height: 16),
                    Text('Coming soon',
                        style: AppType.heading(size: 18, color: c.text)),
                    const SizedBox(height: 8),
                    Text(
                      'This module is fully available in the web app.\nMobile version in progress.',
                      textAlign: TextAlign.center,
                      style: AppType.body(size: 13, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
