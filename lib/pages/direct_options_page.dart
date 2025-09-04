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

class DirectOptionsPage extends StatefulWidget {
  const DirectOptionsPage({super.key});

  @override
  State<DirectOptionsPage> createState() => _DirectOptionsPageState();
}

class _DirectOptionsPageState extends State<DirectOptionsPage> {
  List<Event> _options = [];
  List<Event> _filteredOptions = [];
  bool _isLoading = true;
  bool _isGridView = true;
  String _searchQuery = '';
  String _sortOrder = 'date-desc';
  final TextEditingController _searchController = TextEditingController();
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      debugPrint(
          '🔍 DirectOptionsPage._loadOptions() - Loading direct options');

      // Get all events and filter for direct option types
      final allEvents = await _eventsService.getEvents();
      final options = allEvents
          .where((event) => event.type == EventType.directOption)
          .toList();

      debugPrint(
          '✅ DirectOptionsPage._loadOptions() - Found ${options.length} direct options');

      // Sort by date (newest first)
      options.sort((a, b) {
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return b.date!.compareTo(a.date!);
      });

      if (!mounted) return;
      setState(() {
        _options = options;
        _filteredOptions = options;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('❌ DirectOptionsPage._loadOptions() - Error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading options: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {
      _filteredOptions = _options.where((option) {
        final searchLower = _searchQuery.toLowerCase();
        return (option.clientName?.toLowerCase().contains(searchLower) ??
                false) ||
            (option.additionalData?['option_type']
                    ?.toLowerCase()
                    .contains(searchLower) ??
                false) ||
            (option.location?.toLowerCase().contains(searchLower) ?? false);
      }).toList();

      // Apply sorting
      _filteredOptions.sort((a, b) {
        switch (_sortOrder) {
          case 'date-asc':
            return (a.date ?? DateTime(1900))
                .compareTo(b.date ?? DateTime(1900));
          case 'date-desc':
            return (b.date ?? DateTime(1900))
                .compareTo(a.date ?? DateTime(1900));
          case 'client-asc':
            return (a.clientName ?? '').compareTo(b.clientName ?? '');
          case 'client-desc':
            return (b.clientName ?? '').compareTo(a.clientName ?? '');
          default:
            return (b.date ?? DateTime(1900))
                .compareTo(a.date ?? DateTime(1900));
        }
      });
    });
  }

