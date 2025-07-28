import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:new_flutter/services/job_gallery_service.dart';
import 'package:new_flutter/models/job_gallery.dart';
import 'package:new_flutter/widgets/app_layout.dart';
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
            childAspectRatio: 0.75,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Preview
            Expanded(
              flex: 3,
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
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No Images',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            // Gallery Info
            Expanded(
              flex: 2,
              child: Padding(
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
                            child: Text(
                              gallery.location!,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
      // Use Base64 image widget to bypass CORS issues
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
          child: const Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 40,
          ),
        ),
      );
    } else {
      // For local file paths or invalid URLs, show placeholder
      debugPrint('⚠️ Invalid image URL format: $imageUrl');
      return _buildPlaceholderWidget();
    }
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(gallery.name),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (gallery.photographerName != null) ...[
                  Text('Photographer: ${gallery.photographerName}'),
                  const SizedBox(height: 8),
                ],
                if (gallery.location != null) ...[
                  Text('Location: ${gallery.location}'),
                  const SizedBox(height: 8),
                ],
                if (gallery.description != null) ...[
                  Text('Description: ${gallery.description}'),
                  const SizedBox(height: 8),
                ],
                if (gallery.date != null) ...[
                  Text('Date: ${gallery.date}'),
                  const SizedBox(height: 8),
                ],
              ],
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
