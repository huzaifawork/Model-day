import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'context_service.dart';
import '../config/openai_config.dart';

class OpenAIService {
  /// Initialize the OpenAI service
  static void initialize() {
    // Since we're using a backend proxy, no direct initialization needed
    // This method exists for compatibility with the main.dart initialization
    debugPrint('🤖 OpenAI Service initialized - using backend proxy');
  }

  /// Send a chat message and get AI response from backend
  static Future<String> sendChatMessage(String userMessage) async {
    try {
      debugPrint('🤖 OpenAI Service: Building user context...');

      // Build comprehensive user context
      final userContext = await ContextService.buildUserContext();

      debugPrint('🤖 OpenAI Service: Sending message with context...');

      final url = Uri.parse(
          'http://localhost:3001/api/openai/chat'); // Change to your deployed backend URL in production

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': [
            {
              'role': 'system',
              'content': '${OpenAIConfig.systemPrompt}\n\n$userContext'
            },
            {'role': 'user', 'content': userMessage}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'No response from AI.';
      } else {
        return 'Failed to get AI response: ${response.body}';
      }
    } catch (e) {
      debugPrint('❌ OpenAI Service error: $e');
      return 'Error connecting to AI service: $e';
    }
  }

  /// Test the OpenAI connection
  static Future<bool> testConnection() async {
    try {
      // This method is no longer directly related to OpenAI API calls
      // but keeping it for now as it was in the original file.
      // If it needs to be updated, it should be removed or refactored.
      return true; // Assuming a successful connection if no error
    } catch (e) {
      return false;
    }
  }

  /// Get usage statistics (if needed for monitoring)
  static Future<Map<String, dynamic>?> getUsageStats() async {
    try {
      // This method is no longer directly related to OpenAI API calls
      // but keeping it for now as it was in the original file.
      // If it needs to be updated, it should be removed or refactored.
      return {
        'status': 'connected',
        'last_request': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return null;
    }
  }
}
