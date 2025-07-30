import 'package:flutter/material.dart';

class SwipeNavigation extends StatefulWidget {
  final Widget child;
  final String currentRoute;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  const SwipeNavigation({
    super.key,
    required this.child,
    required this.currentRoute,
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  @override
  State<SwipeNavigation> createState() => _SwipeNavigationState();
}

class _SwipeNavigationState extends State<SwipeNavigation>
    with AutomaticKeepAliveClientMixin {
  double _dragStartX = 0.0;
  bool _isDragging = false;

  @override
  bool get wantKeepAlive => true; // Keep state alive for better performance

  // Define the navigation order for pages - following client's preferred event order
  static const List<String> _pageOrder = [
    '/welcome',
    '/calendar',
    '/all-activities',
    // Event pages in client's preferred order (1-10)
    '/options', // 1. Option
    '/jobs', // 2. Job
    '/direct-options', // 3. Direct option
    '/direct-bookings', // 4. Direct booking
    '/castings', // 5. Casting
    '/on-stay', // 6. On stay
    '/tests', // 7. Test
    '/polaroids', // 8. Polaroids
    '/meetings', // 9. Meeting
    '/other', // 10. Other
    // Additional event types
    '/ai-jobs',
    '/shootings',
    // Management pages
    '/agencies',
    '/agents',
    '/industry-contacts',
    '/models',
    '/job-gallery',
    '/community-board',
    '/support',
    '/profile',
  ];

  void _handleDragStart(DragStartDetails details) {
    if (!_isMobile()) return;
    _dragStartX = details.globalPosition.dx;
    _isDragging = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isMobile() || !_isDragging) return;

    // Prevent conflicts with vertical scrolling
    if (details.delta.dx.abs() > details.delta.dy.abs()) {
      // Horizontal swipe is dominant, consume the gesture
    }
  }

  void _handleSwipe(DragEndDetails details) {
    // Only enable swipe navigation on mobile devices
    if (!_isMobile() || !_isDragging) return;

    // Enhanced sensitivity for better mobile experience across all devices
    const double velocitySensitivity = 50.0; // Reduced for faster response
    const double distanceThreshold = 80.0; // Minimum swipe distance

    _isDragging = false;

    if (details.primaryVelocity == null) return;

    // Calculate swipe distance
    final currentX = details.globalPosition.dx;
    final swipeDistance = (currentX - _dragStartX).abs();
    final velocity = details.primaryVelocity!;

    // Require minimum distance OR sufficient velocity for better UX
    final isValidSwipe = swipeDistance > distanceThreshold || velocity.abs() > velocitySensitivity * 2;

    if (!isValidSwipe) return;

    // More responsive swipe detection
    // Swipe right (previous page) - positive velocity
    if (velocity > velocitySensitivity) {
      _navigateToPreviousPage();
    }
    // Swipe left (next page) - negative velocity
    else if (velocity < -velocitySensitivity) {
      _navigateToNextPage();
    }
  }

  bool _isMobile() {
    final screenWidth = MediaQuery.of(context).size.width;
    // Enhanced mobile detection for better device support
    // Include tablets in portrait mode for better UX
    return screenWidth < 900; // Increased threshold for better tablet support
  }

  void _navigateToPreviousPage() {
    // Use custom callback if provided
    if (widget.onSwipeRight != null) {
      widget.onSwipeRight!();
      return;
    }

    final currentIndex = _pageOrder.indexOf(widget.currentRoute);
    if (currentIndex > 0) {
      final previousRoute = _pageOrder[currentIndex - 1];
      // Use immediate navigation for better performance
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, previousRoute);
        }
      });
    }
  }

  void _navigateToNextPage() {
    // Use custom callback if provided
    if (widget.onSwipeLeft != null) {
      widget.onSwipeLeft!();
      return;
    }

    final currentIndex = _pageOrder.indexOf(widget.currentRoute);
    if (currentIndex >= 0 && currentIndex < _pageOrder.length - 1) {
      final nextRoute = _pageOrder[currentIndex + 1];
      // Use immediate navigation for better performance
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, nextRoute);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return GestureDetector(
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleSwipe,
      // Improve responsiveness by reducing gesture arena delay
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          widget.child,
          // Show swipe indicators on mobile
          if (_isMobile()) _buildSwipeIndicators(),
        ],
      ),
    );
  }

  Widget _buildSwipeIndicators() {
    final currentIndex = _pageOrder.indexOf(widget.currentRoute);
    final canSwipeLeft =
        currentIndex >= 0 && currentIndex < _pageOrder.length - 1;
    final canSwipeRight = currentIndex > 0;

    // Don't show indicators if user can't swipe in either direction
    if (!canSwipeLeft && !canSwipeRight) return const SizedBox.shrink();

    return Positioned(
      bottom: 30, // Moved up slightly for better visibility
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (canSwipeRight)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8), // More opaque
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 18, // Slightly larger
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Swipe',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13, // Slightly larger
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          if (canSwipeLeft && canSwipeRight) const SizedBox(width: 24),
          if (canSwipeLeft)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8), // More opaque
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Swipe',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13, // Slightly larger
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 18, // Slightly larger
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Extension to easily add swipe navigation to any page
extension SwipeNavigationExtension on Widget {
  Widget withSwipeNavigation(
    String currentRoute, {
    VoidCallback? onSwipeLeft,
    VoidCallback? onSwipeRight,
  }) {
    return Builder(
      builder: (context) => SwipeNavigation(
        currentRoute: currentRoute,
        onSwipeLeft: onSwipeLeft,
        onSwipeRight: onSwipeRight,
        child: this,
      ),
    );
  }
}
