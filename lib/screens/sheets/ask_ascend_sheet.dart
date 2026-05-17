import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../config.dart';
import '../../state/app_state.dart';
import '../../services/ai_service.dart';

class AskAscendSheet extends StatefulWidget {
  final String? initialPrompt;

  const AskAscendSheet({super.key, this.initialPrompt});

  @override
  State<AskAscendSheet> createState() => _AskAscendSheetState();
}

class _AskAscendSheetState extends State<AskAscendSheet> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];
  bool _loading = false;

  static const _suggestions = [
    'What should I focus on today?',
    'How is my business doing this month?',
    'Help me draft a follow-up reminder',
    'Explain my cash flow',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _send(widget.initialPrompt!));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _loading) return;
    // Capture the live business profile + financials so the AI grounds its
    // answer in the signed-in user's actual numbers (not the mock).
    final appState = context.read<AppState>();
    final business = appState.business;
    final financials = appState.financials;
    setState(() {
      _messages.add(_Msg(text: prompt, fromUser: true));
      _loading = true;
    });
    _ctrl.clear();
    _scrollToBottom();
    final reply = await AIService.ask(prompt,
        maxSentences: 5, business: business, financials: financials);
    if (mounted) {
      setState(() {
        _messages.add(_Msg(text: reply, fromUser: false));
        _loading = false;
      });
      _scrollToBottom();
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: c.bgElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SheetHandle(),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.teal, c.tealDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ask Ascend',
                          style: AppType.heading(size: 16, color: c.text)),
                      Text('Powered by ${state.aiModel.label}',
                          style: AppType.body(size: 11, color: c.textMuted)),
                    ],
                  ),
                ),
                // Model picker button
                GestureDetector(
                  onTap: () => _showModelPicker(context, state),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.bgInset,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.aiModel.badge.isNotEmpty
                              ? state.aiModel.badge
                              : 'Model',
                          style:
                              AppType.body(size: 11, color: c.textMuted),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.expand_more, size: 13, color: c.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),

          // Chat area
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(
                    suggestions: _suggestions, onTap: _send)
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

          // Input row
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
                    10),
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
                        hintStyle:
                            AppType.body(size: 13, color: c.textFaint),
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

  void _showModelPicker(BuildContext context, AppState state) {
    final c = context.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 4),
            Text('Choose AI model',
                style: AppType.heading(size: 18, color: c.text)),
            const SizedBox(height: 8),
            Text(
              'Gemini: free Google AI Studio quota.\nGroq: fast LPU inference, free tier.\nOpenRouter: broad catalogue, free tier.',
              style: AppType.body(size: 12, color: c.textMuted),
            ),
            const SizedBox(height: 16),
            ...AIModel.values.map(
              (model) => GestureDetector(
                onTap: () {
                  state.setAiModel(model);
                  Navigator.pop(ctx);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: state.aiModel == model
                        ? c.tealSurface
                        : c.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: state.aiModel == model
                          ? c.tealSurfaceStrong
                          : c.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(model.label,
                                style: AppType.body(
                                    size: 14,
                                    weight: FontWeight.w600,
                                    color: c.text)),
                            Text(
                              switch (model.provider) {
                                AIProvider.gemini =>
                                  'Google Gemini · 1,500 free req/day',
                                AIProvider.groq =>
                                  'Groq · Fast LPU inference',
                                AIProvider.openRouter =>
                                  'OpenRouter · Free tier',
                              },
                              style: AppType.body(
                                  size: 11.5, color: c.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (model.badge.isNotEmpty)
                        AppPill(model.badge,
                            tone: PillTone.teal, small: true),
                      if (state.aiModel == model) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle,
                            size: 18, color: c.teal),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                colors: [c.teal, c.tealDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
          ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12, right: 56),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        decoration: BoxDecoration(
            color: c.textMuted, shape: BoxShape.circle),
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
        const SizedBox(height: 8),
        Text('Try asking…',
            style: AppType.body(
                size: 13, weight: FontWeight.w600, color: c.textMuted)),
        const SizedBox(height: 12),
        ...suggestions.map(
          (s) => GestureDetector(
            onTap: () => onTap(s),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
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
