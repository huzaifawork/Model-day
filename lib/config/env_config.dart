import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class EnvConfig {
  static bool _initialized = false;

  /// Initialize environment configuration
  static Future<void> initialize() async {
    if (!_initialized) {
      if (kIsWeb) {
        // For web builds, we don't need to load .env files
        // Environment variables are injected at build time
        _initialized = true;
        debugPrint('✅ Web environment configuration initialized');
      } else {
        // For mobile builds, load from .env file
        try {
          await dotenv.load(fileName: ".env");
          _initialized = true;
          debugPrint('✅ Environment configuration loaded successfully');
        } catch (e) {
          debugPrint('⚠️ Could not load .env file: $e');
          debugPrint('⚠️ Using fallback configuration');
          _initialized = true;
        }
      }
    }
  }

  // Remove OpenAI API key logic
}