  void _onSearchChanged(String query) {
    if (!mounted) return;
    setState(() => _searchQuery = query);
    _applyFilters();
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

  double _calculateFinalAmount(Event option) {
    final baseAmount = option.dayRate ?? 0;
    final extraHours = double.tryParse(
            option.additionalData?['extra_hours']?.toString() ?? '0') ??
        0;
    final additionalFees = double.tryParse(
            option.additionalData?['additional_fees']?.toString() ?? '0') ??
        0;
    final agencyFeePercentage = double.tryParse(
            option.additionalData?['agency_fee']?.toString() ?? '0') ??
        0;
    final taxPercentage = double.tryParse(
            option.additionalData?['tax_percentage']?.toString() ?? '0') ??
        0;

    final extraHoursAmount = extraHours * (baseAmount / 8);
    final totalBeforeDeductions =
        baseAmount + extraHoursAmount + additionalFees;
    final agencyFee = (totalBeforeDeductions * agencyFeePercentage) / 100;
    final taxAmount = (totalBeforeDeductions * taxPercentage) / 100;
    final finalAmount = totalBeforeDeductions - agencyFee - taxAmount;

    return finalAmount;
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildSearchAndFilters(),
        const SizedBox(height: 16),
        Expanded(
          child: _filteredOptions.isEmpty
              ? _buildEmptyState()
              : _isGridView
                  ? _buildGridView()
                  : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search options...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              if (mounted) {
                setState(() => _sortOrder = value);
                _applyFilters();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'date-desc', child: Text('Newest First')),
              const PopupMenuItem(
                  value: 'date-asc', child: Text('Oldest First')),
              const PopupMenuItem(
                  value: 'client-asc', child: Text('Client (A-Z)')),
              const PopupMenuItem(
                  value: 'client-desc', child: Text('Client (Z-A)')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_available, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No direct options found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first direct option to get started',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result =
                  await Navigator.pushNamed(context, '/new-direct-option');
              if (result == true && mounted) {
                _loadOptions();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add New Direct Option'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        double childAspectRatio =
            0.75; // Even taller cards for mobile to accommodate files

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
          itemCount: _filteredOptions.length,
          itemBuilder: (context, index) =>
              _buildOptionCard(_filteredOptions[index]),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredOptions.length,
      itemBuilder: (context, index) =>
          _buildOptionListItem(_filteredOptions[index]),
    );
  }

  Widget _buildOptionCard(Event option) {
    final finalAmount = _calculateFinalAmount(option);
    final optionType = option.additionalData?['option_type'] ?? 'No Type';
    final status = option.status?.toString().split('.').last ?? 'unknown';
    final paymentStatus =
        option.paymentStatus?.toString().split('.').last ?? 'unknown';

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showOptionDetails(option),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      option.clientName ?? 'No Client',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(status),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editOption(option);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(option);
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
              Text(
                optionType,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              if (option.date != null)
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, yyyy').format(option.date!),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              if (option.location != null)
                ClickableContactInfo(
                  text: option.location!,
                  type: ContactType.location,
                  iconColor: Colors.grey,
                  textColor: Colors.blue[400],
                  fontSize: 14,
                ),

              // File attachments section
              Builder(
                builder: (context) {
                  // Check for files in multiple possible locations
                  Map<String, dynamic>? fileData;

                  // First check option.files
                  if (option.files != null && option.files!.isNotEmpty) {
                    fileData = option.files;
                  }
                  // Then check option.additionalData.file_data
                  else if (option.additionalData != null &&
                      option.additionalData!.containsKey('file_data') &&
                      option.additionalData!['file_data']
                          is Map<String, dynamic>) {
                    fileData = option.additionalData!['file_data']
                        as Map<String, dynamic>;
                  }

                  // Check if we have valid file data
                  if (fileData != null &&
                      fileData.containsKey('files') &&
                      fileData['files'] is List &&
                      (fileData['files'] as List).isNotEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final filesList = fileData!['files'] as List;

                        // For very small cards, show just a compact indicator
                        if (constraints.maxHeight < 250) {
                          return Column(
                            children: [
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.grey[800]?.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.attach_file,
                                        size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${filesList.length} file${filesList.length > 1 ? 's' : ''}',
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        // For larger cards, show the full FilePreviewWidget
                        return Column(
                          children: [
                            const SizedBox(height: 6),
                            FilePreviewWidget(
                              fileData: fileData,
                              showTitle: false, // Hide title to save space
                              maxFilesToShow: 1,
                            ),
                          ],
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_getCurrencySymbol(option.currency)}${finalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  _buildPaymentStatusChip(paymentStatus),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionListItem(Event option) {
    final finalAmount = _calculateFinalAmount(option);
    final optionType = option.additionalData?['option_type'] ?? 'No Type';
    final status = option.status?.toString().split('.').last ?? 'unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(option.clientName ?? 'No Client'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(optionType),
            if (option.date != null)
              Text(DateFormat('MMM d, yyyy').format(option.date!)),
            // File attachments indicator
            Builder(
              builder: (context) {
                // Check for files in multiple possible locations
                Map<String, dynamic>? fileData;

                // First check option.files
                if (option.files != null && option.files!.isNotEmpty) {
                  fileData = option.files;
                }
                // Then check option.additionalData.file_data
                else if (option.additionalData != null &&
                    option.additionalData!.containsKey('file_data') &&
                    option.additionalData!['file_data']
                        is Map<String, dynamic>) {
                  fileData = option.additionalData!['file_data']
                      as Map<String, dynamic>;
                }

                // Check if we have valid file data
                if (fileData != null &&
                    fileData.containsKey('files') &&
                    fileData['files'] is List &&
                    (fileData['files'] as List).isNotEmpty) {
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
                            '${filesList.length} files',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_getCurrencySymbol(option.currency)}${finalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildStatusChip(status),
          ],
        ),
        onTap: () => Navigator.pushNamed(
          context,
          '/new-direct-option',
          arguments: {'event': option},
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    switch (status) {
      case 'option':
        color = Colors.blue;
        break;
      case 'confirmed':
        color = Colors.green;
        break;
      case 'canceled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        status?.toUpperCase() ?? 'UNKNOWN',
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildPaymentStatusChip(String? paymentStatus) {
    Color color;
    switch (paymentStatus) {
      case 'paid':
        color = Colors.green;
        break;
      case 'partial':
        color = Colors.orange;
        break;
      case 'unpaid':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Chip(
      label: Text(
        paymentStatus?.toUpperCase() ?? 'UNKNOWN',
        style: const TextStyle(fontSize: 10, color: Colors.white),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  void _showOptionDetails(Event option) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            option.clientName ?? 'Direct Option Details',
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
                children: _buildDirectOptionDetails(option),
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
                _editOption(option);
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

  List<Widget> _buildDirectOptionDetails(Event option) {
    List<Widget> details = [];

    // Event Type
    details.addAll([
      _buildDetailRow('Type', 'Direct Option'),
      const SizedBox(height: 8),
    ]);

    // Option Type
    final optionType = option.additionalData?['option_type'];
    if (optionType != null) {
      details.addAll([
        _buildDetailRow('Option Type', optionType.toString()),
        const SizedBox(height: 8),
      ]);
    }

    // Date and Time
    if (option.date != null) {
      details.addAll([
        _buildDetailRow(
            'Date', DateFormat('EEEE, MMMM d, yyyy').format(option.date!)),
        const SizedBox(height: 8),
      ]);
      if (option.startTime != null) {
        details.addAll([
          _buildDetailRow('Time',
              '${option.startTime}${option.endTime != null ? ' - ${option.endTime}' : ''}'),
          const SizedBox(height: 8),
        ]);
      }
    }

    // Location
    if (option.location != null && option.location!.isNotEmpty) {
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
                text: option.location!,
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

    // Day Rate and Usage Rate
    if (option.dayRate != null && option.dayRate! > 0) {
      details.addAll([
        _buildDetailRow('Day Rate',
            '${_getCurrencySymbol(option.currency)}${option.dayRate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    if (option.usageRate != null && option.usageRate! > 0) {
      details.addAll([
        _buildDetailRow('Usage Rate',
            '${_getCurrencySymbol(option.currency)}${option.usageRate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    // Agent Information
    if (option.agentId != null && option.agentId!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', option.agentId!),
        const SizedBox(height: 8),
      ]);
    }

    // Status
    final status = option.status?.toString().split('.').last ?? 'Unknown';
    details.addAll([
      _buildDetailRow('Status', status.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    // Payment Status
    if (option.paymentStatus != null) {
      details.addAll([
        _buildDetailRow('Payment',
            option.paymentStatus.toString().split('.').last.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    // Notes
    if (option.notes != null && option.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', option.notes!),
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

  void _editOption(Event option) async {
    final result = await Navigator.pushNamed(
      context,
      '/new-direct-option',
      arguments: {'event': option},
    );
    if (result == true && mounted) {
      _loadOptions();
    }
  }

  void _showDeleteConfirmation(Event option) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Option'),
          content: Text(
              'Are you sure you want to delete "${option.clientName ?? 'this option'}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteOption(option);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteOption(Event option) async {
    if (option.id == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final success = await _eventsService.deleteEvent(option.id!);
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Option deleted successfully'
                : 'Failed to delete option'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          _loadOptions();
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting option: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/direct-options',
      title: 'Direct Options',
      actions: [
        // Export button
        ExportButton(
          type: ExportType.events,
          data: _options,
          customFilename:
              'direct_options_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          onPressed: () {
            if (mounted) setState(() => _isGridView = !_isGridView);
          },
          tooltip: 'Toggle View',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadOptions,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => Navigator.pushNamed(context, '/new-direct-option'),
          tooltip: 'Add Direct Option',
        ),
      ],
      child: _isLoading ? _buildLoadingWidget() : _buildContent(),
    );
  }
}
