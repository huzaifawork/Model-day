import 'dart:typed_data';

/// Stub implementation for non-web platforms
class WebOcrService {
  static Future<void> initialize() async {
    throw UnsupportedError('Web OCR is only supported on web platforms');
  }

  static Future<String> extractTextFromImage(Uint8List imageBytes) async {
    throw UnsupportedError('Web OCR is only supported on web platforms');
  }

  static bool isSupported() {
    return false;
  }

  static Map<String, dynamic> getStatus() {
    return {
      'isWeb': false,
      'isInitialized': false,
      'isInitializing': false,
      'tesseractAvailable': false,
    };
  }
}
