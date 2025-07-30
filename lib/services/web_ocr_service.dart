import 'dart:js_interop';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

// JavaScript interop definitions
@JS('eval')
external JSAny? eval(String code);

@JS('window.Tesseract')
external JSObject? get tesseract;

class WebOcrService {
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  /// Initialize Tesseract.js for web OCR
  static Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    debugPrint('🔍 WebOcrService: Initializing Tesseract.js...');

    try {
      // Load Tesseract.js from CDN
      await _loadTesseractScript();
      _isInitialized = true;
      debugPrint('✅ WebOcrService: Tesseract.js initialized successfully');
    } catch (e) {
      debugPrint('❌ WebOcrService: Failed to initialize Tesseract.js: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Load Tesseract.js script dynamically
  static Future<void> _loadTesseractScript() async {
    // Check if Tesseract is already loaded
    if (_isTesseractLoaded()) {
      debugPrint('🔍 WebOcrService: Tesseract.js already loaded');
      return;
    }

    // Create script element
    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.src = 'https://unpkg.com/tesseract.js@4.1.1/dist/tesseract.min.js';
    script.type = 'text/javascript';

    // Add to document head
    web.document.head!.appendChild(script);

    // Wait for script to load
    await _waitForScriptLoad(script);

    // Verify Tesseract is available
    if (!_isTesseractLoaded()) {
      throw Exception('Failed to load Tesseract.js');
    }
  }

  /// Check if Tesseract is loaded
  static bool _isTesseractLoaded() {
    try {
      return tesseract != null;
    } catch (e) {
      return false;
    }
  }

  /// Wait for script to load
  static Future<void> _waitForScriptLoad(web.HTMLScriptElement script) {
    final completer = Completer<void>();
    script.onLoad.listen((_) => completer.complete());
    script.onError.listen(
        (_) => completer.completeError(Exception('Script failed to load')));
    return completer.future;
  }

  /// Extract text from image bytes using Tesseract.js
  static Future<String> extractTextFromImage(Uint8List imageBytes) async {
    if (!_isInitialized) {
      await initialize();
    }

    debugPrint('🔍 WebOcrService: Starting OCR extraction...');

    try {
      // Create blob from image bytes
      final blob = web.Blob([imageBytes.toJS].toJS);
      final url = web.URL.createObjectURL(blob);

      debugPrint('🔍 WebOcrService: Created blob URL: $url');

      // Call Tesseract.js recognize function
      final result = await _recognizeText(url);

      // Clean up blob URL
      web.URL.revokeObjectURL(url);

      debugPrint('✅ WebOcrService: OCR extraction completed');
      debugPrint('📝 WebOcrService: Extracted text: $result');

      return result;
    } catch (e) {
      debugPrint('❌ WebOcrService: OCR extraction failed: $e');
      rethrow;
    }
  }

  /// Call Tesseract.js recognize function using JS interop
  static Future<String> _recognizeText(String imageUrl) async {
    try {
      debugPrint('🔍 Starting Tesseract recognition for: $imageUrl');

      // Clear any previous results
      eval(
          'window.ocrResult = null; window.ocrError = null; window.ocrDone = false;');

      // Start OCR process
      final jsCode = '''
        Tesseract.recognize('$imageUrl', 'eng', {
          logger: function(m) {
            console.log('Tesseract:', m);
          }
        }).then(function(result) {
          console.log('✅ Tesseract recognition completed');
          window.ocrResult = result.data.text;
          window.ocrDone = true;
        }).catch(function(error) {
          console.error('❌ Tesseract recognition failed:', error);
          window.ocrError = error.toString();
          window.ocrDone = true;
        });
      ''';

      eval(jsCode);

      // Wait for result with polling
      return await _waitForOcrResult();
    } catch (e) {
      debugPrint('❌ WebOcrService: Tesseract recognition error: $e');
      throw Exception('OCR recognition failed: $e');
    }
  }

  /// Wait for OCR result using polling
  static Future<String> _waitForOcrResult() async {
    const maxWaitTime = 30; // 30 seconds timeout
    const pollInterval = 100; // 100ms polling interval
    int waitTime = 0;

    while (waitTime < maxWaitTime * 1000) {
      await Future.delayed(const Duration(milliseconds: pollInterval));
      waitTime += pollInterval;

      try {
        final done = eval('window.ocrDone');
        if (done != null && done.toString() == 'true') {
          final error = eval('window.ocrError');
          if (error != null) {
            final errorMsg = error.toString();
            // Clean up
            eval(
                'window.ocrResult = null; window.ocrError = null; window.ocrDone = false;');
            throw Exception('OCR failed: $errorMsg');
          }

          final result = eval('window.ocrResult');
          final text = result?.toString() ?? '';

          // Clean up
          eval(
              'window.ocrResult = null; window.ocrError = null; window.ocrDone = false;');

          debugPrint(
              '✅ OCR completed successfully. Text length: ${text.length}');
          return text;
        }
      } catch (e) {
        debugPrint('❌ Error polling for OCR result: $e');
        break;
      }
    }

    // Timeout
    eval(
        'window.ocrResult = null; window.ocrError = null; window.ocrDone = false;');
    throw Exception('OCR timeout after ${maxWaitTime}s');
  }

  /// Check if web OCR is supported
  static bool isSupported() {
    return kIsWeb;
  }

  /// Get OCR status for debugging
  static Map<String, dynamic> getStatus() {
    return {
      'isWeb': kIsWeb,
      'isInitialized': _isInitialized,
      'isInitializing': _isInitializing,
      'tesseractAvailable': kIsWeb ? _isTesseractLoaded() : false,
    };
  }
}
