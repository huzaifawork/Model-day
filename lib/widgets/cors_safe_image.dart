import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A widget that displays images with CORS handling for Firebase Storage
class CorsSafeImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const CorsSafeImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  /// Fix Firebase Storage URL for CORS compatibility
  String _fixStorageUrl(String url) {
    // Don't use CORS proxy - it causes issues
    // Just ensure we're using the right domain and add cache busting
    if (url.contains('.appspot.com')) {
      url = url.replaceAll('.appspot.com', '.firebasestorage.app');
    }

    // Add CORS-friendly parameters
    final uri = Uri.parse(url);
    final fixedUrl = uri.replace(queryParameters: {
      ...uri.queryParameters,
      'alt': 'media',
      '_cb': DateTime.now().millisecondsSinceEpoch.toString(),
    }).toString();

    return fixedUrl;
  }

  /// Build web image with multiple fallback strategies
  Future<Widget> _buildWebImage(String url) async {
    try {
      // Strategy 1: Try direct network image
      return Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Direct network image failed: $error');
          throw error;
        },
      );
    } catch (e) {
      debugPrint('❌ All web image strategies failed: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorWidget();
    }

    final fixedUrl = _fixStorageUrl(imageUrl);

    Widget imageWidget;

    if (kIsWeb) {
      // For web, try multiple approaches to handle CORS
      imageWidget = FutureBuilder<Widget>(
        future: _buildWebImage(fixedUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildPlaceholder();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            debugPrint('❌ Web image error: ${snapshot.error}');
            return _buildErrorWidget();
          }
          return snapshot.data!;
        },
      );
    } else {
      // For mobile, use CachedNetworkImage
      imageWidget = CachedNetworkImage(
        imageUrl: fixedUrl,
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          debugPrint('❌ Cached image error: $error');
          return _buildErrorWidget();
        },
        httpHeaders: const {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET',
          'Access-Control-Allow-Headers': 'Content-Type',
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          width: width,
          height: height,
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
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: Colors.grey[800],
          child: const Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 40,
          ),
        );
  }
}

/// Circle Avatar with CORS handling
class CorsSafeCircleAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? child;
  final Color? backgroundColor;

  const CorsSafeCircleAvatar({
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
        child: CorsSafeImage(
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
