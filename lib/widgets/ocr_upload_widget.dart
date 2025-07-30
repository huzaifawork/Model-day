import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/ocr_service.dart';
import 'ui/button.dart';

class OcrUploadWidget extends StatefulWidget {
  final Function(Map<String, dynamic>)? onDataExtracted;
  final VoidCallback? onClose;
  final VoidCallback? onAutoSubmit; // New callback for auto-submission

  const OcrUploadWidget({
    super.key,
    this.onDataExtracted,
    this.onClose,
    this.onAutoSubmit,
  });

  @override
  State<OcrUploadWidget> createState() => _OcrUploadWidgetState();
}

class _OcrUploadWidgetState extends State<OcrUploadWidget> {
  final TextEditingController _textController = TextEditingController();
  bool _isProcessing = false;
  XFile? _selectedImage;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleImageUpload() async {
    try {
      // Show options for camera or gallery
      final source = await _showImageSourceDialog();
      if (source == null) return;

      setState(() {
        _isProcessing = true;
      });

      XFile? imageFile;
      if (source == ImageSource.camera) {
        imageFile = await OcrService.pickImageFromCamera();
      } else {
        imageFile = await OcrService.pickImageFromGallery();
      }

      if (imageFile == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Store the selected image for preview
      setState(() {
        _selectedImage = imageFile;
      });

      // Extract text from image
      final extractedText = await OcrService.extractTextFromImage(imageFile);

      if (extractedText == null || extractedText.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(kIsWeb
                  ? 'Image OCR is not supported in web browsers. Please use the "Paste Text" feature below instead.'
                  : 'No text found in the image. Please try a clearer image.'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Parse the extracted text
      final extractedData = OcrService.parseTextForOptions(extractedText);

      // Call the callback with extracted data
      widget.onDataExtracted?.call(extractedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Text extracted successfully from image! Creating option...'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }

      // Auto-submit after a short delay to allow form fields to be populated
      if (widget.onAutoSubmit != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          widget.onAutoSubmit!();
        }
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text(
            'Select Image Source',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.camera_alt, color: AppTheme.goldColor),
                title: const Text(
                  'Camera',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: AppTheme.goldColor),
                title: const Text(
                  'Gallery',
                  style: TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleExtractFromText() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste some text to extract information'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Parse the pasted text using OCR service
      debugPrint('=== OCR WIDGET PROCESSING ===');
      debugPrint('Input text: ${_textController.text}');
      final extractedData =
          OcrService.parseTextForOptions(_textController.text);
      debugPrint('OCR Widget extracted data: $extractedData');

      // Call the callback with extracted data
      debugPrint('Calling onDataExtracted callback...');
      debugPrint('Callback function exists: ${widget.onDataExtracted != null}');
      if (widget.onDataExtracted != null) {
        widget.onDataExtracted!(extractedData);
        debugPrint('Callback called successfully');
      } else {
        debugPrint('ERROR: No callback function provided!');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text parsed successfully! Creating option...'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }

      // Auto-submit after a short delay to allow form fields to be populated
      if (widget.onAutoSubmit != null) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          widget.onAutoSubmit!();
        }
      }
    } catch (e) {
      debugPrint('Error parsing text: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error parsing text: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Build dotted border container
  Widget _buildDottedBorder({required Widget child}) {
    return CustomPaint(
      painter: DottedBorderPainter(),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColorLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: child,
      ),
    );
  }

  /// Build extract button
  Widget _buildExtractButton() {
    if (_selectedImage == null) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: AppTheme.spacingMd),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _handleImageUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isProcessing
                  ? AppTheme.textSecondary
                  : const Color(0xFF8B7355), // Brown color like in image
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isProcessing) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('Processing...'),
                ] else ...[
                  const Icon(Icons.text_fields, size: 18),
                  const SizedBox(width: 8),
                  const Text('Extract from Image'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build image preview widget with "Preview:" label
  Widget _buildImagePreviewWithLabel() {
    if (_selectedImage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Preview:" label with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Preview:',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedImage = null;
                  });
                },
                child: const Icon(
                  Icons.close,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Image preview
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: kIsWeb
                    ? Image.network(
                        _selectedImage!.path,
                        fit: BoxFit
                            .cover, // Changed from contain to cover for better web display
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: AppTheme.textSecondary,
                              size: 32,
                            ),
                          );
                        },
                      )
                    : Image.file(
                        File(_selectedImage!.path),
                        fit: BoxFit
                            .contain, // Keep contain for mobile for full image view
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.image_not_supported,
                              color: AppTheme.textSecondary,
                              size: 32,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebLargeScreen = kIsWeb && screenWidth > 768;

    return Container(
      decoration: AppTheme.cardDecoration,
      padding: EdgeInsets.all(
          isWebLargeScreen ? AppTheme.spacingXl : AppTheme.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add New Option',
                style: TextStyle(
                  color: AppTheme.goldColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(
                    Icons.close,
                    color: AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // AI Form Assistant Section
          Container(
            width: double.infinity, // Ensure full width
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.borderColor),
            ),
            padding: EdgeInsets.all(
                isWebLargeScreen ? AppTheme.spacingLg : AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Form Assistant',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // Blue info box
                Container(
                  width: double.infinity, // Ensure full width
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A), // Dark blue background
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border:
                        Border.all(color: const Color(0xFF3B82F6), width: 1),
                  ),
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  child: const Text(
                    'For best results with dark background images, try to crop the image to focus on just the text areas.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),

                // Upload Image Section
                const Text(
                  'Upload Image',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),

                // Dotted border container
                GestureDetector(
                  onTap: _selectedImage == null ? _handleImageUpload : null,
                  child: _buildDottedBorder(
                    child: SizedBox(
                      height: _selectedImage != null
                          ? (kIsWeb ? 300 : 200) // Increased height for web
                          : 120,
                      width: double.infinity,
                      child: _selectedImage != null
                          ? _buildImagePreviewWithLabel()
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.upload_outlined,
                                    color: AppTheme.textSecondary,
                                    size: 32,
                                  ),
                                  SizedBox(height: AppTheme.spacingSm),
                                  Text(
                                    'Click to upload an image',
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Supports JPG, PNG, WEBP',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),

                // Extract/Processing Button
                _buildExtractButton(),

                const SizedBox(height: AppTheme.spacingLg),

                // Or Paste Text Section
                const Text(
                  'Or Paste Text',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),

                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColorLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: TextFormField(
                    controller: _textController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Paste text here to extract information...',
                      hintStyle: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(AppTheme.spacingMd),
                    ),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),

                // Extract Button
                SizedBox(
                  width: double.infinity,
                  child: Button(
                    onPressed: _isProcessing ? null : _handleExtractFromText,
                    text: _isProcessing ? 'Processing...' : 'Extract from Text',
                    variant: ButtonVariant.primary,
                    isLoading: _isProcessing,
                    prefix: _isProcessing
                        ? null
                        : const Icon(
                            Icons.search,
                            color: Colors.black,
                            size: 18,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for dotted border
class DottedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.borderColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    final radius = AppTheme.radiusSm;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    _drawDashedPath(canvas, path, paint, dashWidth, dashSpace);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, double dashWidth,
      double dashSpace) {
    final pathMetrics = path.computeMetrics();
    for (final pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final nextDistance = distance + dashWidth;
        final extractPath = pathMetric.extractPath(
          distance,
          nextDistance > pathMetric.length ? pathMetric.length : nextDistance,
        );
        canvas.drawPath(extractPath, paint);
        distance = nextDistance + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
