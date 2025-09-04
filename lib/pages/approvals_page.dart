import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/app_layout.dart';
import '../theme/app_theme.dart';
import '../services/events_service.dart';
import '../services/auth_service.dart';
import '../services/google_calendar_service.dart';
import '../models/event.dart';
import '../providers/approval_notification_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final EventsService _eventsService = EventsService();
  List<Event> _pendingEvents = [];
  List<Event> _processedEvents = [];
  List<Event> _receivedEvents = [];
  List<Event> _sentEvents = [];
  bool _isLoading = true;
  final Map<String, bool> _expandedStates = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEvents();

    // Initialize approval notifications
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        context.read<ApprovalNotificationProvider>().initialize();
      }
    });

    // Optional: Set up periodic refresh to catch status updates from models
    // Commented out to prevent automatic refreshing - uncomment if needed
    // _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
    //   if (mounted) {
    //     _loadEvents();
    //   }
    // });
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      final currentUserEmail = currentUser?.email;

      if (currentUserEmail == null) {
        debugPrint('No current user email found');
        setState(() {
          _pendingEvents = [];
          _processedEvents = [];
          _isLoading = false;
        });
        return;
      }

      debugPrint('📅 Loading events for approvals...');
      final rawDocuments = await _eventsService.getEventsWithRawData();
      debugPrint('📅 Total events fetched: ${rawDocuments.length}');
      debugPrint('📧 Current user email: $currentUserEmail');
      debugPrint(
          '🔐 Auth service current user: ${authService.currentUser?.email}');
      debugPrint('🔐 Is authenticated: ${authService.isAuthenticated}');

      // Debug: Print first event structure to understand data format
      if (rawDocuments.isNotEmpty) {
        final firstDoc = rawDocuments.first;
        debugPrint('🔍 First event debug:');
        debugPrint('  - model_email: ${firstDoc['model_email']}');
        debugPrint('  - agent_email: ${firstDoc['agent_email']}');
        debugPrint('  - status: ${firstDoc['status']}');
        debugPrint('  - type: ${firstDoc['type']}');
      }

      // Filter documents based on email fields, then convert to Event objects
      final receivedDocs = rawDocuments.where((doc) {
        final modelEmail = doc['model_email'];
        final agentEmail = doc['agent_email'];
        final isReceived = modelEmail == currentUserEmail;
        debugPrint(
            '🔍 Checking doc ${doc['id']}: model_email = $modelEmail, agent_email = $agentEmail, isReceived = $isReceived (currentUser: $currentUserEmail)');
        // User receives events where they are the model (receiving approval requests)
        return isReceived;
      }).toList();

      final sentDocs = rawDocuments.where((doc) {
        final modelEmail = doc['model_email'];
        final agentEmail = doc['agent_email'];
        final isSent = agentEmail == currentUserEmail;
        debugPrint(
            '🔍 Checking doc ${doc['id']}: model_email = $modelEmail, agent_email = $agentEmail, isSent = $isSent (currentUser: $currentUserEmail)');
        // User sends events where they are the agent (sending approval requests)
        return isSent;
      }).toList();

      debugPrint('📥 Filtered receivedDocs: ${receivedDocs.length}');
      debugPrint('📤 Filtered sentDocs: ${sentDocs.length}');

      // Convert filtered documents to Event objects, preserving email fields
      final receivedEvents = receivedDocs.map((doc) {
        // Add email fields to additional_data before creating Event
        final docWithEmails = Map<String, dynamic>.from(doc);
        docWithEmails['additional_data'] = {
          ...?(doc['additional_data'] as Map<String, dynamic>?),
          'model_email': doc['model_email'],
          'agent_email': doc['agent_email'],
          'status': doc['status'],
        };
        return Event.fromJson(docWithEmails);
      }).toList();

      final sentEvents = sentDocs.map((doc) {
        // Add email fields to additional_data before creating Event
        final docWithEmails = Map<String, dynamic>.from(doc);
        docWithEmails['additional_data'] = {
          ...?(doc['additional_data'] as Map<String, dynamic>?),
          'model_email': doc['model_email'],
          'agent_email': doc['agent_email'],
          'status': doc['status'],
        };
        return Event.fromJson(docWithEmails);
      }).toList();

      debugPrint('📥 Received events: ${receivedEvents.length}');
      debugPrint('📤 Sent events: ${sentEvents.length}');

      // Debug: Print details of received and sent events
      debugPrint('🔍 Received events details:');
      for (int i = 0; i < receivedEvents.length; i++) {
        final event = receivedEvents[i];
        debugPrint(
            '  Event $i: model_email=${event.additionalData?['model_email']}, agent_email=${event.additionalData?['agent_email']}');
      }

      debugPrint('🔍 Sent events details:');
      for (int i = 0; i < sentEvents.length; i++) {
        final event = sentEvents[i];
        debugPrint(
            '  Event $i: model_email=${event.additionalData?['model_email']}, agent_email=${event.additionalData?['agent_email']}');
      }

      setState(() {
        // Filter received events to only show pending ones
        _receivedEvents = receivedEvents.where((event) {
          final rawStatus =
              (event.additionalData?['status'] ?? '').toString().toLowerCase();
          final enumStatus =
              event.status?.toString().split('.').last.toLowerCase();
          final optionEnum =
              event.optionStatus?.toString().split('.').last.toLowerCase();
          return rawStatus == 'pending' ||
              enumStatus == 'pending' ||
              optionEnum == 'pending';
        }).toList();

        // Sent events include all statuses
        _sentEvents = sentEvents;

        // For backward compatibility with existing UI
        _pendingEvents = _receivedEvents;
        _processedEvents = _sentEvents;

        _isLoading = false;
      });

      debugPrint('📋 Pending events (received): ${_pendingEvents.length}');
      debugPrint(
          '📋 Processed events (received + sent): ${_processedEvents.length}');
    } catch (e) {
      debugPrint('❌ Error loading events: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveEvent(String eventId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Find the event to get details for calendar sync and notifications
      final event = _receivedEvents.firstWhere((e) => e.id == eventId);
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      final notificationProvider = context.read<ApprovalNotificationProvider>();

      final success = await _eventsService.approveEvent(eventId);
      if (!mounted) return;
      
      if (success) {
        // Sync to calendar
        try {
          await GoogleCalendarService.createEventInGoogleCalendar(event);
        } catch (calendarError) {
          debugPrint('Calendar sync failed: $calendarError');
        }

        // Create notification for the event sender
        if (event.createdBy != null && currentUser != null) {
          await notificationProvider.createApprovalApprovedNotification(
            recipientUserId: event.createdBy!,
            approverUserId: currentUser.uid,
            approverUserName:
                currentUser.displayName ?? currentUser.email ?? 'Unknown User',
            approverUserEmail: currentUser.email ?? '',
            event: event,
          );
        }

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Event approved and synced to calendar'),
              backgroundColor: Colors.green,
            ),
          );
          _loadEvents(); // Refresh the data
        }
      } else {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to approve event'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error approving event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectEvent(String eventId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Find the event to get details for notifications
      final event = _receivedEvents.firstWhere((e) => e.id == eventId);
      final authService = context.read<AuthService>();
      final currentUser = authService.currentUser;
      final notificationProvider = context.read<ApprovalNotificationProvider>();

      final success = await _eventsService.rejectEvent(eventId);
      if (!mounted) return;
      
      if (success) {
        // Create notification for the event sender
        if (event.createdBy != null && currentUser != null) {
          await notificationProvider.createApprovalRejectedNotification(
            recipientUserId: event.createdBy!,
            rejecterUserId: currentUser.uid,
            rejecterUserName:
                currentUser.displayName ?? currentUser.email ?? 'Unknown User',
            rejecterUserEmail: currentUser.email ?? '',
            event: event,
          );
        }

        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Event rejected successfully'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadEvents(); // Refresh the data
        }
      } else {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to reject event'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error rejecting event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return AppLayout(
      currentPage: '/approvals',
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header - Responsive Layout
                isMobile
                    ? Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.goldColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.goldColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.check_circle_outline,
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
                                  'Approvals',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'Manage event approvals',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white70,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          // Notification Icon - Mobile (positioned like desktop)
                          Consumer<ApprovalNotificationProvider>(
                            builder: (context, notificationProvider, child) {
                              final unreadCount =
                                  notificationProvider.unreadCount;
                              debugPrint(
                                  '🔔 Mobile notification icon rendering - unreadCount: $unreadCount');
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Stack(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        debugPrint(
                                            '🔔 Mobile notification icon pressed');
                                        _showNotificationPanel(context);
                                      },
                                      icon: Icon(
                                        Icons.notifications,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      tooltip: 'Notifications',
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                            minHeight: 20,
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.goldColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.goldColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.check_circle_outline,
                              color: AppTheme.goldColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Approvals',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'Manage event approvals and requests',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.white70,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          // Notification Icon - Desktop
                          Consumer<ApprovalNotificationProvider>(
                            builder: (context, notificationProvider, child) {
                              final unreadCount =
                                  notificationProvider.unreadCount;
                              debugPrint(
                                  '🔔 Notification icon rendering - unreadCount: $unreadCount');
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.1)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Stack(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        debugPrint(
                                            '🔔 Notification icon pressed');
                                        _showNotificationPanel(context);
                                      },
                                      icon: Icon(
                                        Icons.notifications,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      tooltip: 'Notifications',
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                            minHeight: 20,
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                SizedBox(height: isMobile ? 16 : 24),

                // Tab Bar - Responsive
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: AppTheme.goldColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                      border: Border.all(
                        color: AppTheme.goldColor,
                        width: isMobile ? 2.5 : 2.0,
                      ),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 4 : 8,
                      vertical: isMobile ? 4 : 6,
                    ),
                    labelColor: AppTheme.goldColor,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 14 : 16,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: isMobile ? 14 : 16,
                    ),
                    labelPadding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 16,
                      vertical: isMobile ? 12 : 16,
                    ),
                    tabs: [
                      Tab(
                        child: Text(
                          isMobile ? 'Received' : 'Received Approvals',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Tab(
                        child: Text(
                          isMobile ? 'Sent' : 'Sent Approvals',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildReceivedApprovalsTab(),
                      _buildSentApprovalsTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }





  Widget _buildReceivedApprovalsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(
          color: AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Received Approvals',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          // Table Header - Only show on desktop
          if (!isMobile && !_isLoading && _pendingEvents.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.goldColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.goldColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Sent By',
                      style: TextStyle(
                        color: AppTheme.goldColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Approve/Disapprove',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.goldColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.goldColor,
                    ),
                  )
                : _pendingEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: Colors.white30,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No pending approvals',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _pendingEvents.length,
                        itemBuilder: (context, index) {
                          final event = _pendingEvents[index];
                          return _buildReceivedApprovalCard(
                              event, index, isMobile);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentApprovalsTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(
          color: AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sent Approvals',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          // Table Header - Only show on desktop
          if (!isMobile && !_isLoading && _sentEvents.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.goldColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.goldColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Sent To',
                      style: TextStyle(
                        color: AppTheme.goldColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        color: AppTheme.goldColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Event Info',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.goldColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.goldColor,
                    ),
                  )
                : _sentEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.send_outlined,
                              size: 64,
                              color: Colors.white30,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No sent approvals',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _sentEvents.length,
                        itemBuilder: (context, index) {
                          final event = _sentEvents[index];
                          return _buildSentApprovalCard(event, index, isMobile);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedApprovalCard(Event event, int index, bool isMobile) {
    final isExpanded =
        event.id != null ? (_expandedStates[event.id!] ?? false) : false;
    final agentEmail = event.additionalData?['agent_email'] ?? 'Unknown Agent';

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 12),
            child: isMobile
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.goldColor.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.goldColor.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with Agent Info - Compact
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.goldColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.goldColor.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.goldColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  color: AppTheme.goldColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sent by Agent',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      agentEmail,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Action Buttons - Compact Mobile Design
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green.shade600,
                                      Colors.green.shade700
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: event.id != null
                                      ? () => _approveEvent(event.id!)
                                      : null,
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Approve',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.red.shade600,
                                      Colors.red.shade700
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton.icon(
                                  onPressed: event.id != null
                                      ? () => _rejectEvent(event.id!)
                                      : null,
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Reject',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Expand/Collapse Button - Compact
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.goldColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.goldColor.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  if (event.id != null) {
                                    _expandedStates[event.id!] = !isExpanded;
                                  }
                                });
                              },
                              icon: Icon(
                                isExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                color: AppTheme.goldColor,
                                size: 18,
                              ),
                              label: Text(
                                isExpanded ? 'Show Less' : 'Show Details',
                                style: TextStyle(
                                  color: AppTheme.goldColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      // Desktop Layout - Row
                      Expanded(
                        flex: 3,
                        child: Text(
                          agentEmail,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Approve/Disapprove Column with Actions
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: event.id != null
                                  ? () => _approveEvent(event.id!)
                                  : null,
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              tooltip: 'Approve',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: event.id != null
                                  ? () => _rejectEvent(event.id!)
                                  : null,
                              icon: const Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 20,
                              ),
                              tooltip: 'Reject',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  if (event.id != null) {
                                    _expandedStates[event.id!] = !isExpanded;
                                  }
                                });
                              },
                              icon: Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: AppTheme.goldColor,
                                size: 20,
                              ),
                              tooltip: isExpanded ? 'Collapse' : 'Expand',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event Information',
                    style: TextStyle(
                      color: AppTheme.goldColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEventInfoRow('Client', event.clientName ?? 'N/A'),
                  _buildEventInfoRow('Type', event.type.displayName),
                  _buildEventInfoRow(
                      'Date',
                      event.date != null
                          ? DateFormat('MMM dd, yyyy').format(event.date!)
                          : 'N/A'),
                  _buildEventInfoRow('Location', event.location ?? 'N/A'),
                  _buildEventInfoRow(
                      'Day Rate',
                      event.dayRate != null
                          ? '${event.currency ?? ''} ${event.dayRate}'
                          : 'N/A'),
                  _buildEventInfoRow('Notes', event.notes ?? 'No notes'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSentApprovalCard(Event event, int index, bool isMobile) {
    final isExpanded =
        event.id != null ? (_expandedStates[event.id!] ?? false) : false;
    final status = event.additionalData?['status'] ?? 'pending';
    final statusColor = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;
    final modelEmail = event.additionalData?['model_email'] ?? 'Unknown Model';

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 12),
            child: isMobile
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.goldColor.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.goldColor.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with Model Info - Compact
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.goldColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.goldColor.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.goldColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.send_rounded,
                                  color: AppTheme.goldColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sent to Model',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      modelEmail,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Status Section - Compact
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor.withValues(alpha: 0.1),
                                statusColor.withValues(alpha: 0.03),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.25),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  _getStatusIcon(status),
                                  color: statusColor,
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Status',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Expand/Collapse Button - Compact
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.goldColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.goldColor.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  if (event.id != null) {
                                    _expandedStates[event.id!] = !isExpanded;
                                  }
                                });
                              },
                              icon: Icon(
                                isExpanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                color: AppTheme.goldColor,
                                size: 20,
                              ),
                              label: Text(
                                isExpanded ? 'Show Less' : 'Show Details',
                                style: TextStyle(
                                  color: AppTheme.goldColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      // Desktop Layout - Row
                      Expanded(
                        flex: 3,
                        child: Text(
                          modelEmail,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Status Column
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // Event Info Column with Dropdown
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: IconButton(
                            onPressed: () {
                              setState(() {
                                if (event.id != null) {
                                  _expandedStates[event.id!] = !isExpanded;
                                }
                              });
                            },
                            icon: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: AppTheme.goldColor,
                              size: 20,
                            ),
                            tooltip: isExpanded ? 'Collapse' : 'Expand',
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event Information',
                    style: TextStyle(
                      color: AppTheme.goldColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEventInfoRow('Client', event.clientName ?? 'N/A'),
                  _buildEventInfoRow('Type', event.type.displayName),
                  _buildEventInfoRow(
                      'Date',
                      event.date != null
                          ? DateFormat('MMM dd, yyyy').format(event.date!)
                          : 'N/A'),
                  _buildEventInfoRow('Location', event.location ?? 'N/A'),
                  _buildEventInfoRow(
                      'Day Rate',
                      event.dayRate != null
                          ? '${event.currency ?? ''} ${event.dayRate}'
                          : 'N/A'),
                  _buildEventInfoRow('Notes', event.notes ?? 'No notes'),
                ],
              ),
            ),
        ],
      ),
    );
  }







  Widget _buildEventInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'blue':
        return Colors.blue;
      case 'yellow':
        return Colors.yellow;
      case 'purple':
        return Colors.purple;
      case 'grey':
      case 'gray':
        return Colors.grey;
      default:
        return AppTheme.goldColor;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  void _showNotificationPanel(BuildContext context) {
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
                  isMobile ? screenSize.height * 0.8 : (isTablet ? 550 : 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A1A1A),
                    const Color(0xFF2A2A2A),
                  ],
                ),
                borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                border: Border.all(
                  color: AppTheme.goldColor.withValues(alpha: 0.4),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section with responsive layout
                  isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Notifications',
                                  style: TextStyle(
                                    color: AppTheme.goldColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Consumer<ApprovalNotificationProvider>(
                              builder: (context, provider, child) {
                                return Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed:
                                            provider.notifications.isNotEmpty
                                                ? () => provider.markAllAsRead()
                                                : null,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          backgroundColor: provider
                                                  .notifications.isNotEmpty
                                              ? AppTheme.goldColor
                                                  .withValues(alpha: 0.1)
                                              : Colors.grey.withValues(alpha: 0.1),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Mark All Read',
                                          style: TextStyle(
                                            color: provider
                                                    .notifications.isNotEmpty
                                                ? AppTheme.goldColor
                                                : Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextButton(
                                        onPressed: provider
                                                .notifications.isNotEmpty
                                            ? () =>
                                                provider.clearAllNotifications()
                                            : null,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                          backgroundColor: provider
                                                  .notifications.isNotEmpty
                                              ? Colors.red.withValues(alpha: 0.1)
                                              : Colors.grey.withValues(alpha: 0.1),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Clear All',
                                          style: TextStyle(
                                            color: provider
                                                    .notifications.isNotEmpty
                                                ? Colors.red
                                                : Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Approval Notifications',
                              style: TextStyle(
                                color: AppTheme.goldColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Consumer<ApprovalNotificationProvider>(
                                  builder: (context, provider, child) {
                                    return TextButton(
                                      onPressed:
                                          provider.notifications.isNotEmpty
                                              ? () => provider.markAllAsRead()
                                              : null,
                                      child: Text(
                                        'Mark All Read',
                                        style: TextStyle(
                                          color:
                                              provider.notifications.isNotEmpty
                                                  ? AppTheme.goldColor
                                                  : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                Consumer<ApprovalNotificationProvider>(
                                  builder: (context, provider, child) {
                                    return TextButton(
                                      onPressed: provider
                                              .notifications.isNotEmpty
                                          ? () =>
                                              provider.clearAllNotifications()
                                          : null,
                                      child: Text(
                                        'Clear All',
                                        style: TextStyle(
                                          color:
                                              provider.notifications.isNotEmpty
                                                  ? Colors.red
                                                  : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Consumer<ApprovalNotificationProvider>(
                      builder: (context, provider, child) {
                        if (provider.notifications.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_none,
                                  size: 64,
                                  color: Colors.white30,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No notifications yet',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: provider.notifications.length,
                          separatorBuilder: (context, index) => Divider(
                            color: Colors.white10,
                            height: isMobile ? 0.5 : 1,
                            thickness: 0.5,
                          ),
                          itemBuilder: (context, index) {
                            final notification = provider.notifications[index];
                            return Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: isMobile ? 4 : 0,
                                vertical: isMobile ? 2 : 0,
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: isMobile ? 10 : 12,
                                horizontal: isMobile ? 12 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: notification.isRead
                                    ? Colors.transparent
                                    : AppTheme.goldColor.withValues(alpha: 0.05),
                                borderRadius:
                                    BorderRadius.circular(isMobile ? 12 : 8),
                                border: isMobile && !notification.isRead
                                    ? Border.all(
                                        color:
                                            AppTheme.goldColor.withValues(alpha: 0.2),
                                        width: 0.5,
                                      )
                                    : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                              notification.statusColor)
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(
                                          isMobile ? 6 : 8),
                                    ),
                                    child: Text(
                                      notification.notificationIcon,
                                      style: TextStyle(
                                        fontSize: isMobile ? 16 : 20,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isMobile ? 8 : 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notification.message,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isMobile ? 13 : 14,
                                            fontWeight: notification.isRead
                                                ? FontWeight.normal
                                                : FontWeight.w600,
                                          ),
                                          maxLines: isMobile ? 2 : null,
                                          overflow: isMobile
                                              ? TextOverflow.ellipsis
                                              : null,
                                        ),
                                        SizedBox(height: isMobile ? 3 : 4),
                                        if (notification
                                                .eventTitle?.isNotEmpty ==
                                            true)
                                          Text(
                                            'Event: ${notification.eventTitle}',
                                            style: TextStyle(
                                              color: AppTheme.goldColor,
                                              fontSize: isMobile ? 11 : 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: isMobile ? 1 : null,
                                            overflow: isMobile
                                                ? TextOverflow.ellipsis
                                                : null,
                                          ),
                                        if (notification
                                                .fromUserName?.isNotEmpty ==
                                            true)
                                          Text(
                                            'From: ${notification.fromUserName}',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: isMobile ? 11 : 12,
                                            ),
                                            maxLines: isMobile ? 1 : null,
                                            overflow: isMobile
                                                ? TextOverflow.ellipsis
                                                : null,
                                          ),
                                        if (notification.eventDate != null)
                                          Text(
                                            'Date: ${notification.formattedEventDate}',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: isMobile ? 10 : 11,
                                            ),
                                          ),
                                        if (notification
                                                .eventLocation?.isNotEmpty ==
                                            true)
                                          Text(
                                            'Location: ${notification.eventLocation}',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: isMobile ? 10 : 11,
                                            ),
                                            maxLines: isMobile ? 1 : null,
                                            overflow: isMobile
                                                ? TextOverflow.ellipsis
                                                : null,
                                          ),
                                        SizedBox(height: isMobile ? 3 : 4),
                                        Text(
                                          DateFormat(isMobile
                                                  ? 'MMM dd • hh:mm a'
                                                  : 'MMM dd, yyyy • hh:mm a')
                                              .format(notification.createdAt),
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: isMobile ? 9 : 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      if (!notification.isRead)
                                        Container(
                                          width: isMobile ? 6 : 8,
                                          height: isMobile ? 6 : 8,
                                          decoration: BoxDecoration(
                                            color: AppTheme.goldColor,
                                            borderRadius: BorderRadius.circular(
                                                isMobile ? 3 : 4),
                                          ),
                                        ),
                                      SizedBox(height: isMobile ? 6 : 8),
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: Colors.white54,
                                          size: isMobile ? 14 : 16,
                                        ),
                                        color: const Color(0xFF2A2A2A),
                                        padding:
                                            EdgeInsets.all(isMobile ? 4 : 8),
                                        onSelected: (value) {
                                          switch (value) {
                                            case 'mark_read':
                                              if (!notification.isRead) {
                                                provider.markAsRead(
                                                    notification.id);
                                              }
                                              break;
                                            case 'delete':
                                              provider.deleteNotification(
                                                  notification.id);
                                              break;
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          if (!notification.isRead)
                                            PopupMenuItem(
                                              value: 'mark_read',
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isMobile ? 12 : 16,
                                                vertical: isMobile ? 8 : 12,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.mark_email_read,
                                                    color: AppTheme.goldColor,
                                                    size: isMobile ? 14 : 16,
                                                  ),
                                                  SizedBox(
                                                      width: isMobile ? 6 : 8),
                                                  Text(
                                                    'Mark as Read',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize:
                                                          isMobile ? 13 : 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isMobile ? 12 : 16,
                                              vertical: isMobile ? 8 : 12,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.delete,
                                                  color: Colors.red,
                                                  size: isMobile ? 14 : 16,
                                                ),
                                                SizedBox(
                                                    width: isMobile ? 6 : 8),
                                                Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize:
                                                        isMobile ? 13 : 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
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
