import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:new_flutter/widgets/app_layout.dart';
import 'package:new_flutter/widgets/ui/button.dart' as ui;
import 'package:new_flutter/widgets/ui/input.dart' as ui;
import 'package:new_flutter/widgets/ui/card.dart' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import '../models/agency.dart';
import '../providers/agencies_provider.dart';
import '../widgets/clickable_contact_info.dart';
import 'package:new_flutter/theme/app_theme.dart';

class AgenciesPage extends StatefulWidget {
  const AgenciesPage({super.key});

  @override
  State<AgenciesPage> createState() => _AgenciesPageState();
}

class _AgenciesPageState extends State<AgenciesPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AgenciesProvider>().loadAgencies();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showDeleteConfirmation(Agency agency) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete Agency',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${agency.name}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAgency(agency);
    }
  }

  Future<void> _deleteAgency(Agency agency) async {
    final provider = context.read<AgenciesProvider>();
    final success = await provider.deleteAgency(agency.id!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Agency deleted successfully'
              : provider.error ?? 'Error deleting agency'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Widget _buildAgencyCard(Agency agency) {
    return ui.Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with agency name and action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agency.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Agency type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: agency.agencyType == 'Sister Agency'
                              ? Colors.blue[100]
                              : Colors.green[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          agency.agencyType ?? 'Agency',
                          style: TextStyle(
                            color: agency.agencyType == 'Sister Agency'
                                ? Colors.blue[700]
                                : Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/new-agency',
                          arguments: agency.id,
                        );
                        if (result != null && mounted) {
                          context.read<AgenciesProvider>().loadAgencies();
                        }
                      },
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        _showDeleteConfirmation(agency);
                      },
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Website link
            if (agency.website != null) ...[
              ClickableContactInfo(
                text: agency.website!,
                type: ContactType.location,
                showIcon: true,
                icon: Icons.language,
                iconColor: Colors.grey[600],
                textColor: Colors.white70,
                fontSize: 14,
              ),
              const SizedBox(height: 12),
            ],

            // Location information
            if (agency.address != null ||
                agency.city != null ||
                agency.country != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (agency.address != null)
                          ClickableContactInfo(
                            text: agency.address!,
                            type: ContactType.location,
                            showIcon: false,
                            textColor: Colors.white70,
                            fontSize: 14,
                          ),
                        if (agency.city != null || agency.country != null)
                          ClickableContactInfo(
                            text: [
                              agency.city,
                              agency.country,
                            ].where((e) => e != null).join(', '),
                            type: ContactType.location,
                            showIcon: false,
                            textColor: Colors.white70,
                            fontSize: 14,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Main Booker section
            if (agency.mainBooker != null) ...[
              const Divider(height: 16, thickness: 1, color: Colors.white10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Main Booker:',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    agency.mainBooker!.name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  if (agency.mainBooker!.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    ClickableContactInfo(
                      text: agency.mainBooker!.email,
                      type: ContactType.email,
                      showIcon: true,
                      textColor: Colors.white70,
                      fontSize: 14,
                    ),
                  ],
                  if (agency.mainBooker!.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    ClickableContactInfo(
                      text: agency.mainBooker!.phone,
                      type: ContactType.whatsapp,
                      showIcon: true,
                      textColor: Colors.white70,
                      fontSize: 14,
                    ),
                  ],
                  if (agency.mainBooker!.instagram != null &&
                      agency.mainBooker!.instagram!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    ClickableContactInfo(
                      text: agency.mainBooker!.instagram!.replaceAll('@', ''),
                      type: ContactType.instagram,
                      showIcon: true,
                      textColor: Colors.white70,
                      fontSize: 14,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Finance Contact section
            if (agency.financeContact != null) ...[
              const Divider(height: 32, thickness: 1, color: Colors.white10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finance Contact:',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    agency.financeContact!.name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  if (agency.financeContact!.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    ClickableContactInfo(
                      text: agency.financeContact!.email,
                      type: ContactType.email,
                      showIcon: true,
                      textColor: Colors.white70,
                      fontSize: 14,
                    ),
                  ],
                  if (agency.financeContact!.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    ClickableContactInfo(
                      text: agency.financeContact!.phone,
                      type: ContactType.whatsapp,
                      showIcon: true,
                      textColor: Colors.white70,
                      fontSize: 14,
                    ),
                  ],
                  if (agency.financeContact!.instagram != null &&
                      agency.financeContact!.instagram!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    ClickableContactInfo(
                      text:
                          agency.financeContact!.instagram!.replaceAll('@', ''),
                      type: ContactType.instagram,
                      showIcon: true,
                      textColor: Colors.white70,
                      fontSize: 14,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Commission section
            if (agency.commissionRate > 0) ...[
              const Divider(height: 32, thickness: 1, color: Colors.white10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Commission: ${agency.commissionRate}%',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // View Contract button - only show when contract exists
            if (agency.contract != null && agency.contract!.isNotEmpty) ...[
              InkWell(
                onTap: () {
                  // Placeholder for contract viewing functionality
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'View Contract',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn().slideX();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AgenciesProvider>(
      builder: (context, provider, child) {
        return AppLayout(
          currentPage: '/agencies',
          title: 'Agencies',
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Manage Your Agencies',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        ui.Button(
                          onPressed: () async {
                            final result = await Navigator.pushNamed(
                                context, '/new-agency');
                            if (result == true) {
                              provider.loadAgencies();
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add,
                                  size: 20, color: Colors.grey[100]),
                              const SizedBox(width: 8),
                              Text(
                                'Add Agency',
                                style: TextStyle(
                                  color: Colors.grey[100],
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ui.Input(
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        hintText: 'Search agencies...',
                        controller: _searchController,
                        onChanged: (value) => provider.setSearchTerm(value),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : provider.error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.red[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    provider.error!,
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ui.Button(
                                    onPressed: provider.loadAgencies,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.refresh,
                                          size: 20,
                                          color: Colors.grey[100],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Try Again',
                                          style: TextStyle(
                                            color: Colors.grey[100],
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : provider.filteredAgencies.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.business_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No agencies found',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try adjusting your search or add a new agency',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(24),
                                  itemCount: provider.filteredAgencies.length,
                                  separatorBuilder: (context, index) => Column(
                                    children: const [
                                      SizedBox(height: 8),
                                      Divider(color: AppTheme.borderColor, thickness: 1, height: 1),
                                      SizedBox(height: 8),
                                    ],
                                  ),
                                  itemBuilder: (context, index) =>
                                      _buildAgencyCard(
                                          provider.filteredAgencies[index]),
                                ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
