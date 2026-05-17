import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Wraps the Groq Chat Completions API — free tier, no credit card needed.
///
/// The API key is loaded from assets/.env at app startup via flutter_dotenv.
/// Get a free key at: https://console.groq.com/keys
///
/// Groq uses the same request/response shape as OpenAI's chat completions,
/// so switching models is just changing [_model].
class GroqService {
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  // llama-3.3-70b-versatile is Groq's best free model as of 2025.
  static const String _model = 'llama-3.3-70b-versatile';
  static const int _maxTokens = 1024;

  /// Sends [userMessage] to Groq and returns the assistant's reply text.
  Future<String> getChatResponse(String userMessage) async {
    final apiKey = dotenv.env['GROQ_API_KEY'];

    if (apiKey == null || apiKey.isEmpty || apiKey == 'your-groq-key-here') {
      throw Exception(
        'GROQ_API_KEY not set. Open assets/.env and paste your key from https://console.groq.com/keys',
      );
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': userMessage},
        ],
        'max_tokens': _maxTokens,
      }),
    );

    if (response.statusCode == 200) {
      // Same shape as OpenAI: { choices: [ { message: { content: '...' } } ] }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('Groq API error ${response.statusCode}: ${response.body}');
    }
  }
}
