import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_storage_service.dart';

/// Service for handling file uploads across all forms
class FileUploadService {
  
  /// Convert PlatformFile to XFile for Firebase Storage upload
  static XFile platformFileToXFile(PlatformFile platformFile) {
    if (kIsWeb) {
      return XFile.fromData(
        platformFile.bytes!,
        name: platformFile.name,
        mimeType: _getMimeType(platformFile.extension ?? ''),
      );
    } else {
      return XFile(
        platformFile.path!,
        name: platformFile.name,
        mimeType: _getMimeType(platformFile.extension ?? ''),
      );
    }
  }

  /// Upload multiple files for a specific event/job
  static Future<List<String>> uploadEventFiles({
    required List<PlatformFile> files,
    required String eventId,
    required String eventType,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      if (files.isEmpty) return [];

      final List<String> downloadUrls = [];
      
      for (int i = 0; i < files.length; i++) {
        final platformFile = files[i];
        final xFile = platformFileToXFile(platformFile);
        
        // Call progress callback
        onProgress?.call(i + 1, files.length);
        
        final downloadUrl = await FirebaseStorageService.uploadJobFile(
          xFile,
          eventId,
          eventType,
        );
        
        if (downloadUrl != null) {
          downloadUrls.add(downloadUrl);
        }
      }

      debugPrint('✅ Uploaded ${downloadUrls.length}/${files.length} files for $eventType');
      return downloadUrls;
    } catch (e) {
      debugPrint('❌ Error uploading files for $eventType: $e');
      return [];
    }
  }

  /// Upload files using the multiple files method from FirebaseStorageService
  static Future<List<String>> uploadMultipleFiles({
    required List<PlatformFile> files,
    required String eventId,
    required String eventType,
    Function(int current, int total)? onProgress,
  }) async {
    try {
      if (files.isEmpty) return [];

      // Convert PlatformFiles to XFiles
      final List<XFile> xFiles = files.map((file) => platformFileToXFile(file)).toList();
      
      // Upload using FirebaseStorageService
      final downloadUrls = await FirebaseStorageService.uploadMultipleFiles(
        xFiles,
        eventId,
        eventType,
      );

      debugPrint('✅ Uploaded ${downloadUrls.length}/${files.length} files for $eventType');
      return downloadUrls;
    } catch (e) {
      debugPrint('❌ Error uploading multiple files for $eventType: $e');
      return [];
    }
  }

  /// Pick files with specified types
  static Future<List<PlatformFile>?> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
    FileType fileType = FileType.any,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: allowMultiple,
        type: fileType,
        allowedExtensions: allowedExtensions,
      );

      return result?.files;
    } catch (e) {
      debugPrint('❌ Error picking files: $e');
      return null;
    }
  }

  /// Pick common document and image files
  static Future<List<PlatformFile>?> pickDocumentAndImageFiles({
    bool allowMultiple = true,
  }) async {
    return await pickFiles(
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'csv',
        'png', 'jpg', 'jpeg', 'gif', 'webp'
      ],
      allowMultiple: allowMultiple,
      fileType: FileType.custom,
    );
  }

  /// Get file icon based on extension
  static String getFileIcon(String? extension) {
    if (extension == null) return '📄';
    
    switch (extension.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'doc':
      case 'docx':
        return '📝';
      case 'xls':
      case 'xlsx':
      case 'csv':
        return '📊';
      case 'txt':
        return '📃';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return '🖼️';
      case 'mp4':
      case 'mov':
      case 'avi':
        return '🎥';
      case 'mp3':
      case 'wav':
        return '🎵';
      case 'zip':
      case 'rar':
        return '🗜️';
      default:
        return '📄';
    }
  }

  /// Get file size in human readable format
  static String getFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Validate file size (default 50MB limit)
  static bool isFileSizeValid(int bytes, {int maxSizeInMB = 50}) {
    final maxSizeInBytes = maxSizeInMB * 1024 * 1024;
    return bytes <= maxSizeInBytes;
  }

  /// Validate file type
  static bool isFileTypeAllowed(String? extension, List<String> allowedExtensions) {
    if (extension == null) return false;
    return allowedExtensions.contains(extension.toLowerCase());
  }

  /// Get MIME type from extension
  static String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'csv':
        return 'text/csv';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }

  /// Create file data for database storage
  static Map<String, dynamic> createFileData({
    required List<String> downloadUrls,
    required List<PlatformFile> originalFiles,
  }) {
    final List<Map<String, dynamic>> fileList = [];
    
    for (int i = 0; i < downloadUrls.length && i < originalFiles.length; i++) {
      final file = originalFiles[i];
      fileList.add({
        'name': file.name,
        'url': downloadUrls[i],
        'size': file.size,
        'extension': file.extension,
        'uploadedAt': DateTime.now().toIso8601String(),
      });
    }

    return {
      'files': fileList,
      'fileCount': fileList.length,
      'totalSize': originalFiles.fold<int>(0, (sum, file) => sum + file.size),
    };
  }

  /// Extract file URLs from file data
  static List<String> extractFileUrls(Map<String, dynamic>? fileData) {
    if (fileData == null || fileData['files'] == null) return [];
    
    final files = fileData['files'] as List<dynamic>;
    return files.map((file) => file['url'] as String).toList();
  }

  /// Delete files from storage
  static Future<void> deleteEventFiles(Map<String, dynamic>? fileData) async {
    final urls = extractFileUrls(fileData);
    if (urls.isNotEmpty) {
      await FirebaseStorageService.deleteMultipleFiles(urls);
    }
  }
}
