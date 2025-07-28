import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'admin_sidebar.dart';

class AdminLayout extends StatefulWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;

  const AdminLayout({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  bool _isSidebarOpen = true;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768;
    final isMobile = screenWidth <= 768;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: isMobile
          ? AppBar(
              backgroundColor: AppTheme.surfaceColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: AppTheme.goldColor),
                tooltip: 'Open navigation menu',
                onPressed: () {
                  setState(() {
                    _isSidebarOpen = !_isSidebarOpen;
                  });
                },
              ),
              title: Text(
                widget.title,
                style: const TextStyle(
                  color: AppTheme.goldColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: widget.actions,
            )
          : null,
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar (only show on desktop/tablet, not mobile)
              if (_isSidebarOpen && !isMobile)
                SizedBox(
                  width: isDesktop ? 280 : (isTablet ? 250 : 280),
                  child: AdminSidebar(
                    onCloseSidebar:
                        null, // Desktop/tablet doesn't need close callback
                  ),
                ),

              // Main content
              Expanded(
                child: Column(
                  children: [
                    // Desktop header
                    if (!isMobile)
                      Container(
                        height: 70,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceColor,
                          border: Border(
                            bottom: BorderSide(color: AppTheme.borderColor),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (!_isSidebarOpen)
                              IconButton(
                                icon: const Icon(Icons.menu,
                                    color: AppTheme.goldColor),
                                onPressed: () {
                                  setState(() {
                                    _isSidebarOpen = true;
                                  });
                                },
                              ),
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: AppTheme.goldColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (widget.actions != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: widget.actions!,
                              ),
                          ],
                        ),
                      ),

                    // Content area
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(
                          isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0),
                        ),
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Mobile overlay
          if (isMobile && _isSidebarOpen)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Row(
                    children: [
                      // Sidebar with slide animation
                      Container(
                        width: 280,
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(2, 0),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: AdminSidebar(
                            onCloseSidebar: () =>
                                setState(() => _isSidebarOpen = false),
                          ),
                        ),
                      ),
                      // Tap area to close
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSidebarOpen = false),
                          child: Container(
                            color: Colors.transparent,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
