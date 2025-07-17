import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_service.dart';
import '../models/support_message.dart';
import '../theme/app_theme.dart';
import '../widgets/admin/admin_layout.dart';
import '../widgets/admin/support_message_card.dart';

class AdminSupportPage extends StatefulWidget {
  const AdminSupportPage({super.key});

  @override
  State<AdminSupportPage> createState() => _AdminSupportPageState();
}

class _AdminSupportPageState extends State<AdminSupportPage> with TickerProviderStateMixin {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  final List<String> _filters = ['All', 'Pending', 'Resolved', 'Closed'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      // Filter will be handled in StreamBuilder
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<SupportMessage> _filterMessages(List<SupportMessage> messages) {
    final query = _searchController.text.toLowerCase();

    return messages.where((message) {
      final matchesSearch = query.isEmpty ||
          message.title.toLowerCase().contains(query) ||
          message.message.toLowerCase().contains(query) ||
          message.userEmail.toLowerCase().contains(query);

      final matchesFilter = _selectedFilter == 'All' ||
          message.status.toLowerCase() == _selectedFilter.toLowerCase();

      return matchesSearch && matchesFilter;
    }).toList();
  }

  Future<void> _updateMessageStatus(String messageId, String status) async {
    try {
      final success = await AdminService.updateSupportMessageStatus(messageId, status);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message status updated to $status'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update message: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _respondToMessage(String messageId, String response) async {
    try {
      final adminAuth = context.read<AdminAuthService>();
      final currentAdmin = adminAuth.currentAdmin;

      debugPrint('🔍 Admin response - Current admin: ${currentAdmin?.email}, ID: ${currentAdmin?.id}');

      if (currentAdmin == null) {
        throw Exception('Admin not authenticated');
      }

      if (currentAdmin.id == null || currentAdmin.id!.isEmpty) {
        throw Exception('Admin ID is missing');
      }

      debugPrint('📤 Sending admin response for message: $messageId');

      final success = await AdminService.addSupportMessageResponse(
        messageId,
        response,
        currentAdmin.id!,
      );

      if (success && mounted) {
        debugPrint('✅ Admin response sent successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Response sent successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else if (mounted) {
        debugPrint('❌ Failed to send admin response');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send response'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Admin response error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send response: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Support Messages',
      child: StreamBuilder<List<SupportMessage>>(
        stream: AdminService.getSupportMessagesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.goldColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading messages: ${snapshot.error}',
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final messages = snapshot.data ?? [];
          return _buildSupportContent(messages);
        },
      ),
    );
  }

  Widget _buildSupportContent(List<SupportMessage> messages) {
    final pendingCount = messages.where((m) => m.status == 'pending').length;
    final resolvedCount = messages.where((m) => m.status == 'resolved').length;
    final closedCount = messages.where((m) => m.status == 'closed').length;
    final filteredMessages = _filterMessages(messages);

    return Column(
      children: [
        // Filter tabs
        Container(
          decoration: AppTheme.cardDecoration,
          child: TabBar(
            controller: _tabController,
            onTap: (index) {
              setState(() {
                _selectedFilter = _filters[index];
              });
            },
            tabs: [
              Tab(text: 'All (${messages.length})'),
              Tab(text: 'Pending ($pendingCount)'),
              Tab(text: 'Resolved ($resolvedCount)'),
              Tab(text: 'Closed ($closedCount)'),
            ],
            labelColor: AppTheme.goldColor,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.goldColor,
          ),
        ),

        const SizedBox(height: 16),

        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: AppTheme.cardDecoration,
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Search messages...',
              hintStyle: TextStyle(color: AppTheme.textMuted),
              prefixIcon: Icon(Icons.search, color: AppTheme.goldColor),
              border: InputBorder.none,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Messages list
        Expanded(
          child: filteredMessages.isEmpty
              ? Container(
                  decoration: AppTheme.cardDecoration,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 48,
                          color: AppTheme.textMuted,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages found',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredMessages.length,
                  itemBuilder: (context, index) {
                    final message = filteredMessages[index];
                    return SupportMessageCard(
                      message: message,
                      onStatusUpdate: (status) => _updateMessageStatus(message.id, status),
                      onRespond: (response) => _respondToMessage(message.id, response),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
