import 'package:flutter/material.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:new_flutter/models/event.dart';
import 'package:new_flutter/models/agent.dart';
import 'package:new_flutter/services/events_service.dart';
import 'package:new_flutter/services/agents_service.dart';
import 'package:new_flutter/widgets/export_button.dart';
import 'package:new_flutter/widgets/clickable_contact_info.dart';
import 'package:new_flutter/widgets/file_preview_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class OptionsListPage extends StatefulWidget {
  const OptionsListPage({super.key});

  @override
  State<OptionsListPage> createState() => _OptionsListPageState();
}

class _OptionsListPageState extends State<OptionsListPage> {
  List<Event> _options = [];
  bool _isLoading = true;
  String? _error;
  final EventsService _eventsService = EventsService();
  Map<String, Agent> _agentCache =
      {}; // Cache for agent ID -> Agent object mapping

  @override
  void initState() {
    super.initState();
    _loadAgents();
    _loadOptions();
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

  Future<void> _loadOptions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get all events and filter for option types (excluding direct options and transferred options)
      final allEvents = await _eventsService.getEvents();
      final options = allEvents
          .where((event) => 
              event.type == EventType.option && 
              event.optionStatus != OptionStatus.transferredToJob)
          .toList();

      // Sort by date (newest first)
      options.sort((a, b) {
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return b.date!.compareTo(a.date!);
      });

      if (mounted) {
        setState(() {
          _options = options;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading options: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteOption(String optionId) async {
    try {
      final success = await _eventsService.deleteEvent(optionId);
      if (success) {
        await _loadOptions(); // Refresh the list

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Option deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to delete option');
      }
    } catch (e) {
      debugPrint('Error deleting option: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting option: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Event option) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Option',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${option.clientName ?? 'this option'}"?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (option.id != null) {
                _deleteOption(option.id!);
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(Event option, int index) {
    return GestureDetector(
      onTap: () => _showEventPreview(option),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[800]!.withValues(alpha: 0.8),
              Colors.grey[900]!.withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    option.type == EventType.directOption
                        ? Icons.arrow_forward
                        : Icons.schedule,
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
                        option.clientName ?? 'No client name',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.type.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: Colors.grey[800],
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        Navigator.pushNamed(
                          context,
                          '/new-option',
                          arguments: {'event': option},
                        ).then((_) => _loadOptions());
                        break;
                      case 'delete':
                        _showDeleteConfirmation(option);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Option details
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  option.date != null
                      ? DateFormat('MMM d, yyyy').format(option.date!)
                      : 'No date set',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(width: 24),
                Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 8),
                Text(
                  option.startTime ?? 'No time set',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),

            if (option.location != null) ...[
              const SizedBox(height: 8),
              ClickableContactInfo(
                text: option.location!,
                type: ContactType.location,
                iconColor: Colors.grey[400],
                textColor: Colors.blue[400],
                fontSize: 14,
              ),
            ],

            if (option.dayRate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Text(
                    '${option.dayRate} ${option.currency ?? 'USD'}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            ],

            // Show uploaded files if any
            if (option.files != null ||
                (option.additionalData != null &&
                    option.additionalData!.containsKey('file_data'))) ...[
              const SizedBox(height: 16),
              FilePreviewWidget(
                fileData: option.files ?? option.additionalData?['file_data'],
                maxFilesToShow: 3,
              ),
            ],

            const SizedBox(height: 16),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(option),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _getStatusText(option),
                style: TextStyle(
                  color: _getStatusTextColor(option),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 100))
        .fadeIn(duration: 600.ms)
        .slideY(begin: 0.2);
  }

  Color _getStatusColor(Event option) {
    // Use optionStatus for options, fallback to general status
    final status = option.optionStatus ?? option.status;
    if (status == null) return Colors.grey.withValues(alpha: 0.2);

    switch (status.toString().split('.').last.toLowerCase()) {
      case 'confirmed':
      case 'completed':
        return Colors.green.withValues(alpha: 0.2);
      case 'pending':
      case 'scheduled':
        return Colors.orange.withValues(alpha: 0.2);
      case 'canceled':
      case 'declined':
      case 'clientcanceled':
      case 'ideclined':
        return Colors.red.withValues(alpha: 0.2);
      case 'postponed':
        return Colors.blue.withValues(alpha: 0.2);
      case 'transferredtojob':
        return Colors.purple.withValues(alpha: 0.2);
      default:
        return Colors.grey.withValues(alpha: 0.2);
    }
  }

  Color _getStatusTextColor(Event option) {
    final status = option.optionStatus ?? option.status;
    if (status == null) return Colors.grey;

    switch (status.toString().split('.').last.toLowerCase()) {
      case 'confirmed':
      case 'completed':
        return Colors.green;
      case 'pending':
      case 'scheduled':
        return Colors.orange;
      case 'canceled':
      case 'declined':
      case 'clientcanceled':
      case 'ideclined':
        return Colors.red;
      case 'postponed':
        return Colors.blue;
      case 'transferredtojob':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(Event option) {
    // Use optionStatus for options, fallback to general status
    final status = option.optionStatus ?? option.status;
    if (status == null) return 'Unknown';

    // Convert enum to display text
    final statusString = status.toString().split('.').last;
    switch (statusString.toLowerCase()) {
      case 'clientcanceled':
        return 'Client Canceled';
      case 'ideclined':
        return 'I Declined';
      case 'transferredtojob':
        return 'Transferred to Job';
      default:
        return statusString[0].toUpperCase() + statusString.substring(1);
    }
  }

  void _showEventPreview(Event option) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          option.clientName ?? 'Option Details',
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
              children: _buildEventDetails(option),
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
              Navigator.pushNamed(
                context,
                '/new-option',
                arguments: {'event': option},
              ).then((_) => _loadOptions());
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

    // Event Type
    details.addAll([
      _buildDetailRow('Type', 'Option'),
      const SizedBox(height: 8),
    ]);

    // Date and Time
    if (event.date != null) {
      details.addAll([
        _buildDetailRow(
            'Date', DateFormat('EEEE, MMMM d, yyyy').format(event.date!)),
        const SizedBox(height: 8),
      ]);
      if (event.startTime != null) {
        details.addAll([
          _buildDetailRow('Time',
              '${event.startTime}${event.endTime != null ? ' - ${event.endTime}' : ''}'),
          const SizedBox(height: 8),
        ]);
      }
    }

    // Location
    if (event.location != null && event.location!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Location', event.location!),
        const SizedBox(height: 8),
      ]);
    }

    // Day Rate and Usage Rate
    if (event.dayRate != null && event.dayRate! > 0) {
      details.addAll([
        _buildDetailRow('Day Rate',
            '${event.currency ?? 'USD'} ${event.dayRate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (event.usageRate != null && event.usageRate! > 0) {
      details.addAll([
        _buildDetailRow('Usage Rate',
            '${event.currency ?? 'USD'} ${event.usageRate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    // Agent Information
    if (event.agentId != null && event.agentId!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', event.agentId!),
        const SizedBox(height: 8),
      ]);
    }

    // Status
    if (event.optionStatus != null || event.status != null) {
      details.addAll([
        _buildDetailRow('Status', _getStatusText(event)),
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

    // Notes
    if (event.notes != null && event.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', event.notes!),
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

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/options',
      title: 'Options',
      actions: [
        // Export button
        ExportButton(
          type: ExportType.events,
          data: _options,
          customFilename:
              'options_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: () {
            Navigator.pushNamed(context, '/new-option')
                .then((_) => _loadOptions());
          },
          tooltip: 'Add Option',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadOptions,
          tooltip: 'Refresh',
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading options',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadOptions,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _options.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No options yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first option to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/new-option')
                                  .then((_) => _loadOptions());
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Option'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.goldColor,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(0),
                      itemCount: _options.length,
                      itemBuilder: (context, index) {
                        return _buildOptionCard(_options[index], index);
                      },
                    ),
    );
  }
}
