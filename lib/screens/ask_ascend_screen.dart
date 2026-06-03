import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/tokens.dart';
import '../core/widgets/common.dart';
import '../state/app_state.dart';
import '../services/ai_service.dart';
import '../services/supabase_service.dart';

/// Full-screen Ask Ascend — the AI business advisor as a dedicated tab.
/// Replaces the old bottom-sheet + floating FAB pattern.
class AskAscendScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;

  const AskAscendScreen({super.key, this.onOpenDrawer});

  @override
  State<AskAscendScreen> createState() => _AskAscendScreenState();
}

class _AskAscendScreenState extends State<AskAscendScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];
  bool _loading = false;

  static const _suggestions = [
    'What should I focus on today?',
    'How is my business doing this month?',
    'Help me draft a follow-up reminder',
    'Explain my cash flow',
    'I need help with something in the app',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _loading) return;
    final appState = context.read<AppState>();
    final business = appState.business;
    final financials = appState.financials;
    setState(() {
      _messages.add(_Msg(text: prompt, fromUser: true));
      _loading = true;
    });
    _ctrl.clear();
    _scrollToBottom();

    // Detect support requests and log them
    final isSupport = _detectSupportRequest(prompt);
    if (isSupport) {
      _logSupportRequest(context, prompt);
    }

    // Get AI reply with support-aware system context
    final supportCtx = isSupport
        ? '\n\nThe user is asking for help/support. Be empathetic and helpful. '
            'Ask clarifying questions to understand their issue better. '
            'If they provide details about a problem, acknowledge it and '
            'assure them it has been logged for the team. '
            'For issues that need human intervention, say "I\'ve logged this for our team."'
        : '';
    final reply = await AIService.ask(prompt,
        maxSentences: 5,
        business: business,
        financials: financials,
        extraContext: supportCtx);
    if (mounted) {
      setState(() {
        _messages.add(_Msg(text: reply, fromUser: false));
        _loading = false;
      });
      _scrollToBottom();
    }
  }

  /// Naive detection — looks for support/help/issue/problem keywords.
  /// In a production version this would be a lightweight AI classification.
  bool _detectSupportRequest(String prompt) {
    final lower = prompt.toLowerCase();
    final keywords = [
      'help', 'issue', 'problem', 'bug', 'broken', 'error',
      'not working', 'can\'t', 'cannot', 'support', 'stuck',
    ];
    return keywords.any((k) => lower.contains(k));
  }

  Future<void> _logSupportRequest(BuildContext context, String prompt) async {
    try {
      final state = context.read<AppState>();
      await SupabaseService.logSupportRequest(
        businessId: state.business.id,
        description: prompt,
      );
    } catch (_) {
      // Silent — logging is best-effort
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = context.watch<AppState>();

    // Reactively consume any pending AI prompt set from another screen.
    // Using context.watch ensures this fires on every AppState change,
    // including subsequent prompts (not just first mount).
    final pending = state.consumeAiPrompt();
    if (pending != null && pending.isNotEmpty && !_loading) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _send(pending));
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.navy, c.navyDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ask Ascend',
                          style: AppType.display(size: 28, color: c.text)),
                      Text('Your 24/7 business advisor',
                          style: AppType.body(size: 12, color: c.textMuted)),
                    ],
                  ),
                ),
                // Avatar for opening drawer
                if (widget.onOpenDrawer != null)
                  GestureDetector(
                    onTap: widget.onOpenDrawer,
                    child: AppAvatar(state.business.initials, size: 38),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Ask me anything about your business — cash flow, invoices, follow-ups, or get help. I respond instantly.',
              style: AppType.body(size: 12.5, color: c.textMuted),
            ),
          ),
          Divider(height: 1, color: c.border),

          // ── Chat area ──
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(suggestions: _suggestions, onTap: _send)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _messages.length) {
                        return const _TypingBubble();
                      }
                      return _ChatBubble(msg: _messages[i]);
                    },
                  ),
          ),

          // ── Input row ──
          Container(
            decoration: BoxDecoration(
              color: c.bgElevated,
              border: Border(top: BorderSide(color: c.border)),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  10,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border),
                    ),
                    child: TextField(
                      controller: _ctrl,
                      style: AppType.body(size: 14, color: c.text),
                      decoration: InputDecoration(
                        hintText: 'Ask anything about your business…',
                        hintStyle: AppType.body(size: 13, color: c.textFaint),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        isDense: true,
                      ),
                      onSubmitted: _send,
                      textInputAction: TextInputAction.send,
                      maxLines: null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(_ctrl.text),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: c.teal,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────
class _Msg {
  final String text;
  final bool fromUser;
  _Msg({required this.text, required this.fromUser});
}

// ── Chat bubble ───────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final _Msg msg;
  const _ChatBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (msg.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.teal,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(msg.text,
              style: AppType.body(size: 14, color: Colors.white)),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(right: 8, bottom: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c.navy, c.navyDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
          ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12, right: 56),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: c.bgInset,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(msg.text,
                  style: AppType.body(size: 14, color: c.text)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.bgInset,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx, child) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dot(c, _ctrl.value),
              const SizedBox(width: 4),
              _dot(c, (_ctrl.value + 0.33) % 1.0),
              const SizedBox(width: 4),
              _dot(c, (_ctrl.value + 0.66) % 1.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(AppColorsX c, double phase) {
    final t = (1.0 - (phase * 2.0 - 1.0).abs()).clamp(0.0, 1.0);
    return Opacity(
      opacity: t * 0.8 + 0.2,
      child: Container(
        width: 6, height: 6,
        decoration: BoxDecoration(color: c.textMuted, shape: BoxShape.circle),
      ),
    );
  }
}

// ── Empty state with suggestions ──────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onTap;
  const _EmptyState({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.navy, c.navyDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.auto_awesome, size: 36, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text('How can I help you today?',
            style: AppType.display(size: 22, color: c.text)),
        const SizedBox(height: 8),
        Text(
          'Ask me about your finances, draft messages, get insights, or report an issue. I\'m here 24/7.',
          style: AppType.body(size: 14, color: c.textMuted),
        ),
        const SizedBox(height: 28),
        Text('Try asking…',
            style: AppType.body(size: 13, weight: FontWeight.w600, color: c.textMuted)),
        const SizedBox(height: 12),
        ...suggestions.map(
          (s) => GestureDetector(
            onTap: () => onTap(s),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(s,
                        style: AppType.body(size: 13, color: c.text)),
                  ),
                  Icon(Icons.arrow_forward, size: 14, color: c.teal),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
