import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import 'home_screen.dart';
import 'money_screen.dart';
import 'customers_screen.dart';
import 'profile_screen.dart';
import 'verify_screen.dart';
import 'tools/invoices_screen.dart';
import 'sheets/profile_drawer.dart';
import 'sheets/notifications_sheet.dart';
import 'sheets/new_invoice_sheet.dart';
import 'sheets/log_expense_sheet.dart';
import 'sheets/ask_ascend_sheet.dart';

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
  void _openAI([String? prompt]) =>
      _showSheet(context, AskAscendSheet(initialPrompt: prompt));

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
      case 'booking':
        _pushTool(ctx, 'booking');
      case 'customer':
        // Jump to the Customers tab. Real "add customer" form lands in
        // Phase 3+ when we model a customers table.
        context.read<AppState>().setTab(AppTab.customers);

      // ── Recommendation card CTAs (kRecommendations.id) ───────────────
      case 'r1': // "Log this month's expenses"
        LogExpenseSheet.show(ctx);
      case 'r2': // "Follow up on overdue invoices"
        _openAI('I have overdue invoices. Draft a polite, professional WhatsApp '
            'follow-up reminder I can send to the customer. Keep it warm and brief.');
      case 'r3': // "Apply to the Stanbic Women in Business facility"
        // Surface the verification + funding flow as the canonical entry
        // point. The lender list is at the bottom of that screen.
        _pushVerification(ctx);
      case 'r4': // "Add 2 more product photos to your public shop"
        _comingSoon(ctx, 'Online shop');
    }
  }

  void _comingSoon(BuildContext ctx, String featureName) {
    final c = ctx.colors;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text('$featureName — coming soon.',
            style: AppType.body(size: 13, color: Colors.white)),
        backgroundColor: c.tealDeep,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _pushVerification(BuildContext ctx) {
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => const VerifyScreen()),
    );
  }

  void _pushTool(BuildContext ctx, String id) {
    // Route known real tools to their dedicated screens; everything else
    // falls back to the "Coming soon" stub.
    final Widget screen = switch (id) {
      'invoicing' => const InvoicesScreen(),
      _ => ToolStubScreen(toolId: id),
    };
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = context.colors;
    final bottomPad = state.navVariant == NavVariant.pill ? 96.0 : 72.0;

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
                Expanded(
                  child: IndexedStack(
                    index: state.tab.index,
                    children: [
                      HomeScreen(
                        onAction: (id) => _handleAction(context, id),
                        onOpenDrawer: () => setState(() => _drawerOpen = true),
                      ),
                      const MoneyScreen(),
                      const CustomersScreen(),
                      const ProfileScreen(),
                    ],
                  ),
                ),
                // bottom nav takes space in classic/fab variant
                if (state.navVariant != NavVariant.pill)
                  BottomNav(
                    current: state.tab,
                    onTab: state.setTab,
                    onCreate: _openNewInvoice,
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
                onCreate: _openNewInvoice,
                variant: NavVariant.pill,
              ),
            ),

          // ── Ask Ascend FAB (home tab only) ─
          if (state.tab == AppTab.home)
            Positioned(
              right: 16,
              bottom: bottomPad,
              child: _AskAscendFAB(onTap: () => _openAI()),
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

// ── Floating Ask Ascend button ───────────────
class _AskAscendFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _AskAscendFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.teal, c.tealDeep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
                color: c.teal.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 15, color: Colors.white),
            const SizedBox(width: 8),
            Text('Ask Ascend',
                style: AppType.body(
                    size: 13, weight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
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
                    Icon(Icons.build_circle_outlined, size: 48, color: c.teal),
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
