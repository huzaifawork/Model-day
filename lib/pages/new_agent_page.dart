import 'package:flutter/material.dart';
import 'package:new_flutter/widgets/app_layout.dart';

import 'package:new_flutter/widgets/ui/button.dart';
import 'package:new_flutter/widgets/ui/form_navigation_helper.dart';
import 'package:new_flutter/widgets/ui/agency_dropdown.dart';
import 'package:new_flutter/widgets/ocr_upload_widget.dart';
import 'package:new_flutter/models/agent.dart';
import 'package:new_flutter/services/agents_service.dart';

class NewAgentPage extends StatefulWidget {
  const NewAgentPage({super.key});

  @override
  State<NewAgentPage> createState() => _NewAgentPageState();
}

class _NewAgentPageState extends State<NewAgentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _agencyController = TextEditingController();
  String? _selectedAgencyId;
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _instagramController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isEditing = false;
  String? _editingId;

  final AgentsService _agentsService = AgentsService();
  final FormNavigationHelper _formNavigation = FormNavigationHelper();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is String) {
        _loadAgent(args);
      }
    });
  }

  Future<void> _loadAgent(String id) async {
    setState(() {
      _isLoading = true;
      _isEditing = true;
      _editingId = id;
    });

    try {
      final agent = await _agentsService.getAgentById(id);
      if (agent != null) {
        setState(() {
          _nameController.text = agent.name;
          _emailController.text = agent.email ?? '';
          _phoneController.text = agent.phone ?? '';
          _agencyController.text = agent.agency ?? '';
          _selectedAgencyId = agent.agencyId; // Load the agency relationship
          _cityController.text = agent.city ?? '';
          _countryController.text = agent.country ?? '';
          _instagramController.text = agent.instagram ?? '';
          _notesController.text = agent.notes ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading agent: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _agencyController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _instagramController.dispose();
    _notesController.dispose();
    _formNavigation.dispose();
    super.dispose();
  }

  void _handleOcrDataExtracted(Map<String, dynamic> data) {
    debugPrint('👤 OCR data extracted for agent: $data');

    setState(() {
      // Map agent name
      if (data['name'] != null) {
        _nameController.text = data['name'];
        debugPrint('👤 Set agent name: ${data['name']}');
      } else if (data['fullName'] != null) {
        _nameController.text = data['fullName'];
        debugPrint('👤 Set agent name from fullName: ${data['fullName']}');
      } else if (data['agentName'] != null) {
        _nameController.text = data['agentName'];
        debugPrint('👤 Set agent name from agentName: ${data['agentName']}');
      }

      // Map email
      if (data['email'] != null) {
        _emailController.text = data['email'];
        debugPrint('👤 Set email: ${data['email']}');
      }

      // Map phone
      if (data['phone'] != null) {
        _phoneController.text = data['phone'];
        debugPrint('👤 Set phone: ${data['phone']}');
      } else if (data['phoneNumber'] != null) {
        _phoneController.text = data['phoneNumber'];
        debugPrint('👤 Set phone from phoneNumber: ${data['phoneNumber']}');
      }

      // Map agency
      if (data['agency'] != null) {
        _agencyController.text = data['agency'];
        debugPrint('👤 Set agency: ${data['agency']}');
      } else if (data['agencyName'] != null) {
        _agencyController.text = data['agencyName'];
        debugPrint('👤 Set agency from agencyName: ${data['agencyName']}');
      }

      // Map city
      if (data['city'] != null) {
        _cityController.text = data['city'];
        debugPrint('👤 Set city: ${data['city']}');
      }

      // Map country
      if (data['country'] != null) {
        _countryController.text = data['country'];
        debugPrint('👤 Set country: ${data['country']}');
      }

      // Map Instagram username
      if (data['instagram'] != null) {
        final instagram = data['instagram'].toString().replaceAll('@', '');
        _instagramController.text = instagram;
        debugPrint('👤 Set instagram: $instagram');
      } else if (data['instagramUsername'] != null) {
        final instagram =
            data['instagramUsername'].toString().replaceAll('@', '');
        _instagramController.text = instagram;
        debugPrint('👤 Set instagram from instagramUsername: $instagram');
      }

      // Map notes
      if (data['notes'] != null) {
        _notesController.text = data['notes'];
        debugPrint('👤 Set notes: ${data['notes']}');
      } else if (data['description'] != null) {
        _notesController.text = data['description'];
        debugPrint('👤 Set notes from description: ${data['description']}');
      }

      // Add additional information to notes if available
      final additionalInfo = <String>[];

      if (data['experience'] != null) {
        additionalInfo.add('Experience: ${data['experience']}');
      }

      if (data['specialization'] != null) {
        additionalInfo.add('Specialization: ${data['specialization']}');
      }

      if (data['languages'] != null) {
        additionalInfo.add('Languages: ${data['languages']}');
      }

      if (data['availability'] != null) {
        additionalInfo.add('Availability: ${data['availability']}');
      }

      if (additionalInfo.isNotEmpty) {
        final currentNotes = _notesController.text;
        final additional = additionalInfo.join('\n');
        _notesController.text =
            currentNotes.isEmpty ? additional : '$currentNotes\n\n$additional';
      }
    });

    debugPrint('👤 Agent form populated with OCR data');
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final agent = Agent(
        id: _editingId,
        name: _nameController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        agency: _agencyController.text.isEmpty
            ? null
            : _agencyController.text, // Keep for backward compatibility
        agencyId: _selectedAgencyId, // New agency relationship
        city: _cityController.text.isEmpty ? null : _cityController.text,
        country:
            _countryController.text.isEmpty ? null : _countryController.text,
        instagram: _instagramController.text.isEmpty
            ? null
            : _instagramController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (_isEditing && _editingId != null) {
        await _agentsService.updateAgent(_editingId!, agent);
      } else {
        await _agentsService.createAgent(agent.toJson());
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving agent: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _isEditing) {
      return AppLayout(
        currentPage: '/new-agent',
        title: _isEditing ? 'Edit Agent' : 'New Agent',
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return AppLayout(
      currentPage: '/new-agent',
      title: _isEditing ? 'Edit Agent' : 'New Agent',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OCR Widget for new agents (not when editing)
              if (!_isEditing) ...[
                OcrUploadWidget(
                  onDataExtracted: (data) {
                    debugPrint('OCR Widget callback received data: $data');
                    _handleOcrDataExtracted(data);
                  },
                  onAutoSubmit: () {
                    debugPrint('Auto-submitting agent form after OCR...');
                    _handleSubmit();
                  },
                ),
                const SizedBox(height: 24),
              ],

              // Basic Information
              _buildSectionCard(
                'Basic Information',
                [
                  _formNavigation.createInputField(
                    label: 'Full Name',
                    controller: _nameController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter agent name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _formNavigation.createInputField(
                    label: 'Email',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          !value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _formNavigation.createInputField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  AgencyDropdown(
                    selectedAgencyId: _selectedAgencyId,
                    labelText: 'Agency *',
                    hintText: 'Select an agency',
                    onChanged: (value) {
                      setState(() {
                        _selectedAgencyId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please select an agency';
                      }
                      return null;
                    },
                    isRequired: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Location Information
              _buildSectionCard(
                'Location',
                [
                  Row(
                    children: [
                      Expanded(
                        child: _formNavigation.createInputField(
                          label: 'City',
                          controller: _cityController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _formNavigation.createInputField(
                          label: 'Country',
                          controller: _countryController,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Social Media
              _buildSectionCard(
                'Social Media',
                [
                  _formNavigation.createInputField(
                    label: 'Instagram Username (without @)',
                    controller: _instagramController,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Notes
              _buildSectionCard(
                'Notes',
                [
                  _formNavigation.createInputField(
                    label: 'Notes',
                    controller: _notesController,
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Submit Buttons
              Row(
                children: [
                  Expanded(
                    child: Button(
                      onPressed: () => Navigator.pop(context),
                      text: 'Cancel',
                      variant: ButtonVariant.outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Button(
                      onPressed: _isLoading ? null : _handleSubmit,
                      text: _isLoading
                          ? 'Saving...'
                          : (_isEditing ? 'Update Agent' : 'Create Agent'),
                      variant: ButtonVariant.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
