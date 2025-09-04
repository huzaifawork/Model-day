import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/widgets/export_button.dart';
import 'package:new_flutter/widgets/clickable_contact_info.dart';
import 'package:new_flutter/models/meeting.dart';
import 'package:new_flutter/models/agent.dart';
import 'package:new_flutter/services/meetings_service.dart';
import 'package:new_flutter/services/agents_service.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  List<Meeting> _meetings = [];
  List<Meeting> _filteredMeetings = [];
  bool _isLoading = true;
  Map<String, Agent> _agentCache =
      {}; // Cache for agent ID -> Agent object mapping
  bool _isGridView = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAgents();
    _loadMeetings();
  }

  Future<void> _loadAgents() async {
    try {
      final agentsService = AgentsService();
      final agents = await agentsService.getAgents();
      if (mounted) {
        setState(() {
          _agentCache = {
            for (final agent in agents)
              if (agent.id != null) agent.id!: agent
          };
        });
      }
    } catch (e) {
      debugPrint('Error loading agents: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMeetings() async {
    if (!mounted) return;
    debugPrint(
        '🏢 MeetingsPage._loadMeetings() - Starting to load meetings...');
    setState(() => _isLoading = true);
    final currentContext = context;
    try {
      final meetings = await MeetingsService.list();
      debugPrint(
          '🏢 MeetingsPage._loadMeetings() - Loaded ${meetings.length} meetings');
      if (!mounted) return;
      setState(() {
        _meetings = meetings;
        _filteredMeetings = meetings;
        _isLoading = false;
      });
      _applyFilters();
      debugPrint(
          '🏢 MeetingsPage._loadMeetings() - Applied filters, showing ${_filteredMeetings.length} meetings');
    } catch (e) {
      debugPrint('❌ MeetingsPage._loadMeetings() - Error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (currentContext.mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(content: Text('Error loading meetings: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {
      _filteredMeetings = _meetings.where((meeting) {
        final searchLower = _searchQuery.toLowerCase();
        return meeting.clientName.toLowerCase().contains(searchLower) ||
            (meeting.type?.toLowerCase().contains(searchLower) ?? false) ||
            (meeting.location?.toLowerCase().contains(searchLower) ?? false);
      }).toList();

      _filteredMeetings.sort((a, b) {
        try {
          final dateA = DateTime.tryParse(a.date) ?? DateTime(1900);
          final dateB = DateTime.tryParse(b.date) ?? DateTime(1900);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });
    });
  }

  void _onSearchChanged(String query) {
    if (!mounted) return;
    setState(() => _searchQuery = query);
    _applyFilters();
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search meetings...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: _filteredMeetings.isEmpty
              ? _buildEmptyState()
              : _isGridView
                  ? _buildGridView()
                  : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No meetings found',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/new-meeting');
              if (result == true && mounted) {
                _loadMeetings();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add New Meeting'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 600) crossAxisCount = 2;
        if (constraints.maxWidth > 900) crossAxisCount = 3;
        if (constraints.maxWidth > 1200) crossAxisCount = 4;

        return GridView.builder(
          padding: const EdgeInsets.all(0),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _filteredMeetings.length,
          itemBuilder: (context, index) =>
              _buildMeetingCard(_filteredMeetings[index]),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(0),
      itemCount: _filteredMeetings.length,
      itemBuilder: (context, index) =>
          _buildMeetingListItem(_filteredMeetings[index]),
    );
  }

  Widget _buildMeetingCard(Meeting meeting) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showMeetingPreview(meeting),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      meeting.clientName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(meeting.status),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editMeeting(meeting);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(meeting);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
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
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(meeting.type ?? 'No Type',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(_formatDate(meeting.date),
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
              if (meeting.location != null && meeting.location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClickableContactInfo(
                  text: meeting.location!,
                  type: ContactType.location,
                  iconColor: Colors.grey,
                  textColor: Colors.blue[400],
                  fontSize: 14,
                ),
              ],
              if (meeting.email != null && meeting.email!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClickableContactInfo(
                  text: meeting.email!,
                  type: ContactType.email,
                  iconColor: Colors.grey,
                  textColor: Colors.blue[400],
                  fontSize: 14,
                ),
              ],
              if (meeting.phone != null && meeting.phone!.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClickableContactInfo(
                  text: meeting.phone!,
                  type: ContactType.phone,
                  iconColor: Colors.grey,
                  textColor: Colors.blue[400],
                  fontSize: 14,
                ),
              ],
              const Spacer(),
              if (meeting.rate != null && meeting.rate!.isNotEmpty)
                Text('\$${meeting.rate}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingListItem(Meeting meeting) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(meeting.clientName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(meeting.type ?? 'No Type'),
            Text(_formatDate(meeting.date)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (meeting.rate != null && meeting.rate!.isNotEmpty)
              Text('\$${meeting.rate}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            _buildStatusChip(meeting.status),
          ],
        ),
        onTap: () => _showMeetingPreview(meeting),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    switch (status) {
      case 'scheduled':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'canceled':
        color = Colors.red;
        break;
      case 'rescheduled':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(status?.toUpperCase() ?? 'UNKNOWN',
          style: const TextStyle(fontSize: 10, color: Colors.white)),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _showMeetingPreview(Meeting meeting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          meeting.clientName,
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
              children: _buildMeetingDetails(meeting),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.goldColor,
            ),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _editMeeting(meeting);
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

  List<Widget> _buildMeetingDetails(Meeting meeting) {
    List<Widget> details = [];

    // Type
    if (meeting.type != null && meeting.type!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Type', meeting.type!),
        const SizedBox(height: 8),
      ]);
    }

    // Date
    details.addAll([
      _buildDetailRow('Date', _formatDate(meeting.date)),
      const SizedBox(height: 8),
    ]);

    // Location
    if (meeting.location != null && meeting.location!.isNotEmpty) {
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
                text: meeting.location!,
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
    if (meeting.rate != null && meeting.rate!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Rate', '\$${meeting.rate}'),
        const SizedBox(height: 8),
      ]);
    }

    // Agent Information
    if (meeting.bookingAgent != null && meeting.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', meeting.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    // Status
    details.addAll([
      _buildDetailRow('Status', (meeting.status ?? 'Unknown').toUpperCase()),
      const SizedBox(height: 8),
    ]);

    // Notes
    if (meeting.notes != null && meeting.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', meeting.notes!),
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

  void _editMeeting(Meeting meeting) async {
    final result = await Navigator.pushNamed(
      context,
      '/new-meeting',
      arguments: meeting,
    );
    if (result == true && mounted) {
      _loadMeetings();
    }
  }

  void _showDeleteConfirmation(Meeting meeting) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Meeting'),
          content:
              Text('Are you sure you want to delete "${meeting.clientName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteMeeting(meeting);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMeeting(Meeting meeting) async {
    try {
      final success = await MeetingsService.delete(meeting.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Meeting deleted successfully'
                : 'Failed to delete meeting'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          _loadMeetings();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/meetings',
      title: 'Meetings',
      actions: [
        // Export button
        ExportButton(
          type: ExportType.meetings,
          data: _filteredMeetings,
          customFilename:
              'meetings_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
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
            final result = await Navigator.pushNamed(context, '/new-meeting');
            if (result == true && mounted) {
              _loadMeetings();
            }
          },
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }
}
