import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'context_service.dart';

class HttpChatService {
  static const String _baseUrl =
      'https://modelday-backend.vercel.app'; // External backend URL
  static const Duration _timeout = Duration(seconds: 30);

  /// Send a chat message and get AI response from backend API
  static Future<String> sendChatMessage(String userMessage) async {
    try {
      debugPrint(
          '🤖 HttpChatService.sendChatMessage() - Sending message: $userMessage');

      // Build user context using existing ContextService
      debugPrint('🤖 Building user context...');
      final userContext = await ContextService.buildUserContext();

      // Prepare request body
      final requestBody = {
        'message': userMessage,
        'context': userContext,
      };

      debugPrint('🤖 Making HTTP request to $_baseUrl/api/chat');

      // Make HTTP POST request to backend API
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/chat'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(_timeout);

      debugPrint('🤖 HTTP response status: ${response.statusCode}');

      // Handle successful response
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['response'] != null) {
          final aiResponse = responseData['response'] as String;
          debugPrint(
              '✅ AI response received: ${aiResponse.substring(0, aiResponse.length > 100 ? 100 : aiResponse.length)}...');
          return aiResponse;
        } else {
          throw Exception('Invalid response format: missing response field');
        }
      }

      // Handle error responses
      if (response.statusCode >= 400) {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Unknown error occurred';

        debugPrint('❌ API Error (${response.statusCode}): $errorMessage');

        // Return user-friendly error messages based on status code
        switch (response.statusCode) {
          case 400:
            return 'I couldn\'t process your request. Please try rephrasing your question.';
          case 429:
            return errorMessage; // Rate limit messages are already user-friendly
          case 500:
            return errorMessage; // Server error messages are already user-friendly
          case 503:
            return 'I\'m temporarily unavailable. Please try again in a moment.';
          default:
            return 'I\'m having trouble connecting to my AI service. Please try again.';
        }
      }

      // Unexpected status code
      throw Exception('Unexpected response status: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ HttpChatService Error: $e');

      // Handle specific error types
      if (e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout')) {
        return 'The request is taking longer than expected. Please try again.';
      }

      if (e.toString().contains('SocketException') ||
          e.toString().contains('network')) {
        return 'I\'m having trouble connecting to my AI service. Please check your internet connection and try again.';
      }

      if (e.toString().contains('FormatException') ||
          e.toString().contains('json')) {
        return 'I received an unexpected response. Please try again.';
      }

      // Generic error message
      return 'I\'m having trouble connecting to my AI service. Please try again in a moment.';
    }
  }

  /// Test the backend API connection
  static Future<bool> testConnection() async {
    try {
      debugPrint('🤖 Testing backend API connection...');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'message': 'Hello, are you working?',
              'context': 'This is a connection test.',
            }),
          )
          .timeout(const Duration(seconds: 10));

      final isConnected = response.statusCode == 200;
      debugPrint(isConnected
          ? '✅ Backend API connection successful'
          : '❌ Backend API connection failed');

      return isConnected;
    } catch (e) {
      debugPrint('❌ Backend API connection test failed: $e');
      return false;
    }
  }

  /// Get service status information
  static Future<Map<String, dynamic>?> getServiceStatus() async {
    try {
      return {
        'status': 'connected',
        'service': 'HTTP Chat Service',
        'endpoint': '$_baseUrl/chat',
        'last_request': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Error getting service status: $e');
      return null;
    }
  }

  /// Validate message before sending (optional client-side validation)
  static bool isValidMessage(String message) {
    if (message.trim().isEmpty) {
      return false;
    }

    if (message.length > 2000) {
      return false;
    }

    return true;
  }

  /// Get user-friendly validation error message
  static String getValidationError(String message) {
    if (message.trim().isEmpty) {
      return 'Please enter a message.';
    }

    if (message.length > 2000) {
      return 'Message is too long. Please keep it under 2000 characters.';
    }

    return '';
  }
}
