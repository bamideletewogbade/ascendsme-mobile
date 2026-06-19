import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../core/models.dart';
import '../core/mock_data.dart';
import 'app_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AIService — fronts a chain of providers and tries them in priority order.
// Each provider may expose multiple model attempts that run sequentially until
// one succeeds. If every provider and model fails, a graceful fallback string
// is returned.
//
// ── How to swap / reorder models ────────────────────────────────────────────
// The [_models] list at the bottom of this file is the single source of truth.
// Add, remove, or reorder entries to change the fallback chain:
//
//     static final List<_ModelAttempt> _models = [
//       // OpenCode Zen (free tier — trial-use)
//       _OpenCodeModel(model: 'opencode/nemotron-3-ultra-free'),
//       _OpenCodeModel(model: 'opencode/deepseek-v4-flash-free'),
//
//       // Groq (fast LPU inference, free developer tier — 1,000 TPM)
//       _GroqModel(model: 'llama-3.3-70b-versatile'),
//       _GroqModel(model: 'llama-3.1-8b-instant'),
//
//       // OpenRouter (free models via :free suffix + catch-all router)
//       _OpenRouterModel(model: 'meta-llama/llama-3.3-70b-instruct:free'),
//       _OpenRouterModel(model: 'meta-llama/llama-3.1-8b-instruct:free'),
//       _OpenRouterModel(model: 'openrouter/free'),  // auto-routes to any free model
//     ];
//
// Providers with empty API keys in AppConfig (or uninitialized Firebase) are
// skipped at runtime.
// ─────────────────────────────────────────────────────────────────────────────

class AIService {
  static const Duration _timeoutGroq = Duration(seconds: 15);
  static const Duration _timeoutOpenRouter = Duration(seconds: 20);
  static const Duration _timeoutOpenCode = Duration(seconds: 20);

  /// Send a prompt with business context. Returns the AI response text or
  /// `'(AI unavailable — try again in a moment)'` if every model/provider in
  /// the chain fails.
  static Future<String> ask(
    String userPrompt, {
    int maxSentences = 3,
    String? extraContext,
    Business? business,
    Financials? financials,
  }) async {
    final ctx = extraContext ?? buildBizContext(business, financials);
    final full =
        '$ctx\n\nUser asks: $userPrompt\n\nRespond in at most $maxSentences short sentences. No markdown formatting.';

    final sw = Stopwatch()..start();
    final failures = <String>[];

    for (final model in _models) {
      if (!model.isConfigured) {
        log.debug('AIService.ask — skipping ${model.name} (no key)');
        continue;
      }
      try {
        final result = await model.ask(full);
        if (result.trim().isEmpty) {
          throw Exception('empty response');
        }
        log.info(
            'AIService.ask — ok via ${model.name} (${sw.elapsedMilliseconds}ms)');
        return result.trim();
      } catch (e, st) {
        log.warning('AIService.ask — ${model.name} failed: $e',
            error: e, stackTrace: st);
        failures.add('${model.name}: $e');
        // Continue to next model in chain.
      }
    }

    log.error('AIService.ask — all models failed',
        error: Exception('No working AI model: ${failures.join(' | ')}'));
    return '(AI unavailable — try again in a moment)';
  }

  /// Specialized: parse a natural-language invoice description into JSON.
  /// Same fallback semantics as [ask].
  static Future<Map<String, dynamic>?> parseInvoice(String description) async {
    log.debug('parseInvoice — desc="$description"');
    const systemPrompt = '''You are a JSON-only assistant inside an invoicing app.
Extract the customer name and total amount in GHS from the user description.
Return STRICTLY a JSON object: {"customer":"...","amount":0}
No prose, no markdown, just the JSON.''';

    for (final model in _models) {
      if (!model.isConfigured) continue;
      try {
        final raw = await model.parseInvoice(systemPrompt, description);
        final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
        if (match == null) {
          throw Exception('no JSON object in response');
        }
        final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        log.debug(
            'parseInvoice — ok via ${model.name} customer="${parsed['customer']}" amount=${parsed['amount']}');
        return parsed;
      } catch (e) {
        log.warning('parseInvoice — ${model.name} failed: $e');
        // Try next.
      }
    }
    log.warning('parseInvoice — all models failed');
    return null;
  }

}

// ─── Model attempt interface ────────────────────────────────────────────────

abstract class _ModelAttempt {
  String get name;
  bool get isConfigured;
  Future<String> ask(String prompt);
  Future<String> parseInvoice(String systemPrompt, String description);
}

// ── Groq (fast LPU inference — free developer tier, 1,000 TPM / 1,000 RPM) ─

class _GroqModel implements _ModelAttempt {
  final String model;
  _GroqModel({required this.model});

  @override
  String get name => 'groq ($model)';

  @override
  bool get isConfigured => AppConfig.groqApiKey.isNotEmpty;

