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
// ─────────────────────────────────────────────
class AIService {
  static AIModel _currentModel = AIModel.groqLlama33;

  static AIModel get currentModel => _currentModel;

  static void setModel(AIModel model) {
    _currentModel = model;
  }

  /// Send a prompt with business context. Returns the AI response text.
  /// Pass `business` and `financials` to ground the AI in the real signed-in
  /// profile; omit them to use mock fallbacks (useful from places without
  /// AppState).
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

    log.debug('AIService.ask — model=${_currentModel.id} provider=${_currentModel.provider.name} promptLen=${full.length}');
    final sw = Stopwatch()..start();
    try {
      String result;
      switch (_currentModel.provider) {
        case AIProvider.gemini:
          result = await _gemini(full);
        case AIProvider.groq:
          result = await _groq(full);
        case AIProvider.openRouter:
          result = await _openRouter(full);
      }
      log.info('AIService.ask — ok responseLen=${result.length} (${sw.elapsedMilliseconds}ms)');
      return result;
    } catch (e, st) {
      log.error('AIService.ask failed', error: e, stackTrace: st);
      return '(AI unavailable — try again in a moment)';
    }
  }

  // ── Gemini ─────────────────────────────────
  static Future<String> _gemini(String prompt) async {
    if (AppConfig.geminiApiKey.isEmpty) {
      return '(Add your Gemini API key in lib/config.dart to enable AI · Get one free at aistudio.google.com)';
    }
    final model = GenerativeModel(
      model: _currentModel.id,
      apiKey: AppConfig.geminiApiKey,
      generationConfig: GenerationConfig(
        maxOutputTokens: 256,
        temperature: 0.7,
      ),
    );
    final response = await model.generateContent([Content.text(prompt)]);
    return (response.text ?? '').trim();
  }

  // ── Groq (LPU inference — fast, OpenAI-compatible) ─────────────────────
  static Future<String> _groq(String prompt) async {
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
            'model': _currentModel.id,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'max_tokens': 256,
            'temperature': 0.7,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ((data['choices'][0]['message']['content'] as String?) ?? '').trim();
    }
    throw Exception('Groq ${response.statusCode}: ${response.body}');
  }

  // ── OpenRouter (Llama / any free model) ────
  static Future<String> _openRouter(String prompt) async {
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
            'model': _currentModel.id,
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
            'max_tokens': 256,
            'temperature': 0.7,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return ((data['choices'][0]['message']['content'] as String?) ?? '').trim();
    }
    throw Exception('OpenRouter ${response.statusCode}: ${response.body}');
  }

  /// Specialized: parse a natural-language invoice description into JSON.
  static Future<Map<String, dynamic>?> parseInvoice(String description) async {
    log.debug('parseInvoice — model=${_currentModel.id} desc="$description"');
    const systemPrompt = '''You are a JSON-only assistant inside an invoicing app.
Extract the customer name and total amount in GHS from the user description.
Return STRICTLY a JSON object: {"customer":"...","amount":0}
No prose, no markdown, just the JSON.''';

    try {
      String result;
      switch (_currentModel.provider) {
        case AIProvider.gemini:
          if (AppConfig.geminiApiKey.isEmpty) return null;
          final model = GenerativeModel(
            model: _currentModel.id,
            apiKey: AppConfig.geminiApiKey,
            generationConfig:
                GenerationConfig(maxOutputTokens: 60, temperature: 0),
          );
          final resp = await model.generateContent(
              [Content.text('$systemPrompt\n\nUser: $description')]);
          result = resp.text ?? '';
          break;
        case AIProvider.groq:
          if (AppConfig.groqApiKey.isEmpty) return null;
          final resp = await http
              .post(
                Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
                headers: {
                  'Authorization': 'Bearer ${AppConfig.groqApiKey}',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'model': _currentModel.id,
                  'messages': [
                    {'role': 'system', 'content': systemPrompt},
                    {'role': 'user', 'content': description},
                  ],
                  'max_tokens': 60,
                  'temperature': 0,
                }),
              )
              .timeout(const Duration(seconds: 15));
          result = resp.statusCode == 200
              ? (jsonDecode(resp.body)['choices'][0]['message']['content'] ?? '')
              : '';
          break;
        case AIProvider.openRouter:
          if (AppConfig.openRouterApiKey.isEmpty) return null;
          final resp = await http
              .post(
                Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
                headers: {
                  'Authorization': 'Bearer ${AppConfig.openRouterApiKey}',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'model': _currentModel.id,
                  'messages': [
                    {'role': 'system', 'content': systemPrompt},
                    {'role': 'user', 'content': description},
                  ],
                  'max_tokens': 60,
                  'temperature': 0,
                }),
              )
              .timeout(const Duration(seconds: 20));
          result = resp.statusCode == 200
              ? (jsonDecode(resp.body)['choices'][0]['message']['content'] ?? '')
              : '';
          break;
      }
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(result);
      if (match != null) {
        final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        log.debug('parseInvoice — parsed customer="${parsed['customer']}" amount=${parsed['amount']}');
        return parsed;
      }
      log.warning('parseInvoice — no JSON object found in response: "$result"');
    } catch (e, st) {
      log.error('parseInvoice failed', error: e, stackTrace: st);
    }
    return null;
  }
}
