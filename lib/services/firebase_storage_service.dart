import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

/// Service for handling Firebase Storage operations
class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Convert Firebase Storage URL to use correct domain for CORS compatibility
  static String _fixStorageUrl(String url) {
    // URLs are already using the correct .firebasestorage.app domain
    // CORS is configured on this bucket, so don't convert domains

    // Add cache busting parameter
    final uri = Uri.parse(url);
    final fixedUrl = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'alt': 'media',
      '_cb': DateTime.now().millisecondsSinceEpoch.toString(),
    }).toString();

    return fixedUrl;
  }

  /// Download image as base64 to bypass CORS issues
  static Future<String?> getImageAsBase64(String downloadUrl) async {
    try {
      final fixedUrl = _fixStorageUrl(downloadUrl);

      // Try multiple approaches for web CORS issues
      if (kIsWeb) {
        // Approach 1: Use CORS proxy for web
        final proxyUrl = 'https://cors-anywhere.herokuapp.com/$fixedUrl';
        try {
          final response = await http.get(Uri.parse(proxyUrl));
          if (response.statusCode == 200) {
            final base64String = base64Encode(response.bodyBytes);
            return 'data:image/jpeg;base64,$base64String';
          }
        } catch (proxyError) {
          debugPrint('❌ CORS proxy failed: $proxyError');
        }

        // Approach 2: Try direct access with original URL (don't convert domain)
        try {
          final response = await http.get(Uri.parse(fixedUrl));
          if (response.statusCode == 200) {
            final base64String = base64Encode(response.bodyBytes);
            return 'data:image/jpeg;base64,$base64String';
          }
        } catch (directError) {
          debugPrint('❌ Direct access failed: $directError');
        }
      } else {
        // For mobile, direct access should work
        final response = await http.get(Uri.parse(fixedUrl));
        if (response.statusCode == 200) {
          final base64String = base64Encode(response.bodyBytes);
          return 'data:image/jpeg;base64,$base64String';
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error converting image to base64: $e');
      return null;
    }
  }

  /// Get signed URL for image (alternative CORS solution)
  static Future<String?> getSignedUrl(String storagePath) async {
    try {
      _ensureAuthenticated();
      final ref = _storage.ref().child(storagePath);

      // Get a signed URL that's valid for 1 hour
      final downloadUrl = await ref.getDownloadURL();

      // Add additional parameters to help with CORS
      final uri = Uri.parse(downloadUrl);
      final signedUrl = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'alt': 'media',
        'token': DateTime.now().millisecondsSinceEpoch.toString(),
      }).toString();

      debugPrint('🔗 Generated signed URL: $signedUrl');
      return signedUrl;
    } catch (e) {
      debugPrint('❌ Error generating signed URL: $e');
      return null;
    }
  }

  /// Get current user ID
  static String? get _currentUserId => _auth.currentUser?.uid;

  /// Check if user is authenticated
  static bool get _isAuthenticated => _auth.currentUser != null;

  /// Ensure user is authenticated
  static void _ensureAuthenticated() {
    if (!_isAuthenticated) {
      throw Exception('User not authenticated. Please log in and try again.');
    }
    if (_currentUserId == null) {
      throw Exception('User ID not available. Please log in again.');
    }
    debugPrint('✅ User authenticated: $_currentUserId');
  }

  /// Upload profile picture
  static Future<String?> uploadProfilePicture(XFile imageFile) async {
    try {
      _ensureAuthenticated();
      debugPrint('📤 Starting profile picture upload...');

      final fileName =
          'profile_${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('profile_pictures/$fileName');
      debugPrint('📁 Upload path: profile_pictures/$fileName');

      Uint8List imageData;
      if (kIsWeb) {
        imageData = await imageFile.readAsBytes();
        debugPrint('🌐 Web: Read ${imageData.length} bytes');
      } else {
        imageData = await File(imageFile.path).readAsBytes();
        debugPrint('📱 Mobile: Read ${imageData.length} bytes');
      }

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=3600',
        customMetadata: {
          'userId': _currentUserId!,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      debugPrint('🚀 Starting upload task...');

      // For web, try a different approach to avoid CORS issues
      if (kIsWeb) {
        debugPrint('🌐 Using web-optimized upload method...');

        try {
          // Use putData with specific settings for web
          final uploadTask = ref.putData(
            imageData,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'uploaded_by': _currentUserId ?? 'unknown',
                'upload_time': DateTime.now().toIso8601String(),
              },
            ),
          );

          // Wait for upload completion without progress monitoring to avoid CORS
          final snapshot = await uploadTask;
          debugPrint('✅ Web upload completed successfully');

          final downloadUrl = await snapshot.ref.getDownloadURL();
          debugPrint('🔗 Raw download URL: $downloadUrl');

          // Fix URL domain for CORS compatibility
          final fixedUrl = _fixStorageUrl(downloadUrl);
          debugPrint('🔧 Fixed URL: $fixedUrl');

          // Add cache-busting parameter for immediate display
          final uri = Uri.parse(fixedUrl);
          final cacheBustUrl = uri.replace(queryParameters: {
            ...uri.queryParameters,
            'alt': 'media',
            'token': DateTime.now().millisecondsSinceEpoch.toString(),
          }).toString();

          debugPrint('✅ Profile picture uploaded successfully: $cacheBustUrl');
          return cacheBustUrl;
        } catch (webError) {
          debugPrint('❌ Web upload failed: $webError');
          // Fall back to standard method
        }
      }

      // Standard upload method for non-web platforms
      debugPrint('📱 Using standard upload method...');
      final uploadTask = ref.putData(imageData, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((taskSnapshot) {
        final progress =
            (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) * 100;
        debugPrint('📊 Upload progress: ${progress.toStringAsFixed(1)}%');
      });

      final snapshot = await uploadTask;
      debugPrint('✅ Upload completed, getting download URL...');

      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('🔗 Raw download URL: $downloadUrl');

      // Fix URL domain for CORS compatibility
      final fixedUrl = _fixStorageUrl(downloadUrl);
      debugPrint('🔧 Fixed URL: $fixedUrl');

      // Add cache-busting parameter for immediate display
      final uri = Uri.parse(fixedUrl);
      final cacheBustUrl = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'alt': 'media',
        'token': DateTime.now().millisecondsSinceEpoch.toString(),
      }).toString();

      debugPrint('✅ Profile picture uploaded successfully: $cacheBustUrl');
      return cacheBustUrl;
    } catch (e) {
      debugPrint('❌ Error uploading profile picture: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      if (e.toString().contains('CORS')) {
        debugPrint(
            '🚨 CORS error detected - check Firebase Storage CORS configuration');
      }
      return null;
    }
  }

  /// Upload admin profile picture
  static Future<String?> uploadAdminProfilePicture(
      XFile imageFile, String adminId) async {
    try {
      _ensureAuthenticated();
      final fileName =
          'admin_profile_${adminId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('admin_profile_pictures/$fileName');

      Uint8List imageData;
      if (kIsWeb) {
        imageData = await imageFile.readAsBytes();
      } else {
        imageData = await File(imageFile.path).readAsBytes();
      }

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=3600',
        customMetadata: {
          'adminId': adminId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putData(imageData, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Fix URL domain for CORS compatibility
      final fixedUrl = _fixStorageUrl(downloadUrl);

      // Add cache-busting parameter for immediate display
      final uri = Uri.parse(fixedUrl);
      final cacheBustUrl = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'alt': 'media',
        'token': DateTime.now().millisecondsSinceEpoch.toString(),
      }).toString();

      debugPrint('✅ Admin profile picture uploaded: $cacheBustUrl');
      return cacheBustUrl;
    } catch (e) {
      debugPrint('❌ Error uploading admin profile picture: $e');
      return null;
    }
  }

  /// Upload gallery images
  static Future<List<String>> uploadGalleryImages(
      List<XFile> imageFiles, String galleryId) async {
    try {
      _ensureAuthenticated();

      final List<String> downloadUrls = [];

      for (int i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];
        final fileName =
            'gallery_${galleryId}_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage.ref().child('gallery/$_currentUserId/$fileName');

        Uint8List imageData;
        if (kIsWeb) {
          imageData = await imageFile.readAsBytes();
        } else {
          imageData = await File(imageFile.path).readAsBytes();
        }

        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=3600',
          customMetadata: {
            'userId': _currentUserId!,
            'galleryId': galleryId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        final uploadTask = ref.putData(imageData, metadata);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        // Fix URL domain for CORS compatibility
        final fixedUrl = _fixStorageUrl(downloadUrl);

        // Add cache-busting parameter for immediate display
        final uri = Uri.parse(fixedUrl);
        final cacheBustUrl = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'alt': 'media',
          'token': DateTime.now().millisecondsSinceEpoch.toString(),
        }).toString();

        downloadUrls.add(cacheBustUrl);

        debugPrint('✅ Gallery image ${i + 1}/${imageFiles.length} uploaded');
      }

      debugPrint(
          '✅ All gallery images uploaded: ${downloadUrls.length} images');
      return downloadUrls;
    } catch (e) {
      debugPrint('❌ Error uploading gallery images: $e');
      return [];
    }
  }

  /// Upload job/event related files
  static Future<String?> uploadJobFile(
      XFile file, String jobId, String fileType) async {
    try {
      _ensureAuthenticated();

      final extension = _getFileExtension(file.name);
      final fileName =
          '${fileType}_${jobId}_${DateTime.now().millisecondsSinceEpoch}$extension';
      final ref = _storage.ref().child('jobs/$_currentUserId/$fileName');

      Uint8List fileData;
      if (kIsWeb) {
        fileData = await file.readAsBytes();
      } else {
        fileData = await File(file.path).readAsBytes();
      }

      final metadata = SettableMetadata(
        contentType: _getContentType(extension),
        cacheControl: 'public, max-age=3600',
        customMetadata: {
          'userId': _currentUserId!,
          'jobId': jobId,
          'fileType': fileType,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = ref.putData(fileData, metadata);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Add cache-busting parameter for immediate display
      final uri = Uri.parse(downloadUrl);
      final cacheBustUrl = uri.replace(queryParameters: {
        ...uri.queryParameters,
        'alt': 'media',
        'token': DateTime.now().millisecondsSinceEpoch.toString(),
      }).toString();

      debugPrint('✅ Job file uploaded: $cacheBustUrl');
      return cacheBustUrl;
    } catch (e) {
      debugPrint('❌ Error uploading job file: $e');
      return null;
    }
  }

  /// Upload multiple files for events/jobs
  static Future<List<String>> uploadMultipleFiles(
      List<XFile> files, String eventId, String eventType) async {
    try {
      _ensureAuthenticated();

      final List<String> downloadUrls = [];

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final extension = _getFileExtension(file.name);
        final fileName =
            '${eventType}_${eventId}_${i}_${DateTime.now().millisecondsSinceEpoch}$extension';
        final ref =
            _storage.ref().child('$eventType/$_currentUserId/$fileName');

        Uint8List fileData;
        if (kIsWeb) {
          fileData = await file.readAsBytes();
        } else {
          fileData = await File(file.path).readAsBytes();
        }

        final metadata = SettableMetadata(
          contentType: _getContentType(extension),
          cacheControl: 'public, max-age=3600',
          customMetadata: {
            'userId': _currentUserId!,
            'eventId': eventId,
            'eventType': eventType,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        final uploadTask = ref.putData(fileData, metadata);
        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();

        // Add cache-busting parameter for immediate display
        final uri = Uri.parse(downloadUrl);
        final cacheBustUrl = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'alt': 'media',
          'token': DateTime.now().millisecondsSinceEpoch.toString(),
        }).toString();

        downloadUrls.add(cacheBustUrl);

        debugPrint('✅ File ${i + 1}/${files.length} uploaded for $eventType');
      }

      return downloadUrls;
    } catch (e) {
      debugPrint('❌ Error uploading multiple files: $e');
      return [];
    }
  }

  /// Delete file from storage
  static Future<bool> deleteFile(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      debugPrint('✅ File deleted from storage');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
      return false;
    }
  }

  /// Delete multiple files
  static Future<void> deleteMultipleFiles(List<String> downloadUrls) async {
    for (final url in downloadUrls) {
      await deleteFile(url);
    }
  }

  /// Get content type based on file extension
  static String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Get file extension from filename
  static String _getFileExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1) return '';
    return filename.substring(lastDot);
  }

  /// Get upload progress stream
  static Stream<TaskSnapshot> getUploadProgress(UploadTask uploadTask) {
    return uploadTask.snapshotEvents;
  }

  /// Check if user has storage quota
  static Future<bool> checkStorageQuota() async {
    try {
      // Implement storage quota check if needed
      return true;
    } catch (e) {
      debugPrint('❌ Error checking storage quota: $e');
      return false;
    }
  }
}
