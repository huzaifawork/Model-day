import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/models/event.dart';
import 'package:new_flutter/models/agent.dart';
import 'package:new_flutter/services/events_service.dart';
import 'package:new_flutter/services/agents_service.dart';
import 'package:new_flutter/widgets/export_button.dart';
import 'package:new_flutter/widgets/clickable_contact_info.dart';
import 'package:new_flutter/widgets/file_preview_widget.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class OtherPage extends StatefulWidget {
  const OtherPage({super.key});

  @override
  State<OtherPage> createState() => _OtherPageState();
}

class _OtherPageState extends State<OtherPage> {
  List<Event> _otherEvents = [];
  List<Event> _filteredOtherEvents = [];
  bool _isLoading = true;
  bool _isGridView = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final EventsService _eventsService = EventsService();
  Map<String, Agent> _agentCache =
      {}; // Cache for agent ID -> Agent object mapping

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load agents first, then events
    await _loadAgents();
    await _loadOtherEvents();
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

  Future<void> _loadOtherEvents() async {
    if (!mounted) return;
    debugPrint(
        '🔄 OtherPage._loadOtherEvents() - Starting to load other events...');
    setState(() => _isLoading = true);
    try {
      final allEvents = await _eventsService.getEvents();
      final otherEvents =
          allEvents.where((event) => event.type == EventType.other).toList();
      debugPrint(
          '🔄 OtherPage._loadOtherEvents() - Loaded ${otherEvents.length} other events');

      // Debug each event's agent info
      for (final event in otherEvents) {
        debugPrint(
            '  📋 Event: ${event.clientName ?? 'Unnamed'} - Agent ID: ${event.agentId}');
      }
      if (!mounted) return;
      setState(() {
        _otherEvents = otherEvents;
        _filteredOtherEvents = otherEvents;
        _isLoading = false;
      });
      _applyFilters();
      debugPrint(
          '🔄 OtherPage._loadOtherEvents() - Applied filters, showing ${_filteredOtherEvents.length} other events');
    } catch (e) {
      debugPrint('❌ OtherPage._loadOtherEvents() - Error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading other events: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {
      _filteredOtherEvents = _otherEvents.where((event) {
        final searchLower = _searchQuery.toLowerCase();
        return (event.clientName?.toLowerCase().contains(searchLower) ??
                false) ||
            (event.location?.toLowerCase().contains(searchLower) ?? false) ||
            (event.notes?.toLowerCase().contains(searchLower) ?? false) ||
            (event.additionalData?['event_name']
                    ?.toLowerCase()
                    .contains(searchLower) ??
                false);
      }).toList();

      _filteredOtherEvents.sort((a, b) {
        final dateA = a.date ?? DateTime(1900);
        final dateB = b.date ?? DateTime(1900);
        return dateB.compareTo(dateA);
      });
    });
  }

  void _onSearchChanged(String query) {
    if (!mounted) return;
    setState(() => _searchQuery = query);
    _applyFilters();
  }

  String _formatDateRange(Event event) {
    if (event.date == null) return 'No Date';

    String dateText = DateFormat('MMM d, yyyy').format(event.date!);

    if (event.endDate != null &&
        !event.endDate!.isAtSameMomentAs(event.date!)) {
      dateText += ' - ${DateFormat('MMM d, yyyy').format(event.endDate!)}';
    }

    return dateText;
  }

