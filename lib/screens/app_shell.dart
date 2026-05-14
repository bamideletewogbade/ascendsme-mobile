import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import 'home_screen.dart';
import 'tools_screen.dart';
import 'verify_screen.dart';
import 'help_screen.dart';
import 'sheets/profile_drawer.dart';
import 'sheets/notifications_sheet.dart';
import 'sheets/new_invoice_sheet.dart';
import 'sheets/ask_ascend_sheet.dart';
import 'sheets/score_up_overlay.dart';

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
        _openAI('Draft a polite WhatsApp reminder for Kente Co. for INV-0142 '
            '(12 days overdue, GHS 2,400). Use a warm, professional tone.');
      case 'expense':
        final q = context.read<AppState>().quests.firstWhere(
            (q) => q.id == 'q1' && !q.done,
            orElse: () => context.read<AppState>().quests.first);
        if (!q.done) context.read<AppState>().completeQuest(q);
      case 'booking':
        _pushTool(ctx, 'booking');
    }
  }

  void _pushTool(BuildContext ctx, String id) {
    Navigator.push(ctx,
        MaterialPageRoute(builder: (_) => ToolStubScreen(toolId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = context.colors;
    final bottomPad = state.navVariant == NavVariant.pill ? 96.0 : 72.0;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
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
                        onTool: (id) => _pushTool(context, id),
                        onOpenDrawer: () => setState(() => _drawerOpen = true),
                      ),
                      ToolsScreen(
                        onTool: (id) => _pushTool(context, id),
                        onNewInvoice: _openNewInvoice,
                      ),
                      const VerifyScreen(),
                      const HelpScreen(),
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

          // ── Score-up celebration ───────────
          if (state.scoreUp != null)
            ScoreUpOverlay(
              event: state.scoreUp!,
              onClose: () => context.read<AppState>().clearScoreUp(),
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
