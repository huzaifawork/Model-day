import 'package:flutter/material.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/models/direct_booking.dart';
import 'package:new_flutter/models/agent.dart';
import 'package:new_flutter/services/direct_bookings_service.dart';
import 'package:new_flutter/services/agents_service.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/widgets/file_preview_widget.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:new_flutter/widgets/export_button.dart';
import 'package:new_flutter/widgets/clickable_contact_info.dart';
import 'package:url_launcher/url_launcher.dart';

class EnhancedDirectBookingsPage extends StatefulWidget {
  const EnhancedDirectBookingsPage({super.key});

  @override
  State<EnhancedDirectBookingsPage> createState() =>
      _EnhancedDirectBookingsPageState();
}

class _EnhancedDirectBookingsPageState
    extends State<EnhancedDirectBookingsPage> {
  List<DirectBooking> _bookings = [];
  List<DirectBooking> _filteredBookings = [];
  bool _isLoading = true;
  bool _isGridView = true;
  String _searchQuery = '';
  String _sortOrder = 'date-desc';
  final TextEditingController _searchController = TextEditingController();
  Map<String, Agent> _agentCache =
      {}; // Cache for agent ID -> Agent object mapping

  @override
  void initState() {
    super.initState();
    _loadAgents();
    _loadBookings();
  }

  Future<void> _loadAgents() async {
    try {
      final agentsService = AgentsService();
      final agents = await agentsService.getAgents();
      setState(() {
        _agentCache = {
          for (final agent in agents)
            if (agent.id != null) agent.id!: agent
        };
      });
    } catch (e) {
      debugPrint('Error loading agents: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    final currentContext = context;
    try {
      final bookings = await DirectBookingsService.list();
      if (currentContext.mounted) {
        setState(() {
          _bookings = bookings;
          _filteredBookings = bookings;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bookings: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredBookings = _bookings.where((booking) {
        final searchLower = _searchQuery.toLowerCase();
        return booking.clientName.toLowerCase().contains(searchLower) ||
            (booking.bookingType?.toLowerCase().contains(searchLower) ??
                false) ||
            (booking.location?.toLowerCase().contains(searchLower) ?? false);
      }).toList();

      // Apply sorting
      _filteredBookings.sort((a, b) {
        switch (_sortOrder) {
          case 'date-asc':
            return (a.date ?? DateTime(1900))
                .compareTo(b.date ?? DateTime(1900));
          case 'date-desc':
            return (b.date ?? DateTime(1900))
                .compareTo(a.date ?? DateTime(1900));
          case 'client-asc':
            return a.clientName.compareTo(b.clientName);
          case 'client-desc':
            return b.clientName.compareTo(a.clientName);
          default:
            return (b.date ?? DateTime(1900))
                .compareTo(a.date ?? DateTime(1900));
        }
      });
    });
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _applyFilters();
  }

  String _formatDateRange(DirectBooking booking) {
    if (booking.date == null) return 'No date';

    String dateText = DateFormat('MMM d, yyyy').format(booking.date!);

    if (booking.isMultiDay && booking.endDate != null) {
      dateText += ' - ${DateFormat('MMM d, yyyy').format(booking.endDate!)}';
    }

    return dateText;
  }

  String _formatShortDateRange(DirectBooking booking) {
    if (booking.date == null) return 'No date';

    String dateText = DateFormat('MMM d').format(booking.date!);

    if (booking.isMultiDay && booking.endDate != null) {
      dateText += ' - ${DateFormat('MMM d').format(booking.endDate!)}';
    }

    return dateText;
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/direct-bookings',
      title: 'Direct Bookings',
      actions: [
        // Export button
        ExportButton(
          type: ExportType.directBookings,
          data: _filteredBookings,
          customFilename:
              'direct_bookings_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          onPressed: () => setState(() => _isGridView = !_isGridView),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => Navigator.pushNamed(context, '/new-direct-booking'),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 800;

          return Column(
            children: [
              // Header
              _buildHeader(isSmallScreen),
              const SizedBox(height: 24),

              // Search and Filters
              _buildSearchAndFilters(isSmallScreen),
              const SizedBox(height: 16),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredBookings.isEmpty
                        ? _buildEmptyState(isSmallScreen)
                        : _buildBookingsList(isSmallScreen),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Direct Bookings',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track all your direct bookings and earnings',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/new-direct-booking');
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(isSmallScreen ? 'Add' : 'Add New Direct Booking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 8 : 12,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildSearchAndFilters(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 0),
      child: Row(
        children: [
          // Search Field
          Expanded(
            flex: 3,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF3E3E3E)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search bookings...',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Sort Button
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3E3E3E)),
            ),
            child: PopupMenuButton<String>(
              color: const Color(0xFF2A2A2A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFF3E3E3E)),
              ),
              icon: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Sort', style: TextStyle(color: Colors.white)),
                ],
              ),
              onSelected: (value) {
                setState(() => _sortOrder = value);
                _applyFilters();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'date-desc',
                  child: Text('Newest First',
                      style: TextStyle(color: Colors.white)),
                ),
                const PopupMenuItem(
                  value: 'date-asc',
                  child: Text('Oldest First',
                      style: TextStyle(color: Colors.white)),
                ),
                const PopupMenuItem(
                  value: 'client-asc',
                  child: Text('Client (A-Z)',
                      style: TextStyle(color: Colors.white)),
                ),
                const PopupMenuItem(
                  value: 'client-desc',
                  child: Text('Client (Z-A)',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Grid/List Toggle
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF3E3E3E)),
            ),
            child: IconButton(
              icon: Icon(
                _isGridView ? Icons.view_list : Icons.grid_view,
                color: Colors.white,
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 200.ms);
  }

  Widget _buildEmptyState(bool isSmallScreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: isSmallScreen ? 80 : 120,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            'No direct bookings found',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 24,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, '/new-direct-booking'),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add New Direct Booking'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20 : 32,
                vertical: isSmallScreen ? 12 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 400.ms);
  }

  Widget _buildBookingsList(bool isSmallScreen) {
    if (_isGridView && !isSmallScreen) {
      return _buildGridView();
    } else {
      return _buildListView(isSmallScreen);
    }
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 5;
        if (constraints.maxWidth < 1400) {
          crossAxisCount = 4;
        }
        if (constraints.maxWidth < 1100) {
          crossAxisCount = 3;
        }
        if (constraints.maxWidth < 800) {
          crossAxisCount = 2;
        }
        if (constraints.maxWidth < 500) {
          crossAxisCount = 1;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _filteredBookings.length,
          itemBuilder: (context, index) =>
              _buildBookingCard(_filteredBookings[index], index),
        );
      },
    );
  }

  Widget _buildListView(bool isSmallScreen) {
    return ListView.builder(
      padding: const EdgeInsets.all(0),
      itemCount: _filteredBookings.length,
      itemBuilder: (context, index) =>
          _buildBookingListItem(_filteredBookings[index], index, isSmallScreen),
    );
  }

  Widget _buildBookingCard(DirectBooking booking, int index) {
    final finalAmount = _calculateFinalAmount(booking);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3E3E3E)),
      ),
      child: InkWell(
        onTap: () => _showBookingDetails(booking),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with client name and menu
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.clientName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editBooking(booking);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(booking);
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
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Status chip
              _buildStatusChip(booking.status),
              const SizedBox(height: 8),

              // Booking type
              if (booking.bookingType != null)
                Text(
                  booking.bookingType!,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 6),

              // Location
              if (booking.location != null)
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ClickableContactInfo(
                        text: booking.location!,
                        type: ContactType.location,
                        showIcon: false,
                        textColor: Colors.blue[400],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),

              // File attachments section
              Builder(
                builder: (context) {
                  // Check for files in booking.files
                  Map<String, dynamic>? fileData = booking.files;

                  // If no files found, return empty widget
                  if (fileData == null ||
                      !fileData.containsKey('files') ||
                      fileData['files'] is! List ||
                      (fileData['files'] as List).isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    children: [
                      const SizedBox(height: 6),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final filesList = fileData['files'] as List;

                          // For very small cards, show just a compact indicator
                          if (constraints.maxHeight < 200) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey[800]?.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.attach_file,
                                      size: 10, color: Colors.grey),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${filesList.length} file${filesList.length > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }

                          // For larger cards, show the full FilePreviewWidget
                          return FilePreviewWidget(
                            fileData: fileData,
                            showTitle: false, // Hide title to save space
                            maxFilesToShow: 1,
                          );
                        },
                      ),
                    ],
                  );
                },
              ),

              const Spacer(),

              // Date
              if (booking.date != null)
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _formatShortDateRange(booking),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              // Amount
              Text(
                '${_getCurrencySymbol(booking.currency)}${finalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.goldColor,
                ),
              ),
              const SizedBox(height: 4),

              // Payment status
              _buildPaymentStatusChip(booking.paymentStatus),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: Duration(milliseconds: 100 * index));
  }

  Widget _buildBookingListItem(
      DirectBooking booking, int index, bool isSmallScreen) {
    final finalAmount = _calculateFinalAmount(booking);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3E3E3E)),
      ),
      child: InkWell(
        onTap: () => _showBookingDetails(booking),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            booking.clientName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusChip(booking.status),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editBooking(booking);
                            } else if (value == 'delete') {
                              _showDeleteConfirmation(booking);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit,
                                      size: 16, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Edit',
                                      style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (booking.bookingType != null)
                      Text(
                        booking.bookingType!,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    if (booking.date != null)
                      Text(
                        _formatDateRange(booking),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    // File attachments indicator
                    Builder(
                      builder: (context) {
                        // Check for files in booking.files
                        Map<String, dynamic>? fileData = booking.files;

                        // If no files found, return empty widget
                        if (fileData == null ||
                            !fileData.containsKey('files') ||
                            fileData['files'] is! List ||
                            (fileData['files'] as List).isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final filesList = fileData['files'] as List;
                        return Column(
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.attach_file,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${filesList.length} file${filesList.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Amount and payment status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_getCurrencySymbol(booking.currency)}${finalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.goldColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPaymentStatusChip(booking.paymentStatus),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: Duration(milliseconds: 50 * index));
  }

  String _getCurrencySymbol(String? currency) {
    switch (currency) {
      case 'EUR':
        return '€';
      case 'PLN':
        return 'zł';
      case 'ILS':
        return '₪';
      case 'JPY':
        return '¥';
      case 'KRW':
        return '₩';
      case 'GBP':
        return '£';
      case 'USD':
      default:
        return '\$';
    }
  }

  double _calculateFinalAmount(DirectBooking booking) {
    final baseAmount = booking.rate ?? 0;
    final extraHours = double.tryParse(booking.extraHours ?? '0') ?? 0;
    final additionalFees = double.tryParse(booking.additionalFees ?? '0') ?? 0;
    final agencyFeePercentage =
        double.tryParse(booking.agencyFeePercentage ?? '0') ?? 0;
    final taxPercentage = double.tryParse(booking.taxPercentage ?? '0') ?? 0;

    final extraHoursAmount = extraHours * (baseAmount / 8);
    final totalBeforeDeductions =
        baseAmount + extraHoursAmount + additionalFees;
    final agencyFee = (totalBeforeDeductions * agencyFeePercentage) / 100;
    final taxAmount = (totalBeforeDeductions * taxPercentage) / 100;
    final finalAmount = totalBeforeDeductions - agencyFee - taxAmount;

    return finalAmount;
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    String displayText;

    switch (status?.toLowerCase()) {
      case 'scheduled':
        color = Colors.blue;
        displayText = 'Scheduled';
        break;
      case 'in_progress':
        color = Colors.orange;
        displayText = 'In Progress';
        break;
      case 'completed':
        color = Colors.green;
        displayText = 'Completed';
        break;
      case 'canceled':
        color = Colors.red;
        displayText = 'Canceled';
        break;
      default:
        color = Colors.grey;
        displayText = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildPaymentStatusChip(String? paymentStatus) {
    Color color;
    String displayText;

    switch (paymentStatus?.toLowerCase()) {
      case 'paid':
        color = Colors.green;
        displayText = 'Paid';
        break;
      case 'partial':
        color = Colors.orange;
        displayText = 'Partial';
        break;
      case 'unpaid':
        color = Colors.red;
        displayText = 'Unpaid';
        break;
      default:
        color = Colors.grey;
        displayText = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showBookingDetails(DirectBooking booking) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            booking.clientName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildDirectBookingDetails(booking),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.goldColor,
              ),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _editBooking(booking);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildDirectBookingDetails(DirectBooking booking) {
    List<Widget> details = [];

    // Booking Type
    if (booking.bookingType != null && booking.bookingType!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Type', booking.bookingType!),
        const SizedBox(height: 8),
      ]);
    }

    // Date and Time
    if (booking.date != null) {
      details.addAll([
        _buildDetailRow('Date', _formatDateRange(booking)),
        const SizedBox(height: 8),
      ]);
      if (booking.time != null) {
        details.addAll([
          _buildDetailRow('Time',
              '${booking.time}${booking.endTime != null ? ' - ${booking.endTime}' : ''}'),
          const SizedBox(height: 8),
        ]);
      }
    }

    // Location
    if (booking.location != null && booking.location!.isNotEmpty) {
      details.addAll([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                'Location:',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: ClickableContactInfo(
                text: booking.location!,
                type: ContactType.location,
                showIcon: false,
                textColor: Colors.blue[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ]);
    }

    // Rate
    if (booking.rate != null && booking.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate',
            '${_getCurrencySymbol(booking.currency)}${booking.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    // Extra Hours
    if (booking.extraHours != null && booking.extraHours!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Extra Hours', booking.extraHours!),
        const SizedBox(height: 8),
      ]);
    }

    // Booking Agent
    if (booking.bookingAgent != null && booking.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', booking.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    // Contact Information
    if (booking.phone != null && booking.phone!.isNotEmpty) {
      details.addAll([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                'Phone:',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: ClickableContactInfo(
                text: booking.phone!,
                type: ContactType.phone,
                showIcon: false,
                textColor: Colors.blue[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ]);
    }

    if (booking.email != null && booking.email!.isNotEmpty) {
      details.addAll([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                'Email:',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: ClickableContactInfo(
                text: booking.email!,
                type: ContactType.email,
                showIcon: false,
                textColor: Colors.blue[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ]);
    }

    // Status
    details.addAll([
      _buildDetailRow('Status', (booking.status ?? 'Unknown').toUpperCase()),
      const SizedBox(height: 8),
    ]);

    // Payment Status
    details.addAll([
      _buildDetailRow(
          'Payment', (booking.paymentStatus ?? 'Unknown').toUpperCase()),
      const SizedBox(height: 8),
    ]);

    // Notes
    if (booking.notes != null && booking.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', booking.notes!),
        const SizedBox(height: 8),
      ]);
    }

    return details;
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgentRow(String label, String agentIdOrName) {
    // Get agent from cache, fallback to creating a dummy agent with the provided name
    final agent = _agentCache[agentIdOrName] ?? Agent(name: agentIdOrName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Text(
                agent.name,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _sendWhatsAppToAgent(agent),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendWhatsAppToAgent(Agent agent) async {
    // Check if agent has a phone number
    if (agent.phone == null || agent.phone!.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No phone number available for ${agent.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Use the same approach as agents page
    final whatsappUrl = 'https://wa.me/${_cleanPhoneNumber(agent.phone!)}';
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await _launchUrl(whatsappUrl);
    } catch (e) {
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error opening WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _cleanPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _editBooking(DirectBooking booking) async {
    final result = await Navigator.pushNamed(
      context,
      '/edit-direct-booking',
      arguments: booking,
    );
    if (result == true && mounted) {
      _loadBookings();
    }
  }

  void _showDeleteConfirmation(DirectBooking booking) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Booking'),
          content:
              Text('Are you sure you want to delete "${booking.clientName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteBooking(booking);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteBooking(DirectBooking booking) async {
    if (booking.id == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final success = await DirectBookingsService.delete(booking.id!);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Booking deleted successfully'
                : 'Failed to delete booking'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          _loadBookings();
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting booking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
