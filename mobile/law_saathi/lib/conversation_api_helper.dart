import 'dart:developer';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:LawSaathi/app_secrets.dart';

class ConversationApiHelper {
  // API endpoints remain the same
  static const String apiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent';
  static const String apiKey = AppSecrets.geminiApiKey;

  // To store conversation history
  static final List<Map<String, dynamic>> _conversationHistory = [];

  // Improved system prompt with better prompt engineering
  static const String _systemPrompt = """
  You are LawSaathi, an AI legal assistant specialized in Indian law. Follow these directives carefully:

  ## Response Classification
  - For greetings or casual conversation: Be conversational and human-like, without mentioning law
  - For legal questions: Provide precise legal information with mandatory section citations
  
  ## For Legal Questions:
  1. START with relevant section numbers in bold (e.g., "**Section 319 BNS**")
  2. ALWAYS include at least one specific section number from the applicable law
  3. Keep explanations under 3 sentences unless detailed information is requested
  4. For criminal matters, cite the Bharatiya Nyaya Sanhita (BNS) 
  5. Mention other relevant specialized laws when applicable
  
  ## Response Format
  - Use **bold** for section numbers and important legal terms
  - Structure: [Section citation] → [1-2 sentence explanation] → [brief consequence]
  
  ## Examples:
  QUERY: "What happens if I hit someone?"
  RESPONSE: "**Section 319 BNS** defines causing bodily hurt as an offense punishable with imprisonment up to 1 year or fine or both. The severity of punishment increases under **Section 324 BNS** if a dangerous weapon is used."
  
  QUERY: "Hi there"
  RESPONSE: "Hello! How can I help you today?"
  
  QUERY: "Can landlords evict without notice?"
  RESPONSE: "**Section 106 of Transfer of Property Act** requires landlords to provide proper notice before evicting tenants in periodic tenancies. The notice period typically equals the tenancy period (monthly/yearly) as per **Section 111** of the same Act."
  """;

  // Set of common greetings and casual phrases - keeping this from previous version
  static final Set<String> _casualPhrases = {
    'hi',
    'hello',
    'hey',
    'good morning',
    'good afternoon',
    'good evening',
    'how are you',
    'how\'s it going',
    'what\'s up',
    'namaste',
    'hola',
    'greetings',
    'yo',
    'sup',
    'howdy'
  };

  // Initialize the conversation with the system prompt
  static Future<void> initializeConversation() async {
    // Clear any existing conversation
    _conversationHistory.clear();

    // Add the system prompt to guide the AI
    _conversationHistory.add({
      "role": "user",
      "parts": [
        {"text": _systemPrompt}
      ]
    });

    // Get initial acknowledgment from the model (hidden from user)
    await _getInitialResponse();
  }

