import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/models/community_post.dart';
import 'package:new_flutter/services/community_service.dart';
import 'package:new_flutter/pages/community_post_detail_page.dart';
import 'package:new_flutter/providers/notification_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunityBoardPage extends StatefulWidget {
  const CommunityBoardPage({super.key});

  @override
  State<CommunityBoardPage> createState() => _CommunityBoardPageState();
}

class _CommunityBoardPageState extends State<CommunityBoardPage> {
  String _extractLocation(String content) {
    final locationRegex = RegExp(r'Location: ([^\n]+)');
    final match = locationRegex.firstMatch(content);
    return match?.group(1)?.trim() ?? 'Unknown';
  }

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  List<CommunityPost> _posts = [];

  Future<void> _launchMap(String location) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$location');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('Could not launch $uri');
    }
  }
  List<CommunityPost> _filteredPosts = [];
  bool _isLoading = true;
  bool _isPosting = false;
  String _selectedCategory = 'All Categories';
  final String _selectedStatus = 'Active';
  String _selectedContactMethod = 'Comments';

  final List<String> _categories = [
    'All Categories',
    'Looking for Roommate',
    'Housing',
    'Services',
    'Jobs',
    'Events',
    'General',
  ];

  final List<String> _contactMethods = [
    'Comments',
    'Direct Message',
    'Email',
    'Phone',
  ];

  @override
  void initState() {
    super.initState();
    _loadPosts();
    // Initialize notifications for the current user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      notificationProvider.initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await CommunityService.getPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _filteredPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterPosts() {
    setState(() {
      _filteredPosts = _posts.where((post) {
        final matchesSearch = _searchController.text.isEmpty ||
            post.content
                .toLowerCase()
                .contains(_searchController.text.toLowerCase()) ||
            post.authorName
                .toLowerCase()
                .contains(_searchController.text.toLowerCase());

        final matchesCategory = _selectedCategory == 'All Categories' ||
            post.tags
                .contains(_selectedCategory.toLowerCase().replaceAll(' ', '_'));

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _createPost() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in title and description'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isPosting = true;
    });

    try {
      // Create a formatted post content
      String content = '$title\n\n$description';
      if (_locationController.text.isNotEmpty) {
        content += '\n\nLocation: ${_locationController.text}';
      }
      if (_dateController.text.isNotEmpty) {
        content += '\n\nDate: ${_dateController.text}';
      }

      await CommunityService.createPost(
        content,
        category: _selectedCategory,
        location: _locationController.text.isNotEmpty
            ? _locationController.text
            : null,
        date: _dateController.text.isNotEmpty ? _dateController.text : null,
        time: _timeController.text.isNotEmpty ? _timeController.text : null,
        contactMethod: _selectedContactMethod,
      );
      _clearForm();
      await _loadPosts();
      if (mounted) {
        Navigator.pop(context); // Close the dialog
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post created successfully!'),
            backgroundColor: AppTheme.goldColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating post: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _dateController.clear();
    _timeController.clear();
    setState(() {
      _selectedCategory = 'All Categories';
      _selectedContactMethod = 'Comments';
    });
  }

  void _showNewPostDialog() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth <= 768;
    final isSmallMobile = screenWidth < 360;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile
                ? (isSmallMobile ? screenWidth * 0.98 : screenWidth * 0.95)
                : 600,
            maxHeight: screenHeight * (isMobile ? 0.92 : 0.8),
          ),
          child: Container(
            width: isMobile ? double.infinity : 600,
            padding: EdgeInsets.all(isMobile ? (isSmallMobile ? 12 : 16) : 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Create New Post',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your request with the modeling community',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Title',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'What are you looking for?',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: Colors.grey[800]!.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category
                  const Text(
                    'Category',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _categories.skip(1).contains(
                            _selectedCategory == 'All Categories'
                                ? _categories[1]
                                : _selectedCategory)
                        ? (_selectedCategory == 'All Categories'
                            ? _categories[1]
                            : _selectedCategory)
                        : null,
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[800]!.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    dropdownColor: Colors.grey[800],
                    items: _categories.skip(1).map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category,
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Provide more details about your request...',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: Colors.grey[800]!.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location and Date Row (responsive)
                  isMobile
                      ? Column(
                          children: [
                            // Location
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Location',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _locationController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Where is this relevant to?',
                                    hintStyle: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.5)),
                                    filled: true,
                                    fillColor: Colors.grey[800]!
                                        .withValues(alpha: 0.5),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Date
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Date',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _dateController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'mm/dd/yyyy',
                                    hintStyle: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.5)),
                                    filled: true,
                                    fillColor: Colors.grey[800]!
                                        .withValues(alpha: 0.5),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                    suffixIcon: Icon(
                                      Icons.calendar_today,
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                      size: 18,
                                    ),
                                  ),
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365)),
                                    );
                                    if (date != null) {
                                      _dateController.text =
                                          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
                                    }
                                  },
                                  readOnly: true,
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Location',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _locationController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Where is this relevant to?',
                                      hintStyle: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5)),
                                      filled: true,
                                      fillColor: Colors.grey[800]!
                                          .withValues(alpha: 0.5),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.all(12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Date',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _dateController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'mm/dd/yyyy',
                                      hintStyle: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5)),
                                      filled: true,
                                      fillColor: Colors.grey[800]!
                                          .withValues(alpha: 0.5),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.all(12),
                                      suffixIcon: Icon(
                                        Icons.calendar_today,
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        size: 18,
                                      ),
                                    ),
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: DateTime.now(),
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now()
                                            .add(const Duration(days: 365)),
                                      );
                                      if (date != null) {
                                        _dateController.text =
                                            '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
                                      }
                                    },
                                    readOnly: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),

                  // Time and Contact Method Row (responsive)
                  isMobile
                      ? Column(
                          children: [
                            // Time
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Time (if applicable)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _timeController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: '--:-- --',
                                    hintStyle: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.5)),
                                    filled: true,
                                    fillColor: Colors.grey[800]!
                                        .withValues(alpha: 0.5),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                    suffixIcon: Icon(
                                      Icons.access_time,
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                      size: 18,
                                    ),
                                  ),
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: const ColorScheme.dark(
                                              primary: AppTheme.goldColor,
                                              surface: Colors.black,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (time != null && mounted) {
                                      final hour = time.hourOfPeriod;
                                      final minute = time.minute
                                          .toString()
                                          .padLeft(2, '0');
                                      final period = time.period == DayPeriod.am
                                          ? 'AM'
                                          : 'PM';
                                      _timeController.text =
                                          '$hour:$minute $period';
                                    }
                                  },
                                  readOnly: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Contact Method
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Preferred Contact Method',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedContactMethod,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedContactMethod = value!;
                                    });
                                  },
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey[800]!
                                        .withValues(alpha: 0.5),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                  dropdownColor: Colors.grey[800],
                                  items: _contactMethods.map((method) {
                                    return DropdownMenuItem(
                                      value: method,
                                      child: Text(method,
                                          style: const TextStyle(
                                              color: Colors.white)),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Time (if applicable)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _timeController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: '--:-- --',
                                      hintStyle: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5)),
                                      filled: true,
                                      fillColor: Colors.grey[800]!
                                          .withValues(alpha: 0.5),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.all(12),
                                      suffixIcon: Icon(
                                        Icons.access_time,
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        size: 18,
                                      ),
                                    ),
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme:
                                                  const ColorScheme.dark(
                                                primary: AppTheme.goldColor,
                                                surface: Colors.black,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (time != null && mounted) {
                                        final hour = time.hourOfPeriod;
                                        final minute = time.minute
                                            .toString()
                                            .padLeft(2, '0');
                                        final period =
                                            time.period == DayPeriod.am
                                                ? 'AM'
                                                : 'PM';
                                        _timeController.text =
                                            '$hour:$minute $period';
                                      }
                                    },
                                    readOnly: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Preferred Contact Method',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedContactMethod,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedContactMethod = value!;
                                      });
                                    },
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey[800]!
                                          .withValues(alpha: 0.5),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.all(12),
                                    ),
                                    dropdownColor: Colors.grey[800],
                                    items: _contactMethods.map((method) {
                                      return DropdownMenuItem(
                                        value: method,
                                        child: Text(method,
                                            style: const TextStyle(
                                                color: Colors.white)),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isPosting
                            ? null
                            : () async {
                                await _createPost();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.goldColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isPosting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black),
                                ),
                              )
                            : const Text(
                                'Post',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final isMobile = screenWidth <= 768;

    return AppLayout(
      currentPage: '/community-board',
      title: 'Community Board',
      actions: [
        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            final unreadCount = notificationProvider.unreadCount;
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.mail_outline, color: Colors.white),
                  tooltip: 'Notifications',
                  onPressed: () => _showNotificationPanel(context),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
      child: isMobile
          ? _buildMobileLayout()
          : LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final sidebarWidth = isDesktop
                    ? (availableWidth * 0.25).clamp(280.0, 350.0)
                    : isTablet
                        ? (availableWidth * 0.3).clamp(240.0, 300.0)
                        : 220.0;

                return Row(
                  children: [
                    // Left Sidebar - Filters (responsive width)
                    Container(
                      width: sidebarWidth,
                      padding: EdgeInsets.all(isDesktop ? 16 : 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]!.withValues(alpha: 0.5),
                        border: Border(
                          right: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Back to Previous Page
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_back,
                                    color: Colors.white.withValues(alpha: 0.7),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      isDesktop ? 'Back to Home' : 'Back',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        fontSize: isDesktop ? 14 : 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isDesktop ? 24 : 16),

                            // Connect text
                            if (isDesktop) ...[
                              Text(
                                'Connect with other models in your area',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Filters Section
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]!.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Filters',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Search
                                  const Text(
                                    'Search',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (_) => _filterPosts(),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Search posts...',
                                      hintStyle: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        fontSize: 14,
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[700]!
                                          .withValues(alpha: 0.5),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color:
                                            Colors.white.withValues(alpha: 0.5),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Category
                                  const Text(
                                    'Category',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue:
                                        _categories.contains(_selectedCategory)
                                            ? _selectedCategory
                                            : null,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCategory = value!;
                                      });
                                      _filterPosts();
                                    },
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.grey[700]!
                                          .withValues(alpha: 0.5),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    dropdownColor: Colors.grey[800],
                                    items: _categories.map((category) {
                                      return DropdownMenuItem(
                                        value: category,
                                        child: Text(
                                          category,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),

                                  // Status
                                  const Text(
                                    'Status',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[700]!
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _selectedStatus,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Main Content Area
                    Expanded(
                      child: Column(
                        children: [
                          // Header with New Post button
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _showNewPostDialog(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.goldColor,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'New Post',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Posts List
                          Expanded(
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator())
                                : _filteredPosts.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.forum_outlined,
                                              size: 64,
                                              color: Colors.white
                                                  .withValues(alpha: 0.3),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No posts found',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Try adjusting your filters or create a new post',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount: _filteredPosts.length,
                                        itemBuilder: (context, index) {
                                          final post = _filteredPosts[index];
                                          return _buildPostCard(post, index);
                                        },
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildPostCard(CommunityPost post, int index) {
    // Parse post content to extract title and description
    final lines = post.content.split('\n');
    final title = lines.isNotEmpty ? lines[0] : 'Untitled';
    final description = lines.length > 1 ? lines.skip(1).join('\n').trim() : '';

    // Determine category based on tags or content
    String category = 'General';
    if (post.tags.contains('roommate') ||
        title.toLowerCase().contains('roommate')) {
      category = 'Looking for Roommate';
    } else if (post.tags.contains('housing') ||
        title.toLowerCase().contains('housing')) {
      category = 'Housing';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[800]!.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author info and category
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.goldColor,
                child: Text(
                  post.authorName.isNotEmpty
                      ? post.authorName[0].toUpperCase()
                      : 'G',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatTimestamp(post.timestamp),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.goldColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.goldColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: AppTheme.goldColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Post title
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Post description
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 16),

          // Location and date info (if available)
          Row(
            children: [
              if (post.content.contains('Location:')) ...[
                Icon(
                  Icons.location_on,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _launchMap(_extractLocation(post.content)),
                    child: Text(
                    _extractLocation(post.content),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Icon(
                Icons.calendar_today,
                size: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                _formatTimestamp(post.timestamp),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Text(
                '${post.comments} comments',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommunityPostDetailPage(post: post),
                    ),
                  );
                  // Refresh posts if the post was edited or deleted
                  if (result == true) {
                    _loadPosts();
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.goldColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                child: const Text(
                  'View Details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 100))
        .fadeIn(duration: 600.ms)
        .slideX(begin: 0.2);
  }

  Widget _buildMobileLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 360;

    return Column(
      children: [
        // Mobile Header with filters toggle
        Container(
          padding: EdgeInsets.all(isSmallMobile ? 12 : 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Back button
              Flexible(
                flex: 2,
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      if (!isSmallMobile)
                        Text(
                          'Back',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Filters button
              IconButton(
                onPressed: () => _showMobileFilters(),
                icon: const Icon(Icons.filter_list, color: Colors.white),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                iconSize: 20,
              ),
              const SizedBox(width: 8),
              // New Post button
              Flexible(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => _showNewPostDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.goldColor,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmallMobile ? 8 : 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(
                    isSmallMobile ? 'Post' : 'New Post',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallMobile ? 11 : 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Posts List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredPosts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.forum_outlined,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No posts found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters or create a new post',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredPosts.length,
                      itemBuilder: (context, index) {
                        final post = _filteredPosts[index];
                        return _buildMobilePostCard(post, index);
                      },
                    ),
        ),
      ],
    );
  }

  void _showMobileFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search
            TextField(
              controller: _searchController,
              onChanged: (_) => _filterPosts(),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search posts...',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                filled: true,
                fillColor: Colors.grey[700]!.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category
            const Text(
              'Category',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _categories.contains(_selectedCategory)
                  ? _selectedCategory
                  : null,
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
                _filterPosts();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[700]!.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              dropdownColor: Colors.grey[800],
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category,
                      style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePostCard(CommunityPost post, int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallMobile = screenWidth < 360;
    final lines = post.content.split('\n');
    final title = lines.isNotEmpty ? lines[0] : 'Untitled';
    final description = lines.length > 1 ? lines.skip(1).join('\n').trim() : '';

    String category = 'General';
    if (post.tags.contains('roommate') ||
        title.toLowerCase().contains('roommate')) {
      category = 'Looking for Roommate';
    } else if (post.tags.contains('housing') ||
        title.toLowerCase().contains('housing')) {
      category = 'Housing';
    }

    return Container(
      margin: EdgeInsets.only(bottom: isSmallMobile ? 12 : 16),
      padding: EdgeInsets.all(isSmallMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[800]!.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author info and category
          Row(
            children: [
              CircleAvatar(
                radius: isSmallMobile ? 12 : 14,
                backgroundColor: AppTheme.goldColor,
                child: Text(
                  post.authorName.isNotEmpty
                      ? post.authorName[0].toUpperCase()
                      : 'G',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallMobile ? 10 : 12,
                  ),
                ),
              ),
              SizedBox(width: isSmallMobile ? 6 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: isSmallMobile ? 12 : 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatTimestamp(post.timestamp),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: isSmallMobile ? 10 : 11,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: isSmallMobile ? 4 : 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: AppTheme.goldColor,
                      fontSize: isSmallMobile ? 9 : 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Post title
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallMobile ? 14 : 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: isSmallMobile ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),

          // Post description
          if (description.isNotEmpty) ...[
            SizedBox(height: isSmallMobile ? 4 : 6),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: isSmallMobile ? 12 : 13,
                height: 1.3,
              ),
              maxLines: isSmallMobile ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          SizedBox(height: isSmallMobile ? 10 : 12),

          // Actions
          Row(
            children: [
              Expanded(
                child: Text(
                  '${post.comments} comments',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: isSmallMobile ? 10 : 11,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommunityPostDetailPage(post: post),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.goldColor,
                  padding: EdgeInsets.symmetric(
                      horizontal: isSmallMobile ? 6 : 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  isSmallMobile ? 'View' : 'View Details',
                  style: TextStyle(
                    fontSize: isSmallMobile ? 10 : 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: index * 100))
        .fadeIn(duration: 600.ms)
        .slideX(begin: 0.2);
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showNotificationPanel(BuildContext context) async {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width <= 768;
    final isTablet = screenSize.width > 768 && screenSize.width <= 1200;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext context) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 32,
              vertical: isMobile ? 40 : 60,
            ),
            child: Container(
              width: isMobile ? double.infinity : (isTablet ? 450 : 500),
              height:
                  isMobile ? screenSize.height * 0.7 : (isTablet ? 550 : 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.surfaceColor,
                    AppTheme.surfaceColorLight,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.goldColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Enhanced Header
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.goldColor.withValues(alpha: 0.15),
                          AppTheme.goldColor.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.goldColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.goldColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.message,
                            color: AppTheme.goldColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notifications',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Consumer<NotificationProvider>(
                                builder:
                                    (context, notificationProvider, child) {
                                  final unreadCount =
                                      notificationProvider.unreadCount;
                                  return Text(
                                    unreadCount > 0
                                        ? '$unreadCount unread notification${unreadCount > 1 ? 's' : ''}'
                                        : 'All caught up!',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Consumer<NotificationProvider>(
                          builder: (context, notificationProvider, child) {
                            if (isMobile) {
                              // Mobile layout: Stack buttons vertically or use icons only
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedOpacity(
                                        opacity:
                                            notificationProvider.notifications.any((n) => !n.isRead)
                                                ? 1.0
                                                : 0.5,
                                        duration: const Duration(milliseconds: 200),
                                        child: IconButton(
                                          onPressed: notificationProvider.notifications.any((n) => !n.isRead)
                                              ? () => notificationProvider.markAllAsRead()
                                              : null,
                                          icon: const Icon(
                                            Icons.done_all,
                                            size: 18,
                                          ),
                                          color: notificationProvider.notifications.any((n) => !n.isRead)
                                              ? AppTheme.goldColor
                                              : Colors.grey,
                                          tooltip: 'Mark all read',
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                      ),
                                      AnimatedOpacity(
                                        opacity:
                                            notificationProvider.notifications.isNotEmpty
                                                ? 1.0
                                                : 0.5,
                                        duration: const Duration(milliseconds: 200),
                                        child: IconButton(
                                          onPressed: notificationProvider.notifications.isNotEmpty
                                              ? () => notificationProvider.clearAllNotifications()
                                              : null,
                                          icon: const Icon(
                                            Icons.clear_all,
                                            size: 18,
                                          ),
                                          color: notificationProvider.notifications.isNotEmpty
                                              ? Colors.red.shade400
                                              : Colors.grey,
                                          tooltip: 'Clear all',
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            } else {
                              // Desktop layout: Keep original button layout
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedOpacity(
                                    opacity:
                                        notificationProvider.notifications.any((n) => !n.isRead)
                                            ? 1.0
                                            : 0.5,
                                    duration: const Duration(milliseconds: 200),
                                    child: TextButton.icon(
                                      onPressed: notificationProvider.notifications.any((n) => !n.isRead)
                                          ? () => notificationProvider.markAllAsRead()
                                          : null,
                                      icon: const Icon(
                                        Icons.done_all,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Mark all read',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: notificationProvider.notifications.any((n) => !n.isRead)
                                            ? AppTheme.goldColor
                                            : Colors.grey,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedOpacity(
                                    opacity:
                                        notificationProvider.notifications.isNotEmpty
                                            ? 1.0
                                            : 0.5,
                                    duration: const Duration(milliseconds: 200),
                                    child: TextButton.icon(
                                      onPressed: notificationProvider.notifications.isNotEmpty
                                          ? () => notificationProvider.clearAllNotifications()
                                          : null,
                                      icon: const Icon(
                                        Icons.clear_all,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Clear',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: notificationProvider.notifications.isNotEmpty
                                            ? Colors.red.shade400
                                            : Colors.grey,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                         ),
                         const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Enhanced Notifications List
                  Expanded(
                    child: Consumer<NotificationProvider>(
                      builder: (context, notificationProvider, child) {
                        if (notificationProvider.isLoading) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(
                                  color: AppTheme.goldColor,
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Loading notifications...',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        if (notificationProvider.notifications.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardColor,
                                    borderRadius: BorderRadius.circular(50),
                                    border: Border.all(
                                        color: AppTheme.borderColor, width: 1),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_outlined,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'No notifications yet',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'You\'ll see notifications here when someone\ninteracts with your posts',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          itemCount: notificationProvider.notifications.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final notification =
                                notificationProvider.notifications[index];
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: AppTheme.cardColor,
                                gradient: notification.isRead
                                    ? null
                                    : LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          AppTheme.goldColor
                                              .withValues(alpha: 0.08),
                                          AppTheme.goldColor
                                              .withValues(alpha: 0.03),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(12),
                                border: notification.isRead
                                    ? Border.all(
                                        color: AppTheme.borderColor,
                                        width: 1,
                                      )
                                    : Border.all(
                                        color: AppTheme.goldColor
                                            .withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                boxShadow: notification.isRead
                                    ? AppTheme.shadowSm
                                    : [
                                        BoxShadow(
                                          color: AppTheme.goldColor
                                              .withValues(alpha: 0.12),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    if (!notification.isRead) {
                                      notificationProvider
                                          .markAsRead(notification.id);
                                    }
                                    // Navigate to post if postId is available
                                    if (notification.postId != null) {
                                      debugPrint('Attempting to navigate to post with ID: ${notification.postId}');
                                      final navigator = Navigator.of(context);
                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      try {
                                        final post = await CommunityService.getPostById(notification.postId!);
                                        debugPrint('Successfully fetched post: ${post.id}');
                                        // Pop the dialog first
                                        navigator.pop();
                                        // Then navigate to the post detail page
                                        if (mounted) {
                                          await navigator.push(
                                            MaterialPageRoute(
                                              builder: (context) => CommunityPostDetailPage(post: post),
                                            ),
                                          );
                                          debugPrint('Navigation completed successfully');
                                        }
                                      } catch (e) {
                                        debugPrint('Error fetching post with ID ${notification.postId}: $e');
                                        // Pop the dialog first
                                        navigator.pop();
                                        if (mounted) {
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Error loading post: ${e.toString()}'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    } else {
                                      // If postId is null, just pop the dialog
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                AppTheme.goldColor
                                                    .withValues(alpha: 0.2),
                                                AppTheme.goldColor
                                                    .withValues(alpha: 0.1),
                                              ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: AppTheme.goldColor
                                                  .withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            notification.type == 'comment'
                                                ? Icons.comment_outlined
                                                : Icons.notifications_active,
                                            color: AppTheme.goldColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                notification.message,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: isMobile ? 14 : 15,
                                                  fontWeight:
                                                      notification.isRead
                                                          ? FontWeight.normal
                                                          : FontWeight.w500,
                                                  height: 1.3,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    size: 12,
                                                    color: Colors.white
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatTimestamp(
                                                        notification.createdAt),
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                              alpha: 0.6),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!notification.isRead) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  AppTheme.goldColor,
                                                  AppTheme.goldColor
                                                      .withValues(alpha: 0.8),
                                                ],
                                              ),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppTheme.goldColor
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
