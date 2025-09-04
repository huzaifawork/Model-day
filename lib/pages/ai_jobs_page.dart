import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/widgets/export_button.dart';
import 'package:new_flutter/widgets/clickable_contact_info.dart';
import 'package:new_flutter/models/ai_job.dart';
import 'package:new_flutter/models/agent.dart';
import 'package:new_flutter/services/ai_jobs_service.dart';
import 'package:new_flutter/services/agents_service.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AiJobsPage extends StatefulWidget {
  const AiJobsPage({super.key});

  @override
  State<AiJobsPage> createState() => _AiJobsPageState();
}

class _AiJobsPageState extends State<AiJobsPage> {
  List<AiJob> _aiJobs = [];
  List<AiJob> _filteredAIJobs = [];
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
    _loadAIJobs();
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

  Future<void> _loadAIJobs() async {
    if (!mounted) return;
    debugPrint('🤖 AiJobsPage._loadAIJobs() - Starting to load AI jobs...');
    setState(() => _isLoading = true);
    try {
      final aiJobs = await AiJobsService.list();
      debugPrint(
          '🤖 AiJobsPage._loadAIJobs() - Loaded ${aiJobs.length} AI jobs');
      if (!mounted) return;
      setState(() {
        _aiJobs = aiJobs;
        _filteredAIJobs = aiJobs;
        _isLoading = false;
      });
      _applyFilters();
      debugPrint(
          '🤖 AiJobsPage._loadAIJobs() - Applied filters, showing ${_filteredAIJobs.length} AI jobs');
    } catch (e) {
      debugPrint('❌ AiJobsPage._loadAIJobs() - Error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading AI jobs: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {
      _filteredAIJobs = _aiJobs.where((aiJob) {
        final searchLower = _searchQuery.toLowerCase();
        return aiJob.clientName.toLowerCase().contains(searchLower) ||
            (aiJob.type?.toLowerCase().contains(searchLower) ?? false) ||
            (aiJob.description?.toLowerCase().contains(searchLower) ?? false);
      }).toList();

      _filteredAIJobs.sort((a, b) {
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'No Date';
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildContent() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search AI jobs...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: _filteredAIJobs.isEmpty
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
          const Icon(Icons.smart_toy, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No AI jobs found',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.pushNamed(context, '/new-ai-job');
              if (result == true && mounted) {
                _loadAIJobs();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add New AI Job'),
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
          itemCount: _filteredAIJobs.length,
          itemBuilder: (context, index) =>
              _buildAIJobCard(_filteredAIJobs[index]),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredAIJobs.length,
      itemBuilder: (context, index) =>
          _buildAIJobListItem(_filteredAIJobs[index]),
    );
  }

  Widget _buildAIJobCard(AiJob aiJob) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showAIJobDetails(aiJob),
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
                      aiJob.clientName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(aiJob.status),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editAIJob(aiJob);
                      } else if (value == 'delete') {
                        _showDeleteConfirmation(aiJob);
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
              Text(aiJob.type ?? 'No Type',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(_formatDate(aiJob.date),
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const Spacer(),
              if (aiJob.rate != null)
                Text('\$${aiJob.rate!.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAIJobListItem(AiJob aiJob) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(aiJob.clientName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(aiJob.type ?? 'No Type'),
            Text(_formatDate(aiJob.date)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (aiJob.rate != null)
                  Text('\$${aiJob.rate!.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                _buildStatusChip(aiJob.status),
              ],
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editAIJob(aiJob);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(aiJob);
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
        onTap: () => _showAIJobDetails(aiJob),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'in_progress':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.green;
        break;
      case 'canceled':
        color = Colors.red;
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

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: '/ai-jobs',
      title: 'AI Jobs',
      actions: [
        // Export button
        ExportButton(
          type: ExportType.jobs,
          data: _filteredAIJobs,
          customFilename:
              'ai_jobs_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
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
            final result = await Navigator.pushNamed(context, '/new-ai-job');
            if (result == true && mounted) {
              _loadAIJobs();
            }
          },
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  void _showAIJobDetails(AiJob aiJob) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            aiJob.clientName,
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
                children: _buildAIJobDetails(aiJob),
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
                _editAIJob(aiJob);
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

  List<Widget> _buildAIJobDetails(AiJob aiJob) {
    List<Widget> details = [];

    // Type
    if (aiJob.type != null && aiJob.type!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Type', aiJob.type!),
        const SizedBox(height: 8),
      ]);
    }

    // Date
    details.addAll([
      _buildDetailRow('Date', _formatDate(aiJob.date)),
      const SizedBox(height: 8),
    ]);

    // Location
    if (aiJob.location != null && aiJob.location!.isNotEmpty) {
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
                text: aiJob.location!,
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
    if (aiJob.rate != null && aiJob.rate! > 0) {
      details.addAll([
        _buildDetailRow('Rate', '\$${aiJob.rate!.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    // Agent Information
    if (aiJob.bookingAgent != null && aiJob.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', aiJob.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    // Status
    details.addAll([
      _buildDetailRow('Status', (aiJob.status ?? 'Unknown').toUpperCase()),
      const SizedBox(height: 8),
    ]);

    // Description
    if (aiJob.description != null && aiJob.description!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Description', aiJob.description!),
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

  void _editAIJob(AiJob aiJob) async {
    final result = await Navigator.pushNamed(
      context,
      '/new-ai-job',
      arguments: aiJob,
    );
    if (result == true && mounted) {
      _loadAIJobs();
    }
  }

  void _showDeleteConfirmation(AiJob aiJob) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete AI Job'),
          content:
              Text('Are you sure you want to delete "${aiJob.clientName}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteAIJob(aiJob);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAIJob(AiJob aiJob) async {
    if (aiJob.id == null) return;

    try {
      final success = await AiJobsService.delete(aiJob.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'AI Job deleted successfully'
                : 'Failed to delete AI Job'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) {
          _loadAIJobs();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting AI Job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