  // Get initial response from the model to set the context
  static Future<void> _getInitialResponse() async {
    try {
      final payload = {
        "contents": _conversationHistory,
        "generationConfig": {
          "temperature":
              0.1, // Lower for more deterministic response to system prompt
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
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'];

        // Add model's acknowledgment to history (but don't show to user)
        _conversationHistory.add({
          "role": "model",
          "parts": [
            {"text": responseText}
          ]
        });
      } else {
        log('Failed to initialize legal assistant context: ${response.statusCode}');
      }
    } catch (e) {
      log('Error initializing legal assistant: $e');
    }
  }

  // Check if a message is likely just a casual greeting
  static bool _isGreeting(String message) {
    final lowerMessage = message.toLowerCase().trim();

    // Check if the message matches any casual greeting in our set
    return _casualPhrases.contains(lowerMessage) ||
        _casualPhrases.any((greeting) => lowerMessage.startsWith(greeting));
  }

  static Future<String> sendMessage(String message) async {
    // Initialize conversation if this is the first message
    if (_conversationHistory.isEmpty) {
      await initializeConversation();
    }

    // Add user message to conversation history
    _conversationHistory.add({
      "role": "user",
      "parts": [
        {"text": message}
      ]
    });

    // Check if the message is a casual greeting
    final bool isGreeting = _isGreeting(message);

    // User-specific prompt to guide this specific response
    String userPrompt;
    if (isGreeting) {
      userPrompt = """
      This is a greeting or casual message. 
      Respond in a friendly, conversational way without mentioning anything about law.
      Keep it brief and natural, like a normal chat conversation.
      """;
    } else {
      userPrompt = """
      This is a legal query that requires a precise response.
      
      1. Your response MUST begin with a specific section citation in bold (e.g., "**Section 319 BNS**")
      2. Provide a 1-2 sentence explanation of the legal position
      3. Briefly mention the consequences/penalties if applicable
      4. Keep total response under 3 sentences unless detailed explanation is requested
      5. Use proper legal terminology and be accurate with section numbers
      
      DO NOT use vague phrases like "relevant sections" - always cite specific section numbers.
      """;
    }

    // Add this prompt to the conversation
    _conversationHistory.add({
      "role": "user",
      "parts": [
        {"text": userPrompt}
      ]
    });

    // Prepare the request payload
    final payload = {
      "contents": _conversationHistory,
      "generationConfig": {
        "temperature": isGreeting
            ? 0.7
            : 0.2, // Higher temperature for casual conversation, lower for legal precision
        "topK": 40,
        "topP": 0.95,
        "maxOutputTokens": 800,
      }
    };

    try {
      final response = await http.post(
        Uri.parse('$apiUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract the response text
        final responseText =
            data['candidates'][0]['content']['parts'][0]['text'];

        // Add assistant response to conversation history
        _conversationHistory.add({
          "role": "model",
          "parts": [
            {"text": responseText}
          ]
        });

        // Remove the handling instruction from history to keep it clean
        if (_conversationHistory.length >= 2) {
          _conversationHistory.removeAt(_conversationHistory.length - 3);
        }

        return responseText;
      } else {
        log('API Error: ${response.statusCode}');
        log('Response body: ${response.body}');

        // Try fallback to gemini-pro if the flash model fails
        return await _sendFallbackMessage(message, isGreeting);
      }
    } catch (e) {
      log('Error sending message to Gemini API: $e');

      // Try fallback
      return await _sendFallbackMessage(message, isGreeting);
    }
  }

  // Fallback method to use if the primary model fails
  static Future<String> _sendFallbackMessage(
      String message, bool isGreeting) async {
    try {
      log('Attempting fallback to gemini-pro model...');

      // Fallback URL with the more reliable model
      const fallbackUrl =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

      // User-specific prompt for fallback model, same as primary
      String userPrompt;
      if (isGreeting) {
        userPrompt = """
        This is a greeting or casual message. 
        Respond in a friendly, conversational way without mentioning anything about law.
        Keep it brief and natural, like a normal chat conversation.
        """;
      } else {
        userPrompt = """
        This is a legal query that requires a precise response.
        
        1. Your response MUST begin with a specific section citation in bold (e.g., "**Section 319 BNS**")
        2. Provide a 1-2 sentence explanation of the legal position
        3. Briefly mention the consequences/penalties if applicable
        4. Keep total response under 3 sentences unless detailed explanation is requested
        5. Use proper legal terminology and be accurate with section numbers
        
        DO NOT use vague phrases like "relevant sections" - always cite specific section numbers.
        """;
      }

      // Add this prompt to the conversation for fallback
      _conversationHistory.add({
        "role": "user",
        "parts": [
          {"text": userPrompt}
        ]
      });

      final fallbackPayload = {
        "contents": _conversationHistory,
        "generationConfig": {
          "temperature": isGreeting ? 0.7 : 0.2, // Same as primary model
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 800,
        }
      };

      final fallbackResponse = await http.post(
        Uri.parse('$fallbackUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(fallbackPayload),
      );

      if (fallbackResponse.statusCode == 200) {
        log('Successful response from fallback model');
        final fallbackData = jsonDecode(fallbackResponse.body);

        final fallbackText =
            fallbackData['candidates'][0]['content']['parts'][0]['text'];

        // Add fallback response to conversation history
        _conversationHistory.add({
          "role": "model",
          "parts": [
            {"text": fallbackText}
          ]
        });

        // Remove the handling instruction from history to keep it clean
        if (_conversationHistory.length >= 2) {
          _conversationHistory.removeAt(_conversationHistory.length - 3);
        }

        return fallbackText;
      } else {
        throw Exception(
            'Fallback model also failed: ${fallbackResponse.statusCode}');
      }
    } catch (e) {
      log('Fallback also failed: $e');
      return "I'm sorry, I'm having trouble connecting to my knowledge base right now. Please try again in a moment.";
    }
  }

  // Method to clear conversation history and reset
  static void clearConversation() {
    _conversationHistory.clear();
    initializeConversation();
  }

  // Method to get conversation history (for debugging)
  static List<Map<String, dynamic>> getConversationHistory() {
    return List.from(_conversationHistory);
  }
}
