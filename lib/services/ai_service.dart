import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../core/models.dart';
import '../core/mock_data.dart';
import 'app_logger.dart';

// ─────────────────────────────────────────────
// AIService — Gemini first, Groq for fast Llama, OpenRouter as fallback.
// Switch models at runtime via AIService.currentModel.
//
// Fallback: if the selected provider fails (bad key, rate-limit, timeout),
// ask() automatically tries the other providers before giving up.
// ─────────────────────────────────────────────
class AIService {
  static AIModel _currentModel = AIModel.geminiFlash;

  static AIModel get currentModel => _currentModel;

  static void setModel(AIModel model) {
    _currentModel = model;
  }

  /// Send a prompt with business context. Returns the AI response text.
  /// Pass `business` and `financials` to ground the AI in the real signed-in
  /// profile; omit them to use mock fallbacks (useful from places without
  /// AppState).
  ///
  /// The business context is sent as a system message (or system-role prefix
  /// for Gemini) so the model treats it as grounding, not as user
  /// instructions. If the primary provider fails, we try the remaining
  /// providers in order: Gemini → Groq → OpenRouter.
  static Future<String> ask(
    String userPrompt, {
    int maxSentences = 5,
    String? extraContext,
    Business? business,
    Financials? financials,
  }) async {
    final systemCtx = extraContext ?? buildBizContext(business, financials);

    log.debug(
        'AIService.ask — model=${_currentModel.id} provider=${_currentModel.provider.name} promptLen=${userPrompt.length}');
    final sw = Stopwatch()..start();

    // Build the provider order: current first, then the rest as fallbacks.
    final providers = <AIModel>[
      _currentModel,
      ..._fallbackModels(_currentModel),
    ];

    for (final model in providers) {
      try {
        final result = await _dispatch(model, systemCtx, userPrompt);
        if (result.startsWith('(Add your')) {
          // Missing API key — skip to next provider silently.
          log.debug(
              'AIService.ask — ${model.provider.name} skipped (no API key)');
          continue;
        }
        log.info(
            'AIService.ask — ok via ${model.provider.name} responseLen=${result.length} (${sw.elapsedMilliseconds}ms)');
        return result;
      } catch (e, st) {
        log.warning(
            'AIService.ask — ${model.provider.name} failed, trying next',
            error: e,
            stackTrace: st);
        continue;
      }
    }

    log.error('AIService.ask — all providers failed',
        error: 'exhausted fallback chain');
    return '(AI unavailable — check your connection and try again in a moment)';
  }

  /// Specialized: parse a natural-language invoice description into JSON.
  static Future<Map<String, dynamic>?> parseInvoice(String description) async {
    log.debug(
        'parseInvoice — model=${_currentModel.id} desc="$description"');
    const systemPrompt = '''You are a JSON-only assistant inside an invoicing app for Ghanaian SMEs.
Extract the customer name and total amount from the user's description.
Rules:
- Assume amounts are in GHS unless another currency is explicitly stated.
- If the user gives a description but no customer name, set customer to an empty string.
- If the user gives a description but no amount, set amount to 0.
- Return STRICTLY a JSON object with this shape: {"customer":"...","amount":0}
- No prose, no markdown, no explanation — just the JSON object.''';

    // Build the provider order: current first, then fallbacks.
    final providers = <AIModel>[
      _currentModel,
      ..._fallbackModels(_currentModel),
    ];

    try {
      for (final model in providers) {
        try {
          final result = await _dispatch(
            model,
            systemPrompt,
            description,
            maxTokens: 60,
            temperature: 0,
          );
          if (result.startsWith('(Add your')) continue;

          final match = RegExp(r'\{[\s\S]*\}').firstMatch(result);
          if (match != null) {
            final parsed =
                jsonDecode(match.group(0)!) as Map<String, dynamic>;
            log.debug(
                'parseInvoice — parsed customer="${parsed['customer']}" amount=${parsed['amount']}');
            return parsed;
          }
          log.warning(
              'parseInvoice — no JSON object found in ${model.provider.name} response: "$result"');
        } catch (e, st) {
          log.warning(
              'parseInvoice — ${model.provider.name} failed, trying next',
              error: e,
              stackTrace: st);
          continue;
        }
      }
    } catch (e, st) {
      log.error('parseInvoice failed', error: e, stackTrace: st);
    }
    return null;
  }

