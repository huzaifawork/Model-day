import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/services/job_gallery_service.dart';
import 'package:new_flutter/services/firebase_storage_service.dart';
import 'package:new_flutter/services/logger_service.dart';
import 'package:new_flutter/models/job_gallery.dart';
import 'package:new_flutter/widgets/base64_image_widget.dart';

class NewJobGalleryPage extends StatefulWidget {
  const NewJobGalleryPage({super.key});

  @override
  State<NewJobGalleryPage> createState() => _NewJobGalleryPageState();
}

class _NewJobGalleryPageState extends State<NewJobGalleryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _photographerController = TextEditingController();
  final _locationController = TextEditingController();
  final _hairMakeupController = TextEditingController();
  final _stylistController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  final List<XFile> _selectedImages = [];
  bool _isSaving = false;
  JobGallery? _editingGallery; // Track if we're editing an existing gallery
  List<String> _existingImageUrls = []; // Store existing image URLs for editing

  @override
  void initState() {
    super.initState();
    // Handle edit mode - check for gallery argument after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is JobGallery) {
        _loadGalleryForEdit(args);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _photographerController.dispose();
    _locationController.dispose();
    _hairMakeupController.dispose();
    _stylistController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _loadGalleryForEdit(JobGallery gallery) {
    LoggerService.info('📝 Loading gallery for edit: ${gallery.name}');
    setState(() {
      _editingGallery = gallery;
      _nameController.text = gallery.name;
      _photographerController.text = gallery.photographerName ?? '';
      _locationController.text = gallery.location ?? '';
      _hairMakeupController.text = gallery.hairMakeup ?? '';
      _stylistController.text = gallery.stylist ?? '';
      _descriptionController.text = gallery.description ?? '';
      _selectedDate = gallery.date ?? DateTime.now();

      // Parse existing images
      if (gallery.images != null && gallery.images!.isNotEmpty) {
        try {
          final String imagesStr = gallery.images!;
          if (imagesStr.contains(',')) {
            _existingImageUrls = imagesStr
                .split(',')
                .map((url) => url.trim())
                .where((url) => url.isNotEmpty)
                .toList();
          } else if (imagesStr.isNotEmpty) {
            _existingImageUrls = [imagesStr];
          }
          LoggerService.info(
              '📸 Loaded ${_existingImageUrls.length} existing images for edit');
          for (int i = 0; i < _existingImageUrls.length; i++) {
            LoggerService.info(
                '📸 Image $i: ${_existingImageUrls[i].substring(0, 100)}...');
          }
        } catch (e) {
          LoggerService.error('❌ Error parsing existing images: $e');
        }
      }
    });
  }

  Future<void> _pickImages() async {
    try {
      LoggerService.info('📷 Starting image picker...');
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 65, // BALANCED: Good quality but still fast upload
        maxWidth: 1400, // BALANCED: Good resolution but compressed
        maxHeight: 800, // BALANCED: Good resolution but compressed
      );

      if (images.isNotEmpty) {
        LoggerService.info(
            '📷 Selected ${images.length} images with BALANCED compression (65% quality, 1400x800) for fast upload with good quality');

        // Log file sizes for performance tracking
        for (int i = 0; i < images.length; i++) {
          final bytes = await images[i].readAsBytes();
          final sizeKB = (bytes.length / 1024).round();
          LoggerService.info('📊 Image ${i + 1}: ${sizeKB}KB (compressed)');
        }

        setState(() {
          _selectedImages.addAll(images);
        });
        LoggerService.info(
            '✅ Added ${images.length} QUALITY-OPTIMIZED images to gallery (Total: ${_selectedImages.length}) - FAST + GOOD QUALITY');
      } else {
        LoggerService.info('📷 No images selected');
      }
    } catch (e) {
      LoggerService.error('❌ Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error selecting images. Please try again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    LoggerService.info(
        '🗑️ Removing image at index $index (${_selectedImages.length - 1} remaining)');
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// ULTRA-FAST parallel upload method for gallery images only
  Future<List<String>> _uploadGalleryImagesParallel(
      List<XFile> imageFiles, String galleryId) async {
    LoggerService.info(
        '🚀 Starting ULTRA-FAST PARALLEL upload of ${imageFiles.length} images');

    // Create upload futures for MAXIMUM parallel processing
    final uploadFutures = <Future<String?>>[];

    for (int i = 0; i < imageFiles.length; i++) {
      // Start ALL uploads immediately without waiting
      uploadFutures.add(_uploadSingleGalleryImageFast(
          imageFiles[i], galleryId, i, imageFiles.length));
    }

    // Execute ALL uploads simultaneously for maximum speed
    LoggerService.info(
        '⚡ FIRING ${uploadFutures.length} SIMULTANEOUS uploads for maximum speed...');
    final results = await Future.wait(uploadFutures);

    // Filter out null results (failed uploads)
    final downloadUrls =
        results.where((url) => url != null).cast<String>().toList();

    LoggerService.info(
        '🎉 ULTRA-FAST upload complete: ${downloadUrls.length}/${imageFiles.length} successful');
    return downloadUrls;
  }

  /// ULTRA-FAST single image upload with minimal overhead
  Future<String?> _uploadSingleGalleryImageFast(
      XFile imageFile, String galleryId, int index, int total) async {
    try {
      final uploadStartTime = DateTime.now();
      LoggerService.info('🚀 [${index + 1}/$total] FAST upload starting...');

      // Use existing Firebase service but with unique gallery ID per image for speed
      final result = await FirebaseStorageService.uploadGalleryImages(
          [imageFile], '${galleryId}_$index');

      final uploadEndTime = DateTime.now();
      final uploadDuration = uploadEndTime.difference(uploadStartTime);

      if (result.isNotEmpty) {
        LoggerService.info(
            '⚡ [${index + 1}/$total] FAST upload done in ${uploadDuration.inSeconds}s (${(uploadDuration.inMilliseconds / 1000).toStringAsFixed(1)}s)');
        return result.first;
      } else {
        LoggerService.error('❌ [${index + 1}/$total] FAST upload failed');
        return null;
      }
    } catch (e) {
      LoggerService.error('💥 [${index + 1}/$total] FAST upload error: $e');
      return null;
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.goldColor,
              onPrimary: Colors.black,
              surface: AppTheme.surfaceColor,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveGallery() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if we have images (either new or existing)
    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one image'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final totalOperationStartTime = DateTime.now();
    LoggerService.info(
        '🎬 TOTAL GALLERY SAVE OPERATION START: ${_selectedImages.length} images');

    try {
      // Generate a unique gallery ID for organizing images
      final galleryId = DateTime.now().millisecondsSinceEpoch.toString();

      // Handle images - combine existing and new images
      List<String> imageUrls = [];

      // Add existing images if we're editing
      if (_editingGallery != null) {
        imageUrls.addAll(_existingImageUrls);
        LoggerService.info(
            '📸 Keeping ${_existingImageUrls.length} existing images');
      }

      // Upload new images if any
      if (_selectedImages.isNotEmpty) {
        final uploadStartTime = DateTime.now();
        LoggerService.info(
            '🚀 LIGHTNING-FAST GALLERY UPLOAD START: ${_selectedImages.length} images at ${uploadStartTime.toIso8601String()}');
        LoggerService.info(
            '⚡ Starting FAST parallel upload of ${_selectedImages.length} quality-optimized images - FAST + GOOD QUALITY!');

        // Simple UI indicator without detailed progress
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uploading images...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Use optimized parallel upload for galleries
        LoggerService.info(
            '📤 Using optimized parallel upload for gallery images...');
        final newImageUrls =
            await _uploadGalleryImagesParallel(_selectedImages, galleryId);
        imageUrls.addAll(newImageUrls);

        final uploadEndTime = DateTime.now();
        final uploadDuration = uploadEndTime.difference(uploadStartTime);

        if (newImageUrls.length != _selectedImages.length) {
          LoggerService.error(
              '❌ UPLOAD FAILED: Only ${newImageUrls.length}/${_selectedImages.length} new images uploaded in ${uploadDuration.inSeconds}s');
          throw Exception(
              'Failed to upload all new images. Only ${newImageUrls.length}/${_selectedImages.length} uploaded.');
        }

        LoggerService.info(
            '🎉 LIGHTNING UPLOAD COMPLETE: ${newImageUrls.length} new images uploaded in ${uploadDuration.inSeconds}s (${(uploadDuration.inMilliseconds / _selectedImages.length).round()}ms per image) - ${uploadDuration.inSeconds < 60 ? "✅ UNDER 1 MINUTE!" : "⚠️ OVER 1 MINUTE"}');
        LoggerService.info(
            '⚡ Successfully uploaded ${newImageUrls.length} new images in ${uploadDuration.inSeconds} seconds');
      }

      final imagesJson = imageUrls.join(',');
      LoggerService.info(
          '📝 Preparing gallery data with ${imageUrls.length} image URLs');

      final galleryData = {
        'name': _nameController.text.trim(),
        'photographer_name': _photographerController.text.trim(),
        'location': _locationController.text.trim(),
        'hair_makeup': _hairMakeupController.text.trim(),
        'stylist': _stylistController.text.trim(),
        'date': _selectedDate.toIso8601String().split('T')[0],
        'description': _descriptionController.text.trim(),
        'images': imagesJson,
        'gallery_id': galleryId,
      };

      // Save or update gallery
      final dbSaveStartTime = DateTime.now();
      JobGallery? result;

      if (_editingGallery != null) {
        // Update existing gallery
        LoggerService.info(
            '💾 Updating existing gallery: "${_nameController.text.trim()}"');
        result =
            await JobGalleryService.update(_editingGallery!.id!, galleryData);
      } else {
        // Create new gallery
        LoggerService.info(
            '💾 Creating new gallery: "${_nameController.text.trim()}"');
        result = await JobGalleryService.create(galleryData);
      }

      final dbSaveEndTime = DateTime.now();
      final dbSaveDuration = dbSaveEndTime.difference(dbSaveStartTime);

      if (result != null && mounted) {
        final totalOperationEndTime = DateTime.now();
        final totalOperationDuration =
            totalOperationEndTime.difference(totalOperationStartTime);

        LoggerService.info(
            '✅ Gallery saved to database in ${dbSaveDuration.inMilliseconds}ms: ${result.name}');
        LoggerService.info(
            '🎉 TOTAL LIGHTNING OPERATION COMPLETE in ${totalOperationDuration.inSeconds}s (${totalOperationDuration.inMilliseconds}ms) - ${totalOperationDuration.inSeconds < 60 ? "🚀 MISSION ACCOMPLISHED: UNDER 1 MINUTE!" : "⚠️ OVER TARGET TIME"}');

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingGallery != null
                ? 'Gallery updated successfully!'
                : 'Gallery created successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        throw Exception('Failed to create gallery');
      }
    } catch (e) {
      final totalOperationEndTime = DateTime.now();
      final totalOperationDuration =
          totalOperationEndTime.difference(totalOperationStartTime);

      LoggerService.error(
          '❌ GALLERY OPERATION FAILED after ${totalOperationDuration.inSeconds}s: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating gallery: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/new-job-gallery',
      title: 'Add Gallery',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Adjust font size based on available width
                        double fontSize = constraints.maxWidth > 400 ? 28 : 24;
                        if (constraints.maxWidth < 300) fontSize = 20;

                        return Text(
                          _editingGallery != null
                              ? 'Edit Gallery'
                              : 'Create New Gallery',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Gallery Details Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gallery Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Gallery Name
                    _buildTextField(
                      controller: _nameController,
                      label: 'Gallery Name *',
                      hint: 'Enter gallery name',
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Gallery name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Two column layout for medium fields
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          return Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _photographerController,
                                  label: 'Photographer',
                                  hint: 'Photographer name',
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _buildTextField(
                                  controller: _locationController,
                                  label: 'Location',
                                  hint: 'Shoot location',
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildTextField(
                                controller: _photographerController,
                                label: 'Photographer',
                                hint: 'Photographer name',
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _locationController,
                                label: 'Location',
                                hint: 'Shoot location',
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Hair/Makeup and Stylist
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          return Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _hairMakeupController,
                                  label: 'Hair & Makeup',
                                  hint: 'Hair & makeup artist',
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: _buildTextField(
                                  controller: _stylistController,
                                  label: 'Stylist',
                                  hint: 'Stylist name',
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildTextField(
                                controller: _hairMakeupController,
                                label: 'Hair & Makeup',
                                hint: 'Hair & makeup artist',
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _stylistController,
                                label: 'Stylist',
                                hint: 'Stylist name',
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Date Picker
                    _buildDateField(),
                    const SizedBox(height: 20),

                    // Description
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Add notes or details about this gallery',
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Images Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Use column layout on very narrow screens
                        if (constraints.maxWidth < 400) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Gallery Images',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _pickImages,
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('Add Images'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.goldColor,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Gallery Images',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: _pickImages,
                                icon: const Icon(Icons.add_photo_alternate),
                                label: const Text('Add Images'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.goldColor,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty)
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColorLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.borderColor,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 48,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No images selected',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Add Images" to select photos',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildImageGrid(),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              LayoutBuilder(
                builder: (context, constraints) {
                  // Use column layout on very narrow screens
                  if (constraints.maxWidth < 350) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveGallery,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black),
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? 'Saving...' : 'Save Gallery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.goldColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveGallery,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.black),
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label:
                                Text(_isSaving ? 'Saving...' : 'Save Gallery'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.goldColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: AppTheme.surfaceColorLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.goldColor),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.errorColor),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Date',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColorLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: const TextStyle(color: Colors.white),
                ),
                const Icon(
                  Icons.calendar_today,
                  color: AppTheme.goldColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageGrid() {
    LoggerService.info(
        '🖼️ _buildImageGrid() called with ${_selectedImages.length} new + ${_existingImageUrls.length} existing images');
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust grid columns based on available width
        int crossAxisCount = 3;
        if (constraints.maxWidth < 400) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 4;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: _selectedImages.length + _existingImageUrls.length,
          itemBuilder: (context, index) {
            // Show existing images first, then new images
            if (index < _existingImageUrls.length) {
              // Existing image
              final imageUrl = _existingImageUrls[index];

              return _buildExistingImageCard(imageUrl, index);
            } else {
              // New image
              final newImageIndex = index - _existingImageUrls.length;
              final image = _selectedImages[newImageIndex];

              return _buildNewImageCard(image, newImageIndex);
            }
          },
        );
      },
    );
  }

  Widget _buildExistingImageCard(String imageUrl, int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.surfaceColorLight,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Base64ImageWidget(
              imageUrl: imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder: Container(
                color: AppTheme.surfaceColorLight,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.goldColor,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: Container(
                color: AppTheme.surfaceColorLight,
                child: const Icon(
                  Icons.image,
                  color: Colors.grey,
                  size: 32,
                ),
              ),
            ),
          ),
        ),

        // Remove button for existing images
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _removeExistingImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.errorColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewImageCard(XFile image, int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.surfaceColorLight,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<Uint8List>(
              future: image.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Image.memory(
                    snapshot.data!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  );
                } else if (snapshot.hasError) {
                  return Container(
                    color: AppTheme.surfaceColorLight,
                    child: const Icon(
                      Icons.image,
                      color: Colors.grey,
                      size: 32,
                    ),
                  );
                } else {
                  return Container(
                    color: AppTheme.surfaceColorLight,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.goldColor,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),

        // Remove button for new images
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _removeImage(index),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.errorColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _removeExistingImage(int index) {
    LoggerService.info('🗑️ Removing existing image at index $index');
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }
}