  @override
  Future<String> ask(String prompt) async {
    final response = await http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${AppConfig.groqApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'max_tokens': 256,
            'temperature': 0.7,
          }),
        )
        .timeout(AIService._timeoutGroq);
    if (response.statusCode != 200) {
      throw Exception('Groq ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return ((data['choices'][0]['message']['content'] as String?) ?? '').trim();
  }

  @override
  Future<String> parseInvoice(String systemPrompt, String description) async {
    final resp = await http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${AppConfig.groqApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': description},
            ],
            'max_tokens': 60,
            'temperature': 0,
          }),
        )
        .timeout(AIService._timeoutGroq);
    if (resp.statusCode != 200) {
      throw Exception('Groq ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    return (data['choices'][0]['message']['content'] as String?) ?? '';
  }
}

// ── OpenCode Zen (free tier — Nemotron 3 Ultra, DeepSeek V4 Flash) ─────────

class _OpenCodeModel implements _ModelAttempt {
  final String model;
  _OpenCodeModel({required this.model});

  @override
  String get name => 'opencode ($model)';

  @override
  bool get isConfigured => AppConfig.opencodeApiKey.isNotEmpty;

  @override
  Future<String> ask(String prompt) async {
    final response = await http
        .post(
          Uri.parse('https://opencode.ai/zen/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${AppConfig.opencodeApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'max_tokens': 256,
            'temperature': 0.7,
          }),
        )
        .timeout(AIService._timeoutOpenCode);
    if (response.statusCode != 200) {
      throw Exception('OpenCode ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return ((data['choices'][0]['message']['content'] as String?) ?? '').trim();
  }

  @override
  Future<String> parseInvoice(String systemPrompt, String description) async {
    final resp = await http
        .post(
          Uri.parse('https://opencode.ai/zen/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${AppConfig.opencodeApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': description},
            ],
            'max_tokens': 60,
            'temperature': 0,
          }),
        )
        .timeout(AIService._timeoutOpenCode);
    if (resp.statusCode != 200) {
      throw Exception('OpenCode ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    return (data['choices'][0]['message']['content'] as String?) ?? '';
  }
}

// ── OpenRouter (free models via :free suffix + openrouter/free router) ──────

class _OpenRouterModel implements _ModelAttempt {
  final String model;
  _OpenRouterModel({required this.model});

  @override
  String get name => 'openrouter ($model)';

  @override
  bool get isConfigured => AppConfig.openRouterApiKey.isNotEmpty;

  @override
  Future<String> ask(String prompt) async {
    final response = await http
        .post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${AppConfig.openRouterApiKey}',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://ascendsme.app',
            'X-Title': 'AscendSME Mobile',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'max_tokens': 256,
            'temperature': 0.7,
          }),
        )
        .timeout(AIService._timeoutOpenRouter);
    if (response.statusCode != 200) {
      throw Exception('OpenRouter ${response.statusCode}: ${response.body}');
    }
    final data = jsonDecode(response.body);
    return ((data['choices'][0]['message']['content'] as String?) ?? '').trim();
  }

  @override
  Future<String> parseInvoice(String systemPrompt, String description) async {
    final resp = await http
        .post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${AppConfig.openRouterApiKey}',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://ascendsme.app',
            'X-Title': 'AscendSME Mobile',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': description},
            ],
            'max_tokens': 60,
            'temperature': 0,
          }),
        )
        .timeout(AIService._timeoutOpenRouter);
    if (resp.statusCode != 200) {
      throw Exception('OpenRouter ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body);
    return (data['choices'][0]['message']['content'] as String?) ?? '';
  }
}

// ── Model chain (single source of truth — add/remove/reorder freely) ────────
//
// Priority order: fastest first, fallbacks later.
// Empty-keyed providers are skipped at runtime.
//
// Quick reference:
//   OpenCode  → REST API /v1/chat/completions at opencode.ai/zen
//               • Nemotron 3 Ultra + DeepSeek V4 Flash (free tier)
//   Groq      → REST API /v1/chat/completions (free dev tier: 1,000 TPM/RPM)
//   OpenRouter→ REST API /v1/chat/completions (free via :free suffix)
//               • `openrouter/free` auto-routes to any available free model
//
final List<_ModelAttempt> _models = [
  // ── OpenCode Zen (free tier) ─────────────────────────────────────────────
  // Nemotron 3 Ultra is a powerful general-purpose model (trial-use free).
  // DeepSeek V4 Flash is a fast fallback for coding and reasoning tasks.
  _OpenCodeModel(model: 'opencode/nemotron-3-ultra-free'),
  _OpenCodeModel(model: 'opencode/deepseek-v4-flash-free'),

  // ── Groq ─────────────────────────────────────────────────────────────────
  // Fast LPU inference. Free developer tier — generates text faster than
  // any other provider here.
  _GroqModel(model: 'llama-3.3-70b-versatile'),
  _GroqModel(model: 'llama-3.1-8b-instant'),

  // ── OpenRouter ───────────────────────────────────────────────────────────
  // Free models via :free suffix. The `openrouter/free` router is a catch-all
  // that auto-selects any currently-free model on the platform.
  _OpenRouterModel(model: 'meta-llama/llama-3.3-70b-instruct:free'),
  _OpenRouterModel(model: 'meta-llama/llama-3.1-8b-instruct:free'),
  _OpenRouterModel(model: 'openrouter/free'),
];
