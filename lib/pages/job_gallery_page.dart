import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:new_flutter/services/job_gallery_service.dart';
import 'package:new_flutter/models/job_gallery.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/widgets/clickable_contact_info.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/widgets/base64_image_widget.dart';

class JobGalleryPage extends StatefulWidget {
  const JobGalleryPage({super.key});

  @override
  State<JobGalleryPage> createState() => _JobGalleryPageState();
}

class _JobGalleryPageState extends State<JobGalleryPage> {
  List<JobGallery> galleries = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGalleries();
  }

  Future<void> _loadGalleries() async {
    try {
      final loadedGalleries = await JobGalleryService.list();
      if (mounted) {
        setState(() {
          galleries = loadedGalleries;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading galleries: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<JobGallery> get filteredGalleries {
    if (searchQuery.isEmpty) return galleries;
    return galleries
        .where((gallery) =>
            gallery.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
            (gallery.description
                    ?.toLowerCase()
                    .contains(searchQuery.toLowerCase()) ??
                false) ||
            (gallery.photographerName
                    ?.toLowerCase()
                    .contains(searchQuery.toLowerCase()) ??
                false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/job-gallery',
      title: 'Job Gallery',
      actions: [
        IconButton(
          icon: const Icon(Icons.add, color: AppTheme.goldColor),
          onPressed: () async {
            final result =
                await Navigator.pushNamed(context, '/new-job-gallery');
            if (result == true && mounted) {
              _loadGalleries();
            }
          },
        ),
      ],
      child: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search galleries...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ).animate().fadeIn(duration: 600.ms),

          // Gallery Grid
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.goldColor),
                  )
                : filteredGalleries.isEmpty
                    ? _buildEmptyState()
                    : _buildGalleryGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty ? 'No galleries yet' : 'No galleries found',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            searchQuery.isEmpty
                ? 'Create your first gallery to showcase your work'
                : 'Try adjusting your search terms',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
          if (searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result =
                    await Navigator.pushNamed(context, '/new-job-gallery');
                if (result == true && mounted) {
                  _loadGalleries();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldColor,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildGalleryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 400) crossAxisCount = 2;
        if (constraints.maxWidth > 700) crossAxisCount = 3;
        if (constraints.maxWidth > 1000) crossAxisCount = 4;
        if (constraints.maxWidth > 1300) crossAxisCount = 5;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85, // Adjusted for compact cards
          ),
          itemCount: filteredGalleries.length,
          itemBuilder: (context, index) {
            final gallery = filteredGalleries[index];
            return _buildGalleryCard(gallery, index);
          },
        );
      },
    );
  }

  Widget _buildGalleryCard(JobGallery gallery, int index) {
    // Parse images from comma-separated string or JSON
    List<String> imageUrls = [];
    if (gallery.images != null && gallery.images!.isNotEmpty) {
      try {
        final String imagesStr = gallery.images!;

        // Check if it's a comma-separated string (current format)
        if (imagesStr.contains(',')) {
          imageUrls = imagesStr
              .split(',')
              .map((url) => url.trim())
              .where((url) => url.isNotEmpty)
              .toList();
        }
        // Check if it's a single URL
        else if (imagesStr.isNotEmpty && !imagesStr.startsWith('[')) {
          imageUrls = [imagesStr];
        }
        // Handle JSON array format (future compatibility)
        else if (imagesStr.startsWith('[')) {
          final RegExp urlRegex = RegExp(r'"url":"([^"]+)"');
          final matches = urlRegex.allMatches(imagesStr);
          imageUrls = matches.map((match) => match.group(1)!).toList();
        }

        debugPrint(
            '🖼️ Gallery "${gallery.name}" has ${imageUrls.length} images: $imageUrls');
      } catch (e) {
        debugPrint('❌ Error parsing images for gallery ${gallery.name}: $e');
        imageUrls = [];
      }
    }

    return GestureDetector(
      onTap: () => _showGalleryDetails(gallery),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[800]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Preview - Compact thumbnail
                Expanded(
                  flex: 2, // Compact ratio for image
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      color: Colors.grey[800],
                    ),
                    child: imageUrls.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16)),
                            child: _buildImageWidget(imageUrls.first),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  color: Colors.grey[600],
                                  size: 24, // Smaller icon for compact view
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No Images',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10, // Smaller text
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                // Gallery Info - Compact
                Expanded(
                  flex: 1, // Compact ratio for info
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gallery.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (gallery.photographerName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'by ${gallery.photographerName}',
                            style: const TextStyle(
                              color: AppTheme.goldColor,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (gallery.location != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.grey[400],
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ClickableContactInfo(
                                  text: gallery.location!,
                                  type: ContactType.location,
                                  showIcon: false,
                                  textColor: Colors.blue[400],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (imageUrls.isNotEmpty)
                              Text(
                                '${imageUrls.length} photo${imageUrls.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11,
                                ),
                              ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[500],
                              size: 12,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Action buttons
            Positioned(
              top: 8,
              right: 8,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _editGallery(gallery);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(gallery);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 100))
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildImageWidget(String imageUrl) {
    debugPrint('🖼️ Loading image: $imageUrl');

    // Check if it's a valid HTTP/HTTPS URL
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      // Try multiple image loading strategies for better compatibility
      return _buildNetworkImageWithFallback(imageUrl);
    } else {
      // For local file paths or invalid URLs, show placeholder
      debugPrint('⚠️ Invalid image URL format: $imageUrl');
      return _buildPlaceholderWidget();
    }
  }

  Widget _buildNetworkImageWithFallback(String imageUrl) {
    // Transform Firebase Storage URL for better web compatibility
    String processedUrl = _processFirebaseStorageUrl(imageUrl);

    return Image.network(
      processedUrl,
      fit: BoxFit.cover,
      headers: const {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET',
        'Access-Control-Allow-Headers': 'Content-Type',
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          color: Colors.grey[800],
          child: const Center(
            child: CircularProgressIndicator(
              color: AppTheme.goldColor,
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('❌ Network image failed for URL: $imageUrl');
        debugPrint('❌ Error details: $error');
        debugPrint('❌ Stack trace: $stackTrace');

        // Fallback to Base64ImageWidget for CORS issues
        return Base64ImageWidget(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: Container(
            color: Colors.grey[800],
            child: const Center(
              child: CircularProgressIndicator(
                color: AppTheme.goldColor,
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: Container(
            color: Colors.grey[800],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  color: Colors.grey,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  'Image Load Failed',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _processFirebaseStorageUrl(String imageUrl) {
    // If it's a Firebase Storage URL, add token parameter for web access
    if (imageUrl.contains('firebasestorage.googleapis.com')) {
      debugPrint(
          '🔄 Processing Firebase Storage URL: ${imageUrl.substring(0, 100)}...');

      // Add alt=media parameter if not present for direct media access
      if (!imageUrl.contains('alt=media')) {
        String separator = imageUrl.contains('?') ? '&' : '?';
        imageUrl = '$imageUrl${separator}alt=media';
      }

      debugPrint('🔄 Processed URL: ${imageUrl.substring(0, 100)}...');
    }

    return imageUrl;
  }

  Widget _buildPlaceholderWidget() {
    return Container(
      color: Colors.grey[800],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo,
            color: Colors.grey[600],
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Image Preview',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showGalleryDetails(JobGallery gallery) {
    // Parse images for display
    List<String> imageUrls = [];
    if (gallery.images != null && gallery.images!.isNotEmpty) {
      try {
        final String imagesStr = gallery.images!;
        if (imagesStr.contains(',')) {
          imageUrls = imagesStr
              .split(',')
              .map((url) => url.trim())
              .where((url) => url.isNotEmpty)
              .toList();
        } else if (imagesStr.isNotEmpty) {
          imageUrls = [imagesStr];
        }
      } catch (e) {
        debugPrint('Error parsing images: $e');
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(gallery.name,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 500),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Photographer
                  if (gallery.photographerName != null &&
                      gallery.photographerName!.isNotEmpty) ...[
                    _buildDetailRow('Photographer:', gallery.photographerName!),
                    const SizedBox(height: 12),
                  ],

                  // Location
                  if (gallery.location != null &&
                      gallery.location!.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Location: ',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Expanded(
                          child: ClickableContactInfo(
                            text: gallery.location!,
                            type: ContactType.location,
                            showIcon: false,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Hair & Makeup
                  if (gallery.hairMakeup != null &&
                      gallery.hairMakeup!.isNotEmpty) ...[
                    _buildDetailRow('Hair & Makeup:', gallery.hairMakeup!),
                    const SizedBox(height: 12),
                  ],

                  // Stylist
                  if (gallery.stylist != null &&
                      gallery.stylist!.isNotEmpty) ...[
                    _buildDetailRow('Stylist:', gallery.stylist!),
                    const SizedBox(height: 12),
                  ],

                  // Date
                  if (gallery.date != null) ...[
                    _buildDetailRow(
                        'Date:', gallery.date!.toIso8601String().split('T')[0]),
                    const SizedBox(height: 12),
                  ],

                  // Description
                  if (gallery.description != null &&
                      gallery.description!.isNotEmpty) ...[
                    _buildDetailRow('Description:', gallery.description!),
                    const SizedBox(height: 12),
                  ],

                  // Images count and gallery
                  if (imageUrls.isNotEmpty) ...[
                    _buildDetailRow('Images:',
                        '${imageUrls.length} image${imageUrls.length > 1 ? 's' : ''}'),
                    const SizedBox(height: 12),

                    // Image gallery grid
                    SizedBox(
                      height: 200, // Fixed height for image preview
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: imageUrls.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () =>
                                _showFullScreenImage(context, imageUrls[index]),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[800],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildImageWidget(imageUrls[index]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _editGallery(gallery);
              },
              child: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: _buildImageWidget(imageUrl),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editGallery(JobGallery gallery) async {
    final result = await Navigator.pushNamed(
      context,
      '/new-job-gallery',
      arguments: gallery,
    );
    if (result == true && mounted) {
      _loadGalleries();
    }
  }

  void _showDeleteConfirmation(JobGallery gallery) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Gallery'),
          content: Text('Are you sure you want to delete "${gallery.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteGallery(gallery);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteGallery(JobGallery gallery) async {
    if (gallery.id == null) return;

    try {
      final success = await JobGalleryService.delete(gallery.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Gallery deleted successfully'
                : 'Failed to delete gallery'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          _loadGalleries();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting gallery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
