import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/base64_image_widget.dart';
import '../theme/app_theme.dart';

/// Widget to display uploaded files with basic functionality
class FilePreviewWidget extends StatelessWidget {
  final Map<String, dynamic>? fileData;
  final bool showTitle;
  final int maxFilesToShow;

  const FilePreviewWidget({
    super.key,
    this.fileData,
    this.showTitle = true,
    this.maxFilesToShow = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (fileData == null || fileData!.isEmpty) {
      return const SizedBox.shrink();
    }

    debugPrint('🔍 FilePreviewWidget - fileData: $fileData');
    final files = _extractFileList(fileData!);
    if (files.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Row(
            children: [
              const Icon(Icons.attach_file,
                  size: 16, color: AppTheme.goldColor),
              const SizedBox(width: 8),
              Text(
                'Attached Files (${files.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.goldColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        ...files
            .take(maxFilesToShow)
            .map((file) => _buildFileItem(context, file)),
        if (files.length > maxFilesToShow) ...[
          const SizedBox(height: 8),
          Text(
            '... and ${files.length - maxFilesToShow} more files',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _extractFileList(Map<String, dynamic> fileData) {
    final List<Map<String, dynamic>> files = [];

    // Handle different file data structures
    if (fileData.containsKey('files') && fileData['files'] is List) {
      final filesList = fileData['files'] as List;
      for (final file in filesList) {
        if (file is Map<String, dynamic>) {
          files.add(file);
        }
      }
    }

    // Handle single file structure
    if (fileData.containsKey('url') && fileData['url'] != null) {
      files.add(fileData);
    }

    // Handle file_data structure
    if (fileData.containsKey('file_data') && fileData['file_data'] is Map) {
      final fileDataMap = fileData['file_data'] as Map<String, dynamic>;
      if (fileDataMap.containsKey('files') && fileDataMap['files'] is List) {
        final filesList = fileDataMap['files'] as List;
        for (final file in filesList) {
          if (file is Map<String, dynamic>) {
            files.add(file);
          }
        }
      }
    }

    return files;
  }

  Widget _buildFileItem(BuildContext context, Map<String, dynamic> file) {
    final String url = file['url'] ?? '';
    final String name = file['name'] ?? 'Unknown file';
    final String? extension = file['extension'];
    final int? size = file['size'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800]?.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[600]!.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // File icon or image preview
          _buildFileIcon(url, extension),
          const SizedBox(width: 12),

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (size != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatFileSize(size),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Copy URL button
              ElevatedButton(
                onPressed: () => _copyToClipboard(context, url),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(60, 32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('Copy', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),

              // Open/Download button
              ElevatedButton(
                onPressed: () => _openFile(context, url),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldColor,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(80, 32),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('Download', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileIcon(String url, String? extension) {
    // Check if it's an image
    if (_isImageFile(extension)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Base64ImageWidget(
          imageUrl: url,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getFileTypeColor(extension).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              _getFileIconData(extension),
              color: _getFileTypeColor(extension),
              size: 24,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getFileTypeColor(extension).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        _getFileIconData(extension),
        color: _getFileTypeColor(extension),
        size: 24,
      ),
    );
  }

  /// Get file type icon data
  IconData _getFileIconData(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Get file type color
  Color _getFileTypeColor(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'txt':
        return Colors.grey;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.purple;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Colors.pink;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return Colors.indigo;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Colors.teal;
      default:
        return AppTheme.goldColor;
    }
  }

  bool _isImageFile(String? extension) {
    if (extension == null) return false;
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    return imageExtensions.contains(extension.toLowerCase());
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _copyToClipboard(BuildContext context, String url) async {
    try {
      await Clipboard.setData(ClipboardData(text: url));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File URL copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error copying to clipboard: $e');
    }
  }

  Future<void> _openFile(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