  // ── Provider dispatch ──────────────────────────────────────────────────────

  /// Unified dispatch to any provider. Splits system/user messages properly
  /// for each API format.
  static Future<String> _dispatch(
    AIModel model,
    String systemPrompt,
    String userMessage, {
    int maxTokens = 256,
    double temperature = 0.7,
  }) async {
    switch (model.provider) {
      case AIProvider.gemini:
        return _gemini(model, systemPrompt, userMessage,
            maxTokens: maxTokens, temperature: temperature);
      case AIProvider.groq:
        return _groq(model, systemPrompt, userMessage,
            maxTokens: maxTokens, temperature: temperature);
      case AIProvider.openRouter:
        return _openRouter(model, systemPrompt, userMessage,
            maxTokens: maxTokens, temperature: temperature);
    }
  }

  // ── Gemini ─────────────────────────────────
  static Future<String> _gemini(
    AIModel model,
    String systemPrompt,
    String userMessage, {
    required int maxTokens,
    required double temperature,
  }) async {
    if (AppConfig.geminiApiKey.isEmpty) {
      return '(Add your Gemini API key in lib/config.dart to enable AI · Get one free at aistudio.google.com)';
    }
    final generativeModel = GenerativeModel(
      model: model.id,
      apiKey: AppConfig.geminiApiKey,
      systemInstruction: Content.text(systemPrompt),
      generationConfig: GenerationConfig(
        maxOutputTokens: maxTokens,
        temperature: temperature,
      ),
    );
    final response = await generativeModel
        .generateContent([Content.text(userMessage)]);
    return (response.text ?? '').trim();
  }

  // ── Groq (LPU inference — fast, OpenAI-compatible) ─────────────────────
  static Future<String> _groq(
    AIModel model,
    String systemPrompt,
    String userMessage, {
    required int maxTokens,
    required double temperature,
  }) async {
    if (AppConfig.groqApiKey.isEmpty) {
      return '(Add your Groq API key in lib/config.dart · Free at console.groq.com)';
    }
    final response = await http
        .post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${AppConfig.groqApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model.id,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userMessage},
            ],
            'max_tokens': maxTokens,
            'temperature': temperature,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ((data['choices'][0]['message']['content'] as String?) ?? '')
          .trim();
    }
    throw Exception('Groq ${response.statusCode}: ${response.body}');
  }

  // ── OpenRouter (Llama / any free model) ────
  static Future<String> _openRouter(
    AIModel model,
    String systemPrompt,
    String userMessage, {
    required int maxTokens,
    required double temperature,
  }) async {
    if (AppConfig.openRouterApiKey.isEmpty) {
      return '(Add your OpenRouter API key in lib/config.dart · Free at openrouter.ai)';
    }
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
            'model': model.id,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userMessage},
            ],
            'max_tokens': maxTokens,
            'temperature': temperature,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ((data['choices'][0]['message']['content'] as String?) ?? '')
          .trim();
    }
    throw Exception('OpenRouter ${response.statusCode}: ${response.body}');
  }

  // ── Fallback ordering ─────────────────────────────────────────────────────
  /// Returns one fallback model per provider that isn't the current model's
  /// provider, in preference order: Gemini → Groq → OpenRouter.
  static List<AIModel> _fallbackModels(AIModel current) {
    const fallbacks = {
      AIProvider.gemini: AIModel.geminiFlash,
      AIProvider.groq: AIModel.groqLlama33,
      AIProvider.openRouter: AIModel.llama33,
    };
    return [AIProvider.gemini, AIProvider.groq, AIProvider.openRouter]
        .where((p) => p != current.provider)
        .map((p) => fallbacks[p]!)
        .toList();
  }
}
