import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'web_ocr_service.dart' if (dart.library.io) 'web_ocr_service_stub.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

class OcrService {
  static final TextRecognizer _textRecognizer = TextRecognizer();
  static final ImagePicker _imagePicker = ImagePicker();

  /// Pick image from camera
  static Future<XFile?> pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  /// Pick image from gallery
  static Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      return image;
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Extract text from image file
  static Future<String?> extractTextFromImage(XFile imageFile) async {
    try {
      // Use web OCR service for web platforms
      if (kIsWeb) {
        debugPrint('🌐 OCRService: Using Web OCR service (Tesseract.js)');
        final imageBytes = await imageFile.readAsBytes();
        final extractedText =
            await WebOcrService.extractTextFromImage(imageBytes);

        if (extractedText.isEmpty) {
          debugPrint('No text found in image');
          return null;
        }

        debugPrint('Extracted text: $extractedText');
        return extractedText;
      }

      // Use Google ML Kit for mobile/desktop platforms
      debugPrint('📱 OCRService: Using Google ML Kit');
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        debugPrint('No text found in image');
        return null;
      }

      debugPrint('Extracted text: ${recognizedText.text}');
      return recognizedText.text;
    } catch (e) {
      debugPrint('Error extracting text from image: $e');
      // Return null so the UI can show the error message
      return null;
    }
  }

  /// Preprocess image for better OCR results
  static Future<XFile?> preprocessImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return imageFile;

      // Apply image enhancements
      image = img.adjustColor(image, contrast: 1.2, brightness: 1.1);
      image = img.grayscale(image);

      // Save processed image
      final processedBytes = img.encodeJpg(image, quality: 90);
      final tempFile = File('${imageFile.path}_processed.jpg');
      await tempFile.writeAsBytes(processedBytes);

      return XFile(tempFile.path);
    } catch (e) {
      debugPrint('Error preprocessing image: $e');
      return imageFile; // Return original if preprocessing fails
    }
  }

  /// Check if a line could be a potential agency name
  static bool _isPotentialAgencyName(String line) {
    if (line.isEmpty || line.length < 2 || line.length > 100) {
      return false;
    }

    // Skip lines that are clearly not agency names
    final lowerLine = line.toLowerCase();
    if (lowerLine.contains('contact') ||
        lowerLine.contains('phone') ||
        lowerLine.contains('email') ||
        lowerLine.contains('address') ||
        lowerLine.contains('www') ||
        lowerLine.contains('http') ||
        lowerLine.contains('@') ||
        lowerLine.contains('street') ||
        lowerLine.contains('avenue') ||
        lowerLine.contains('road') ||
        lowerLine.contains('city') ||
        lowerLine.contains('state') ||
        lowerLine.contains('zip') ||
        lowerLine.contains('postal')) {
      return false;
    }

    // Check if this looks like a company name
    // 1. Contains common business words
    if (lowerLine.contains(RegExp(
        r'\b(agency|company|studio|firm|group|inc|ltd|llc|corp|corporation|enterprises|solutions|media|creative|marketing|advertising|pr|communications|design|digital|brand|consulting|services|partners|associates|international|global)\b'))) {
      return true;
    }

    // 2. Is in all caps (common for business names)
    if (line == line.toUpperCase() && line.contains(' ')) {
      return true;
    }

    // 3. Is title case (each word capitalized)
    final words = line.split(' ');
    if (words.length >= 2 &&
        words.length <= 6 &&
        words.every(
            (word) => word.isNotEmpty && word[0] == word[0].toUpperCase())) {
      return true;
    }

    return false;
  }

  /// Parse date string to ISO format (YYYY-MM-DD)
  static String _parseDate(String dateStr) {
    try {
      // First try to parse as ISO date
      final isoDate = DateTime.parse(dateStr);
      return isoDate.toIso8601String().split('T')[0];
    } catch (e) {
      // If ISO parsing fails, try common formats
      final cleanDateStr = dateStr.toLowerCase().replaceAll(',', '').trim();

      // Month name to number mapping
      final monthMap = {
        'january': '01',
        'jan': '01',
        'february': '02',
        'feb': '02',
        'march': '03',
        'mar': '03',
        'april': '04',
        'apr': '04',
        'may': '05',
        'june': '06',
        'jun': '06',
        'july': '07',
        'jul': '07',
        'august': '08',
        'aug': '08',
        'september': '09',
        'sep': '09',
        'sept': '09',
        'october': '10',
        'oct': '10',
        'november': '11',
        'nov': '11',
        'december': '12',
        'dec': '12',
      };

      // Try "Month DD, YYYY" or "Month DD YYYY" format
      final parts = cleanDateStr.split(' ');
      if (parts.length >= 3) {
        final monthName = parts[0];
        final day = parts[1];
        final year = parts[2];

        if (monthMap.containsKey(monthName)) {
          final monthNum = monthMap[monthName]!;
          final dayPadded = day.padLeft(2, '0');
          return '$year-$monthNum-$dayPadded';
        }
      }

      // Try "DD/MM/YYYY" or "MM/DD/YYYY" format
      if (cleanDateStr.contains('/')) {
        final parts = cleanDateStr.split('/');
        if (parts.length == 3) {
          // Assume MM/DD/YYYY format (US style)
          final month = parts[0].padLeft(2, '0');
          final day = parts[1].padLeft(2, '0');
          final year = parts[2];
          return '$year-$month-$day';
        }
      }

      // Try "DD-MM-YYYY" or "YYYY-MM-DD" format
      if (cleanDateStr.contains('-')) {
        final parts = cleanDateStr.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            // YYYY-MM-DD format
            return cleanDateStr;
          } else {
            // DD-MM-YYYY format
            final day = parts[0].padLeft(2, '0');
            final month = parts[1].padLeft(2, '0');
            final year = parts[2];
            return '$year-$month-$day';
          }
        }
      }

      // If all parsing fails, return original string
      debugPrint('⚠️ Could not parse date: $dateStr');
      return dateStr;
    }
  }

  /// Parse extracted text into structured data for Tests
  static Map<String, dynamic> parseTextForTests(String text) {
    final Map<String, dynamic> extractedData = {};
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    debugPrint('🧪 Parsing text lines for tests: $lines');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      final originalLine = lines[i];

      // Extract photographer name - look for "Photographer:" pattern first
      if (line.contains('photographer:') &&
          extractedData['clientName'] == null) {
        final photographerName = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (photographerName != null && photographerName.isNotEmpty) {
          extractedData['clientName'] = photographerName;
        }
      }

      // Extract client name - look for "Client:" pattern
      if (line.contains('client:') && extractedData['clientName'] == null) {
        final clientName = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (clientName != null && clientName.isNotEmpty) {
          extractedData['clientName'] = clientName;
        }
      }

      // Extract test type - look for "Test Type:" pattern
      if (line.contains('test type:') && extractedData['testType'] == null) {
        final testType = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim().toLowerCase()
            : null;
        if (testType != null && testType.isNotEmpty) {
          if (testType.contains('paid') || testType.contains('commercial')) {
            extractedData['testType'] = 'paid';
          } else if (testType.contains('free') || testType.contains('tfp')) {
            extractedData['testType'] = 'free';
          } else {
            extractedData['testType'] = testType;
          }
        }
      }

      // Extract date - look for "Date:" pattern first
      if (line.contains('date:') && extractedData['date'] == null) {
        final dateStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (dateStr != null && dateStr.isNotEmpty) {
          String processedDate = _parseDate(dateStr);
          extractedData['date'] = processedDate;
        }
      }

      // Extract call time - look for "Call Time:" or "Time:" pattern
      if ((line.contains('call time:') || line.contains('time:')) &&
          extractedData['time'] == null) {
        final colonIndex = line.contains('call time:')
            ? originalLine.toLowerCase().indexOf('call time:')
            : originalLine.toLowerCase().indexOf('time:');
        if (colonIndex != -1) {
          final timeStr = originalLine
              .substring(colonIndex + (line.contains('call time:') ? 10 : 5))
              .trim();
          if (timeStr.isNotEmpty) {
            extractedData['time'] = timeStr;
          }
        }
      }

      // Extract location - look for "Location:" pattern
      if (line.contains('location:') && extractedData['location'] == null) {
        final location = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (location != null && location.isNotEmpty) {
          extractedData['location'] = location;
        }
      }

      // Extract rate - look for "Rate:" pattern
      if (line.contains('rate:') && extractedData['rate'] == null) {
        final rateStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (rateStr != null) {
          final rate = _extractRateFromString(rateStr);
          if (rate != null) {
            extractedData['rate'] = rate.toString();
            extractedData['testType'] =
                'paid'; // If rate is specified, it's a paid test
          }
        }
      }

      // Extract status - look for "Status:" pattern
      if (line.contains('status:') && extractedData['status'] == null) {
        final statusStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim().toLowerCase()
            : null;
        if (statusStr != null && statusStr.isNotEmpty) {
          // Map common status variations
          if (statusStr.contains('confirm')) {
            extractedData['status'] = 'confirmed';
          } else if (statusStr.contains('pend')) {
            extractedData['status'] = 'pending';
          } else if (statusStr.contains('complet')) {
            extractedData['status'] = 'completed';
          } else if (statusStr.contains('cancel')) {
            extractedData['status'] = 'cancelled';
          } else if (statusStr.contains('declin')) {
            extractedData['status'] = 'declined';
          } else if (statusStr.contains('postpon')) {
            extractedData['status'] = 'postponed';
          } else {
            extractedData['status'] = statusStr;
          }
        }
      }

      // Extract agent - look for "Agent:" pattern
      if (line.contains('agent:') && extractedData['bookingAgent'] == null) {
        final agentStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (agentStr != null && agentStr.isNotEmpty) {
          extractedData['bookingAgent'] = agentStr;
        }
      }

      // Extract requirements - look for "Requirements:" pattern
      if (line.contains('requirements:') &&
          extractedData['requirements'] == null) {
        final reqStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (reqStr != null && reqStr.isNotEmpty) {
          extractedData['requirements'] = reqStr;
        }
      }
    }

    // Add default agent if none was extracted
    if (extractedData['bookingAgent'] == null) {
      extractedData['bookingAgent'] = 'ogbhai(uzibhaikiagencykoishak)';
    }

    // Set default test type if none was extracted
    if (extractedData['testType'] == null) {
      extractedData['testType'] = 'free';
    }

    debugPrint('🧪 Extracted test data: $extractedData');
    return extractedData;
  }

  /// AI-Powered text parsing using backend OpenAI integration
  /// This method provides superior extraction compared to local parsing
  static Future<Map<String, dynamic>> parseTextWithAI(String text) async {
    debugPrint(
        '🤖 AI OCR: Starting backend-powered intelligent text analysis...');
    debugPrint('📝 Text length: ${text.length} characters');

    try {
      // Call the backend OCR API
      final response = await _callBackendOcrApi(text);

      if (response['success'] == true && response['extractedData'] != null) {
        final extractedData = response['extractedData'] as Map<String, dynamic>;

        debugPrint('✅ AI OCR: Backend extraction successful!');
        debugPrint('📊 Extracted data: $extractedData');
        debugPrint('🔑 Fields found: ${extractedData.keys.toList()}');
        debugPrint(
            '📈 Fields extracted: ${response['fieldsExtracted']} fields');

        return extractedData;
      } else {
        debugPrint('❌ AI OCR: Backend extraction failed');
        throw Exception(
            'Backend OCR extraction failed - no fallback available');
      }
    } catch (e) {
      debugPrint('❌ AI OCR: Backend error: $e');
      throw Exception('Backend OCR API error: $e');
    }
  }

  /// Call the backend OCR API for AI-powered text analysis
  static Future<Map<String, dynamic>> _callBackendOcrApi(String text) async {
    // Backend URL - using deployed backend
    const backendUrl = 'https://modelday-backend.vercel.app';

    final url = Uri.parse('$backendUrl/api/ocr');

    debugPrint('🌐 Calling backend OCR API: $url');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'documentType': 'modeling_document',
      }),
    );

    debugPrint('📡 Backend response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint(
          '✅ Backend OCR successful: ${data['fieldsExtracted']} fields extracted');
      return data;
    } else {
      debugPrint(
          '❌ Backend OCR failed: ${response.statusCode} - ${response.body}');
      throw Exception('Backend OCR API failed: ${response.statusCode}');
    }
  }

  /// Parse extracted text into structured data for Options and Jobs (Local fallback)
  static Map<String, dynamic> parseTextForOptions(String text) {
    final Map<String, dynamic> extractedData = {};
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    debugPrint('🔍 OCR Parsing text lines: $lines');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      final originalLine = lines[i];

      // === ENHANCED CLIENT NAME EXTRACTION ===
      // Look for "Client" patterns (with and without colons) - prioritize this over Contact
      if ((line.contains('client:') || line.contains('client ')) &&
          extractedData['clientName'] == null) {
        String? clientName;

        if (line.contains('client:')) {
          clientName = originalLine.split(':').length > 1
              ? originalLine.split(':')[1].trim()
              : null;
        } else if (line.contains('client ')) {
          // Handle "Client SAMSUNG" format
          final clientIndex = line.indexOf('client ');
          if (clientIndex != -1) {
            clientName = originalLine.substring(clientIndex + 7).trim();
          }
        }

        if (clientName != null && clientName.isNotEmpty) {
          extractedData['clientName'] = clientName;
          debugPrint('✅ OCR extracted client name: $clientName');
        }
      }

      // Extract contact info separately (don't confuse with client name)
      if (line.contains('contact:') && extractedData['contactInfo'] == null) {
        final contactInfo = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (contactInfo != null && contactInfo.isNotEmpty) {
          extractedData['contactInfo'] = contactInfo;
          debugPrint('✅ OCR extracted contact info: $contactInfo');
        }
      }

      // === ENHANCED TITLE EXTRACTION ===
      // Look for "Title :" pattern (common in job briefs)
      if (line.contains('title :') && extractedData['title'] == null) {
        final titleStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (titleStr != null && titleStr.isNotEmpty) {
          extractedData['title'] = titleStr;
          extractedData['jobTitle'] = titleStr; // Also set as job title
          debugPrint('✅ OCR extracted title: $titleStr');
        }
      }

      // === ENHANCED BUDGET EXTRACTION ===
      // Look for "Budget :" pattern
      if (line.contains('budget :') && extractedData['budget'] == null) {
        final budgetStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (budgetStr != null && budgetStr.isNotEmpty) {
          extractedData['budget'] = budgetStr;
          // Try to extract numeric value for dayRate
          final budgetAmount = _extractRateFromString(budgetStr);
          if (budgetAmount != null) {
            extractedData['dayRate'] = budgetAmount.toString();
          }
          debugPrint('✅ OCR extracted budget: $budgetStr');
        }
      }

      // === ENHANCED SHOOTING LOCATION EXTRACTION ===
      // Look for "Shooting location :" pattern
      if (line.contains('shooting location :') &&
          extractedData['location'] == null) {
        final locationStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (locationStr != null && locationStr.isNotEmpty) {
          extractedData['location'] = locationStr;
          debugPrint('✅ OCR extracted shooting location: $locationStr');
        }
      }

      // === ENHANCED SHOOTING SCHEDULE EXTRACTION ===
      // Look for "Shooting Schedule :" pattern
      if (line.contains('shooting schedule :') &&
          extractedData['shootingSchedule'] == null) {
        final scheduleStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (scheduleStr != null && scheduleStr.isNotEmpty) {
          extractedData['shootingSchedule'] = scheduleStr;
          // Try to extract date information
          String processedDate = _parseDate(scheduleStr);
          if (processedDate != scheduleStr) {
            extractedData['date'] = processedDate;
          }
          debugPrint('✅ OCR extracted shooting schedule: $scheduleStr');
        }
      }

      // Extract date - look for "Date:" pattern first
      if (line.contains('date:') && extractedData['date'] == null) {
        final dateStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (dateStr != null && dateStr.isNotEmpty) {
          // Convert common date formats to ISO format
          String processedDate = _parseDate(dateStr);
          extractedData['date'] = processedDate;
        }
      }

      // Extract location - look for "Location:" pattern first
      if (line.contains('location:') && extractedData['location'] == null) {
        final location = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (location != null && location.isNotEmpty) {
          extractedData['location'] = location;
        }
      }

      // Extract day rate - look for "Day Rate:" pattern
      if (line.contains('day rate:') && extractedData['dayRate'] == null) {
        final rateStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (rateStr != null) {
          final rate = _extractRateFromString(rateStr);
          if (rate != null) {
            extractedData['dayRate'] = rate.toString();
          }
        }
      }

      // Extract usage rate - look for "Usage Rate:" pattern
      if (line.contains('usage rate:') && extractedData['usageRate'] == null) {
        final rateStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (rateStr != null) {
          final rate = _extractRateFromString(rateStr);
          if (rate != null) {
            extractedData['usageRate'] = rate.toString();
          }
        }
      }

      // Extract time - look for "Time:" pattern
      if (line.contains('time:') && extractedData['time'] == null) {
        // Handle time that might span multiple parts after splitting on ':'
        final colonIndex = originalLine.toLowerCase().indexOf('time:');
        if (colonIndex != -1) {
          final timeStr = originalLine.substring(colonIndex + 5).trim();
          if (timeStr.isNotEmpty) {
            extractedData['time'] = timeStr;
          }
        }
      }

      // === ENHANCED AGENT EXTRACTION ===
      // Look for "Agent" patterns (with and without colons)
      if ((line.contains('agent:') || line.contains('agent ')) &&
          extractedData['bookingAgent'] == null) {
        String? agentStr;

        if (line.contains('agent:')) {
          agentStr = originalLine.split(':').length > 1
              ? originalLine.split(':')[1].trim()
              : null;
        } else if (line.contains('agent ')) {
          // Handle "Agent kubafrancyzk" format
          final agentIndex = line.indexOf('agent ');
          if (agentIndex != -1) {
            agentStr = originalLine.substring(agentIndex + 6).trim();
          }
        }

        if (agentStr != null && agentStr.isNotEmpty) {
          extractedData['bookingAgent'] = agentStr;
          debugPrint('✅ OCR extracted agent: $agentStr');
        }
      }

      // === ENHANCED MEDIA TYPE EXTRACTION ===
      // Look for "Media :" pattern
      if (line.contains('media :') && extractedData['mediaType'] == null) {
        final mediaStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (mediaStr != null && mediaStr.isNotEmpty) {
          extractedData['mediaType'] = mediaStr;
          debugPrint('✅ OCR extracted media type: $mediaStr');
        }
      }

      // === ENHANCED USAGE PERIOD EXTRACTION ===
      // Look for "Usage Period :" pattern
      if (line.contains('usage period :') &&
          extractedData['usagePeriod'] == null) {
        final usageStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (usageStr != null && usageStr.isNotEmpty) {
          extractedData['usagePeriod'] = usageStr;
          debugPrint('✅ OCR extracted usage period: $usageStr');
        }
      }

      // === ENHANCED RELEASE COUNTRY EXTRACTION ===
      // Look for "Release country :" pattern
      if (line.contains('release country :') &&
          extractedData['releaseCountry'] == null) {
        final countryStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (countryStr != null && countryStr.isNotEmpty) {
          extractedData['releaseCountry'] = countryStr;
          debugPrint('✅ OCR extracted release country: $countryStr');
        }
      }

      // === ENHANCED EXCLUSIVITY EXTRACTION ===
      // Look for "Exclusivity :" pattern
      if (line.contains('exclusivity :') &&
          extractedData['exclusivity'] == null) {
        final exclusivityStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (exclusivityStr != null && exclusivityStr.isNotEmpty) {
          extractedData['exclusivity'] = exclusivityStr;
          debugPrint('✅ OCR extracted exclusivity: $exclusivityStr');
        }
      }

      // === TEST-SPECIFIC FIELDS ===

      // Extract photographer name - look for "Photographer:" pattern
      if (line.contains('photographer:') &&
          extractedData['clientName'] == null) {
        final photographerName = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (photographerName != null && photographerName.isNotEmpty) {
          extractedData['clientName'] = photographerName;
        }
      }

      // Extract test type - look for "Test Type:" pattern
      if (line.contains('test type:') && extractedData['testType'] == null) {
        final testType = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim().toLowerCase()
            : null;
        if (testType != null && testType.isNotEmpty) {
          if (testType.contains('paid') || testType.contains('commercial')) {
            extractedData['testType'] = 'paid';
          } else if (testType.contains('free') || testType.contains('tfp')) {
            extractedData['testType'] = 'free';
          } else {
            extractedData['testType'] = testType;
          }
        }
      }

      // Extract call time - look for "Call Time:" pattern
      if (line.contains('call time:') && extractedData['time'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('call time:');
        if (colonIndex != -1) {
          final timeStr = originalLine.substring(colonIndex + 10).trim();
          if (timeStr.isNotEmpty) {
            extractedData['time'] = timeStr;
          }
        }
      }

      // Extract rate for tests - look for "Rate:" pattern (in addition to "Day Rate:")
      if (line.contains('rate:') &&
          !line.contains('day rate:') &&
          !line.contains('usage rate:') &&
          extractedData['rate'] == null &&
          extractedData['dayRate'] == null) {
        final rateStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (rateStr != null) {
          final rate = _extractRateFromString(rateStr);
          if (rate != null) {
            extractedData['rate'] = rate.toString();
            extractedData['dayRate'] =
                rate.toString(); // Also set dayRate for compatibility
          }
        }
      }

      // === ON STAY SPECIFIC FIELDS ===

      // Extract agency name - look for "Agency:" pattern (case insensitive)
      if (line.contains('agency:') && extractedData['agencyName'] == null) {
        debugPrint('🔍 Found agency pattern in line: $originalLine');
        final parts = originalLine.split(':');
        if (parts.length > 1) {
          final agencyStr = parts.sublist(1).join(':').trim();
          if (agencyStr.isNotEmpty) {
            debugPrint('✅ Extracted agency name: $agencyStr');
            extractedData['agencyName'] = agencyStr;
          }
        }
      }

      // Extract agency address - look for "Agency Address:" pattern (case insensitive)
      if (line.contains('agency address:') &&
          extractedData['agencyAddress'] == null) {
        final parts = originalLine.split(':');
        if (parts.length > 1) {
          final addressStr = parts.sublist(1).join(':').trim();
          if (addressStr.isNotEmpty) {
            debugPrint('✅ Extracted agency address: $addressStr');
            extractedData['agencyAddress'] = addressStr;
          }
        }
      }

      // Extract hotel address - look for "Hotel Address:" pattern (case insensitive)
      if (line.contains('hotel address:') &&
          extractedData['hotelAddress'] == null) {
        final parts = originalLine.split(':');
        if (parts.length > 1) {
          final hotelStr = parts.sublist(1).join(':').trim();
          if (hotelStr.isNotEmpty) {
            debugPrint('✅ Extracted hotel address: $hotelStr');
            extractedData['hotelAddress'] = hotelStr;
          }
        }
      }

      // Extract hotel cost - look for "Hotel Cost:" pattern (case insensitive)
      if (line.contains('hotel cost:') && extractedData['hotelCost'] == null) {
        debugPrint('🔍 Found hotel cost pattern in line: $originalLine');
        final parts = originalLine.split(':');
        if (parts.length > 1) {
          final costStr = parts.sublist(1).join(':').trim();
          if (costStr.isNotEmpty) {
            debugPrint('🔍 Extracting cost from: $costStr');
            final cost = _extractRateFromString(costStr);
            if (cost != null) {
              debugPrint('✅ Extracted hotel cost: $cost');
              extractedData['hotelCost'] = cost;
            } else {
              debugPrint('❌ Failed to extract cost from: $costStr');
            }
          }
        }
      }

      // Extract flight cost - look for "Flight Cost:" pattern (case insensitive)
      if (line.contains('flight cost:') &&
          extractedData['flightCost'] == null) {
        debugPrint('🔍 Found flight cost pattern in line: $originalLine');
        final parts = originalLine.split(':');
        if (parts.length > 1) {
          final costStr = parts.sublist(1).join(':').trim();
          if (costStr.isNotEmpty) {
            debugPrint('🔍 Extracting flight cost from: $costStr');
            final cost = _extractRateFromString(costStr);
            if (cost != null) {
              debugPrint('✅ Extracted flight cost: $cost');
              extractedData['flightCost'] = cost;
            } else {
              debugPrint('❌ Failed to extract flight cost from: $costStr');
            }
          }
        }
      }

      // Extract pocket money - look for "Pocket Money:" pattern (case insensitive)
      if (line.contains('pocket money:') &&
          extractedData['pocketMoney'] == null) {
        debugPrint('🔍 Found pocket money pattern in line: $originalLine');
        final parts = originalLine.split(':');
        if (parts.length > 1) {
          final pocketStr = parts.sublist(1).join(':').trim();
          if (pocketStr.isNotEmpty) {
            debugPrint('✅ Extracted pocket money: $pocketStr');
            extractedData['pocketMoney'] = pocketStr;
            // Also try to extract pocket money cost
            final cost = _extractRateFromString(pocketStr);
            if (cost != null) {
              debugPrint('✅ Extracted pocket money cost: $cost');
              extractedData['pocketMoneyCost'] = cost;
            }
          }
        }
      }

      // Extract check-in date - look for "Check-in:" pattern (case insensitive)
      if (line.contains('check-in:') && extractedData['checkInDate'] == null) {
        debugPrint('🔍 Found check-in pattern in line: $originalLine');
        final parts = originalLine.split(':');
        if (parts.length > 1) {
          final dateStr = parts.sublist(1).join(':').trim();
          if (dateStr.isNotEmpty) {
            String processedDate = _parseDate(dateStr);
            debugPrint('✅ Extracted check-in date: $processedDate');
            extractedData['checkInDate'] = processedDate;
          }
        }
      }

      // Extract check-out date - look for "Check-out:" pattern (case insensitive)
      if (line.contains('check-out:') &&
          extractedData['checkOutDate'] == null) {
        debugPrint('🔍 Found check-out pattern in line: $originalLine');
        final parts = originalLine.split(':');
        if (parts.length > 1) {
          final dateStr = parts.sublist(1).join(':').trim();
          if (dateStr.isNotEmpty) {
            String processedDate = _parseDate(dateStr);
            debugPrint('✅ Extracted check-out date: $processedDate');
            extractedData['checkOutDate'] = processedDate;
          }
        }
      }

      // Extract contract details - look for contract-related patterns
      if ((line.contains('contract') ||
              line.contains('fashion week') ||
              line.contains('runway') ||
              line.contains('photo shoot')) &&
          extractedData['contractDetails'] == null) {
        // Collect contract-related lines
        List<String> contractLines = [];

        // Look for contract details section
        for (int j = i; j < lines.length && j < i + 5; j++) {
          final contractLine = lines[j];
          if (contractLine.toLowerCase().contains('contract') ||
              contractLine.toLowerCase().contains('fashion') ||
              contractLine.toLowerCase().contains('runway') ||
              contractLine.toLowerCase().contains('shoot') ||
              contractLine.toLowerCase().contains('day') ||
              contractLine.startsWith('•') ||
              contractLine.startsWith('-')) {
            contractLines.add(contractLine);
          }
        }

        if (contractLines.isNotEmpty) {
          extractedData['contractDetails'] = contractLines.join('\n');
        }
      }

      // Extract option type - look for "Option Type:" pattern
      if (line.contains('option type:') &&
          extractedData['optionType'] == null) {
        final typeStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (typeStr != null && typeStr.isNotEmpty) {
          extractedData['optionType'] = typeStr;
        }
      }

      // Extract job type - look for "Job Type:" pattern
      if (line.contains('job type:') && extractedData['jobType'] == null) {
        final typeStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (typeStr != null && typeStr.isNotEmpty) {
          extractedData['jobType'] = typeStr;
        }
      }

      // Extract status - look for "Status:" pattern
      if (line.contains('status:') && extractedData['status'] == null) {
        final statusStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (statusStr != null && statusStr.isNotEmpty) {
          extractedData['status'] = statusStr;
        }
      }

      // === JOB-SPECIFIC FIELDS ===

      // Extract extra hours - look for "Extra Hours:" pattern
      if (line.contains('extra hours:') &&
          extractedData['extraHours'] == null) {
        final hoursStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (hoursStr != null && hoursStr.isNotEmpty) {
          final hours =
              double.tryParse(hoursStr.replaceAll(RegExp(r'[^\d.]'), ''));
          if (hours != null) {
            extractedData['extraHours'] = hours;
          }
        }
      }

      // Extract agency fee - look for "Agency Fee:" pattern
      if (line.contains('agency fee:') && extractedData['agencyFee'] == null) {
        final feeStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (feeStr != null && feeStr.isNotEmpty) {
          final fee = double.tryParse(feeStr.replaceAll(RegExp(r'[^\d.]'), ''));
          if (fee != null) {
            extractedData['agencyFee'] = fee;
          }
        }
      }

      // Extract tax - look for "Tax:" pattern
      if (line.contains('tax:') && extractedData['tax'] == null) {
        final taxStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (taxStr != null && taxStr.isNotEmpty) {
          final tax = double.tryParse(taxStr.replaceAll(RegExp(r'[^\d.]'), ''));
          if (tax != null) {
            extractedData['tax'] = tax;
          }
        }
      }

      // Extract currency - look for currency symbols and codes
      if (extractedData['currency'] == null) {
        if (line.contains('\$') || line.contains('usd')) {
          extractedData['currency'] = 'USD';
        } else if (line.contains('€') || line.contains('eur')) {
          extractedData['currency'] = 'EUR';
        } else if (line.contains('£') || line.contains('gbp')) {
          extractedData['currency'] = 'GBP';
        }
      }

      // Extract payment status - look for "Payment:" or "Payment Status:" pattern
      if ((line.contains('payment:') || line.contains('payment status:')) &&
          extractedData['paymentStatus'] == null) {
        final paymentStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim().toLowerCase()
            : null;
        if (paymentStr != null && paymentStr.isNotEmpty) {
          if (paymentStr.contains('paid') && !paymentStr.contains('unpaid')) {
            extractedData['paymentStatus'] = 'Paid';
          } else if (paymentStr.contains('partial')) {
            extractedData['paymentStatus'] = 'Partially Paid';
          } else {
            extractedData['paymentStatus'] = 'Unpaid';
          }
        }
      }

      // Extract requirements - look for "Requirements:" pattern
      if (line.contains('requirements:') &&
          extractedData['requirements'] == null) {
        final reqStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (reqStr != null && reqStr.isNotEmpty) {
          extractedData['requirements'] = reqStr;
        }
      }

      // === POLAROID-SPECIFIC FIELDS ===

      // Extract polaroid type - look for "Polaroid Type:" or "Type:" pattern
      if ((line.contains('polaroid type:') ||
              (line.contains('type:') &&
                  !line.contains('job type:') &&
                  !line.contains('test type:') &&
                  !line.contains('option type:'))) &&
          extractedData['polaroidType'] == null) {
        final typeStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim().toLowerCase()
            : null;
        if (typeStr != null && typeStr.isNotEmpty) {
          if (typeStr.contains('paid') || typeStr.contains('commercial')) {
            extractedData['polaroidType'] = 'paid';
          } else if (typeStr.contains('free') || typeStr.contains('tfp')) {
            extractedData['polaroidType'] = 'free';
          } else {
            extractedData['polaroidType'] = typeStr;
          }
        }
      }

      // Extract cost - look for "Cost:" pattern (in addition to rate patterns)
      if (line.contains('cost:') && extractedData['cost'] == null) {
        final costStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (costStr != null) {
          final cost = _extractRateFromString(costStr);
          if (cost != null) {
            extractedData['cost'] = cost.toString();
            extractedData['polaroidType'] =
                'paid'; // If cost is specified, it's a paid polaroid
          }
        }
      }

      // Extract session duration - look for "Duration:" or "Session:" pattern
      if ((line.contains('duration:') || line.contains('session:')) &&
          extractedData['duration'] == null) {
        final durationStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (durationStr != null && durationStr.isNotEmpty) {
          extractedData['duration'] = durationStr;
        }
      }

      // === MEETING-SPECIFIC FIELDS ===

      // Extract meeting type/subject - look for "Meeting Type:", "Subject:", or "Meeting:" pattern
      if ((line.contains('meeting type:') ||
              line.contains('subject:') ||
              (line.contains('meeting:') && !line.contains('meeting time:'))) &&
          extractedData['meetingType'] == null &&
          extractedData['subject'] == null) {
        final subjectStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (subjectStr != null && subjectStr.isNotEmpty) {
          extractedData['meetingType'] = subjectStr;
          extractedData['subject'] = subjectStr;
        }
      }

      // Extract start time - look for "Start Time:" pattern
      if (line.contains('start time:') && extractedData['startTime'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('start time:');
        if (colonIndex != -1) {
          final timeStr = originalLine.substring(colonIndex + 11).trim();
          if (timeStr.isNotEmpty) {
            extractedData['startTime'] = timeStr;
            // Also set as general time if not already set
            if (extractedData['time'] == null) {
              extractedData['time'] = timeStr;
            }
          }
        }
      }

      // Extract end time - look for "End Time:" pattern
      if (line.contains('end time:') && extractedData['endTime'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('end time:');
        if (colonIndex != -1) {
          final timeStr = originalLine.substring(colonIndex + 9).trim();
          if (timeStr.isNotEmpty) {
            extractedData['endTime'] = timeStr;
          }
        }
      }

      // Extract agenda - look for "Agenda:" pattern
      if (line.contains('agenda:') && extractedData['agenda'] == null) {
        final agendaStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (agendaStr != null && agendaStr.isNotEmpty) {
          extractedData['agenda'] = agendaStr;
        }
      }

      // Extract attendees - look for "Attendees:" pattern
      if (line.contains('attendees:') && extractedData['attendees'] == null) {
        final attendeesStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (attendeesStr != null && attendeesStr.isNotEmpty) {
          extractedData['attendees'] = attendeesStr;
        }
      }

      // Extract email - look for "Email:" pattern
      if (line.contains('email:') && extractedData['email'] == null) {
        final emailStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (emailStr != null && emailStr.isNotEmpty) {
          extractedData['email'] = emailStr;
        }
      }

      // Extract phone - look for "Phone:" pattern
      if (line.contains('phone:') && extractedData['phone'] == null) {
        final phoneStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (phoneStr != null && phoneStr.isNotEmpty) {
          extractedData['phone'] = phoneStr;
        }
      }

      // Extract website - look for "Website:" pattern
      if (line.contains('website:') && extractedData['website'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('website:');
        if (colonIndex != -1) {
          final websiteStr = originalLine.substring(colonIndex + 8).trim();
          if (websiteStr.isNotEmpty) {
            extractedData['website'] = websiteStr;
            extractedData['url'] = websiteStr; // Also set as URL
            debugPrint('🏢 OCR extracted website: $websiteStr');
          }
        }
      }

      // Extract address - look for "Address:" pattern
      if (line.contains('address:') && extractedData['address'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('address:');
        if (colonIndex != -1) {
          final addressStr = originalLine.substring(colonIndex + 8).trim();
          if (addressStr.isNotEmpty) {
            extractedData['address'] = addressStr;
            debugPrint('🏢 OCR extracted address: $addressStr');
          }
        }
      }

      // Extract city - look for "City:" pattern
      if (line.contains('city:') && extractedData['city'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('city:');
        if (colonIndex != -1) {
          final cityStr = originalLine.substring(colonIndex + 5).trim();
          if (cityStr.isNotEmpty) {
            extractedData['city'] = cityStr;
            debugPrint('🏢 OCR extracted city: $cityStr');
          }
        }
      }

      // Extract country - look for "Country:" pattern
      if (line.contains('country:') && extractedData['country'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('country:');
        if (colonIndex != -1) {
          final countryStr = originalLine.substring(colonIndex + 8).trim();
          if (countryStr.isNotEmpty) {
            extractedData['country'] = countryStr;
            debugPrint('🏢 OCR extracted country: $countryStr');
          }
        }
      }

      // === AI JOB-SPECIFIC FIELDS ===

      // Extract AI job type - look for "AI Job Type:", "Job Type:", or "Type:" pattern
      if ((line.contains('ai job type:') ||
              (line.contains('job type:') && !line.contains('test type:')) ||
              (line.contains('type:') &&
                  !line.contains('test type:') &&
                  !line.contains('option type:') &&
                  !line.contains('polaroid type:'))) &&
          extractedData['aiJobType'] == null) {
        final typeStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim().toLowerCase()
            : null;
        if (typeStr != null && typeStr.isNotEmpty) {
          extractedData['aiJobType'] = typeStr;
          extractedData['type'] = typeStr; // Also set general type field
        }
      }

      // Extract specifications - look for "Specifications:" pattern
      if (line.contains('specifications:') &&
          extractedData['specifications'] == null) {
        final specsStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (specsStr != null && specsStr.isNotEmpty) {
          extractedData['specifications'] = specsStr;
        }
      }

      // Extract payment status - look for "Payment Status:" or "Payment:" pattern
      if ((line.contains('payment status:') || line.contains('payment:')) &&
          extractedData['paymentStatus'] == null) {
        final paymentStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim().toLowerCase()
            : null;
        if (paymentStr != null && paymentStr.isNotEmpty) {
          extractedData['paymentStatus'] = paymentStr;
        }
      }

      // Extract description - look for "Description:" pattern (if not already set)
      if (line.contains('description:') &&
          extractedData['description'] == null) {
        final descStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (descStr != null && descStr.isNotEmpty) {
          extractedData['description'] = descStr;
        }
      }

      // Extract deliverables - look for "Deliverables:" pattern
      if (line.contains('deliverables:') &&
          extractedData['deliverables'] == null) {
        final delivStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (delivStr != null && delivStr.isNotEmpty) {
          extractedData['deliverables'] = delivStr;
        }
      }

      // Extract timeline - look for "Timeline:" or "Deadline:" pattern
      if ((line.contains('timeline:') || line.contains('deadline:')) &&
          extractedData['timeline'] == null) {
        final timelineStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (timelineStr != null && timelineStr.isNotEmpty) {
          extractedData['timeline'] = timelineStr;
        }
      }

      // === OTHER EVENT-SPECIFIC FIELDS ===

      // Extract event name - look for "Event Name:", "Event:", "Title:", or "Name:" pattern
      if ((line.contains('event name:') ||
              (line.contains('event:') && !line.contains('event type:')) ||
              (line.contains('title:') && !line.contains('job title:')) ||
              (line.contains('name:') &&
                  !line.contains('client name:') &&
                  !line.contains('agency name:') &&
                  !line.contains('photographer name:'))) &&
          extractedData['eventName'] == null) {
        final eventNameStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (eventNameStr != null && eventNameStr.isNotEmpty) {
          extractedData['eventName'] = eventNameStr;
          extractedData['title'] = eventNameStr; // Also set as title
        }
      }

      // Extract event type/category - look for "Event Type:" or "Category:" pattern
      if ((line.contains('event type:') || line.contains('category:')) &&
          extractedData['eventType'] == null) {
        final eventTypeStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (eventTypeStr != null && eventTypeStr.isNotEmpty) {
          extractedData['eventType'] = eventTypeStr;
          extractedData['category'] = eventTypeStr; // Also set as category
        }
      }

      // Extract organizer - look for "Organizer:" or "Organized by:" pattern
      if ((line.contains('organizer:') || line.contains('organized by:')) &&
          extractedData['organizer'] == null) {
        final organizerStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (organizerStr != null && organizerStr.isNotEmpty) {
          extractedData['organizer'] = organizerStr;
        }
      }

      // Extract subject - look for "Subject:" pattern (if not already set)
      if (line.contains('subject:') && extractedData['subject'] == null) {
        final subjectStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (subjectStr != null && subjectStr.isNotEmpty) {
          extractedData['subject'] = subjectStr;
        }
      }

      // Extract venue - look for "Venue:" pattern (maps to location if location not set)
      if (line.contains('venue:') && extractedData['venue'] == null) {
        final venueStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (venueStr != null && venueStr.isNotEmpty) {
          extractedData['venue'] = venueStr;
          // Also set as location if location not already set
          if (extractedData['location'] == null) {
            extractedData['location'] = venueStr;
          }
        }
      }

      // Extract duration - look for "Duration:" pattern
      if (line.contains('duration:') && extractedData['duration'] == null) {
        final durationStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (durationStr != null && durationStr.isNotEmpty) {
          extractedData['duration'] = durationStr;
        }
      }

      // === AGENCY-SPECIFIC FIELDS ===

      // Extract agency name - Enhanced pattern recognition
      if (extractedData['agencyName'] == null) {
        String? agencyNameStr;

        // Primary patterns with colons - expanded list
        final patterns = [
          'agency name:',
          'agency:',
          'company name:',
          'company:',
          'organization:',
          'business name:',
          'firm name:',
          'firm:',
          'studio name:',
          'studio:',
          'brand name:',
          'brand:',
          'business:',
          'enterprise:',
          'group name:',
          'group:',
          'corporation:',
          'corp:',
          'inc:',
          'ltd:',
          'llc:'
        ];

        for (final pattern in patterns) {
          if (line.contains(pattern) &&
              (pattern != 'agency:' || !line.contains('agency type:')) &&
              (pattern != 'company:' || !line.contains('company type:')) &&
              agencyNameStr == null) {
            final colonIndex = originalLine.toLowerCase().indexOf(pattern);
            if (colonIndex != -1) {
              agencyNameStr =
                  originalLine.substring(colonIndex + pattern.length).trim();
              if (agencyNameStr.isNotEmpty) {
                debugPrint(
                    '🏢 OCR extracted agency name with pattern "$pattern": $agencyNameStr');
                break;
              }
            }
          }
        }

        // Fallback: Look for potential agency names in first few lines
        if (agencyNameStr == null && i < 5) {
          final cleanLine = originalLine.trim();
          if (_isPotentialAgencyName(cleanLine)) {
            agencyNameStr = cleanLine;
            debugPrint(
                '🏢 OCR extracted agency name from fallback: $agencyNameStr');
          }
        }

        // Set the extracted agency name
        if (agencyNameStr != null && agencyNameStr.isNotEmpty) {
          extractedData['agencyName'] = agencyNameStr;
          extractedData['name'] = agencyNameStr; // Also set as general name
          extractedData['company'] = agencyNameStr; // Also set as company
        }
      }

      // Extract agency type - Enhanced pattern recognition
      if (extractedData['agencyType'] == null) {
        String? typeStr;

        // Look for explicit type patterns
        final typePatterns = [
          'agency type:',
          'type:',
          'category:',
          'classification:',
          'kind:'
        ];

        for (final pattern in typePatterns) {
          if (line.contains(pattern) &&
              !line.contains('event type:') &&
              !line.contains('job type:') &&
              !line.contains('option type:') &&
              typeStr == null) {
            final parts = originalLine.split(':');
            if (parts.length > 1) {
              typeStr = parts[1].trim().toLowerCase();
              if (typeStr.isNotEmpty) {
                debugPrint(
                    '🏢 OCR extracted agency type with pattern "$pattern": $typeStr');
                break;
              }
            }
          }
        }

        // Fallback: Look for common agency type keywords in the text
        if (typeStr == null) {
          if (line.contains('mother') || line.contains('parent')) {
            typeStr = 'mother agency';
            debugPrint('🏢 OCR detected mother agency type from keywords');
          } else if (line.contains('representing') ||
              line.contains('represent')) {
            typeStr = 'representing';
            debugPrint(
                '🏢 OCR detected representing agency type from keywords');
          }
        }

        // Set the extracted agency type
        if (typeStr != null && typeStr.isNotEmpty) {
          extractedData['agencyType'] = typeStr;
          extractedData['type'] = typeStr; // Also set as general type
        }
      }

      // Extract commission rate - look for "Commission Rate:", "Commission:", or "Rate:" pattern
      if ((line.contains('commission rate:') ||
              (line.contains('commission:') &&
                  !line.contains('commission fee:')) ||
              (line.contains('rate:') &&
                  !line.contains('day rate:') &&
                  !line.contains('usage rate:'))) &&
          extractedData['commissionRate'] == null) {
        final rateStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (rateStr != null && rateStr.isNotEmpty) {
          extractedData['commissionRate'] = rateStr;
          extractedData['commission'] = rateStr; // Also set as commission
        }
      }

      // Extract main booker name - look for "Main Booker:", "Booker Name:", or "Contact Name:" pattern
      if ((line.contains('main booker:') ||
              line.contains('booker name:') ||
              (line.contains('contact name:') &&
                  !line.contains('finance contact name:'))) &&
          extractedData['mainBookerName'] == null) {
        final bookerNameStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (bookerNameStr != null && bookerNameStr.isNotEmpty) {
          extractedData['mainBookerName'] = bookerNameStr;
          extractedData['bookerName'] =
              bookerNameStr; // Also set as booker name
          extractedData['contactName'] =
              bookerNameStr; // Also set as contact name
        }
      }

      // Extract main booker email - look for "Main Booker Email:", "Booker Email:" pattern
      if ((line.contains('main booker email:') ||
              line.contains('booker email:') ||
              (line.contains('contact email:') &&
                  !line.contains('finance contact email:'))) &&
          extractedData['mainBookerEmail'] == null) {
        final bookerEmailStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (bookerEmailStr != null && bookerEmailStr.isNotEmpty) {
          extractedData['mainBookerEmail'] = bookerEmailStr;
          extractedData['bookerEmail'] =
              bookerEmailStr; // Also set as booker email
        }
      }

      // Extract main booker phone - look for "Main Booker Phone:", "Booker Phone:" pattern
      if ((line.contains('main booker phone:') ||
              line.contains('booker phone:') ||
              (line.contains('contact phone:') &&
                  !line.contains('finance contact phone:'))) &&
          extractedData['mainBookerPhone'] == null) {
        final bookerPhoneStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (bookerPhoneStr != null && bookerPhoneStr.isNotEmpty) {
          extractedData['mainBookerPhone'] = bookerPhoneStr;
          extractedData['bookerPhone'] =
              bookerPhoneStr; // Also set as booker phone
        }
      }

      // Extract finance contact name - look for "Finance Contact Name:", "Finance Name:" pattern
      if ((line.contains('finance contact name:') ||
              line.contains('finance name:') ||
              line.contains('finance contact:')) &&
          extractedData['financeContactName'] == null) {
        final financeNameStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (financeNameStr != null && financeNameStr.isNotEmpty) {
          extractedData['financeContactName'] = financeNameStr;
          extractedData['financeName'] =
              financeNameStr; // Also set as finance name
        }
      }

      // Extract finance contact email - look for "Finance Contact Email:", "Finance Email:" pattern
      if ((line.contains('finance contact email:') ||
              line.contains('finance email:')) &&
          extractedData['financeContactEmail'] == null) {
        final financeEmailStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (financeEmailStr != null && financeEmailStr.isNotEmpty) {
          extractedData['financeContactEmail'] = financeEmailStr;
          extractedData['financeEmail'] =
              financeEmailStr; // Also set as finance email
        }
      }

      // Extract finance contact phone - look for "Finance Contact Phone:", "Finance Phone:" pattern
      if ((line.contains('finance contact phone:') ||
              line.contains('finance phone:')) &&
          extractedData['financeContactPhone'] == null) {
        final financePhoneStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (financePhoneStr != null && financePhoneStr.isNotEmpty) {
          extractedData['financeContactPhone'] = financePhoneStr;
          extractedData['financePhone'] =
              financePhoneStr; // Also set as finance phone
        }
      }

      // Extract contract signed date - look for "Contract Signed:", "Contract Signed Date:" pattern
      if ((line.contains('contract signed:') ||
              line.contains('contract signed date:')) &&
          extractedData['contractSigned'] == null) {
        final contractSignedStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (contractSignedStr != null && contractSignedStr.isNotEmpty) {
          extractedData['contractSigned'] = contractSignedStr;
          extractedData['contractSignedDate'] =
              contractSignedStr; // Also set as contract signed date
        }
      }

      // Extract contract expired date - look for "Contract Expired:", "Contract Expired Date:" pattern
      if ((line.contains('contract expired:') ||
              line.contains('contract expired date:') ||
              line.contains('contract expires:')) &&
          extractedData['contractExpired'] == null) {
        final contractExpiredStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (contractExpiredStr != null && contractExpiredStr.isNotEmpty) {
          extractedData['contractExpired'] = contractExpiredStr;
          extractedData['contractExpiredDate'] =
              contractExpiredStr; // Also set as contract expired date
        }
      }

      // Extract services - look for "Services:" pattern
      if (line.contains('services:') && extractedData['services'] == null) {
        final servicesStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (servicesStr != null && servicesStr.isNotEmpty) {
          extractedData['services'] = servicesStr;
        }
      }

      // Extract specialization - look for "Specialization:" pattern
      if (line.contains('specialization:') &&
          extractedData['specialization'] == null) {
        final specializationStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (specializationStr != null && specializationStr.isNotEmpty) {
          extractedData['specialization'] = specializationStr;
        }
      }

      // Extract territories - look for "Territories:" pattern
      if (line.contains('territories:') &&
          extractedData['territories'] == null) {
        final territoriesStr = originalLine.split(':').length > 1
            ? originalLine.split(':')[1].trim()
            : null;
        if (territoriesStr != null && territoriesStr.isNotEmpty) {
          extractedData['territories'] = territoriesStr;
        }
      }

      // === AGENT-SPECIFIC FIELDS ===

      // Extract full name - look for "Full Name:" pattern
      if (line.contains('full name:') && extractedData['fullName'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('full name:');
        if (colonIndex != -1) {
          final fullNameStr = originalLine.substring(colonIndex + 10).trim();
          if (fullNameStr.isNotEmpty) {
            extractedData['fullName'] = fullNameStr;
            extractedData['name'] = fullNameStr; // Also set as general name
            debugPrint('👤 OCR extracted full name: $fullNameStr');
          }
        }
      }

      // Extract agent name - look for "Agent Name:" pattern
      if (line.contains('agent name:') && extractedData['agentName'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('agent name:');
        if (colonIndex != -1) {
          final agentNameStr = originalLine.substring(colonIndex + 11).trim();
          if (agentNameStr.isNotEmpty) {
            extractedData['agentName'] = agentNameStr;
            extractedData['name'] = agentNameStr; // Also set as general name
            debugPrint('👤 OCR extracted agent name: $agentNameStr');
          }
        }
      }

      // Extract phone number - look for "Phone Number:" pattern
      if (line.contains('phone number:') &&
          extractedData['phoneNumber'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('phone number:');
        if (colonIndex != -1) {
          final phoneNumberStr = originalLine.substring(colonIndex + 13).trim();
          if (phoneNumberStr.isNotEmpty) {
            extractedData['phoneNumber'] = phoneNumberStr;
            extractedData['phone'] =
                phoneNumberStr; // Also set as general phone
            debugPrint('👤 OCR extracted phone number: $phoneNumberStr');
          }
        }
      }

      // Extract Instagram username - look for "Instagram Username:" or "Instagram:" pattern
      if ((line.contains('instagram username:') ||
              (line.contains('instagram:') &&
                  !line.contains('instagram handle:'))) &&
          extractedData['instagramUsername'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf(
            line.contains('instagram username:')
                ? 'instagram username:'
                : 'instagram:');
        if (colonIndex != -1) {
          final fieldLength = line.contains('instagram username:') ? 18 : 10;
          final instagramStr =
              originalLine.substring(colonIndex + fieldLength).trim();
          if (instagramStr.isNotEmpty) {
            extractedData['instagramUsername'] = instagramStr;
            extractedData['instagram'] =
                instagramStr; // Also set as general instagram
            debugPrint('👤 OCR extracted instagram: $instagramStr');
          }
        }
      }

      // Extract experience - look for "Experience:" pattern
      if (line.contains('experience:') && extractedData['experience'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('experience:');
        if (colonIndex != -1) {
          final experienceStr = originalLine.substring(colonIndex + 11).trim();
          if (experienceStr.isNotEmpty) {
            extractedData['experience'] = experienceStr;
            debugPrint('👤 OCR extracted experience: $experienceStr');
          }
        }
      }

      // Extract specialization - look for "Specialization:" pattern (if not already set)
      if (line.contains('specialization:') &&
          extractedData['specialization'] == null) {
        final colonIndex =
            originalLine.toLowerCase().indexOf('specialization:');
        if (colonIndex != -1) {
          final specializationStr =
              originalLine.substring(colonIndex + 15).trim();
          if (specializationStr.isNotEmpty) {
            extractedData['specialization'] = specializationStr;
            debugPrint('👤 OCR extracted specialization: $specializationStr');
          }
        }
      }

      // Extract languages - look for "Languages:" pattern
      if (line.contains('languages:') && extractedData['languages'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('languages:');
        if (colonIndex != -1) {
          final languagesStr = originalLine.substring(colonIndex + 10).trim();
          if (languagesStr.isNotEmpty) {
            extractedData['languages'] = languagesStr;
            debugPrint('👤 OCR extracted languages: $languagesStr');
          }
        }
      }

      // Extract availability - look for "Availability:" pattern
      if (line.contains('availability:') &&
          extractedData['availability'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('availability:');
        if (colonIndex != -1) {
          final availabilityStr =
              originalLine.substring(colonIndex + 13).trim();
          if (availabilityStr.isNotEmpty) {
            extractedData['availability'] = availabilityStr;
            debugPrint('👤 OCR extracted availability: $availabilityStr');
          }
        }
      }

      // === INDUSTRY CONTACT-SPECIFIC FIELDS ===

      // Extract contact name - look for "Contact Name:" pattern
      if (line.contains('contact name:') &&
          extractedData['contactName'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('contact name:');
        if (colonIndex != -1) {
          final contactNameStr = originalLine.substring(colonIndex + 13).trim();
          if (contactNameStr.isNotEmpty) {
            extractedData['contactName'] = contactNameStr;
            extractedData['name'] = contactNameStr; // Also set as general name
            debugPrint('🏭 OCR extracted contact name: $contactNameStr');
          }
        }
      }

      // Extract job title - look for "Job Title:" pattern (if not already set)
      if (line.contains('job title:') && extractedData['jobTitle'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('job title:');
        if (colonIndex != -1) {
          final jobTitleStr = originalLine.substring(colonIndex + 10).trim();
          if (jobTitleStr.isNotEmpty) {
            extractedData['jobTitle'] = jobTitleStr;
            debugPrint('🏭 OCR extracted job title: $jobTitleStr');
          }
        }
      }

      // Extract mobile phone - look for "Mobile Phone:" or "Mobile:" pattern
      if ((line.contains('mobile phone:') ||
              (line.contains('mobile:') && !line.contains('mobile number:'))) &&
          extractedData['mobilePhone'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf(
            line.contains('mobile phone:') ? 'mobile phone:' : 'mobile:');
        if (colonIndex != -1) {
          final fieldLength = line.contains('mobile phone:') ? 13 : 7;
          final mobileStr =
              originalLine.substring(colonIndex + fieldLength).trim();
          if (mobileStr.isNotEmpty) {
            extractedData['mobilePhone'] = mobileStr;
            extractedData['mobile'] = mobileStr; // Also set as mobile
            debugPrint('🏭 OCR extracted mobile phone: $mobileStr');
          }
        }
      }

      // Extract portfolio - look for "Portfolio:" pattern
      if (line.contains('portfolio:') && extractedData['portfolio'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('portfolio:');
        if (colonIndex != -1) {
          final portfolioStr = originalLine.substring(colonIndex + 10).trim();
          if (portfolioStr.isNotEmpty) {
            extractedData['portfolio'] = portfolioStr;
            debugPrint('🏭 OCR extracted portfolio: $portfolioStr');
          }
        }
      }

      // Extract position - look for "Position:" pattern (maps to job title if not set)
      if (line.contains('position:') && extractedData['position'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('position:');
        if (colonIndex != -1) {
          final positionStr = originalLine.substring(colonIndex + 9).trim();
          if (positionStr.isNotEmpty) {
            extractedData['position'] = positionStr;
            // Also set as job title if job title not already set
            if (extractedData['jobTitle'] == null) {
              extractedData['jobTitle'] = positionStr;
            }
            debugPrint('🏭 OCR extracted position: $positionStr');
          }
        }
      }

      // Extract role - look for "Role:" pattern (maps to job title if not set)
      if (line.contains('role:') && extractedData['role'] == null) {
        final colonIndex = originalLine.toLowerCase().indexOf('role:');
        if (colonIndex != -1) {
          final roleStr = originalLine.substring(colonIndex + 5).trim();
          if (roleStr.isNotEmpty) {
            extractedData['role'] = roleStr;
            // Also set as job title if job title not already set
            if (extractedData['jobTitle'] == null) {
              extractedData['jobTitle'] = roleStr;
            }
            debugPrint('🏭 OCR extracted role: $roleStr');
          }
        }
      }

      // Extract title - look for "Title:" pattern (maps to job title if not set and not already used for event title)
      if (line.contains('title:') &&
          extractedData['title'] == null &&
          !line.contains('job title:') &&
          !line.contains('event title:')) {
        final colonIndex = originalLine.toLowerCase().indexOf('title:');
        if (colonIndex != -1) {
          final titleStr = originalLine.substring(colonIndex + 6).trim();
          if (titleStr.isNotEmpty) {
            extractedData['title'] = titleStr;
            // Also set as job title if job title not already set
            if (extractedData['jobTitle'] == null) {
              extractedData['jobTitle'] = titleStr;
            }
            debugPrint('🏭 OCR extracted title: $titleStr');
          }
        }
      }
    }

    // If no client name found, try to find it after "OPTION AGREEMENT" or "JOB AGREEMENT" or use first substantial line
    if (extractedData['clientName'] == null && lines.isNotEmpty) {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if ((line.toLowerCase().contains('option agreement') ||
                line.toLowerCase().contains('job agreement')) &&
            i + 1 < lines.length) {
          // Skip empty lines and look for client info
          for (int j = i + 1; j < lines.length; j++) {
            if (lines[j].isNotEmpty &&
                !_isDateOrTime(lines[j]) &&
                lines[j].length > 3) {
              extractedData['clientName'] = lines[j];
              break;
            }
          }
          break;
        }
      }
    }

    // Add default agent if none was extracted
    if (extractedData['bookingAgent'] == null) {
      extractedData['bookingAgent'] = 'ogbhai(uzibhaikiagencykoishak)';
    }

    // Extract only description and contact info for notes
    final notesLines = <String>[];
    bool inDescriptionSection = false;
    bool inContactSection = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      final originalLine = lines[i];

      // Check if we're entering description section
      if (line.contains('this is') ||
          line.contains('description') ||
          line.contains('campaign') ||
          line.contains('shoot')) {
        inDescriptionSection = true;
      }

      // Check if we're entering contact section
      if (line.contains('contact') ||
          line.contains('phone') ||
          line.contains('email') ||
          line.contains('@')) {
        inContactSection = true;
      }

      // Add lines that are part of description or contact
      if (inDescriptionSection || inContactSection) {
        // Skip lines that are clearly form fields
        if (!line.contains('client:') &&
            !line.contains('date:') &&
            !line.contains('location:') &&
            !line.contains('rate:') &&
            !line.contains('time:') &&
            !line.contains('agent:') &&
            !line.contains('status:') &&
            !line.contains('job type:') &&
            !line.contains('option type:') &&
            !line.contains('extra hours:') &&
            !line.contains('agency fee:') &&
            !line.contains('tax:') &&
            !line.contains('currency:') &&
            !line.contains('payment:') &&
            !line.contains('option agreement') &&
            !line.contains('job agreement') &&
            // OnStay specific field exclusions
            !line.contains('agency:') &&
            !line.contains('agency address:') &&
            !line.contains('hotel address:') &&
            !line.contains('hotel cost:') &&
            !line.contains('flight cost:') &&
            !line.contains('pocket money:') &&
            !line.contains('check-in:') &&
            !line.contains('check-out:') &&
            !line.contains('contract details:') &&
            !line.contains('on stay accommodation')) {
          notesLines.add(originalLine);
        }
      }
    }

    // Build comprehensive notes from extracted fields and remaining text
    final notesBuilder = StringBuffer();

    // Add contact info to notes if available
    if (extractedData['contactInfo'] != null) {
      notesBuilder.writeln('Contact: ${extractedData['contactInfo']}');
    }

    // Add job details to notes if available
    if (extractedData['title'] != null) {
      notesBuilder.writeln('Title: ${extractedData['title']}');
    }
    if (extractedData['mediaType'] != null) {
      notesBuilder.writeln('Media: ${extractedData['mediaType']}');
    }
    if (extractedData['usagePeriod'] != null) {
      notesBuilder.writeln('Usage Period: ${extractedData['usagePeriod']}');
    }
    if (extractedData['releaseCountry'] != null) {
      notesBuilder
          .writeln('Release Country: ${extractedData['releaseCountry']}');
    }
    if (extractedData['exclusivity'] != null) {
      notesBuilder.writeln('Exclusivity: ${extractedData['exclusivity']}');
    }
    if (extractedData['shootingSchedule'] != null) {
      notesBuilder
          .writeln('Shooting Schedule: ${extractedData['shootingSchedule']}');
    }
    if (extractedData['budget'] != null) {
      notesBuilder.writeln('Budget: ${extractedData['budget']}');
    }

    // Add any remaining notes
    if (notesLines.isNotEmpty) {
      if (notesBuilder.isNotEmpty) notesBuilder.writeln();
      notesBuilder.write(notesLines.join('\n'));
    }

    extractedData['notes'] = notesBuilder.toString().trim();

    debugPrint('=== OCR PARSING COMPLETE ===');
    debugPrint('Final extracted data: $extractedData');
    debugPrint('Keys found: ${extractedData.keys.toList()}');
    extractedData.forEach((key, value) {
      debugPrint('  $key: "$value"');
    });
    debugPrint('=== END OCR PARSING ===');
    return extractedData;
  }

  // Helper methods
  static double? _extractRateFromString(String rateStr) {
    // Remove currency symbols and clean the string
    final cleanStr = rateStr.replaceAll(RegExp(r'[\$€£,]'), '').trim();
    return double.tryParse(cleanStr);
  }

  static bool _containsDatePattern(String line) {
    return RegExp(r'\b\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}\b').hasMatch(line) ||
        RegExp(r'\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+\d{1,2}',
                caseSensitive: false)
            .hasMatch(line);
  }

  static bool _containsTimePattern(String line) {
    return RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(line);
  }

  static bool _isDateOrTime(String line) {
    return _containsDatePattern(line) || _containsTimePattern(line);
  }

  /// Test method to verify OCR parsing with sample data
  static Map<String, dynamic> testParsingWithSampleData() {
    const sampleText = '''
Client SAMSUNG
Contact Adrien Gras | IMM BELGIUM
Agent kubafrancyzk
Info Job details :
Title : Samsung Galaxy Book 5
Media : All electronic, digital, All print, Online
Usage Period : 1year
Release country : Global
Exclusivity : Non
Shooting Schedule : 2nd week of May 2025
Shooting location : TBC
Budget : 6000 euros gross
''';

    debugPrint('🧪 Testing OCR parsing with sample data...');
    final result = parseTextForOptions(sampleText);
    debugPrint('🧪 Test result: $result');
    return result;
  }

  /// Dispose resources
  static void dispose() {
    _textRecognizer.close();
  }
}
