import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/firebase_storage_service.dart';

/// A widget that displays Firebase Storage images using base64 encoding to bypass CORS
class Base64ImageWidget extends StatefulWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const Base64ImageWidget({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  State<Base64ImageWidget> createState() => _Base64ImageWidgetState();
}

class _Base64ImageWidgetState extends State<Base64ImageWidget> {
  String? _base64Image;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(Base64ImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // For web, try direct image loading first (faster)
      if (kIsWeb) {
        // Try to use the image URL directly with CORS-friendly parameters
        final fixedUrl = _fixImageUrl(widget.imageUrl);
        setState(() {
          _base64Image = fixedUrl;
          _isLoading = false;
          _hasError = false;
        });
        return;
      }

      // For mobile or as fallback, use base64
      final base64Image =
          await FirebaseStorageService.getImageAsBase64(widget.imageUrl);

      if (mounted) {
        setState(() {
          _base64Image = base64Image;
          _isLoading = false;
          _hasError = base64Image == null;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading image: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  String _fixImageUrl(String url) {
    // Keep the correct .firebasestorage.app domain (CORS is configured on this bucket)
    // Don't convert domains - the URLs are already correct!

    // Add CORS-friendly parameters
    final uri = Uri.parse(url);
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      'alt': 'media',
      'token': DateTime.now().millisecondsSinceEpoch.toString(),
    }).toString();
  }

  void _tryBase64Fallback() async {
    try {
      debugPrint('🔄 Trying base64 fallback for: ${widget.imageUrl}');
      final base64Image =
          await FirebaseStorageService.getImageAsBase64(widget.imageUrl);

      if (mounted && base64Image != null) {
        setState(() {
          _base64Image = base64Image;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Base64 fallback failed: $e');
    }
  }

  Widget _buildPlaceholder() {
    return widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[800],
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.amber,
              strokeWidth: 2,
            ),
          ),
        );
  }

  Widget _buildErrorWidget() {
    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[800],
          child: const Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 40,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildPlaceholder();
    }

    if (_hasError || _base64Image == null) {
      return _buildErrorWidget();
    }

    Widget imageWidget;

    if (_base64Image!.startsWith('data:image')) {
      // Base64 data URL
      final base64Data = _base64Image!.split(',')[1];
      final imageBytes = base64Decode(base64Data);

      imageWidget = Image.memory(
        imageBytes,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Memory image error: $error');
          return _buildErrorWidget();
        },
      );
    } else {
      // Regular network image URL
      imageWidget = Image.network(
        _base64Image!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Network image error: $error');
          // Try to fallback to base64 if network fails
          _tryBase64Fallback();
          return _buildErrorWidget();
        },
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Circle Avatar with base64 image support
class Base64CircleAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? child;
  final Color? backgroundColor;

  const Base64CircleAvatar({
    super.key,
    this.imageUrl,
    required this.radius,
    this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey[800],
        child: child ?? const Icon(Icons.person, color: Colors.grey),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[800],
      child: ClipOval(
        child: Base64ImageWidget(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorWidget: child ?? const Icon(Icons.person, color: Colors.grey),
        ),
      ),
    );
  }
}