  Widget _buildContent() {
    if (_filteredOtherEvents.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _isGridView ? _buildGridView() : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.more_horiz,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No other events found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first other event to get started',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.pushNamed(
                context,
                '/new-event',
                arguments: {'eventType': EventType.other},
              );
              if (result == true && mounted) {
                _loadData();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add New Other Event'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: const InputDecoration(
          hintText: 'Search other events...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/other',
      title: 'Other Events',
      actions: [
        // Export button
        ExportButton(
          type: ExportType.events,
          data: _filteredOtherEvents,
          customFilename:
              'other_events_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          onPressed: () {
            if (mounted) setState(() => _isGridView = !_isGridView);
          },
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () async {
            final result = await Navigator.pushNamed(
              context,
              '/new-event',
              arguments: {'eventType': EventType.other},
            );
            if (result == true && mounted) {
              _loadData();
            }
          },
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        double childAspectRatio =
            0.75; // Taller cards for mobile to accommodate files

        if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
          childAspectRatio = 0.85;
        }
        if (constraints.maxWidth > 900) {
          crossAxisCount = 3;
          childAspectRatio = 0.95;
        }
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
          childAspectRatio = 1.0;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _filteredOtherEvents.length,
          itemBuilder: (context, index) {
            final event = _filteredOtherEvents[index];
            return _buildEventCard(event);
          },
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredOtherEvents.length,
      itemBuilder: (context, index) {
        final event = _filteredOtherEvents[index];
        return _buildEventListItem(event);
      },
    );
  }

