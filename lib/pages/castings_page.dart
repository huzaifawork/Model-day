import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/casting.dart';
import '../models/agent.dart';
import '../providers/castings_provider.dart';
import '../services/agents_service.dart';
import '../widgets/app_layout.dart';
import '../widgets/ui/button.dart';
import '../widgets/ui/input.dart' as ui;
import '../widgets/export_button.dart';
import '../widgets/clickable_contact_info.dart';
import '../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class CastingsPage extends StatefulWidget {
  const CastingsPage({super.key});

  @override
  State<CastingsPage> createState() => _CastingsPageState();
}

class _CastingsPageState extends State<CastingsPage> {
  final _searchController = TextEditingController();
  Map<String, Agent> _agentCache =
      {}; // Cache for agent ID -> Agent object mapping

  @override
  void initState() {
    super.initState();
    _loadAgents();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CastingsProvider>().loadCastings();
    });
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

  Future<void> _deleteCasting(String id) async {
    final provider = context.read<CastingsProvider>();
    final success = await provider.deleteCasting(id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Casting deleted successfully'
              : provider.error ?? 'Error deleting casting'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Widget _buildCastingCard(Casting casting) {
    return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () => _showCastingPreview(casting),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            casting.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            casting.description ?? 'No description',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: casting.status == 'confirmed'
                            ? Colors.green[100]
                            : casting.status == 'pending'
                                ? Colors.orange[100]
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        casting.status.toUpperCase(),
                        style: TextStyle(
                          color: casting.status == 'confirmed'
                              ? Colors.green[800]
                              : casting.status == 'pending'
                                  ? Colors.orange[800]
                                  : Colors.grey[800],
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, yyyy').format(casting.date),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (casting.rate != null) ...[
                      const SizedBox(width: 24),
                      const Icon(Icons.attach_money,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        '${casting.currency ?? 'USD'} ${casting.rate!.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                if (casting.location != null)
                  ClickableContactInfo(
                    text: casting.location!,
                    type: ContactType.location,
                    iconColor: Colors.grey,
                    textColor: Colors.blue[400],
                    fontSize: 14,
                  )
                else
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Text(
                        'No location',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Text('Requirements',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  casting.requirements ?? 'No requirements specified',
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (casting.images != null && casting.images!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Images', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: casting.images!.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            casting.images![index],
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 100,
                                width: 100,
                                color: Colors.grey[200],
                                child: const Icon(Icons.error),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Button(
                      variant: ButtonVariant.outline,
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/new-casting',
                          arguments: casting,
                        );
                        if (result == true && mounted) {
                          context.read<CastingsProvider>().loadCastings();
                        }
                      },
                      text: 'Edit',
                    ),
                    const SizedBox(width: 8),
                    Button(
                      variant: ButtonVariant.destructive,
                      onPressed: () => _deleteCasting(casting.id),
                      text: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
  }

  void _showCastingPreview(Casting casting) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          casting.title,
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
              children: _buildCastingDetails(casting),
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
              final navigator = Navigator.of(context);
              final castingsProvider = context.read<CastingsProvider>();
              navigator.pushNamed(
                '/new-casting',
                arguments: casting,
              ).then((_) {
                if (mounted) {
                  castingsProvider.loadCastings();
                }
              });
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

  List<Widget> _buildCastingDetails(Casting casting) {
    List<Widget> details = [];

    // Parse description to extract individual fields
    Map<String, String> parsedData = _parseDescriptionData(casting.description);

    // Job Type (from description)
    if (parsedData['jobType'] != null) {
      details.addAll([
        _buildDetailRow('Description', parsedData['jobType']!),
        const SizedBox(height: 8),
      ]);
    }

    // Time (combine start and end time from description)
    String? startTime = parsedData['startTime'];
    String? endTime = parsedData['endTime'];

    if (startTime != null && endTime != null) {
      details.addAll([
        _buildDetailRow('Time', '$startTime - $endTime'),
        const SizedBox(height: 8),
      ]);
    } else if (startTime != null) {
      details.addAll([
        _buildDetailRow('Start Time', startTime),
        const SizedBox(height: 8),
      ]);
    } else if (endTime != null) {
      details.addAll([
        _buildDetailRow('End Time', endTime),
        const SizedBox(height: 8),
      ]);
    }

    // Agent Information (from description)
    String? agentId = parsedData['agentId'];
    if (agentId != null) {
      details.addAll([
        _buildAgentRow('Agent', agentId),
        const SizedBox(height: 8),
      ]);
    }

    // Notes (from description)
    if (parsedData['notes'] != null) {
      details.addAll([
        _buildDetailRow('Notes', parsedData['notes']!),
        const SizedBox(height: 8),
      ]);
    }

    // Date
    details.addAll([
      _buildDetailRow(
          'Date', DateFormat('EEEE, MMMM d, yyyy').format(casting.date)),
      const SizedBox(height: 8),
    ]);

    // Location
    if (casting.location != null && casting.location!.isNotEmpty) {
      details.addAll([
        _buildLocationRow('Location', casting.location!),
        const SizedBox(height: 8),
      ]);
    }

    // Status
    details.addAll([
      _buildDetailRow('Status', casting.status.toUpperCase()),
      const SizedBox(height: 8),
    ]);

    return details;
  }

  Map<String, String> _parseDescriptionData(String? description) {
    Map<String, String> data = {};

    if (description == null || description.isEmpty) {
      return data;
    }

    final lines = description.split('\n');
    for (String line in lines) {
      line = line.trim();
      if (line.startsWith('Job Type: ')) {
        data['jobType'] = line.substring('Job Type: '.length);
      } else if (line.startsWith('Start Time: ')) {
        data['startTime'] = line.substring('Start Time: '.length);
      } else if (line.startsWith('End Time: ')) {
        data['endTime'] = line.substring('End Time: '.length);
      } else if (line.startsWith('Agent ID: ')) {
        data['agentId'] = line.substring('Agent ID: '.length);
      } else if (line.startsWith('Notes: ')) {
        data['notes'] = line.substring('Notes: '.length);
      }
    }

    return data;
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

  Widget _buildLocationRow(String label, String location) {
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
            text: location,
            type: ContactType.location,
            showIcon: false,
            textColor: Colors.blue[400],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAgentRow(String label, String agentId) {
    // Get agent from cache
    final agent = _agentCache[agentId];

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

  @override
  Widget build(BuildContext context) {
    return Consumer<CastingsProvider>(
      builder: (context, provider, child) {
        return AppLayout(
          currentPage: '/castings',
          title: 'Castings',
          actions: [
            // Export button
            ExportButton(
              type: ExportType.castings,
              data: provider.filteredCastings,
              customFilename:
                  'castings_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result =
                    await Navigator.pushNamed(context, '/new-casting');
                if (result == true) {
                  provider.loadCastings();
                }
              },
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ui.Input(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search castings...',
                  controller: _searchController,
                  onChanged: (value) => provider.setSearchTerm(value),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: provider.refresh,
                    child: provider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : provider.error != null
                            ? Center(child: Text(provider.error!))
                            : provider.filteredCastings.isEmpty
                                ? const Center(child: Text('No castings found'))
                                : ListView.builder(
                                    itemCount: provider.filteredCastings.length,
                                    itemBuilder: (context, index) =>
                                        _buildCastingCard(
                                            provider.filteredCastings[index]),
                                  ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
