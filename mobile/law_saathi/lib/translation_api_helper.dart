import 'dart:developer';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:LawSaathi/app_secrets.dart';

class TranslationApiHelper {
  // API endpoints for translation
  static const String apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  static const String apiKey = AppSecrets.geminiApiKey;

  // List of supported languages
  static final List<String> supportedLanguages = [
    'Original',
    'हिन्दी',
    'தமிழ்',
    'తెలుగు',
    'ಕನ್ನಡ',
    'മലയാളം',
  ];

  // Method to translate text to the selected language
  static Future<String> translateText(
      String text, String targetLanguage) async {
    // If target language is Original, just return the original text
    if (targetLanguage == 'Original') {
      return text;
    }

    log('Translating text to $targetLanguage');

    try {
      // Create translation prompt
      final Map<String, dynamic> payload = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text":
                    """Translate the following text to $targetLanguage. Keep the translation simple, natural, and accurate. Only respond with the translated text, no explanations or additional text.

Text to translate: $text"""
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.2, // Lower temperature for more accurate translation
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
        }
      };

      final response = await http.post(
        Uri.parse('$apiUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translatedText =
            data['candidates'][0]['content']['parts'][0]['text'];

        // Clean up the response - remove any explanations or prefixes that might come with the translation
        final cleanedTranslation = _cleanTranslationResponse(translatedText);

        log('Translation successful');
        return cleanedTranslation;
      } else {
        log('Translation API Error: ${response.statusCode}');
        log('Response body: ${response.body}');

        // Try fallback model if primary fails
        return await _fallbackTranslate(text, targetLanguage);
      }
    } catch (e) {
      log('Error during translation: $e');
      return await _fallbackTranslate(text, targetLanguage);
    }
  }

  // Fallback translation method using a different model
  static Future<String> _fallbackTranslate(
      String text, String targetLanguage) async {
    log('Attempting fallback translation');

    try {
      // Fallback URL with more reliable model
      const fallbackUrl =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

      final Map<String, dynamic> payload = {
        "contents": [
          {
            "role": "user",
            "parts": [
              {
                "text":
                    """Translate the following text to $targetLanguage. Keep the translation simple, natural, and accurate. Only respond with the translated text, no explanations or additional text.

Text to translate: $text"""
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.2,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
        }
      };

      final fallbackResponse = await http.post(
        Uri.parse('$fallbackUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (fallbackResponse.statusCode == 200) {
        log('Successful response from fallback translation model');
        final fallbackData = jsonDecode(fallbackResponse.body);
        final fallbackText =
            fallbackData['candidates'][0]['content']['parts'][0]['text'];

        // Clean up the response
        return _cleanTranslationResponse(fallbackText);
      } else {
        throw Exception(
            'Fallback translation also failed: ${fallbackResponse.statusCode}');
      }
    } catch (e) {
      log('Fallback translation failed: $e');
      return "Translation unavailable. Please try again later.";
    }
  }

  // Helper method to clean translation responses
  static String _cleanTranslationResponse(String response) {
    // Remove common prefixes that the model might add
    final prefixesToRemove = [
      'Here is the translation:',
      'Translated text:',
      'Translation:',
    ];

    String cleaned = response.trim();

    for (var prefix in prefixesToRemove) {
      if (cleaned.startsWith(prefix)) {
        cleaned = cleaned.substring(prefix.length).trim();
      }
    }

    // Remove quotes if the model put them around the translation
    if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }

    return cleaned;
  }
}