  Widget _buildEventCard(Event event) {
    final eventName = event.additionalData?['event_name'] ??
        event.clientName ??
        'Unnamed Event';
    final dateStr = _formatDateRange(event);

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showEventPreview(event),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with title and menu
              Row(
                children: [
                  Expanded(
                    child: Text(
                      eventName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editEvent(event);
                      } else if (value == 'delete') {
                        _deleteEvent(event);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Location (if available)
              if (event.location != null) ...[
                ClickableContactInfo(
                  text: event.location!,
                  type: ContactType.location,
                  iconColor: Colors.grey,
                  textColor: Colors.blue[400],
                  fontSize: 12,
                ),
                const SizedBox(height: 4),
              ],

              // Date
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      dateStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Time (if available)
              if (event.startTime != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      event.startTime!,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],

              // File attachments section
              Builder(
                builder: (context) {
                  // Check for files in event.additionalData.file_data
                  Map<String, dynamic>? fileData;

                  if (event.additionalData != null &&
                      event.additionalData!.containsKey('file_data') &&
                      event.additionalData!['file_data']
                          is Map<String, dynamic>) {
                    fileData = event.additionalData!['file_data']
                        as Map<String, dynamic>;
                  }

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
                          final filesList = fileData!['files'] as List;

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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventListItem(Event event) {
    final eventName = event.additionalData?['event_name'] ??
        event.clientName ??
        'Unnamed Event';
    final dateStr = _formatDateRange(event);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showEventPreview(event),
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.more_horiz, color: Colors.white),
        ),
        title: Text(
          eventName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.location != null) ...[
              ClickableContactInfo(
                text: event.location!,
                type: ContactType.location,
                iconColor: Colors.grey,
                textColor: Colors.blue[400],
                fontSize: 14,
              ),
            ],
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.grey),
                ),
                if (event.startTime != null) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    event.startTime!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
            // File attachments indicator
            Builder(
              builder: (context) {
                // Check for files in event.additionalData.file_data
                Map<String, dynamic>? fileData;

                if (event.additionalData != null &&
                    event.additionalData!.containsKey('file_data') &&
                    event.additionalData!['file_data']
                        is Map<String, dynamic>) {
                  fileData = event.additionalData!['file_data']
                      as Map<String, dynamic>;
                }

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
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editEvent(event);
            } else if (value == 'delete') {
              _deleteEvent(event);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventPreview(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          event.clientName ?? 'Other Event',
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
              children: _buildEventDetails(event),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _editEvent(event);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.black,
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildEventDetails(Event event) {
    List<Widget> details = [];

    // Client Name
    if (event.clientName != null && event.clientName!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Client', event.clientName!),
        const SizedBox(height: 8),
      ]);
    }

    // Date
    if (event.date != null) {
      details.addAll([
        _buildDetailRow('Date', _formatDateRange(event)),
        const SizedBox(height: 8),
      ]);
    }

    // Time
    if (event.startTime != null && event.startTime!.isNotEmpty) {
      String timeText = event.startTime!;
      if (event.endTime != null && event.endTime!.isNotEmpty) {
        timeText += ' - ${event.endTime!}';
      }
      details.addAll([
        _buildDetailRow('Time', timeText),
        const SizedBox(height: 8),
      ]);
    }

    // Location
    if (event.location != null && event.location!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Location', event.location!),
        const SizedBox(height: 8),
      ]);
    }

    // Agent Information
    debugPrint('🔍 Other Event Agent Debug:');
    debugPrint('  - event.agentId: ${event.agentId}');
    debugPrint('  - _agentCache.length: ${_agentCache.length}');
    debugPrint('  - _agentCache.keys: ${_agentCache.keys.toList()}');

    if (event.agentId != null && event.agentId!.isNotEmpty) {
      final agent = _agentCache[event.agentId!];
      debugPrint('  - Found agent: ${agent?.name ?? 'NOT FOUND'}');
      details.addAll([
        _buildAgentRow('Agent', event.agentId!),
        const SizedBox(height: 8),
      ]);
    } else {
      debugPrint('  - No agent ID found in event');
    }

    // Status
    if (event.status != null) {
      details.addAll([
        _buildDetailRow(
            'Status', event.status.toString().split('.').last.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    // Payment Status
    if (event.paymentStatus != null) {
      details.addAll([
        _buildDetailRow('Payment',
            event.paymentStatus.toString().split('.').last.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    // Day Rate
    if (event.dayRate != null && event.dayRate! > 0) {
      details.addAll([
        _buildDetailRow('Day Rate', '£${event.dayRate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    // Usage Rate
    if (event.usageRate != null && event.usageRate! > 0) {
      details.addAll([
        _buildDetailRow(
            'Usage Rate', '£${event.usageRate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    // Notes
    if (event.notes != null && event.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', event.notes!),
        const SizedBox(height: 8),
      ]);
    }

    // Contact Information (if available in additionalData)
    if (event.additionalData != null) {
      final email = event.additionalData!['clientEmail'] as String?;
      final phone = event.additionalData!['clientPhone'] as String?;

      if (email != null && email.isNotEmpty) {
        details.addAll([
          _buildClickableDetailRow('Email', email, ContactType.email),
          const SizedBox(height: 8),
        ]);
      }

      if (phone != null && phone.isNotEmpty) {
        details.addAll([
          _buildClickableDetailRow('Phone', phone, ContactType.phone),
          const SizedBox(height: 8),
        ]);
      }
    }

    // Files
    if (event.files != null && event.files!.isNotEmpty) {
      details.addAll([
        FilePreviewWidget(
          fileData: event.files,
          showTitle: true,
        ),
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

  Widget _buildClickableDetailRow(
      String label, String value, ContactType type) {
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
          child: ClickableContactInfo(
            text: value,
            type: type,
            showIcon: false,
            textColor: Colors.blue[300],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAgentRow(String label, String agentId) {
    // Get agent from cache
    final agent = _agentCache[agentId];
    debugPrint('🔍 _buildAgentRow called with agentId: $agentId');
    debugPrint('🔍 Found agent: ${agent?.name ?? 'NULL'}');

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
                agent?.name ?? 'Unknown Agent',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 6),
              if (agent != null)
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
    final currentContext = context;

    try {
      await _launchUrl(whatsappUrl);
    } catch (e) {
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
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

  void _editEvent(Event event) async {
    final result = await Navigator.pushNamed(
      context,
      '/new-event',
      arguments: {
        'eventType': EventType.other,
        'event': event,
      },
    );
    if (result == true && mounted) {
      _loadData();
    }
  }

  void _deleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
            'Are you sure you want to delete "${event.additionalData?['event_name'] ?? event.clientName ?? 'this event'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && event.id != null) {
      try {
        final success = await _eventsService.deleteEvent(event.id!);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully')),
          );
          _loadData();
        } else {
          throw Exception('Failed to delete event');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting event: $e')),
          );
        }
      }
    }
  }
}
