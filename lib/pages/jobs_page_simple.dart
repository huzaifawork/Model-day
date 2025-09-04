import 'package:flutter/material.dart';
import 'package:new_flutter/models/job.dart';
import 'package:new_flutter/models/agent.dart';
import 'package:new_flutter/services/jobs_service.dart';
import 'package:new_flutter/services/agents_service.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/widgets/clickable_contact_info.dart';
import 'package:new_flutter/widgets/ui/input.dart' as ui;
import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/export_button.dart';
import 'package:new_flutter/widgets/file_preview_widget.dart';
import 'package:new_flutter/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class JobsPageSimple extends StatefulWidget {
  const JobsPageSimple({super.key});

  @override
  State<JobsPageSimple> createState() => _JobsPageSimpleState();
}

class _JobsPageSimpleState extends State<JobsPageSimple> {
  List<Job> jobs = [];
  bool isLoading = true;
  String? error;
  String _searchTerm = '';
  final _searchController = TextEditingController();
  Map<String, Agent> _agentCache =
      {}; // Cache for agent ID -> Agent object mapping

  @override
  void initState() {
    super.initState();
    _loadAgents();
    _loadJobs();
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

  Future<void> _loadJobs() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final loadedJobs = await JobsService.list();
      setState(() {
        jobs = loadedJobs;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load jobs: $e';
        isLoading = false;
      });
    }
  }

  String _formatDateRange(Job job) {
    try {
      final startDate = DateTime.parse(job.date);
      String dateText = DateFormat('MMM d, yyyy').format(startDate);

      if (job.isMultiDay && job.endDate != null && job.endDate!.isNotEmpty) {
        final endDate = DateTime.parse(job.endDate!);
        dateText += ' - ${DateFormat('MMM d, yyyy').format(endDate)}';
      }

      return dateText;
    } catch (e) {
      return job.date;
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context, Job job) async {
    if (!mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Job',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete the job for "${job.clientName}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      try {
        final success = await JobsService.delete(job.id!);
        if (success) {
          await _loadJobs();
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Job deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Failed to delete job');
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error deleting job: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<Job> get _filteredJobs {
    if (_searchTerm.isEmpty) return jobs;
    final term = _searchTerm.toLowerCase();
    return jobs.where((job) {
      return job.clientName.toLowerCase().contains(term) ||
          job.type.toLowerCase().contains(term) ||
          job.location.toLowerCase().contains(term);
    }).toList();
  }

  Widget _buildJobCard(Job job) {
    return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () => _showJobPreview(job),
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
                            job.clientName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            job.type,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        ],
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
                      _formatDateRange(job),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (job.time != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        job.time!,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                ClickableContactInfo(
                  text: job.location,
                  type: ContactType.location,
                  iconColor: Colors.grey,
                  textColor: Colors.blue[400],
                  fontSize: 14,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${job.currency ?? 'USD'} ${job.rate.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                if (job.notes != null) ...[
                  const SizedBox(height: 16),
                  Text('Notes', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    job.notes!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // File attachments section
                if (job.fileData != null &&
                    job.fileData!.containsKey('files') &&
                    job.fileData!['files'] is List &&
                    (job.fileData!['files'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FilePreviewWidget(
                    fileData: job.fileData,
                    showTitle: true,
                    maxFilesToShow: 3,
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Button(
                        variant: ButtonVariant.outline,
                        onPressed: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            '/new-job',
                            arguments: job,
                          );
                          if (result == true) {
                            _loadJobs(); // Refresh the jobs list
                          }
                        },
                        text: 'Edit',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Button(
                        variant: ButtonVariant.destructive,
                        onPressed: () => _showDeleteConfirmation(context, job),
                        text: 'Delete',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
  }

  void _showJobPreview(Job job) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          job.clientName,
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
              children: _buildJobDetails(job),
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
                '/new-job',
                arguments: job,
              ).then((_) => _loadJobs());
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

  List<Widget> _buildJobDetails(Job job) {
    List<Widget> details = [];

    // Job Type
    details.addAll([
      _buildDetailRow('Type', job.type),
      const SizedBox(height: 8),
    ]);

    // Date and Time
    details.addAll([
      _buildDetailRow('Date', _formatDateRange(job)),
      const SizedBox(height: 8),
    ]);

    if (job.time != null) {
      details.addAll([
        _buildDetailRow('Time',
            '${job.time}${job.endTime != null ? ' - ${job.endTime}' : ''}'),
        const SizedBox(height: 8),
      ]);
    }

    // Location
    if (job.location.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Location', job.location),
        const SizedBox(height: 8),
      ]);
    }

    // Rate
    if (job.rate > 0) {
      details.addAll([
        _buildDetailRow(
            'Rate', '${job.currency ?? 'USD'} ${job.rate.toStringAsFixed(2)}'),
        const SizedBox(height: 8),
      ]);
    }

    // Extra Hours
    if (job.extraHours != null && job.extraHours! > 0) {
      details.addAll([
        _buildDetailRow(
            'Extra Hours', '${job.extraHours!.toStringAsFixed(1)} hours'),
        const SizedBox(height: 8),
      ]);
    }

    // Booking Agent
    if (job.bookingAgent != null && job.bookingAgent!.isNotEmpty) {
      details.addAll([
        _buildAgentRow('Agent', job.bookingAgent!),
        const SizedBox(height: 8),
      ]);
    }

    // Status
    if (job.status != null) {
      details.addAll([
        _buildDetailRow('Status', job.status!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    // Payment Status
    if (job.paymentStatus != null) {
      details.addAll([
        _buildDetailRow('Payment', job.paymentStatus!.toUpperCase()),
        const SizedBox(height: 8),
      ]);
    }

    // Requirements
    if (job.requirements != null && job.requirements!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Requirements', job.requirements!),
        const SizedBox(height: 8),
      ]);
    }

    // Notes
    if (job.notes != null && job.notes!.isNotEmpty) {
      details.addAll([
        _buildDetailRow('Notes', job.notes!),
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

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: 'Jobs',
      title: 'Jobs',
      actions: [
        // Export button
        ExportButton(
          type: ExportType.jobs,
          data: _filteredJobs,
          customFilename:
              'jobs_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv',
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () async {
            final result = await Navigator.pushNamed(context, '/new-job');
            if (result == true) {
              _loadJobs(); // Refresh the jobs list
            }
          },
          tooltip: 'Add Job',
        ),
      ],
      child: Column(
        children: [
          // Search and controls
          Row(
            children: [
              Expanded(
                child: ui.Input(
                  placeholder: 'Search jobs...',
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchTerm = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Button(
                onPressed: () async {
                  final result = await Navigator.pushNamed(context, '/new-job');
                  if (result == true) {
                    _loadJobs(); // Refresh the jobs list
                  }
                },
                text: 'Add Job',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            Button(
                              onPressed: _loadJobs,
                              text: 'Retry',
                            ),
                          ],
                        ),
                      )
                    : _filteredJobs.isEmpty
                        ? const Center(
                            child: Text('No jobs found'),
                          )
                        : ListView.builder(
                            itemCount: _filteredJobs.length,
                            itemBuilder: (context, index) {
                              return _buildJobCard(_filteredJobs[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
